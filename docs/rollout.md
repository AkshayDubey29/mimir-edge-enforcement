# Mimir Edge Enforcement Rollout Guide

This guide provides step-by-step instructions for deploying Mimir Edge Enforcement in production with zero downtime and safe rollback capabilities.

## Prerequisites

### 1. Infrastructure Requirements
- Kubernetes cluster (v1.24+)
- Helm (v3.8+)
- kubectl configured
- NGINX ingress controller
- Prometheus monitoring stack (optional but recommended)

### 2. Mimir Setup
- Mimir cluster deployed and operational
- Overrides ConfigMap configured
- Distributor service accessible

### 3. Network Requirements
- Internal cluster communication between components
- External access to NGINX ingress
- Prometheus metrics endpoints accessible

## Deployment Phases

### Phase 1: Mirror Mode (Week 1)

**Objective**: Zero-impact testing and validation

#### Step 1: Deploy Core Components
```bash
# Create namespace
kubectl create namespace mimir-edge-enforcement

# Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Deploy RLS service
helm install mimir-rls charts/mimir-rls/ \
  --namespace mimir-edge-enforcement \
  --set image.tag=v0.1.0 \
  --set replicaCount=2 \
  --set hpa.enabled=true

# Deploy overrides-sync
helm install overrides-sync charts/overrides-sync/ \
  --namespace mimir-edge-enforcement \
  --set image.tag=v0.1.0 \
  --set mimir.namespace=mimir \
  --set mimir.overridesConfigMap=mimir-overrides

# Deploy Envoy (mirror mode)
helm install mimir-envoy charts/envoy/ \
  --namespace mimir-edge-enforcement \
  --set image.tag=v0.1.0 \
  --set replicaCount=2 \
  --set hpa.enabled=true
```

#### Step 2: Configure NGINX Mirror
```nginx
# Apply mirror configuration
# See ops/nginx/mirror.conf.gist

upstream mimir_distributor {
    server mimir-distributor.mimir.svc.cluster.local:8080;
}

upstream mimir_envoy {
    server mimir-envoy.mimir-edge-enforcement.svc.cluster.local:8080;
}

server {
    listen 80;
    server_name _;

    # Mirror traffic to Envoy (shadow mode)
    mirror /api/v1/push;
    mirror_timeout 30s;

    location /api/v1/push {
        proxy_pass http://mimir_distributor;
        # ... standard proxy settings
    }
}
```

#### Step 3: Validation
```bash
# Check component health
kubectl get pods -n mimir-edge-enforcement
kubectl logs -f deployment/mimir-rls -n mimir-edge-enforcement
kubectl logs -f deployment/mimir-envoy -n mimir-edge-enforcement

# Verify metrics
curl http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:9090/metrics
curl http://mimir-envoy.mimir-edge-enforcement.svc.cluster.local:9901/stats/prometheus

# Test traffic flow
curl -X POST http://your-nginx/api/v1/push \
  -H "Content-Type: application/x-protobuf" \
  -H "X-Scope-OrgID: test-tenant" \
  -d "test-data"
```

**Success Criteria**:
- All pods healthy and ready
- RLS metrics showing authorization decisions
- No impact on existing traffic
- Mirror responses being ignored

### Phase 2: Canary Mode (Week 2)

**Objective**: Gradual traffic shifting with monitoring

#### Step 1: Update NGINX Configuration
```nginx
# Apply canary configuration
# See ops/nginx/canary.conf.gist

split_clients "${remote_addr}${request_uri}" $backend {
    1%     mimir_envoy;      # Start with 1% traffic
    99%    mimir_distributor;
}

location /api/v1/push {
    proxy_pass http://$backend;
    # ... standard proxy settings
}
```

#### Step 2: Monitor and Validate
```bash
# Monitor error rates
kubectl logs -f deployment/mimir-rls -n mimir-edge-enforcement | grep "denied"

# Check metrics
curl http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:9090/metrics | grep rls_decisions_total

# Monitor application metrics
# Check Grafana dashboards for:
# - Error rate comparison
# - Latency comparison
# - Throughput comparison
```

#### Step 3: Gradual Increase
```nginx
# Increase traffic gradually
split_clients "${remote_addr}${request_uri}" $backend {
    5%     mimir_envoy;      # 5% traffic
    95%    mimir_distributor;
}

# Monitor for 2 hours, then:
split_clients "${remote_addr}${request_uri}" $backend {
    10%    mimir_envoy;      # 10% traffic
    90%    mimir_distributor;
}

# Continue until 100%
split_clients "${remote_addr}${request_uri}" $backend {
    100%   mimir_envoy;      # All traffic
}
```

**Success Criteria**:
- Error rates within acceptable limits
- Latency impact < 5ms
- No customer complaints
- Metrics showing proper enforcement

### Phase 3: Full Mode (Week 3)

**Objective**: Complete deployment with full enforcement

#### Step 1: Update NGINX Configuration
```nginx
# Direct all traffic to Envoy
location /api/v1/push {
    proxy_pass http://mimir_envoy;
    # ... standard proxy settings
}
```

#### Step 2: Scale Components
```bash
# Scale up for production load
helm upgrade mimir-rls charts/mimir-rls/ \
  --namespace mimir-edge-enforcement \
  --set replicaCount=3 \
  --set hpa.maxReplicas=10

helm upgrade mimir-envoy charts/envoy/ \
  --namespace mimir-edge-enforcement \
  --set replicaCount=3 \
  --set hpa.maxReplicas=10
```

#### Step 3: Enable Advanced Features
```bash
# Enable body parsing for accurate enforcement
helm upgrade mimir-rls charts/mimir-rls/ \
  --namespace mimir-edge-enforcement \
  --set limits.enforceBodyParsing=true

# Configure failure modes
helm upgrade mimir-envoy charts/envoy/ \
  --namespace mimir-edge-enforcement \
  --set extAuthz.failureModeAllow=false \
  --set rateLimit.failureModeDeny=true
```

## Monitoring and Alerting

### 1. Key Metrics to Monitor
```promql
# RLS health
rls_decisions_total{decision="deny"}
rls_authz_check_duration_seconds_bucket
rls_body_parse_errors_total

# Envoy health
envoy_http_downstream_rq_xx{response_code="429"}
envoy_http_downstream_rq_total

# Overrides sync
rls_limits_stale_seconds
```

### 2. Alert Rules
```yaml
# RLS down
- alert: RLSDown
  expr: up{job="mimir-rls"} == 0
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "RLS service is down"

# High denial rate
- alert: HighDenialRate
  expr: rate(rls_decisions_total{decision="deny"}[5m]) > 0.1
  for: 2m
  labels:
    severity: warning
  annotations:
    summary: "High rate of denied requests"

# Limits stale
- alert: LimitsStale
  expr: rls_limits_stale_seconds > 300
  for: 1m
  labels:
    severity: warning
  annotations:
    summary: "RLS limits are stale"
```

## Rollback Procedures

### Emergency Rollback (0-5 minutes)
```bash
# Option 1: NGINX configuration rollback
# Apply direct routing configuration (see rollback-runbook.md)

# Option 2: Kubernetes service rollback
kubectl scale deployment mimir-envoy --replicas=0 -n mimir-edge-enforcement
kubectl scale deployment mimir-rls --replicas=0 -n mimir-edge-enforcement
```

### Gradual Rollback
```nginx
# Reduce traffic gradually
split_clients "${remote_addr}${request_uri}" $backend {
    50%    mimir_envoy;
    50%    mimir_distributor;
}

# Then 25%, 10%, 5%, 0%
```

## Post-Deployment Validation

### 1. Functional Testing
```bash
# Test rate limiting
for i in {1..100}; do
  curl -X POST http://your-nginx/api/v1/push \
    -H "X-Scope-OrgID: test-tenant" \
    -d "test-data"
done

# Verify some requests are denied (429)
```

### 2. Performance Testing
```bash
# Run load tests
go run scripts/load-remote-write.go \
  -url=http://your-nginx/api/v1/push \
  -tenant=load-test-tenant \
  -concurrency=50 \
  -duration=5m
```

### 3. Monitoring Validation
- [ ] All dashboards populated with data
- [ ] Alerts configured and tested
- [ ] Log aggregation working
- [ ] Metrics flowing to Prometheus

## Success Metrics

### 1. Technical Metrics
- **Latency**: < 5ms additional latency
- **Throughput**: > 10,000 req/s per RLS instance
- **Availability**: > 99.9% uptime
- **Error Rate**: < 0.1% 4xx/5xx errors

### 2. Business Metrics
- **Enforcement Accuracy**: > 95% correct rate limiting
- **False Positives**: < 1% legitimate requests denied
- **Customer Impact**: Zero customer complaints
- **Cost Savings**: Measurable reduction in Mimir resource usage

## Maintenance Procedures

### 1. Regular Updates
```bash
# Update images
helm upgrade mimir-rls charts/mimir-rls/ \
  --namespace mimir-edge-enforcement \
  --set image.tag=v0.2.0

# Rolling update with zero downtime
kubectl rollout restart deployment/mimir-rls -n mimir-edge-enforcement
```

### 2. Configuration Changes
```bash
# Update limits
kubectl patch configmap mimir-overrides -n mimir \
  --patch '{"data":{"tenant-1:samples_per_second":"15000"}}'

# Verify sync
kubectl logs -f deployment/overrides-sync -n mimir-edge-enforcement
```

### 3. Scaling
```bash
# Scale based on metrics
kubectl autoscale deployment mimir-rls \
  --namespace mimir-edge-enforcement \
  --min=2 --max=10 --cpu-percent=80
```

## Troubleshooting

### Common Issues

1. **RLS not receiving requests**
   - Check Envoy configuration
   - Verify gRPC connectivity
   - Check logs for connection errors

2. **High denial rates**
   - Review tenant limits
   - Check for burst configuration
   - Verify tenant header parsing

3. **Performance degradation**
   - Scale up RLS instances
   - Check resource limits
   - Monitor token bucket states

### Debug Commands
```bash
# Check component status
kubectl get pods -n mimir-edge-enforcement
kubectl describe pod <pod-name> -n mimir-edge-enforcement

# View logs
kubectl logs -f deployment/mimir-rls -n mimir-edge-enforcement
kubectl logs -f deployment/mimir-envoy -n mimir-edge-enforcement

# Check metrics
curl http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:9090/metrics

# Test endpoints
curl -X POST http://your-nginx/api/v1/push \
  -H "X-Scope-OrgID: test-tenant" \
  -d "test-data"
``` 