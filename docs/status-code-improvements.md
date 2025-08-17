# Status Code Improvements for RLS

## 🎯 **Problem Statement**

You correctly identified that the 413 errors in Envoy were genuine limit violations, not actual payload size issues. The status codes needed to be more semantically correct to distinguish between:

- **413 (Payload Too Large)**: Actual request body size issues
- **429 (Too Many Requests)**: Rate limiting and quota violations

## 🔧 **Changes Made**

### **Before: Incorrect Status Codes**
```go
// Limit violations were returning 413 (incorrect)
decision.Code = 413  // body_size_exceeded
decision.Code = 413  // labels_per_series_exceeded
```

### **After: Correct Status Codes**
```go
// Limit violations now return 429 (correct)
decision.Code = 429  // body_size_exceeded - Changed from 413 to 429
decision.Code = 429  // labels_per_series_exceeded - Changed from 413 to 429
```

## 📊 **Status Code Mapping**

| Violation Type | Old Code | New Code | Reason |
|----------------|----------|----------|---------|
| `body_size_exceeded` | 413 | **429** | ✅ Limit violation, not payload size |
| `labels_per_series_exceeded` | 413 | **429** | ✅ Limit violation, not payload size |
| `request body too large` | 413 | **413** | ✅ Actual payload size issue |
| `samples_per_second_exceeded` | 429 | **429** | ✅ Already correct |
| `bytes_per_second_exceeded` | 429 | **429** | ✅ Already correct |

## 🎯 **Semantic Correctness**

### **413 (Payload Too Large)**
- **When to use**: Actual request body size exceeds server limits
- **Example**: Request body is 60MB when server limit is 50MB
- **Current usage**: Only for `request body too large` (actual size issues)

### **429 (Too Many Requests)**
- **When to use**: Rate limiting, quota violations, or limit breaches
- **Examples**: 
  - Body size exceeds tenant's configured limit
  - Labels per series exceeds tenant's configured limit
  - Samples per second exceeds rate limit
  - Bytes per second exceeds rate limit
- **Current usage**: All limit violations and rate limiting

## 🔍 **Code Changes**

### **File**: `services/rls/internal/service/rls.go`

**Line 1676**: Body size limit violation
```go
// Before
decision.Code = 413

// After  
decision.Code = 429  // Changed from 413 to 429 for limit violations
```

**Line 1690**: Labels per series limit violation
```go
// Before
decision.Code = 413

// After
decision.Code = 429  // Changed from 413 to 429 for limit violations
```

**Line 1863**: Actual payload size issue (unchanged)
```go
// This remains 413 (correct)
return limits.Decision{Allowed: false, Reason: "request body too large", Code: 413}
```

## 📈 **Benefits**

### **1. Better Monitoring**
- **413 errors**: Indicate actual payload size issues (rare, needs investigation)
- **429 errors**: Indicate limit violations (expected, can be monitored for trends)

### **2. Correct Client Handling**
- Clients can distinguish between size issues and limit issues
- Proper retry strategies can be implemented
- Better error messages for users

### **3. Accurate Metrics**
- **413 rate**: Shows actual payload size problems
- **429 rate**: Shows limit violation patterns
- Better capacity planning and limit tuning

### **4. Semantic Clarity**
- **413**: "Your request is too big for the server"
- **429**: "You've exceeded your configured limits"

## 🚀 **Deployment Status**

- ✅ **Code updated**: Status codes changed in RLS service
- ✅ **Binary rebuilt**: New RLS binary with updated status codes
- ✅ **Docker image**: Updated and pushed to registry
- ✅ **Deployment updated**: RLS pods restarted with new image

## 📊 **Expected Results**

### **Before (Incorrect)**
```
413 errors: High (limit violations + actual size issues)
429 errors: Low (only rate limiting)
```

### **After (Correct)**
```
413 errors: Low (only actual size issues)
429 errors: High (limit violations + rate limiting)
```

## 🔧 **Monitoring Commands**

### **Check Status Code Distribution**
```bash
# Monitor 413 vs 429 errors
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | \
  grep -E "(413|429)" | awk '{print $NF}' | sort | uniq -c

# Check specific limit violations
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | \
  grep -E "(body_size_exceeded|labels_per_series_exceeded)" | \
  grep -E "(413|429)"
```

### **Real-time Monitoring**
```bash
# Monitor status codes in real-time
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls -f | \
  grep -E "(413|429)" | while read line; do
    echo "[$(date '+%H:%M:%S')] $line"
  done
```

## 🎯 **Next Steps**

1. **Monitor the changes**: Watch for the shift from 413 to 429 errors
2. **Update alerts**: Adjust monitoring alerts for the new status code distribution
3. **Client updates**: Update any client code that handles these status codes
4. **Documentation**: Update API documentation to reflect correct status codes

## 📋 **Summary**

The status code improvements provide:

- ✅ **Semantic correctness**: 413 for size issues, 429 for limit violations
- ✅ **Better monitoring**: Clear distinction between different error types
- ✅ **Improved debugging**: Easier to identify root causes
- ✅ **Client compatibility**: Standard HTTP status code usage

Your RLS service now returns the correct status codes for different types of violations!
