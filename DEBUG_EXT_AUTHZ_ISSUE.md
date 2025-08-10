# 🔍 Ext_Authz Filter Not Working - Debugging Guide

## 🚨 **Issue Identified**

Your Envoy logs show:
```
ext_authz_status="-"
ext_authz_denied="-"
ext_authz_failure_reason="-"
```

This indicates the **ext_authz filter is not executing at all**.

## 🔍 **Root Cause Analysis**

The `-` values in ext_authz metadata mean:
- **ext_authz_status="-"**: No authorization status recorded
- **ext_authz_denied="-"**: No authorization decision recorded  
- **ext_authz_failure_reason="-"**: No failure reason recorded

This suggests the ext_authz filter is **bypassed, disabled, or failing silently**.

## 🔧 **Immediate Debugging Steps**

### **Step 1: Check Envoy Configuration**
```bash
# Port forward to Envoy
kubectl port-forward -n your-namespace deployment/mimir-envoy 8080:8080

# Check debug endpoint
curl http://localhost:8080/debug

# Expected output should show:
# - Ext Authz Filter: ENABLED
# - RLS Host: mimir-rls.mimir-edge-enforcement.svc.cluster.local:8080
# - Failure Mode Allow: true
```

### **Step 2: Check RLS Cluster Health**
```bash
# Port forward to Envoy admin
kubectl port-forward -n your-namespace deployment/mimir-envoy 9901:9901

# Check cluster health
curl http://localhost:9901/clusters | grep rls_ext_authz

# Expected output:
# rls_ext_authz::default_priority::healthy::
# rls_ext_authz::default_priority::max_connections::
# rls_ext_authz::default_priority::active::

# If you see "unhealthy" or no output, RLS is not reachable
```

### **Step 3: Check Ext_Authz Stats**
```bash
# Check ext_authz statistics
curl http://localhost:9901/stats | grep ext_authz

# Look for:
# ext_authz.rls_ext_authz.grpc_call_total: X
# ext_authz.rls_ext_authz.grpc_success: X
# ext_authz.rls_ext_authz.grpc_failure: X

# If all values are 0, ext_authz is not being called
```

### **Step 4: Test RLS Connectivity**
```bash
# Test if Envoy can reach RLS
kubectl exec -it -n your-namespace deployment/mimir-envoy -- \
  curl -v http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8082/healthz

# Test gRPC connectivity (if grpcurl available)
kubectl exec -it -n your-namespace deployment/mimir-envoy -- \
  grpcurl -plaintext mimir-rls.mimir-edge-enforcement.svc.cluster.local:8080 list

# Expected output:
# envoy.service.auth.v3.Authorization
# grpc.reflection.v1alpha.ServerReflection
```

### **Step 5: Check RLS Service Status**
```bash
# Verify RLS is running
kubectl get pods -n your-namespace -l app.kubernetes.io/name=mimir-rls

# Check RLS logs for gRPC server
kubectl logs -f deployment/mimir-rls -n your-namespace | grep -E "(ext_authz|gRPC|server)"

# Expected logs:
# "ext_authz gRPC server started with health checks"
# "listening on :8080"
```

## 🚨 **Common Issues and Solutions**

### **Issue 1: RLS Service Not Running**
**Symptoms**: Cluster shows unhealthy, connection refused
**Solution**:
```bash
# Restart RLS
kubectl rollout restart deployment/mimir-rls -n your-namespace

# Check service endpoints
kubectl get endpoints -n your-namespace mimir-rls
```

### **Issue 2: Network Policy Blocking**
**Symptoms**: Connection timeout to RLS
**Solution**:
```bash
# Check network policies
kubectl get networkpolicy -n your-namespace

# Test DNS resolution
kubectl exec -it -n your-namespace deployment/mimir-envoy -- \
  nslookup mimir-rls.mimir-edge-enforcement.svc.cluster.local
```

### **Issue 3: gRPC Service Not Registered**
**Symptoms**: RLS running but gRPC calls fail
**Solution**:
```bash
# Check RLS logs for service registration
kubectl logs deployment/mimir-rls -n your-namespace | grep -E "(Register|service)"

# Expected: "Register ext_authz service"
```

### **Issue 4: Filter Configuration Error**
**Symptoms**: Filter not executing despite RLS being healthy
**Solution**:
```bash
# Check Envoy configuration
kubectl get configmap -n your-namespace mimir-envoy-config -o yaml

# Look for ext_authz filter configuration
# Verify cluster_name: rls_ext_authz is correct
```

## 🔧 **Temporary Workaround**

If you need traffic to flow while debugging:

```yaml
# In values-envoy.yaml
extAuthz:
  failureModeAllow: true  # Allow traffic when RLS is unreachable
```

## 📊 **Monitoring Commands**

```bash
# Real-time monitoring of ext_authz activity
watch -n 2 'kubectl logs --tail=5 deployment/mimir-envoy -n your-namespace | grep ENVOY_ACCESS'

# Monitor RLS for incoming requests
watch -n 2 'kubectl logs --tail=5 deployment/mimir-rls -n your-namespace | grep "Check\|ext_authz"'

# Check cluster health continuously
watch -n 5 'curl -s http://localhost:9901/clusters | grep rls_ext_authz'
```

## 🎯 **Expected Behavior After Fix**

When ext_authz is working correctly, you should see:

```
tenant="mesh"
ext_authz_status="OK"
ext_authz_denied="false"
ext_authz_failure_reason="-"
```

Or if authorization is denied:

```
tenant="mesh"
ext_authz_status="OK"
ext_authz_denied="true"
ext_authz_failure_reason="samples_rate_exceeded"
```

## 🚀 **Next Steps**

1. **Run the debugging steps above**
2. **Check RLS cluster health**
3. **Verify gRPC connectivity**
4. **Monitor logs for ext_authz activity**
5. **Share the output for further diagnosis**

The key is to identify whether RLS is reachable and whether the gRPC service is properly registered.
