# 🛡️ Production Monitoring Guide: Validating Edge Enforcement Effectiveness

## 📊 **Key Metrics to Monitor**

### **1. Edge Enforcement Effectiveness**

#### **🎯 Primary Success Indicators**
```bash
# Traffic being processed by edge enforcement
kubectl logs -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement | grep "RLS admin API request"

# Tenant limits being loaded
kubectl logs -l app.kubernetes.io/name=overrides-sync -n mimir-edge-enforcement | grep "successfully synced tenant limits"

# Enforcement decisions being made
kubectl logs -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement | grep "enforcement decision"
```

#### **🚦 Traffic Flow Validation**
```bash
# Check if requests are flowing through Envoy
kubectl logs -l app.kubernetes.io/name=mimir-envoy -n mimir-edge-enforcement | grep "ext_authz"

# Verify RLS is making enforcement decisions
kubectl logs -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement | grep -E "(ALLOW|DENY)"

# Check token bucket utilization
kubectl logs -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement | grep "bucket"
```

### **2. Mimir Protection Metrics**

#### **🛡️ Load Reduction on Mimir**
```bash
# Compare Mimir distributor metrics before/after edge enforcement
curl -s http://mimir-distributor:8080/metrics | grep -E "(cortex_distributor_samples_in_total|cortex_distributor_requests_in_total)"

# Check if rate limiting is preventing overload
curl -s http://mimir-distributor:8080/metrics | grep "cortex_distributor_ingester_append_failures_total"
```

#### **📈 Expected Mimir Behavior**
- **Lower request volume** hitting distributors
- **Fewer 429 errors** from Mimir (shifted to edge)
- **More stable ingester performance**
- **Consistent query performance**

## 🎛️ **Admin UI Monitoring Dashboard**

### **Real-Time Operational View**

#### **📋 Overview Page Checklist**
```
✅ Active Tenants > 0 (confirms tenant loading)
✅ Total Requests > 0 (confirms traffic flow)
✅ Allow Percentage 80-95% (healthy enforcement)
✅ Denied Requests > 0 (confirms protection working)
✅ Top Tenants showing actual data
```

#### **👥 Tenants Page Validation**
```
✅ All expected tenants visible
✅ Limits match Mimir ConfigMap values
✅ Current metrics showing activity:
   - Allow Rate > 0 (traffic flowing)
   - Deny Rate appropriate for limits
   - Utilization % under limits
✅ Enforcement status = "Enforced"
```

#### **🚫 Denials Page Monitoring**
```
✅ Recent denials appearing (shows protection active)
✅ Denial reasons accurate:
   - "samples_per_second_exceeded"
   - "max_body_bytes_exceeded"
   - "max_series_per_request_exceeded"
✅ Tenant IDs match expected violators
✅ Timestamps recent and frequent
```

#### **❤️ Health Page Verification**
```json
{
  "status": "ok",
  "version": "1.0.0",
  "tenant_count": 25,
  "enforcement_active": true,
  "uptime_seconds": 3600,
  "memory_usage_bytes": 41943040
}
```

## 📈 **Production Metrics Collection**

### **🔢 Key Performance Indicators (KPIs)**

#### **Edge Enforcement Efficiency**
```prometheus
# Requests handled at edge vs passed to Mimir
rate(rls_requests_total[5m]) # Total edge requests
rate(rls_requests_allowed_total[5m]) # Passed to Mimir
rate(rls_requests_denied_total[5m]) # Blocked at edge

# Efficiency ratio
(rate(rls_requests_denied_total[5m]) / rate(rls_requests_total[5m])) * 100
```

#### **Mimir Load Reduction**
```prometheus
# Mimir distributor load reduction
rate(cortex_distributor_requests_in_total[5m]) # Should be lower
rate(cortex_distributor_samples_in_total[5m]) # Should be controlled

# Error rate improvement
rate(cortex_distributor_ingester_append_failures_total[5m]) # Should decrease
```

#### **System Performance**
```prometheus
# Edge components resource usage
container_memory_usage_bytes{pod=~"mimir-rls.*"}
container_cpu_usage_seconds_total{pod=~"mimir-rls.*"}
container_memory_usage_bytes{pod=~"mimir-envoy.*"}

# Response time impact
histogram_quantile(0.95, rate(envoy_http_downstream_rq_time_bucket[5m]))
```

## 🔍 **Validation Commands**

### **📋 Quick Health Check Script**

```bash
#!/bin/bash
# Save as: scripts/production-health-check.sh

NAMESPACE="mimir-edge-enforcement"

echo "🔍 Edge Enforcement Health Check"
echo "================================"

# 1. Check if all pods are running
echo "📦 Pod Status:"
kubectl get pods -n $NAMESPACE -o wide

# 2. Check tenant count
echo -e "\n👥 Tenant Loading:"
kubectl logs -l app.kubernetes.io/name=overrides-sync -n $NAMESPACE --tail=5 | grep "tenant_count"

# 3. Check recent enforcement decisions
echo -e "\n⚖️ Recent Enforcement Decisions:"
kubectl logs -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE --tail=10 | grep -E "(ALLOW|DENY|enforcement decision)"

# 4. Check if requests are flowing
echo -e "\n🌊 Traffic Flow:"
kubectl logs -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE --tail=5 | grep "admin API request"

# 5. Test Admin UI accessibility
echo -e "\n🖥️ Admin UI Status:"
kubectl get ingress -n $NAMESPACE
```

### **📊 Detailed Metrics Extraction**

```bash
#!/bin/bash
# Save as: scripts/extract-protection-metrics.sh

NAMESPACE="mimir-edge-enforcement"
TIMEFRAME="1h"

echo "📊 Edge Protection Metrics (Last $TIMEFRAME)"
echo "============================================="

# Get Admin UI data
echo "📋 Current Overview Stats:"
kubectl port-forward svc/mimir-rls 8082:8082 -n $NAMESPACE &
PF_PID=$!
sleep 2

curl -s "http://localhost:8082/api/overview" | jq '.stats'
curl -s "http://localhost:8082/api/tenants" | jq '.tenants | length'
curl -s "http://localhost:8082/api/denials" | jq '. | length'

kill $PF_PID 2>/dev/null
```

## 🎯 **Success Criteria**

### **✅ Edge Enforcement Working Correctly**

#### **Traffic Flow Indicators**
- **Tenant Count > 0**: Overrides-sync successfully loading tenants
- **Requests Being Processed**: RLS logs show incoming traffic
- **Enforcement Decisions**: Both ALLOW and DENY decisions being made
- **Admin UI Data**: All pages showing real-time data

#### **Protection Effectiveness**
- **Denial Rate 5-20%**: Showing active protection without over-blocking
- **Mimir Error Reduction**: Fewer 429/503 errors from Mimir distributors
- **Consistent Mimir Performance**: Query latency stays stable under load
- **Resource Efficiency**: Edge components using minimal resources

#### **Operational Excellence**
- **Auto-Refresh Working**: Admin UI updates every 5 seconds
- **All Limits Displayed**: Complete visibility in Tenants page
- **Recent Denials**: Active monitoring of blocked requests
- **CSV Export Available**: Historical analysis capability

### **🚨 Warning Signs**

#### **System Not Working**
- **Tenant Count = 0**: Overrides-sync not loading tenants
- **No Denial Activity**: No protection happening (100% allow rate)
- **High Error Rate**: More denials than expected (>50%)
- **Admin UI Empty**: No data in Overview/Tenants pages

#### **Performance Issues**
- **High Resource Usage**: Edge components consuming too much CPU/memory
- **Slow Response Times**: Envoy adding significant latency
- **Mimir Still Overloaded**: Error rates not improving

## 📋 **Daily Operations Checklist**

### **🌅 Morning Checks**
```
□ Check Admin UI Overview for yesterday's stats
□ Verify all tenants loaded correctly
□ Review denial patterns for anomalies
□ Confirm auto-refresh indicators active
□ Check edge component pod health
```

### **🔄 Ongoing Monitoring**
```
□ Monitor deny rates for sudden spikes
□ Watch for new tenants being added
□ Track Mimir performance improvements
□ Review resource usage trends
□ Validate NGINX canary weight settings
```

### **🌙 End-of-Day Review**
```
□ Export denial CSV for analysis
□ Review enforcement effectiveness
□ Check for any component restarts
□ Validate limit adjustments needed
□ Plan capacity adjustments
```

## 🎪 **Demo/Validation Scenarios**

### **🧪 Controlled Load Testing**

#### **Scenario 1: Tenant Limit Violation**
```bash
# Send requests exceeding samples/sec limit
for i in {1..100}; do
  curl -X POST http://your-mimir-endpoint/api/v1/push \
    -H "X-Scope-OrgID: test-tenant" \
    -H "Content-Type: application/x-protobuf" \
    --data-binary @large-sample-batch.pb
done

# Expected: See denials in Admin UI within 5 seconds
```

#### **Scenario 2: Body Size Enforcement**
```bash
# Send request exceeding max_body_bytes
curl -X POST http://your-mimir-endpoint/api/v1/push \
  -H "X-Scope-OrgID: test-tenant" \
  -H "Content-Type: application/x-protobuf" \
  --data-binary @oversized-payload.pb

# Expected: "max_body_bytes_exceeded" denial
```

### **📊 Expected Results**
- **Immediate Visibility**: Denials appear in Admin UI within 5 seconds
- **Mimir Protection**: Overloaded requests blocked before reaching distributors
- **Detailed Logging**: All decisions logged with reasoning
- **Metrics Available**: Complete operational visibility

## 🎉 **Success Validation Summary**

Your edge enforcement is working efficiently if you see:

1. **✅ Traffic Flowing**: Requests processed by RLS (allow + deny > 0)
2. **✅ Tenants Loaded**: All expected tenants in Admin UI with limits
3. **✅ Active Protection**: Appropriate denial rate (5-20%)
4. **✅ Mimir Relief**: Reduced error rates and stable performance
5. **✅ Real-Time Monitoring**: Auto-refreshing Admin UI with live data
6. **✅ Operational Visibility**: Complete observability and debugging tools

Perfect production validation! 🛡️📊🎯
