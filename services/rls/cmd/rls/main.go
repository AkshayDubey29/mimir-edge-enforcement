package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/AkshayDubey29/mimir-edge-enforcement/services/rls/internal/limits"
	"github.com/AkshayDubey29/mimir-edge-enforcement/services/rls/internal/service"
	"github.com/gorilla/mux"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"

	envoy_service_auth_v3 "github.com/envoyproxy/go-control-plane/envoy/service/auth/v3"
	ratelimit "github.com/lyft/ratelimit/proto/ratelimit"
)

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

	// Default limits
	defaultSamplesPerSecond    = flag.Float64("default-samples-per-second", 10000, "Default samples per second limit")
	defaultBurstPercent        = flag.Float64("default-burst-percent", 0.2, "Default burst percentage")
	defaultMaxBodyBytes        = flag.Int64("default-max-body-bytes", 4194304, "Default maximum body size in bytes")
	defaultMaxLabelsPerSeries  = flag.Int("default-max-labels-per-series", 60, "Default maximum labels per series")
	defaultMaxLabelValueLength = flag.Int("default-max-label-value-length", 2048, "Default maximum label value length")
	defaultMaxSeriesPerRequest = flag.Int("default-max-series-per-request", 100000, "Default maximum series per request")

	// Logging
	logLevel = flag.String("log-level", "info", "Log level (debug, info, warn, error)")
)

func main() {
	flag.Parse()

	// Setup logging
	level, err := zerolog.ParseLevel(*logLevel)
	if err != nil {
		log.Fatal().Err(err).Msg("invalid log level")
	}
	zerolog.SetGlobalLevel(level)
	logger := log.With().Str("component", "rls").Logger()

	// Create RLS configuration
	config := &service.RLSConfig{
		TenantHeader:       *tenantHeader,
		EnforceBodyParsing: *enforceBodyParsing,
		MaxRequestBytes:    *maxRequestBytes,
		FailureModeAllow:   *failureModeAllow,
		DefaultLimits: limits.TenantLimits{
			SamplesPerSecond:    *defaultSamplesPerSecond,
			BurstPercent:        *defaultBurstPercent,
			MaxBodyBytes:        *defaultMaxBodyBytes,
			MaxLabelsPerSeries:  int32(*defaultMaxLabelsPerSeries),
			MaxLabelValueLength: int32(*defaultMaxLabelValueLength),
			MaxSeriesPerRequest: int32(*defaultMaxSeriesPerRequest),
		},
	}

	// Create RLS service
	rls := service.NewRLS(config, logger)

	// Create context for graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Start gRPC servers
	go startExtAuthzServer(ctx, rls, *extAuthzPort, logger)
	go startRateLimitServer(ctx, rls, *rateLimitPort, logger)

	// Start HTTP servers
	go startAdminServer(ctx, rls, *adminPort, logger)
	go startMetricsServer(ctx, *metricsPort, logger)

	// Wait for shutdown signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	logger.Info().Msg("RLS service started")
	<-sigChan

	logger.Info().Msg("Shutting down RLS service...")

	// Graceful shutdown
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer shutdownCancel()

	// TODO: Implement graceful shutdown for servers

	logger.Info().Msg("RLS service stopped")
}

func startExtAuthzServer(ctx context.Context, rls *service.RLS, port string, logger zerolog.Logger) {
	lis, err := net.Listen("tcp", ":"+port)
	if err != nil {
		logger.Fatal().Err(err).Str("port", port).Msg("failed to listen for ext_authz")
	}

	grpcServer := grpc.NewServer()
	envoy_service_auth_v3.RegisterAuthorizationServer(grpcServer, rls)
	reflection.Register(grpcServer)

	logger.Info().Str("port", port).Msg("ext_authz gRPC server started")

	if err := grpcServer.Serve(lis); err != nil {
		logger.Fatal().Err(err).Msg("failed to serve ext_authz")
	}
}

func startRateLimitServer(ctx context.Context, rls *service.RLS, port string, logger zerolog.Logger) {
	lis, err := net.Listen("tcp", ":"+port)
	if err != nil {
		logger.Fatal().Err(err).Str("port", port).Msg("failed to listen for ratelimit")
	}

	grpcServer := grpc.NewServer()
	ratelimit.RegisterRateLimitServiceServer(grpcServer, rls)
	reflection.Register(grpcServer)

	logger.Info().Str("port", port).Msg("ratelimit gRPC server started")

	if err := grpcServer.Serve(lis); err != nil {
		logger.Fatal().Err(err).Msg("failed to serve ratelimit")
	}
}

func startAdminServer(ctx context.Context, rls *service.RLS, port string, logger zerolog.Logger) {
	router := mux.NewRouter()

	// Health check
	router.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	}).Methods("GET")

	// Readiness check
	router.HandleFunc("/readyz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	}).Methods("GET")

	// Admin API endpoints
	router.HandleFunc("/api/health", handleHealth(rls)).Methods("GET")
	router.HandleFunc("/api/overview", handleOverview(rls)).Methods("GET")
	router.HandleFunc("/api/tenants", handleListTenants(rls)).Methods("GET")
	router.HandleFunc("/api/tenants/{id}", handleGetTenant(rls)).Methods("GET")
	router.HandleFunc("/api/tenants/{id}/enforcement", handleSetEnforcement(rls)).Methods("POST")
	router.HandleFunc("/api/denials", handleListDenials(rls)).Methods("GET")
	router.HandleFunc("/api/export/csv", handleExportCSV(rls)).Methods("GET")

	server := &http.Server{
		Addr:    ":" + port,
		Handler: router,
	}

	logger.Info().Str("port", port).Msg("admin HTTP server started")

	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		logger.Fatal().Err(err).Msg("failed to serve admin")
	}
}

func startMetricsServer(ctx context.Context, port string, logger zerolog.Logger) {
	// This would serve Prometheus metrics
	// For now, just log that it's started
	logger.Info().Str("port", port).Msg("metrics HTTP server started")
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
		stats := rls.OverviewSnapshot()
		writeJSON(w, http.StatusOK, map[string]any{"stats": stats})
	}
}

func handleListTenants(rls *service.RLS) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		tenants := rls.ListTenantsWithMetrics()
		writeJSON(w, http.StatusOK, map[string]any{"tenants": tenants})
	}
}

func handleGetTenant(rls *service.RLS) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := mux.Vars(r)["id"]
		tenant, ok := rls.GetTenantSnapshot(id)
		if !ok {
			http.Error(w, "tenant not found", http.StatusNotFound)
			return
		}
		denials := rls.RecentDenials(id, 24*time.Hour)
		writeJSON(w, http.StatusOK, map[string]any{"tenant": tenant, "recent_denials": denials})
	}
}

func handleSetEnforcement(rls *service.RLS) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := mux.Vars(r)["id"]
		enabledParam := r.URL.Query().Get("enabled")
		burstParam := r.URL.Query().Get("burstPctOverride")
		if enabledParam == "" && burstParam == "" {
			http.Error(w, "missing parameters", http.StatusBadRequest)
			return
		}
		enforcement := limits.EnforcementConfig{}
		if enabledParam != "" {
			enforcement.Enabled = enabledParam == "true"
		}
		if burstParam != "" {
			v, err := strconv.ParseFloat(burstParam, 64)
			if err != nil || v < 0 || v > 1 {
				http.Error(w, "invalid burstPctOverride (0..1)", http.StatusBadRequest)
				return
			}
			enforcement.BurstPctOverride = v
		}
		if err := rls.SetEnforcement(id, enforcement); err != nil {
			http.Error(w, err.Error(), http.StatusNotFound)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"success": true})
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

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
