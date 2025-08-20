# Deployment Strategy - Mimir Edge Enforcement

## Overview

The Mimir Edge Enforcement system is designed for zero-risk deployment with comprehensive rollback capabilities. The deployment strategy follows a phased approach that ensures minimal impact on existing services while providing full validation and monitoring capabilities.

## Deployment Phases

### Phase 1: Mirror Mode (Zero Impact)

#### Objective
Deploy the system in shadow mode to validate functionality and collect baseline metrics without any impact on production traffic.

#### Architecture
```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Phase 1: Mirror Mode                              │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │   Alloy     │───▶│   NGINX     │───▶│   Mimir     │    │             │     │
│  │  (Client)   │    │  (Proxy)    │    │Distributor  │    │             │     │
│  └─────────────┘    └─────────────┘    └─────────────┘    │             │     │
│                           │                                │             │     │
│                           ▼                                │             │     │
│                    ┌─────────────┐                        │             │     │
│                    │   Mirror    │                        │             │     │
│                    │   Traffic   │                        │             │     │
│                    └─────────────┘                        │             │     │
│                           │                                │             │     │
│                           ▼                                │             │     │
│                    ┌─────────────┐    ┌─────────────┐    │             │     │
│                    │   Envoy     │───▶│   RLS       │    │             │     │
│                    │ (Shadow)    │    │(Shadow)     │    │             │     │
│                    └─────────────┘    └─────────────┘    │             │     │
│                                                           │             │     │
└─────────────────────────────────────────────────────────────────────────────────┘
```

#### NGINX Configuration
```nginx
# nginx-mirror.conf
upstream mimir_direct {
    server distributor.mimir.svc.cluster.local:8080;
}

upstream mimirrls {
    server mimirrls.mimir-edge-enforcement.svc.cluster.local:8080;
}

server {
    listen 80;
    
    # Main traffic - direct to Mimir
    location /api/v1/push {
        proxy_pass http://mimir_direct;
        
        # Mirror traffic to Envoy (shadow mode)
        mirror /mirror;
        mirror_request_body on;
    }
    
    # Mirror endpoint - traffic goes to Envoy but response is ignored
    location = /mirror {
        internal;
        proxy_pass http://mimirrls;
        proxy_pass_request_body on;
        proxy_set_header Content-Length "";
        proxy_set_header X-Original-URI $request_uri;
        
        # Ignore response from mirror
        proxy_ignore_client_abort on;
        proxy_ignore_headers X-Accel-*;
    }
}
```

#### Deployment Steps
```bash
# 1. Deploy RLS service
helm install mimir-rls charts/mimir-rls/ \
  --namespace mimir-edge-enforcement \
  --set rls.replicas=3 \
  --set rls.config.failureModeAllow=true

# 2. Deploy Envoy proxy
helm install mimir-envoy charts/envoy/ \
  --namespace mimir-edge-enforcement \
  --set envoy.replicas=3

# 3. Deploy overrides-sync controller
helm install overrides-sync charts/overrides-sync/ \
  --namespace mimir-edge-enforcement

# 4. Apply NGINX mirror configuration
kubectl apply -f examples/nginx-mirror.yaml

# 5. Verify deployment
kubectl get pods -n mimir-edge-enforcement
kubectl logs -f deployment/mimir-rls -n mimir-edge-enforcement
```

#### Validation Criteria
- [ ] All pods are running and healthy
- [ ] RLS service is receiving mirrored traffic
- [ ] No impact on existing Mimir traffic
- [ ] Metrics are being collected
- [ ] Admin UI is accessible and showing data

#### Success Metrics
- **Zero Impact**: 100% of requests reach Mimir distributor
- **Shadow Traffic**: RLS receives mirrored requests
- **System Health**: All components healthy
- **Metrics Collection**: Prometheus metrics populated

### Phase 2: Canary Mode (Gradual Rollout)

#### Objective
Gradually shift traffic from direct Mimir access to Envoy enforcement, starting with a small percentage and monitoring closely.

#### Architecture
```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Phase 2: Canary Mode                              │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │   Alloy     │───▶│   NGINX     │───▶│   Envoy     │───▶│   Mimir     │     │
│  │  (Client)   │    │  (Proxy)    │    │ (Canary)    │    │Distributor  │     │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘     │
│                           │                   │                                │
│                           ▼                   ▼                                │
│                    ┌─────────────┐    ┌─────────────┐                         │
│                    │   RLS       │    │   RLS       │                         │
│                    │(Canary)     │    │(Canary)     │                         │
│                    └─────────────┘    └─────────────┘                         │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

#### NGINX Configuration (10% Canary)
```nginx
# nginx-canary-10.conf
upstream mimir_direct {
    server distributor.mimir.svc.cluster.local:8080;
}

upstream mimirrls {
    server mimirrls.mimir-edge-enforcement.svc.cluster.local:8080;
}

# Split traffic based on request ID hash
split_clients "${request_id}" $backend {
    10%     mimirrls;
    *       mimir_direct;
}

server {
    listen 80;
    
    location /api/v1/push {
        proxy_pass http://$backend;
        
        # Add headers for tracking
        add_header X-Edge-Enforcement $backend;
        add_header X-Canary-Percentage "10%";
    }
}
```

#### Deployment Steps
```bash
# 1. Scale up RLS service for canary traffic
helm upgrade mimir-rls charts/mimir-rls/ \
  --namespace mimir-edge-enforcement \
  --set rls.replicas=5 \
  --set rls.config.failureModeAllow=false

# 2. Scale up Envoy proxy
helm upgrade mimir-envoy charts/envoy/ \
  --namespace mimir-edge-enforcement \
  --set envoy.replicas=5

# 3. Apply canary NGINX configuration
kubectl apply -f examples/nginx-canary-10.yaml

# 4. Monitor canary traffic
kubectl logs -f deployment/mimir-rls -n mimir-edge-enforcement | grep "canary"
```

#### Canary Progression
```bash
# 10% canary
kubectl apply -f examples/nginx-canary-10.yaml

# 25% canary
kubectl apply -f examples/nginx-canary-25.yaml

# 50% canary
kubectl apply -f examples/nginx-canary-50.yaml

# 75% canary
kubectl apply -f examples/nginx-canary-75.yaml

# 100% canary
kubectl apply -f examples/nginx-canary-100.yaml
```

#### Validation Criteria
- [ ] Canary traffic is being routed correctly
- [ ] Error rates are within acceptable limits
- [ ] Latency impact is minimal
- [ ] All tenants are being enforced
- [ ] Rollback capability is tested

#### Success Metrics
- **Error Rate**: <0.1% error rate for canary traffic
- **Latency Impact**: <10ms additional latency
- **Throughput**: No degradation in request processing
- **Enforcement**: All tenant limits being enforced correctly

### Phase 3: Full Mode (Complete Deployment)

#### Objective
Deploy the system in full enforcement mode with all traffic going through Envoy and RLS.

#### Architecture
```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Phase 3: Full Mode                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │   Alloy     │───▶│   NGINX     │───▶│   Envoy     │───▶│   Mimir     │     │
│  │  (Client)   │    │  (Proxy)    │    │ (Full)      │    │Distributor  │     │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘     │
│                           │                   │                                │
│                           ▼                   ▼                                │
│                    ┌─────────────┐    ┌─────────────┐                         │
│                    │   RLS       │    │   RLS       │                         │
│                    │(Full)       │    │(Full)       │                         │
│                    └─────────────┘    └─────────────┘                         │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

#### NGINX Configuration (Full Mode)
```nginx
# nginx-full.conf
upstream mimirrls {
    server mimirrls.mimir-edge-enforcement.svc.cluster.local:8080;
}

server {
    listen 80;
    
    location /api/v1/push {
        proxy_pass http://mimirrls;
        
        # Add headers for tracking
        add_header X-Edge-Enforcement "full";
        add_header X-Deployment-Mode "production";
    }
}
```

#### Deployment Steps
```bash
# 1. Scale to production capacity
helm upgrade mimir-rls charts/mimir-rls/ \
  --namespace mimir-edge-enforcement \
  --set rls.replicas=10 \
  --set rls.config.failureModeAllow=false \
  --set rls.resources.requests.memory=8Gi \
  --set rls.resources.requests.cpu=1000m

# 2. Scale Envoy to production capacity
helm upgrade mimir-envoy charts/envoy/ \
  --namespace mimir-edge-enforcement \
  --set envoy.replicas=10 \
  --set envoy.resources.requests.memory=4Gi \
  --set envoy.resources.requests.cpu=500m

# 3. Apply full NGINX configuration
kubectl apply -f examples/nginx-full.yaml

# 4. Enable HPA for auto-scaling
kubectl apply -f examples/hpa-rls.yaml
kubectl apply -f examples/hpa-envoy.yaml
```

#### Validation Criteria
- [ ] All traffic is going through Envoy
- [ ] All tenant limits are being enforced
- [ ] System performance is stable
- [ ] Monitoring and alerting are working
- [ ] Rollback procedures are documented and tested

#### Success Metrics
- **Full Enforcement**: 100% of traffic through Envoy
- **System Stability**: 99.9% uptime
- **Performance**: <10ms latency impact
- **Compliance**: All tenant limits enforced

## Rollback Procedures

### Emergency Rollback (5 Minutes)

#### Quick Rollback
```bash
# 1. Revert NGINX configuration to direct Mimir access
kubectl apply -f examples/nginx-direct.yaml

# 2. Verify traffic is flowing directly to Mimir
kubectl logs -f deployment/nginx-ingress -n ingress-nginx

# 3. Scale down enforcement components
kubectl scale deployment mimir-rls --replicas=0 -n mimir-edge-enforcement
kubectl scale deployment mimir-envoy --replicas=0 -n mimir-edge-enforcement
```

#### NGINX Direct Configuration
```nginx
# nginx-direct.yaml
upstream mimir_direct {
    server distributor.mimir.svc.cluster.local:8080;
}

server {
    listen 80;
    
    location /api/v1/push {
        proxy_pass http://mimir_direct;
        
        # Add header indicating direct access
        add_header X-Edge-Enforcement "disabled";
        add_header X-Rollback "emergency";
    }
}
```

### Graceful Rollback (30 Minutes)

#### Step-by-Step Rollback
```bash
# 1. Reduce canary percentage gradually
kubectl apply -f examples/nginx-canary-50.yaml
sleep 300  # Wait 5 minutes

kubectl apply -f examples/nginx-canary-25.yaml
sleep 300  # Wait 5 minutes

kubectl apply -f examples/nginx-canary-10.yaml
sleep 300  # Wait 5 minutes

# 2. Switch to mirror mode
kubectl apply -f examples/nginx-mirror.yaml

# 3. Scale down enforcement components
kubectl scale deployment mimir-rls --replicas=3 -n mimir-edge-enforcement
kubectl scale deployment mimir-envoy --replicas=3 -n mimir-edge-enforcement

# 4. Disable enforcement
kubectl patch deployment mimir-rls -p '{"spec":{"template":{"spec":{"containers":[{"name":"rls","env":[{"name":"ENFORCEMENT_DISABLED","value":"true"}]}]}}}}'
```

## Monitoring and Validation

### Pre-Deployment Checks

#### Infrastructure Validation
```bash
# Check cluster resources
kubectl get nodes -o custom-columns="NAME:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory"

# Check namespace resources
kubectl get pods -n mimir-edge-enforcement -o wide

# Check network connectivity
kubectl run test-pod --image=busybox --rm -it --restart=Never -- nslookup mimirrls.mimir-edge-enforcement.svc.cluster.local
```

#### Configuration Validation
```bash
# Validate Helm charts
helm lint charts/mimir-rls/
helm lint charts/envoy/
helm lint charts/overrides-sync/

# Dry run deployment
helm install mimir-rls charts/mimir-rls/ --dry-run --debug

# Validate ConfigMaps
kubectl get configmap mimir-overrides -n mimir -o yaml
```

### Post-Deployment Validation

#### Health Checks
```bash
# Check pod health
kubectl get pods -n mimir-edge-enforcement

# Check service health
kubectl get svc -n mimir-edge-enforcement

# Check endpoints
kubectl get endpoints -n mimir-edge-enforcement

# Check logs
kubectl logs -f deployment/mimir-rls -n mimir-edge-enforcement
kubectl logs -f deployment/mimir-envoy -n mimir-edge-enforcement
```

#### Performance Validation
```bash
# Check resource usage
kubectl top pods -n mimir-edge-enforcement

# Check metrics
curl http://localhost:9090/metrics | grep rls_

# Check API endpoints
curl http://localhost:8082/api/health
curl http://localhost:8082/api/overview
```

#### Traffic Validation
```bash
# Check NGINX logs
kubectl logs -f deployment/nginx-ingress -n ingress-nginx | grep "api/v1/push"

# Check Envoy logs
kubectl logs -f deployment/mimir-envoy -n mimir-edge-enforcement

# Check RLS logs
kubectl logs -f deployment/mimir-rls -n mimir-edge-enforcement | grep "decision"
```

## Configuration Management

### Environment-Specific Configurations

#### Development Environment
```yaml
# values-dev.yaml
global:
  environment: development

rls:
  replicas: 1
  config:
    maxRequestBytes: 10485760  # 10MB
    failureModeAllow: true
  resources:
    requests:
      memory: 1Gi
      cpu: 100m
    limits:
      memory: 2Gi
      cpu: 200m

envoy:
  replicas: 1
  resources:
    requests:
      memory: 512Mi
      cpu: 50m
    limits:
      memory: 1Gi
      cpu: 100m
```

#### Staging Environment
```yaml
# values-staging.yaml
global:
  environment: staging

rls:
  replicas: 3
  config:
    maxRequestBytes: 52428800  # 50MB
    failureModeAllow: false
  resources:
    requests:
      memory: 4Gi
      cpu: 500m
    limits:
      memory: 8Gi
      cpu: 1000m

envoy:
  replicas: 3
  resources:
    requests:
      memory: 2Gi
      cpu: 250m
    limits:
      memory: 4Gi
      cpu: 500m
```

#### Production Environment
```yaml
# values-production.yaml
global:
  environment: production

rls:
  replicas: 10
  config:
    maxRequestBytes: 52428800  # 50MB
    failureModeAllow: false
  resources:
    requests:
      memory: 8Gi
      cpu: 1000m
    limits:
      memory: 16Gi
      cpu: 4000m

envoy:
  replicas: 10
  resources:
    requests:
      memory: 4Gi
      cpu: 500m
    limits:
      memory: 8Gi
      cpu: 2000m
```

### Deployment Commands

#### Development Deployment
```bash
# Deploy to development
helm install mimir-edge-enforcement charts/ \
  --namespace mimir-edge-enforcement \
  -f values-dev.yaml \
  --set global.environment=development
```

#### Staging Deployment
```bash
# Deploy to staging
helm install mimir-edge-enforcement charts/ \
  --namespace mimir-edge-enforcement \
  -f values-staging.yaml \
  --set global.environment=staging
```

#### Production Deployment
```bash
# Deploy to production
helm install mimir-edge-enforcement charts/ \
  --namespace mimir-edge-enforcement \
  -f values-production.yaml \
  --set global.environment=production
```

## Risk Mitigation

### Technical Risks

#### Service Failure
- **Risk**: RLS or Envoy service failure
- **Mitigation**: Configurable failure modes (allow/deny)
- **Monitoring**: Health checks and alerting
- **Recovery**: Automatic restart via Kubernetes

#### Performance Impact
- **Risk**: High latency or throughput degradation
- **Mitigation**: Comprehensive load testing
- **Monitoring**: Real-time performance metrics
- **Recovery**: Auto-scaling and rollback procedures

#### Configuration Errors
- **Risk**: Incorrect tenant limits or enforcement rules
- **Mitigation**: Configuration validation
- **Monitoring**: Configuration drift detection
- **Recovery**: ConfigMap sync and validation

### Operational Risks

#### Deployment Issues
- **Risk**: Failed deployment or configuration
- **Mitigation**: Gradual rollout with rollback capability
- **Monitoring**: Deployment status and health checks
- **Recovery**: Instant rollback procedures

#### Monitoring Gaps
- **Risk**: Insufficient monitoring or alerting
- **Mitigation**: Comprehensive observability
- **Monitoring**: Multi-level monitoring and alerting
- **Recovery**: Manual intervention procedures

#### Security Concerns
- **Risk**: Security vulnerabilities or data exposure
- **Mitigation**: Security hardening and RBAC
- **Monitoring**: Security scanning and audit logs
- **Recovery**: Security incident response procedures

## Success Criteria

### Phase 1 Success Criteria
- [ ] Zero impact on existing Mimir traffic
- [ ] RLS service receiving and processing mirrored traffic
- [ ] All metrics and monitoring working correctly
- [ ] Admin UI accessible and functional

### Phase 2 Success Criteria
- [ ] Canary traffic being processed correctly
- [ ] Error rates within acceptable limits (<0.1%)
- [ ] Latency impact minimal (<10ms)
- [ ] Rollback procedures tested and working

### Phase 3 Success Criteria
- [ ] All traffic going through enforcement
- [ ] System performance stable and acceptable
- [ ] All tenant limits being enforced correctly
- [ ] Monitoring and alerting fully operational

## Conclusion

The deployment strategy provides a comprehensive, risk-mitigated approach to deploying the Mimir Edge Enforcement system. The phased approach ensures minimal impact on existing services while providing full validation and monitoring capabilities.

The rollback procedures ensure that any issues can be quickly addressed, while the monitoring and validation procedures provide confidence in the deployment process. The configuration management approach supports multiple environments and ensures consistent deployments across development, staging, and production.

---

**Next Steps**: Review component-specific deployment guides and monitoring setup procedures.
