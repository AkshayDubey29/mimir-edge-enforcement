package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"

	"github.com/rs/zerolog"
	"gopkg.in/yaml.v2"
)

// TenantLimits represents the limits for a tenant
type TenantLimits struct {
	SamplesPerSecond    float64 `json:"samples_per_second"`
	BurstPercent        float64 `json:"burst_pct"`
	MaxBodyBytes        int64   `json:"max_body_bytes"`
	MaxLabelsPerSeries  int32   `json:"max_labels_per_series"`
	MaxLabelValueLength int32   `json:"max_label_value_length"`
	MaxSeriesPerRequest int32   `json:"max_series_per_request"`
}

// MimirOverridesConfig represents the structure of Mimir's overrides.yaml
type MimirOverridesConfig struct {
	Overrides map[string]map[string]interface{} `yaml:"overrides"`
}

// min returns the minimum of two integers
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// Test function similar to the controller's parseOverrides
func parseOverrides(data map[string]string, logger zerolog.Logger) (map[string]TenantLimits, error) {
	logger.Info().Int("configmap_keys", len(data)).Msg("parsing ConfigMap data")

	// Log all keys for debugging
	for key := range data {
		logger.Debug().Str("key", key).Int("value_length", len(data[key])).Msg("found ConfigMap entry")
	}

	// First, try to parse the Mimir YAML format (overrides.yaml key)
	if overridesYaml, exists := data["overrides.yaml"]; exists {
		logger.Info().Msg("found overrides.yaml - parsing Mimir YAML format")
		return parseMimirYamlOverrides(overridesYaml, logger)
	}

	// Fallback to legacy flat format for backward compatibility
	logger.Info().Msg("no overrides.yaml found - trying legacy flat format")
	return parseFlatOverrides(data, logger)
}

// parseMimirYamlOverrides parses the actual Mimir overrides.yaml format
func parseMimirYamlOverrides(yamlContent string, logger zerolog.Logger) (map[string]TenantLimits, error) {
	var config MimirOverridesConfig
	
	logger.Debug().Str("yaml_content", yamlContent[:min(500, len(yamlContent))]).Msg("parsing Mimir YAML overrides")

	if err := yaml.Unmarshal([]byte(yamlContent), &config); err != nil {
		return nil, fmt.Errorf("failed to parse overrides YAML: %w", err)
	}

	overrides := make(map[string]TenantLimits)

	logger.Info().Int("tenants_in_yaml", len(config.Overrides)).Msg("found tenants in overrides YAML")

	for tenantID, tenantConfig := range config.Overrides {
		logger.Debug().Str("tenant", tenantID).Int("config_fields", len(tenantConfig)).Msg("processing tenant overrides")

		// Start with defaults
		tenantLimits := TenantLimits{
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
			
			logger.Debug().Str("tenant", tenantID).Str("field", fieldName).Str("value", valueStr).Msg("parsing tenant field")

			if err := parseLimitValue(&tenantLimits, fieldName, valueStr, logger); err != nil {
				logger.Warn().Err(err).Str("tenant", tenantID).Str("field", fieldName).Str("value", valueStr).Msg("failed to parse tenant field - skipping")
				continue
			}
		}

		overrides[tenantID] = tenantLimits
		logger.Info().Str("tenant", tenantID).Interface("limits", tenantLimits).Msg("processed tenant overrides")
	}

	logger.Info().Int("total_tenants", len(overrides)).Msg("completed parsing Mimir YAML overrides")
	return overrides, nil
}

// parseFlatOverrides parses the legacy flat key-value format for backward compatibility
func parseFlatOverrides(data map[string]string, logger zerolog.Logger) (map[string]TenantLimits, error) {
	overrides := make(map[string]TenantLimits)

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
			logger.Debug().Str("key", key).Msg("skipping non-tenant-specific key")
			continue
		}

		if tenantID == "" || limitName == "" {
			logger.Debug().Str("key", key).Msg("skipping malformed key")
			continue
		}

		logger.Info().Str("tenant", tenantID).Str("limit", limitName).Str("value", value).Msg("parsing tenant limit")

		// Get or create tenant limits
		tenantLimits, exists := overrides[tenantID]
		if !exists {
			tenantLimits = TenantLimits{
				SamplesPerSecond:    10000, // Default
				BurstPercent:        0.2,
				MaxBodyBytes:        4194304,
				MaxLabelsPerSeries:  60,
				MaxLabelValueLength: 2048,
				MaxSeriesPerRequest: 100000,
			}
			logger.Info().Str("tenant", tenantID).Msg("created new tenant limits with defaults")
		}

		// Parse limit value
		if err := parseLimitValue(&tenantLimits, limitName, value, logger); err != nil {
			logger.Warn().Err(err).Str("tenant", tenantID).Str("limit", limitName).Str("value", value).Msg("failed to parse limit value")
			continue
		}

		overrides[tenantID] = tenantLimits
		logger.Info().Str("tenant", tenantID).Str("limit", limitName).Interface("limits", tenantLimits).Msg("updated tenant limits")
	}

	logger.Info().Int("total_tenants", len(overrides)).Msg("completed parsing ConfigMap")
	return overrides, nil
}

func parseLimitValue(limits *TenantLimits, limitName, value string, logger zerolog.Logger) error {
	normalizedLimitName := strings.ToLower(strings.TrimSpace(limitName))

	logger.Debug().Str("original_limit", limitName).Str("normalized_limit", normalizedLimitName).Str("value", value).Msg("parsing limit value")

	switch normalizedLimitName {
	case "samples_per_second", "ingestion_rate", "samples_per_sec", "sps":
		if val, err := strconv.ParseFloat(value, 64); err == nil {
			limits.SamplesPerSecond = val
			logger.Info().Float64("parsed_value", val).Msg("set samples_per_second")
		} else {
			return fmt.Errorf("invalid samples_per_second: %s", value)
		}

	case "burst_percent", "burst_pct", "burst_percentage", "ingestion_burst_size":
		if val, err := strconv.ParseFloat(value, 64); err == nil {
			limits.BurstPercent = val
			logger.Info().Float64("parsed_value", val).Msg("set burst_percent")
		} else {
			return fmt.Errorf("invalid burst_percent: %s", value)
		}

	case "max_body_bytes", "max_request_size", "request_rate_limit", "max_request_body_size":
		if val, err := strconv.ParseInt(value, 10, 64); err == nil {
			limits.MaxBodyBytes = val
			logger.Info().Int64("parsed_value", val).Msg("set max_body_bytes")
		} else {
			return fmt.Errorf("invalid max_body_bytes: %s", value)
		}

	case "max_labels_per_series", "max_labels_per_metric", "labels_limit":
		if val, err := strconv.ParseInt(value, 10, 32); err == nil {
			limits.MaxLabelsPerSeries = int32(val)
			logger.Info().Int32("parsed_value", int32(val)).Msg("set max_labels_per_series")
		} else {
			return fmt.Errorf("invalid max_labels_per_series: %s", value)
		}

	case "max_label_value_length", "max_label_name_length", "label_length_limit":
		if val, err := strconv.ParseInt(value, 10, 32); err == nil {
			limits.MaxLabelValueLength = int32(val)
			logger.Info().Int32("parsed_value", int32(val)).Msg("set max_label_value_length")
		} else {
			return fmt.Errorf("invalid max_label_value_length: %s", value)
		}

	case "max_series_per_request", "max_series_per_metric", "max_series_per_query", "series_limit":
		if val, err := strconv.ParseInt(value, 10, 32); err == nil {
			limits.MaxSeriesPerRequest = int32(val)
			logger.Info().Int32("parsed_value", int32(val)).Msg("set max_series_per_request")
		} else {
			return fmt.Errorf("invalid max_series_per_request: %s", value)
		}

	default:
		logger.Warn().Str("limit_name", limitName).Str("normalized_name", normalizedLimitName).Str("value", value).Msg("unknown limit type - skipping")
		return nil
	}

	return nil
}

func main() {
	// Setup logger
	logger := zerolog.New(zerolog.ConsoleWriter{Out: os.Stderr}).With().Timestamp().Logger()
	zerolog.SetGlobalLevel(zerolog.InfoLevel)

	// Test data mimicking actual production Mimir ConfigMap
	testData := map[string]string{
		"mimir.yaml": `metrics:
  per_tenant_metrics_enabled: true`,
		"overrides.yaml": `overrides:
  benefit:
    cardinality_analysis_enabled: true
    ingestion_burst_size: 3.5e+06
    ingestion_rate: 350000
    ingestion_tenant_shard_size: 8
    max_global_metadata_per_metric: 10
    max_global_metadata_per_user: 600000
    max_global_series_per_user: 3e+06
    max_label_names_per_series: 50
    ruler_max_rule_groups_per_tenant: 20
    ruler_max_rules_per_rule_group: 20
  boltx:
    accept_ha_samples: true
    cardinality_analysis_enabled: true
    ha_cluster_label: cluster
    ha_replica_label: __replica__
    ingestion_burst_size: 3.5e+06
    ingestion_rate: 1e+07
    ingestion_tenant_shard_size: 40
    max_cache_freshness: 2h
    max_global_metadata_per_metric: 10
    max_global_metadata_per_user: 4e+06
    max_global_series_per_metric: 5e+06
    max_global_series_per_user: 2e+07
    max_label_names_per_series: 250
    ruler_max_rule_groups_per_tenant: 90
    ruler_max_rules_per_rule_group: 90
  buybox:
    cardinality_analysis_enabled: true
    ingestion_burst_size: 3.5e+06
    ingestion_rate: 350000
    ingestion_tenant_shard_size: 8
    max_global_metadata_per_metric: 10
    max_global_series_per_user: 3e+06`,
	}

	fmt.Println("🧪 Testing ConfigMap parsing...")
	fmt.Println("===============================")

	overrides, err := parseOverrides(testData, logger)
	if err != nil {
		log.Fatalf("Failed to parse overrides: %v", err)
	}

	fmt.Printf("\n✅ Parsed %d tenants successfully!\n\n", len(overrides))

	// Pretty print the results
	for tenantID, limits := range overrides {
		fmt.Printf("📊 Tenant: %s\n", tenantID)
		jsonData, _ := json.MarshalIndent(limits, "   ", "  ")
		fmt.Printf("   %s\n\n", string(jsonData))
	}

	if len(overrides) == 0 {
		fmt.Println("❌ No tenants parsed! Check your ConfigMap format.")
	}
}
