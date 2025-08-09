package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"

	"github.com/rs/zerolog"
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

// Test function similar to the controller's parseOverrides
func parseOverrides(data map[string]string, logger zerolog.Logger) (map[string]TenantLimits, error) {
	overrides := make(map[string]TenantLimits)

	logger.Info().Int("configmap_keys", len(data)).Msg("parsing ConfigMap data")

	// Log all keys for debugging
	for key, value := range data {
		logger.Debug().Str("key", key).Str("value", value).Msg("found ConfigMap entry")
	}

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

	// Test data similar to your ConfigMap
	testData := map[string]string{
		"tenant-1:samples_per_second":     "5000",
		"tenant-1:burst_percent":          "0.1",
		"tenant-1:max_body_bytes":         "1048576",
		"tenant-2:ingestion_rate":         "10000",
		"tenant-2:burst_pct":              "0.2",
		"tenant-2:max_labels_per_series":  "50",
		"tenant-3.samples_per_second":     "15000",
		"tenant-3.burst_percentage":       "0.3",
		"tenant-3.max_series_per_request": "50000",
		"default_ingestion_rate":          "1000",
		"global_max_body_bytes":           "2097152",
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
