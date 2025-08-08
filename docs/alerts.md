# Alert Rules (Suggested)

RLSDown: up{job="mimir-rls"} == 0 for 1m (critical)
HighDenialRate: rate(rls_decisions_total{decision="deny"}[5m]) > 0.1 for 2m (warning)
ParseErrors: rate(rls_body_parse_errors_total[5m]) > 0 for 5m (warning)
LimitsStale: rls_limits_stale_seconds > 300 for 1m (warning)

Envoy429Spike: increase(envoy_http_downstream_rq_xx{response_code="429"}[5m]) > 1000 (warning)
UpstreamErrors: rate(envoy_cluster_upstream_rq_5xx[5m]) > 0 (critical)

NoConfigMapWatch: absence of logs/metrics; add custom metric if needed

