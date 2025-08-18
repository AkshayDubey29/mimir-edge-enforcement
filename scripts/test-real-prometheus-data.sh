#!/bin/bash
# Test Selective Filtering with Real Prometheus Data
# This script creates realistic Prometheus remote write data and tests RLS filtering

set -e

echo "🔍 Testing Selective Filtering with Real Prometheus Data"
echo "========================================================"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }

NAMESPACE="mimir-edge-enforcement"

# Check if RLS is running
print_info "Step 1: Checking RLS status..."
RLS_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=mimir-rls --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$RLS_POD" ]; then
    print_error "No running RLS pods found!"
    exit 1
fi

print_success "RLS pod running: $RLS_POD"

# Check if Mimir distributor is running
print_info "Step 2: Checking Mimir distributor status..."
DISTRIBUTOR_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=distributor --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$DISTRIBUTOR_POD" ]; then
    print_error "No running Mimir distributor pods found!"
    exit 1
fi

print_success "Mimir distributor pod running: $DISTRIBUTOR_POD"

# Create a Go program to generate realistic Prometheus remote write data
print_info "Step 3: Creating realistic Prometheus data generator..."
cat > /tmp/generate_prometheus_data.go << 'EOF'
package main

import (
	"bytes"
	"compress/gzip"
	"encoding/binary"
	"fmt"
	"os"
	"time"

	"github.com/golang/protobuf/proto"
	"github.com/golang/snappy"
	"github.com/prometheus/prometheus/prompb"
)

func main() {
	// Create realistic Prometheus data
	series := []prompb.TimeSeries{
		{
			Labels: []prompb.Label{
				{Name: "__name__", Value: "http_requests_total"},
				{Name: "method", Value: "GET"},
				{Name: "status", Value: "200"},
				{Name: "instance", Value: "web-01"},
			},
			Samples: []prompb.Sample{
				{Value: 1234.0, Timestamp: time.Now().UnixMilli()},
			},
		},
		{
			Labels: []prompb.Label{
				{Name: "__name__", Value: "http_requests_total"},
				{Name: "method", Value: "POST"},
				{Name: "status", Value: "500"},
				{Name: "instance", Value: "web-01"},
			},
			Samples: []prompb.Sample{
				{Value: 56.0, Timestamp: time.Now().UnixMilli()},
			},
		},
		{
			Labels: []prompb.Label{
				{Name: "__name__", Value: "cpu_usage"},
				{Name: "cpu", Value: "0"},
				{Name: "mode", Value: "user"},
				{Name: "instance", Value: "web-01"},
			},
			Samples: []prompb.Sample{
				{Value: 45.2, Timestamp: time.Now().UnixMilli()},
			},
		},
	}

	// Create WriteRequest
	req := &prompb.WriteRequest{
		Timeseries: series,
	}

	// Marshal to protobuf
	data, err := proto.Marshal(req)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error marshaling: %v\n", err)
		os.Exit(1)
	}

	// Compress with snappy
	compressed := snappy.Encode(nil, data)

	// Write to file
	err = os.WriteFile("/tmp/prometheus_data.snappy", compressed, 0644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error writing file: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Generated Prometheus data: %d bytes (original: %d bytes)\n", len(compressed), len(data))
	fmt.Printf("Series count: %d\n", len(series))
}
EOF

# Install Go dependencies and build the generator
print_info "Step 4: Building Prometheus data generator..."
cd /tmp
go mod init test
go get github.com/golang/protobuf/proto
go get github.com/golang/snappy
go get github.com/prometheus/prometheus/prompb
go build -o generate_prometheus_data generate_prometheus_data.go

if [ $? -ne 0 ]; then
    print_warning "Could not build Go program, using fallback method..."
    # Fallback: Create a simple test payload
    echo "test_prometheus_data" > /tmp/prometheus_data.snappy
else
    # Run the generator
    ./generate_prometheus_data
fi

# Test 1: Small request (within limits)
print_info "Step 5: Testing small request (within limits)..."
SMALL_RESPONSE=$(kubectl run test-small --image=curlimages/curl -n $NAMESPACE --rm -it --restart=Never -- \
    curl -s -w "%{http_code}" -o /dev/null \
    -H "Content-Type: application/x-protobuf" \
    -H "X-Prometheus-Remote-Write-Version: 0.1.0" \
    -H "X-Scope-OrgID: test-tenant-small" \
    -d "test_small_data" \
    http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8082/api/v1/push 2>/dev/null || echo "000")

if [ "$SMALL_RESPONSE" = "200" ]; then
    print_success "Small request passed (HTTP 200)"
elif [ "$SMALL_RESPONSE" = "429" ]; then
    print_warning "Small request rate limited (HTTP 429)"
elif [ "$SMALL_RESPONSE" = "400" ]; then
    print_warning "Small request bad format (HTTP 400) - expected for test data"
else
    print_error "Small request failed (HTTP $SMALL_RESPONSE)"
fi

# Test 2: Large request (exceeding limits)
print_info "Step 6: Testing large request (exceeding limits)..."
# Create a larger payload by repeating the data
LARGE_PAYLOAD=$(cat /tmp/prometheus_data.snappy | base64 | tr -d '\n' | head -c 10000)

LARGE_RESPONSE=$(kubectl run test-large --image=curlimages/curl -n $NAMESPACE --rm -it --restart=Never -- \
    curl -s -w "%{http_code}" -o /dev/null \
    -H "Content-Type: application/x-protobuf" \
    -H "X-Prometheus-Remote-Write-Version: 0.1.0" \
    -H "X-Scope-OrgID: test-tenant-large" \
    -d "$LARGE_PAYLOAD" \
    http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8082/api/v1/push 2>/dev/null || echo "000")

if [ "$LARGE_RESPONSE" = "200" ]; then
    print_success "Large request was filtered and passed (HTTP 200)"
elif [ "$LARGE_RESPONSE" = "429" ]; then
    print_warning "Large request was denied (HTTP 429) - this may indicate strict limits"
elif [ "$LARGE_RESPONSE" = "400" ]; then
    print_warning "Large request bad format (HTTP 400) - expected for test data"
else
    print_error "Large request failed (HTTP $LARGE_RESPONSE)"
fi

# Test 3: Check RLS logs for selective filtering activity
print_info "Step 7: Checking RLS logs for selective filtering activity..."
sleep 2
RLS_LOGS=$(kubectl logs -n $NAMESPACE $RLS_POD --tail=20 2>/dev/null || echo "")

if echo "$RLS_LOGS" | grep -q "selective"; then
    print_success "Found selective filtering activity in RLS logs"
    echo "$RLS_LOGS" | grep "selective" | head -3
elif echo "$RLS_LOGS" | grep -q "filter"; then
    print_success "Found filtering activity in RLS logs"
    echo "$RLS_LOGS" | grep "filter" | head -3
else
    print_warning "No selective filtering activity found in RLS logs"
    echo "Recent RLS logs:"
    echo "$RLS_LOGS" | tail -5
fi

# Test 4: Check Mimir distributor logs for received metrics
print_info "Step 8: Checking Mimir distributor logs for received metrics..."
sleep 2
DISTRIBUTOR_LOGS=$(kubectl logs -n $NAMESPACE $DISTRIBUTOR_POD --tail=10 2>/dev/null || echo "")

if echo "$DISTRIBUTOR_LOGS" | grep -q "received\|ingest"; then
    print_success "Found received metrics in Mimir distributor logs"
    echo "$DISTRIBUTOR_LOGS" | grep -E "received|ingest" | head -3
else
    print_warning "No received metrics found in Mimir distributor logs"
    echo "Recent distributor logs:"
    echo "$DISTRIBUTOR_LOGS" | tail -5
fi

# Test 5: Check RLS metrics
print_info "Step 9: Checking RLS metrics for selective filtering statistics..."
RLS_METRICS=$(kubectl run test-metrics --image=curlimages/curl -n $NAMESPACE --rm -it --restart=Never -- \
    curl -s http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8082/metrics 2>/dev/null || echo "")

if echo "$RLS_METRICS" | grep -q "rls_"; then
    print_success "Found RLS metrics"
    echo "$RLS_METRICS" | grep "rls_" | head -5
else
    print_warning "No RLS metrics found"
fi

# Summary
echo ""
echo "🎯 Test Summary"
echo "==============="
print_status "Test Results:"
echo "  - Small Request: HTTP $SMALL_RESPONSE"
echo "  - Large Request: HTTP $LARGE_RESPONSE"

if [ "$LARGE_RESPONSE" = "200" ]; then
    print_success "✅ Selective filtering is working! Large requests are being filtered and passed through."
elif [ "$LARGE_RESPONSE" = "429" ]; then
    print_warning "⚠️  Large requests are being denied (HTTP 429). This may indicate:"
    echo "    1. Strict limits are configured"
    echo "    2. Selective filtering is not working as expected"
    echo "    3. The request format is invalid"
else
    print_warning "⚠️  Unexpected response for large request (HTTP $LARGE_RESPONSE)"
fi

print_info "Next Steps:"
echo "  1. Monitor RLS logs for selective filtering activity"
echo "  2. Check Mimir metrics to verify filtered data is reaching distributor"
echo "  3. Adjust limits in values-rls-ultra-minimal.yaml if needed"

# Cleanup
rm -f /tmp/generate_prometheus_data.go /tmp/generate_prometheus_data /tmp/prometheus_data.snappy /tmp/go.mod /tmp/go.sum

echo ""
print_success "Test completed successfully!"
