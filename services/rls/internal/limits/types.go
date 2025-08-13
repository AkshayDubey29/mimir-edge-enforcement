package limits

import (
	"time"
)

// TenantLimits represents the limits for a tenant
type TenantLimits struct {
	SamplesPerSecond    float64 `json:"samples_per_second"`
	BurstPercent        float64 `json:"burst_pct"`
	MaxBodyBytes        int64   `json:"max_body_bytes"`
	MaxLabelsPerSeries  int32   `json:"max_labels_per_series"`
	MaxLabelValueLength int32   `json:"max_label_value_length"`
	MaxSeriesPerRequest int32   `json:"max_series_per_request"`
	MaxSeriesPerMetric  int32   `json:"max_series_per_metric"` // 🔧 NEW: Per-metric series limit
}

// EnforcementConfig represents enforcement settings for a tenant
type EnforcementConfig struct {
	Enabled          bool    `json:"enabled"`
	BurstPctOverride float64 `json:"burst_pct_override"`

	// Granular enforcement controls
	EnforceSamplesPerSecond    bool `json:"enforce_samples_per_second,omitempty"`
	EnforceMaxBodyBytes        bool `json:"enforce_max_body_bytes,omitempty"`
	EnforceMaxLabelsPerSeries  bool `json:"enforce_max_labels_per_series,omitempty"`
	EnforceMaxSeriesPerRequest bool `json:"enforce_max_series_per_request,omitempty"`
	EnforceMaxSeriesPerMetric  bool `json:"enforce_max_series_per_metric,omitempty"` // 🔧 NEW: Per-metric enforcement
	EnforceBytesPerSecond      bool `json:"enforce_bytes_per_second,omitempty"`
}

// TenantInfo represents tenant information with limits and metrics
type TenantInfo struct {
	ID          string            `json:"id"`
	Name        string            `json:"name"`
	Limits      TenantLimits      `json:"limits"`
	Metrics     TenantMetrics     `json:"metrics"`
	Enforcement EnforcementConfig `json:"enforcement"`
}

// TenantMetrics represents metrics for a tenant
type TenantMetrics struct {
	RPS             float64 `json:"rps"`
	BytesPerSec     float64 `json:"bytes_per_sec"`
	SamplesPerSec   float64 `json:"samples_per_sec"`
	DenyRate        float64 `json:"deny_rate"`
	AllowRate       float64 `json:"allow_rate"`
	UtilizationPct  float64 `json:"utilization_pct"`
	AvgResponseTime float64 `json:"avg_response_time,omitempty"`
}

// DenialInfo represents information about a denied request
type DenialInfo struct {
	TenantID          string            `json:"tenant_id"`
	Reason            string            `json:"reason"`
	Timestamp         time.Time         `json:"timestamp"`
	ObservedSamples   int64             `json:"observed_samples"`
	ObservedBodyBytes int64             `json:"observed_body_bytes"`
	ObservedSeries    int64             `json:"observed_series,omitempty"`
	ObservedLabels    int64             `json:"observed_labels,omitempty"`
	LimitExceeded     int64             `json:"limit_exceeded,omitempty"`
	SampleMetrics     []SampleMetric    `json:"sample_metrics,omitempty"`
	ParseInfo         *ParseDiagnostics `json:"parse_info,omitempty"`
}

// SampleMetric represents a sample metric that was denied
type SampleMetric struct {
	MetricName string            `json:"metric_name"`
	Labels     map[string]string `json:"labels"`
	Value      float64           `json:"value"`
	Timestamp  int64             `json:"timestamp"`
	SeriesHash string            `json:"series_hash,omitempty"`
}

// ParseDiagnostics provides partial, useful details when parsing fails
type ParseDiagnostics struct {
	ContentEncoding string   `json:"content_encoding,omitempty"`
	BodySize        int      `json:"body_size,omitempty"`
	Error           string   `json:"error,omitempty"`
	HexPreview      []string `json:"hex_preview,omitempty"`
	GuessedCause    string   `json:"guessed_cause,omitempty"`
	Suggestions     []string `json:"suggestions,omitempty"`
}

// EnhancedDenialInfo represents enriched information about a denied request
type EnhancedDenialInfo struct {
	DenialInfo
	TenantLimits    TenantLimits   `json:"tenant_limits"`
	Insights        DenialInsights `json:"insights"`
	Recommendations []string       `json:"recommendations"`
	Severity        string         `json:"severity"`
	Category        string         `json:"category"`
}

// DenialInsights represents calculated insights about a denial
type DenialInsights struct {
	SamplesExceededBy  int64   `json:"samples_exceeded_by"`
	BodySizeExceededBy int64   `json:"body_size_exceeded_by"`
	SeriesExceededBy   int32   `json:"series_exceeded_by"`
	LabelsExceededBy   int32   `json:"labels_exceeded_by"`
	UtilizationPercent float64 `json:"utilization_percentage"`
	TrendDirection     string  `json:"trend_direction"`
	FrequencyInPeriod  int     `json:"frequency_in_period"`
}

// DenialTrend represents trend analysis for denials
type DenialTrend struct {
	TenantID        string    `json:"tenant_id"`
	Reason          string    `json:"reason"`
	Period          string    `json:"period"`
	Count           int       `json:"count"`
	TrendDirection  string    `json:"trend_direction"`
	LastOccurrence  time.Time `json:"last_occurrence"`
	FirstOccurrence time.Time `json:"first_occurrence"`
}

// DenialRecommendation represents a recommendation for fixing denials
type DenialRecommendation struct {
	Type        string `json:"type"`
	Title       string `json:"title"`
	Description string `json:"description"`
	Priority    string `json:"priority"`
	Action      string `json:"action"`
}

// OverviewStats represents overview statistics
type OverviewStats struct {
	TotalRequests   int64   `json:"total_requests"`
	AllowedRequests int64   `json:"allowed_requests"`
	DeniedRequests  int64   `json:"denied_requests"`
	AllowPercentage float64 `json:"allow_percentage"`
	ActiveTenants   int32   `json:"active_tenants"`
}

// RequestInfo represents information about an incoming request
type RequestInfo struct {
	ObservedSamples    int64            `json:"observed_samples"`
	ObservedSeries     int64            `json:"observed_series"`
	ObservedLabels     int64            `json:"observed_labels"`
	MetricSeriesCounts map[string]int64 `json:"metric_series_counts"` // 🔧 NEW: Per-metric series counts for Mimir-style limits
}

// Decision represents the result of an authorization check
type Decision struct {
	Allowed bool
	Reason  string
	Code    int32 // HTTP status code
}

// CardinalityMetrics represents cardinality-specific metrics
type CardinalityMetrics struct {
	TotalSeries           int64   `json:"total_series"`
	TotalLabels           int64   `json:"total_labels"`
	AvgSeriesPerRequest   float64 `json:"avg_series_per_request"`
	AvgLabelsPerSeries    float64 `json:"avg_labels_per_series"`
	MaxSeriesInRequest    int64   `json:"max_series_in_request"`
	MaxLabelsInSeries     int64   `json:"max_labels_in_series"`
	CardinalityViolations int64   `json:"cardinality_violations"`
	ViolationRate         float64 `json:"violation_rate"`
}

// CardinalityViolation represents a cardinality violation
type CardinalityViolation struct {
	TenantID       string    `json:"tenant_id"`
	Reason         string    `json:"reason"`
	Timestamp      time.Time `json:"timestamp"`
	ObservedSeries int64     `json:"observed_series"`
	ObservedLabels int64     `json:"observed_labels"`
	LimitExceeded  int64     `json:"limit_exceeded"`
}

// CardinalityTrend represents cardinality trends over time
type CardinalityTrend struct {
	Timestamp           time.Time `json:"timestamp"`
	AvgSeriesPerRequest float64   `json:"avg_series_per_request"`
	AvgLabelsPerSeries  float64   `json:"avg_labels_per_series"`
	ViolationCount      int64     `json:"violation_count"`
	TotalRequests       int64     `json:"total_requests"`
}

// CardinalityAlert represents a cardinality alert
type CardinalityAlert struct {
	ID        string    `json:"id"`
	Severity  string    `json:"severity"`
	Message   string    `json:"message"`
	Timestamp time.Time `json:"timestamp"`
	TenantID  string    `json:"tenant_id,omitempty"`
	Metric    string    `json:"metric"`
	Value     int64     `json:"value"`
	Threshold int64     `json:"threshold"`
	Resolved  bool      `json:"resolved"`
}

// CardinalityData represents comprehensive cardinality data for the dashboard
type CardinalityData struct {
	Metrics    CardinalityMetrics     `json:"metrics"`
	Violations []CardinalityViolation `json:"violations"`
	Trends     []CardinalityTrend     `json:"trends"`
	Tenants    []TenantCardinality    `json:"tenants"`
	Alerts     []CardinalityAlert     `json:"alerts"`
}

// TenantCardinality represents per-tenant cardinality data
type TenantCardinality struct {
	TenantID       string    `json:"tenant_id"`
	Name           string    `json:"name"`
	CurrentSeries  int64     `json:"current_series"`
	CurrentLabels  int64     `json:"current_labels"`
	ViolationCount int64     `json:"violation_count"`
	LastViolation  time.Time `json:"last_violation"`
	Limits         struct {
		MaxSeriesPerRequest int32 `json:"max_series_per_request"`
		MaxLabelsPerSeries  int32 `json:"max_labels_per_series"`
	} `json:"limits"`
}
