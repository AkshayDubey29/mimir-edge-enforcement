# 🚀 NGINX Canary Setup for Mimir Edge Enforcement

This guide shows how to implement **safe canary rollout** of Mimir edge enforcement using your existing NGINX configuration.

## 🎯 Architecture Overview

```
┌─────────────┐    ┌─────────────┐    ┌──────────────────┐    ┌─────────────┐
│    Alloy    │───▶│    NGINX    │───▶│ Canary Decision  │───▶│   Mimir     │
│  (Metrics)  │    │   Gateway   │    │                  │    │Distributor  │
└─────────────┘    └─────────────┘    └──────────────────┘    └─────────────┘
                                               │
                                               ▼
                                      ┌──────────────────┐    
                                      │ Mimir-Envoy      │    
                                      │ (Edge Enforce)   │    
                                      └──────────────────┘    
                                               │
                                               ▼
                                      ┌──────────────────┐
                                      │   Mimir RLS      │
                                      │ (Rate Limiting)  │
                                      └──────────────────┘
```

## 🔧 Implementation Steps

### 1. **Deploy Mimir Edge Enforcement**
First, ensure your edge enforcement is deployed:
```bash
# Deploy the complete system
./scripts/deploy-complete.sh production

# Verify all components are running
kubectl get pods -n mimir-edge-enforcement
```

### 2. **Update NGINX Configuration**
Replace your current NGINX ConfigMap with the canary-enabled version:

```bash
# Backup current config
kubectl get configmap mimir-nginx -n mimir -o yaml > backup-nginx-config.yaml

# Apply canary configuration
kubectl apply -f examples/nginx-with-canary.yaml

# Restart NGINX to pick up new config
kubectl rollout restart deployment/mimir-nginx -n mimir
```

### 3. **Start with Shadow Testing**
Begin with **mirror mode** to test without affecting production traffic:

```bash
# Enable shadow/mirror mode
./scripts/manage-canary.sh mirror

# Check status
./scripts/manage-canary.sh status

# Monitor logs
kubectl logs -l app=mimir-nginx -n mimir --tail=100 -f | grep 'X-Mirror-Request'
```

### 4. **Gradual Canary Rollout**
Once shadow testing passes, begin the gradual rollout:

```bash
# Start with 10% canary traffic
./scripts/manage-canary.sh set 10

# Monitor for 15-30 minutes, check metrics
kubectl logs -l app=mimir-envoy -n mimir-edge-enforcement --tail=100

# If stable, increase gradually
./scripts/manage-canary.sh set 25
./scripts/manage-canary.sh set 50
./scripts/manage-canary.sh set 75
./scripts/manage-canary.sh set 100  # Full rollout
```

## 🎛️ Canary Control Commands

### **Traffic Management**
```bash
# Check current status
./scripts/manage-canary.sh status

# Set specific percentage (0-100%)
./scripts/manage-canary.sh set 10    # 10% through edge enforcement
./scripts/manage-canary.sh set 50    # 50% through edge enforcement  
./scripts/manage-canary.sh set 100   # 100% through edge enforcement

# Emergency controls
./scripts/manage-canary.sh bypass    # Emergency bypass (0%)
./scripts/manage-canary.sh rollback  # Same as bypass
```

### **Shadow Testing**
```bash
# Enable shadow mode (non-blocking)
./scripts/manage-canary.sh mirror

# Disable shadow mode
./scripts/manage-canary.sh unmirror
```

## 📊 Monitoring & Observability

### **NGINX Access Logs**
Monitor canary routing decisions:
```bash
# Watch canary routing
kubectl logs -l app=mimir-nginx -n mimir --tail=100 -f | grep 'X-Canary-Route'

# Check mirror requests
kubectl logs -l app=mimir-nginx -n mimir --tail=100 -f | grep 'X-Mirror-Request'
```

### **Edge Enforcement Metrics**
```bash
# RLS metrics
kubectl port-forward -n mimir-edge-enforcement svc/mimir-rls 8081:8081
curl http://localhost:8081/metrics | grep -E "(tenant_requests|rate_limit|denied)"

# Envoy metrics  
kubectl port-forward -n mimir-edge-enforcement svc/mimir-envoy 8001:8001
curl http://localhost:8001/stats | grep -E "(ext_authz|ratelimit)"
```

### **Key Metrics to Watch**
- **RLS**: `tenant_requests_total`, `rate_limit_decisions_total`, `denied_requests_total`
- **Envoy**: `ext_authz.allowed`, `ext_authz.denied`, `ratelimit.ok`, `ratelimit.over_limit`
- **NGINX**: Response times, error rates, upstream status

## 🚨 Emergency Procedures

### **Instant Rollback**
If issues are detected:
```bash
# Emergency bypass - all traffic goes direct to Mimir
./scripts/manage-canary.sh bypass

# Alternative: Use emergency endpoint
curl -X POST https://your-mimir-endpoint/api/v1/push/direct \
  -H "Authorization: Basic $(echo -n 'user:pass' | base64)" \
  -d @metrics.txt
```

### **Health Checks**
```bash
# Check edge enforcement health
kubectl get pods -n mimir-edge-enforcement
curl http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8080/health
curl http://mimir-envoy.mimir-edge-enforcement.svc.cluster.local:8001/ready

# Check Mimir distributor health
curl http://distributor.mimir.svc.cluster.local:8080/ready
```

## 🔍 Traffic Flow Details

### **Canary Traffic (X% through Edge Enforcement)**
```
Request → NGINX → if (canary decision) → Envoy → RLS Check → Mimir Distributor
                                              ↓
                                         Rate Limit Applied
```

### **Direct Traffic ((100-X)% direct)**
```
Request → NGINX → Mimir Distributor (original path)
```

### **Mirror Traffic (shadow testing)**
```
Request → NGINX → Mimir Distributor (original path)
                ↓
          (copy) → Envoy → RLS Check (results ignored)
```

## 📋 Configuration Options

### **Canary Weight Patterns**
The canary decision is based on request ID patterns:

- **0%**: `~.{100,}$` (never matches)
- **10%**: `~.{0,}0$` (last digit is 0)
- **50%**: `~.{0,}[02468]$` (last digit is even)
- **100%**: `~.*` (always matches)

### **Upstream Configuration**
```nginx
upstream mimir_direct {
    server distributor.mimir.svc.cluster.local:8080;
}

upstream mimir_via_edge_enforcement {
    server mimir-envoy.mimir-edge-enforcement.svc.cluster.local:8080;
}
```

## 🎯 Best Practices

### **Rollout Strategy**
1. **Deploy edge enforcement** (RLS + Envoy + Overrides-sync)
2. **Enable mirror mode** (shadow testing)
3. **Monitor shadow traffic** for 24 hours
4. **Start canary at 10%** if shadow testing passes
5. **Increase gradually**: 10% → 25% → 50% → 75% → 100%
6. **Monitor each step** for 30+ minutes before increasing
7. **Have rollback plan** ready at each step

### **Monitoring Checklist**
- ✅ Response latency unchanged
- ✅ Error rates stable
- ✅ Rate limits working correctly
- ✅ Tenant limits from ConfigMap applied
- ✅ No memory/CPU spikes in edge enforcement
- ✅ Mimir distributor load unchanged

### **Safety Measures**
- **Emergency bypass endpoint**: `/api/v1/push/direct`
- **Automatic failover**: RLS failure → allow traffic through
- **Resource limits**: Prevent resource exhaustion
- **Health checks**: Continuous monitoring
- **Instant rollback**: Single command restoration

This setup gives you **zero-downtime deployment** with **instant rollback capability** while maintaining full observability! 🚀
