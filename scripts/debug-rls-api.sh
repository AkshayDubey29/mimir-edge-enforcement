#!/bin/bash

# 🔍 Debug RLS Admin API Endpoints
# This script helps troubleshoot RLS API connectivity issues

set -euo pipefail

# Configuration
NAMESPACE=${NAMESPACE:-mimir-edge-enforcement}
RLS_SERVICE=${RLS_SERVICE:-mimir-rls}
LOCAL_PORT=${LOCAL_PORT:-8082}

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
🔍 Debug RLS Admin API Endpoints

Usage: $0 [options]

Options:
  --namespace NAMESPACE     Kubernetes namespace (default: mimir-edge-enforcement)
  --service SERVICE         RLS service name (default: mimir-rls)
  --port PORT              Local port for port-forward (default: 8082)
  --test-direct            Test direct API calls without port-forward
  --test-via-admin-ui      Test via Admin UI proxy
  --check-logs             Show RLS logs
  --all                    Run all debug checks
  --help                   Show this help message

Examples:
  $0 --all                     # Run all debug checks
  $0 --test-direct            # Test API endpoints directly
  $0 --check-logs             # Show RLS service logs
EOF
}

# Parse command line arguments
TEST_DIRECT=false
TEST_VIA_ADMIN_UI=false
CHECK_LOGS=false
RUN_ALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --service)
            RLS_SERVICE="$2"
            shift 2
            ;;
        --port)
            LOCAL_PORT="$2"
            shift 2
            ;;
        --test-direct)
            TEST_DIRECT=true
            shift
            ;;
        --test-via-admin-ui)
            TEST_VIA_ADMIN_UI=true
            shift
            ;;
        --check-logs)
            CHECK_LOGS=true
            shift
            ;;
        --all)
            RUN_ALL=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ "$RUN_ALL" == "true" ]]; then
    TEST_DIRECT=true
    TEST_VIA_ADMIN_UI=true
    CHECK_LOGS=true
fi

log "🔍 Debugging RLS API in namespace: $NAMESPACE"
echo

# Check if RLS service exists
log "📋 Checking RLS deployment status..."
if ! kubectl get deployment "$RLS_SERVICE" -n "$NAMESPACE" &> /dev/null; then
    error "RLS deployment '$RLS_SERVICE' not found in namespace '$NAMESPACE'"
    exit 1
fi

# Get deployment status
kubectl get deployment "$RLS_SERVICE" -n "$NAMESPACE"
kubectl get pods -l app.kubernetes.io/name=mimir-rls -n "$NAMESPACE"
kubectl get services -l app.kubernetes.io/name=mimir-rls -n "$NAMESPACE"
echo

# Get pod name
POD_NAME=$(kubectl get pods -l app.kubernetes.io/name=mimir-rls -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -z "$POD_NAME" ]]; then
    error "No RLS pods found"
    exit 1
fi

log "📦 Using RLS pod: $POD_NAME"
echo

# Show logs if requested
if [[ "$CHECK_LOGS" == "true" ]]; then
    log "📄 Recent RLS logs (last 50 lines):"
    echo "----------------------------------------"
    kubectl logs "$POD_NAME" -n "$NAMESPACE" --tail=50 || warn "Could not retrieve logs"
    echo "----------------------------------------"
    echo
fi

# Test direct API calls if requested
if [[ "$TEST_DIRECT" == "true" ]]; then
    log "🌐 Testing RLS API endpoints directly via port-forward..."
    
    # Start port-forward in background
    kubectl port-forward "$POD_NAME" "$LOCAL_PORT:8082" -n "$NAMESPACE" &
    PF_PID=$!
    
    # Wait for port-forward to be ready
    sleep 3
    
    echo "Testing RLS endpoints on localhost:$LOCAL_PORT..."
    echo
    
    # Test health endpoint
    log "🔍 Testing /healthz endpoint:"
    curl -s -w "Status: %{http_code}, Size: %{size_download} bytes\n" "http://localhost:$LOCAL_PORT/healthz" 2>/dev/null || warn "Health endpoint failed"
    echo
    
    # Test readiness endpoint
    log "🔍 Testing /readyz endpoint:"
    curl -s -w "Status: %{http_code}, Size: %{size_download} bytes\n" "http://localhost:$LOCAL_PORT/readyz" 2>/dev/null || warn "Readiness endpoint failed"
    echo
    
    # Test API health endpoint
    log "🔍 Testing /api/health endpoint:"
    RESPONSE=$(curl -s -w "Status: %{http_code}\n" "http://localhost:$LOCAL_PORT/api/health" 2>/dev/null || echo "Failed to connect")
    echo "$RESPONSE"
    echo
    
    # Test API overview endpoint
    log "🔍 Testing /api/overview endpoint:"
    RESPONSE=$(curl -s -w "Status: %{http_code}\n" "http://localhost:$LOCAL_PORT/api/overview" 2>/dev/null || echo "Failed to connect")
    echo "$RESPONSE"
    echo
    
    # Test API tenants endpoint (the problematic one)
    log "🔍 Testing /api/tenants endpoint:"
    RESPONSE=$(curl -s -w "Status: %{http_code}\n" "http://localhost:$LOCAL_PORT/api/tenants" 2>/dev/null || echo "Failed to connect")
    if [[ "$RESPONSE" == *"200"* ]]; then
        success "Tenants endpoint responds with 200"
        echo "Response preview:"
        curl -s "http://localhost:$LOCAL_PORT/api/tenants" 2>/dev/null | head -5 || echo "Could not get response body"
    else
        warn "Tenants endpoint failed: $RESPONSE"
    fi
    echo
    
    # Test API denials endpoint
    log "🔍 Testing /api/denials endpoint:"
    RESPONSE=$(curl -s -w "Status: %{http_code}\n" "http://localhost:$LOCAL_PORT/api/denials" 2>/dev/null || echo "Failed to connect")
    echo "$RESPONSE"
    echo
    
    # Kill port-forward
    kill $PF_PID 2>/dev/null || true
    wait $PF_PID 2>/dev/null || true
fi

# Test via Admin UI if requested
if [[ "$TEST_VIA_ADMIN_UI" == "true" ]]; then
    log "🌐 Testing API via Admin UI proxy..."
    
    # Check if Admin UI is deployed
    ADMIN_POD=$(kubectl get pods -l app.kubernetes.io/name=admin-ui -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$ADMIN_POD" ]]; then
        log "📦 Found Admin UI pod: $ADMIN_POD"
        
        # Start port-forward to Admin UI
        kubectl port-forward "$ADMIN_POD" 8888:80 -n "$NAMESPACE" &
        ADMIN_PF_PID=$!
        
        # Wait for port-forward to be ready
        sleep 3
        
        # Test API through Admin UI proxy
        log "🔍 Testing /api/tenants via Admin UI proxy:"
        RESPONSE=$(curl -s -w "Status: %{http_code}\n" "http://localhost:8888/api/tenants" 2>/dev/null || echo "Failed to connect")
        if [[ "$RESPONSE" == *"200"* ]]; then
            success "Tenants endpoint works via Admin UI proxy"
        else
            warn "Tenants endpoint failed via Admin UI proxy: $RESPONSE"
        fi
        echo
        
        # Kill admin UI port-forward
        kill $ADMIN_PF_PID 2>/dev/null || true
        wait $ADMIN_PF_PID 2>/dev/null || true
    else
        warn "Admin UI not found - cannot test proxy"
    fi
fi

# Network connectivity tests
log "🌐 Checking network connectivity..."

# Test if RLS admin port is accessible from within cluster
log "🔍 Testing RLS admin port accessibility:"
kubectl exec "$POD_NAME" -n "$NAMESPACE" -- nc -zv localhost 8082 2>/dev/null && success "RLS admin port 8082 is accessible" || warn "RLS admin port 8082 not accessible"

# Check if RLS process is running
log "🔍 Checking RLS process:"
kubectl exec "$POD_NAME" -n "$NAMESPACE" -- ps aux | grep rls || warn "RLS process check failed"
echo

# Check service endpoints
log "🔍 Checking service endpoints:"
kubectl get endpoints "$RLS_SERVICE" -n "$NAMESPACE" 2>/dev/null || warn "No service endpoints found"
echo

# Check if overrides-sync is working
log "🔍 Checking overrides-sync integration:"
OVERRIDES_POD=$(kubectl get pods -l app.kubernetes.io/name=overrides-sync -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "$OVERRIDES_POD" ]]; then
    log "📦 Found overrides-sync pod: $OVERRIDES_POD"
    kubectl logs "$OVERRIDES_POD" -n "$NAMESPACE" --tail=10 | grep -E "(tenant|sync|error)" || echo "No recent tenant sync logs"
else
    warn "Overrides-sync pod not found"
fi
echo

# Summary and recommendations
log "💡 Troubleshooting Summary:"
echo
echo "If /api/tenants is failing with ERR_CONNECTION_RESET:"
echo
echo "1. 🔍 Check RLS logs for errors:"
echo "   kubectl logs $POD_NAME -n $NAMESPACE"
echo
echo "2. 🔧 Verify RLS admin server is listening:"
echo "   kubectl exec $POD_NAME -n $NAMESPACE -- netstat -tlnp | grep 8082"
echo
echo "3. 🌐 Test direct connectivity:"
echo "   kubectl port-forward $POD_NAME 8082:8082 -n $NAMESPACE"
echo "   curl http://localhost:8082/api/tenants"
echo
echo "4. 📊 Check if tenants are loaded:"
echo "   curl http://localhost:8082/api/health"
echo "   curl http://localhost:8082/api/overview"
echo
echo "5. 🔄 Restart RLS if needed:"
echo "   kubectl rollout restart deployment/$RLS_SERVICE -n $NAMESPACE"
echo
echo "6. 🔍 Check for memory/resource issues:"
echo "   kubectl top pod $POD_NAME -n $NAMESPACE"
echo "   kubectl describe pod $POD_NAME -n $NAMESPACE"
echo

success "🎉 RLS API debug analysis completed!"
