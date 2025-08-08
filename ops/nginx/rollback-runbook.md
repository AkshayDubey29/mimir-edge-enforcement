# Mimir Edge Enforcement Rollback Runbook

This document provides step-by-step instructions for rolling back the Mimir Edge Enforcement system in emergency situations.

## Emergency Rollback Scenarios

### 1. High Error Rate or Service Degradation
- **Symptoms**: Increased 4xx/5xx errors, high latency, service timeouts
- **Action**: Immediate rollback to direct Mimir distributor

### 2. Envoy or RLS Service Failure
- **Symptoms**: Envoy/RLS pods not ready, health checks failing
- **Action**: Bypass edge enforcement entirely

### 3. Configuration Issues
- **Symptoms**: Incorrect rate limiting, false positives/negatives
- **Action**: Rollback to previous configuration or disable enforcement

## Rollback Procedures

### Phase 1: Quick Rollback (0-5 minutes)

#### Option A: NGINX Configuration Rollback
```bash
# 1. Backup current configuration
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)

# 2. Apply direct routing configuration
cat > /etc/nginx/conf.d/mimir-direct.conf << 'EOF'
upstream mimir_distributor {
    server mimir-distributor.mimir.svc.cluster.local:8080;
}

server {
    listen 80;
    server_name _;

    location /api/v1/push {
        proxy_pass http://mimir_distributor;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Scope-OrgID $http_x_scope_orgid;
        
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
        proxy_request_buffering off;
        proxy_buffering off;
    }

    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# 3. Test configuration
nginx -t

# 4. Reload NGINX
nginx -s reload
```

#### Option B: Kubernetes Service Rollback
```bash
# 1. Scale down edge enforcement components
kubectl scale deployment mimir-envoy --replicas=0 -n mimir-edge-enforcement
kubectl scale deployment mimir-rls --replicas=0 -n mimir-edge-enforcement
kubectl scale deployment overrides-sync --replicas=0 -n mimir-edge-enforcement

# 2. Update service to point directly to Mimir distributor
kubectl patch service mimir-envoy -n mimir-edge-enforcement -p '{"spec":{"selector":{"app":"mimir-distributor"}}}'
```

### Phase 2: Verification (5-15 minutes)

#### 1. Health Check Verification
```bash
# Check NGINX health
curl -f http://localhost/health

# Check Mimir distributor health
curl -f http://mimir-distributor.mimir.svc.cluster.local:8080/ready

# Check application metrics
curl -f http://localhost/metrics | grep -E "(http_requests_total|http_request_duration_seconds)"
```

#### 2. Traffic Flow Verification
```bash
# Test remote write endpoint
curl -X POST http://localhost/api/v1/push \
  -H "Content-Type: application/x-protobuf" \
  -H "X-Scope-OrgID: test-tenant" \
  -d "test-data"

# Check logs for successful requests
tail -f /var/log/nginx/access.log | grep "200"
```

#### 3. Performance Verification
```bash
# Monitor response times
watch -n 5 'curl -w "@curl-format.txt" -o /dev/null -s http://localhost/api/v1/push'

# Check error rates
grep -c " 4[0-9][0-9] " /var/log/nginx/access.log
grep -c " 5[0-9][0-9] " /var/log/nginx/access.log
```

### Phase 3: Monitoring and Alerting (15+ minutes)

#### 1. Update Monitoring
```bash
# Update Prometheus targets if needed
kubectl patch servicemonitor mimir-envoy -n mimir-edge-enforcement -p '{"spec":{"selector":{"matchLabels":{"app":"mimir-distributor"}}}}'

# Check Grafana dashboards
# Verify metrics are flowing correctly
```

#### 2. Alert Verification
```bash
# Check alert manager status
kubectl get alertmanager -n monitoring

# Verify critical alerts are resolved
kubectl logs -n monitoring deployment/prometheus-operator-alertmanager
```

## Recovery Procedures

### Option 1: Gradual Re-enablement
```bash
# 1. Start with mirror mode (0% impact)
# Update NGINX configuration to mirror traffic
# Monitor for 30 minutes

# 2. Move to 1% canary
# Update split_clients to 1% Envoy, 99% Mimir
# Monitor for 1 hour

# 3. Gradually increase to 5%, 10%, 25%, 50%, 100%
# Monitor at each step for at least 30 minutes
```

### Option 2: Full Re-enablement
```bash
# 1. Verify all components are healthy
kubectl get pods -n mimir-edge-enforcement
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls

# 2. Scale up components
kubectl scale deployment mimir-envoy --replicas=1 -n mimir-edge-enforcement
kubectl scale deployment mimir-rls --replicas=1 -n mimir-edge-enforcement
kubectl scale deployment overrides-sync --replicas=1 -n mimir-edge-enforcement

# 3. Wait for readiness
kubectl wait --for=condition=ready pod -l app=mimir-envoy -n mimir-edge-enforcement --timeout=300s

# 4. Re-enable traffic routing
# Apply original NGINX configuration
```

## Post-Rollback Actions

### 1. Root Cause Analysis
- [ ] Review logs from all components
- [ ] Check configuration changes
- [ ] Analyze metrics and alerts
- [ ] Document findings

### 2. Communication
- [ ] Notify stakeholders of rollback
- [ ] Update status page
- [ ] Schedule post-mortem meeting

### 3. Prevention
- [ ] Update monitoring and alerting
- [ ] Improve testing procedures
- [ ] Document lessons learned
- [ ] Update rollback procedures

## Emergency Contacts

- **On-Call Engineer**: [Contact Information]
- **SRE Team**: [Contact Information]
- **Mimir Team**: [Contact Information]

## Useful Commands

```bash
# Check component status
kubectl get pods -n mimir-edge-enforcement
kubectl get pods -n mimir

# View logs
kubectl logs -f deployment/mimir-rls -n mimir-edge-enforcement
kubectl logs -f deployment/mimir-envoy -n mimir-edge-enforcement

# Check metrics
curl http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:9090/metrics

# Test endpoints
curl -X POST http://localhost/api/v1/push -H "X-Scope-OrgID: test" -d "test"
```

## Recovery Checklist

- [ ] Traffic flowing to Mimir distributor
- [ ] No 4xx/5xx errors in NGINX logs
- [ ] Response times within acceptable limits
- [ ] All critical alerts resolved
- [ ] Monitoring dashboards updated
- [ ] Stakeholders notified
- [ ] Post-mortem scheduled 