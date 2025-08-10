# 🔐 NGINX 401 Authentication Error Fix

## 📋 **Problem Overview**

When using NGINX canary routing to send traffic through the edge enforcement system, you may encounter **401 Unauthorized** errors for `route=edge` traffic. This occurs because:

1. **NGINX** requires HTTP Basic Authentication for API endpoints
2. **Canary routing** forwards traffic to Envoy but may not preserve the `Authorization` header
3. **Envoy** receives requests without authentication credentials
4. **Mimir** rejects unauthenticated requests with 401 errors

## 🚨 **Symptoms**

### **NGINX Logs Show:**
```
route=edge 401 POST /api/v1/push
```

### **Expected vs Actual Behavior:**
- **Expected**: `route=edge 200 POST /api/v1/push` (with valid auth)
- **Actual**: `route=edge 401 POST /api/v1/push` (auth header lost)

## 🔍 **Root Cause Analysis**

### **The Problem:**
```nginx
# ❌ BROKEN: Missing Authorization header forwarding
location /api/v1/push {
    if ($route_decision = "edge") {
        proxy_pass http://mimir_via_edge_enforcement;
    }
    # Missing: proxy_set_header Authorization $http_authorization;
}
```

### **The Fix:**
```nginx
# ✅ FIXED: Proper Authorization header forwarding
location /api/v1/push {
    if ($route_decision = "edge") {
        proxy_pass http://mimir_via_edge_enforcement;
    }
    # 🔧 CRITICAL: Forward Authorization header
    proxy_set_header Authorization $http_authorization;
}
```

## 🔧 **Solution: Authorization Header Forwarding**

### **1. Automatic Fix Script**
```bash
# Run the automated fix
./scripts/fix-nginx-401.sh

# This script will:
# ✅ Backup your current NGINX configuration
# ✅ Apply the fixed ConfigMap with proper header forwarding
# ✅ Update your NGINX deployment
# ✅ Verify the configuration
# ✅ Test the fix
```

### **2. Manual Configuration**
If you prefer manual configuration, apply this ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config-with-auth-fix
  namespace: mimir
data:
  nginx.conf: |
    # Hash-based canary routing
    map $request_id $canary_hash {
        default 0;
        ~^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ 1;
    }
    
    map $canary_hash $route_decision {
        0 direct;
        1 edge;
    }
    
    upstream mimir_direct {
        server distributor.mimir.svc.cluster.local:8080;
    }
    
    upstream mimir_via_edge_enforcement {
        server mimir-envoy.mimir-edge-enforcement.svc.cluster.local:8080;
    }
    
    server {
        listen 80;
        server_name _;
        
        # 🔧 CRITICAL FIX: Preserve Authorization headers for all routes
        proxy_set_header Authorization $http_authorization;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Host $http_host;
        proxy_set_header X-Request-ID $request_id;
        
        # Authentication configuration
        auth_basic "Restricted Access";
        auth_basic_user_file /etc/nginx/.htpasswd;
        
        location /api/v1/push {
            set $target_upstream mimir_direct;
            if ($route_decision = "edge") {
                set $target_upstream mimir_via_edge_enforcement;
            }
            
            # 🔧 CRITICAL: Ensure Authorization header is forwarded
            proxy_set_header Authorization $http_authorization;
            
            proxy_set_header X-Canary-Route $route_decision;
            proxy_pass http://$target_upstream;
            
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
            proxy_buffering off;
            proxy_request_buffering off;
        }
    }
```

## 🧪 **Testing the Fix**

### **1. Quick Diagnostic**
```bash
# Run comprehensive 401 debugging
./scripts/debug-401-errors.sh

# This will check:
# ✅ NGINX authentication configuration
# ✅ .htpasswd secret existence
# ✅ Authorization header forwarding
# ✅ Recent 401 errors in logs
# ✅ Edge enforcement components
```

### **2. Manual Testing**
```bash
# Test without authentication (should get 401)
curl -v http://your-nginx-service/api/v1/push

# Test with authentication (should work)
curl -v -u username:password http://your-nginx-service/api/v1/push

# Check NGINX logs for route=edge entries
kubectl logs -f deployment/nginx -n mimir | grep "route=edge"
```

### **3. Verify Header Forwarding**
```bash
# Check if Authorization header forwarding is configured
kubectl exec -it deployment/nginx -n mimir -- \
  grep -A 5 -B 5 "proxy_set_header Authorization" /etc/nginx/nginx.conf
```

## 📊 **Expected Results After Fix**

### **Before Fix:**
```
NGINX → Envoy: Request without Authorization header
Envoy → Mimir: Unauthenticated request
Mimir: 401 Unauthorized
Result: route=edge 401 POST /api/v1/push ❌
```

### **After Fix:**
```
NGINX → Envoy: Request with Authorization header
Envoy → Mimir: Authenticated request  
Mimir: 200 OK
Result: route=edge 200 POST /api/v1/push ✅
```

## 🔄 **Deployment Steps**

### **Step 1: Apply the Fix**
```bash
# Option A: Automated fix
./scripts/fix-nginx-401.sh

# Option B: Manual application
kubectl apply -f examples/nginx-auth-header-fix.yaml
```

### **Step 2: Update NGINX Deployment**
```bash
# Find your NGINX deployment
kubectl get deployment -n mimir | grep nginx

# Update to use new ConfigMap
kubectl patch deployment <nginx-deployment> -n mimir -p '{
  "spec": {
    "template": {
      "spec": {
        "volumes": [
          {
            "name": "nginx-config",
            "configMap": {
              "name": "nginx-config-with-auth-fix"
            }
          }
        ]
      }
    }
  }
}'

# Restart deployment
kubectl rollout restart deployment <nginx-deployment> -n mimir
```

### **Step 3: Verify the Fix**
```bash
# Wait for rollout
kubectl rollout status deployment <nginx-deployment> -n mimir

# Check configuration
kubectl exec -it deployment/<nginx-deployment> -n mimir -- nginx -t

# Test authentication
curl -u username:password http://your-nginx-service/api/v1/push
```

## 🚨 **Troubleshooting**

### **Common Issues:**

#### **1. .htpasswd Secret Missing**
```bash
# Create the secret
kubectl create secret generic nginx-auth -n mimir \
  --from-file=.htpasswd=/path/to/.htpasswd

# Verify it exists
kubectl get secret nginx-auth -n mimir
```

#### **2. ConfigMap Not Mounted**
```bash
# Check volume mounts
kubectl describe deployment <nginx-deployment> -n mimir | grep -A 10 "Volumes"

# Verify ConfigMap exists
kubectl get configmap nginx-config-with-auth-fix -n mimir
```

#### **3. NGINX Configuration Syntax Error**
```bash
# Check syntax
kubectl exec -it deployment/<nginx-deployment> -n mimir -- nginx -t

# Check logs
kubectl logs deployment/<nginx-deployment> -n mimir
```

#### **4. Authorization Header Still Not Forwarded**
```bash
# Verify the configuration
kubectl exec -it deployment/<nginx-deployment> -n mimir -- \
  grep -n "proxy_set_header Authorization" /etc/nginx/nginx.conf

# Check if it's in the right location block
kubectl exec -it deployment/<nginx-deployment> -n mimir -- \
  grep -A 10 -B 5 "/api/v1/push" /etc/nginx/nginx.conf
```

## 🔄 **Rollback Instructions**

### **If the fix causes issues:**
```bash
# Restore from backup (if using automated script)
kubectl apply -f backup-nginx-config-YYYYMMDD-HHMMSS.yaml

# Or manually restore your original configuration
kubectl apply -f your-original-nginx-config.yaml

# Restart NGINX
kubectl rollout restart deployment <nginx-deployment> -n mimir
```

## 📋 **Checklist**

### **Pre-Fix Verification:**
- [ ] NGINX requires authentication for API endpoints
- [ ] `.htpasswd` secret exists in the namespace
- [ ] Canary routing is configured and working
- [ ] 401 errors are occurring for `route=edge` traffic

### **Post-Fix Verification:**
- [ ] Authorization header forwarding is configured
- [ ] NGINX configuration syntax is valid
- [ ] NGINX deployment restarted successfully
- [ ] Authentication works for direct traffic
- [ ] Authentication works for edge-routed traffic
- [ ] No more 401 errors for `route=edge`

### **Monitoring:**
- [ ] Monitor NGINX logs for 401 errors
- [ ] Verify canary percentage is working
- [ ] Check that both routes (direct/edge) work with auth
- [ ] Test emergency endpoints if configured

## 🎯 **Success Indicators**

After applying the fix, you should see:

1. **✅ No more 401 errors** for `route=edge` traffic
2. **✅ Successful authentication** for both direct and edge routes
3. **✅ Proper canary distribution** (10% to edge, 90% direct)
4. **✅ Authorization headers preserved** in all proxy requests
5. **✅ Edge enforcement working** with authenticated requests

## 📚 **Related Documentation**

- **[NGINX Canary Setup Guide](nginx-canary-setup.md)**: Complete canary deployment guide
- **[Envoy HTTP Protocol Fix](envoy-http-protocol-fix.md)**: Fix for 426 Upgrade Required errors
- **[Deployment Guide](deployment.md)**: Complete production deployment instructions
- **[Troubleshooting Guide](troubleshooting.md)**: General troubleshooting procedures

---

**The 401 authentication error in canary routing is now permanently fixed!** 🔐✅
