# 🚨 Troubleshooting Admin UI API Connection Issues

This guide helps resolve `ERR_CONNECTION_RESET` and other API connectivity issues between the Admin UI and RLS service.

## 🎯 Common Issue: ERR_CONNECTION_RESET on /api/tenants

### 🔍 **Symptoms:**
- Admin UI shows `ERR_CONNECTION_RESET` when accessing `/tenants` page
- `/api/tenants` endpoint not responding
- Other endpoints (health, overview) might work fine
- Browser shows connection reset errors

### 🚀 **Quick Diagnosis Steps:**

#### **1. Use the Debug Script**
```bash
# Run comprehensive API tests
./scripts/debug-rls-api.sh --all

# Test just the API endpoints
./scripts/debug-rls-api.sh --test-direct

# Check RLS logs
./scripts/debug-rls-api.sh --check-logs
```

#### **2. Manual Quick Tests**
```bash
# Check if RLS pods are running
kubectl get pods -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement

# Test direct API access
kubectl port-forward svc/mimir-rls 8082:8082 -n mimir-edge-enforcement &
curl http://localhost:8082/api/tenants

# Check RLS logs
kubectl logs -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement --tail=50
```

## 🔧 **Common Causes & Solutions:**

### **Issue 1: RLS Service Not Running**

**Symptoms:**
- No RLS pods running
- Service endpoints empty

**Solution:**
```bash
# Check deployment status
kubectl get deployment mimir-rls -n mimir-edge-enforcement

# Restart if needed
kubectl rollout restart deployment/mimir-rls -n mimir-edge-enforcement

# Check logs
kubectl logs -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement
```

### **Issue 2: RLS Admin Server Not Listening**

**Symptoms:**
- Pod running but API not responding
- Connection refused on port 8082

**Solution:**
```bash
# Check if admin server is listening
kubectl exec deployment/mimir-rls -n mimir-edge-enforcement -- netstat -tlnp | grep 8082

# Check process status
kubectl exec deployment/mimir-rls -n mimir-edge-enforcement -- ps aux | grep rls

# If not listening, check startup logs
kubectl logs -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement | grep -E "(admin|8082|error)"
```

### **Issue 3: Service/Ingress Misconfiguration**

**Symptoms:**
- Direct pod access works
- Service/Ingress access fails

**Solution:**
```bash
# Check service configuration
kubectl get service mimir-rls -n mimir-edge-enforcement -o yaml

# Verify service endpoints
kubectl get endpoints mimir-rls -n mimir-edge-enforcement

# Test service connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -qO- http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8082/api/tenants
```

### **Issue 4: Admin UI NGINX Proxy Issues**

**Symptoms:**
- Direct RLS access works
- Admin UI proxy returns 502/503

**Solution:**
```bash
# Check Admin UI logs
kubectl logs -l app.kubernetes.io/name=admin-ui -n mimir-edge-enforcement

# Verify NGINX configuration
kubectl exec deployment/mimir-admin -n mimir-edge-enforcement -- cat /etc/nginx/nginx.conf | grep -A 10 "/api"

# Test Admin UI to RLS connectivity
kubectl exec deployment/mimir-admin -n mimir-edge-enforcement -- wget -qO- http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8082/api/tenants
```

### **Issue 5: Resource Exhaustion**

**Symptoms:**
- Intermittent connection resets
- High memory/CPU usage

**Solution:**
```bash
# Check resource usage
kubectl top pod -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement

# Check for OOMKilled pods
kubectl get events -n mimir-edge-enforcement | grep -E "(OOMKilled|Evicted)"

# Increase resource limits if needed
kubectl patch deployment mimir-rls -n mimir-edge-enforcement -p '{"spec":{"template":{"spec":{"containers":[{"name":"rls","resources":{"limits":{"memory":"2Gi","cpu":"1000m"}}}]}}}}'
```

### **Issue 6: No Tenants Data**

**Symptoms:**
- API responds but returns empty tenant list
- `tenant_count: 0` in logs

**Solution:**
```bash
# Check if overrides-sync is working
kubectl logs -l app.kubernetes.io/name=overrides-sync -n mimir-edge-enforcement --tail=20

# Verify Mimir ConfigMap exists
kubectl get configmap mimir-overrides -n mimir -o yaml

# Check overrides-sync parsing
kubectl logs -l app.kubernetes.io/name=overrides-sync -n mimir-edge-enforcement | grep -E "(tenant|parsing|sync)"

# Restart overrides-sync if needed
kubectl rollout restart deployment/overrides-sync -n mimir-edge-enforcement
```

## 🛠️ **Advanced Debugging:**

### **Network Connectivity Test**
```bash
# Test pod-to-pod connectivity
kubectl exec deployment/mimir-admin -n mimir-edge-enforcement -- nc -zv mimir-rls.mimir-edge-enforcement.svc.cluster.local 8082

# Test DNS resolution
kubectl exec deployment/mimir-admin -n mimir-edge-enforcement -- nslookup mimir-rls.mimir-edge-enforcement.svc.cluster.local

# Check network policies
kubectl get networkpolicy -n mimir-edge-enforcement
```

### **Enable Debug Logging**
```bash
# Enable debug logging in RLS
kubectl patch deployment mimir-rls -n mimir-edge-enforcement -p '{"spec":{"template":{"spec":{"containers":[{"name":"rls","args":["--log-level=debug"]}]}}}}'

# Watch debug logs
kubectl logs -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement -f | grep -E "(debug|api|tenants)"
```

### **Manual API Testing**
```bash
# Start comprehensive port-forward session
kubectl port-forward svc/mimir-rls 8082:8082 -n mimir-edge-enforcement &

# Test all endpoints
echo "=== Health Check ==="
curl -v http://localhost:8082/healthz

echo "=== API Health ==="
curl -v http://localhost:8082/api/health

echo "=== API Overview ==="
curl -v http://localhost:8082/api/overview

echo "=== API Tenants ==="
curl -v http://localhost:8082/api/tenants

echo "=== API Denials ==="
curl -v http://localhost:8082/api/denials
```

## 🎯 **Expected Working State:**

### **Healthy RLS Response:**
```json
# GET /api/tenants
{
  "tenants": [
    {
      "id": "tenant-production",
      "name": "tenant-production", 
      "limits": {
        "samples_per_second": 350000,
        "burst_percent": 0.2,
        "max_body_bytes": 4194304
      },
      "enforcement": {
        "enabled": true
      },
      "metrics": {
        "allow_rate": 1500.5,
        "deny_rate": 25.2,
        "utilization_pct": 85.3
      }
    }
  ]
}
```

### **Healthy Admin UI Access:**
```bash
# Should return tenant data without errors
curl https://mimir-edge-enforcement.vzonel.kr.couwatchdev.net/api/tenants

# Browser access should work
open https://mimir-edge-enforcement.vzonel.kr.couwatchdev.net/tenants
```

## 🚨 **Emergency Recovery:**

### **Quick Restart All Components**
```bash
# Restart all components
kubectl rollout restart deployment/mimir-rls -n mimir-edge-enforcement
kubectl rollout restart deployment/overrides-sync -n mimir-edge-enforcement  
kubectl rollout restart deployment/mimir-admin -n mimir-edge-enforcement

# Wait for all to be ready
kubectl wait --for=condition=available --timeout=300s deployment/mimir-rls -n mimir-edge-enforcement
kubectl wait --for=condition=available --timeout=300s deployment/overrides-sync -n mimir-edge-enforcement
kubectl wait --for=condition=available --timeout=300s deployment/mimir-admin -n mimir-edge-enforcement
```

### **Reset to Known Good State**
```bash
# Scale down and up
kubectl scale deployment/mimir-rls --replicas=0 -n mimir-edge-enforcement
sleep 10
kubectl scale deployment/mimir-rls --replicas=3 -n mimir-edge-enforcement

# Verify health
kubectl get pods -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement
./scripts/debug-rls-api.sh --test-direct
```

## 📋 **Prevention:**

1. **Monitor Resource Usage**: Set up alerts for memory/CPU usage
2. **Health Checks**: Implement proper liveness/readiness probes
3. **Logging**: Keep debug logging enabled during initial deployment
4. **Testing**: Regularly test API endpoints
5. **Documentation**: Keep troubleshooting logs for pattern analysis

---

**Most Common Resolution:** The issue is usually related to RLS service not being properly started or the overrides-sync not populating tenant data. Run the debug script first, then check the specific service logs! 🎯
