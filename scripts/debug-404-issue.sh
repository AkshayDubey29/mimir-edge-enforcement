#!/bin/bash

# 🔍 Debug RLS 404 Issue
# This script helps debug the 404 error between overrides-sync and RLS

set -euo pipefail

# Configuration
NAMESPACE=${NAMESPACE:-mimir-edge-enforcement}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠️  WARNING:${NC} $1"
}

error() {
    echo -e "${RED}❌ ERROR:${NC} $1"
}

success() {
    echo -e "${GREEN}✅ SUCCESS:${NC} $1"
}

log "🔍 Debugging RLS 404 issue in namespace: $NAMESPACE"
echo

# Check if RLS is running
RLS_POD=$(kubectl get pods -l app.kubernetes.io/name=mimir-rls -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -z "$RLS_POD" ]]; then
    error "No RLS pods found"
    exit 1
fi

log "📦 Using RLS pod: $RLS_POD"

# Start port-forward
log "🌐 Starting port-forward to RLS admin port..."
kubectl port-forward "$RLS_POD" 8082:8082 -n "$NAMESPACE" &
PF_PID=$!

# Wait for port-forward
sleep 3

# Test basic connectivity
log "🔍 Testing basic RLS connectivity..."
if curl -s "http://localhost:8082/healthz" &> /dev/null; then
    success "RLS is reachable on port 8082"
else
    error "Cannot reach RLS on port 8082"
    kill $PF_PID 2>/dev/null || true
    exit 1
fi

# List all available routes
log "📋 Available RLS routes:"
echo "----------------------------------------"
curl -s "http://localhost:8082/api/debug/routes" | jq '.' 2>/dev/null || curl -s "http://localhost:8082/api/debug/routes"
echo "----------------------------------------"
echo

# Test the specific endpoint that's failing
log "🔍 Testing the problematic endpoint manually..."
echo "Testing: PUT /api/tenants/test-tenant/limits"

RESPONSE=$(curl -s -w "HTTP_STATUS:%{http_code}" -X PUT "http://localhost:8082/api/tenants/test-tenant/limits" \
    -H "Content-Type: application/json" \
    -d '{
        "samples_per_second": 1000,
        "burst_pct": 0.2,
        "max_body_bytes": 4194304,
        "max_labels_per_series": 60,
        "max_label_value_length": 2048,
        "max_series_per_request": 100000
    }' 2>/dev/null || echo "HTTP_STATUS:000")

HTTP_STATUS=$(echo "$RESPONSE" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed 's/HTTP_STATUS:[0-9]*$//')

echo "HTTP Status: $HTTP_STATUS"
echo "Response Body: $BODY"
echo

if [[ "$HTTP_STATUS" == "200" ]]; then
    success "✅ PUT /api/tenants/{id}/limits endpoint works!"
elif [[ "$HTTP_STATUS" == "404" ]]; then
    error "❌ 404 - Endpoint not found"
    echo "This confirms the routing issue."
elif [[ "$HTTP_STATUS" == "000" ]]; then
    error "❌ Connection failed"
else
    warn "⚠️ Unexpected status: $HTTP_STATUS"
fi

# Test other endpoints for comparison
log "🔍 Testing other endpoints for comparison..."

echo "GET /api/health:"
curl -s -w " (Status: %{http_code})\n" "http://localhost:8082/api/health"

echo "GET /api/tenants:"
curl -s -w " (Status: %{http_code})\n" "http://localhost:8082/api/tenants"

echo "GET /api/overview:"
curl -s -w " (Status: %{http_code})\n" "http://localhost:8082/api/overview"

# Check what overrides-sync is actually trying to call
log "📄 Recent overrides-sync logs (looking for URL and errors):"
echo "----------------------------------------"
kubectl logs -l app.kubernetes.io/name=overrides-sync -n "$NAMESPACE" --tail=20 | grep -E "(sending tenant limits|HTTP request failed|RLS returned status)" || echo "No relevant logs found"
echo "----------------------------------------"

# Check RLS logs for request attempts
log "📄 Recent RLS logs (looking for incoming requests):"
echo "----------------------------------------"
kubectl logs "$RLS_POD" -n "$NAMESPACE" --tail=20 | grep -E "(admin API request|registered route|PUT|404)" || echo "No relevant logs found"
echo "----------------------------------------"

# Kill port-forward
kill $PF_PID 2>/dev/null || true
wait $PF_PID 2>/dev/null || true

log "💡 Troubleshooting Summary:"
echo
echo "If you see a 404 error, possible causes:"
echo "1. 🔍 Route not registered properly"
echo "2. 🔍 HTTP method mismatch (PUT vs GET/POST)"
echo "3. 🔍 Path template doesn't match the request"
echo "4. 🔍 RLS service not running the latest code"
echo "5. 🔍 Middleware blocking the request"
echo
echo "🔧 Next steps:"
echo "1. Check if the route appears in the debug/routes output above"
echo "2. Verify RLS deployment is using the latest image"
echo "3. Check RLS startup logs for route registration"
echo "4. Compare working endpoints vs broken endpoint"
echo

success "🎉 404 debugging completed!"
