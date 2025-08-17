# Production 413 Error Fix Guide

## 🚨 **Problem**: High 413 Error Rate in Production

You're experiencing a high rate of 413 "Payload Too Large" errors in production, with most requests failing while only health checks return 2XX responses.

## 🔍 **Root Cause Analysis**

Based on the diagnostic results, the most likely causes are:

### **1. NGINX Ingress Controller (80% probability)**
- **Default Limit**: NGINX ingress has a default `client_max_body_size` of 1MB
- **Impact**: Any request > 1MB gets rejected with 413
- **Fix**: Increase to 50MB

### **2. Ingress Annotations (15% probability)**
- **Issue**: Missing or too small `client-max-body-size` annotations
- **Fix**: Add proper annotations to all ingresses

### **3. Load Balancer Limits (5% probability)**
- **AWS ALB**: Default 1MB limit
- **GCP LB**: May have request size limits
- **Azure LB**: May have request size limits

## 🛠️ **Immediate Fixes**

### **Step 1: Fix NGINX Ingress Controller**

```bash
# Check if nginx-ingress is installed
kubectl get namespaces | grep ingress-nginx

# Update the configmap
kubectl patch configmap nginx-configuration -n ingress-nginx \
  --patch '{"data":{"client-max-body-size":"50m"}}'

# Restart nginx pods
kubectl rollout restart deployment -n ingress-nginx
```

### **Step 2: Fix Ingress Annotations**

```bash
# Add client-max-body-size to all ingresses
kubectl patch ingress <ingress-name> -n <namespace> \
  --type='merge' \
  -p='{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/client-max-body-size":"50m"}}}'
```

### **Step 3: Verify Envoy Configuration**

```bash
# Check Envoy HTTP/2 buffer settings
kubectl get configmap mimir-envoy-config -n mimir-edge-enforcement \
  -o jsonpath='{.data.envoy\.yaml}' | grep -A 5 -B 5 "initial_stream_window_size"
```

### **Step 4: Verify RLS Configuration**

```bash
# Check RLS max body bytes
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | \
  grep "default_max_body_bytes"
```

## 🔧 **Automated Fix Script**

Run the production fix script:

```bash
./scripts/fix-production-413-errors.sh
```

This script will:
- ✅ Check and fix NGINX ingress configuration
- ✅ Update ingress annotations
- ✅ Check load balancer settings
- ✅ Verify Envoy and RLS configurations
- ✅ Provide specific recommendations

## 📊 **Monitoring and Verification**

### **Check 413 Error Rates**

```bash
# Check Envoy access logs for 413 errors
kubectl logs -n mimir-edge-enforcement deployment/mimir-envoy | \
  grep " 413 " | wc -l

# Check RLS logs for 413 errors
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | \
  grep "413" | wc -l
```

### **Test Request Sizes**

```bash
# Test with different request sizes
curl -X POST http://your-endpoint/api/v1/push \
  -H "Content-Type: application/x-protobuf" \
  -H "X-Scope-OrgID: test-tenant" \
  -d @large-payload.bin \
  -v
```

### **Monitor Response Codes**

```bash
# Check response code distribution
kubectl logs -n mimir-edge-enforcement deployment/mimir-envoy | \
  grep "api/v1/push" | \
  awk '{print $6}' | sort | uniq -c
```

## 🎯 **Expected Results**

After applying the fixes:

- ✅ **413 errors should drop significantly**
- ✅ **2XX responses should increase**
- ✅ **Health checks should continue working**
- ✅ **Large requests (>1MB) should be accepted**

## 🚨 **If 413 Errors Persist**

### **Check Load Balancer Settings**

**AWS ALB/NLB:**
```bash
# Check service annotations
kubectl get svc -A -o jsonpath='{.items[*].metadata.annotations}' | \
  grep -E "alb|nlb|aws"
```

**GCP Load Balancer:**
```bash
# Check for GCP annotations
kubectl get svc -A -o jsonpath='{.items[*].metadata.annotations}' | \
  grep -E "gcp|google"
```

### **Check Network Policies**

```bash
# Check for network policies that might limit request sizes
kubectl get networkpolicy -A
```

### **Check Client-Side Issues**

- Verify request compression (snappy)
- Check client timeout settings
- Monitor actual request sizes being sent

## 📋 **Configuration Reference**

### **NGINX Ingress Configuration**

```yaml
# nginx-configuration ConfigMap
data:
  client-max-body-size: "50m"
  proxy-body-size: "50m"
  proxy-connect-timeout: "30"
  proxy-send-timeout: "120"
  proxy-read-timeout: "120"
```

### **Ingress Annotations**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/client-max-body-size: "50m"
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "30"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "120"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "120"
```

### **Envoy Configuration**

```yaml
# HTTP/2 buffer settings
http2_protocol_options:
  initial_stream_window_size: 52428800    # 50MB
  initial_connection_window_size: 52428800 # 50MB
```

### **RLS Configuration**

```yaml
# RLS limits
limits:
  maxRequestBytes: 52428800    # 50MB
  maxBodyBytes: 52428800       # 50MB
```

## 🔄 **Rollback Plan**

If the fixes cause issues:

```bash
# Revert NGINX config
kubectl patch configmap nginx-configuration -n ingress-nginx \
  --patch '{"data":{"client-max-body-size":"1m"}}'

# Revert ingress annotations
kubectl patch ingress <ingress-name> -n <namespace> \
  --type='merge' \
  -p='{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/client-max-body-size":"1m"}}}'

# Restart services
kubectl rollout restart deployment -n ingress-nginx
```

## 📞 **Support**

If you continue to experience 413 errors after applying these fixes:

1. Run the diagnostic script: `./scripts/diagnose-413-errors.sh`
2. Check the logs for specific error messages
3. Monitor request sizes in your application
4. Consider implementing request compression
5. Review load balancer configuration with your cloud provider
