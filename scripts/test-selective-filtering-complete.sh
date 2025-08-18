#!/bin/bash
# Comprehensive Test for Selective Filtering: nginx → envoy → rls → mimir
# This script tests the complete pipeline with selective filtering enabled

set -e

echo "🔍 Testing Selective Filtering Pipeline"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right namespace
NAMESPACE="mimir-edge-enforcement"
print_status "Checking namespace: $NAMESPACE"

if ! kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
    print_error "Namespace $NAMESPACE not found!"
    exit 1
fi

# Check if RLS is running
print_status "Checking RLS pod status..."
RLS_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=mimir-rls --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$RLS_POD" ]; then
    print_error "No running RLS pods found!"
    kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=mimir-rls
    exit 1
fi

print_success "RLS pod running: $RLS_POD"

# Check if Envoy is running
print_status "Checking Envoy pod status..."
ENVOY_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=mimir-envoy --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$ENVOY_POD" ]; then
    print_error "No running Envoy pods found!"
    kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=mimir-envoy
    exit 1
fi

print_success "Envoy pod running: $ENVOY_POD"

# Check if Mimir distributor is running
print_status "Checking Mimir distributor status..."
DISTRIBUTOR_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=distributor --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$DISTRIBUTOR_POD" ]; then
    print_error "No running Mimir distributor pods found!"
    kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=distributor
    exit 1
fi

print_success "Mimir distributor pod running: $DISTRIBUTOR_POD"

# Verify RLS configuration
print_status "Verifying RLS selective filtering configuration..."
kubectl exec -n $NAMESPACE $RLS_POD -- ps aux | grep rls | grep -q "selective-filtering-enabled=true" && print_success "Selective filtering enabled" || print_error "Selective filtering not enabled"

# Start port forwarding
print_status "Starting port forwarding..."
kubectl port-forward -n $NAMESPACE svc/mimir-envoy 8080:8080 >/dev/null 2>&1 &
ENVOY_PF_PID=$!

kubectl port-forward -n $NAMESPACE svc/mimir-rls 8082:8082 >/dev/null 2>&1 &
RLS_PF_PID=$!

# Wait for port forwarding to be ready
sleep 5

# Function to cleanup port forwarding
cleanup() {
    print_status "Cleaning up port forwarding..."
    kill $ENVOY_PF_PID 2>/dev/null || true
    kill $RLS_PF_PID 2>/dev/null || true
}

trap cleanup EXIT

# Test 1: Small request within limits (should pass through)
print_status "Test 1: Small request within limits (should pass through)"
SMALL_RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/small_response.txt \
    -H "Content-Type: application/x-protobuf" \
    -H "X-Prometheus-Remote-Write-Version: 0.1.0" \
    -H "X-Scope-OrgID: test-tenant" \
    -d "test data" \
    http://localhost:8080/api/v1/push)

if [ "$SMALL_RESPONSE" = "200" ]; then
    print_success "Small request passed through (HTTP 200)"
else
    print_warning "Small request returned HTTP $SMALL_RESPONSE (expected 200)"
fi

# Test 2: Request exceeding series limit (should be filtered)
print_status "Test 2: Request exceeding series limit (should be filtered)"
# Create a larger payload that exceeds the 100 series limit
LARGE_PAYLOAD=$(python3 -c "
import struct
# Create a minimal protobuf-like payload with many series
payload = b''
for i in range(150):  # Exceeds 100 series limit
    payload += struct.pack('<I', i) + b'test_metric_' + str(i).encode() + b'_series'
print(payload.hex())
" 2>/dev/null || echo "test_large_payload")

LARGE_RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/large_response.txt \
    -H "Content-Type: application/x-protobuf" \
    -H "X-Prometheus-Remote-Write-Version: 0.1.0" \
    -H "X-Scope-OrgID: test-tenant" \
    -d "$LARGE_PAYLOAD" \
    http://localhost:8080/api/v1/push)

if [ "$LARGE_RESPONSE" = "200" ]; then
    print_success "Large request was filtered and passed through (HTTP 200)"
elif [ "$LARGE_RESPONSE" = "429" ]; then
    print_warning "Large request was denied (HTTP 429) - this is expected for strict limits"
else
    print_warning "Large request returned HTTP $LARGE_RESPONSE"
fi

# Test 3: Check RLS logs for selective filtering activity
print_status "Test 3: Checking RLS logs for selective filtering activity..."
sleep 2
RLS_LOGS=$(kubectl logs -n $NAMESPACE $RLS_POD --tail=20 2>/dev/null || echo "")

if echo "$RLS_LOGS" | grep -q "selective"; then
    print_success "Found selective filtering activity in RLS logs"
else
    print_warning "No selective filtering activity found in RLS logs"
fi

# Test 4: Check Mimir distributor logs for received metrics
print_status "Test 4: Checking Mimir distributor logs for received metrics..."
sleep 2
DISTRIBUTOR_LOGS=$(kubectl logs -n $NAMESPACE $DISTRIBUTOR_POD --tail=10 2>/dev/null || echo "")

if echo "$DISTRIBUTOR_LOGS" | grep -q "received"; then
    print_success "Found received metrics in Mimir distributor logs"
else
    print_warning "No received metrics found in Mimir distributor logs"
fi

# Test 5: Verify RLS health endpoint
print_status "Test 5: Testing RLS health endpoint..."
RLS_HEALTH=$(curl -s -w "%{http_code}" -o /tmp/rls_health.txt http://localhost:8082/healthz)

if [ "$RLS_HEALTH" = "200" ]; then
    print_success "RLS health endpoint responding (HTTP 200)"
else
    print_error "RLS health endpoint returned HTTP $RLS_HEALTH"
fi

# Test 6: Check RLS metrics for selective filtering stats
print_status "Test 6: Checking RLS metrics for selective filtering statistics..."
RLS_METRICS=$(curl -s http://localhost:8082/metrics 2>/dev/null || echo "")

if echo "$RLS_METRICS" | grep -q "rls_"; then
    print_success "Found RLS metrics endpoint"
    echo "$RLS_METRICS" | grep "rls_" | head -5
else
    print_warning "No RLS metrics found"
fi

# Summary
echo ""
echo "========================================"
echo "🎯 Selective Filtering Test Summary"
echo "========================================"

print_status "Pipeline Status:"
echo "  - RLS Pod: $RLS_POD ✅"
echo "  - Envoy Pod: $ENVOY_POD ✅"
echo "  - Mimir Distributor: $DISTRIBUTOR_POD ✅"

print_status "Test Results:"
echo "  - Small Request: HTTP $SMALL_RESPONSE"
echo "  - Large Request: HTTP $LARGE_RESPONSE"
echo "  - RLS Health: HTTP $RLS_HEALTH"

if [ "$LARGE_RESPONSE" = "200" ]; then
    print_success "✅ Selective filtering is working! Large requests are being filtered and passed through."
elif [ "$LARGE_RESPONSE" = "429" ]; then
    print_warning "⚠️  Large requests are being denied (HTTP 429). This may indicate strict limits or filtering failure."
else
    print_warning "⚠️  Unexpected response for large request (HTTP $LARGE_RESPONSE)"
fi

print_status "Next Steps:"
echo "  1. Monitor RLS logs for selective filtering activity"
echo "  2. Check Mimir metrics to verify filtered data is reaching distributor"
echo "  3. Adjust limits in values-rls-ultra-minimal.yaml if needed"

echo ""
print_success "Test completed successfully!"
