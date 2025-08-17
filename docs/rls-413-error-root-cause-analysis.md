# RLS 413 Error Root Cause Analysis

## 🚨 **Problem Statement**

You were experiencing a high rate of 413 "Payload Too Large" errors in production after adding RLS to the pipeline. The issue was that:

- **Before RLS**: Requests worked fine with large payloads
- **After RLS**: 90% of requests were failing with 413 errors
- **Configuration**: You had set `maxRequestBytes: 52428800` (50MB) in `values-rls.yaml`
- **Expected**: Requests up to 50MB should be accepted
- **Actual**: Requests > 10MB were being rejected with 413

## 🔍 **Root Cause Analysis**

### **The Real Issue: Hardcoded 10MB Limit in RLS Code**

The problem was **NOT** in the NGINX ingress, Envoy configuration, or load balancer settings. The issue was a **hardcoded limit** in the RLS source code.

### **Location of the Bug**

**File**: `services/rls/internal/service/rls.go`  
**Line**: 452  
**Code**:
```go
// 🔥 ULTRA-FAST PATH: Skip parsing for very large requests to prevent timeouts
if bodyBytes > 10*1024*1024 { // 10MB limit (reduced from 50MB)
    return rls.denyResponse("request body too large", http.StatusRequestEntityTooLarge), nil
}
```

### **Why This Was Happening**

1. **Your Configuration**: You correctly set `maxRequestBytes: 52428800` (50MB) in `values-rls.yaml`
2. **Flag Passing**: The flag was correctly passed to RLS as `--max-request-bytes=52428800`
3. **RLS Configuration**: RLS correctly parsed the flag and set `MaxRequestBytes: 52428800`
4. **The Bug**: However, there was a **hardcoded 10MB check** that was executed **BEFORE** the configured limit check
5. **Result**: Any request > 10MB was immediately rejected with 413, regardless of your 50MB configuration

### **Additional 413 Error Sources**

The RLS code also had other places where 413 errors were generated:

1. **Line 1675**: Body size exceeded enforcement
2. **Line 1689**: Labels per series exceeded enforcement  
3. **Line 1862**: Request body too large in limits check

## 🛠️ **The Fix**

### **Code Change**

**Before**:
```go
if bodyBytes > 10*1024*1024 { // 10MB limit (reduced from 50MB)
    return rls.denyResponse("request body too large", http.StatusRequestEntityTooLarge), nil
}
```

**After**:
```go
// Use configured MaxRequestBytes instead of hardcoded 10MB limit
if rls.config.MaxRequestBytes > 0 && bodyBytes > rls.config.MaxRequestBytes {
    return rls.denyResponse("request body too large", http.StatusRequestEntityTooLarge), nil
}
```

### **What Changed**

1. **Removed hardcoded 10MB limit**
2. **Used configured `MaxRequestBytes` value** (50MB from your config)
3. **Added safety check** to ensure `MaxRequestBytes > 0` before comparison
4. **Now respects your configuration** instead of ignoring it

## 🔧 **Deployment Steps**

### **1. Code Fix Applied**
- ✅ Fixed the hardcoded 10MB limit in RLS code
- ✅ Updated to use configured `MaxRequestBytes` value
- ✅ Committed and pushed to GitHub

### **2. Binary Rebuilt**
- ✅ Built new RLS binary with the fix
- ✅ Created new Docker image: `ghcr.io/akshaydubey29/mimir-rls:latest`
- ✅ Pushed image to container registry

### **3. Deployment Updated**
- ✅ Updated RLS deployment with new image
- ✅ Restarted RLS pods to pick up new image

## 📊 **Expected Results**

After applying this fix:

- ✅ **413 errors should drop from 90% to near 0%**
- ✅ **Requests up to 50MB should be accepted**
- ✅ **2XX responses should increase significantly**
- ✅ **RLS will now respect your configured limits**

## 🧪 **Verification**

### **Check RLS Configuration**
```bash
# Verify RLS is using the correct limit
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | \
  grep "parsed configuration values"
```

Expected output should show:
```json
{"default_max_body_bytes":52428800}
```

### **Test Large Requests**
```bash
# Test with requests > 10MB but < 50MB
curl -X POST http://your-endpoint/api/v1/push \
  -H "Content-Type: application/x-protobuf" \
  -H "X-Scope-OrgID: test-tenant" \
  -d @large-payload.bin \
  -v
```

### **Monitor 413 Error Rates**
```bash
# Check for 413 errors in Envoy logs
kubectl logs -n mimir-edge-enforcement deployment/mimir-envoy | \
  grep " 413 " | wc -l

# Check for 413 errors in RLS logs  
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | \
  grep "413" | wc -l
```

## 🎯 **Key Takeaways**

### **Why This Happened**
1. **Configuration vs Implementation Mismatch**: Your configuration was correct, but the code had a hardcoded override
2. **Early Exit Logic**: The 10MB check was executed before the configured limit check
3. **Performance Optimization Gone Wrong**: The comment suggests this was added for "ultra-fast path" but it was too restrictive

### **Lessons Learned**
1. **Always verify code implementation** matches configuration
2. **Test with actual request sizes** that match your production traffic
3. **Monitor for hardcoded limits** in performance-critical code paths
4. **Configuration should always take precedence** over hardcoded values

### **Prevention**
1. **Add integration tests** with various request sizes
2. **Monitor 413 error rates** as a key metric
3. **Document configuration limits** clearly
4. **Code review** for hardcoded limits in performance paths

## 🚀 **Next Steps**

1. **Deploy the fix** to production
2. **Monitor 413 error rates** - should drop significantly
3. **Test with real traffic patterns** to verify the fix
4. **Update monitoring** to alert on 413 error spikes
5. **Consider adding tests** to prevent regression

## 📞 **Support**

If you continue to see 413 errors after this fix:

1. **Verify the new image is deployed**: Check pod image SHA
2. **Check RLS logs**: Look for the configuration values
3. **Test with known request sizes**: Verify the limits are working
4. **Monitor upstream components**: Check if other components have limits

The root cause has been identified and fixed. The RLS service will now properly respect your 50MB configuration instead of being limited by the hardcoded 10MB check.
