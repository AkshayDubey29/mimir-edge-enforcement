# Selective Filtering Approach for RLS

## 🎯 **Problem Statement**

You correctly identified that the current RLS logic is too aggressive. Currently, when any limit is exceeded, the entire request is denied. This is inefficient and causes unnecessary data loss.

**Current Behavior (Incorrect):**
- User has limit of 100 series
- User sends 103 series
- **Result**: All 103 series are dropped ❌

**Desired Behavior (Correct):**
- User has limit of 100 series  
- User sends 103 series
- **Result**: Only 3 excess series are dropped, 100 series pass through ✅

## 🔧 **Selective Filtering Approach**

### **Core Concept**
Instead of denying entire requests, RLS should:
1. **Parse the entire request** to understand what's being sent
2. **Check each metric/series individually** against limits
3. **Filter out only the problematic metrics/series** that exceed limits
4. **Allow the rest of the request** to pass through

### **Implementation Strategy**

#### **1. Request Analysis Phase**
```go
// Parse the entire request to understand structure
parseResult, err := parser.ParseRemoteWriteRequest(body, contentEncoding)
if err != nil {
    // Fall back to original logic if parsing fails
    return rls.CheckRemoteWriteLimits(tenantID, body, contentEncoding)
}
```

#### **2. Limit Checking Phase**
For each limit type, check if any part of the request exceeds it:

- **Per-User Series Limit**: Total series across all metrics
- **Per-Metric Series Limit**: Series count per individual metric
- **Labels Per Series Limit**: Series with too many labels
- **Body Size Limit**: Overall request size

#### **3. Selective Filtering Phase**
For each limit violation, apply specific filtering:

```go
// Example: Per-user series limit exceeded
if projectedTotal > limit {
    excessSeries := projectedTotal - limit
    filteredBody, droppedSeries := rls.filterExcessSeries(body, excessSeries)
    // Continue with filtered body
}
```

#### **4. Request Reconstruction Phase**
Rebuild the protobuf with only the allowed series and re-compress if needed.

## 📊 **Detailed Filtering Logic**

### **1. Per-User Series Limit Filtering**
```go
// Scenario: User has 100 series limit, sends 103 series
currentSeries := 95  // Existing series
newSeries := 8      // New series in request
projectedTotal := 95 + 8 = 103
limit := 100
excessSeries := 103 - 100 = 3

// Action: Drop 3 series proportionally across metrics
// Result: 100 series pass through, 3 series dropped
```

### **2. Per-Metric Series Limit Filtering**
```go
// Scenario: Metric "http_requests" has 50 series limit
currentMetricSeries := 48  // Existing series for this metric
newMetricSeries := 5       // New series for this metric in request
projectedTotal := 48 + 5 = 53
limit := 50
excessSeries := 53 - 50 = 3

// Action: Drop 3 series from "http_requests" metric only
// Result: Other metrics unaffected, only "http_requests" filtered
```

### **3. Labels Per Series Filtering**
```go
// Scenario: Series has 20 labels, limit is 15
labelsCount := 20
limit := 15
excessLabels := 20 - 15 = 5

// Action: Drop series with more than 15 labels
// Result: Series with ≤15 labels pass through
```

## 🔧 **Implementation Status**

### **✅ Completed**
- ✅ **Framework Structure**: Added `SelectiveFilterRequest` function
- ✅ **Limit Checking Logic**: Implemented all limit checks
- ✅ **Statistics Tracking**: Added detailed filtering statistics
- ✅ **Logging**: Comprehensive logging for debugging
- ✅ **Fallback Logic**: Falls back to original logic if parsing fails

### **🔄 In Progress**
- 🔄 **Protobuf Parsing**: Need to implement actual protobuf manipulation
- 🔄 **Series Filtering**: Need to implement `filterExcessSeries`
- 🔄 **Metric Filtering**: Need to implement `filterMetricSeries`
- 🔄 **Label Filtering**: Need to implement `filterExcessLabels`

### **📋 To Be Implemented**

#### **1. Protobuf Manipulation Functions**
```go
// Need to implement these functions:
func (rls *RLS) filterExcessSeries(body []byte, contentEncoding string, excessSeries int64, parseResult *parser.ParseResult) ([]byte, int64)
func (rls *RLS) filterMetricSeries(body []byte, contentEncoding string, metricName string, excessSeries int64, parseResult *parser.ParseResult) ([]byte, int64)
func (rls *RLS) filterExcessLabels(body []byte, contentEncoding string, excessLabels int64, parseResult *parser.ParseResult) ([]byte, int64)
```

#### **2. Protobuf Reconstruction**
```go
// Steps needed:
// 1. Parse protobuf into WriteRequest structure
// 2. Identify which TimeSeries to keep/drop
// 3. Reconstruct WriteRequest with only allowed series
// 4. Re-compress if original was compressed
// 5. Return filtered body
```

#### **3. Series Selection Strategy**
```go
// Need to decide how to select which series to drop:
// - Random selection
// - Oldest first
// - Newest first
// - Based on metric priority
// - Based on series value/importance
```

## 🎯 **Benefits of Selective Filtering**

### **1. Reduced Data Loss**
- **Before**: 100% data loss when limits exceeded
- **After**: Only excess data is dropped

### **2. Better User Experience**
- Users get partial success instead of complete failure
- More predictable behavior
- Easier to understand what was accepted/rejected

### **3. Improved Monitoring**
- Detailed statistics on what was filtered
- Better capacity planning
- More accurate limit tuning

### **4. Graceful Degradation**
- System continues to function even when limits are exceeded
- Gradual degradation instead of hard failures

## 📈 **Example Scenarios**

### **Scenario 1: Per-User Series Limit**
```
User Limit: 1000 series
Current Series: 950
New Request: 100 series
Total: 1050 series
Excess: 50 series

Result: 50 series dropped, 1000 series pass through
```

### **Scenario 2: Per-Metric Series Limit**
```
Metric "cpu_usage" Limit: 100 series
Current "cpu_usage" Series: 95
New "cpu_usage" Series: 10
Total: 105 series
Excess: 5 series

Result: 5 "cpu_usage" series dropped, other metrics unaffected
```

### **Scenario 3: Multiple Limit Violations**
```
Per-User Limit: 1000 series (exceeded by 50)
Per-Metric Limit: 100 series for "http_requests" (exceeded by 10)
Labels Limit: 15 labels (5 series exceed by 3 labels each)

Result: 
- 50 series dropped for per-user limit
- 10 "http_requests" series dropped for per-metric limit  
- 5 series dropped for label limit
- Remaining series pass through
```

## 🚀 **Next Steps**

### **Phase 1: Protobuf Manipulation**
1. Implement protobuf parsing and reconstruction
2. Add series selection strategies
3. Handle compression/decompression

### **Phase 2: Integration**
1. Integrate with existing RLS endpoints
2. Add configuration options for selective filtering
3. Update metrics and monitoring

### **Phase 3: Testing**
1. Unit tests for filtering logic
2. Integration tests with real Prometheus data
3. Performance testing

### **Phase 4: Deployment**
1. Gradual rollout with feature flags
2. Monitor effectiveness
3. Tune filtering strategies

## 📋 **Configuration Options**

### **Enable Selective Filtering**
```yaml
enforcement:
  selectiveFiltering:
    enabled: true
    fallbackToDeny: true  # Fall back to deny if filtering fails
```

### **Series Selection Strategy**
```yaml
enforcement:
  selectiveFiltering:
    seriesSelectionStrategy: "random"  # random, oldest, newest, priority
    metricPriority: ["critical_metrics", "important_metrics"]
```

### **Filtering Thresholds**
```yaml
enforcement:
  selectiveFiltering:
    maxFilteringPercentage: 50  # Don't filter more than 50% of request
    minSeriesToKeep: 10         # Always keep at least 10 series
```

## 🎉 **Summary**

The selective filtering approach will transform RLS from a binary allow/deny system to a sophisticated filtering system that:

- ✅ **Minimizes data loss** by only dropping excess data
- ✅ **Improves user experience** with partial success
- ✅ **Provides better monitoring** with detailed statistics
- ✅ **Enables graceful degradation** instead of hard failures

This approach aligns perfectly with your requirement to drop only the specific metrics/series that cross limits, rather than entire requests.
