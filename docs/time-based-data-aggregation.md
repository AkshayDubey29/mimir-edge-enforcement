# Time-Based Data Aggregation and Caching Solution

## Problem Statement

The UI data in the Overview page and Cardinality Dashboard was unstable and changing frequently, making it difficult to get consistent metrics. The system needed:

1. **Time-based data aggregation** - Data should be aggregated over specific time periods (15m, 1h, 24h, 1w)
2. **Stable data within time frames** - Data should remain consistent within the selected time range
3. **Proper caching** - Backend should cache aggregated data to serve fresh and actual data within time frames
4. **Reduced UI refresh frequency** - UI should not fetch data too frequently

## Solution Overview

### 1. Backend Enhancements

#### Time Aggregator
- **15-minute buckets** (96 buckets for 24 hours)
- **1-hour buckets** (168 buckets for 1 week)  
- **24-hour buckets** (30 buckets for 1 month)
- **1-week buckets** (52 buckets for 1 year)

#### Caching System
- **In-memory cache** with TTL (Time To Live)
- **Time-range specific TTL**:
  - 15m/5m: 30 seconds
  - 1h: 2 minutes
  - 24h: 5 minutes
  - 1w: 10 minutes
- **Automatic cache cleanup** every 5 minutes

#### API Enhancements
- **Time range support** in all API endpoints
- **Query parameter**: `?range=1h`
- **Valid ranges**: `5m`, `15m`, `1h`, `24h`, `1w`
- **Default range**: `1h`

### 2. Frontend Improvements

#### Time Range Selector
- **Dropdown selector** in Overview and Cardinality pages
- **Options**: 15 Minutes, 1 Hour, 24 Hours, 1 Week
- **Real-time switching** between time ranges

#### Reduced Refresh Frequency
- **Overview page**: 5 minutes (increased from 60 seconds)
- **Cardinality page**: 5 minutes (increased from 10 seconds)
- **Cache time**: 10 minutes
- **Stale time**: 3 minutes

#### Better Error Handling
- **Graceful fallbacks** when API calls fail
- **Safe defaults** for all data structures
- **User-friendly error messages**

## Implementation Details

### Backend Changes

#### 1. Time Aggregator (`services/rls/internal/service/rls.go`)

```go
type TimeAggregator struct {
    mu sync.RWMutex
    buckets15min map[string]*TimeBucket
    buckets1h    map[string]*TimeBucket
    buckets24h   map[string]*TimeBucket
    buckets1w    map[string]*TimeBucket
}

type TimeBucket struct {
    StartTime         time.Time
    EndTime           time.Time
    TotalRequests     int64
    AllowedRequests   int64
    DeniedRequests    int64
    TotalSeries       int64
    TotalLabels       int64
    Violations        int64
    AvgResponseTime   float64
    MaxResponseTime   float64
    MinResponseTime   float64
    ResponseTimeCount int64
}
```

#### 2. Caching System

```go
type CacheEntry struct {
    Data      interface{}
    Timestamp time.Time
    TTL       time.Duration
}

func (rls *RLS) GetCachedData(key string) (interface{}, bool)
func (rls *RLS) SetCachedData(key string, data interface{}, ttl time.Duration)
func (rls *RLS) CleanupExpiredCache()
```

#### 3. Enhanced API Methods

```go
func (rls *RLS) GetOverviewSnapshotWithTimeRange(timeRange string) limits.OverviewStats
func (rls *RLS) GetTenantsWithTimeRange(timeRange string) []limits.TenantInfo
```

### Frontend Changes

#### 1. Overview Page (`ui/admin/src/pages/Overview.tsx`)

```typescript
const { data: overviewData, isLoading, error } = useQuery<OverviewData>(
  ['overview', timeRange],
  () => fetchOverviewData(timeRange),
  {
    refetchInterval: 300000, // 5 minutes
    refetchIntervalInBackground: true,
    staleTime: 180000, // 3 minutes
    cacheTime: 600000, // 10 minutes
  }
);
```

#### 2. Time Range Selector

```typescript
const timeRangeOptions = [
  { value: '15m', label: '15 Minutes' },
  { value: '1h', label: '1 Hour' },
  { value: '24h', label: '24 Hours' },
  { value: '1w', label: '1 Week' },
];
```

#### 3. Enhanced API Calls

```typescript
async function fetchOverviewData(timeRange: string): Promise<OverviewData> {
  const overviewResponse = await fetch(`/api/overview?range=${timeRange}`);
  const tenantsResponse = await fetch(`/api/tenants?range=${timeRange}`);
  // ... rest of implementation
}
```

## API Endpoints

### Overview API
```
GET /api/overview?range=1h
```

**Response:**
```json
{
  "stats": {
    "total_requests": 1234,
    "allowed_requests": 1200,
    "denied_requests": 34,
    "allow_percentage": 97.2,
    "active_tenants": 5
  },
  "time_range": "1h",
  "data_freshness": "2024-01-15T10:30:00Z"
}
```

### Tenants API
```
GET /api/tenants?range=1h
```

**Response:**
```json
{
  "tenants": [
    {
      "id": "tenant-1",
      "name": "Production Tenant",
      "limits": {
        "samples_per_second": 1000
      },
      "metrics": {
        "rps": 50.5,
        "allow_rate": 95.2,
        "deny_rate": 4.8
      }
    }
  ],
  "time_range": "1h",
  "data_freshness": "2024-01-15T10:30:00Z"
}
```

## Testing

### Test Script
Run the test script to verify the solution:

```bash
./scripts/test-time-based-data.sh
```

### Manual Testing

1. **Start the RLS service:**
   ```bash
   cd services/rls && ./rls
   ```

2. **Test API endpoints:**
   ```bash
   curl "http://localhost:8082/api/overview?range=1h"
   curl "http://localhost:8082/api/tenants?range=1h"
   ```

3. **Test different time ranges:**
   ```bash
   curl "http://localhost:8082/api/overview?range=15m"
   curl "http://localhost:8082/api/overview?range=24h"
   curl "http://localhost:8082/api/overview?range=1w"
   ```

4. **Test caching:**
   ```bash
   # Make rapid requests to see cached responses
   for i in {1..5}; do
     curl -s "http://localhost:8082/api/overview?range=1h" | jq '.stats.total_requests'
     sleep 0.1
   done
   ```

## Benefits

### 1. Data Stability
- **Consistent metrics** within time frames
- **No more fluctuating numbers** in the UI
- **Predictable data** for monitoring and alerting

### 2. Performance
- **Reduced API calls** (5-minute intervals vs 10-60 seconds)
- **Cached responses** reduce backend load
- **Faster UI rendering** with stable data

### 3. User Experience
- **Time range selection** for different analysis needs
- **Stable dashboard** that doesn't constantly change
- **Better monitoring** with consistent metrics

### 4. Scalability
- **Efficient data aggregation** over time periods
- **Memory-efficient caching** with automatic cleanup
- **Horizontal scaling** ready with time-based buckets

## Configuration

### Time Range Mapping
- `5m` → `15m` (minimum bucket size)
- `15m` → `15m`
- `1h` → `1h`
- `24h` → `24h`
- `1w` → `1w`

### Cache TTL Settings
- **15m/5m**: 30 seconds
- **1h**: 2 minutes
- **24h**: 5 minutes
- **1w**: 10 minutes

### UI Refresh Intervals
- **Overview page**: 5 minutes
- **Cardinality page**: 5 minutes
- **Cache time**: 10 minutes
- **Stale time**: 3 minutes

## Monitoring

### Cache Metrics
- Cache hit/miss ratios
- Cache size and memory usage
- Expired entry cleanup frequency

### API Performance
- Response times for different time ranges
- Cache effectiveness
- Data aggregation performance

### Data Quality
- Time bucket completeness
- Data freshness indicators
- Aggregation accuracy

## Future Enhancements

1. **Persistent caching** with Redis
2. **More granular time ranges** (5m, 30m, 6h, etc.)
3. **Custom time range selection**
4. **Historical data retention** for longer periods
5. **Real-time streaming** for live data updates
6. **Advanced aggregation functions** (percentiles, moving averages)

## Troubleshooting

### Common Issues

1. **Data not updating:**
   - Check cache TTL settings
   - Verify time bucket aggregation
   - Monitor cache cleanup

2. **High memory usage:**
   - Adjust cache TTL values
   - Increase cache cleanup frequency
   - Monitor bucket retention

3. **API timeouts:**
   - Check aggregation performance
   - Optimize bucket queries
   - Consider caching more aggressively

### Debug Endpoints

```bash
# Check cache status
curl "http://localhost:8082/api/debug/cache"

# Check time aggregator status
curl "http://localhost:8082/api/debug/time-aggregator"

# Check system health
curl "http://localhost:8082/api/health"
```

## Conclusion

This solution provides stable, time-based data aggregation with intelligent caching, significantly improving the user experience and system performance. The UI now shows consistent metrics within selected time frames, making it much more useful for monitoring and analysis.
