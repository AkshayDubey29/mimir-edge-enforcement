# Protobuf Manipulation Implementation for Selective Filtering

## 🎯 **Overview**

Successfully implemented the actual protobuf manipulation functions for RLS selective filtering. These functions enable granular filtering of metrics/series that exceed limits, rather than denying entire requests.

## 🔧 **Implemented Functions**

### **1. `filterExcessSeries()` - Proportional Series Filtering**

**Purpose**: Filters out excess series proportionally across all metrics when per-user series limit is exceeded.

**Algorithm**:
```go
// Example: User has 1000 series limit, sends 1050 series (50 excess)
// Distribute the 50 excess series proportionally across metrics:
// - Metric A: 400 series → drop 20 series (50 * 400/1000)
// - Metric B: 300 series → drop 15 series (50 * 300/1000)  
// - Metric C: 350 series → drop 15 series (50 * 350/1000)
```

**Implementation Steps**:
1. **Decompress** the request body
2. **Parse** the protobuf into `WriteRequest` structure
3. **Group series** by metric name
4. **Calculate proportional drops** for each metric
5. **Filter series** based on calculated drops
6. **Reconstruct** the protobuf
7. **Re-compress** if original was compressed

**Key Features**:
- ✅ **Proportional distribution**: Excess series are dropped proportionally across metrics
- ✅ **Fair filtering**: No single metric bears the entire burden
- ✅ **Preserves structure**: Maintains protobuf format and compression

### **2. `filterMetricSeries()` - Metric-Specific Filtering**

**Purpose**: Filters out excess series for a specific metric when per-metric series limit is exceeded.

**Algorithm**:
```go
// Example: Metric "http_requests" has 100 series limit
// Current: 95 series, New: 10 series → Total: 105 series
// Excess: 5 series
// Result: Drop 5 series from "http_requests" only
```

**Implementation Steps**:
1. **Decompress** the request body
2. **Parse** the protobuf into `WriteRequest` structure
3. **Identify series** for the target metric
4. **Calculate excess** series for that metric
5. **Filter series** for the specific metric only
6. **Reconstruct** the protobuf
7. **Re-compress** if original was compressed

**Key Features**:
- ✅ **Targeted filtering**: Only affects the specific metric that exceeded limits
- ✅ **Other metrics unaffected**: Series for other metrics pass through unchanged
- ✅ **Precise control**: Exact number of excess series are dropped

### **3. `filterExcessLabels()` - Label Limit Filtering**

**Purpose**: Filters out series with too many labels when labels per series limit is exceeded.

**Algorithm**:
```go
// Example: Label limit is 15 labels per series
// Series A: 20 labels → Drop (exceeds limit by 5)
// Series B: 12 labels → Keep (within limit)
// Series C: 18 labels → Drop (exceeds limit by 3)
```

**Implementation Steps**:
1. **Decompress** the request body
2. **Parse** the protobuf into `WriteRequest` structure
3. **Identify series** with too many labels
4. **Calculate excess** labels
5. **Filter series** with excess labels
6. **Reconstruct** the protobuf
7. **Re-compress** if original was compressed

**Key Features**:
- ✅ **Label-based filtering**: Filters based on label count per series
- ✅ **Configurable limit**: Uses tenant-specific label limits
- ✅ **Series-level granularity**: Drops individual series, not entire metrics

## 🔧 **Helper Functions**

### **1. `decompressBody()`**
```go
func decompressBody(body []byte, contentEncoding string) ([]byte, error)
```
- Supports **gzip**, **snappy**, and **uncompressed** formats
- Handles decompression errors gracefully
- Returns original body for unsupported encodings

### **2. `compressBody()`**
```go
func compressBody(body []byte, contentEncoding string) ([]byte, error)
```
- Re-compresses filtered data in the same format as original
- Maintains compression efficiency
- Handles compression errors gracefully

### **3. `extractMetricNameFromLabels()`**
```go
func extractMetricNameFromLabels(labels []*prompb.Label) string
```
- Extracts metric name from `__name__` label
- Returns "unknown_metric" if `__name__` label not found
- Essential for metric-based filtering

## 📊 **Filtering Examples**

### **Example 1: Per-User Series Limit**
```
User Limit: 1000 series
Current Series: 950
New Request: 100 series
Total: 1050 series
Excess: 50 series

Filtering Result:
- Metric "cpu_usage": 400 series → drop 20 series
- Metric "memory_usage": 300 series → drop 15 series  
- Metric "disk_io": 300 series → drop 15 series
- Total dropped: 50 series
- Series passing through: 1000 series
```

### **Example 2: Per-Metric Series Limit**
```
Metric "http_requests" Limit: 100 series
Current "http_requests" Series: 95
New "http_requests" Series: 10
Total: 105 series
Excess: 5 series

Filtering Result:
- "http_requests": 95 series pass through, 5 series dropped
- Other metrics: Unaffected
- Total dropped: 5 series
```

### **Example 3: Labels Per Series Limit**
```
Label Limit: 15 labels per series
Series A: 20 labels → Drop
Series B: 12 labels → Keep
Series C: 18 labels → Drop
Series D: 10 labels → Keep

Filtering Result:
- Series A: Dropped (exceeds limit by 5)
- Series B: Pass through (within limit)
- Series C: Dropped (exceeds limit by 3)
- Series D: Pass through (within limit)
```

## 🎯 **Benefits of Implementation**

### **1. Reduced Data Loss**
- **Before**: 100% data loss when limits exceeded
- **After**: Only excess data is dropped (e.g., 5% loss instead of 100%)

### **2. Granular Control**
- **Per-user limits**: Proportional filtering across all metrics
- **Per-metric limits**: Targeted filtering for specific metrics
- **Label limits**: Series-level filtering based on label count

### **3. Maintains Data Integrity**
- **Protobuf structure**: Preserved during filtering
- **Compression**: Maintained or re-applied as needed
- **Series relationships**: Kept intact for remaining series

### **4. Comprehensive Logging**
- **Detailed statistics**: Original vs filtered counts
- **Filtering reasons**: Clear indication of why series were dropped
- **Performance metrics**: Timing and efficiency information

## 🔧 **Error Handling**

### **Graceful Degradation**
```go
// If any step fails, return original body and log error
if err != nil {
    rls.logger.Error().Err(err).Msg("RLS: Failed to filter series")
    return body, 0 // Return original body unchanged
}
```

### **Fallback Mechanisms**
- **Decompression failure**: Return original body
- **Protobuf parsing failure**: Return original body
- **Serialization failure**: Return original body
- **Compression failure**: Return original body

## 📈 **Performance Considerations**

### **Memory Efficiency**
- **Streaming processing**: Process series one by one
- **Minimal allocations**: Reuse buffers where possible
- **Early termination**: Stop processing when limit reached

### **CPU Optimization**
- **Efficient parsing**: Use protobuf unmarshaling
- **Smart filtering**: Calculate drops once, apply efficiently
- **Compression reuse**: Maintain original compression format

## 🚀 **Integration Points**

### **1. RLS Service Integration**
```go
// In SelectiveFilterRequest function
filteredBody, droppedSeries := rls.filterExcessSeries(body, contentEncoding, excessSeries, parseResult)
result.FilteredBody = filteredBody
result.DroppedSeries = droppedSeries
```

### **2. Metrics and Monitoring**
```go
// Record filtering statistics
rls.metrics.LimitViolationsTotal.WithLabelValues(tenantID, "selective_filtering").Inc()
rls.metrics.SamplesCountGauge.WithLabelValues(tenantID).Set(float64(result.FilteredSamples))
```

### **3. Logging and Debugging**
```go
// Comprehensive logging for debugging
rls.logger.Info().
    Int64("excess_series", excessSeries).
    Int64("dropped_series", droppedCount).
    Int("original_series", len(writeRequest.Timeseries)).
    Int("filtered_series", len(filteredTimeseries)).
    Msg("RLS: Successfully filtered excess series")
```

## 🎉 **Summary**

The protobuf manipulation implementation provides:

- ✅ **Complete selective filtering**: All three filtering functions implemented
- ✅ **Robust error handling**: Graceful degradation on failures
- ✅ **Performance optimized**: Efficient protobuf manipulation
- ✅ **Comprehensive logging**: Detailed statistics and debugging info
- ✅ **Compression support**: Handles gzip and snappy compression
- ✅ **Granular control**: Precise filtering at series level

This implementation transforms RLS from a binary allow/deny system to a sophisticated filtering system that minimizes data loss while enforcing limits effectively!
