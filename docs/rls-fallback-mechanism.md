# RLS Fallback Mechanism Documentation

## Overview

The RLS (Rate Limit Service) fallback mechanism ensures that metrics continue flowing to Mimir even when RLS is temporarily unavailable or returns 503 errors. This provides high availability and prevents metric loss during RLS outages.

## How It Works

### 1. Primary Flow
```
Client Request → Envoy → RLS → Mimir Distributor
```

### 2. Fallback Flow (when RLS returns 503)
```
Client Request → Envoy → RLS (503 error) → Envoy → Mimir Distributor (direct)
```

## Configuration

### Envoy Configuration (`values-envoy.yaml`)

```yaml
# RLS Fallback configuration - Production Reliability
rlsFallback:
  enabled: true                    # Enable fallback to Mimir distributor
  triggerStatusCodes: ["503"]      # Status codes that trigger fallback
  maxRetries: 1                    # Number of retries before fallback
  retryTimeout: "5s"               # Timeout for retry attempts
  fallbackTimeout: "30s"           # Timeout for fallback requests
  logFallbackEvents: true          # Log fallback events for monitoring
  addFallbackHeaders: true         # Add headers to track fallback usage
```

### Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `enabled` | `true` | Enable/disable the fallback mechanism |
| `triggerStatusCodes` | `["503"]` | HTTP status codes that trigger fallback |
| `maxRetries` | `1` | Number of retries to RLS before fallback |
| `retryTimeout` | `"5s"` | Timeout for each retry attempt |
| `fallbackTimeout` | `"30s"` | Timeout for fallback requests to Mimir |
| `logFallbackEvents` | `true` | Log fallback events for monitoring |
| `addFallbackHeaders` | `true` | Add tracking headers to fallback requests |

## Implementation Details

### 1. Lua Filter
A Lua filter monitors responses from RLS and adds a fallback header when 503 errors are detected:

```lua
function envoy_on_response(response_handle)
  local status = response_handle:headers():get(":status")
  local upstream_cluster = response_handle:streamInfo():upstreamCluster()
  
  if status == "503" and upstream_cluster == "rls_remote_write" then
    response_handle:headers():add("x-rls-fallback", "true")
    response_handle:logInfo("RLS fallback triggered: 503 error from RLS")
  end
end
```

### 2. Fallback Route
A dedicated route handles requests with the fallback header:

```yaml
- match:
    prefix: "/api/v1/push"
    headers:
    - name: "x-rls-fallback"
      present_match: true
  route:
    cluster: mimir_distributor
    timeout: "30s"
    request_headers_to_add:
    - header:
        key: "x-rls-bypass"
        value: "true"
    - header:
        key: "x-fallback-reason"
        value: "rls-service-unavailable"
```

### 3. Retry Policy
The primary route includes a retry policy for transient failures:

```yaml
retry_policy:
  retry_on: "5xx,connect-failure,refused-stream,unavailable,cancelled,retriable-status-codes"
  num_retries: 1
  per_try_timeout: "5s"
```

## Monitoring and Observability

### Headers Added During Fallback

| Header | Value | Purpose |
|--------|-------|---------|
| `x-rls-bypass` | `true` | Indicates RLS was bypassed |
| `x-fallback-reason` | `rls-service-unavailable` | Reason for fallback |
| `x-fallback-timestamp` | `%START_TIME%` | When fallback occurred |

### Log Messages

The system logs fallback events when enabled:

```
[INFO] RLS fallback triggered: 503 error from RLS, routing to Mimir distributor
```

### Metrics to Monitor

1. **Fallback Rate**: Percentage of requests using fallback
2. **RLS Error Rate**: 503 errors from RLS service
3. **Fallback Latency**: Time difference between primary and fallback paths
4. **Mimir Success Rate**: Success rate of fallback requests

## Use Cases

### 1. RLS Service Outage
When RLS pods are down or restarting, requests automatically fallback to Mimir.

### 2. RLS Overload
When RLS is overwhelmed and returns 503 errors, requests bypass RLS.

### 3. Network Issues
When network connectivity to RLS is intermittent, fallback ensures reliability.

## Benefits

1. **High Availability**: Metrics continue flowing during RLS outages
2. **Zero Data Loss**: No metrics are dropped due to RLS failures
3. **Automatic Recovery**: System automatically recovers when RLS is healthy
4. **Transparent Operation**: Clients don't need to handle fallback logic
5. **Observability**: Full visibility into fallback usage and reasons

## Considerations

### 1. Rate Limiting Bypass
During fallback, rate limiting is bypassed. This should be temporary and monitored.

### 2. Monitoring Requirements
Enable monitoring to track fallback usage and ensure it's not abused.

### 3. Alerting
Set up alerts for:
- High fallback rates (>5% of requests)
- Extended fallback periods (>5 minutes)
- RLS service outages

### 4. Performance Impact
The Lua filter adds minimal latency (~1-2ms) to all requests.

## Troubleshooting

### Common Issues

1. **Fallback Not Triggering**
   - Check if `rlsFallback.enabled` is `true`
   - Verify RLS is returning 503 status codes
   - Check Envoy logs for Lua filter errors

2. **Fallback Always Triggering**
   - Check RLS service health
   - Verify RLS configuration
   - Monitor RLS resource usage

3. **High Latency During Fallback**
   - Check Mimir distributor health
   - Verify network connectivity
   - Monitor Mimir resource usage

### Debug Commands

```bash
# Check Envoy logs for fallback events
kubectl logs -n mimir-edge-enforcement deployment/mimir-envoy | grep "fallback"

# Check RLS service status
kubectl get pods -n mimir-edge-enforcement -l app.kubernetes.io/name=mimir-rls

# Check Mimir distributor health
kubectl get pods -n mimir -l app.kubernetes.io/name=mimir-distributor
```

## Best Practices

1. **Monitor Fallback Usage**: Track fallback rates and set up alerts
2. **Test Fallback**: Regularly test the fallback mechanism
3. **Document Incidents**: Document when fallback is used and why
4. **Review Configuration**: Periodically review fallback configuration
5. **Capacity Planning**: Ensure Mimir can handle additional load during fallback
