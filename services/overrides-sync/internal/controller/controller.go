package controller

import (
	"context"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/AkshayDubey29/mimir-edge-enforcement/services/overrides-sync/internal/limits"
	"github.com/rs/zerolog"
	v1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/watch"
	"k8s.io/client-go/kubernetes"
)

// Config holds the controller configuration
type Config struct {
	MimirNamespace      string
	OverridesConfigMap  string
	RLSHost             string
	RLSAdminPort        string
	PollFallbackSeconds int
}

// Controller watches Mimir overrides ConfigMap and syncs to RLS
type Controller struct {
	config    *Config
	k8sClient *kubernetes.Clientset
	logger    zerolog.Logger

	// State
	lastResourceVersion string
	stopChan            chan struct{}
}

// NewController creates a new controller
func NewController(config *Config, k8sClient *kubernetes.Clientset, logger zerolog.Logger) *Controller {
	return &Controller{
		config:    config,
		k8sClient: k8sClient,
		logger:    logger,
		stopChan:  make(chan struct{}),
	}
}

// Run starts the controller
func (c *Controller) Run(ctx context.Context) error {
	c.logger.Info().
		Str("namespace", c.config.MimirNamespace).
		Str("configmap", c.config.OverridesConfigMap).
		Msg("starting overrides sync controller")

	// Initial sync
	if err := c.syncOverrides(); err != nil {
		c.logger.Error().Err(err).Msg("initial sync failed")
	}

	// Start watching
	return c.watchOverrides(ctx)
}

// Stop stops the controller
func (c *Controller) Stop() {
	close(c.stopChan)
}

// watchOverrides watches the overrides ConfigMap for changes
func (c *Controller) watchOverrides(ctx context.Context) error {
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-c.stopChan:
			return nil
		default:
			if err := c.watchOnce(ctx); err != nil {
				c.logger.Error().Err(err).Msg("watch failed, falling back to polling")
				time.Sleep(time.Duration(c.config.PollFallbackSeconds) * time.Second)
			}
		}
	}
}

// watchOnce performs a single watch operation
func (c *Controller) watchOnce(ctx context.Context) error {
	watcher, err := c.k8sClient.CoreV1().ConfigMaps(c.config.MimirNamespace).Watch(ctx, metav1.ListOptions{
		FieldSelector: fmt.Sprintf("metadata.name=%s", c.config.OverridesConfigMap),
		Watch:         true,
	})
	if err != nil {
		return fmt.Errorf("failed to create watcher: %w", err)
	}
	defer watcher.Stop()

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-c.stopChan:
			return nil
		case event, ok := <-watcher.ResultChan():
			if !ok {
				return fmt.Errorf("watcher channel closed")
			}

			if err := c.handleEvent(event); err != nil {
				c.logger.Error().Err(err).Msg("failed to handle event")
			}
		}
	}
}

// handleEvent handles a ConfigMap event
func (c *Controller) handleEvent(event watch.Event) error {
	switch event.Type {
	case watch.Added, watch.Modified:
		configMap, ok := event.Object.(*v1.ConfigMap)
		if !ok {
			return fmt.Errorf("expected ConfigMap, got %T", event.Object)
		}

		c.logger.Info().
			Str("resourceVersion", configMap.ResourceVersion).
			Msg("ConfigMap updated")

		return c.syncOverridesFromConfigMap(configMap)

	case watch.Deleted:
		c.logger.Warn().Msg("overrides ConfigMap deleted")
		return nil

	case watch.Error:
		return fmt.Errorf("watch error")

	default:
		return nil
	}
}

// syncOverrides performs a full sync of overrides
func (c *Controller) syncOverrides() error {
	configMap, err := c.k8sClient.CoreV1().ConfigMaps(c.config.MimirNamespace).Get(
		context.Background(),
		c.config.OverridesConfigMap,
		metav1.GetOptions{},
	)
	if err != nil {
		return fmt.Errorf("failed to get ConfigMap: %w", err)
	}

	return c.syncOverridesFromConfigMap(configMap)
}

// syncOverridesFromConfigMap syncs overrides from a ConfigMap
func (c *Controller) syncOverridesFromConfigMap(configMap *v1.ConfigMap) error {
	c.lastResourceVersion = configMap.ResourceVersion

	// Parse overrides from ConfigMap
	overrides, err := c.parseOverrides(configMap.Data)
	if err != nil {
		return fmt.Errorf("failed to parse overrides: %w", err)
	}

	// Sync to RLS (simplified - in real implementation, you'd call RLS gRPC API)
	c.logger.Info().
		Int("tenant_count", len(overrides)).
		Msg("syncing overrides to RLS")

	for tenantID, limits := range overrides {
		c.logger.Debug().
			Str("tenant", tenantID).
			Float64("samples_per_second", limits.SamplesPerSecond).
			Msg("syncing tenant limits")

		// TODO: Call RLS gRPC API to set limits
		// For now, just log
	}

	return nil
}

// parseOverrides parses overrides from ConfigMap data
func (c *Controller) parseOverrides(data map[string]string) (map[string]limits.TenantLimits, error) {
	overrides := make(map[string]limits.TenantLimits)

	for key, value := range data {
		// Parse tenant-specific overrides
		// Format: tenant_id:limit_name = value
		parts := strings.SplitN(key, ":", 2)
		if len(parts) != 2 {
			continue // Skip non-tenant keys
		}

		tenantID := parts[0]
		limitName := parts[1]

		// Get or create tenant limits
		tenantLimits, exists := overrides[tenantID]
		if !exists {
			tenantLimits = limits.TenantLimits{
				SamplesPerSecond:    10000, // Default
				BurstPercent:        0.2,
				MaxBodyBytes:        4194304,
				MaxLabelsPerSeries:  60,
				MaxLabelValueLength: 2048,
				MaxSeriesPerRequest: 100000,
			}
		}

		// Parse limit value
		if err := c.parseLimitValue(&tenantLimits, limitName, value); err != nil {
			c.logger.Warn().
				Err(err).
				Str("tenant", tenantID).
				Str("limit", limitName).
				Str("value", value).
				Msg("failed to parse limit value")
			continue
		}

		overrides[tenantID] = tenantLimits
	}

	return overrides, nil
}

// parseLimitValue parses a single limit value
func (c *Controller) parseLimitValue(limits *limits.TenantLimits, limitName, value string) error {
	switch limitName {
	case "samples_per_second":
		if val, err := strconv.ParseFloat(value, 64); err == nil {
			limits.SamplesPerSecond = val
		} else {
			return fmt.Errorf("invalid samples_per_second: %s", value)
		}

	case "burst_percent":
		if val, err := strconv.ParseFloat(value, 64); err == nil {
			limits.BurstPercent = val
		} else {
			return fmt.Errorf("invalid burst_percent: %s", value)
		}

	case "max_body_bytes":
		if val, err := strconv.ParseInt(value, 10, 64); err == nil {
			limits.MaxBodyBytes = val
		} else {
			return fmt.Errorf("invalid max_body_bytes: %s", value)
		}

	case "max_labels_per_series":
		if val, err := strconv.ParseInt(value, 10, 32); err == nil {
			limits.MaxLabelsPerSeries = int32(val)
		} else {
			return fmt.Errorf("invalid max_labels_per_series: %s", value)
		}

	case "max_label_value_length":
		if val, err := strconv.ParseInt(value, 10, 32); err == nil {
			limits.MaxLabelValueLength = int32(val)
		} else {
			return fmt.Errorf("invalid max_label_value_length: %s", value)
		}

	case "max_series_per_request":
		if val, err := strconv.ParseInt(value, 10, 32); err == nil {
			limits.MaxSeriesPerRequest = int32(val)
		} else {
			return fmt.Errorf("invalid max_series_per_request: %s", value)
		}

	default:
		return fmt.Errorf("unknown limit: %s", limitName)
	}

	return nil
}
