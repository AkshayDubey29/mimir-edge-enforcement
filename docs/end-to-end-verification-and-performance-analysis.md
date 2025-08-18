# End-to-End Verification and Performance Analysis

## 🎯 **Overview**

This document explains how to verify that filtered metrics reach Mimir and measure the performance impact of selective filtering. We need to ensure the complete `nginx → envoy → rls → mimir` pipeline works correctly with selective filtering enabled.

## 🔍 **End-to-End Verification**

### **What We Need to Verify**

1. **✅ Complete Pipeline Flow**: `nginx → envoy → rls → mimir`
2. **✅ Selective Filtering Works**: RLS filters excess series correctly
3. **✅ Filtered Data Reaches Mimir**: Mimir receives and stores filtered metrics
4. **✅ Performance Impact**: Measure latency and throughput impact

### **Verification Scripts**

#### **1. Comprehensive End-to-End Test**
```bash
# Run complete end-to-end verification
./scripts/verify-end-to-end-flow.sh
```

**This script verifies:**
- ✅ **Component Health**: All services (RLS, Envoy, Mimir) are running
- ✅ **Test Data Generation**: Creates protobuf data that triggers limits
- ✅ **Baseline Performance**: Measures performance without selective filtering
- ✅ **Selective Filtering Performance**: Measures performance with selective filtering
- ✅ **Mimir Ingestion**: Confirms filtered metrics reach Mimir
- ✅ **Log Analysis**: Checks RLS and Envoy logs for filtering activity

#### **2. Performance Impact Analysis**
```bash
# Run focused performance analysis
./scripts/analyze-performance-impact.sh
```

**This script measures:**
- 📊 **Latency Impact**: Response time difference between baseline and selective filtering
- 📊 **Throughput Impact**: Success rate and error rate comparison
- 📊 **Payload Size Impact**: Performance across different payload sizes
- 📊 **Resource Usage**: CPU and memory impact

## 📊 **Expected Results**

### **End-to-End Flow Verification**

#### **Before Selective Filtering**
```
Request with 1000 series → RLS → DENY (413/429) → No data reaches Mimir
```

#### **After Selective Filtering**
```
Request with 1000 series → RLS → Filter (drop 200 excess series) → 800 series reach Mimir ✅
```

### **Performance Impact Expectations**

#### **Acceptable Performance Impact**
- **Latency**: < 20% increase in response time
- **Throughput**: > 90% success rate
- **Resource Usage**: < 30% additional CPU/memory

#### **Performance Thresholds**
| Metric | Acceptable | Moderate | High |
|--------|------------|----------|------|
| **Latency Increase** | < 20% | 20-50% | > 50% |
| **Success Rate** | > 95% | 90-95% | < 90% |
| **Resource Usage** | < 30% | 30-60% | > 60% |

## 🧪 **Testing Methodology**

### **1. Test Data Generation**

The verification scripts create realistic test data:

```go
// Generate 1000 series to trigger limits
for i := 0; i < 1000; i++ {
    timeseries := &prompb.TimeSeries{}
    
    // Add metric name
    timeseries.Labels = append(timeseries.Labels, &prompb.Label{
        Name:  "__name__",
        Value: fmt.Sprintf("test_metric_%d", i%10), // 10 different metrics
    })
    
    // Add labels
    timeseries.Labels = append(timeseries.Labels, &prompb.Label{
        Name:  "instance",
        Value: fmt.Sprintf("server-%d", i%5),
    })
    
    // Add sample
    timeseries.Samples = append(timeseries.Samples, &prompb.Sample{
        Value:     float64(i),
        Timestamp: 1640995200000 + int64(i*1000),
    })
}
```

### **2. Performance Testing**

#### **Baseline Testing (Without Selective Filtering)**
```bash
# Disable selective filtering
kubectl patch configmap -n mimir-edge-enforcement mimir-rls \
  --type='json' -p='[{"op": "replace", "path": "/data/selectiveFiltering.enabled", "value": "false"}]'

# Restart RLS
kubectl rollout restart deployment/mimir-rls -n mimir-edge-enforcement

# Test performance
curl -X POST \
  -H "Content-Type: application/x-protobuf" \
  -H "Content-Encoding: snappy" \
  -H "X-Scope-OrgID: test-tenant" \
  --data-binary @test-data/limit_test_data.pb \
  http://localhost:8080/api/v1/push
```

#### **Selective Filtering Testing**
```bash
# Enable selective filtering
kubectl patch configmap -n mimir-edge-enforcement mimir-rls \
  --type='json' -p='[{"op": "replace", "path": "/data/selectiveFiltering.enabled", "value": "true"}]'

# Restart RLS
kubectl rollout restart deployment/mimir-rls -n mimir-edge-enforcement

# Test performance
curl -X POST \
  -H "Content-Type: application/x-protobuf" \
  -H "Content-Encoding: snappy" \
  -H "X-Scope-OrgID: test-tenant" \
  --data-binary @test-data/limit_test_data.pb \
  http://localhost:8080/api/v1/push
```

### **3. Verification Points**

#### **RLS Logs Verification**
```bash
# Check for selective filtering activity
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | grep "selective_filter_applied"

# Check for successful filtering
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | grep "Successfully filtered"

# Check for series dropped
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | grep "dropped_series"
```

#### **Envoy Logs Verification**
```bash
# Check for successful requests
kubectl logs -n mimir-edge-enforcement deployment/envoy | grep "200"

# Check for error requests
kubectl logs -n mimir-edge-enforcement deployment/envoy | grep "413\|429\|500"
```

#### **Mimir Verification**
```bash
# Check Mimir metrics for ingested data
kubectl exec -n mimir deployment/mimir-distributor -- curl -s http://localhost:9009/metrics | grep 'cortex_distributor_received_samples_total'

# Query Mimir for test metrics
kubectl exec -n mimir deployment/mimir-distributor -- curl -s "http://localhost:9009/prometheus/api/v1/query?query=test_metric_0"
```

## 📈 **Performance Analysis Results**

### **Expected Performance Impact**

#### **Latency Impact**
- **Small Payloads (1-10KB)**: 5-15ms additional latency
- **Medium Payloads (100KB)**: 10-30ms additional latency
- **Large Payloads (1MB+)**: 20-50ms additional latency

#### **Success Rate Impact**
- **Before**: 0% success (all requests denied when limits exceeded)
- **After**: 80-95% success (filtered requests pass through)

#### **Resource Usage Impact**
- **CPU**: 10-25% additional usage during filtering
- **Memory**: 5-15% additional usage for protobuf manipulation
- **Network**: Minimal impact (filtered data is smaller)

### **Performance Optimization**

#### **If Performance Impact is High (> 50%)**
1. **Optimize Filtering Strategy**: Use "random" instead of "priority"
2. **Reduce Filtering Complexity**: Simplify protobuf manipulation
3. **Increase Resources**: Allocate more CPU/memory to RLS
4. **Batch Processing**: Process multiple requests together

#### **If Success Rate is Low (< 90%)**
1. **Check Configuration**: Verify selective filtering is enabled
2. **Review Limits**: Ensure limits are reasonable
3. **Check Logs**: Look for filtering errors
4. **Test Data**: Verify test data triggers limits correctly

## 🚨 **Troubleshooting**

### **Common Issues**

#### **1. Selective Filtering Not Working**
```bash
# Check if selective filtering is enabled
kubectl get configmap -n mimir-edge-enforcement mimir-rls -o yaml | grep selectiveFiltering

# Check RLS logs
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | grep "selective_filter"
```

#### **2. Metrics Not Reaching Mimir**
```bash
# Check Mimir distributor status
kubectl get pods -n mimir -l app.kubernetes.io/component=distributor

# Check Mimir logs
kubectl logs -n mimir deployment/mimir-distributor | tail -50
```

#### **3. High Performance Impact**
```bash
# Check RLS resource usage
kubectl top pod -n mimir-edge-enforcement -l app=mimir-rls

# Check RLS metrics
kubectl exec -n mimir-edge-enforcement deployment/mimir-rls -- curl -s http://localhost:9090/metrics | grep "authz_check_duration"
```

### **Debugging Steps**

1. **Verify Components**: Ensure all services are running
2. **Check Configuration**: Verify selective filtering is enabled
3. **Test Data**: Ensure test data triggers limits
4. **Monitor Logs**: Check RLS, Envoy, and Mimir logs
5. **Measure Performance**: Run performance analysis scripts
6. **Optimize**: Adjust configuration based on results

## 📋 **Verification Checklist**

### **Pre-Testing**
- [ ] All components (RLS, Envoy, Mimir) are running
- [ ] Selective filtering is configured correctly
- [ ] Test data generation is working
- [ ] Monitoring scripts are ready

### **Testing**
- [ ] Run end-to-end verification script
- [ ] Run performance impact analysis
- [ ] Verify metrics reach Mimir
- [ ] Check all component logs

### **Post-Testing**
- [ ] Review performance impact results
- [ ] Analyze success rate improvements
- [ ] Document any issues found
- [ ] Plan optimizations if needed

## 🎉 **Expected Outcomes**

### **Successful Verification**
- ✅ **Complete Pipeline**: All components work together
- ✅ **Selective Filtering**: RLS filters excess series correctly
- ✅ **Mimir Ingestion**: Filtered metrics reach Mimir
- ✅ **Performance**: Acceptable performance impact (< 20% latency increase)
- ✅ **Success Rate**: High success rate (> 90%)

### **Benefits Confirmed**
- 📈 **Reduced Data Loss**: 5-20% vs 100% data loss
- 📈 **Better User Experience**: Partial success instead of complete failure
- 📈 **Improved Monitoring**: Clear metrics and observability
- 📈 **Granular Control**: Precise filtering at series level

The end-to-end verification and performance analysis ensure that selective filtering works correctly in the complete pipeline and provides acceptable performance characteristics for production deployment.
