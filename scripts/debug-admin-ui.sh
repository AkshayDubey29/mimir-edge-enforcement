#!/bin/bash

# 🔍 Debug Mimir Edge Enforcement Admin UI
# This script helps troubleshoot Admin UI deployment issues

set -euo pipefail

# Configuration
NAMESPACE=${NAMESPACE:-mimir-edge-enforcement}
DEPLOYMENT_NAME=${DEPLOYMENT_NAME:-mimir-admin}

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
🔍 Debug Mimir Edge Enforcement Admin UI

Usage: $0 [options]

Options:
  --namespace NAMESPACE     Kubernetes namespace (default: mimir-edge-enforcement)
  --deployment DEPLOYMENT   Deployment name (default: mimir-admin)
  --pod-logs               Show pod logs
  --test-endpoints         Test health and debug endpoints
  --check-files            Check if React files exist in pod
  --nginx-config           Show current NGINX configuration
  --all                    Run all debug checks
  --help                   Show this help message

Examples:
  $0 --all                     # Run all debug checks
  $0 --test-endpoints          # Test endpoints only
  $0 --pod-logs               # Show recent logs
EOF
}

# Parse command line arguments
SHOW_LOGS=false
TEST_ENDPOINTS=false
CHECK_FILES=false
SHOW_CONFIG=false
RUN_ALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --deployment)
            DEPLOYMENT_NAME="$2"
            shift 2
            ;;
        --pod-logs)
            SHOW_LOGS=true
            shift
            ;;
        --test-endpoints)
            TEST_ENDPOINTS=true
            shift
            ;;
        --check-files)
            CHECK_FILES=true
            shift
            ;;
        --nginx-config)
            SHOW_CONFIG=true
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
    SHOW_LOGS=true
    TEST_ENDPOINTS=true
    CHECK_FILES=true
    SHOW_CONFIG=true
fi

log "🔍 Debugging Admin UI in namespace: $NAMESPACE"
echo

# Check if deployment exists
log "📋 Checking deployment status..."
if ! kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" &> /dev/null; then
    error "Deployment '$DEPLOYMENT_NAME' not found in namespace '$NAMESPACE'"
    exit 1
fi

# Get deployment status
kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE"
kubectl get pods -l app.kubernetes.io/name=admin-ui -n "$NAMESPACE"
echo

# Get pod name
POD_NAME=$(kubectl get pods -l app.kubernetes.io/name=admin-ui -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -z "$POD_NAME" ]]; then
    error "No Admin UI pods found"
    exit 1
fi

log "📦 Using pod: $POD_NAME"
echo

# Show logs if requested
if [[ "$SHOW_LOGS" == "true" ]]; then
    log "📄 Recent pod logs (last 50 lines):"
    echo "----------------------------------------"
    kubectl logs "$POD_NAME" -n "$NAMESPACE" --tail=50 || warn "Could not retrieve logs"
    echo "----------------------------------------"
    echo
fi

# Show NGINX config if requested
if [[ "$SHOW_CONFIG" == "true" ]]; then
    log "⚙️  Current NGINX configuration:"
    echo "----------------------------------------"
    kubectl exec "$POD_NAME" -n "$NAMESPACE" -- cat /etc/nginx/nginx.conf 2>/dev/null || warn "Could not retrieve NGINX config"
    echo "----------------------------------------"
    echo
fi

# Check files if requested
if [[ "$CHECK_FILES" == "true" ]]; then
    log "📁 Checking React app files in pod:"
    echo "----------------------------------------"
    kubectl exec "$POD_NAME" -n "$NAMESPACE" -- ls -la /usr/share/nginx/html/ 2>/dev/null || warn "Could not list files"
    echo
    log "📄 Checking index.html content:"
    echo "----------------------------------------"
    kubectl exec "$POD_NAME" -n "$NAMESPACE" -- head -20 /usr/share/nginx/html/index.html 2>/dev/null || warn "Could not read index.html"
    echo "----------------------------------------"
    echo
fi

# Test endpoints if requested
if [[ "$TEST_ENDPOINTS" == "true" ]]; then
    log "🌐 Testing endpoints via port-forward..."
    
    # Start port-forward in background
    kubectl port-forward "$POD_NAME" 8888:80 -n "$NAMESPACE" &
    PF_PID=$!
    
    # Wait for port-forward to be ready
    sleep 3
    
    echo "Testing endpoints on localhost:8888..."
    echo
    
    # Test health endpoint
    log "🔍 Testing /health endpoint:"
    curl -s -w "Status: %{http_code}\n" http://localhost:8888/health || warn "Health endpoint failed"
    echo
    
    # Test healthz endpoint
    log "🔍 Testing /healthz endpoint:"
    curl -s -w "Status: %{http_code}\n" http://localhost:8888/healthz || warn "Healthz endpoint failed"
    echo
    
    # Test debug endpoint
    log "🔍 Testing /debug endpoint:"
    curl -s -w "Status: %{http_code}\n" http://localhost:8888/debug || warn "Debug endpoint failed"
    echo
    
    # Test main page
    log "🔍 Testing / (main page):"
    RESPONSE=$(curl -s -w "Status: %{http_code}\n" http://localhost:8888/ 2>/dev/null || echo "Failed to connect")
    if [[ "$RESPONSE" == *"200"* ]]; then
        if [[ "$RESPONSE" == *"<!doctype html>"* ]] || [[ "$RESPONSE" == *"<html"* ]]; then
            success "Main page returns HTML content (200)"
        else
            warn "Main page returns 200 but no HTML content detected"
        fi
    else
        warn "Main page test failed: $RESPONSE"
    fi
    echo
    
    # Test a static asset
    log "🔍 Testing /assets/ (static files):"
    ASSET_RESPONSE=$(curl -s -w "Status: %{http_code}\n" http://localhost:8888/assets/ 2>/dev/null || echo "Failed")
    echo "Assets directory: $ASSET_RESPONSE"
    echo
    
    # Kill port-forward
    kill $PF_PID 2>/dev/null || true
    wait $PF_PID 2>/dev/null || true
fi

# Check service and ingress
log "🌐 Checking service and ingress:"
kubectl get service -l app.kubernetes.io/name=admin-ui -n "$NAMESPACE" 2>/dev/null || warn "No Admin UI service found"
kubectl get ingress -n "$NAMESPACE" 2>/dev/null || warn "No ingress found"
echo

# Show events
log "📅 Recent events for Admin UI:"
kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | grep -i admin || warn "No Admin UI events found"
echo

# Recommendations
log "💡 Troubleshooting Recommendations:"
echo
echo "1. If main page (/) returns 200 but browser shows blank:"
echo "   - Check browser console for JavaScript errors"
echo "   - Verify React app is built correctly"
echo "   - Check Content-Security-Policy headers"
echo
echo "2. If health endpoints work but main page fails:"
echo "   - React app files might be missing or corrupted"
echo "   - Check if /usr/share/nginx/html/index.html exists"
echo "   - Verify Docker build process"
echo
echo "3. If all endpoints fail:"
echo "   - NGINX configuration issues"
echo "   - Pod networking problems"
echo "   - Service/Ingress misconfiguration"
echo
echo "4. Check browser network tab for failed requests"
echo "5. Verify ALB health checks are passing"
echo "6. Check if domain DNS resolves correctly"
echo

success "🎉 Debug analysis completed!"
