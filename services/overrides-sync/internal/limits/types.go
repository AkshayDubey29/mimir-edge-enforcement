package limits

// TenantLimits represents the limits for a tenant
type TenantLimits struct {
	SamplesPerSecond    float64 `json:"samples_per_second"`
	BurstPercent        float64 `json:"burst_pct"`
	MaxBodyBytes        int64   `json:"max_body_bytes"`
	MaxLabelsPerSeries  int32   `json:"max_labels_per_series"`
	MaxLabelValueLength int32   `json:"max_label_value_length"`
	MaxSeriesPerRequest int32   `json:"max_series_per_request"`
}
