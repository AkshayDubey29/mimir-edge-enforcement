#!/bin/bash

echo "=== Testing Per-Tenant Data Tracking ==="

# Generate traffic for different tenants with different patterns
echo "Generating traffic for tenant-a (low concurrency)..."
./load-remote-write -url="http://localhost:8080/api/v1/push" -tenant=tenant-a -duration=5s -concurrency=2 &
PID1=$!

echo "Generating traffic for tenant-b (high concurrency)..."
./load-remote-write -url="http://localhost:8080/api/v1/push" -tenant=tenant-b -duration=5s -concurrency=8 &
PID2=$!

echo "Generating traffic for tenant-c (medium concurrency)..."
./load-remote-write -url="http://localhost:8080/api/v1/push" -tenant=tenant-c -duration=5s -concurrency=5 &
PID3=$!

# Wait for all traffic to complete
echo "Waiting for traffic to complete..."
wait $PID1 $PID2 $PID3

# Wait a bit for processing
sleep 3

echo ""
echo "=== Results ==="

echo "Overview (15m):"
curl -s "http://localhost:8082/api/overview?range=15m" | jq .

echo ""
echo "Tenants (15m):"
curl -s "http://localhost:8082/api/tenants?range=15m" | jq '.tenants[] | {id: .id, rps: .metrics.rps, samples_per_sec: .metrics.samples_per_sec, total_requests: .metrics.total_requests, allow_rate: .metrics.allow_rate}'

echo ""
echo "=== Per-Tenant RPS Comparison ==="
TENANTS=$(curl -s "http://localhost:8082/api/tenants?range=15m" | jq -r '.tenants[] | "\(.id): \(.metrics.rps)"')
echo "$TENANTS"

echo ""
echo "=== Testing Data Consistency ==="
echo "Multiple requests to same endpoint:"
for i in {1..3}; do
    echo "Request $i:"
    curl -s "http://localhost:8082/api/tenants?range=15m" | jq -r '.tenants[] | "\(.id): \(.metrics.rps)"'
    echo ""
    sleep 1
done

echo "Test completed!"
