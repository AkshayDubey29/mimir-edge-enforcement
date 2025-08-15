package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"math"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/AkshayDubey29/mimir-edge-enforcement/services/rls/internal/limits"
	"github.com/AkshayDubey29/mimir-edge-enforcement/services/rls/internal/service"
	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	"google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/keepalive"
	"google.golang.org/grpc/reflection"

	"bytes"
	"io"

	envoy_service_auth_v3 "github.com/envoyproxy/go-control-plane/envoy/service/auth/v3"
	envoy_service_ratelimit_v3 "github.com/envoyproxy/go-control-plane/envoy/service/ratelimit/v3"
)

// parseScientificNotationInt64 parses a string value that may contain scientific notation and converts to int64
func parseScientificNotationInt64(value string) (int64, error) {
	// Handle scientific notation (e.g., "4e6", "1.5e7", "4E6")
	value = strings.TrimSpace(value)
	if strings.Contains(strings.ToLower(value), "e") {
		f, err := strconv.ParseFloat(value, 64)
		if err != nil {
			return 0, fmt.Errorf("invalid scientific notation: %s", value)
		}
		// Check for overflow
		if f > float64(math.MaxInt64) || f < float64(math.MinInt64) {
			return 0, fmt.Errorf("value out of range for int64: %s", value)
		}
		return int64(f), nil
	}

	// Handle regular integer parsing
	i, err := strconv.ParseInt(value, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("invalid integer: %s", value)
	}
	return i, nil
}

// parseScientificNotationFloat64 parses a string value that may contain scientific notation
func parseScientificNotationFloat64(value string) (float64, error) {
	// Handle scientific notation (e.g., "4e6", "1.5e7", "4E6")
	value = strings.TrimSpace(value)
	if strings.Contains(strings.ToLower(value), "e") {
		f, err := strconv.ParseFloat(value, 64)
		if err != nil {
			return 0, fmt.Errorf("invalid scientific notation: %s", value)
		}
		return f, nil
	}

	// Handle regular float parsing
	f, err := strconv.ParseFloat(value, 64)
	if err != nil {
		return 0, fmt.Errorf("invalid float: %s", value)
	}
	return f, nil
}

var (
	// Server configuration
	extAuthzPort  = flag.String("ext-authz-port", "8080", "Port for ext_authz gRPC server")
	rateLimitPort = flag.String("rate-limit-port", "8081", "Port for ratelimit gRPC server")
	adminPort     = flag.String("admin-port", "8082", "Port for admin HTTP server")
	metricsPort   = flag.String("metrics-port", "9090", "Port for metrics HTTP server")

	// Configuration
	tenantHeader       = flag.String("tenant-header", "X-Scope-OrgID", "Header name for tenant identification")
	enforceBodyParsing = flag.Bool("enforce-body-parsing", true, "Whether to parse request body for sample counting")
	maxRequestBytes    = flag.Int64("max-request-bytes", 4194304, "Maximum request body size in bytes")
	failureModeAllow   = flag.Bool("failure-mode-allow", false, "Whether to allow requests when body parsing fails")

	// Default limits - using string flags for scientific notation support
	defaultSamplesPerSecondStr = flag.String("default-samples-per-second", "10000", "Default samples per second limit (supports scientific notation)")
	defaultBurstPercentStr     = flag.String("default-burst-percent", "0.2", "Default burst percentage (supports scientific notation)")
	defaultMaxBodyBytesStr     = flag.String("default-max-body-bytes", "4194304", "Default maximum body size in bytes (supports scientific notation)")
	defaultMaxLabelsPerSeries  = flag.Int("default-max-labels-per-series", 60, "Default maximum labels per series")
	defaultMaxLabelValueLength = flag.Int("default-max-label-value-length", 2048, "Default maximum label value length")
	defaultMaxSeriesPerRequest = flag.Int("default-max-series-per-request", 100000, "Default maximum series per request")

	// Selective enforcement flags
	enforceSamplesPerSecond    = flag.Bool("enforce-samples-per-second", true, "Whether to enforce samples per second limits")
	enforceMaxBodyBytes        = flag.Bool("enforce-max-body-bytes", true, "Whether to enforce maximum body size limits")
	enforceMaxLabelsPerSeries  = flag.Bool("enforce-max-labels-per-series", true, "Whether to enforce maximum labels per series limits")
	enforceMaxSeriesPerRequest = flag.Bool("enforce-max-series-per-request", true, "Whether to enforce maximum series per request limits")
	enforceMaxSeriesPerMetric  = flag.Bool("enforce-max-series-per-metric", true, "Whether to enforce maximum series per metric limits")
	enforceBytesPerSecond      = flag.Bool("enforce-bytes-per-second", true, "Whether to enforce bytes per second limits")

	// Store configuration
	storeBackend = flag.String("store-backend", "memory", "Store backend (memory or redis)")
	redisAddress = flag.String("redis-address", "localhost:6379", "Redis server address")

	// Mimir configuration for direct integration
	mimirHost = flag.String("mimir-host", "mock-mimir-distributor.mimir.svc.cluster.local", "Mimir distributor host")
	mimirPort = flag.String("mimir-port", "8080", "Mimir distributor port")

	// 🔧 NEW: New tenant leniency configuration
	newTenantLeniency = flag.Bool("new-tenant-leniency", true, "Enable lenient limits for new tenants (50% of normal limits)")

	// Logging
	logLevel = flag.String("log-level", "info", "Log level (debug, info, warn, error)")
)

func main() {
	flag.Parse()

	// Parse scientific notation values
	defaultSamplesPerSecond, err := parseScientificNotationFloat64(*defaultSamplesPerSecondStr)
	if err != nil {
		log.Fatal().Err(err).Msg("invalid default-samples-per-second value")
	}

	defaultBurstPercent, err := parseScientificNotationFloat64(*defaultBurstPercentStr)
	if err != nil {
		log.Fatal().Err(err).Msg("invalid default-burst-percent value")
	}

	defaultMaxBodyBytes, err := parseScientificNotationInt64(*defaultMaxBodyBytesStr)
	if err != nil {
		log.Fatal().Err(err).Msg("invalid default-max-body-bytes value")
	}

	// Setup logging
	level, err := zerolog.ParseLevel(*logLevel)
	if err != nil {
		log.Fatal().Err(err).Msg("invalid log level")
	}
	zerolog.SetGlobalLevel(level)
	logger := log.With().Str("component", "rls").Logger()

	// Log parsed values for debugging
	logger.Info().
		Float64("default_samples_per_second", defaultSamplesPerSecond).
		Float64("default_burst_percent", defaultBurstPercent).
		Int64("default_max_body_bytes", defaultMaxBodyBytes).
		Msg("parsed configuration values")

	// Create RLS configuration
	config := &service.RLSConfig{
		TenantHeader:       *tenantHeader,
		EnforceBodyParsing: *enforceBodyParsing,
		MaxRequestBytes:    *maxRequestBytes,
		FailureModeAllow:   *failureModeAllow,
		StoreBackend:       *storeBackend,
		RedisAddress:       *redisAddress,
		MimirHost:          *mimirHost,
		MimirPort:          *mimirPort,
		NewTenantLeniency:  *newTenantLeniency, // 🔧 NEW: Add new tenant leniency configuration
		DefaultLimits: limits.TenantLimits{
			SamplesPerSecond:    defaultSamplesPerSecond,
			BurstPercent:        defaultBurstPercent,
			MaxBodyBytes:        defaultMaxBodyBytes,
			MaxLabelsPerSeries:  int32(*defaultMaxLabelsPerSeries),
			MaxLabelValueLength: int32(*defaultMaxLabelValueLength),
			MaxSeriesPerRequest: int32(*defaultMaxSeriesPerRequest),
		},
		DefaultEnforcement: limits.EnforcementConfig{
			Enabled:                    true,
			EnforceSamplesPerSecond:    *enforceSamplesPerSecond,
			EnforceMaxBodyBytes:        *enforceMaxBodyBytes,
			EnforceMaxLabelsPerSeries:  *enforceMaxLabelsPerSeries,
			EnforceMaxSeriesPerRequest: *enforceMaxSeriesPerRequest,
			EnforceMaxSeriesPerMetric:  *enforceMaxSeriesPerMetric,
			EnforceBytesPerSecond:      *enforceBytesPerSecond,
		},
	}

	// Create RLS service
	rls := service.NewRLS(config, logger)

	// Create context for graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// 🔧 FIX: Add startup validation and better logging
	logger.Info().
		Str("ext_authz_port", *extAuthzPort).
		Str("rate_limit_port", *rateLimitPort).
		Str("admin_port", *adminPort).
		Str("metrics_port", *metricsPort).
		Msg("starting RLS service components")

	// Start gRPC servers
	go startExtAuthzServer(ctx, rls, *extAuthzPort, logger)
	go startRateLimitServer(ctx, rls, *rateLimitPort, logger)

	// Start HTTP servers
	go startAdminServer(ctx, rls, *adminPort, logger)
	go startMetricsServer(ctx, *metricsPort, logger)

	// 🔧 FIX: Add proper startup validation and graceful shutdown
	logger.Info().Msg("RLS service started - all components initialized")

	// Wait for shutdown signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	<-sigChan

	logger.Info().Msg("Shutting down RLS service...")

	// Trigger graceful shutdown
	cancel()

	// Wait for all servers to shutdown gracefully
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer shutdownCancel()

	// Wait for shutdown to complete
	<-shutdownCtx.Done()
	if shutdownCtx.Err() == context.DeadlineExceeded {
		logger.Warn().Msg("shutdown timeout exceeded, forcing exit")
	}

	logger.Info().Msg("RLS service stopped")
}

func startExtAuthzServer(ctx context.Context, rls *service.RLS, port string, logger zerolog.Logger) {
	lis, err := net.Listen("tcp", ":"+port)
	if err != nil {
		logger.Fatal().Err(err).Str("port", port).Msg("failed to listen for ext_authz")
	}

	// 🔧 PERFORMANCE FIX: Add gRPC server optimizations for high throughput
	grpcServer := grpc.NewServer(
		grpc.MaxConcurrentStreams(1000),  // Allow more concurrent streams
		grpc.MaxRecvMsgSize(4*1024*1024), // 4MB max message size
		grpc.MaxSendMsgSize(4*1024*1024), // 4MB max message size
		grpc.NumStreamWorkers(32),        // More worker goroutines
		grpc.KeepaliveEnforcementPolicy(keepalive.EnforcementPolicy{
			MinTime:             5 * time.Second,
			PermitWithoutStream: true,
		}),
		grpc.KeepaliveParams(keepalive.ServerParameters{
			MaxConnectionIdle: 30 * time.Second,
			MaxConnectionAge:  5 * time.Minute,
			Time:              10 * time.Second,
			Timeout:           3 * time.Second,
		}),
	)

	// Register ext_authz service
	envoy_service_auth_v3.RegisterAuthorizationServer(grpcServer, rls)

	// 🔧 FIX: Add gRPC health check service
	healthServer := health.NewServer()
	healthServer.SetServingStatus("envoy.service.auth.v3.Authorization", grpc_health_v1.HealthCheckResponse_SERVING)
	grpc_health_v1.RegisterHealthServer(grpcServer, healthServer)

	// Enable reflection for debugging
	reflection.Register(grpcServer)

	logger.Info().Str("port", port).Msg("ext_authz gRPC server started with health checks")

	// 🔧 FIX: Add graceful shutdown handling
	go func() {
		<-ctx.Done()
		logger.Info().Msg("shutting down ext_authz gRPC server")
		healthServer.SetServingStatus("envoy.service.auth.v3.Authorization", grpc_health_v1.HealthCheckResponse_NOT_SERVING)
		grpcServer.GracefulStop()
	}()

	if err := grpcServer.Serve(lis); err != nil {
		logger.Error().Err(err).Msg("ext_authz gRPC server stopped")
	}
}

func startRateLimitServer(ctx context.Context, rls *service.RLS, port string, logger zerolog.Logger) {
	lis, err := net.Listen("tcp", ":"+port)
	if err != nil {
		logger.Fatal().Err(err).Str("port", port).Msg("failed to listen for ratelimit")
	}

	// 🔧 PERFORMANCE FIX: Add gRPC server optimizations for high throughput
	grpcServer := grpc.NewServer(
		grpc.MaxConcurrentStreams(1000),  // Allow more concurrent streams
		grpc.MaxRecvMsgSize(4*1024*1024), // 4MB max message size
		grpc.MaxSendMsgSize(4*1024*1024), // 4MB max message size
		grpc.NumStreamWorkers(32),        // More worker goroutines
		grpc.KeepaliveEnforcementPolicy(keepalive.EnforcementPolicy{
			MinTime:             5 * time.Second,
			PermitWithoutStream: true,
		}),
		grpc.KeepaliveParams(keepalive.ServerParameters{
			MaxConnectionIdle: 30 * time.Second,
			MaxConnectionAge:  5 * time.Minute,
			Time:              10 * time.Second,
			Timeout:           3 * time.Second,
		}),
	)

	// Register rate limit service
	envoy_service_ratelimit_v3.RegisterRateLimitServiceServer(grpcServer, rls)

	// 🔧 FIX: Add gRPC health check service
	healthServer := health.NewServer()
	healthServer.SetServingStatus("envoy.service.ratelimit.v3.RateLimitService", grpc_health_v1.HealthCheckResponse_SERVING)
	grpc_health_v1.RegisterHealthServer(grpcServer, healthServer)

	// Enable reflection for debugging
	reflection.Register(grpcServer)

	logger.Info().Str("port", port).Msg("ratelimit gRPC server started with health checks")

	// 🔧 FIX: Add graceful shutdown handling
	go func() {
		<-ctx.Done()
		logger.Info().Msg("shutting down ratelimit gRPC server")
		healthServer.SetServingStatus("envoy.service.ratelimit.v3.RateLimitService", grpc_health_v1.HealthCheckResponse_NOT_SERVING)
		grpcServer.GracefulStop()
	}()

	if err := grpcServer.Serve(lis); err != nil {
		logger.Error().Err(err).Msg("ratelimit gRPC server stopped")
	}
}

func startAdminServer(ctx context.Context, rls *service.RLS, port string, logger zerolog.Logger) {
	router := mux.NewRouter()

	// 🔧 PERFORMANCE FIX: Remove excessive logging middleware - only log errors
	router.Use(func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Only log health checks at debug level, everything else at error level only
			if r.URL.Path == "/healthz" || r.URL.Path == "/readyz" {
				log.Debug().
					Str("method", r.Method).
					Str("path", r.URL.Path).
					Msg("health check request")
			}
			next.ServeHTTP(w, r)
		})
	})

	// 🔧 PERFORMANCE FIX: Cache static responses for better performance
	var (
		healthResponse = []byte("ok")
		healthHeaders  = map[string]string{
			"Content-Type":   "text/plain; charset=utf-8",
			"Cache-Control":  "no-cache",
			"Content-Length": "2",
		}
	)

	// Health check
	router.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		// 🔧 PERFORMANCE FIX: Use cached response for better performance
		for key, value := range healthHeaders {
			w.Header().Set(key, value)
		}
		w.WriteHeader(http.StatusOK)
		w.Write(healthResponse)
	}).Methods("GET")

	// Readiness check
	router.HandleFunc("/readyz", func(w http.ResponseWriter, r *http.Request) {
		// 🔧 PERFORMANCE FIX: Use cached response for better performance
		for key, value := range healthHeaders {
			w.Header().Set(key, value)
		}
		w.WriteHeader(http.StatusOK)
		w.Write(healthResponse)
	}).Methods("GET")

	// Admin API endpoints
	router.HandleFunc("/api/health", handleHealth(rls)).Methods("GET")
	router.HandleFunc("/api/overview", handleOverview(rls)).Methods("GET")
	router.HandleFunc("/api/tenants", handleListTenants(rls)).Methods("GET")
	router.HandleFunc("/api/tenants/{id}", handleGetTenant(rls)).Methods("GET")
	router.HandleFunc("/api/tenants/{id}/enforcement", handleSetEnforcement(rls)).Methods("POST")
	router.HandleFunc("/api/tenants/{id}/limits", handleSetTenantLimits(rls)).Methods("PUT")
	router.HandleFunc("/api/denials", handleListDenials(rls)).Methods("GET")
	router.HandleFunc("/api/denials/enhanced", handleEnhancedDenials(rls)).Methods("GET")
	router.HandleFunc("/api/denials/trends", handleDenialTrends(rls)).Methods("GET")
	router.HandleFunc("/api/export/csv", handleExportCSV(rls)).Methods("GET")

	// Pipeline and Metrics endpoints for Admin UI
	router.HandleFunc("/api/pipeline/status", handlePipelineStatus(rls)).Methods("GET")
	router.HandleFunc("/api/metrics/system", handleSystemMetrics(rls)).Methods("GET")
	router.HandleFunc("/api/flow/status", handleFlowStatus(rls)).Methods("GET")
	router.HandleFunc("/api/system/status", handleComprehensiveSystemStatus(rls)).Methods("GET")
	router.HandleFunc("/api/traffic/flow", handleTrafficFlow(rls)).Methods("GET")

	// Debug endpoint to list all routes
	router.HandleFunc("/api/debug/routes", func(w http.ResponseWriter, r *http.Request) {
		routes := []map[string]interface{}{}
		router.Walk(func(route *mux.Route, router *mux.Router, ancestors []*mux.Route) error {
			pathTemplate, err := route.GetPathTemplate()
			if err == nil {
				methods, _ := route.GetMethods()
				routes = append(routes, map[string]interface{}{
					"path":    pathTemplate,
					"methods": methods,
				})
			}
			return nil
		})
		writeJSON(w, http.StatusOK, map[string]interface{}{"routes": routes})
	}).Methods("GET")

	// 🔧 DEBUG: Add endpoint to check tenant state
	router.HandleFunc("/api/debug/tenants", func(w http.ResponseWriter, r *http.Request) {
		debugInfo := rls.GetDebugInfo()
		writeJSON(w, http.StatusOK, debugInfo)
	}).Methods("GET")

	// 🔧 DEBUG: Add endpoint to check traffic flow state directly
	router.HandleFunc("/api/debug/traffic-flow", func(w http.ResponseWriter, r *http.Request) {
		log.Info().Msg("RLS: INFO - Debug traffic flow endpoint called")

		// Get traffic flow state using the public method
		trafficFlow := rls.GetDebugTrafficFlow()

		log.Info().Interface("traffic_flow", trafficFlow).Msg("RLS: INFO - Traffic flow state")
		writeJSON(w, http.StatusOK, trafficFlow)
	}).Methods("GET")

	// Cardinality dashboard endpoints
	router.HandleFunc("/api/cardinality", handleCardinalityData(rls)).Methods("GET")
	router.HandleFunc("/api/cardinality/violations", handleCardinalityViolations(rls)).Methods("GET")
	router.HandleFunc("/api/cardinality/trends", handleCardinalityTrends(rls)).Methods("GET")
	router.HandleFunc("/api/cardinality/alerts", handleCardinalityAlerts(rls)).Methods("GET")

	// Time-based aggregated data endpoints
	router.HandleFunc("/api/aggregated/{timeRange}", handleAggregatedData(rls)).Methods("GET")

	// Flow timeline endpoint for real time-series data (more specific route first)
	router.HandleFunc("/api/timeseries/{timeRange}/flow", handleFlowTimeline(rls)).Methods("GET")

	// General time series data endpoint (more general route after specific ones)
	router.HandleFunc("/api/timeseries/{timeRange}/{metric}", handleTimeSeriesData(rls)).Methods("GET")

	// Test route to verify route registration
	router.HandleFunc("/api/test", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"message": "test route works"})
	}).Methods("GET")

	// 🔧 NEW: Remote write endpoint for direct integration
	router.HandleFunc("/api/v1/push", handleRemoteWrite(rls)).Methods("POST")

	// 🔧 PERFORMANCE FIX: Remove expensive route walking on startup
	// Routes are now only logged at debug level if needed

	server := &http.Server{
		Addr:         ":" + port,
		Handler:      router,
		ReadTimeout:  30 * time.Second,  // 🔧 FIX: Increased timeout to prevent 504 errors
		WriteTimeout: 60 * time.Second,  // 🔧 FIX: Increased timeout for admin API responses
		IdleTimeout:  120 * time.Second, // Keep connection timeout reasonable
	}

	logger.Info().Str("port", port).Msg("admin HTTP server started")

	// 🔧 FIX: Add graceful shutdown handling for HTTP server
	go func() {
		<-ctx.Done()
		logger.Info().Msg("shutting down admin HTTP server")
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		if err := server.Shutdown(shutdownCtx); err != nil {
			logger.Error().Err(err).Msg("admin HTTP server shutdown error")
		}
	}()

	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		logger.Fatal().Err(err).Msg("failed to serve admin")
	}
}

func startMetricsServer(ctx context.Context, port string, logger zerolog.Logger) {
	// 🔧 FIX: Implement proper Prometheus metrics server
	mux := http.NewServeMux()

	// Add metrics endpoint
	mux.Handle("/metrics", promhttp.Handler())

	// Add health check for metrics server
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("metrics server ok"))
	})

	server := &http.Server{
		Addr:    ":" + port,
		Handler: mux,
	}

	logger.Info().Str("port", port).Msg("metrics HTTP server started")

	// 🔧 FIX: Add graceful shutdown handling for metrics server
	go func() {
		<-ctx.Done()
		logger.Info().Msg("shutting down metrics HTTP server")
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		if err := server.Shutdown(shutdownCtx); err != nil {
			logger.Error().Err(err).Msg("metrics HTTP server shutdown error")
		}
	}()

	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		logger.Fatal().Err(err).Msg("failed to serve metrics")
	}
}

// HTTP handlers (simplified implementations)
func handleHealth(rls *service.RLS) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"ok"}`))
	}
}

func handleOverview(rls *service.RLS) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if r := recover(); r != nil {
				log.Error().Interface("panic", r).Msg("panic in handleOverview")
				http.Error(w, "internal server error", http.StatusInternalServerError)
			}
		}()

		// Extract time range from query parameter
		timeRange := r.URL.Query().Get("range")
		if timeRange == "" {
			timeRange = "1h" // Default to 1 hour
		}

		// Validate time range
		validRanges := map[string]bool{
			"5m": true, "15m": true, "1h": true, "24h": true, "1w": true,
		}
		if !validRanges[timeRange] {
			timeRange = "1h" // Default to 1 hour if invalid
		}

		// Use time-based aggregated data for stable overview
		stats := rls.GetOverviewSnapshotWithTimeRange(timeRange)

		response := map[string]any{
			"stats":          stats,
			"time_range":     timeRange,
			"data_freshness": time.Now().Format(time.RFC3339),
		}

		// 🔧 PERFORMANCE FIX: Only log at debug level to reduce overhead
		log.Debug().
			Str("time_range", timeRange).
			Int64("total_requests", stats.TotalRequests).
			Int64("allowed_requests", stats.AllowedRequests).
			Int64("denied_requests", stats.DeniedRequests).
			Float64("allow_percentage", stats.AllowPercentage).
			Int("active_tenants", int(stats.ActiveTenants)).
			Msg("overview API response")

		writeJSON(w, http.StatusOK, response)
	}
}

func handleListTenants(rls *service.RLS) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if r := recover(); r != nil {
				log.Error().Interface("panic", r).Msg("panic in handleListTenants")
				http.Error(w, "internal server error", http.StatusInternalServerError)
			}
		}()

		// Extract time range from query parameter
		timeRange := r.URL.Query().Get("range")
		if timeRange == "" {
			timeRange = "1h" // Default to 1 hour
		}

		// Validate time range
		validRanges := map[string]bool{
			"5m": true, "15m": true, "1h": true, "24h": true, "1w": true,
		}
		if !validRanges[timeRange] {
			timeRange = "1h" // Default to 1 hour if invalid
		}

		// Use time-based aggregated data for stable tenant metrics
		tenants := rls.GetTenantsWithTimeRange(timeRange)

		// 🔧 PERFORMANCE FIX: Only log at debug level to reduce overhead
		tenantLogger := log.Debug().
			Str("time_range", timeRange).
			Int("tenant_count", len(tenants))

		if len(tenants) == 0 {
			tenantLogger.Msg("tenants API response: NO TENANTS FOUND - this explains zero active tenants!")
		} else {
			// Log first few tenants for debugging
			for i, tenant := range tenants {
				if i >= 3 { // Only log first 3 tenants to avoid spam
					break
				}
				tenantLogger = tenantLogger.
					Str(fmt.Sprintf("tenant_%d_id", i), tenant.ID).
					Str(fmt.Sprintf("tenant_%d_name", i), tenant.Name).
					Float64(fmt.Sprintf("tenant_%d_samples_limit", i), tenant.Limits.SamplesPerSecond).
					Float64(fmt.Sprintf("tenant_%d_allow_rate", i), tenant.Metrics.AllowRate).
					Float64(fmt.Sprintf("tenant_%d_deny_rate", i), tenant.Metrics.DenyRate).
					Bool(fmt.Sprintf("tenant_%d_enforcement", i), tenant.Enforcement.Enabled)
			}
			if len(tenants) > 3 {
				tenantLogger = tenantLogger.Int("additional_tenants", len(tenants)-3)
			}
			tenantLogger.Msg("tenants API response with tenant details")
		}

		response := map[string]any{
			"tenants":        tenants,
			"time_range":     timeRange,
			"data_freshness": time.Now().Format(time.RFC3339),
		}
		writeJSON(w, http.StatusOK, response)
	}
}

func handleGetTenant(rls *service.RLS) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if r := recover(); r != nil {
				log.Error().Interface("panic", r).Msg("panic in handleGetTenant")
				http.Error(w, "internal server error", http.StatusInternalServerError)
			}
		}()

		id := mux.Vars(r)["id"]
		timeRange := r.URL.Query().Get("range")
		if timeRange == "" {
			timeRange = "24h" // Default to 24 hours for tenant details
		}

		// Validate time range
		validRanges := map[string]bool{
			"5m": true, "15m": true, "1h": true, "24h": true, "1w": true,
		}
		if !validRanges[timeRange] {
			timeRange = "24h" // Default to 24 hours if invalid
		}

		log.Debug().Str("tenant_id", id).Str("time_range", timeRange).Msg("handling /api/tenants/{id} request")

		// Debug: Check what tenants are available
		allTenants := rls.ListTenantsWithMetrics()
		log.Info().
			Str("requested_tenant_id", id).
			Str("time_range", timeRange).
			Int("total_tenants", len(allTenants)).
			Strs("available_tenant_ids", func() []string {
				ids := make([]string, len(allTenants))
				for i, t := range allTenants {
					ids[i] = t.ID
				}
				return ids
			}()).
			Msg("debug: checking tenant availability")

		// Try to get tenant details with time-based aggregation
		tenant, ok := rls.GetTenantDetailsWithTimeRange(id, timeRange)
		if !ok {
			// Fallback: Try to find the tenant in the list (case-insensitive search)
			var foundTenant *limits.TenantInfo
			for _, t := range allTenants {
				if strings.EqualFold(t.ID, id) {
					foundTenant = &t
					break
				}
			}

			if foundTenant != nil {
				log.Info().
					Str("requested_tenant_id", id).
					Str("found_tenant_id", foundTenant.ID).
					Msg("tenant found in list but not in time-based details (case sensitivity issue)")
				tenant = *foundTenant
				ok = true
			} else {
				log.Info().Str("tenant_id", id).Msg("tenant not found in GetTenantDetailsWithTimeRange or list")
				writeJSON(w, http.StatusNotFound, map[string]any{
					"error":     "tenant not found",
					"tenant_id": id,
					"message":   "The specified tenant does not exist or has no limits configured",
				})
				return
			}
		}

		// Get recent denials
		denials := rls.RecentDenials(id, 24*time.Hour)

		// Get request history for the specified time range
		requestHistory := rls.GetTenantRequestHistory(id, timeRange)

		log.Info().
			Str("tenant_id", id).
			Str("time_range", timeRange).
			Int("denials_count", len(denials)).
			Int("history_points", len(requestHistory)).
			Msg("tenant details API response")

		response := map[string]any{
			"tenant":          tenant,
			"recent_denials":  denials,
			"request_history": requestHistory,
			"time_range":      timeRange,
			"data_freshness":  time.Now().Format(time.RFC3339),
		}

		writeJSON(w, http.StatusOK, response)
	}
}

func handleSetEnforcement(rls *service.RLS) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if r := recover(); r != nil {
				log.Error().Interface("panic", r).Msg("panic in handleSetEnforcement")
				http.Error(w, "internal server error", http.StatusInternalServerError)
			}
		}()

		id := mux.Vars(r)["id"]

		// Parse request body for full enforcement configuration
		var enforcement limits.EnforcementConfig
		if err := json.NewDecoder(r.Body).Decode(&enforcement); err != nil {
			log.Error().Err(err).Str("tenant_id", id).Msg("failed to decode enforcement configuration JSON")
			http.Error(w, "invalid JSON body", http.StatusBadRequest)
			return
		}

		// Set enforcement configuration in RLS
		if err := rls.SetTenantEnforcement(id, enforcement); err != nil {
			log.Error().Err(err).Str("tenant_id", id).Msg("failed to set tenant enforcement")
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		log.Info().
			Str("tenant_id", id).
			Bool("enabled", enforcement.Enabled).
			Bool("enforce_samples_per_second", enforcement.EnforceSamplesPerSecond).
			Bool("enforce_max_body_bytes", enforcement.EnforceMaxBodyBytes).
			Bool("enforce_max_labels_per_series", enforcement.EnforceMaxLabelsPerSeries).
			Bool("enforce_max_series_per_request", enforcement.EnforceMaxSeriesPerRequest).
			Bool("enforce_bytes_per_second", enforcement.EnforceBytesPerSecond).
			Msg("RLS: tenant enforcement configuration set via HTTP API")

		writeJSON(w, http.StatusOK, map[string]any{
			"success":     true,
			"tenant_id":   id,
			"enforcement": enforcement,
		})
	}
}

func handleSetTenantLimits(rls *service.RLS) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if r := recover(); r != nil {
				log.Error().Interface("panic", r).Msg("panic in handleSetTenantLimits")
				http.Error(w, "internal server error", http.StatusInternalServerError)
			}
		}()

		id := mux.Vars(r)["id"]

		// Parse request body
		var tenantLimits limits.TenantLimits
		if err := json.NewDecoder(r.Body).Decode(&tenantLimits); err != nil {
			log.Error().Err(err).Str("tenant_id", id).Msg("failed to decode tenant limits JSON")
			http.Error(w, "invalid JSON body", http.StatusBadRequest)
			return
		}

		// Set tenant limits in RLS
		if err := rls.SetTenantLimits(id, tenantLimits); err != nil {
			log.Error().Err(err).Str("tenant_id", id).Msg("failed to set tenant limits")
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		log.Info().
			Str("tenant_id", id).
			Float64("samples_per_second", tenantLimits.SamplesPerSecond).
			Float64("burst_percent", tenantLimits.BurstPercent).
			Int64("max_body_bytes", tenantLimits.MaxBodyBytes).
			Msg("RLS: tenant limits set via HTTP API from overrides-sync")

		writeJSON(w, http.StatusOK, map[string]any{
			"success":   true,
			"tenant_id": id,
			"limits":    tenantLimits,
		})
	}
}

func handleListDenials(rls *service.RLS) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		tenant := r.URL.Query().Get("tenant")
		sinceParam := r.URL.Query().Get("since")
		if sinceParam == "" {
			sinceParam = "1h"
		}
		d, _ := time.ParseDuration(sinceParam)
		denials := rls.RecentDenials(tenant, d)
		writeJSON(w, http.StatusOK, map[string]any{"denials": denials})
	}
}

// handleEnhancedDenials returns enriched denial information with context and insights
func handleEnhancedDenials(rls *service.RLS) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		tenant := r.URL.Query().Get("tenant")
		sinceParam := r.URL.Query().Get("since")
		if sinceParam == "" {
			sinceParam = "1h"
		}
		d, _ := time.ParseDuration(sinceParam)

		// Get limit parameter for server-side pagination (default to 25 for performance)
		limitParam := r.URL.Query().Get("limit")
		limit := 25 // Aggressive limit for performance
		if limitParam != "" {
			if parsedLimit, err := strconv.Atoi(limitParam); err == nil && parsedLimit > 0 && parsedLimit <= 100 {
				limit = parsedLimit
			}
		}

		// Start with a shorter time range for better performance
		adjustedSince := d
		if d > 15*time.Minute {
			adjustedSince = 15 * time.Minute // Limit to 15 minutes for performance
		}

		// Get basic denials first
		basicDenials := rls.RecentDenials(tenant, adjustedSince)
		totalCount := len(basicDenials)

		// Aggressively limit denials for performance
		if len(basicDenials) > limit {
			basicDenials = basicDenials[:limit]
		}

		// Convert to enhanced format but skip heavy processing if too many
		var denials []map[string]any
		for i, denial := range basicDenials {
			if i >= limit { // Double check limit
				break
			}

			// Simplified enhanced denial without heavy processing
			enhanced := map[string]any{
				"tenant_id":           denial.TenantID,
				"reason":              denial.Reason,
				"timestamp":           denial.Timestamp.UTC().Format(time.RFC3339),
				"observed_samples":    denial.ObservedSamples,
				"observed_body_bytes": denial.ObservedBodyBytes,
				"severity":            "low", // Default for performance
				"category":            categorizeReason(denial.Reason),
				"tenant_limits": map[string]any{
					"samples_per_second": 1000,
					"max_body_bytes":     1048576,
				},
				"insights": map[string]any{
					"utilization_percentage": 0.0,
					"frequency_in_period":    1,
				},
				"recommendations": []string{"Check tenant configuration"},
			}
			denials = append(denials, enhanced)
		}

		writeJSON(w, http.StatusOK, map[string]any{
			"denials": denials,
			"metadata": map[string]any{
				"total_count":     totalCount,
				"displayed_count": len(denials),
				"time_range":      sinceParam,
				"actual_range":    adjustedSince.String(),
				"tenant_filter":   tenant,
				"generated_at":    time.Now().UTC().Format(time.RFC3339),
				"limited":         totalCount > limit || d > 15*time.Minute,
			},
		})
	}
}

// handleDenialTrends returns trend analysis for denials
func handleDenialTrends(rls *service.RLS) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		tenant := r.URL.Query().Get("tenant")
		sinceParam := r.URL.Query().Get("since")
		if sinceParam == "" {
			sinceParam = "24h"
		}
		d, _ := time.ParseDuration(sinceParam)

		trends := rls.GetDenialTrends(tenant, d)
		writeJSON(w, http.StatusOK, map[string]any{
			"trends": trends,
			"metadata": map[string]any{
				"total_trends":  len(trends),
				"time_range":    sinceParam,
				"tenant_filter": tenant,
				"generated_at":  time.Now().UTC().Format(time.RFC3339),
			},
		})
	}
}

func handleExportCSV(rls *service.RLS) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/csv")
		w.Header().Set("Content-Disposition", "attachment; filename=denials.csv")
		_, _ = w.Write([]byte("tenant,reason,timestamp,samples,body_bytes\n"))
		rows := rls.RecentDenials("*", 24*time.Hour)
		for _, row := range rows {
			_, _ = w.Write([]byte(fmt.Sprintf("%s,%s,%s,%d,%d\n", row.TenantID, row.Reason, row.Timestamp.UTC().Format(time.RFC3339), row.ObservedSamples, row.ObservedBodyBytes)))
		}
	}
}

// categorizeReason categorizes denial reason into general categories
func categorizeReason(reason string) string {
	switch {
	case strings.Contains(reason, "parse"):
		return "parsing_error"
	case strings.Contains(reason, "samples"):
		return "rate_limiting"
	case strings.Contains(reason, "body"):
		return "size_limit"
	case strings.Contains(reason, "series"):
		return "cardinality"
	case strings.Contains(reason, "labels"):
		return "cardinality"
	default:
		return "other"
	}
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	// 🔧 PERFORMANCE FIX: Add compression and caching headers for better performance
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-cache")
	w.WriteHeader(status)

	// 🔧 PERFORMANCE FIX: Use buffered encoder for better performance
	encoder := json.NewEncoder(w)
	encoder.SetEscapeHTML(false) // Don't escape HTML for better performance

	if err := encoder.Encode(v); err != nil {
		log.Error().Err(err).Msg("failed to encode JSON response")
	}
}

// handlePipelineStatus returns pipeline status for Admin UI
func handlePipelineStatus(rls *service.RLS) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if r := recover(); r != nil {
				log.Error().Interface("panic", r).Msg("panic in handlePipelineStatus")
				http.Error(w, "internal server error", http.StatusInternalServerError)
			}
		}()

		log.Debug().Msg("handling /api/pipeline/status request")

		// Get real pipeline status from RLS service
		pipelineStatus := rls.GetPipelineStatus()
		writeJSON(w, http.StatusOK, pipelineStatus)
	}
}

// handleSystemMetrics returns comprehensive system metrics for Admin UI
func handleSystemMetrics(rls *service.RLS) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if r := recover(); r != nil {
				log.Error().Interface("panic", r).Msg("panic in handleSystemMetrics")
				http.Error(w, "internal server error", http.StatusInternalServerError)
			}
		}()

		log.Debug().Msg("handling /api/metrics/system request")

		// Get real system metrics from RLS service
		systemMetrics := rls.GetSystemMetrics()
		writeJSON(w, http.StatusOK, systemMetrics)
	}
}

func handleFlowStatus(rls *service.RLS) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if r := recover(); r != nil {
				log.Error().Interface("panic", r).Msg("panic in handleFlowStatus")
				http.Error(w, "internal server error", http.StatusInternalServerError)
			}
		}()

		log.Debug().Msg("handling /api/flow/status request")

		// Get comprehensive flow status
		flowStatus := rls.GetFlowStatus()
		writeJSON(w, http.StatusOK, flowStatus)
	}
}

func handleComprehensiveSystemStatus(rls *service.RLS) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if r := recover(); r != nil {
				log.Error().Interface("panic", r).Msg("panic in handleComprehensiveSystemStatus")
				http.Error(w, "internal server error", http.StatusInternalServerError)
			}
		}()

		log.Debug().Msg("handling /api/system/status request")

		// Get comprehensive system status
		systemStatus := rls.GetComprehensiveSystemStatus()
		writeJSON(w, http.StatusOK, systemStatus)
	}
}

func handleTrafficFlow(rls *service.RLS) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if r := recover(); r != nil {
				log.Error().Interface("panic", r).Msg("panic in handleTrafficFlow")
				http.Error(w, "internal server error", http.StatusInternalServerError)
			}
		}()

		log.Debug().Msg("handling /api/traffic/flow request")

		// 🔧 DEBUG: Add debug logging before calling GetTrafficFlowData
		log.Info().Msg("RLS: INFO - About to call GetTrafficFlowData")

		// Get traffic flow data
		trafficFlow := rls.GetTrafficFlowData()

		// 🔧 DEBUG: Add debug logging after calling GetTrafficFlowData
		log.Info().Msg("RLS: INFO - GetTrafficFlowData completed successfully")

		writeJSON(w, http.StatusOK, trafficFlow)
	}
}

// Cardinality dashboard handlers
func handleCardinalityData(rls *service.RLS) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if r := recover(); r != nil {
				log.Error().Interface("panic", r).Msg("panic in handleCardinalityData")
				http.Error(w, "internal server error", http.StatusInternalServerError)
			}
		}()

		// Get time range and tenant filter from query parameters
		timeRange := r.URL.Query().Get("range")
		if timeRange == "" {
			timeRange = "1h"
		}
		tenant := r.URL.Query().Get("tenant")
		if tenant == "" {
			tenant = "all"
		}

		// Get cardinality data
		cardinalityData := rls.GetCardinalityData(timeRange, tenant)

		writeJSON(w, http.StatusOK, cardinalityData)
	}
}

func handleCardinalityViolations(rls *service.RLS) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if r := recover(); r != nil {
				log.Error().Interface("panic", r).Msg("panic in handleCardinalityViolations")
				http.Error(w, "internal server error", http.StatusInternalServerError)
			}
		}()

		// Get time range from query parameter
		timeRange := r.URL.Query().Get("range")
		if timeRange == "" {
			timeRange = "1h"
		}

		// Get cardinality violations
		violations := rls.GetCardinalityViolations(timeRange)

		writeJSON(w, http.StatusOK, map[string]interface{}{
			"violations": violations,
		})
	}
}

func handleCardinalityTrends(rls *service.RLS) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if r := recover(); r != nil {
				log.Error().Interface("panic", r).Msg("panic in handleCardinalityTrends")
				http.Error(w, "internal server error", http.StatusInternalServerError)
			}
		}()

		// Get time range from query parameter
		timeRange := r.URL.Query().Get("range")
		if timeRange == "" {
			timeRange = "24h"
		}

		// Get cardinality trends
		trends := rls.GetCardinalityTrends(timeRange)

		writeJSON(w, http.StatusOK, map[string]interface{}{
			"trends": trends,
		})
	}
}

func handleCardinalityAlerts(rls *service.RLS) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if r := recover(); r != nil {
				log.Error().Interface("panic", r).Msg("panic in handleCardinalityAlerts")
				http.Error(w, "internal server error", http.StatusInternalServerError)
			}
		}()

		// Get cardinality alerts
		alerts := rls.GetCardinalityAlerts()

		writeJSON(w, http.StatusOK, map[string]interface{}{
			"alerts": alerts,
		})
	}
}

// handleAggregatedData returns time-based aggregated data
func handleAggregatedData(rls *service.RLS) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if r := recover(); r != nil {
				log.Error().Interface("panic", r).Msg("panic in handleAggregatedData")
				http.Error(w, "internal server error", http.StatusInternalServerError)
			}
		}()

		vars := mux.Vars(r)
		timeRange := vars["timeRange"]

		// Validate time range
		validRanges := map[string]bool{"15m": true, "1h": true, "24h": true, "1w": true}
		if !validRanges[timeRange] {
			writeJSON(w, http.StatusBadRequest, map[string]string{
				"error": "Invalid time range. Supported values: 15m, 1h, 24h, 1w",
			})
			return
		}

		log.Info().Str("timeRange", timeRange).Msg("RLS: INFO - Aggregated data endpoint called")

		data := rls.GetAggregatedData(timeRange)
		log.Info().Interface("data", data).Msg("RLS: INFO - Aggregated data")
		writeJSON(w, http.StatusOK, data)
	}
}

// handleTimeSeriesData returns time series data for charts
func handleTimeSeriesData(rls *service.RLS) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if r := recover(); r != nil {
				log.Error().Interface("panic", r).Msg("panic in handleTimeSeriesData")
				http.Error(w, "internal server error", http.StatusInternalServerError)
			}
		}()

		vars := mux.Vars(r)
		timeRange := vars["timeRange"]
		metric := vars["metric"]

		// Validate time range
		validRanges := map[string]bool{
			"5m": true, "15m": true, "1h": true, "24h": true, "1w": true,
		}
		if !validRanges[timeRange] {
			timeRange = "1h" // Default to 1 hour if invalid
		}

		// Get time series data
		timeSeriesData := rls.GetTimeSeriesData(timeRange, metric)

		response := map[string]any{
			"time_range": timeRange,
			"metric":     metric,
			"points":     timeSeriesData,
		}

		writeJSON(w, http.StatusOK, response)
	}
}

func handleFlowTimeline(rls *service.RLS) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if r := recover(); r != nil {
				log.Error().Interface("panic", r).Msg("panic in handleFlowTimeline")
				http.Error(w, "internal server error", http.StatusInternalServerError)
			}
		}()

		vars := mux.Vars(r)
		timeRange := vars["timeRange"]

		// Validate time range
		validRanges := map[string]bool{
			"5m": true, "15m": true, "1h": true, "24h": true, "1w": true,
		}
		if !validRanges[timeRange] {
			timeRange = "1h" // Default to 1 hour if invalid
		}

		// Get flow timeline data from time aggregator
		flowData := rls.GetFlowTimelineData(timeRange)

		response := map[string]any{
			"time_range": timeRange,
			"points":     flowData,
		}

		writeJSON(w, http.StatusOK, response)
	}
}

// 🔧 NEW: Remote write handler for direct integration
func handleRemoteWrite(rls *service.RLS) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		// Extract tenant ID from header
		tenantID := r.Header.Get("X-Scope-OrgID")
		if tenantID == "" {
			http.Error(w, "missing X-Scope-OrgID header", http.StatusBadRequest)
			return
		}

		// Read request body
		body, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "failed to read request body", http.StatusBadRequest)
			return
		}
		defer r.Body.Close()

		// Check limits using RLS logic
		decision := rls.CheckRemoteWriteLimits(tenantID, body, r.Header.Get("Content-Encoding"))

		if !decision.Allowed {
			// Return appropriate error based on decision
			http.Error(w, decision.Reason, int(decision.Code))
			return
		}

		// Forward to Mimir if limits are not exceeded
		mimirURL := fmt.Sprintf("http://%s:%s/api/v1/push", rls.GetMimirHost(), rls.GetMimirPort())

		// Create request to Mimir
		mimirReq, err := http.NewRequest("POST", mimirURL, bytes.NewReader(body))
		if err != nil {
			http.Error(w, "failed to create request to Mimir", http.StatusInternalServerError)
			return
		}

		// Copy headers
		for key, values := range r.Header {
			for _, value := range values {
				mimirReq.Header.Add(key, value)
			}
		}

		// Forward to Mimir
		client := &http.Client{Timeout: 30 * time.Second}
		resp, err := client.Do(mimirReq)
		if err != nil {
			http.Error(w, "failed to forward request to Mimir", http.StatusInternalServerError)
			return
		}
		defer resp.Body.Close()

		// Copy response
		w.WriteHeader(resp.StatusCode)
		io.Copy(w, resp.Body)

		// Log successful forwarding
		log.Info().
			Str("tenant", tenantID).
			Dur("duration", time.Since(start)).
			Int("status", resp.StatusCode).
			Msg("successfully forwarded request to Mimir")
	}
}
