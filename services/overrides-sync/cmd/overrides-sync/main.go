package main

import (
	"context"
	"flag"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/AkshayDubey29/mimir-edge-enforcement/services/overrides-sync/internal/controller"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
)

var (
	// Kubernetes configuration
	kubeconfig = flag.String("kubeconfig", "", "Path to kubeconfig file (optional)")

	// Mimir configuration
	mimirNamespace     = flag.String("mimir-namespace", "mimir", "Namespace where Mimir is deployed")
	overridesConfigMap = flag.String("overrides-configmap", "mimir-overrides", "Name of the overrides ConfigMap")

	// RLS configuration
	rlsHost      = flag.String("rls-host", "mimir-rls.mimir-edge-enforcement.svc.cluster.local", "RLS service host")
	rlsAdminPort = flag.String("rls-admin-port", "8082", "RLS admin port")

	// Controller configuration
	pollFallbackSeconds = flag.Int("poll-fallback-seconds", 30, "Poll interval in seconds when watch fails")

	// Server configuration
	metricsPort = flag.String("metrics-port", "9090", "Port for metrics HTTP server")

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
	logger := log.With().Str("component", "overrides-sync").Logger()

	// Create Kubernetes client
	k8sClient, err := createK8sClient()
	if err != nil {
		logger.Fatal().Err(err).Msg("failed to create Kubernetes client")
	}

	// Create controller configuration
	config := &controller.Config{
		MimirNamespace:      *mimirNamespace,
		OverridesConfigMap:  *overridesConfigMap,
		RLSHost:             *rlsHost,
		RLSAdminPort:        *rlsAdminPort,
		PollFallbackSeconds: *pollFallbackSeconds,
	}

	// Create controller
	ctrl := controller.NewController(config, k8sClient, logger)

	// Create context for graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Start metrics server
	go startMetricsServer(ctx, *metricsPort, logger)

	// Start controller
	go func() {
		if err := ctrl.Run(ctx); err != nil {
			logger.Fatal().Err(err).Msg("controller failed")
		}
	}()

	// Wait for shutdown signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	logger.Info().Msg("overrides-sync controller started")
	<-sigChan

	logger.Info().Msg("Shutting down overrides-sync controller...")

	// Graceful shutdown
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer shutdownCancel()

	// Stop controller
	ctrl.Stop()

	logger.Info().Msg("overrides-sync controller stopped")
}

func createK8sClient() (*kubernetes.Clientset, error) {
	var config *rest.Config
	var err error

	if *kubeconfig != "" {
		// Use kubeconfig file
		config, err = clientcmd.BuildConfigFromFlags("", *kubeconfig)
	} else {
		// Use in-cluster config
		config, err = rest.InClusterConfig()
	}

	if err != nil {
		return nil, fmt.Errorf("failed to create config: %w", err)
	}

	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		return nil, fmt.Errorf("failed to create clientset: %w", err)
	}

	return clientset, nil
}

func startMetricsServer(ctx context.Context, port string, logger zerolog.Logger) {
	// This would serve Prometheus metrics
	// For now, just log that it's started
	logger.Info().Str("port", port).Msg("metrics HTTP server started")

	// Simple health check endpoint
	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	server := &http.Server{
		Addr: ":" + port,
	}

	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		logger.Error().Err(err).Msg("metrics server failed")
	}
}
