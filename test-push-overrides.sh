#!/bin/bash

# Push tenant configuration to RLS
echo "Pushing test-cardinality tenant configuration to RLS..."

curl -X PUT http://localhost:8082/api/tenants/test-cardinality/limits \
  -H "Content-Type: application/json" \
  -d '{
    "samples_per_second": 100,
    "burst_pct": 10,
    "max_body_bytes": 0,
    "max_labels_per_series": 5,
    "max_label_value_length": 100,
    "max_series_per_request": 10
  }'

echo -e "\n\nPushing enforcement configuration..."

curl -X POST http://localhost:8082/api/tenants/test-cardinality/enforcement \
  -H "Content-Type: application/json" \
  -d '{
    "enabled": true,
    "enforce_samples_per_second": true,
    "enforce_max_body_bytes": false,
    "enforce_max_labels_per_series": true,
    "enforce_max_series_per_request": true,
    "enforce_bytes_per_second": false
  }'

echo -e "\n\nConfiguration pushed successfully!"
