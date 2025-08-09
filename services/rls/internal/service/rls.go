package service

import (
	"context"
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/AkshayDubey29/mimir-edge-enforcement/services/rls/internal/buckets"
	"github.com/AkshayDubey29/mimir-edge-enforcement/services/rls/internal/limits"
	"github.com/AkshayDubey29/mimir-edge-enforcement/services/rls/internal/parser"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/rs/zerolog"

	envoy_extensions_common_ratelimit_v3 "github.com/envoyproxy/go-control-plane/envoy/extensions/common/ratelimit/v3"
	envoy_service_auth_v3 "github.com/envoyproxy/go-control-plane/envoy/service/auth/v3"
	envoy_service_ratelimit_v3 "github.com/envoyproxy/go-control-plane/envoy/service/ratelimit/v3"
	envoy_type_v3 "github.com/envoyproxy/go-control-plane/envoy/type/v3"
)

// RLSConfig holds the configuration for the RLS service
type RLSConfig struct {
	TenantHeader       string
	EnforceBodyParsing bool
	DefaultLimits      limits.TenantLimits
	MaxRequestBytes    int64
	FailureModeAllow   bool
}

// RLS represents the Rate Limit Service
type RLS struct {
	config *RLSConfig
	logger zerolog.Logger

	// Tenant management
	tenants   map[string]*TenantState
	tenantsMu sync.RWMutex

	// Metrics
	metrics *Metrics

	// Health state
	health *HealthState

	// In-memory counters for admin API
	countersMu    sync.RWMutex
	counters      map[string]*TenantCounters
	recentDenials []limits.DenialInfo
}

// TenantState represents the state of a tenant
type TenantState struct {
	Info           limits.TenantInfo
	SamplesBucket  *buckets.TokenBucket
	BytesBucket    *buckets.TokenBucket
	RequestsBucket *buckets.TokenBucket
}

// HealthState represents the health state of the service
type HealthState struct {
	mu                       sync.RWMutex
	OverridesResourceVersion string
	LastSyncTime             time.Time
	Version                  string
}

// Metrics holds all the Prometheus metrics
type Metrics struct {
	DecisionsTotal     *prometheus.CounterVec
	AuthzCheckDuration *prometheus.HistogramVec
	BodyParseErrors    prometheus.Counter
	LimitsStaleSeconds prometheus.Gauge
	TenantBuckets      *prometheus.GaugeVec
}

// NewRLS creates a new RLS service
func NewRLS(config *RLSConfig, logger zerolog.Logger) *RLS {
	rls := &RLS{
		config:        config,
		logger:        logger,
		tenants:       make(map[string]*TenantState),
		health:        &HealthState{Version: "1.0.0"},
		counters:      make(map[string]*TenantCounters),
		recentDenials: make([]limits.DenialInfo, 0, 256),
	}

	rls.metrics = rls.createMetrics()
	
	// Start periodic tenant status logging
	go rls.startPeriodicStatusLog()
	
	return rls
}

// startPeriodicStatusLog logs tenant count periodically for debugging
func (rls *RLS) startPeriodicStatusLog() {
	ticker := time.NewTicker(1 * time.Minute)
	defer ticker.Stop()
	
	for {
		select {
		case <-ticker.C:
			rls.tenantsMu.RLock()
			tenantCount := len(rls.tenants)
			tenantIDs := make([]string, 0, tenantCount)
			for id := range rls.tenants {
				tenantIDs = append(tenantIDs, id)
			}
			rls.tenantsMu.RUnlock()
			
			rls.countersMu.RLock()
			activeCounters := len(rls.counters)
			rls.countersMu.RUnlock()
			
			logger := rls.logger.Info().
				Int("tenant_count", tenantCount).
				Int("active_counters", activeCounters)
			
			if tenantCount > 0 {
				if tenantCount <= 5 {
					// Log all tenant IDs if there are few
					logger = logger.Strs("tenant_ids", tenantIDs)
				} else {
					// Log just the first 5 tenant IDs if there are many
					logger = logger.Strs("sample_tenant_ids", tenantIDs[:5])
				}
				logger.Msg("RLS: periodic tenant status - TENANTS LOADED")
			} else {
				logger.Msg("RLS: periodic tenant status - NO TENANTS (check overrides-sync)")
			}
		}
	}
}

// createMetrics creates and registers all Prometheus metrics
func (rls *RLS) createMetrics() *Metrics {
	return &Metrics{
		DecisionsTotal: promauto.NewCounterVec(
			prometheus.CounterOpts{
				Name: "rls_decisions_total",
				Help: "Total number of authorization decisions",
			},
			[]string{"decision", "tenant", "reason"},
		),
		AuthzCheckDuration: promauto.NewHistogramVec(
			prometheus.HistogramOpts{
				Name:    "rls_authz_check_duration_seconds",
				Help:    "Duration of authorization checks",
				Buckets: prometheus.DefBuckets,
			},
			[]string{"tenant"},
		),
		BodyParseErrors: promauto.NewCounter(
			prometheus.CounterOpts{
				Name: "rls_body_parse_errors_total",
				Help: "Total number of body parsing errors",
			},
		),
		LimitsStaleSeconds: promauto.NewGauge(
			prometheus.GaugeOpts{
				Name: "rls_limits_stale_seconds",
				Help: "How long the limits have been stale",
			},
		),
		TenantBuckets: promauto.NewGaugeVec(
			prometheus.GaugeOpts{
				Name: "rls_tenant_bucket_tokens",
				Help: "Available tokens in tenant buckets",
			},
			[]string{"tenant", "bucket_type"},
		),
	}
}

// Check implements the ext_authz service
func (rls *RLS) Check(ctx context.Context, req *envoy_service_auth_v3.CheckRequest) (*envoy_service_auth_v3.CheckResponse, error) {
	start := time.Now()

	// Extract tenant ID from headers
	tenantID := rls.extractTenantID(req)
	if tenantID == "" {
		rls.metrics.DecisionsTotal.WithLabelValues("deny", "unknown", "missing_tenant_header").Inc()
		return rls.denyResponse("missing tenant header", http.StatusBadRequest), nil
	}

	// Get or initialize tenant state (unknown tenants default to enforcement disabled)
	tenant := rls.getTenant(tenantID)

	// Check if enforcement is enabled
	if !tenant.Info.Enforcement.Enabled {
		rls.metrics.DecisionsTotal.WithLabelValues("allow", tenantID, "enforcement_disabled").Inc()
		rls.recordDecision(tenantID, true, "enforcement_disabled", 0, 0)
		rls.metrics.AuthzCheckDuration.WithLabelValues(tenantID).Observe(time.Since(start).Seconds())
		return rls.allowResponse(), nil
	}

	// Parse request body if enabled
	var samples int64
	var bodyBytes int64

	if rls.config.EnforceBodyParsing {
		body, err := rls.extractBody(req)
		if err != nil {
			rls.logger.Error().Err(err).Str("tenant", tenantID).Msg("failed to extract request body")
			if rls.config.FailureModeAllow {
				rls.metrics.DecisionsTotal.WithLabelValues("allow", tenantID, "body_extract_failed").Inc()
				return rls.allowResponse(), nil
			}
			rls.metrics.DecisionsTotal.WithLabelValues("deny", tenantID, "body_extract_failed").Inc()
			return rls.denyResponse("failed to extract request body", http.StatusBadRequest), nil
		}

		bodyBytes = int64(len(body))

		// Parse remote write request
		contentEncoding := rls.extractContentEncoding(req)
		result, err := parser.ParseRemoteWriteRequest(body, contentEncoding)
		if err != nil {
			rls.metrics.BodyParseErrors.Inc()
			rls.logger.Error().Err(err).Str("tenant", tenantID).Msg("failed to parse remote write request")
			if rls.config.FailureModeAllow {
				rls.metrics.DecisionsTotal.WithLabelValues("allow", tenantID, "parse_failed").Inc()
				return rls.allowResponse(), nil
			}
			rls.metrics.DecisionsTotal.WithLabelValues("deny", tenantID, "parse_failed").Inc()
			return rls.denyResponse("failed to parse request", http.StatusBadRequest), nil
		}

		samples = result.SamplesCount
	} else {
		// Use content length as a proxy for request size
		bodyBytes = int64(len(req.Attributes.Request.Http.Body))
		samples = 1 // Default to 1 sample if not parsing
	}

	// Check limits
	decision := rls.checkLimits(tenant, samples, bodyBytes)

	// Record metrics
	rls.metrics.DecisionsTotal.WithLabelValues(decision.Reason, tenantID, decision.Reason).Inc()
	rls.recordDecision(tenantID, decision.Allowed, decision.Reason, samples, bodyBytes)
	rls.metrics.AuthzCheckDuration.WithLabelValues(tenantID).Observe(time.Since(start).Seconds())

	// Update bucket metrics
	rls.updateBucketMetrics(tenant)

	if decision.Allowed {
		return rls.allowResponse(), nil
	}

	// Log denial
	rls.logger.Info().
		Str("tenant", tenantID).
		Str("reason", decision.Reason).
		Int64("samples", samples).
		Int64("body_bytes", bodyBytes).
		Msg("request denied")

	return rls.denyResponse(decision.Reason, decision.Code), nil
}

// recordDecision updates in-memory counters and recent denials for admin API
func (rls *RLS) recordDecision(tenantID string, allowed bool, reason string, samples int64, bodyBytes int64) {
	rls.countersMu.Lock()
	defer rls.countersMu.Unlock()
	c, ok := rls.counters[tenantID]
	if !ok {
		c = &TenantCounters{}
		rls.counters[tenantID] = c
	}
	c.Total++
	if allowed {
		c.Allowed++
	} else {
		c.Denied++
		// record denial
		di := limits.DenialInfo{TenantID: tenantID, Reason: reason, Timestamp: time.Now(), ObservedSamples: samples, ObservedBodyBytes: bodyBytes}
		rls.recentDenials = append(rls.recentDenials, di)
		if len(rls.recentDenials) > 500 {
			rls.recentDenials = rls.recentDenials[len(rls.recentDenials)-500:]
		}
	}
}

// TenantCounters holds simple aggregates per tenant
type TenantCounters struct {
	Total   int64
	Allowed int64
	Denied  int64
}

// Admin snapshots
func (rls *RLS) OverviewSnapshot() limits.OverviewStats {
	rls.countersMu.RLock()
	defer rls.countersMu.RUnlock()
	var total, allowed, denied int64
	for _, c := range rls.counters {
		total += c.Total
		allowed += c.Allowed
		denied += c.Denied
	}
	allowPct := 100.0
	if total > 0 {
		allowPct = float64(allowed) / float64(total) * 100.0
	}
	rls.tenantsMu.RLock()
	active := int32(len(rls.tenants))
	rls.tenantsMu.RUnlock()
	return limits.OverviewStats{TotalRequests: total, AllowedRequests: allowed, DeniedRequests: denied, AllowPercentage: allowPct, ActiveTenants: active}
}

func (rls *RLS) ListTenantsWithMetrics() []limits.TenantInfo {
	rls.tenantsMu.RLock()
	tenants := make([]*TenantState, 0, len(rls.tenants))
	for _, t := range rls.tenants {
		tenants = append(tenants, t)
	}
	rls.tenantsMu.RUnlock()

	rls.countersMu.RLock()
	defer rls.countersMu.RUnlock()

	out := make([]limits.TenantInfo, 0, len(tenants))
	for _, t := range tenants {
		c := rls.counters[t.Info.ID]
		metrics := limits.TenantMetrics{}
		if c != nil && c.Total > 0 {
			metrics.AllowRate = float64(c.Allowed)
			metrics.DenyRate = float64(c.Denied)
			metrics.UtilizationPct = 0 // placeholder
		}
		info := t.Info
		info.Metrics = metrics
		out = append(out, info)
	}
	return out
}

func (rls *RLS) RecentDenials(tenantID string, since time.Duration) []limits.DenialInfo {
	cutoff := time.Now().Add(-since)
	rls.countersMu.RLock()
	defer rls.countersMu.RUnlock()
	out := make([]limits.DenialInfo, 0)
	for i := len(rls.recentDenials) - 1; i >= 0; i-- {
		d := rls.recentDenials[i]
		if d.Timestamp.Before(cutoff) {
			break
		}
		if tenantID == "" || tenantID == "*" || d.TenantID == tenantID {
			out = append(out, d)
		}
	}
	return out
}

// GetTenantSnapshot returns a single tenant info with metrics if present
func (rls *RLS) GetTenantSnapshot(tenantID string) (limits.TenantInfo, bool) {
	rls.tenantsMu.RLock()
	t, ok := rls.tenants[tenantID]
	rls.tenantsMu.RUnlock()
	if !ok {
		return limits.TenantInfo{}, false
	}
	rls.countersMu.RLock()
	c := rls.counters[tenantID]
	rls.countersMu.RUnlock()
	info := t.Info
	if c != nil && c.Total > 0 {
		info.Metrics = limits.TenantMetrics{AllowRate: float64(c.Allowed), DenyRate: float64(c.Denied)}
	}
	return info, true
}

// ShouldRateLimit implements the ratelimit service
func (rls *RLS) ShouldRateLimit(ctx context.Context, req *envoy_service_ratelimit_v3.RateLimitRequest) (*envoy_service_ratelimit_v3.RateLimitResponse, error) {
	// This is a simplified implementation
	// In a real implementation, you'd want to check the specific rate limit descriptors

	response := &envoy_service_ratelimit_v3.RateLimitResponse{
		OverallCode: envoy_service_ratelimit_v3.RateLimitResponse_OK,
		Statuses:    make([]*envoy_service_ratelimit_v3.RateLimitResponse_DescriptorStatus, len(req.Descriptors)),
	}

	for i, descriptor := range req.Descriptors {
		// Extract tenant from descriptor
		tenantID := ""
		for _, entry := range descriptor.Entries {
			if entry.Key == rls.config.TenantHeader {
				tenantID = entry.Value
				break
			}
		}

		if tenantID == "" {
			response.Statuses[i] = &envoy_service_ratelimit_v3.RateLimitResponse_DescriptorStatus{
				Code: envoy_service_ratelimit_v3.RateLimitResponse_OK,
			}
			continue
		}

		tenant := rls.getTenant(tenantID)
		if tenant == nil {
			response.Statuses[i] = &envoy_service_ratelimit_v3.RateLimitResponse_DescriptorStatus{
				Code: envoy_service_ratelimit_v3.RateLimitResponse_OK,
			}
			continue
		}

		// Check rate limit based on descriptor
		allowed := rls.checkRateLimit(tenant, descriptor.Entries)

		if allowed {
			response.Statuses[i] = &envoy_service_ratelimit_v3.RateLimitResponse_DescriptorStatus{
				Code: envoy_service_ratelimit_v3.RateLimitResponse_OK,
			}
		} else {
			response.Statuses[i] = &envoy_service_ratelimit_v3.RateLimitResponse_DescriptorStatus{
				Code: envoy_service_ratelimit_v3.RateLimitResponse_OVER_LIMIT,
			}
			response.OverallCode = envoy_service_ratelimit_v3.RateLimitResponse_OVER_LIMIT
		}
	}

	return response, nil
}

// extractTenantID extracts the tenant ID from the request headers
func (rls *RLS) extractTenantID(req *envoy_service_auth_v3.CheckRequest) string {
	headers := req.Attributes.Request.Http.Headers
	return headers[rls.config.TenantHeader]
}

// extractBody extracts the request body
func (rls *RLS) extractBody(req *envoy_service_auth_v3.CheckRequest) ([]byte, error) {
	if req.Attributes.Request.Http.Body == "" {
		return nil, fmt.Errorf("no body in request")
	}

	// In a real implementation, you'd need to handle the body properly
	// This is a simplified version
	return []byte(req.Attributes.Request.Http.Body), nil
}

// extractContentEncoding extracts the content encoding from headers
func (rls *RLS) extractContentEncoding(req *envoy_service_auth_v3.CheckRequest) string {
	headers := req.Attributes.Request.Http.Headers
	return headers["content-encoding"]
}

// getTenant gets the tenant state, creating it if it doesn't exist
func (rls *RLS) getTenant(tenantID string) *TenantState {
	rls.tenantsMu.RLock()
	tenant, exists := rls.tenants[tenantID]
	rls.tenantsMu.RUnlock()

	if exists {
		return tenant
	}

	// Create new tenant with enforcement disabled until overrides-sync sets limits
	rls.tenantsMu.Lock()
	defer rls.tenantsMu.Unlock()

	// Double-check after acquiring write lock
	if tenant, exists = rls.tenants[tenantID]; exists {
		return tenant
	}

	tenant = &TenantState{
		Info: limits.TenantInfo{
			ID:   tenantID,
			Name: tenantID,
			// Zero limits mean "no cap"; enforcement stays disabled until sync sets limits
			Limits: limits.TenantLimits{},
			Enforcement: limits.EnforcementConfig{
				Enabled: false,
			},
		},
		// Buckets are created only when non-zero limits are configured by overrides-sync
		RequestsBucket: buckets.NewTokenBucket(100, 100), // coarse safety if ever used
	}

	rls.tenants[tenantID] = tenant
	return tenant
}

// checkLimits checks if the request is within limits
func (rls *RLS) checkLimits(tenant *TenantState, samples, bodyBytes int64) limits.Decision {
	// Check body size
	if tenant.Info.Limits.MaxBodyBytes > 0 && bodyBytes > tenant.Info.Limits.MaxBodyBytes {
		return limits.Decision{
			Allowed: false,
			Reason:  "body_size_exceeded",
			Code:    http.StatusRequestEntityTooLarge,
		}
	}

	// Check samples per second
	if tenant.SamplesBucket != nil && tenant.Info.Limits.SamplesPerSecond > 0 && !tenant.SamplesBucket.Take(float64(samples)) {
		return limits.Decision{
			Allowed: false,
			Reason:  "samples_rate_exceeded",
			Code:    http.StatusTooManyRequests,
		}
	}

	// Check bytes per second
	if tenant.BytesBucket != nil && tenant.Info.Limits.MaxBodyBytes > 0 && !tenant.BytesBucket.Take(float64(bodyBytes)) {
		return limits.Decision{
			Allowed: false,
			Reason:  "bytes_rate_exceeded",
			Code:    http.StatusTooManyRequests,
		}
	}

	return limits.Decision{
		Allowed: true,
		Reason:  "allowed",
		Code:    http.StatusOK,
	}
}

// checkRateLimit checks rate limits for the ratelimit service
func (rls *RLS) checkRateLimit(tenant *TenantState, entries []*envoy_extensions_common_ratelimit_v3.RateLimitDescriptor_Entry) bool {
	// Simplified implementation - check requests per second
	for _, entry := range entries {
		if entry.Key == "requests_per_second" {
			// For simplicity, always allow in this implementation
			// In a real implementation, you'd check against the requests bucket
			return true
		}
	}
	return true
}

// updateBucketMetrics updates the bucket metrics
func (rls *RLS) updateBucketMetrics(tenant *TenantState) {
	rls.metrics.TenantBuckets.WithLabelValues(tenant.Info.ID, "samples").Set(tenant.SamplesBucket.Available())
	rls.metrics.TenantBuckets.WithLabelValues(tenant.Info.ID, "bytes").Set(tenant.BytesBucket.Available())
	rls.metrics.TenantBuckets.WithLabelValues(tenant.Info.ID, "requests").Set(tenant.RequestsBucket.Available())
}

// allowResponse creates an allow response
func (rls *RLS) allowResponse() *envoy_service_auth_v3.CheckResponse {
	return &envoy_service_auth_v3.CheckResponse{
		HttpResponse: &envoy_service_auth_v3.CheckResponse_OkResponse{
			OkResponse: &envoy_service_auth_v3.OkHttpResponse{},
		},
	}
}

// denyResponse creates a deny response
func (rls *RLS) denyResponse(reason string, code int32) *envoy_service_auth_v3.CheckResponse {
	return &envoy_service_auth_v3.CheckResponse{
		HttpResponse: &envoy_service_auth_v3.CheckResponse_DeniedResponse{
			DeniedResponse: &envoy_service_auth_v3.DeniedHttpResponse{
				Status: &envoy_type_v3.HttpStatus{
					Code: envoy_type_v3.StatusCode(code),
				},
				Body: reason,
			},
		},
	}
}

// SetTenantLimits sets the limits for a tenant
func (rls *RLS) SetTenantLimits(tenantID string, newLimits limits.TenantLimits) error {
	rls.tenantsMu.Lock()
	defer rls.tenantsMu.Unlock()

	tenant, exists := rls.tenants[tenantID]
	isNewTenant := !exists
	
	if !exists {
		tenant = &TenantState{
			Info: limits.TenantInfo{
				ID:   tenantID,
				Name: tenantID,
			},
		}
		rls.tenants[tenantID] = tenant
		rls.logger.Info().
			Str("tenant_id", tenantID).
			Msg("RLS: creating new tenant from overrides-sync")
	}

	// Log the limits being set
	rls.logger.Info().
		Str("tenant_id", tenantID).
		Bool("is_new_tenant", isNewTenant).
		Float64("samples_per_second", newLimits.SamplesPerSecond).
		Float64("burst_percent", newLimits.BurstPercent).
		Int64("max_body_bytes", newLimits.MaxBodyBytes).
		Int32("max_labels_per_series", newLimits.MaxLabelsPerSeries).
		Int32("max_label_value_length", newLimits.MaxLabelValueLength).
		Int32("max_series_per_request", newLimits.MaxSeriesPerRequest).
		Int("total_tenants_after", len(rls.tenants)).
		Msg("RLS: received tenant limits from overrides-sync")

	tenant.Info.Limits = newLimits

	// Update buckets only for non-zero limits; nil buckets mean no enforcement for that dimension
	if newLimits.SamplesPerSecond > 0 {
		if tenant.SamplesBucket == nil {
			tenant.SamplesBucket = buckets.NewTokenBucket(newLimits.SamplesPerSecond, newLimits.SamplesPerSecond)
			rls.logger.Debug().
				Str("tenant_id", tenantID).
				Float64("rate", newLimits.SamplesPerSecond).
				Msg("RLS: created samples bucket")
		} else {
			tenant.SamplesBucket.SetRate(newLimits.SamplesPerSecond)
			tenant.SamplesBucket.SetCapacity(newLimits.SamplesPerSecond)
			rls.logger.Debug().
				Str("tenant_id", tenantID).
				Float64("rate", newLimits.SamplesPerSecond).
				Msg("RLS: updated samples bucket")
		}
	} else {
		if tenant.SamplesBucket != nil {
			rls.logger.Debug().
				Str("tenant_id", tenantID).
				Msg("RLS: removed samples bucket (zero limit)")
		}
		tenant.SamplesBucket = nil
	}

	if newLimits.MaxBodyBytes > 0 {
		if tenant.BytesBucket == nil {
			tenant.BytesBucket = buckets.NewTokenBucket(float64(newLimits.MaxBodyBytes), float64(newLimits.MaxBodyBytes))
			rls.logger.Debug().
				Str("tenant_id", tenantID).
				Int64("max_bytes", newLimits.MaxBodyBytes).
				Msg("RLS: created bytes bucket")
		} else {
			tenant.BytesBucket.SetRate(float64(newLimits.MaxBodyBytes))
			tenant.BytesBucket.SetCapacity(float64(newLimits.MaxBodyBytes))
			rls.logger.Debug().
				Str("tenant_id", tenantID).
				Int64("max_bytes", newLimits.MaxBodyBytes).
				Msg("RLS: updated bytes bucket")
		}
	} else {
		if tenant.BytesBucket != nil {
			rls.logger.Debug().
				Str("tenant_id", tenantID).
				Msg("RLS: removed bytes bucket (zero limit)")
		}
		tenant.BytesBucket = nil
	}

	return nil
}

// GetTenantLimits gets the limits for a tenant
func (rls *RLS) GetTenantLimits(tenantID string) (*limits.TenantLimits, bool) {
	rls.tenantsMu.RLock()
	defer rls.tenantsMu.RUnlock()

	tenant, exists := rls.tenants[tenantID]
	if !exists {
		return nil, false
	}

	return &tenant.Info.Limits, true
}

// ListTenants lists all tenants
func (rls *RLS) ListTenants() []limits.TenantInfo {
	rls.tenantsMu.RLock()
	defer rls.tenantsMu.RUnlock()

	tenants := make([]limits.TenantInfo, 0, len(rls.tenants))
	for _, tenant := range rls.tenants {
		tenants = append(tenants, tenant.Info)
	}

	return tenants
}

// SetEnforcement sets the enforcement configuration for a tenant
func (rls *RLS) SetEnforcement(tenantID string, enforcement limits.EnforcementConfig) error {
	rls.tenantsMu.Lock()
	defer rls.tenantsMu.Unlock()

	tenant, exists := rls.tenants[tenantID]
	if !exists {
		return fmt.Errorf("tenant not found: %s", tenantID)
	}

	tenant.Info.Enforcement = enforcement
	return nil
}

// UpdateHealth updates the health state
func (rls *RLS) UpdateHealth(resourceVersion string) {
	rls.health.mu.Lock()
	defer rls.health.mu.Unlock()

	rls.health.OverridesResourceVersion = resourceVersion
	rls.health.LastSyncTime = time.Now()

	// Update stale seconds metric
	if !rls.health.LastSyncTime.IsZero() {
		rls.metrics.LimitsStaleSeconds.Set(time.Since(rls.health.LastSyncTime).Seconds())
	}
}

// GetHealth returns the health state
func (rls *RLS) GetHealth() *HealthState {
	rls.health.mu.RLock()
	defer rls.health.mu.RUnlock()

	return &HealthState{
		OverridesResourceVersion: rls.health.OverridesResourceVersion,
		LastSyncTime:             rls.health.LastSyncTime,
		Version:                  rls.health.Version,
	}
}
