# 🛡️ Envoy Resource Limits Configuration

This document explains the resource monitoring and overload management configuration for Envoy in the mimir-edge-enforcement system.

## 🎯 Purpose

Envoy resource limits protect against:
- **Connection exhaustion**: Too many concurrent connections
- **Memory exhaustion**: Heap memory usage spikes
- **Resource starvation**: Preventing complete service outage
- **Cascading failures**: Graceful degradation under load

## 📊 Default Configuration

### Connection Limits
```yaml
resourceLimits:
  maxDownstreamConnections: 10000    # Default: 10k connections
  disableKeepaliveThreshold: 0.8     # Disable keepalive at 80%
  stopAcceptingRequestsThreshold: 0.95  # Stop accepting at 95%
```

### Generated Envoy Configuration Structure
```yaml
overload_manager:
  refresh_interval: 0.25s
  resource_monitors:
  - name: "envoy.resource_monitors.downstream_connections"
  - name: "envoy.resource_monitors.fixed_heap"
  actions:
  - name: "envoy.overload_actions.disable_http_keepalive"
    triggers:
    - name: "envoy.resource_monitors.downstream_connections"
      threshold:
        value: 0.8
  - name: "envoy.overload_actions.stop_accepting_requests"
    triggers:
    - name: "envoy.resource_monitors.downstream_connections"
      threshold:
        value: 0.95
```

### Memory Limits
```yaml
resourceLimits:
  maxHeapSizeBytes: 838860800        # 800 MiB (for 1Gi container)
  shrinkHeapThreshold: 0.8           # Start shrinking at 80%
  heapStopAcceptingThreshold: 0.95   # Stop accepting at 95%
```

## 🚀 Production Recommendations

### High-Traffic Production
```yaml
envoy:
  resourceLimits:
    maxDownstreamConnections: 25000  # Higher for production
    maxHeapSizeBytes: 1677721600     # 1.6 GiB (for 2Gi container)
    disableKeepaliveThreshold: 0.8
    stopAcceptingRequestsThreshold: 0.9  # More conservative
    shrinkHeapThreshold: 0.75        # Start shrinking earlier
    heapStopAcceptingThreshold: 0.9
```

### Memory Calculation
The `maxHeapSizeBytes` should be **~80% of container memory limit**:
- **512 MiB container**: `maxHeapSizeBytes: 429496729` (400 MiB)
- **1 GiB container**: `maxHeapSizeBytes: 838860800` (800 MiB)  
- **2 GiB container**: `maxHeapSizeBytes: 1677721600` (1.6 GiB)

## 🔧 Configuration Behavior

### Overload Actions

#### 1. **Disable HTTP Keepalive** (80% connections)
- Closes idle connections
- Reduces connection pool size
- Forces new connections for new requests

#### 2. **Stop Accepting Requests** (95% connections or heap)
- Returns 503 Service Unavailable
- Allows existing requests to complete
- Prevents complete service failure

#### 3. **Shrink Heap** (80% memory)
- Triggers garbage collection
- Reduces memory footprint
- Improves memory efficiency

## 📈 Monitoring

### Key Metrics to Watch
```bash
# Envoy admin interface
kubectl port-forward svc/mimir-envoy 8001:8001 -n mimir-edge-enforcement
curl http://localhost:8001/stats | grep -E "(overload|heap|connections)"

# Key metrics:
# - overload.envoy.overload_actions.disable_http_keepalive.scale_timer
# - overload.envoy.overload_actions.stop_accepting_requests.scale_timer  
# - server.memory_allocated
# - server.memory_heap_size
# - http.inbound.downstream_cx_active
```

### Alerts
Set up alerts for:
- **Connection usage > 70%**: Scale up or investigate
- **Memory usage > 70%**: Check for memory leaks
- **Overload actions triggered**: Immediate investigation needed
- **503 errors from overload**: Scale immediately

## 🚨 Troubleshooting

### High Connection Usage
```bash
# Check current connections
curl http://localhost:8001/stats | grep downstream_cx_active

# Scale up Envoy replicas
kubectl scale deployment/mimir-envoy --replicas=5 -n mimir-edge-enforcement

# Or increase limits
helm upgrade mimir-envoy charts/envoy \
  --set resourceLimits.maxDownstreamConnections=50000
```

### Memory Pressure
```bash
# Check memory usage
curl http://localhost:8001/stats | grep memory_heap_size

# Increase container memory limits
helm upgrade mimir-envoy charts/envoy \
  --set resources.limits.memory=2Gi \
  --set resourceLimits.maxHeapSizeBytes=1677721600
```

### Overload Actions Triggered
```bash
# Check which actions are active
curl http://localhost:8001/stats | grep overload

# Temporarily increase thresholds (emergency)
helm upgrade mimir-envoy charts/envoy \
  --set resourceLimits.stopAcceptingRequestsThreshold=0.98

# Long-term: Scale resources
kubectl scale deployment/mimir-envoy --replicas=8 -n mimir-edge-enforcement
```

## 🎛️ Tuning Guidelines

### Development Environment
```yaml
resourceLimits:
  maxDownstreamConnections: 1000     # Lower for dev
  maxHeapSizeBytes: 209715200        # 200 MiB
```

### Staging Environment
```yaml
resourceLimits:
  maxDownstreamConnections: 5000     # Medium for staging
  maxHeapSizeBytes: 419430400        # 400 MiB
```

### Production Environment
```yaml
resourceLimits:
  maxDownstreamConnections: 25000    # High for production
  maxHeapSizeBytes: 838860800        # 800 MiB
  disableKeepaliveThreshold: 0.8
  stopAcceptingRequestsThreshold: 0.9  # More conservative
```

## 📋 Best Practices

1. **Monitor before tuning**: Establish baseline metrics
2. **Conservative thresholds**: Start restrictive, relax as needed
3. **Container alignment**: Heap size = ~80% of container memory
4. **Scale horizontally**: More replicas > higher limits
5. **Test overload**: Verify behavior under load
6. **Alert on trends**: Don't wait for thresholds to trigger

This configuration ensures Envoy remains stable and responsive even under extreme load conditions! 🛡️
