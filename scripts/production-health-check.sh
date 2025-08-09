#!/bin/bash

# 🔍 Production Health Check for Edge Enforcement
# Validates that the edge enforcement system is working correctly

set -euo pipefail

# Configuration
NAMESPACE=${NAMESPACE:-mimir-edge-enforcement}
TIMEOUT=${TIMEOUT:-30}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ SUCCESS:${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠️  WARNING:${NC} $1"
}

error() {
    echo -e "${RED}❌ ERROR:${NC} $1"
}

info() {
    echo -e "${PURPLE}ℹ️  INFO:${NC} $1"
}

echo -e "${BLUE}🔍 Edge Enforcement Health Check${NC}"
echo -e "${BLUE}================================${NC}"
echo

# 1. Check if namespace exists
log "Checking namespace: $NAMESPACE"
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    error "Namespace '$NAMESPACE' not found"
    exit 1
fi
success "Namespace '$NAMESPACE' exists"
echo

# 2. Check if all pods are running
log "📦 Pod Status Check"
echo "--------------------"
POD_STATUS=$(kubectl get pods -n "$NAMESPACE" -o json)
TOTAL_PODS=$(echo "$POD_STATUS" | jq '.items | length')
RUNNING_PODS=$(echo "$POD_STATUS" | jq '.items | map(select(.status.phase == "Running")) | length')

echo "Total Pods: $TOTAL_PODS"
echo "Running Pods: $RUNNING_PODS"

if [[ "$RUNNING_PODS" -eq "$TOTAL_PODS" && "$TOTAL_PODS" -gt 0 ]]; then
    success "All $TOTAL_PODS pods are running"
else
    warning "Only $RUNNING_PODS/$TOTAL_PODS pods are running"
    kubectl get pods -n "$NAMESPACE" -o wide
fi

# Show detailed pod status
kubectl get pods -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount,AGE:.metadata.creationTimestamp
echo

# 3. Check overrides-sync tenant loading
log "👥 Tenant Loading Status"
echo "-------------------------"
OVERRIDES_LOGS=$(kubectl logs -l app.kubernetes.io/name=overrides-sync -n "$NAMESPACE" --tail=20 2>/dev/null || echo "")

if [[ -n "$OVERRIDES_LOGS" ]]; then
    TENANT_COUNT=$(echo "$OVERRIDES_LOGS" | grep -o "tenant_count\":[0-9]*" | tail -1 | cut -d: -f2 || echo "0")
    SUCCESSFUL_SYNCS=$(echo "$OVERRIDES_LOGS" | grep "successfully synced tenant limits" | wc -l)
    
    if [[ "$TENANT_COUNT" -gt 0 ]]; then
        success "Loaded $TENANT_COUNT tenants"
        info "Successful syncs: $SUCCESSFUL_SYNCS"
    else
        error "No tenants loaded (tenant_count: $TENANT_COUNT)"
        echo "Recent overrides-sync logs:"
        echo "$OVERRIDES_LOGS" | tail -5
    fi
else
    warning "No overrides-sync logs found"
fi
echo

# 4. Check RLS enforcement activity
log "⚖️ RLS Enforcement Activity"
echo "----------------------------"
RLS_LOGS=$(kubectl logs -l app.kubernetes.io/name=mimir-rls -n "$NAMESPACE" --tail=50 2>/dev/null || echo "")

if [[ -n "$RLS_LOGS" ]]; then
    TOTAL_REQUESTS=$(echo "$RLS_LOGS" | grep "total_requests" | tail -1 | grep -o "total_requests\":[0-9]*" | cut -d: -f2 || echo "0")
    ALLOWED_REQUESTS=$(echo "$RLS_LOGS" | grep "allowed_requests" | tail -1 | grep -o "allowed_requests\":[0-9]*" | cut -d: -f2 || echo "0")
    DENIED_REQUESTS=$(echo "$RLS_LOGS" | grep "denied_requests" | tail -1 | grep -o "denied_requests\":[0-9]*" | cut -d: -f2 || echo "0")
    
    if [[ "$TOTAL_REQUESTS" -gt 0 ]]; then
        success "RLS processing requests"
        info "Total: $TOTAL_REQUESTS, Allowed: $ALLOWED_REQUESTS, Denied: $DENIED_REQUESTS"
        
        if [[ "$DENIED_REQUESTS" -gt 0 ]]; then
            success "Active protection: $DENIED_REQUESTS denials"
        else
            warning "No denials yet (protection may not be needed or not working)"
        fi
    else
        warning "No requests processed by RLS yet"
    fi
    
    # Check for recent API requests
    API_REQUESTS=$(echo "$RLS_LOGS" | grep "admin API request" | wc -l)
    if [[ "$API_REQUESTS" -gt 0 ]]; then
        success "RLS receiving API requests ($API_REQUESTS recent)"
    else
        warning "No recent RLS API requests"
    fi
else
    warning "No RLS logs found"
fi
echo

# 5. Check Envoy proxy status
log "🌐 Envoy Proxy Status"
echo "----------------------"
ENVOY_LOGS=$(kubectl logs -l app.kubernetes.io/name=mimir-envoy -n "$NAMESPACE" --tail=20 2>/dev/null || echo "")

if [[ -n "$ENVOY_LOGS" ]]; then
    if echo "$ENVOY_LOGS" | grep -q "starting main dispatch loop"; then
        success "Envoy proxy is running"
    fi
    
    EXT_AUTHZ_CALLS=$(echo "$ENVOY_LOGS" | grep "ext_authz" | wc -l)
    if [[ "$EXT_AUTHZ_CALLS" -gt 0 ]]; then
        success "Envoy making ext_authz calls ($EXT_AUTHZ_CALLS recent)"
    else
        warning "No recent ext_authz calls from Envoy"
    fi
else
    warning "No Envoy logs found"
fi
echo

# 6. Test Admin UI accessibility
log "🖥️ Admin UI Accessibility"
echo "--------------------------"
INGRESS_STATUS=$(kubectl get ingress -n "$NAMESPACE" 2>/dev/null || echo "")
SERVICE_STATUS=$(kubectl get svc -l app.kubernetes.io/name=admin-ui -n "$NAMESPACE" 2>/dev/null || echo "")

if [[ -n "$INGRESS_STATUS" ]]; then
    success "Admin UI Ingress configured"
    echo "$INGRESS_STATUS"
elif [[ -n "$SERVICE_STATUS" ]]; then
    success "Admin UI Service available"
    echo "$SERVICE_STATUS"
else
    warning "No Admin UI ingress or service found"
fi
echo

# 7. Quick API test
log "🔌 RLS API Connectivity Test"
echo "------------------------------"
RLS_POD=$(kubectl get pods -l app.kubernetes.io/name=mimir-rls -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -n "$RLS_POD" ]]; then
    info "Testing RLS API via port-forward..."
    
    # Start port-forward in background
    kubectl port-forward "$RLS_POD" 8082:8082 -n "$NAMESPACE" &
    PF_PID=$!
    
    # Wait for port-forward to establish
    sleep 3
    
    # Test health endpoint
    if curl -s --max-time 5 "http://localhost:8082/healthz" &> /dev/null; then
        success "RLS health endpoint responding"
        
        # Test API endpoints
        OVERVIEW_RESPONSE=$(curl -s --max-time 5 "http://localhost:8082/api/overview" 2>/dev/null || echo "{}")
        ACTIVE_TENANTS=$(echo "$OVERVIEW_RESPONSE" | jq -r '.stats.active_tenants // 0' 2>/dev/null || echo "0")
        
        if [[ "$ACTIVE_TENANTS" -gt 0 ]]; then
            success "Admin API working: $ACTIVE_TENANTS active tenants"
        else
            warning "Admin API responding but no active tenants"
        fi
    else
        error "RLS health endpoint not responding"
    fi
    
    # Clean up port-forward
    kill $PF_PID 2>/dev/null || true
    wait $PF_PID 2>/dev/null || true
else
    error "No RLS pod found for API testing"
fi
echo

# 8. Summary and recommendations
log "📋 Health Check Summary"
echo "========================"

HEALTH_SCORE=0
TOTAL_CHECKS=7

# Score the health check
[[ "$RUNNING_PODS" -eq "$TOTAL_PODS" && "$TOTAL_PODS" -gt 0 ]] && ((HEALTH_SCORE++))
[[ "$TENANT_COUNT" -gt 0 ]] && ((HEALTH_SCORE++))
[[ "$TOTAL_REQUESTS" -gt 0 ]] && ((HEALTH_SCORE++))
[[ "$API_REQUESTS" -gt 0 ]] && ((HEALTH_SCORE++))
[[ "$EXT_AUTHZ_CALLS" -gt 0 ]] && ((HEALTH_SCORE++))
[[ -n "$INGRESS_STATUS" || -n "$SERVICE_STATUS" ]] && ((HEALTH_SCORE++))
[[ "$ACTIVE_TENANTS" -gt 0 ]] && ((HEALTH_SCORE++))

HEALTH_PERCENTAGE=$((HEALTH_SCORE * 100 / TOTAL_CHECKS))

echo "Health Score: $HEALTH_SCORE/$TOTAL_CHECKS ($HEALTH_PERCENTAGE%)"

if [[ "$HEALTH_PERCENTAGE" -ge 85 ]]; then
    success "🎉 Edge enforcement system is healthy and working efficiently!"
    echo
    echo "✅ Tenants loaded: $TENANT_COUNT"
    echo "✅ Requests processed: $TOTAL_REQUESTS"
    echo "✅ Active protection: $DENIED_REQUESTS denials"
    echo "✅ Admin UI accessible"
elif [[ "$HEALTH_PERCENTAGE" -ge 60 ]]; then
    warning "⚠️ Edge enforcement system partially working - needs attention"
    echo
    echo "🔧 Recommended actions:"
    [[ "$TENANT_COUNT" -eq 0 ]] && echo "  - Check overrides-sync ConfigMap access"
    [[ "$TOTAL_REQUESTS" -eq 0 ]] && echo "  - Verify traffic routing through Envoy"
    [[ "$API_REQUESTS" -eq 0 ]] && echo "  - Check RLS service connectivity"
else
    error "❌ Edge enforcement system has significant issues"
    echo
    echo "🚨 Critical actions needed:"
    echo "  - Check pod logs for errors"
    echo "  - Verify Mimir ConfigMap exists and is accessible"
    echo "  - Ensure traffic is routed through edge enforcement"
    echo "  - Run detailed debugging: ./scripts/debug-404-issue.sh"
fi

echo
info "💡 For detailed monitoring, access Admin UI or run:"
echo "     ./scripts/extract-protection-metrics.sh"
echo "     kubectl port-forward svc/admin-ui 3000:80 -n $NAMESPACE"
