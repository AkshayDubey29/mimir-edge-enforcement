# Core Features - Mimir Edge Enforcement

## Overview

This document provides a comprehensive overview of the core features and capabilities of the Mimir Edge Enforcement system, including detailed explanations, use cases, and implementation details.

## Feature Categories

### 1. Rate Limiting and Quota Management

#### Selective Traffic Routing

**Description**: Intelligent routing of traffic based on user identity, allowing selective application of rate limiting to specific users while bypassing others.

**Implementation**:
```nginx
# NGINX Configuration
map $remote_user $route_decision {
    "boltx"      "edge";
    "cloudwatch" "edge";
    default      "direct";
}

location /api/v1/push {
    if ($route_decision = "edge") {
        proxy_pass http://mimir_rls;
        add_header X-Edge-Enforcement "selective";
    }
    if ($route_decision = "direct") {
        proxy_pass http://mimir_direct;
        add_header X-Edge-Enforcement "none";
    }
    add_header X-Route-Decision $route_decision;
}
```

**Use Cases**:
- **Cost Control**: Apply rate limiting to high-volume users to control costs
- **Resource Protection**: Protect critical infrastructure from resource exhaustion
- **Fair Usage**: Ensure fair resource allocation across tenants
- **Compliance**: Meet regulatory requirements for resource usage

**Benefits**:
- **Flexibility**: Granular control over which users are rate limited
- **Transparency**: Clear visibility into routing decisions
- **Performance**: Minimal overhead for non-rate-limited traffic
- **Scalability**: Easy to add or remove users from rate limiting

#### Token Bucket Rate Limiting

**Description**: Implementation of the token bucket algorithm for efficient and fair rate limiting with burst support.

**Implementation**:
```go
// Token Bucket Implementation
type TokenBucket struct {
    capacity     int64
    tokens       int64
    refillRate   float64
    lastRefill   time.Time
    mutex        sync.RWMutex
}

func (tb *TokenBucket) Take(tokens int64) bool {
    tb.mutex.Lock()
    defer tb.mutex.Unlock()
    
    // Refill tokens based on time elapsed
    now := time.Now()
    elapsed := now.Sub(tb.lastRefill).Seconds()
    newTokens := int64(elapsed * tb.refillRate)
    
    if newTokens > 0 {
        tb.tokens = min(tb.capacity, tb.tokens+newTokens)
        tb.lastRefill = now
    }
    
    // Check if enough tokens available
    if tb.tokens >= tokens {
        tb.tokens -= tokens
        return true
    }
    
    return false
}
```

**Features**:
- **Burst Support**: Allow temporary bursts above the sustained rate
- **Fair Distribution**: Ensure fair token distribution across tenants
- **Configurable Parameters**: Adjustable capacity and refill rates
- **Real-time Updates**: Dynamic rate limit adjustments

**Configuration**:
```yaml
# Rate Limiting Configuration
rate_limits:
  tenant_default:
    requests_per_second: 1000
    burst_capacity: 2000
    refill_rate: 1000.0
    
  tenant_premium:
    requests_per_second: 5000
    burst_capacity: 10000
    refill_rate: 5000.0
```

#### Multi-Tenant Quota Management

**Description**: Comprehensive quota management system that enforces tenant-specific limits on various resources.

**Implementation**:
```go
// Tenant Quota Structure
type TenantQuota struct {
    TenantID           string    `json:"tenant_id"`
    MaxRequestsPerSec  int64     `json:"max_requests_per_sec"`
    MaxSamplesPerSec   int64     `json:"max_samples_per_sec"`
    MaxBytesPerSec     int64     `json:"max_bytes_per_sec"`
    MaxSeriesPerMetric int64     `json:"max_series_per_metric"`
    MaxMetricsPerTenant int64    `json:"max_metrics_per_tenant"`
    SoftLimit          bool      `json:"soft_limit"`
    HardLimit          bool      `json:"hard_limit"`
}

// Quota Enforcement
func (rls *RateLimitService) enforceQuota(tenant *TenantInfo, request *MetricRequest) error {
    quota := rls.getTenantQuota(tenant.ID)
    
    // Check various quota limits
    if err := rls.checkRequestRate(tenant, quota); err != nil {
        return err
    }
    
    if err := rls.checkSampleRate(tenant, quota); err != nil {
        return err
    }
    
    if err := rls.checkByteRate(tenant, quota); err != nil {
        return err
    }
    
    return nil
}
```

**Quota Types**:
- **Request Rate**: Maximum requests per second
- **Sample Rate**: Maximum samples per second
- **Byte Rate**: Maximum bytes per second
- **Series Limit**: Maximum series per metric
- **Metric Limit**: Maximum metrics per tenant

### 2. Time-Based Aggregation

#### Intelligent Metric Aggregation

**Description**: Advanced time-based aggregation system that provides intelligent caching and metric calculation over various time ranges.

**Implementation**:
```go
// Time Aggregator Structure
type TimeAggregator struct {
    windows    map[string]*TimeWindow
    cache      *Cache
    mutex      sync.RWMutex
}

type TimeWindow struct {
    Start     time.Time
    End       time.Time
    Metrics   map[string]float64
    Count     int64
    LastUpdate time.Time
}

// Aggregation Methods
func (ta *TimeAggregator) RecordDecision(tenantID string, decision Decision, timestamp time.Time) {
    ta.mutex.Lock()
    defer ta.mutex.Unlock()
    
    // Update all relevant time windows
    for windowKey, window := range ta.windows {
        if timestamp.After(window.Start) && timestamp.Before(window.End) {
            ta.updateWindow(windowKey, tenantID, decision)
        }
    }
}

func (ta *TimeAggregator) GetTenantAggregatedData(tenantID, timeRange string) map[string]interface{} {
    normalizedRange := ta.normalizeTimeRange(timeRange)
    window := ta.getOrCreateWindow(normalizedRange)
    
    return map[string]interface{}{
        "rps":             ta.calculateRPS(window, tenantID),
        "allow_rate":      ta.calculateAllowRate(window, tenantID),
        "deny_rate":       ta.calculateDenyRate(window, tenantID),
        "samples_per_sec": ta.calculateSamplesPerSec(window, tenantID),
        "bytes_per_sec":   ta.calculateBytesPerSec(window, tenantID),
        "utilization_pct": ta.calculateUtilization(window, tenantID),
    }
}
```

**Time Ranges**:
- **1 Minute**: Real-time monitoring
- **5 Minutes**: Short-term trends
- **1 Hour**: Medium-term analysis
- **24 Hours**: Daily patterns
- **7 Days**: Weekly trends
- **30 Days**: Monthly analysis

**Aggregation Functions**:
- **Rate Calculation**: Requests per second, samples per second
- **Percentage Calculation**: Allow rate, deny rate, utilization
- **Statistical Functions**: Min, max, average, percentiles
- **Trend Analysis**: Rate of change, acceleration

#### Caching Strategy

**Description**: Multi-level caching system that optimizes performance while maintaining data accuracy.

**Implementation**:
```go
// Cache Levels
type CacheLevel int

const (
    Level1Cache CacheLevel = iota // In-memory cache
    Level2Cache                   // Redis cache
    Level3Cache                   // Database cache
)

type CacheManager struct {
    level1 *MemoryCache
    level2 *RedisCache
    level3 *DatabaseCache
}

func (cm *CacheManager) Get(key string) (interface{}, bool) {
    // Try Level 1 (fastest)
    if value, found := cm.level1.Get(key); found {
        return value, true
    }
    
    // Try Level 2
    if value, found := cm.level2.Get(key); found {
        cm.level1.Set(key, value) // Populate Level 1
        return value, true
    }
    
    // Try Level 3
    if value, found := cm.level3.Get(key); found {
        cm.level2.Set(key, value) // Populate Level 2
        cm.level1.Set(key, value) // Populate Level 1
        return value, true
    }
    
    return nil, false
}
```

**Cache Characteristics**:
- **Level 1**: In-memory, <1ms access, 100MB size
- **Level 2**: Redis, <5ms access, 1GB size
- **Level 3**: Database, <50ms access, unlimited size

### 3. External Authorization (Ext Authz)

#### gRPC Ext Authz Integration

**Description**: Integration with Envoy's external authorization filter for real-time authorization decisions.

**Implementation**:
```protobuf
// Ext Authz Service Definition
service Authorization {
    rpc Check(CheckRequest) returns (CheckResponse);
}

message CheckRequest {
    repeated Attribute attributes = 1;
}

message CheckResponse {
    Status status = 1;
    repeated HeaderValueOption headers_to_add = 2;
    repeated HeaderValueOption headers_to_set = 3;
    repeated HeaderValueOption headers_to_remove = 4;
}
```

**Go Implementation**:
```go
// Ext Authz Handler
func (s *ExtAuthzServer) Check(ctx context.Context, req *authz.CheckRequest) (*authz.CheckResponse, error) {
    // Extract tenant ID from request
    tenantID := extractTenantID(req)
    
    // Get tenant information
    tenant := s.rls.GetOrCreateTenant(tenantID)
    
    // Check rate limits
    allowed, err := s.rls.CheckRateLimits(tenant, req)
    if err != nil {
        return &authz.CheckResponse{
            Status: &rpc.Status{
                Code: int32(codes.Internal),
                Message: err.Error(),
            },
        }, nil
    }
    
    if allowed {
        return &authz.CheckResponse{
            Status: &rpc.Status{Code: int32(codes.OK)},
            HeadersToAdd: []*core.HeaderValueOption{
                {Header: &core.HeaderValue{Key: "X-Rate-Limited", Value: "false"}},
            },
        }, nil
    }
    
    return &authz.CheckResponse{
        Status: &rpc.Status{
            Code: int32(codes.PermissionDenied),
            Message: "Rate limit exceeded",
        },
        HeadersToAdd: []*core.HeaderValueOption{
            {Header: &core.HeaderValue{Key: "X-Rate-Limited", Value: "true"}},
        },
    }, nil
}
```

**Features**:
- **Real-time Decisions**: Sub-10ms authorization decisions
- **Header Injection**: Add custom headers to requests
- **Status Codes**: Proper HTTP status codes for different scenarios
- **Error Handling**: Comprehensive error handling and logging

### 4. Dynamic Configuration Management

#### Runtime Configuration Updates

**Description**: Ability to update rate limiting configurations without service restarts.

**Implementation**:
```go
// Configuration Manager
type ConfigManager struct {
    config     *Config
    watchers   []ConfigWatcher
    mutex      sync.RWMutex
}

type Config struct {
    GlobalLimits    GlobalLimits    `yaml:"global_limits"`
    TenantLimits    map[string]TenantLimits `yaml:"tenant_limits"`
    EnforcementMode string          `yaml:"enforcement_mode"`
    Logging         LoggingConfig   `yaml:"logging"`
}

// Configuration Update Handler
func (cm *ConfigManager) UpdateConfig(newConfig *Config) error {
    cm.mutex.Lock()
    defer cm.mutex.Unlock()
    
    // Validate new configuration
    if err := cm.validateConfig(newConfig); err != nil {
        return err
    }
    
    // Apply configuration changes
    cm.applyConfigChanges(cm.config, newConfig)
    
    // Update current configuration
    cm.config = newConfig
    
    // Notify watchers
    cm.notifyWatchers(newConfig)
    
    return nil
}
```

**Configuration Sources**:
- **Kubernetes ConfigMaps**: Primary configuration source
- **Environment Variables**: Runtime overrides
- **API Endpoints**: Dynamic updates via REST API
- **File System**: Local configuration files

**Update Mechanisms**:
- **Hot Reload**: Configuration changes applied immediately
- **Validation**: Comprehensive validation before application
- **Rollback**: Automatic rollback on validation failures
- **Audit Trail**: Complete audit trail of configuration changes

### 5. Comprehensive Monitoring and Metrics

#### Prometheus Metrics

**Description**: Extensive Prometheus metrics for monitoring system health, performance, and rate limiting decisions.

**Implementation**:
```go
// Metrics Collection
type MetricsCollector struct {
    requestCounter    *prometheus.CounterVec
    requestDuration   *prometheus.HistogramVec
    rateLimitCounter  *prometheus.CounterVec
    tenantMetrics     *prometheus.GaugeVec
    systemMetrics     *prometheus.GaugeVec
}

// Metric Definitions
var (
    requestCounter = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "mimir_edge_requests_total",
            Help: "Total number of requests processed",
        },
        []string{"tenant_id", "route_decision", "status"},
    )
    
    requestDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "mimir_edge_request_duration_seconds",
            Help:    "Request duration in seconds",
            Buckets: prometheus.DefBuckets,
        },
        []string{"tenant_id", "route_decision"},
    )
    
    rateLimitCounter = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "mimir_edge_rate_limits_total",
            Help: "Total number of rate limiting decisions",
        },
        []string{"tenant_id", "decision", "limit_type"},
    )
)
```

**Metric Categories**:
- **Request Metrics**: Total requests, duration, status codes
- **Rate Limiting Metrics**: Allow/deny decisions, limit types
- **Tenant Metrics**: Per-tenant usage and limits
- **System Metrics**: Resource utilization, health status
- **Business Metrics**: Cost tracking, SLA compliance

#### Health Checks

**Description**: Comprehensive health checking system for all components.

**Implementation**:
```go
// Health Check Structure
type HealthCheck struct {
    Name     string                 `json:"name"`
    Status   string                 `json:"status"`
    Details  map[string]interface{} `json:"details,omitempty"`
    Timestamp time.Time             `json:"timestamp"`
}

type HealthChecker struct {
    checks map[string]HealthCheckFunc
}

// Health Check Functions
func (hc *HealthChecker) AddCheck(name string, check HealthCheckFunc) {
    hc.checks[name] = check
}

func (hc *HealthChecker) RunChecks() map[string]HealthCheck {
    results := make(map[string]HealthCheck)
    
    for name, check := range hc.checks {
        status, details := check()
        results[name] = HealthCheck{
            Name:      name,
            Status:    status,
            Details:   details,
            Timestamp: time.Now(),
        }
    }
    
    return results
}
```

**Health Check Types**:
- **Liveness**: Service is running and responsive
- **Readiness**: Service is ready to handle requests
- **Dependencies**: External dependencies are available
- **Performance**: Service is performing within acceptable limits

### 6. Admin UI and Management

#### Real-time Dashboard

**Description**: Comprehensive web-based interface for monitoring and managing the system.

**Features**:
- **Real-time Metrics**: Live updates of system metrics
- **Interactive Charts**: Rich, interactive visualizations
- **Tenant Management**: Per-tenant monitoring and configuration
- **System Health**: Comprehensive health status monitoring
- **Configuration Management**: Runtime configuration updates

**Implementation**:
```typescript
// Dashboard Component
interface DashboardProps {
  apiClient: APIClient;
  refreshInterval: number;
}

const Dashboard: React.FC<DashboardProps> = ({ apiClient, refreshInterval }) => {
  const [metrics, setMetrics] = useState<SystemMetrics | null>(null);
  const [tenants, setTenants] = useState<Tenant[]>([]);
  const [health, setHealth] = useState<HealthStatus | null>(null);
  
  // Real-time updates
  useEffect(() => {
    const interval = setInterval(async () => {
      const [metricsData, tenantsData, healthData] = await Promise.all([
        apiClient.getMetrics(),
        apiClient.getTenants(),
        apiClient.getHealth(),
      ]);
      
      setMetrics(metricsData);
      setTenants(tenantsData);
      setHealth(healthData);
    }, refreshInterval);
    
    return () => clearInterval(interval);
  }, [apiClient, refreshInterval]);
  
  return (
    <div className="dashboard">
      <MetricsOverview metrics={metrics} />
      <TenantsTable tenants={tenants} />
      <HealthStatus health={health} />
    </div>
  );
};
```

**Dashboard Sections**:
- **Overview**: System-wide metrics and status
- **Tenants**: Per-tenant metrics and configuration
- **System Health**: Component health and performance
- **Configuration**: Runtime configuration management
- **Wiki**: Documentation and troubleshooting guides

### 7. Advanced Security Features

#### Authentication and Authorization

**Description**: Comprehensive security features including authentication, authorization, and audit logging.

**Implementation**:
```go
// Authentication Middleware
type AuthMiddleware struct {
    authenticator Authenticator
    authorizer    Authorizer
}

func (am *AuthMiddleware) Authenticate(r *http.Request) (*User, error) {
    // Extract credentials
    token := extractToken(r)
    
    // Validate token
    user, err := am.authenticator.ValidateToken(token)
    if err != nil {
        return nil, err
    }
    
    return user, nil
}

func (am *AuthMiddleware) Authorize(user *User, resource string, action string) bool {
    return am.authorizer.CheckPermission(user, resource, action)
}
```

**Security Features**:
- **Token-based Authentication**: JWT token validation
- **Role-based Access Control**: Granular permission management
- **Audit Logging**: Complete audit trail of all actions
- **Data Encryption**: Encryption in transit and at rest
- **Rate Limiting**: Protection against abuse

### 8. Performance Optimization

#### High-Performance Architecture

**Description**: Optimized architecture for high throughput and low latency.

**Optimization Techniques**:
- **Connection Pooling**: Efficient connection management
- **Async Processing**: Non-blocking I/O operations
- **Memory Optimization**: Efficient memory usage patterns
- **Caching**: Multi-level caching strategies
- **Load Balancing**: Intelligent load distribution

**Performance Targets**:
- **Latency**: <10ms for rate limiting decisions
- **Throughput**: 100,000+ requests per second
- **Memory**: <2GB per instance
- **CPU**: <20% utilization under normal load

## Feature Benefits

### 1. Cost Control
- **50-70% Cost Reduction**: Significant infrastructure cost savings
- **Resource Optimization**: Efficient resource utilization
- **Predictable Costs**: Transparent cost attribution and billing
- **Budget Management**: Proactive budget control mechanisms

### 2. Service Protection
- **DDoS Protection**: Protection against distributed attacks
- **Resource Isolation**: Tenant isolation prevents resource exhaustion
- **Circuit Breaking**: Automatic failure protection
- **Graceful Degradation**: Maintain service during high load

### 3. Operational Excellence
- **Automated Operations**: Reduced manual intervention
- **Real-time Monitoring**: Comprehensive visibility into system health
- **Proactive Alerting**: Early warning of potential issues
- **Self-healing**: Automatic recovery from failures

### 4. Compliance and Governance
- **Audit Trail**: Complete audit logging for compliance
- **Policy Enforcement**: Automated policy enforcement
- **Data Protection**: Comprehensive data security measures
- **Regulatory Compliance**: Built-in compliance features

## Conclusion

The Mimir Edge Enforcement system provides a comprehensive set of core features that address the critical challenges of modern observability environments:

1. **Advanced Rate Limiting**: Sophisticated rate limiting with selective enforcement
2. **Intelligent Aggregation**: Time-based aggregation with intelligent caching
3. **Real-time Authorization**: Fast, reliable authorization decisions
4. **Dynamic Configuration**: Runtime configuration updates without downtime
5. **Comprehensive Monitoring**: Extensive metrics and health monitoring
6. **Rich Management Interface**: Powerful admin UI for system management
7. **Enterprise Security**: Comprehensive security and compliance features
8. **High Performance**: Optimized for high throughput and low latency

These features work together to provide a robust, scalable, and cost-effective solution for managing observability infrastructure.

---

**Next Steps**:
1. Explore advanced features in `features/advanced-features.md`
2. Review selective traffic routing in `features/selective-traffic-routing.md`
3. Understand time-based aggregation in `features/time-based-aggregation.md`
4. Learn about deployment strategies in `deployment/deployment-strategy.md`

**Related Documents**:
- [Advanced Features](advanced-features.md)
- [Selective Traffic Routing](selective-traffic-routing.md)
- [Time-based Aggregation](time-based-aggregation.md)
- [Rate Limit Service](../components/rate-limit-service.md)
