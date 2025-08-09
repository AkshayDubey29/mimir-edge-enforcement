#!/bin/bash

# 🔗 Test Overrides-Sync to RLS Communication
# This script helps test the newly implemented communication between overrides-sync and RLS

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

usage() {
    cat << EOF
🔗 Test Overrides-Sync to RLS Communication

Usage: $0 [options]

Options:
  --test-endpoint     Test the new RLS /api/tenants/{id}/limits endpoint
  --watch-logs        Watch logs from both services in real-time
  --force-sync        Trigger a ConfigMap update to force sync
  --namespace NS      Kubernetes namespace (default: mimir-edge-enforcement)
  --help              Show this help message

Examples:
  $0 --watch-logs     # Watch communication logs in real-time
  $0 --test-endpoint  # Test the RLS endpoint manually
  $0 --force-sync     # Force a sync by updating ConfigMap
EOF
}

# Parse command line arguments
TEST_ENDPOINT=false
WATCH_LOGS=false
FORCE_SYNC=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --test-endpoint)
            TEST_ENDPOINT=true
            shift
            ;;
        --watch-logs)
            WATCH_LOGS=true
            shift
            ;;
        --force-sync)
            FORCE_SYNC=true
            shift
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

log "🔗 Testing overrides-sync to RLS communication in namespace: $NAMESPACE"
echo

# Check if both services are running
log "📋 Checking service status..."

if ! kubectl get deployment overrides-sync -n "$NAMESPACE" &> /dev/null; then
    error "overrides-sync deployment not found"
    exit 1
fi

if ! kubectl get deployment mimir-rls -n "$NAMESPACE" &> /dev/null; then
    error "RLS deployment not found"
    exit 1
fi

kubectl get deployment overrides-sync mimir-rls -n "$NAMESPACE"
echo

# Test the new RLS endpoint if requested
if [[ "$TEST_ENDPOINT" == "true" ]]; then
    log "🌐 Testing new RLS endpoint /api/tenants/{id}/limits..."
    
    # Get RLS pod
    RLS_POD=$(kubectl get pods -l app.kubernetes.io/name=mimir-rls -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -z "$RLS_POD" ]]; then
        error "No RLS pods found"
        exit 1
    fi
    
    # Start port-forward
    kubectl port-forward "$RLS_POD" 8082:8082 -n "$NAMESPACE" &
    PF_PID=$!
    
    # Wait for port-forward
    sleep 3
    
    # Test the endpoint with sample data
    log "🔍 Testing PUT /api/tenants/test-tenant/limits..."
    
    curl -X PUT "http://localhost:8082/api/tenants/test-tenant/limits" \
        -H "Content-Type: application/json" \
        -d '{
            "samples_per_second": 50000,
            "burst_pct": 0.2,
            "max_body_bytes": 4194304,
            "max_labels_per_series": 60,
            "max_label_value_length": 2048,
            "max_series_per_request": 100000
        }' || warn "Endpoint test failed"
    
    echo
    
    # Check if tenant was created
    log "🔍 Checking if tenant was created..."
    curl -s "http://localhost:8082/api/tenants" | jq '.' || curl -s "http://localhost:8082/api/tenants"
    echo
    
    # Kill port-forward
    kill $PF_PID 2>/dev/null || true
    wait $PF_PID 2>/dev/null || true
fi

# Watch logs if requested
if [[ "$WATCH_LOGS" == "true" ]]; then
    log "📺 Watching logs from both services (Ctrl+C to stop)..."
    echo "🔍 Look for these key messages:"
    echo "   - overrides-sync: 'syncing overrides to RLS'"
    echo "   - overrides-sync: 'successfully synced tenant limits to RLS'"
    echo "   - RLS: 'RLS: tenant limits set via HTTP API from overrides-sync'"
    echo "   - RLS: 'RLS: received tenant limits from overrides-sync'"
    echo "=========================================="
    
    # Watch logs from both services
    kubectl logs -l app.kubernetes.io/name=overrides-sync -n "$NAMESPACE" -f --timestamps &
    OVERRIDES_PID=$!
    
    kubectl logs -l app.kubernetes.io/name=mimir-rls -n "$NAMESPACE" -f --timestamps &
    RLS_PID=$!
    
    # Wait for interrupt
    trap "kill $OVERRIDES_PID $RLS_PID 2>/dev/null || true; exit 0" INT
    wait
fi

# Force sync if requested
if [[ "$FORCE_SYNC" == "true" ]]; then
    log "🔄 Forcing ConfigMap sync by adding a timestamp annotation..."
    
    # Add timestamp annotation to trigger update
    kubectl annotate configmap mimir-overrides -n mimir \
        sync-test="$(date)" --overwrite || warn "Could not annotate ConfigMap"
    
    echo
    log "📄 Recent overrides-sync logs (after forced sync):"
    sleep 5
    kubectl logs -l app.kubernetes.io/name=overrides-sync -n "$NAMESPACE" --tail=20 | grep -E "(sync|tenant|RLS)" || echo "No sync logs found"
    
    echo
    log "📄 Recent RLS logs (after forced sync):"
    kubectl logs -l app.kubernetes.io/name=mimir-rls -n "$NAMESPACE" --tail=20 | grep -E "(tenant|overrides|HTTP API)" || echo "No tenant logs found"
fi

# Show helpful information
log "💡 Communication Troubleshooting:"
echo
echo "📊 Expected Log Flow:"
echo "  1. overrides-sync: 'syncing overrides to RLS' (tenant_count > 0)"
echo "  2. overrides-sync: 'sending tenant limits to RLS' (for each tenant)"
echo "  3. overrides-sync: 'successfully synced tenant limits to RLS'"
echo "  4. RLS: 'RLS: tenant limits set via HTTP API from overrides-sync'"
echo "  5. RLS: 'RLS: received tenant limits from overrides-sync'"
echo "  6. RLS: 'RLS: periodic tenant status - TENANTS LOADED'"
echo
echo "🔍 If communication fails, check:"
echo "  - Network connectivity: overrides-sync can reach mimir-rls:8082"
echo "  - DNS resolution: mimir-rls.mimir-edge-enforcement.svc.cluster.local"
echo "  - RLS admin port 8082 is accessible"
echo "  - ConfigMap parsing is working in overrides-sync"
echo
echo "🛠️  Manual Tests:"
echo "  # Test RLS endpoint directly:"
echo "  kubectl port-forward svc/mimir-rls 8082:8082 -n $NAMESPACE &"
echo "  curl -X PUT http://localhost:8082/api/tenants/test/limits -H 'Content-Type: application/json' -d '{\"samples_per_second\": 1000}'"
echo
echo "  # Check if services can reach each other:"
echo "  kubectl exec deployment/overrides-sync -n $NAMESPACE -- nc -zv mimir-rls.mimir-edge-enforcement.svc.cluster.local 8082"
echo

success "🎉 Communication test script completed!"
