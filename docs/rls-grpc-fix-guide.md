# 🔧 RLS gRPC Connectivity Fix Guide

## 🎯 Problem: `RLS gRPC (port 8080): NOT_REACHABLE`

**Root Cause**: The RLS service deployment was using an old Docker image that lacked gRPC health check implementations, causing Envoy's `ext_authz` filter to fail when trying to connect to RLS.

## 🔧 Complete Solution Implemented

### 1. **Code Fixes Applied** ✅

#### **RLS Service Enhancement (`services/rls/cmd/rls/main.go`)**
- ✅ **Added gRPC health check services** for both `ext_authz` and `rate_limit` servers
- ✅ **Implemented graceful shutdown** handling for all gRPC servers
- ✅ **Enhanced startup logging** with port validation and status messages
- ✅ **Added startup delay** to ensure proper service initialization
- ✅ **Improved error handling** (Error vs Fatal for better resilience)

#### **Envoy Configuration Updates (`charts/envoy/templates/configmap.yaml`)**
- ✅ **Updated health checks** from HTTP to gRPC for RLS clusters
- ✅ **Configured proper service names** for gRPC health validation:
  - `ext_authz`: `envoy.service.auth.v3.Authorization`
  - `rate_limit`: `envoy.service.ratelimit.v3.RateLimitService`
- ✅ **Increased timeouts** for stability (3s timeout, 10s interval)

### 2. **Deployment Scripts Created** ✅

- ✅ `scripts/diagnose-rls-deployment.sh` - Comprehensive RLS deployment diagnostics
- ✅ `scripts/validate-rls-startup.sh` - gRPC health check validation
- ✅ `scripts/update-rls-with-fixes.sh` - Automated deployment update with new image
- ✅ `scripts/restart-rls-deployment.sh` - Quick restart to pick up latest image

## 🚀 Deployment Steps

### **Step 1: Check GitHub Actions Build Status**
```bash
# Visit: https://github.com/AkshayDubey29/mimir-edge-enforcement/actions
# Wait for the "docker-build" job to complete (5-10 minutes)
```

### **Step 2: Apply the Fixes (Choose One)**

#### **Option A: Automated Update (Recommended)**
```bash
./scripts/update-rls-with-fixes.sh
```

#### **Option B: Quick Restart (if latest image has fixes)**
```bash
./scripts/restart-rls-deployment.sh
```

#### **Option C: Manual Helm Update**
```bash
# Check current commit SHA
COMMIT_SHA=$(git rev-parse HEAD)

# Update to specific commit image
helm upgrade mimir-rls charts/mimir-rls \
  --namespace mimir-edge-enforcement \
  --set image.tag=$COMMIT_SHA \
  --wait --timeout=300s

# OR update to latest
helm upgrade mimir-rls charts/mimir-rls \
  --namespace mimir-edge-enforcement \
  --set image.tag=latest \
  --wait --timeout=300s
```

### **Step 3: Validate the Fix**
```bash
# Run comprehensive validation
./scripts/validate-rls-startup.sh

# Check for gRPC startup messages
kubectl logs -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement | grep "gRPC server started"
```

### **Step 4: Test Connectivity**
```bash
# From Admin UI diagnostics (should now show REACHABLE)
./scripts/admin-ui-debug-envoy.sh
```

## ✅ Expected Results After Fix

### **Before (Broken):**
```
RLS gRPC (port 8080): NOT_REACHABLE
RLS HTTP (port 8082): REACHABLE  
Envoy logs: Only /ready requests
/api/v1/push: 403/503 errors
```

### **After (Fixed):**
```
RLS gRPC (port 8080): REACHABLE       ← FIXED!
RLS HTTP (port 8082): REACHABLE  
Envoy logs: /api/v1/push requests     ← TRAFFIC FLOWS!
/api/v1/push: 200 OK responses       ← SUCCESS!
```

## 🔍 Validation Checklist

- [ ] **GitHub Actions build completed** (green checkmark)
- [ ] **RLS pod restarted** with new image
- [ ] **2x "gRPC server started" log messages** (ext_authz + rate_limit)
- [ ] **gRPC connectivity test passes** from Admin UI
- [ ] **Envoy cluster health shows RLS as healthy**
- [ ] **/api/v1/push requests appear in Envoy logs**
- [ ] **Admin UI shows traffic flow metrics > 0**

## 🔧 Troubleshooting

### **Issue: Still seeing NOT_REACHABLE**
```bash
# 1. Check if new image is deployed
kubectl describe pod -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement | grep Image

# 2. Check pod logs for gRPC startup
kubectl logs -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement | grep -E "(gRPC|health|started)"

# 3. Force restart with latest image
./scripts/restart-rls-deployment.sh
```

### **Issue: GitHub Actions build failed**
```bash
# Manual build and deployment
cd services/rls
docker build -t temp-rls-fix .
# Use manual deployment process
```

### **Issue: Health checks still failing**
```bash
# Check Envoy configuration
kubectl get configmap mimir-envoy -n mimir-edge-enforcement -o yaml | grep -A 10 health_checks

# Restart Envoy after RLS fix
kubectl rollout restart deployment/mimir-envoy -n mimir-edge-enforcement
```

## 🎯 Technical Details

### **What the gRPC Health Checks Provide**
1. **Service Discovery Validation** - Envoy can verify RLS is ready to accept requests
2. **Circuit Breaker Integration** - Envoy marks unhealthy services as down
3. **Load Balancing** - Only healthy RLS instances receive traffic
4. **Debugging Visibility** - Clear health status in Envoy admin interface

### **gRPC Health Check Service Names**
- **ext_authz**: `envoy.service.auth.v3.Authorization`
- **rate_limit**: `envoy.service.ratelimit.v3.RateLimitService`

These match the exact gRPC service interfaces that Envoy expects to call.

## 🎉 Success Indicators

When the fix is working correctly, you should see:

1. **RLS Logs:**
   ```
   ext_authz gRPC server started with health checks
   ratelimit gRPC server started with health checks
   RLS service started - all components initialized
   ```

2. **Envoy Logs:**
   ```
   POST /api/v1/push HTTP/2.0" 200
   ext_authz filter: response_code=OK
   ```

3. **Admin UI:**
   - Traffic flow metrics > 0
   - Connectivity tests show REACHABLE
   - Pipeline status shows active requests

---

**The core issue was that Envoy couldn't validate RLS service health, causing all `ext_authz` requests to fail. With proper gRPC health checks implemented, Envoy can now reliably connect to RLS and enforce traffic limits at the edge.** 🎯
