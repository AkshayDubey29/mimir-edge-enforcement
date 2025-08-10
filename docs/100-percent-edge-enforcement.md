# 100% Edge Enforcement Configuration

This document explains how to configure NGINX to route 100% of traffic through the edge enforcement system instead of the current 10% canary deployment.

## 🎯 Overview

The current configuration (`examples/nginx-10-percent-canary.yaml`) routes only 10% of traffic through edge enforcement. To enforce 100% of traffic through the edge enforcement system, you need to use the new configuration (`examples/nginx-100-percent-edge.yaml`).

## 📊 Configuration Comparison

### Current Configuration (10% Canary)
```nginx
# 🎯 EDGE ENFORCEMENT CANARY: 10% traffic routing
map $request_id $canary_hash {
    default 0;
    ~.*0$ 1;   # 10% of requests (last digit is 0)
}

# Routing decision based on canary hash
map $canary_hash $route_decision {
    0 "direct";
    1 "edge";
    default "direct";
}

# Main route with conditional routing
location = /api/v1/push {
    set $target_upstream "";
    if ($route_decision = "edge") {
        set $target_upstream "mimir_via_edge_enforcement";
    }
    if ($route_decision = "direct") {
        set $target_upstream "mimir_direct";
    }
    proxy_pass http://$target_upstream$request_uri;
}
```

### New Configuration (100% Edge Enforcement)
```nginx
# 🎯 EDGE ENFORCEMENT: 100% traffic routing
map $request_id $route_decision {
    default "edge";
}

# Main route - all traffic goes through edge enforcement
location = /api/v1/push {
    # All traffic goes through edge enforcement
    proxy_pass http://mimir_via_edge_enforcement$request_uri;
}
```

## 🚀 Deployment Steps

### 1. Deploy 100% Edge Enforcement

```bash
# Run the deployment script
./scripts/deploy-100-percent-edge.sh
```

This script will:
- ✅ Validate your Kubernetes cluster
- ✅ Backup your current configuration
- ✅ Apply the new 100% edge enforcement configuration
- ✅ Verify the deployment
- ✅ Create monitoring and rollback instructions

### 2. Manual Deployment (Alternative)

```bash
# Backup current configuration
kubectl get configmap mimir-nginx -n mimir -o yaml > backup-nginx-config.yaml

# Apply new configuration
kubectl apply -f examples/nginx-100-percent-edge.yaml

# Verify deployment
kubectl get configmap mimir-nginx -n mimir
```

## 🔧 Key Changes

### 1. Traffic Routing
- **Before**: 10% edge enforcement, 90% direct to Mimir
- **After**: 100% edge enforcement, 0% direct to Mimir

### 2. Logging
- **Before**: `route=direct` or `route=edge`
- **After**: `route=edge_enforcement` (all traffic)

### 3. Headers
- **Before**: `X-Canary-Route` with varying values
- **After**: `X-Edge-Enforcement: 100%` (all traffic)

### 4. Emergency Bypass
- **Available**: `/api/v1/push/direct` for emergency rollback
- **Headers**: `X-Emergency-Bypass: true`

## 📈 Monitoring

### 1. Admin UI
After deployment, the Admin UI Overview page will show:
- **Envoy**: All requests going to RLS
- **RLS**: All decisions (allowed/denied)
- **Mimir**: Only allowed requests reaching Mimir

### 2. NGINX Logs
```bash
# Check for edge enforcement traffic
kubectl logs -n mimir -l app=nginx --tail=20 | grep "route=edge_enforcement"

# Check for emergency bypass usage
kubectl logs -n mimir -l app=nginx --tail=20 | grep "X-Emergency-Bypass"
```

### 3. Service Status
```bash
# Check RLS service
kubectl get pods -n mimir-edge-enforcement -l app.kubernetes.io/name=mimir-rls

# Check Envoy service
kubectl get pods -n mimir-edge-enforcement -l app.kubernetes.io/name=mimir-envoy
```

## 🚨 Emergency Procedures

### 1. Emergency Bypass
If edge enforcement is causing issues, you can temporarily bypass it:

```bash
# Use emergency bypass endpoint
curl -H "X-Scope-OrgID: your-tenant" \
     http://your-nginx-service/api/v1/push/direct
```

### 2. Quick Rollback
```bash
# Apply backup configuration
kubectl apply -f backup-nginx-config.yaml

# Verify rollback
kubectl get configmap mimir-nginx -n mimir -o yaml
```

### 3. Complete Rollback
```bash
# Delete current ConfigMap
kubectl delete configmap mimir-nginx -n mimir

# Recreate with original configuration
kubectl apply -f backup-nginx-config.yaml
```

## ✅ Verification Checklist

After deployment, verify:

- [ ] **NGINX ConfigMap** is updated with new configuration
- [ ] **NGINX pods** are running and healthy
- [ ] **RLS service** is receiving requests
- [ ] **Envoy service** is processing traffic
- [ ] **Admin UI** shows traffic flow metrics
- [ ] **NGINX logs** show `route=edge_enforcement`
- [ ] **Emergency bypass** endpoint works (`/api/v1/push/direct`)

## 📊 Expected Traffic Flow

### Before (10% Canary)
```
NGINX → 90% Direct → Mimir
     → 10% Edge → Envoy → RLS → Mimir
```

### After (100% Edge Enforcement)
```
NGINX → 100% Edge → Envoy → RLS → Mimir
```

## 🎯 Benefits of 100% Edge Enforcement

1. **Complete Coverage**: All traffic is rate-limited and monitored
2. **Consistent Behavior**: No traffic bypasses enforcement
3. **Better Monitoring**: Full visibility into all requests
4. **Simplified Configuration**: No complex routing logic
5. **Production Ready**: Full enforcement for production workloads

## ⚠️ Important Considerations

1. **Performance Impact**: All requests go through additional components
2. **Dependency Risk**: Edge enforcement becomes a critical dependency
3. **Monitoring Required**: Must monitor edge enforcement health
4. **Emergency Procedures**: Keep rollback procedures ready
5. **Testing**: Test thoroughly before production deployment

## 🔄 Migration Strategy

### Recommended Approach
1. **Test in Staging**: Deploy 100% edge enforcement in staging first
2. **Monitor Performance**: Check for any performance degradation
3. **Gradual Rollout**: Deploy to production during low-traffic periods
4. **Monitor Closely**: Watch for any issues in the first few hours
5. **Keep Backup**: Maintain rollback capability

### Rollback Plan
- **Immediate**: Use emergency bypass endpoint
- **Quick**: Apply backup configuration
- **Complete**: Recreate original setup

## 📞 Support

If you encounter issues:
1. Check the monitoring scripts in the backup directory
2. Review NGINX and RLS logs
3. Use emergency bypass if needed
4. Apply rollback procedures
5. Contact the edge enforcement team

---

**🎉 Congratulations!** You now have 100% edge enforcement protecting your Mimir cluster.
