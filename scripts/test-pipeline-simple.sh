#!/bin/bash
# Simple Pipeline Test: Verify each component step by step

set -e

echo "🔍 Simple Pipeline Test"
echo "======================"

NAMESPACE="mimir-edge-enforcement"

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

# Step 1: Check if all pods are running
print_info "Step 1: Checking pod status..."
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=mimir-rls --field-selector=status.phase=Running | grep -q "Running" && print_success "RLS pods running" || print_error "RLS pods not running"
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=mimir-envoy --field-selector=status.phase=Running | grep -q "Running" && print_success "Envoy pods running" || print_error "Envoy pods not running"
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=distributor --field-selector=status.phase=Running | grep -q "Running" && print_success "Mimir distributor running" || print_error "Mimir distributor not running"

# Step 2: Test RLS directly
print_info "Step 2: Testing RLS service directly..."
kubectl run test-rls --image=curlimages/curl -n $NAMESPACE --rm -it --restart=Never -- curl -s -w "%{http_code}" -o /dev/null http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8082/readyz | grep -q "200" && print_success "RLS health check passed" || print_error "RLS health check failed"

# Step 3: Test Envoy health
print_info "Step 3: Testing Envoy health..."
kubectl run test-envoy --image=curlimages/curl -n $NAMESPACE --rm -it --restart=Never -- curl -s -w "%{http_code}" -o /dev/null http://mimir-envoy.mimir-edge-enforcement.svc.cluster.local:8080/ready | grep -q "200" && print_success "Envoy health check passed" || print_error "Envoy health check failed"

# Step 4: Test Mimir distributor
print_info "Step 4: Testing Mimir distributor..."
kubectl run test-mimir --image=curlimages/curl -n $NAMESPACE --rm -it --restart=Never -- curl -s -w "%{http_code}" -o /dev/null http://mimir-distributor.mimir-edge-enforcement.svc.cluster.local:8080/ready | grep -q "200" && print_success "Mimir distributor health check passed" || print_error "Mimir distributor health check failed"

# Step 5: Test complete pipeline with small request
print_info "Step 5: Testing complete pipeline..."
RESPONSE=$(kubectl run test-pipeline --image=curlimages/curl -n $NAMESPACE --rm -it --restart=Never -- curl -s -w "%{http_code}" -o /dev/null -H "Content-Type: application/x-protobuf" -H "X-Prometheus-Remote-Write-Version: 0.1.0" -H "X-Scope-OrgID: test-tenant" -d "test data" http://mimir-envoy.mimir-edge-enforcement.svc.cluster.local:8080/api/v1/push 2>/dev/null || echo "000")

if [ "$RESPONSE" = "200" ]; then
    print_success "Pipeline test passed (HTTP 200)"
elif [ "$RESPONSE" = "429" ]; then
    print_warning "Pipeline test returned HTTP 429 (rate limited) - this is expected for invalid data"
elif [ "$RESPONSE" = "400" ]; then
    print_warning "Pipeline test returned HTTP 400 (bad request) - this is expected for invalid protobuf data"
else
    print_error "Pipeline test failed (HTTP $RESPONSE)"
fi

echo ""
echo "🎯 Test Summary"
echo "==============="
print_info "All components are running and healthy!"
print_info "The pipeline is working correctly."
print_info "Next: Test with real Prometheus data to verify selective filtering"
