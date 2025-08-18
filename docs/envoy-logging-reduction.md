# Envoy Logging Reduction Configuration

## 🎯 **Objective**

Reduce Envoy proxy logs to minimize verbosity and improve performance in production environments.

## 🔧 **Changes Made**

### **1. Updated `values-envoy.yaml`**

**Logging Level:**
- Changed from `info` to `warn` to reduce log volume
- Only warnings and errors will be logged

**Access Logs:**
- Disabled access logs (`enableAccessLogs: false`)
- Previously logged every HTTP request, now disabled

**Additional Controls:**
```yaml
logging:
  level: "warn"                  # Reduced from info to warn
  enableAccessLogs: false        # Disabled to reduce verbosity
  enableDebugLogs: false         # Already disabled
  enableDetailedLogs: false      # Already disabled
  
  # New controls for reduced verbosity
  logFormat: "json"              # Structured JSON logging
  logSamplingRate: 0.1           # Only log 10% of requests
  enableErrorLogs: true          # Keep error logs for troubleshooting
  enableHealthCheckLogs: false   # Disable health check logs
  enableMetricsLogs: false       # Disable metrics logs
  enableAdminLogs: false         # Disable admin interface logs
```

### **2. Updated `charts/envoy/templates/configmap.yaml`**

**Conditional Access Logs:**
- Access logs are now only enabled if `logging.enableAccessLogs` is true
- Admin access logs are only enabled if `logging.enableAdminLogs` is true
- Simplified log format to reduce verbosity

**JSON vs Text Format:**
- Added support for JSON structured logging
- Configurable via `logging.logFormat`

### **3. Updated `charts/envoy/templates/deployment.yaml`**

**Command Line Arguments:**
- Added `--log-level` argument to set Envoy's internal log level
- Added `--enable-error-logs` flag for error logging control

### **4. Updated `charts/envoy/values.yaml`**

**Default Values:**
- Updated default logging configuration to be less verbose
- Set `level: "warn"` and `enableAccessLogs: false` by default

## 📊 **Expected Impact**

### **Before Changes:**
```
[INFO] Envoy access logs: Every HTTP request logged
[INFO] Admin interface logs: All admin requests logged
[INFO] Health check logs: All health check requests logged
[INFO] Detailed filter logs: Verbose filter processing logs
```

### **After Changes:**
```
[WARN] Only warnings and errors logged
[WARN] No access logs (disabled)
[WARN] No admin logs (disabled)
[WARN] No health check logs (disabled)
[WARN] Only critical errors and warnings
```

## 🎯 **Log Volume Reduction**

**Estimated Reduction:**
- **Access Logs:** 100% reduction (disabled)
- **Admin Logs:** 100% reduction (disabled)
- **Health Check Logs:** 100% reduction (disabled)
- **Info Logs:** 90% reduction (only warnings/errors)
- **Overall:** ~95% reduction in log volume

## 🔍 **What's Still Logged**

**Kept for Troubleshooting:**
- Error logs (`enableErrorLogs: true`)
- Warning logs (log level `warn`)
- Critical system errors
- RLS fallback events (if enabled)

**Removed for Performance:**
- HTTP access logs
- Admin interface logs
- Health check logs
- Info-level logs
- Detailed filter processing logs

## 🚀 **Deployment**

### **Apply Changes:**
```bash
# Update Envoy deployment with reduced logging
helm upgrade mimir-envoy charts/envoy -f values-envoy.yaml

# Verify the changes
kubectl logs -n mimir-edge-enforcement deployment/mimir-envoy --tail=20
```

### **Verify Log Reduction:**
```bash
# Check log volume before and after
kubectl logs -n mimir-edge-enforcement deployment/mimir-envoy --since=5m | wc -l

# Should see significantly fewer log lines
```

## 🔧 **Troubleshooting**

### **If You Need More Logs:**
```yaml
# Temporarily enable more verbose logging
logging:
  level: "info"
  enableAccessLogs: true
  enableErrorLogs: true
  enableHealthCheckLogs: true
```

### **If You Need Debug Logs:**
```yaml
# Enable debug logging for troubleshooting
logging:
  level: "debug"
  enableAccessLogs: true
  enableDebugLogs: true
```

## 📈 **Performance Benefits**

1. **Reduced I/O:** Fewer log writes to disk/network
2. **Lower CPU:** Less log processing overhead
3. **Smaller Log Storage:** Reduced storage requirements
4. **Better Performance:** More resources available for request processing
5. **Cleaner Monitoring:** Easier to spot actual issues

## 🎯 **Monitoring**

**Key Metrics to Monitor:**
- Log volume reduction
- Envoy performance metrics
- Error rate (should remain visible)
- Request processing latency

**Grafana Queries:**
```promql
# Log volume by level
sum(rate(envoy_logs_total[5m])) by (level)

# Error rate (should still be visible)
sum(rate(envoy_logs_total{level="error"}[5m]))
```

This configuration significantly reduces Envoy log verbosity while maintaining the ability to troubleshoot critical issues.
