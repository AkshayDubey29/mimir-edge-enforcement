# 🔧 Envoy Buffer Overflow Fixes

This document details the critical fixes applied to the Envoy Helm chart to resolve the "buffer size limit (64KB) for async client retries has been exceeded" error.

## 🚨 Root Cause Analysis

The buffer overflow error was caused by several configuration issues:

1. **Missing buffer_size_bytes configuration** - Used default 64KB
2. **Missing timeout configurations** - Requests hung indefinitely
3. **Resource limits mismatch** - 800MB heap vs 512Mi container
4. **Poor connection management** - No circuit breakers or health checks

## ✅ Applied Fixes

### 1. **ext_authz Buffer and Timeout Configuration**

**Problem**: No buffer size or timeout configuration causing indefinite retries.

**Fix**: Added buffer and timeout settings in `charts/envoy/templates/configmap.yaml`:

```yaml
- name: envoy.filters.http.ext_authz
  typed_config:
    "@type": type.googleapis.com/envoy.extensions.filters.http.ext_authz.v3.ExtAuthz
    # 🔧 FIX: Add buffer size configuration to prevent overflow
    buffer_size_bytes: 131072  # 128KB (double the default 64KB)
    # 🔧 FIX: Add timeout configuration to prevent hanging requests
    timeout: "5s"
    grpc_service:
      envoy_grpc:
        cluster_name: rls_ext_authz
        # 🔧 FIX: Add gRPC-specific timeout
        timeout: "4s"
```

**Configuration in `values.yaml`**:
```yaml
extAuthz:
  bufferSizeBytes: 131072   # 128KB (double the default 64KB)
  timeout: "5s"             # Overall ext_authz timeout
  grpcTimeout: "4s"         # gRPC call timeout
```

### 2. **Rate Limit Timeout Configuration**

**Problem**: Rate limit service had no timeout configuration.

**Fix**: Added timeout settings for consistency:

```yaml
- name: envoy.filters.http.ratelimit
  typed_config:
    "@type": type.googleapis.com/envoy.extensions.filters.http.ratelimit.v3.RateLimit
    # 🔧 FIX: Add timeout for rate limit service
    timeout: "3s"
    rate_limit_service:
      grpc_service:
        envoy_grpc:
          cluster_name: rls_ratelimit
          # 🔧 FIX: Add gRPC timeout for rate limit
          timeout: "2s"
```

### 3. **Resource Limits Fix**

**Problem**: Heap size (800MB) exceeded container memory (512Mi).

**Fix**: Reduced heap size to 75% of container memory:

```yaml
resourceLimits:
  # 🔧 FIX: Maximum heap size (75% of 512Mi container)
  maxHeapSizeBytes: 402653184  # 384 MiB
```

### 4. **RLS Cluster Health Checks and Circuit Breakers**

**Problem**: No health checks or connection management for RLS clusters.

**Fix**: Added comprehensive cluster configuration:

```yaml
- name: rls_ext_authz
  # 🔧 FIX: Add health checks for RLS service
  health_checks:
  - timeout: 1s
    interval: 5s
    unhealthy_threshold: 2
    healthy_threshold: 1
    http_health_check:
      path: "/health"
  
  # 🔧 FIX: Configure connection pool for better reliability
  circuit_breakers:
    thresholds:
    - priority: DEFAULT
      max_connections: 100
      max_pending_requests: 50
      max_requests: 200
      max_retries: 3
  
  # 🔧 FIX: Enhanced HTTP/2 configuration
  typed_extension_protocol_options:
    envoy.extensions.upstreams.http.v3.HttpProtocolOptions:
      "@type": type.googleapis.com/envoy.extensions.upstreams.http.v3.HttpProtocolOptions
      explicit_http_config:
        http2_protocol_options: 
          max_concurrent_streams: 100
```

## 🎯 Expected Results

After applying these fixes:

### ✅ **Buffer Overflow Resolution**
- **Before**: "buffer size limit (64KB) exceeded"
- **After**: 128KB buffer prevents overflow

### ✅ **Timeout Handling**
- **Before**: Requests hung indefinitely
- **After**: 5s timeout prevents hanging requests

### ✅ **Memory Stability**
- **Before**: 800MB heap vs 512Mi container
- **After**: 384MB heap (75% of 512Mi container)

### ✅ **Connection Reliability**
- **Before**: No health checks or circuit breakers
- **After**: Health checks and circuit breakers prevent cascading failures

### ✅ **Traffic Flow**
- **Before**: Only `/ready` health checks in Envoy logs
- **After**: Actual `/api/v1/push` requests processed

## 🚀 Deployment

To apply these fixes:

```bash
# Upgrade the Envoy deployment with fixed configuration
helm upgrade mimir-envoy charts/envoy \
  --namespace mimir-edge-enforcement \
  --values charts/envoy/values.yaml

# Verify the deployment
kubectl get pods -n mimir-edge-enforcement -l app.kubernetes.io/name=mimir-envoy

# Check Envoy logs for successful traffic processing
kubectl logs -n mimir-edge-enforcement -l app.kubernetes.io/name=mimir-envoy --tail=20
```

## 📊 Monitoring

After deployment, monitor these metrics:

```bash
# Check buffer usage (should be lower)
kubectl exec -n mimir-edge-enforcement <envoy-pod> -- \
  curl -s http://localhost:9901/stats | grep buffer

# Check ext_authz stats (should show successful requests)
kubectl exec -n mimir-edge-enforcement <envoy-pod> -- \
  curl -s http://localhost:9901/stats | grep ext_authz

# Check RLS cluster health
kubectl exec -n mimir-edge-enforcement <envoy-pod> -- \
  curl -s http://localhost:9901/clusters | grep rls
```

## 🎛️ Configuration Values

### **Default Settings (Production Ready)**
```yaml
# External authorization
extAuthz:
  maxRequestBytes: 4194304  # 4 MiB
  bufferSizeBytes: 131072   # 128KB
  timeout: "5s"
  grpcTimeout: "4s"
  failureModeAllow: false

# Rate limiting
rateLimit:
  timeout: "3s"
  grpcTimeout: "2s"
  failureModeDeny: true
  domain: "mimir_remote_write"

# Resource limits (for 512Mi container)
resourceLimits:
  maxHeapSizeBytes: 402653184  # 384 MiB (75% of 512Mi)
  shrinkHeapThreshold: 0.8
  heapStopAcceptingThreshold: 0.95
```

### **High-Traffic Environment**
For high-traffic production environments, consider:

```yaml
# Increase container resources
resources:
  limits:
    memory: 1Gi
    cpu: 1000m

# Adjust heap size accordingly
resourceLimits:
  maxHeapSizeBytes: 805306368  # 768 MiB (75% of 1Gi)

# Increase buffer size if needed
extAuthz:
  bufferSizeBytes: 262144  # 256KB for high traffic
```

## 🔍 Troubleshooting

### **If Buffer Overflow Still Occurs**
1. Increase buffer size: `bufferSizeBytes: 262144` (256KB)
2. Reduce timeout: `timeout: "3s"`
3. Check RLS service health
4. Scale RLS pods if overwhelmed

### **If Timeouts Occur**
1. Increase timeouts: `timeout: "10s"`
2. Check RLS response times
3. Verify network connectivity
4. Scale RLS resources

### **If Memory Issues Persist**
1. Increase container memory to 1Gi
2. Adjust heap size proportionally
3. Monitor memory usage patterns
4. Consider horizontal scaling

## 📋 Validation Checklist

After applying fixes, verify:

- [ ] **Buffer overflow errors eliminated** from Envoy logs
- [ ] **Actual `/api/v1/push` requests** appear in Envoy logs (not just `/ready`)
- [ ] **RLS service receives authorization requests**
- [ ] **Traffic flow metrics show real data** in Admin UI
- [ ] **Memory usage stays within limits**
- [ ] **No timeout errors in logs**
- [ ] **Circuit breakers don't trigger under normal load**

## 🎉 Success Indicators

You'll know the fixes worked when:

1. **Envoy logs show**: `POST /api/v1/push HTTP/1.1 200` (real traffic)
2. **RLS logs show**: Authorization and rate limit requests
3. **Admin UI shows**: Real traffic flow metrics instead of zeros
4. **No buffer overflow warnings** in Envoy logs
5. **Stable memory usage** within container limits

These fixes address the root causes of the buffer overflow issue and ensure reliable traffic flow through the edge enforcement pipeline! 🚀
