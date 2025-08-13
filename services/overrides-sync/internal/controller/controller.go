package controller

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"net/http"
	"strconv"
	"strings"

	"time"

	"github.com/AkshayDubey29/mimir-edge-enforcement/services/overrides-sync/internal/limits"
	"github.com/rs/zerolog"
	"gopkg.in/yaml.v2"
	v1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/watch"
	"k8s.io/client-go/kubernetes"
)

// parseScientificNotation parses a string value that may contain scientific notation
func parseScientificNotation(value string) (float64, error) {
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

// parseScientificNotationInt64 parses a string value that may contain scientific notation and converts to int64
func parseScientificNotationInt64(value string) (int64, error) {
	f, err := parseScientificNotation(value)
	if err != nil {
		return 0, err
	}

	// Check for overflow
	if f > float64(math.MaxInt64) || f < float64(math.MinInt64) {
		return 0, fmt.Errorf("value out of range for int64: %s", value)
	}

	return int64(f), nil
}

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
	config     *Config
	k8sClient  *kubernetes.Clientset
	httpClient *http.Client
	logger     zerolog.Logger

	// State
	lastResourceVersion string
	stopChan            chan struct{}
}

// NewController creates a new controller
func NewController(config *Config, k8sClient *kubernetes.Clientset, logger zerolog.Logger) *Controller {
	// 🔧 PERFORMANCE FIX: Use connection pooling for better performance
	transport := &http.Transport{
		MaxIdleConns:        100,
		MaxIdleConnsPerHost: 10,
		IdleConnTimeout:     90 * time.Second,
		DisableCompression:  true, // RLS responses are small
	}

	httpClient := &http.Client{
		Transport: transport,
		Timeout:   5 * time.Second, // 🔧 OPTIMIZED: Reduced from 30s to 5s for faster sync
	}

	return &Controller{
		config:     config,
		k8sClient:  k8sClient,
		httpClient: httpClient,
		logger:     logger,
		stopChan:   make(chan struct{}),
	}
}

// Run starts the controller
func (c *Controller) Run(ctx context.Context) error {
	c.logger.Info().
		Str("namespace", c.config.MimirNamespace).
		Str("configmap", c.config.OverridesConfigMap).
		Msg("starting overrides sync controller")

	// 🔧 OPTIMIZED: Reduced startup delay for faster initialization
	c.logger.Info().Msg("waiting 3 seconds for RLS to be ready...")
	time.Sleep(3 * time.Second)

	// Initial sync with retry
	if err := c.syncOverridesWithRetry(); err != nil {
		c.logger.Error().Err(err).Msg("initial sync failed after retries")
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

// syncOverridesWithRetry performs a full sync with retry logic
func (c *Controller) syncOverridesWithRetry() error {
	maxRetries := 5
	retryDelay := 2 * time.Second // 🔧 OPTIMIZED: Reduced from 5s to 2s for faster retries

	for attempt := 1; attempt <= maxRetries; attempt++ {
		c.logger.Info().
			Int("attempt", attempt).
			Int("max_retries", maxRetries).
			Msg("attempting to sync overrides to RLS")

		if err := c.syncOverrides(); err != nil {
			c.logger.Warn().
				Err(err).
				Int("attempt", attempt).
				Int("max_retries", maxRetries).
				Msg("sync attempt failed")

			if attempt < maxRetries {
				c.logger.Info().
					Dur("retry_delay", retryDelay).
					Msg("retrying after delay")
				time.Sleep(retryDelay)
				continue
			}
			return fmt.Errorf("sync failed after %d attempts: %w", maxRetries, err)
		}

		c.logger.Info().
			Int("attempt", attempt).
			Msg("successfully synced overrides to RLS")
		return nil
	}

	return fmt.Errorf("sync failed after %d attempts", maxRetries)
}

// syncOverridesFromConfigMap syncs overrides from a ConfigMap
func (c *Controller) syncOverridesFromConfigMap(configMap *v1.ConfigMap) error {
	c.lastResourceVersion = configMap.ResourceVersion

	// Parse overrides from ConfigMap
	overrides, err := c.parseOverrides(configMap.Data)
	if err != nil {
		return fmt.Errorf("failed to parse overrides: %w", err)
	}

	// Sync to RLS via HTTP API
	c.logger.Info().
		Int("tenant_count", len(overrides)).
		Str("rls_host", c.config.RLSHost).
		Str("rls_port", c.config.RLSAdminPort).
		Msg("syncing overrides to RLS")

	// 🔧 OPTIMIZED: Send each tenant's limits to RLS with optimized sequential processing
	successCount := 0
	for tenantID, limits := range overrides {
		if err := c.sendTenantLimitsToRLS(tenantID, limits); err != nil {
			c.logger.Error().
				Err(err).
				Str("tenant", tenantID).
				Msg("failed to sync tenant limits to RLS")
		} else {
			c.logger.Debug().
				Str("tenant", tenantID).
				Float64("samples_per_second", limits.SamplesPerSecond).
				Float64("burst_percent", limits.BurstPercent).
				Int64("max_body_bytes", limits.MaxBodyBytes).
				Msg("successfully synced tenant limits to RLS")
			successCount++
		}
	}

	c.logger.Info().
		Int("total_tenants", len(overrides)).
		Int("successful_syncs", successCount).
		Int("failed_syncs", len(overrides)-successCount).
		Msg("completed sync to RLS")

	return nil
}

// sendTenantLimitsToRLS sends tenant limits to RLS via HTTP API
func (c *Controller) sendTenantLimitsToRLS(tenantID string, tenantLimits limits.TenantLimits) error {
	// Build RLS URL
	rlsURL := fmt.Sprintf("http://%s:%s/api/tenants/%s/limits", c.config.RLSHost, c.config.RLSAdminPort, tenantID)

	// Marshal limits to JSON
	limitsJSON, err := json.Marshal(tenantLimits)
	if err != nil {
		return fmt.Errorf("failed to marshal tenant limits: %w", err)
	}

	// Create HTTP request
	req, err := http.NewRequest(http.MethodPut, rlsURL, bytes.NewBuffer(limitsJSON))
	if err != nil {
		return fmt.Errorf("failed to create HTTP request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")

	// Send request
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	// Read response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("failed to read response body: %w", err)
	}

	// Check response status
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("RLS API returned status %d: %s", resp.StatusCode, string(body))
	}

	c.logger.Debug().
		Str("tenant", tenantID).
		Str("response", string(body)).
		Msg("RLS API response")

	return nil
}

// MimirOverridesConfig represents the structure of Mimir's overrides.yaml
type MimirOverridesConfig struct {
	Overrides map[string]map[string]interface{} `yaml:"overrides"`
}

// parseOverrides parses overrides from ConfigMap data
func (c *Controller) parseOverrides(data map[string]string) (map[string]limits.TenantLimits, error) {
	c.logger.Debug().
		Int("configmap_keys", len(data)).
		Msg("parsing ConfigMap data")

	// Log all keys for debugging
	for key := range data {
		c.logger.Debug().
			Str("key", key).
			Int("value_length", len(data[key])).
			Msg("found ConfigMap entry")
	}

	// First, try to parse the Mimir YAML format (overrides.yaml key)
	if overridesYaml, exists := data["overrides.yaml"]; exists {
		c.logger.Info().Msg("found overrides.yaml - parsing Mimir YAML format")
		return c.parseMimirYamlOverrides(overridesYaml)
	}

	// Fallback to legacy flat format for backward compatibility
	c.logger.Info().Msg("no overrides.yaml found - trying legacy flat format")
	return c.parseFlatOverrides(data)
}

// parseMimirYamlOverrides parses the actual Mimir overrides.yaml format
func (c *Controller) parseMimirYamlOverrides(yamlContent string) (map[string]limits.TenantLimits, error) {
	var config MimirOverridesConfig

	c.logger.Debug().
		Str("yaml_content", yamlContent[:min(500, len(yamlContent))]).
		Msg("parsing Mimir YAML overrides")

	if err := yaml.Unmarshal([]byte(yamlContent), &config); err != nil {
		return nil, fmt.Errorf("failed to parse overrides YAML: %w", err)
	}

	overrides := make(map[string]limits.TenantLimits)

	c.logger.Info().
		Int("tenants_in_yaml", len(config.Overrides)).
		Msg("found tenants in overrides YAML")

	for tenantID, tenantConfig := range config.Overrides {
		c.logger.Debug().
			Str("tenant", tenantID).
			Int("config_fields", len(tenantConfig)).
			Msg("processing tenant overrides")

		// Start with defaults
		tenantLimits := limits.TenantLimits{
			SamplesPerSecond:    10000, // Default
			BurstPercent:        0.2,
			MaxBodyBytes:        4194304,
			MaxLabelsPerSeries:  60,
			MaxLabelValueLength: 2048,
			MaxSeriesPerRequest: 100000,
		}

		// Parse each field in the tenant config
		for fieldName, fieldValue := range tenantConfig {
			valueStr := fmt.Sprintf("%v", fieldValue)

			c.logger.Debug().
				Str("tenant", tenantID).
				Str("field", fieldName).
				Str("value", valueStr).
				Msg("parsing tenant field")

			if err := c.parseLimitValue(&tenantLimits, fieldName, valueStr); err != nil {
				c.logger.Warn().
					Err(err).
					Str("tenant", tenantID).
					Str("field", fieldName).
					Str("value", valueStr).
					Msg("failed to parse tenant field - skipping")
				continue
			}
		}

		overrides[tenantID] = tenantLimits
		c.logger.Info().
			Str("tenant", tenantID).
			Interface("limits", tenantLimits).
			Msg("processed tenant overrides")
	}

	c.logger.Info().
		Int("total_tenants", len(overrides)).
		Msg("completed parsing Mimir YAML overrides")

	return overrides, nil
}

// parseFlatOverrides parses the legacy flat key-value format for backward compatibility
func (c *Controller) parseFlatOverrides(data map[string]string) (map[string]limits.TenantLimits, error) {
	overrides := make(map[string]limits.TenantLimits)

	for key, value := range data {
		var tenantID, limitName string

		// Try colon separator first
		if strings.Contains(key, ":") {
			parts := strings.SplitN(key, ":", 2)
			if len(parts) == 2 {
				tenantID = strings.TrimSpace(parts[0])
				limitName = strings.TrimSpace(parts[1])
			}
		} else if strings.Contains(key, ".") {
			// Try dot separator
			parts := strings.SplitN(key, ".", 2)
			if len(parts) == 2 {
				tenantID = strings.TrimSpace(parts[0])
				limitName = strings.TrimSpace(parts[1])
			}
		} else {
			// Global override or unsupported format - skip
			c.logger.Debug().
				Str("key", key).
				Msg("skipping non-tenant-specific key")
			continue
		}

		if tenantID == "" || limitName == "" {
			c.logger.Debug().
				Str("key", key).
				Msg("skipping malformed key")
			continue
		}

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

	c.logger.Info().
		Int("total_tenants", len(overrides)).
		Msg("completed parsing flat overrides")

	return overrides, nil
}

// parseLimitValue parses a single limit value with scientific notation support
func (c *Controller) parseLimitValue(limits *limits.TenantLimits, limitName, value string) error {
	// Normalize limit name to handle different naming conventions
	normalizedLimitName := strings.ToLower(strings.TrimSpace(limitName))

	c.logger.Debug().
		Str("original_limit", limitName).
		Str("normalized_limit", normalizedLimitName).
		Str("value", value).
		Msg("parsing limit value")

	switch normalizedLimitName {
	// Samples per second variations (ingestion_rate is the primary Mimir field)
	case "samples_per_second", "ingestion_rate", "samples_per_sec", "sps":
		if val, err := parseScientificNotation(value); err == nil {
			limits.SamplesPerSecond = val
			c.logger.Debug().Float64("parsed_value", val).Msg("set samples_per_second")
		} else {
			return fmt.Errorf("invalid samples_per_second: %s", value)
		}

	// Burst size variations (ingestion_burst_size is the primary Mimir field)
	// Note: Mimir uses absolute burst size, we convert to percentage of ingestion_rate
	case "burst_percent", "burst_pct", "burst_percentage":
		if val, err := parseScientificNotation(value); err == nil {
			limits.BurstPercent = val
			c.logger.Debug().Float64("parsed_value", val).Msg("set burst_percent")
		} else {
			return fmt.Errorf("invalid burst_percent: %s", value)
		}

	case "ingestion_burst_size":
		if val, err := parseScientificNotation(value); err == nil {
			// Convert absolute burst size to percentage of ingestion_rate
			// If ingestion_rate is not set yet, use a reasonable default
			rate := limits.SamplesPerSecond
			if rate <= 0 {
				rate = 10000 // Default rate for percentage calculation
			}
			limits.BurstPercent = val / rate
			c.logger.Debug().
				Float64("burst_size", val).
				Float64("ingestion_rate", rate).
				Float64("calculated_burst_percent", limits.BurstPercent).
				Msg("converted ingestion_burst_size to burst_percent")
		} else {
			return fmt.Errorf("invalid ingestion_burst_size: %s", value)
		}

	// Max body bytes variations
	case "max_body_bytes", "max_request_size", "request_rate_limit", "max_request_body_size":
		if val, err := parseScientificNotationInt64(value); err == nil {
			limits.MaxBodyBytes = val
			c.logger.Debug().Int64("parsed_value", val).Msg("set max_body_bytes")
		} else {
			return fmt.Errorf("invalid max_body_bytes: %s", value)
		}

	// Max labels per series variations (max_label_names_per_series is the Mimir field)
	case "max_labels_per_series", "max_labels_per_metric", "labels_limit", "max_label_names_per_series":
		if val, err := parseScientificNotation(value); err == nil {
			limits.MaxLabelsPerSeries = int32(val)
			c.logger.Debug().Int32("parsed_value", int32(val)).Msg("set max_labels_per_series")
		} else {
			return fmt.Errorf("invalid max_labels_per_series: %s", value)
		}

	// Max label value length variations
	case "max_label_value_length", "max_label_name_length", "label_length_limit":
		if val, err := parseScientificNotation(value); err == nil {
			limits.MaxLabelValueLength = int32(val)
			c.logger.Debug().Int32("parsed_value", int32(val)).Msg("set max_label_value_length")
		} else {
			return fmt.Errorf("invalid max_label_value_length: %s", value)
		}

	// Max series per request variations
	case "max_series_per_request", "max_series_per_metric", "max_series_per_query", "series_limit":
		if val, err := parseScientificNotation(value); err == nil {
			limits.MaxSeriesPerRequest = int32(val)
			c.logger.Debug().Int32("parsed_value", int32(val)).Msg("set max_series_per_request")
		} else {
			return fmt.Errorf("invalid max_series_per_request: %s", value)
		}

	// Mimir global limits - map to RLS tenant-specific limits
	case "max_global_series_per_user":
		if val, err := parseScientificNotation(value); err == nil {
			limits.MaxSeriesPerRequest = int32(val)
			c.logger.Debug().
				Str("mimir_field", limitName).
				Int32("mapped_value", int32(val)).
				Msg("mapped max_global_series_per_user to max_series_per_request (per-user limit)")
		} else {
			return fmt.Errorf("invalid max_global_series_per_user: %s", value)
		}

	case "max_global_series_per_metric":
		if val, err := parseScientificNotation(value); err == nil {
			limits.MaxSeriesPerMetric = int32(val)
			c.logger.Debug().
				Str("mimir_field", limitName).
				Int32("mapped_value", int32(val)).
				Msg("mapped max_global_series_per_metric to max_series_per_metric (per-metric limit)")
		} else {
			return fmt.Errorf("invalid max_global_series_per_metric: %s", value)
		}

	// Additional Mimir fields (log but don't error - these are not part of our core limits yet)
	case "max_global_metadata_per_user", "max_global_metadata_per_metric", "ingestion_tenant_shard_size",
		"cardinality_analysis_enabled", "accept_ha_samples", "ha_cluster_label", "ha_replica_label",
		"max_cache_freshness", "ruler_max_rule_groups_per_tenant", "ruler_max_rules_per_rule_group":
		c.logger.Debug().
			Str("field", limitName).
			Str("value", value).
			Msg("recognized Mimir field - not mapped to RLS limits yet")
		// Don't error, just log for future implementation
		return nil

	default:
		c.logger.Warn().
			Str("limit_name", limitName).
			Str("normalized_name", normalizedLimitName).
			Str("value", value).
			Msg("unknown limit type - skipping")
		// Don't return error for unknown limits, just skip them
		return nil
	}

	return nil
}

// min returns the minimum of two integers
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
