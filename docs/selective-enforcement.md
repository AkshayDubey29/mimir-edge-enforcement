# Selective Enforcement Guide

This guide explains how to configure RLS to selectively enforce specific limits while allowing others to pass through.

## Overview

The RLS (Rate Limit Service) supports granular control over which limits are enforced for each tenant. This allows you to:

- Enforce only cardinality limits (series per request, labels per series)
- Enforce only rate limits (samples per second, bytes per second)
- Enforce only specific limits (e.g., only series per request)
- Monitor without enforcement (collect metrics but don't block)

## Available Limits

| Limit | Description | Enforcement Flag |
|-------|-------------|------------------|
| `samples_per_second` | Rate limiting for samples | `enforce_samples_per_second` |
| `max_body_bytes` | Maximum request body size | `enforce_max_body_bytes` |
| `max_series_per_request` | Maximum series per request | `enforce_max_series_per_request` |
| `max_labels_per_series` | Maximum labels per series | `enforce_max_labels_per_series` |
| `max_label_value_length` | Maximum label value length | `enforce_max_labels_per_series` |
| `bytes_per_second` | Rate limiting for bytes | `enforce_bytes_per_second` |

## Configuration Examples

### 1. Only Enforce Series Per Request Limit

Equivalent to `per_metric_series_limit` in other systems:

```yaml
tenant-series-only: |
  {
    "samples_per_second": 0,
    "burst_pct": 0,
    "max_body_bytes": 0,
    "max_labels_per_series": 0,
    "max_label_value_length": 0,
    "max_series_per_request": 1000,
    "enforcement": {
      "enabled": true,
      "enforce_samples_per_second": false,
      "enforce_max_body_bytes": false,
      "enforce_max_labels_per_series": false,
      "enforce_max_series_per_request": true,
      "enforce_bytes_per_second": false
    }
  }
```

### 2. Only Enforce Labels Per Series Limit

Equivalent to `per_user_series_limit` in other systems:

```yaml
tenant-labels-only: |
  {
    "samples_per_second": 0,
    "burst_pct": 0,
    "max_body_bytes": 0,
    "max_labels_per_series": 50,
    "max_label_value_length": 2048,
    "max_series_per_request": 0,
    "enforcement": {
      "enabled": true,
      "enforce_samples_per_second": false,
      "enforce_max_body_bytes": false,
      "enforce_max_labels_per_series": true,
      "enforce_max_series_per_request": false,
      "enforce_bytes_per_second": false
    }
  }
```

### 3. Only Enforce Rate Limiting

```yaml
tenant-rate-only: |
  {
    "samples_per_second": 10000,
    "burst_pct": 0.2,
    "max_body_bytes": 0,
    "max_labels_per_series": 0,
    "max_label_value_length": 0,
    "max_series_per_request": 0,
    "enforcement": {
      "enabled": true,
      "enforce_samples_per_second": true,
      "enforce_max_body_bytes": false,
      "enforce_max_labels_per_series": false,
      "enforce_max_series_per_request": false,
      "enforce_bytes_per_second": false
    }
  }
```

### 4. Enforce Only Cardinality Limits

```yaml
tenant-cardinality-only: |
  {
    "samples_per_second": 0,
    "burst_pct": 0,
    "max_body_bytes": 0,
    "max_labels_per_series": 60,
    "max_label_value_length": 2048,
    "max_series_per_request": 5000,
    "enforcement": {
      "enabled": true,
      "enforce_samples_per_second": false,
      "enforce_max_body_bytes": false,
      "enforce_max_labels_per_series": true,
      "enforce_max_series_per_request": true,
      "enforce_bytes_per_second": false
    }
  }
```

### 5. Monitoring Only (No Enforcement)

```yaml
tenant-monitoring-only: |
  {
    "samples_per_second": 0,
    "burst_pct": 0,
    "max_body_bytes": 0,
    "max_labels_per_series": 0,
    "max_label_value_length": 0,
    "max_series_per_request": 0,
    "enforcement": {
      "enabled": false,
      "enforce_samples_per_second": false,
      "enforce_max_body_bytes": false,
      "enforce_max_labels_per_series": false,
      "enforce_max_series_per_request": false,
      "enforce_bytes_per_second": false
    }
  }
```

## Implementation Details

### Enforcement Logic

The enforcement logic in `checkLimits()` function now checks the enforcement flags before applying limits:

```go
// Check series per request limit (only if enforcement is enabled)
if tenant.Info.Enforcement.EnforceMaxSeriesPerRequest && 
   tenant.Info.Limits.MaxSeriesPerRequest > 0 && 
   requestInfo.ObservedSeries > int64(tenant.Info.Limits.MaxSeriesPerRequest) {
    return limits.Decision{
        Allowed: false,
        Reason:  "max_series_per_request_exceeded",
        Code:    http.StatusTooManyRequests,
    }
}
```

### Default Behavior

If no enforcement flags are specified, the system defaults to:
- `enabled: true` - Overall enforcement is enabled
- All individual enforcement flags default to `true` (enforce all limits)

### Migration from Legacy Configuration

For existing configurations without enforcement flags, the system will:
1. Continue to work as before (enforce all limits)
2. Log a warning about missing enforcement configuration
3. Default to enforcing all limits

## Best Practices

### 1. Start with Monitoring

Begin with monitoring-only mode to understand your traffic patterns:

```yaml
enforcement:
  enabled: false  # No enforcement, just monitoring
```

### 2. Gradual Rollout

Enable limits one at a time:

1. Start with cardinality limits (series per request)
2. Add labels per series limits
3. Finally add rate limiting

### 3. Use Reasonable Limits

Set limits based on observed traffic patterns:

```yaml
# Conservative limits
max_series_per_request: 1000
max_labels_per_series: 50

# Aggressive limits  
max_series_per_request: 10000
max_labels_per_series: 100
```

### 4. Monitor Denials

Watch the denial rates in the Admin UI to ensure limits are appropriate:

- High denial rates indicate limits are too restrictive
- Zero denials might indicate limits are too permissive

## Troubleshooting

### Common Issues

1. **All requests denied**: Check if enforcement is enabled but limits are too low
2. **No enforcement**: Verify `enabled: true` in enforcement config
3. **Specific limits not enforced**: Check individual enforcement flags

### Debug Commands

Check current tenant configuration:

```bash
curl http://localhost:8082/api/tenants/{tenant-id}
```

Check recent denials:

```bash
curl http://localhost:8082/api/denials
```

### Logs

Look for enforcement-related logs:

```
RLS: INFO - Enforcement enabled for tenant {tenant-id}
RLS: INFO - Series per request enforcement: true
RLS: INFO - Labels per series enforcement: false
```

## API Reference

### EnforcementConfig Structure

```go
type EnforcementConfig struct {
    Enabled          bool    `json:"enabled"`
    BurstPctOverride float64 `json:"burst_pct_override"`
    
    // Granular enforcement controls
    EnforceSamplesPerSecond    bool `json:"enforce_samples_per_second,omitempty"`
    EnforceMaxBodyBytes        bool `json:"enforce_max_body_bytes,omitempty"`
    EnforceMaxLabelsPerSeries  bool `json:"enforce_max_labels_per_series,omitempty"`
    EnforceMaxSeriesPerRequest bool `json:"enforce_max_series_per_request,omitempty"`
    EnforceBytesPerSecond      bool `json:"enforce_bytes_per_second,omitempty"`
}
```

### Setting Enforcement via API

```bash
curl -X PUT http://localhost:8082/api/tenants/{tenant-id}/enforcement \
  -H "Content-Type: application/json" \
  -d '{
    "enabled": true,
    "enforce_max_series_per_request": true,
    "enforce_max_labels_per_series": false
  }'
```
