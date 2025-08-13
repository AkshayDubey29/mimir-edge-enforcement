# Metrics Reference

This document provides a comprehensive reference for all metrics exposed by the Mimir Edge Enforcement system.

## RLS (Rate Limit Service) Metrics

### Authorization Decisions
- **`rls_decisions_total`** - Total number of authorization decisions
  - Labels: `decision` (allow/deny), `tenant`, `reason`
  - Example: `rls_decisions_total{decision="deny", tenant="test-tenant", reason="samples_per_second_exceeded"}`

### Performance Metrics
- **`rls_authz_check_duration_seconds`** - Duration of authorization checks (histogram)
  - Labels: `tenant`
  - Example: `histogram_quantile(0.95, rate(rls_authz_check_duration_seconds_bucket[5m]))`

### Error Metrics
- **`rls_body_parse_errors_total`** - Total number of body parsing errors
  - Example: `rate(rls_body_parse_errors_total[5m])`

### System Health
- **`rls_limits_stale_seconds`** - How long the limits have been stale
  - Example: `rls_limits_stale_seconds`

### Token Bucket Status
- **`rls_tenant_bucket_tokens`** - Available tokens in tenant buckets
  - Labels: `tenant`, `bucket_type` (samples, bytes, requests)
  - Example: `rls_tenant_bucket_tokens{tenant="test-tenant", bucket_type="samples"}`

### Traffic Flow Metrics
- **`rls_traffic_flow_total`** - Total number of requests processed by RLS
  - Labels: `tenant`, `decision`
  - Example: `rate(rls_traffic_flow_total[5m])`

- **`rls_traffic_flow_latency_seconds`** - Latency of requests processed by RLS (histogram)
  - Labels: `tenant`, `decision`
  - Example: `histogram_quantile(0.95, rate(rls_traffic_flow_latency_seconds_bucket[5m]))`

- **`rls_traffic_flow_bytes`** - Total bytes of requests processed by RLS
  - Labels: `tenant`, `decision`
  - Example: `rate(rls_traffic_flow_bytes[5m])`

### Limit Violations
- **`rls_limit_violations_total`** - Total number of limit violations
  - Labels: `tenant`, `reason`
  - Example: `rate(rls_limit_violations_total[5m])`

### Series and Labels Monitoring
- **`rls_series_count_gauge`** - Current series count for each tenant
  - Labels: `tenant`
  - Example: `rls_series_count_gauge{tenant="test-tenant"}`

- **`rls_labels_count_gauge`** - Current labels count for each tenant
  - Labels: `tenant`
  - Example: `rls_labels_count_gauge{tenant="test-tenant"}`

- **`rls_samples_count_gauge`** - Current samples count for each tenant
  - Labels: `tenant`
  - Example: `rls_samples_count_gauge{tenant="test-tenant"}`

### Request Size Monitoring
- **`rls_body_size_gauge`** - Current body size for each tenant
  - Labels: `tenant`
  - Example: `rls_body_size_gauge{tenant="test-tenant"}`

### Metric Series Tracking
- **`rls_metric_series_count_gauge`** - Current metric series count for each tenant
  - Labels: `tenant`, `metric`
  - Example: `rls_metric_series_count_gauge{tenant="test-tenant", metric="http_requests_total"}`

- **`rls_global_series_count_gauge`** - Current global series count
  - Labels: `metric`
  - Example: `rls_global_series_count_gauge{metric="http_requests_total"}`

### Limit Thresholds
- **`rls_limit_threshold_gauge`** - Current limit threshold for each tenant
  - Labels: `tenant`, `limit`
  - Example: `rls_limit_threshold_gauge{tenant="test-tenant", limit="samples_per_second"}`

## Envoy Proxy Metrics

### HTTP Response Codes
- **`envoy_http_downstream_rq_xx`** - HTTP response codes by category
  - Labels: `response_code`, `route`
  - Examples:
    - `envoy_http_downstream_rq_xx{response_code="200"}` - Successful requests
    - `envoy_http_downstream_rq_xx{response_code="429"}` - Rate limited requests
    - `envoy_http_downstream_rq_xx{response_code="403"}` - Forbidden requests
    - `envoy_http_downstream_rq_xx{response_code="502"}` - Bad gateway errors

### Request Metrics
- **`envoy_http_downstream_rq_total`** - Total HTTP requests processed by Envoy
  - Labels: `route`
  - Example: `rate(envoy_http_downstream_rq_total[5m])`

- **`envoy_http_downstream_rq_time`** - Request duration (histogram)
  - Labels: `route`
  - Example: `histogram_quantile(0.95, rate(envoy_http_downstream_rq_time_bucket[5m]))`

### External Authorization Filter
- **`envoy_http_ext_authz_total`** - Total external authorization requests
  - Labels: `grpc_service`
  - Example: `rate(envoy_http_ext_authz_total[5m])`

- **`envoy_http_ext_authz_duration`** - External authorization request duration (histogram)
  - Labels: `grpc_service`
  - Example: `histogram_quantile(0.95, rate(envoy_http_ext_authz_duration_bucket[5m]))`

### Rate Limit Filter
- **`envoy_http_ratelimit_total`** - Total rate limit requests
  - Labels: `grpc_service`
  - Example: `rate(envoy_http_ratelimit_total[5m])`

- **`envoy_http_ratelimit_duration`** - Rate limit request duration (histogram)
  - Labels: `grpc_service`
  - Example: `histogram_quantile(0.95, rate(envoy_http_ratelimit_duration_bucket[5m]))`

### Upstream Cluster Metrics
- **`envoy_cluster_upstream_rq_xx`** - Upstream response codes
  - Labels: `cluster_name`, `response_code`
  - Example: `rate(envoy_cluster_upstream_rq_xx{response_code="200"}[5m])`

- **`envoy_cluster_upstream_rq_time`** - Upstream request duration (histogram)
  - Labels: `cluster_name`
  - Example: `histogram_quantile(0.95, rate(envoy_cluster_upstream_rq_time_bucket[5m]))`

- **`envoy_cluster_upstream_cx_active`** - Active connections to upstream clusters
  - Labels: `cluster_name`
  - Example: `envoy_cluster_upstream_cx_active`

- **`envoy_cluster_upstream_cx_connect_fail`** - Connection failures to upstream clusters
  - Labels: `cluster_name`
  - Example: `rate(envoy_cluster_upstream_cx_connect_fail[5m])`

### Circuit Breaker Metrics
- **`envoy_cluster_circuit_breakers_default_rq_tripped`** - Circuit breaker trips
  - Labels: `cluster_name`
  - Example: `rate(envoy_cluster_circuit_breakers_default_rq_tripped[5m])`

### Memory and Resource Metrics
- **`envoy_server_memory_allocated`** - Envoy allocated memory
  - Example: `envoy_server_memory_allocated`

- **`envoy_server_memory_heap_size`** - Envoy heap size
  - Example: `envoy_server_memory_heap_size`

### Overload Management
- **`envoy_overload_actions_active`** - Active overload actions
  - Labels: `action`
  - Example: `envoy_overload_actions_active`

## Common PromQL Queries

### Rate Limiting Effectiveness
```promql
# Rate limiting decisions vs HTTP 429 responses
sum(rate(rls_decisions_total{decision="deny"}[5m])) by (tenant)
sum(rate(envoy_http_downstream_rq_xx{response_code="429"}[5m])) by (route)
```

### System Performance
```promql
# 95th percentile latency
histogram_quantile(0.95, sum(rate(envoy_http_downstream_rq_time_bucket[5m])) by (le, route))
histogram_quantile(0.95, sum(rate(rls_authz_check_duration_seconds_bucket[5m])) by (le, tenant))
```

### Error Rates
```promql
# HTTP error rates
sum(rate(envoy_http_downstream_rq_xx{response_code=~"4.*|5.*"}[5m])) by (response_code)

# RLS parse errors
rate(rls_body_parse_errors_total[5m])
```

### Tenant Activity
```promql
# Tenant activity by decision
sum(rate(rls_traffic_flow_total[5m])) by (tenant, decision)

# Limit violations by tenant
sum(rate(rls_limit_violations_total[5m])) by (tenant, reason)
```

### System Health
```promql
# Limits sync status
rls_limits_stale_seconds

# Upstream health
sum(rate(envoy_cluster_upstream_rq_xx{response_code=~"5.*"}[5m])) by (cluster_name)
```

## Dashboard Usage

The system provides several Grafana dashboards:

1. **RLS Comprehensive Dashboard** (`rls-comprehensive.json`) - Complete RLS metrics
2. **Envoy Comprehensive Dashboard** (`envoy-comprehensive.json`) - Complete Envoy metrics with response codes
3. **Overview Dashboard** (`overview-comprehensive.json`) - Combined system overview
4. **Enhanced Existing Dashboards** - Updated versions of original dashboards

## Alerting Recommendations

Based on these metrics, consider setting up alerts for:

- High denial rates: `rate(rls_decisions_total{decision="deny"}[5m]) > 0.1`
- Parse errors: `rate(rls_body_parse_errors_total[5m]) > 0`
- Stale limits: `rls_limits_stale_seconds > 300`
- High error rates: `rate(envoy_http_downstream_rq_xx{response_code=~"5.*"}[5m]) > 0.01`
- Circuit breaker trips: `rate(envoy_cluster_circuit_breakers_default_rq_tripped[5m]) > 0`
