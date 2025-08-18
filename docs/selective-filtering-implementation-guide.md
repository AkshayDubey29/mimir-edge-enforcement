# Selective Filtering Implementation Guide

## 🎯 **Overview**

This guide provides step-by-step instructions for testing, integrating, and monitoring the RLS selective filtering implementation. The selective filtering feature enables granular filtering of metrics/series that exceed limits, rather than denying entire requests.

## 📋 **Implementation Status**

### **✅ Completed**
- ✅ **Protobuf Manipulation Functions**: All three filtering functions implemented
- ✅ **Integration with RLS**: Selective filtering integrated with existing endpoints
- ✅ **Configuration Options**: Comprehensive configuration for filtering strategies
- ✅ **Performance Monitoring**: Real-time monitoring and reporting scripts
- ✅ **Testing Framework**: Comprehensive test suite with real Prometheus data

### **🚀 Ready for Deployment**
- 🚀 **Production Ready**: All components tested and validated
- 🚀 **Configurable**: Multiple filtering strategies and options
- 🚀 **Monitored**: Performance monitoring and alerting
- 🚀 **Documented**: Complete documentation and examples

## 🧪 **Testing with Real Prometheus Data**

### **1. Run the Test Suite**

```bash
# Make script executable
chmod +x scripts/test-selective-filtering.sh

# Run comprehensive tests
./scripts/test-selective-filtering.sh
```

**Test Scenarios Covered:**
- ✅ **Per-User Series Limit**: Tests proportional filtering across metrics
- ✅ **Per-Metric Series Limit**: Tests targeted filtering for specific metrics
- ✅ **Labels Per Series Limit**: Tests label-based filtering
- ✅ **Multiple Limits**: Tests simultaneous limit violations
- ✅ **Compression Formats**: Tests gzip, snappy, and uncompressed data

### **2. Test Results**

The test script generates:
- **Test Report**: `test-results/test_report_YYYYMMDD_HHMMSS.md`
- **Performance Data**: `test-results/performance_results.csv`
- **Log Analysis**: RLS logs analysis for filtering activity

### **3. Manual Testing**

```bash
# Test with custom data
curl -X POST \
  -H "Content-Type: application/x-protobuf" \
  -H "Content-Encoding: snappy" \
  -H "X-Scope-OrgID: test-tenant" \
  -d @test-data/test_data.pb \
  http://localhost:8082/api/v1/push
```

## 🔧 **Integration with RLS Endpoints**

### **1. Configuration**

The selective filtering is automatically integrated with existing RLS endpoints. Configure it in `values-rls.yaml`:

```yaml
# Selective filtering configuration
selectiveFiltering:
  enabled: true  # Enable selective filtering
  fallbackToDeny: true  # Fall back to deny if filtering fails
  seriesSelectionStrategy: "random"  # Strategy: random, oldest, newest, priority
  metricPriority:  # Priority order for metrics
    - "critical_metrics"
    - "important_metrics" 
    - "standard_metrics"
  maxFilteringPercentage: 50  # Don't filter more than 50% of request
  minSeriesToKeep: 10  # Always keep at least 10 series
```

### **2. Deployment**

```bash
# Deploy with selective filtering enabled
helm upgrade mimir-rls charts/mimir-rls -f values-rls.yaml -n mimir-edge-enforcement

# Restart RLS pods to apply new configuration
kubectl rollout restart deployment/mimir-rls -n mimir-edge-enforcement
```

### **3. Verification**

```bash
# Check RLS logs for selective filtering activity
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | grep "selective_filter"

# Check metrics for selective filtering usage
kubectl exec -n mimir-edge-enforcement deployment/mimir-rls -- curl -s http://localhost:9090/metrics | grep "selective_filter"
```

## 📊 **Performance Monitoring**

### **1. Real-Time Monitoring**

```bash
# Start real-time monitoring dashboard
./scripts/monitor-selective-filtering-performance.sh realtime
```

**Dashboard Shows:**
- 🔄 **Live Metrics**: Selective filter requests, traditional denies/allows
- 📈 **Usage Percentage**: Percentage of requests using selective filtering
- ⚡ **Performance**: Response times and resource usage

### **2. Continuous Monitoring**

```bash
# Start continuous monitoring with logging
./scripts/monitor-selective-filtering-performance.sh monitor
```

**Features:**
- 📝 **Logging**: All metrics logged to `monitoring/selective_filtering_performance.log`
- 📊 **CSV Export**: Metrics exported to `monitoring/selective_filtering_metrics.csv`
- 📋 **Reports**: Automatic report generation every 10 iterations

### **3. Performance Reports**

```bash
# Generate performance report
./scripts/monitor-selective-filtering-performance.sh report
```

**Report Includes:**
- 📈 **Usage Trends**: Selective filtering usage over time
- 💾 **Resource Usage**: CPU and memory consumption
- 🚨 **Alerts**: Performance alerts and recommendations

## ⚙️ **Configuration Options**

### **1. Filtering Strategies**

#### **Random Selection**
```yaml
seriesSelectionStrategy: "random"
```
- **Description**: Randomly selects series to drop
- **Use Case**: When all series have equal importance
- **Performance**: Fastest execution

#### **Oldest First**
```yaml
seriesSelectionStrategy: "oldest"
```
- **Description**: Drops oldest series first
- **Use Case**: When newer data is more important
- **Performance**: Requires timestamp analysis

#### **Newest First**
```yaml
seriesSelectionStrategy: "newest"
```
- **Description**: Drops newest series first
- **Use Case**: When historical data is more important
- **Performance**: Requires timestamp analysis

#### **Priority-Based**
```yaml
seriesSelectionStrategy: "priority"
metricPriority:
  - "critical_metrics"
  - "important_metrics"
  - "standard_metrics"
```
- **Description**: Drops based on metric priority
- **Use Case**: When certain metrics are more important
- **Performance**: Requires priority lookup

### **2. Safety Limits**

#### **Maximum Filtering Percentage**
```yaml
maxFilteringPercentage: 50
```
- **Description**: Don't filter more than 50% of request
- **Purpose**: Prevent excessive data loss
- **Default**: 50%

#### **Minimum Series to Keep**
```yaml
minSeriesToKeep: 10
```
- **Description**: Always keep at least 10 series
- **Purpose**: Ensure some data always passes through
- **Default**: 10

### **3. Fallback Behavior**

```yaml
fallbackToDeny: true
```
- **Description**: Fall back to deny if filtering fails
- **Purpose**: Ensure limits are enforced even if filtering fails
- **Default**: true

## 📈 **Performance Optimization**

### **1. Monitoring Key Metrics**

#### **Selective Filter Usage**
- **Target**: 10-30% of requests using selective filtering
- **Alert**: If usage < 5% (not effective) or > 50% (too aggressive)

#### **Response Time Impact**
- **Target**: < 100ms additional latency for filtering
- **Alert**: If filtering adds > 500ms latency

#### **Resource Usage**
- **Target**: < 20% additional CPU/memory for filtering
- **Alert**: If filtering uses > 50% additional resources

### **2. Optimization Strategies**

#### **Strategy Selection**
```yaml
# For high-performance environments
seriesSelectionStrategy: "random"

# For data-critical environments  
seriesSelectionStrategy: "priority"
```

#### **Batch Processing**
- **Description**: Process multiple requests in batches
- **Benefit**: Reduced overhead per request
- **Configuration**: Adjust batch sizes based on load

#### **Caching**
- **Description**: Cache filtering decisions for similar requests
- **Benefit**: Reduced computation overhead
- **Implementation**: Cache based on request hash

### **3. Scaling Considerations**

#### **Horizontal Scaling**
- **Description**: Scale RLS pods based on filtering load
- **Configuration**: Adjust HPA based on selective filtering metrics
- **Monitoring**: Track filtering load per pod

#### **Resource Allocation**
- **CPU**: Increase CPU limits if filtering is CPU-intensive
- **Memory**: Increase memory limits for large request processing
- **Network**: Monitor network usage for filtered data transmission

## 🚨 **Alerting and Troubleshooting**

### **1. Key Alerts**

#### **High Error Rate**
```bash
# Check error rate in logs
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | grep -c "ERROR"
```
- **Threshold**: > 10% error rate
- **Action**: Check RLS logs for filtering errors

#### **Low Selective Filter Usage**
```bash
# Check selective filter usage
kubectl exec -n mimir-edge-enforcement deployment/mimir-rls -- curl -s http://localhost:9090/metrics | grep "selective_filter"
```
- **Threshold**: < 5% usage
- **Action**: Verify configuration and test data

#### **High Resource Usage**
```bash
# Check resource usage
kubectl top pod -n mimir-edge-enforcement -l app=mimir-rls
```
- **Threshold**: > 80% CPU or Memory
- **Action**: Scale up resources or optimize filtering

### **2. Common Issues**

#### **Filtering Not Working**
```bash
# Check if selective filtering is enabled
kubectl get configmap -n mimir-edge-enforcement mimir-rls -o yaml | grep selectiveFiltering

# Check RLS logs
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | grep "selective_filter"
```

#### **Performance Issues**
```bash
# Check response times
kubectl exec -n mimir-edge-enforcement deployment/mimir-rls -- curl -s http://localhost:9090/metrics | grep "authz_check_duration"

# Check resource usage
kubectl top pod -n mimir-edge-enforcement -l app=mimir-rls
```

#### **Data Loss Issues**
```bash
# Check filtering statistics
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | grep "Successfully filtered"

# Verify configuration limits
kubectl get configmap -n mimir-edge-enforcement mimir-rls -o yaml | grep -A 10 selectiveFiltering
```

## 📋 **Deployment Checklist**

### **Pre-Deployment**
- [ ] **Testing**: Run comprehensive test suite
- [ ] **Configuration**: Review and set selective filtering configuration
- [ ] **Monitoring**: Set up performance monitoring
- [ ] **Backup**: Backup current RLS configuration

### **Deployment**
- [ ] **Update Configuration**: Deploy with selective filtering enabled
- [ ] **Verify Deployment**: Check RLS pods are running
- [ ] **Test Integration**: Verify selective filtering is working
- [ ] **Monitor Performance**: Start performance monitoring

### **Post-Deployment**
- [ ] **Monitor Usage**: Track selective filtering usage
- [ ] **Optimize Performance**: Adjust configuration based on metrics
- [ ] **Document Results**: Record performance improvements
- [ ] **Plan Scaling**: Plan for increased load

## 🎉 **Expected Results**

### **Before Selective Filtering**
- ❌ **100% Data Loss**: Entire requests denied when limits exceeded
- ❌ **Poor User Experience**: Complete failures for limit violations
- ❌ **Difficult Monitoring**: Hard to distinguish between different error types

### **After Selective Filtering**
- ✅ **Minimal Data Loss**: Only excess data dropped (5-20% vs 100%)
- ✅ **Better User Experience**: Partial success instead of complete failure
- ✅ **Improved Monitoring**: Clear distinction between error types
- ✅ **Granular Control**: Precise filtering at series level

### **Performance Improvements**
- 📈 **Reduced 413/429 Errors**: More requests pass through successfully
- 📈 **Better Resource Utilization**: More efficient use of system resources
- 📈 **Improved Observability**: Detailed metrics and monitoring
- 📈 **Enhanced Debugging**: Better error messages and logging

## 🚀 **Next Steps**

1. **Deploy to Production**: Follow the deployment checklist
2. **Monitor Performance**: Use the monitoring scripts
3. **Optimize Configuration**: Adjust based on real-world usage
4. **Scale as Needed**: Plan for increased load
5. **Document Learnings**: Share results and best practices

The selective filtering implementation is now ready for production deployment! 🎉
