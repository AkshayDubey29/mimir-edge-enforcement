# Default Limits and Configuration Parameters

## 🔧 **RLS (Rate Limiting Service) Configuration**

This document outlines all the default limits and configuration parameters for the Mimir Edge Enforcement system.

---

## 📋 **SERVER CONFIGURATION**

### **Port Assignments**
```go
extAuthzPort  = flag.String("ext-authz-port", "8080", "Port for ext_authz gRPC server")
rateLimitPort = flag.String("rate-limit-port", "8081", "Port for ratelimit gRPC server")
adminPort     = flag.String("admin-port", "8082", "Port for admin HTTP server")
metricsPort   = flag.String("metrics-port", "9090", "Port for metrics HTTP server")
```

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `ext-authz-port` | `8080` | gRPC port for Envoy ext_authz service |
| `rate-limit-port` | `8081` | gRPC port for Envoy ratelimit service |
| `admin-port` | `8082` | HTTP port for Admin UI API |
| `metrics-port` | `9090` | HTTP port for Prometheus metrics |

---

## 🔧 **CORE CONFIGURATION**

### **Tenant and Request Processing**
```go
tenantHeader       = flag.String("tenant-header", "X-Scope-OrgID", "Header name for tenant identification")
enforceBodyParsing = flag.Bool("enforce-body-parsing", true, "Whether to parse request body for sample counting")
maxRequestBytes    = flag.Int64("max-request-bytes", 4194304, "Maximum request body size in bytes")
failureModeAllow   = flag.Bool("failure-mode-allow", false, "Whether to allow requests when body parsing fails")
```

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `tenant-header` | `X-Scope-OrgID` | HTTP header used to identify tenants |
| `enforce-body-parsing` | `true` | Enable parsing of remote write protobuf for sample counting |
| `max-request-bytes` | `4,194,304` (4MB) | Maximum request body size that can be processed |
| `failure-mode-allow` | `false` | Allow requests when body parsing fails (vs deny) |

---

## 📊 **DEFAULT TENANT LIMITS**

### **Rate Limiting Limits**
```go
defaultSamplesPerSecond    = flag.Float64("default-samples-per-second", 10000, "Default samples per second limit")
defaultBurstPercent        = flag.Float64("default-burst-percent", 0.2, "Default burst percentage")
```

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `default-samples-per-second` | `10,000` | Maximum samples per second per tenant |
| `default-burst-percent` | `0.2` (20%) | Burst allowance as percentage of rate limit |

**Burst Calculation Example:**
- Rate Limit: 10,000 samples/sec
- Burst Percent: 20%
- Burst Allowance: 10,000 × 0.2 = 2,000 samples
- Total Capacity: 10,000 + 2,000 = 12,000 samples

### **Request Size Limits**
```go
defaultMaxBodyBytes        = flag.Int64("default-max-body-bytes", 4194304, "Default maximum body size in bytes")
```

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `default-max-body-bytes` | `4,194,304` (4MB) | Maximum request body size per tenant |

### **Series and Label Limits**
```go
defaultMaxLabelsPerSeries  = flag.Int("default-max-labels-per-series", 60, "Default maximum labels per series")
defaultMaxLabelValueLength = flag.Int("default-max-label-value-length", 2048, "Default maximum label value length")
defaultMaxSeriesPerRequest = flag.Int("default-max-series-per-request", 100000, "Default maximum series per request")
```

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `default-max-labels-per-series` | `60` | Maximum number of labels per time series |
| `default-max-label-value-length` | `2,048` | Maximum length of label values |
| `default-max-series-per-request` | `100,000` | Maximum number of series per request |

---

## 🎛️ **LOGGING CONFIGURATION**

```go
logLevel = flag.String("log-level", "info", "Log level (debug, info, warn, error)")
```

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `log-level` | `info` | Logging level (debug, info, warn, error) |

---

## 📈 **LIMIT ENFORCEMENT MECHANISMS**

### **Token Bucket Rate Limiting**
The system uses token buckets for rate limiting with the following characteristics:

1. **Samples Per Second Bucket**
   - Rate: `default-samples-per-second` (10,000 samples/sec)
   - Capacity: Rate + (Rate × Burst Percent) = 12,000 samples
   - Refill: Time-based refill at the specified rate

2. **Bytes Per Second Bucket**
   - Rate: Based on `default-max-body-bytes` (4MB)
   - Capacity: Rate + (Rate × Burst Percent)
   - Refill: Time-based refill at the specified rate

3. **Requests Per Second Bucket**
   - Rate: Unlimited (not enforced by default)
   - Capacity: Unlimited
   - Used for monitoring purposes

### **Enforcement Decision Logic**
```go
// Check body size
if tenant.Info.Limits.MaxBodyBytes > 0 && bodyBytes > tenant.Info.Limits.MaxBodyBytes {
    return limits.Decision{
        Allowed: false,
        Reason:  "body_size_exceeded",
        Code:    http.StatusRequestEntityTooLarge,
    }
}

// Check samples per second
if tenant.SamplesBucket != nil && tenant.Info.Limits.SamplesPerSecond > 0 && !tenant.SamplesBucket.Take(float64(samples)) {
    return limits.Decision{
        Allowed: false,
        Reason:  "samples_rate_exceeded",
        Code:    http.StatusTooManyRequests,
    }
}

// Check bytes per second
if tenant.BytesBucket != nil && tenant.Info.Limits.MaxBodyBytes > 0 && !tenant.BytesBucket.Take(float64(bodyBytes)) {
    return limits.Decision{
        Allowed: false,
        Reason:  "bytes_rate_exceeded",
        Code:    http.StatusTooManyRequests,
    }
}
```

---

## 🔄 **FAILURE MODES**

### **Body Parsing Failures**
When `enforce-body-parsing` is enabled and parsing fails:

- **`failure-mode-allow: false`** (default): Request is denied
- **`failure-mode-allow: true`**: Request is allowed

### **Missing Tenant Header**
- Request is denied with HTTP 400 Bad Request
- Reason: "missing tenant header"

### **Unknown Tenants**
- Default to enforcement disabled
- All requests are allowed
- Reason: "enforcement_disabled"

---

## 🚀 **STARTUP COMMAND EXAMPLES**

### **Default Configuration**
```bash
./rls
```

### **Custom Limits**
```bash
./rls \
  --default-samples-per-second=5000 \
  --default-burst-percent=0.3 \
  --default-max-body-bytes=8388608 \
  --default-max-labels-per-series=80 \
  --default-max-label-value-length=4096 \
  --default-max-series-per-request=200000
```

### **Development Configuration**
```bash
./rls \
  --log-level=debug \
  --failure-mode-allow=true \
  --enforce-body-parsing=false
```

### **Production Configuration**
```bash
./rls \
  --log-level=info \
  --failure-mode-allow=false \
  --enforce-body-parsing=true \
  --default-samples-per-second=20000 \
  --default-burst-percent=0.1
```

---

## 📊 **MONITORING AND METRICS**

### **Prometheus Metrics**
The system exposes the following metrics on port 9090:

- `rls_decisions_total`: Total authorization decisions by tenant and reason
- `rls_authz_check_duration_seconds`: Authorization check duration
- `rls_body_parse_errors_total`: Body parsing errors
- `rls_limits_stale_seconds`: How stale the limits are
- `rls_tenant_buckets`: Token bucket availability by tenant

### **Health Checks**
- **Health**: `GET /healthz` - Basic health check
- **Readiness**: `GET /readyz` - Readiness check
- **Admin Health**: `GET /api/health` - Detailed health status

---

## ⚙️ **CONFIGURATION BEST PRACTICES**

### **Production Recommendations**
1. **Rate Limits**: Start conservative and adjust based on monitoring
2. **Burst Percent**: 10-20% for production, 20-30% for development
3. **Body Size**: 4MB default is usually sufficient
4. **Failure Mode**: Use `false` for strict enforcement
5. **Logging**: Use `info` level for production

### **Development Recommendations**
1. **Rate Limits**: Use higher limits for testing
2. **Burst Percent**: Use higher burst for flexibility
3. **Failure Mode**: Use `true` for easier debugging
4. **Logging**: Use `debug` level for detailed logs
5. **Body Parsing**: Can disable for simpler testing

---

## 🔍 **TROUBLESHOOTING**

### **Common Issues**
1. **Requests Denied**: Check tenant limits and burst configuration
2. **Body Size Errors**: Increase `max-request-bytes` or `default-max-body-bytes`
3. **Parsing Failures**: Check `failure-mode-allow` setting
4. **High Latency**: Monitor `rls_authz_check_duration_seconds`

### **Monitoring Queries**
```promql
# Denial rate by tenant
rate(rls_decisions_total{decision="deny"}[5m])

# Authorization latency
histogram_quantile(0.95, rate(rls_authz_check_duration_seconds_bucket[5m]))

# Token bucket utilization
rls_tenant_buckets
```

---

## 📝 **SUMMARY**

The default configuration provides a balanced approach for most production environments:

- **10,000 samples/sec** with 20% burst allowance
- **4MB request body** limit
- **60 labels per series** maximum
- **2KB label values** maximum
- **100K series per request** maximum
- **Strict failure mode** (deny on parsing errors)
- **Body parsing enabled** for accurate sample counting

These defaults can be adjusted based on your specific requirements and monitoring data.
