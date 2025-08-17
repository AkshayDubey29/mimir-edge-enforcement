# RLS Log Analysis Commands

## 🔍 **Quick Commands for RLS Log Analysis**

### **1. Check RLS Configuration**
```bash
# Get current RLS configuration
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | \
  grep "parsed configuration values" | tail -n1 | jq '.'

# Check max body bytes configuration
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | \
  grep "default_max_body_bytes" | tail -n1
```

### **2. Find 413 Errors**
```bash
# Search for 413 errors in RLS logs
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | \
  grep -E "(413|request body too large|body_size_exceeded)"

# Count 413 errors
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | \
  grep -c "413"

# Get recent 413 errors with timestamps
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | \
  grep "413" | tail -n10
```

### **3. Analyze Request Sizes**
```bash
# Find request size information
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | \
  grep -E "(body.*bytes|request.*bytes|size.*bytes)" | \
  grep -v "parsed configuration"

# Extract and analyze request sizes
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | \
  grep -E "(body.*bytes|request.*bytes|size.*bytes)" | \
  grep -v "parsed configuration" | \
  grep -o '[0-9]*' | sort -n | uniq -c

# Find large requests (>10MB)
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | \
  grep -E "(body.*bytes|request.*bytes|size.*bytes)" | \
  grep -v "parsed configuration" | \
  awk '{if($0 ~ /[0-9]+/ && $0 ~ /bytes/) {gsub(/[^0-9]/, " "); for(i=1;i<=NF;i++) if($i>10485760) print $0}}'
```

### **4. Analyze Decision Logs**
```bash
# Find deny decisions
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | \
  grep -E "(decision.*deny|allowed.*false|deny.*decision)"

# Find allow decisions
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | \
  grep -E "(decision.*allow|allowed.*true|allow.*decision)"

# Count decisions
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | \
  grep -c "decision"
```

### **5. Find Error Reasons**
```bash
# Search for error reasons
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | \
  grep -E "(reason.*|error.*|fail.*)" | \
  grep -v "parsed configuration"

# Find specific error types
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | \
  grep -E "(body_size_exceeded|labels_per_series_exceeded|request_too_large|parse_failed)"
```

### **6. Analyze Tenant Information**
```bash
# Find tenant-specific logs
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | \
  grep -E "(tenant.*ID|X-Scope-OrgID)"

# Find tenant-specific errors
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | \
  grep -E "(tenant.*ID|X-Scope-OrgID)" | \
  grep -E "(413|deny|reject|error)"
```

### **7. Real-time Monitoring**
```bash
# Monitor RLS logs in real-time for 413 errors
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls -f | \
  grep -E "(413|deny|reject|too large|body.*size|request.*size)"

# Monitor with timestamps
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls -f | \
  grep -E "(413|deny|reject|too large)" | \
  while read line; do echo "[$(date '+%H:%M:%S')] $line"; done
```

### **8. Comprehensive Analysis**
```bash
# Get summary of recent activity
echo "=== RLS Activity Summary ==="
echo "413 errors: $(kubectl logs -n mimir-edge-enforcement deployment/mimir-rls --tail=1000 | grep -c '413')"
echo "Deny decisions: $(kubectl logs -n mimir-edge-enforcement deployment/mimir-rls --tail=1000 | grep -c 'deny')"
echo "Allow decisions: $(kubectl logs -n mimir-edge-enforcement deployment/mimir-rls --tail=1000 | grep -c 'allow')"
echo "Request processing: $(kubectl logs -n mimir-edge-enforcement deployment/mimir-rls --tail=1000 | grep -c 'processing')"

# Get recent error reasons
echo "=== Recent Error Reasons ==="
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls --tail=1000 | \
  grep -E "(reason.*|error.*|fail.*)" | \
  grep -v "parsed configuration" | tail -n10
```

### **9. Advanced Analysis**
```bash
# Analyze request size distribution
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls --tail=1000 | \
  grep -E "(body.*bytes|request.*bytes|size.*bytes)" | \
  grep -v "parsed configuration" | \
  grep -o '[0-9]*' | sort -n | uniq -c | \
  awk '{if($2>10485760) print "Large request: " $2 " bytes (" $2/1024/1024 "MB) - " $1 " occurrences"}'

# Find patterns in error messages
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls --tail=1000 | \
  grep -E "(413|deny|reject)" | \
  awk '{print $NF}' | sort | uniq -c | sort -nr
```

### **10. Check Specific Pod**
```bash
# Get specific pod name
POD=$(kubectl get pods -n mimir-edge-enforcement | grep rls | grep Running | head -n1 | awk '{print $1}')

# Analyze specific pod logs
kubectl logs -n mimir-edge-enforcement $POD | \
  grep -E "(413|deny|reject|too large|body.*size|request.*size)" | \
  tail -n20
```

## 🎯 **Key Patterns to Look For**

### **413 Error Patterns**
- `413` - HTTP status code
- `request body too large` - Generic size error
- `body_size_exceeded` - RLS-specific body size error
- `labels_per_series_exceeded` - Label limit error
- `request_too_large` - Request size error

### **Request Size Patterns**
- `body.*bytes` - Body size information
- `request.*bytes` - Request size information
- `size.*bytes` - Size information

### **Decision Patterns**
- `decision.*deny` - Deny decisions
- `decision.*allow` - Allow decisions
- `allowed.*false` - Denied requests
- `allowed.*true` - Allowed requests

### **Error Reason Patterns**
- `reason.*` - Error reasons
- `error.*` - Error messages
- `fail.*` - Failure messages

## 📊 **Expected Output Examples**

### **Configuration Log**
```json
{
  "level": "info",
  "component": "rls",
  "default_max_body_bytes": 52428800,
  "time": "2025-08-17T12:56:53Z",
  "message": "parsed configuration values"
}
```

### **413 Error Log**
```json
{
  "level": "warn",
  "component": "rls",
  "tenant": "test-tenant",
  "reason": "request body too large",
  "body_bytes": 15728640,
  "time": "2025-08-17T12:56:53Z"
}
```

### **Decision Log**
```json
{
  "level": "info",
  "component": "rls",
  "tenant": "test-tenant",
  "decision": "deny",
  "reason": "body_size_exceeded",
  "code": 413,
  "time": "2025-08-17T12:56:53Z"
}
```

## 🚨 **Troubleshooting Tips**

1. **If no logs found**: Check if requests are reaching RLS
2. **If no 413 errors**: The issue might be upstream (Envoy/NGINX)
3. **If configuration wrong**: Check if the new image is deployed
4. **If patterns not matching**: Check log format and adjust regex

## 🔧 **Using the Analysis Script**

```bash
# Run comprehensive analysis
./scripts/analyze-rls-413-errors.sh all

# Run specific analysis
./scripts/analyze-rls-413-errors.sh 413
./scripts/analyze-rls-413-errors.sh config
./scripts/analyze-rls-413-errors.sh monitor
```
