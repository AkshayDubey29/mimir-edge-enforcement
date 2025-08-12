#!/bin/bash

echo "🔧 Configuring boltx tenant in RLS..."

# Push tenant limits
echo "📊 Pushing boltx tenant limits..."
curl -X PUT http://localhost:8082/api/tenants/boltx/limits \
  -H "Content-Type: application/json" \
  -d '{
    "samples_per_second": 0,
    "burst_pct": 0,
    "max_body_bytes": 0,
    "max_labels_per_series": 50,
    "max_label_value_length": 2048,
    "max_series_per_request": 20000000
  }'

echo -e "\n\n🔒 Pushing enforcement configuration..."

# Push enforcement configuration
curl -X POST http://localhost:8082/api/tenants/boltx/enforcement \
  -H "Content-Type: application/json" \
  -d '{
    "enabled": true,
    "enforce_samples_per_second": false,
    "enforce_max_body_bytes": false,
    "enforce_max_labels_per_series": true,
    "enforce_max_series_per_request": true,
    "enforce_bytes_per_second": false
  }'

echo -e "\n\n✅ Boltx tenant configuration pushed successfully!"

# Verify configuration
echo -e "\n🔍 Verifying configuration..."
curl -s http://localhost:8082/api/tenants/boltx | jq '.tenant.limits, .tenant.enforcement'
