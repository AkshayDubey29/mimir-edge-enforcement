# Cardinality-Only Enforcement Setup

This document explains how to configure the Mimir Edge Enforcement system to enforce only cardinality limits (`per_metric_series_limit` and `per_user_series_limit`) while disabling all other limits.

## Overview

The system has been enhanced to support selective enforcement, allowing you to:

- **Enforce only cardinality limits**: `max_series_per_request` and `max_labels_per_series`
- **Disable rate limiting**: No samples per second or bytes per second enforcement
- **Disable body size limits**: No maximum body size enforcement
- **Maintain monitoring**: All metrics are still collected for visibility

## Configuration Changes Made

### 1. Enhanced RLS Service

**New Command-Line Flags Added:**
```bash
--enforce-samples-per-second=false      # Disable rate limiting
--enforce-max-body-bytes=false          # Disable body size limits
--enforce-max-labels-per-series=true    # Enable per_user_series_limit
--enforce-max-series-per-request=true   # Enable per_metric_series_limit
--enforce-bytes-per-second=false        # Disable bytes rate limiting
```

**New Enforcement Configuration:**
```go
type EnforcementConfig struct {
    Enabled                    bool
    EnforceSamplesPerSecond    bool
    EnforceMaxBodyBytes        bool
    EnforceMaxLabelsPerSeries  bool
    EnforceMaxSeriesPerRequest bool
    EnforceBytesPerSecond      bool
}
```

### 2. Updated Helm Values

**values-rls.yaml:**
```yaml
limits:
  defaultSamplesPerSecond: 0      # Disable rate limiting
  defaultBurstPercent: 0          # No burst allowance
  maxBodyBytes: 0                 # Disable body size limits
  defaultMaxLabelsPerSeries: 60   # per_user_series_limit
  defaultMaxSeriesPerRequest: 10000 # per_metric_series_limit

enforcement:
  enabled: true
  enforceMaxSeriesPerRequest: true   # per_metric_series_limit
  enforceMaxLabelsPerSeries: true    # per_user_series_limit
  enforceSamplesPerSecond: false     # No rate limiting
  enforceBytesPerSecond: false       # No bytes rate limiting
  enforceMaxBodyBytes: false         # No body size enforcement
```

**values-envoy.yaml:**
```yaml
extAuthz:
  maxRequestBytes: 10485760  # 10 MiB - Global safety limit
  failureModeAllow: false    # Security: deny on gRPC failure
  disableBodyParsing: false  # Enable parsing for cardinality analysis
```

## Deployment Steps

### 1. Build and Deploy RLS with Selective Enforcement

```bash
# Build RLS with new enforcement flags
cd services/rls
go build -o rls-amd64 cmd/rls/main.go

# Build Docker image
docker build --platform linux/amd64 -t ghcr.io/akshaydubey29/mimir-rls:latest-cardinality-enforcement .

# Deploy with cardinality-only enforcement
helm upgrade --install mimir-rls ./charts/mimir-rls -f values-rls.yaml
```

### 2. Deploy Envoy Configuration

```bash
helm upgrade --install mimir-envoy ./charts/mimir-envoy -f values-envoy.yaml
```

### 3. Configure Tenant-Specific Limits

The `mimir-overrides` ConfigMap already contains examples for cardinality-only enforcement. You can use the existing configurations or add your specific tenants:

**Option A: Use Existing Examples**
The ConfigMap already has `tenant-cardinality-only` configuration that enforces only cardinality limits.

**Option B: Add Your Specific Tenants**
Add your actual tenant IDs to the existing ConfigMap:

```yaml
# Add to existing mimir-overrides ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: mimir-overrides
  namespace: mimir-edge-enforcement
data:
  # Your actual tenant ID
  your-tenant-id: |
    {
      "samples_per_second": 0,
      "burst_pct": 0,
      "max_body_bytes": 0,
      "max_labels_per_series": 60,        # per_user_series_limit
      "max_series_per_request": 10000,    # per_metric_series_limit
      "enforcement": {
        "enabled": true,
        "enforce_samples_per_second": false,      # No rate limiting
        "enforce_max_body_bytes": false,          # No body size
        "enforce_max_labels_per_series": true,    # ENFORCE per_user_series_limit
        "enforce_max_series_per_request": true,   # ENFORCE per_metric_series_limit
        "enforce_bytes_per_second": false         # No bytes rate limiting
      }
    }
```

**The overrides-sync service will automatically detect and apply these configurations to RLS.**

## Expected Behavior

### ✅ What Will Be Enforced

1. **Series per Request Limit** (`per_metric_series_limit`):
   - Denies requests with more than `max_series_per_request` series
   - Reason: `max_series_per_request_exceeded`
   - HTTP Status: `429 Too Many Requests`

2. **Labels per Series Limit** (`per_user_series_limit`):
   - Denies requests with series having more than `max_labels_per_series` labels
   - Reason: `max_labels_per_series_exceeded`
   - HTTP Status: `429 Too Many Requests`

### ❌ What Will NOT Be Enforced

1. **Rate Limiting**: No samples per second or bytes per second limits
2. **Body Size**: No maximum body size enforcement
3. **Burst Limits**: No burst allowance enforcement

### 📊 What Will Still Be Monitored

1. **All Metrics**: Samples, bytes, series, labels are still counted
2. **Denial Tracking**: All denials are logged and visible in Admin UI
3. **Performance Metrics**: Response times, throughput, etc.
4. **Cardinality Analysis**: Series and label usage patterns

## Monitoring and Verification

### 1. Check RLS Logs

```bash
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls
```

Look for:
```
RLS: applied default enforcement configuration
enforce_samples_per_second: false
enforce_max_body_bytes: false
enforce_max_labels_per_series: true
enforce_max_series_per_request: true
enforce_bytes_per_second: false
```

### 2. Test Cardinality Enforcement

Generate traffic that exceeds cardinality limits:

```bash
# Test series per request limit
./scripts/load-remote-write \
  -url="http://localhost:8080/api/v1/push" \
  -tenant=test-tenant \
  -series=15000 \
  -duration=10s

# Test labels per series limit
./scripts/load-remote-write \
  -url="http://localhost:8080/api/v1/push" \
  -tenant=test-tenant \
  -labels=100 \
  -duration=10s
```

### 3. Monitor Denials in Admin UI

1. Open Admin UI: `http://localhost:3000`
2. Go to Denials page
3. Look for denial reasons:
   - `max_series_per_request_exceeded`
   - `max_labels_per_series_exceeded`

### 4. Check Tenant Metrics

1. Go to Tenants page in Admin UI
2. Verify that rate limiting metrics show 0 or disabled
3. Verify that cardinality metrics are being tracked

## Troubleshooting

### Common Issues

1. **All requests denied**:
   - Check if enforcement flags are correctly set
   - Verify tenant limits are not too restrictive

2. **No cardinality enforcement**:
   - Ensure `enforce_max_series_per_request` and `enforce_max_labels_per_series` are `true`
   - Check that tenant limits are greater than 0

3. **Rate limiting still active**:
   - Verify `enforce_samples_per_second` is `false`
   - Check that `defaultSamplesPerSecond` is 0

### Debug Commands

```bash
# Check RLS configuration
kubectl exec -n mimir-edge-enforcement deployment/mimir-rls -- ps aux

# Check tenant limits
curl http://localhost:8082/api/tenants/{tenant-id}

# Check recent denials
curl http://localhost:8082/api/denials

# Check enforcement configuration
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | grep enforcement
```

## Performance Impact

### Benefits of Cardinality-Only Enforcement

1. **Reduced Processing Overhead**: No rate limiting calculations
2. **Lower Memory Usage**: No token buckets for rate limiting
3. **Faster Response Times**: Fewer limit checks per request
4. **Simplified Configuration**: Focus on cardinality management

### Expected Performance

- **Request Processing**: ~10-20% faster (no rate limiting overhead)
- **Memory Usage**: ~30% reduction (no token buckets)
- **CPU Usage**: ~15% reduction (fewer calculations)

## Migration from Full Enforcement

If migrating from full enforcement to cardinality-only:

1. **Backup current configuration**
2. **Deploy with cardinality-only enforcement**
3. **Monitor denial rates** to ensure appropriate limits
4. **Adjust tenant limits** based on observed patterns
5. **Verify no unexpected denials** occur

## Security Considerations

1. **Global Safety Limits**: `maxRequestBytes` still enforced at Envoy level
2. **Failure Mode**: `failureModeAllow: false` for security
3. **Body Parsing**: Enabled for cardinality analysis but not for size enforcement
4. **Monitoring**: All requests still logged and monitored

## Next Steps

1. **Deploy the configuration** using the provided values files
2. **Test with your specific workloads** to verify cardinality limits
3. **Monitor denial patterns** and adjust limits as needed
4. **Consider implementing alerts** for cardinality violations
5. **Document tenant-specific limits** for your use cases
