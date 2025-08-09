#!/bin/bash

# 🔍 Debug Tenant Data Flow
# This script helps troubleshoot why the RLS has 0 active tenants

set -euo pipefail

# Configuration
NAMESPACE=${NAMESPACE:-mimir-edge-enforcement}
MIMIR_NAMESPACE=${MIMIR_NAMESPACE:-mimir}

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

log "🔍 Debugging Tenant Data Flow"
echo

# 1. Check if Mimir ConfigMap exists
log "📋 Step 1: Checking Mimir ConfigMap..."
if kubectl get configmap mimir-overrides -n "$MIMIR_NAMESPACE" &> /dev/null; then
    success "Mimir ConfigMap 'mimir-overrides' found in namespace '$MIMIR_NAMESPACE'"
    
    echo "ConfigMap data keys:"
    kubectl get configmap mimir-overrides -n "$MIMIR_NAMESPACE" -o jsonpath='{.data}' | jq -r 'keys[]' 2>/dev/null || echo "  (Unable to parse keys)"
    
    echo
    echo "ConfigMap size:"
    kubectl get configmap mimir-overrides -n "$MIMIR_NAMESPACE" -o jsonpath='{.data}' | wc -c | xargs -I {} echo "  {} bytes"
    
    # Show preview of ConfigMap content
    echo
    echo "ConfigMap content preview (first 10 lines):"
    kubectl get configmap mimir-overrides -n "$MIMIR_NAMESPACE" -o yaml | head -20
else
    error "Mimir ConfigMap 'mimir-overrides' not found in namespace '$MIMIR_NAMESPACE'"
    echo "Available ConfigMaps in $MIMIR_NAMESPACE:"
    kubectl get configmap -n "$MIMIR_NAMESPACE" | head -10
fi
echo

# 2. Check overrides-sync deployment
log "📦 Step 2: Checking overrides-sync deployment..."
if kubectl get deployment overrides-sync -n "$NAMESPACE" &> /dev/null; then
    success "overrides-sync deployment found"
    
    kubectl get deployment overrides-sync -n "$NAMESPACE"
    kubectl get pods -l app.kubernetes.io/name=overrides-sync -n "$NAMESPACE"
    
    # Get pod name
    POD_NAME=$(kubectl get pods -l app.kubernetes.io/name=overrides-sync -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$POD_NAME" ]]; then
        echo
        log "📄 Recent overrides-sync logs (last 20 lines):"
        echo "----------------------------------------"
        kubectl logs "$POD_NAME" -n "$NAMESPACE" --tail=20 || warn "Could not retrieve logs"
        echo "----------------------------------------"
    else
        warn "No overrides-sync pods found"
    fi
else
    error "overrides-sync deployment not found in namespace '$NAMESPACE'"
fi
echo

# 3. Check RLS deployment and tenant count
log "📦 Step 3: Checking RLS deployment and tenant count..."
if kubectl get deployment mimir-rls -n "$NAMESPACE" &> /dev/null; then
    success "RLS deployment found"
    
    kubectl get deployment mimir-rls -n "$NAMESPACE"
    kubectl get pods -l app.kubernetes.io/name=mimir-rls -n "$NAMESPACE"
    
    # Get RLS pod name
    RLS_POD=$(kubectl get pods -l app.kubernetes.io/name=mimir-rls -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$RLS_POD" ]]; then
        echo
        log "📄 Recent RLS logs (last 20 lines):"
        echo "----------------------------------------"
        kubectl logs "$RLS_POD" -n "$NAMESPACE" --tail=20 | grep -E "(tenant|sync|limits|error)" || echo "No tenant-related logs found"
        echo "----------------------------------------"
        
        echo
        log "🌐 Testing RLS API directly..."
        # Start port-forward in background
        kubectl port-forward "$RLS_POD" 8082:8082 -n "$NAMESPACE" &
        PF_PID=$!
        
        # Wait for port-forward to be ready
        sleep 3
        
        # Test API endpoints
        echo "Testing /api/overview:"
        curl -s "http://localhost:8082/api/overview" | jq '.' 2>/dev/null || curl -s "http://localhost:8082/api/overview"
        echo
        
        echo "Testing /api/tenants:"
        TENANTS_RESPONSE=$(curl -s "http://localhost:8082/api/tenants" 2>/dev/null || echo '{"error": "connection failed"}')
        echo "$TENANTS_RESPONSE" | jq '.' 2>/dev/null || echo "$TENANTS_RESPONSE"
        
        # Count tenants
        TENANT_COUNT=$(echo "$TENANTS_RESPONSE" | jq '.tenants | length' 2>/dev/null || echo "0")
        echo
        if [[ "$TENANT_COUNT" == "0" ]]; then
            warn "RLS reports 0 tenants - this explains the issue!"
        else
            success "RLS reports $TENANT_COUNT tenants"
        fi
        
        # Kill port-forward
        kill $PF_PID 2>/dev/null || true
        wait $PF_PID 2>/dev/null || true
    else
        warn "No RLS pods found"
    fi
else
    error "RLS deployment not found in namespace '$NAMESPACE'"
fi
echo

# 4. Check RBAC permissions
log "🔒 Step 4: Checking RBAC permissions..."
echo "Checking if overrides-sync has ConfigMap read permissions:"

# Get service account
SA_NAME=$(kubectl get deployment overrides-sync -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.serviceAccountName}' 2>/dev/null || echo "default")
echo "Service Account: $SA_NAME"

# Check if ServiceAccount exists
if kubectl get serviceaccount "$SA_NAME" -n "$NAMESPACE" &> /dev/null; then
    success "ServiceAccount '$SA_NAME' exists"
else
    warn "ServiceAccount '$SA_NAME' not found"
fi

# Check ClusterRole/RoleBinding
echo "Checking role bindings:"
kubectl get rolebinding,clusterrolebinding -A | grep -E "(overrides-sync|$SA_NAME)" || echo "No specific role bindings found"
echo

# 5. Check network connectivity
log "🌐 Step 5: Checking network connectivity..."
if [[ -n "${POD_NAME:-}" ]]; then
    echo "Testing overrides-sync to Mimir namespace connectivity:"
    kubectl exec "$POD_NAME" -n "$NAMESPACE" -- nc -zv kubernetes.default.svc.cluster.local 443 2>/dev/null && success "Can reach Kubernetes API" || warn "Cannot reach Kubernetes API"
fi
echo

# 6. Summary and recommendations
log "💡 Diagnosis Summary:"
echo
echo "Common causes for 0 active tenants:"
echo
echo "1. 🔍 ConfigMap Issues:"
echo "   - Mimir ConfigMap doesn't exist or is empty"
echo "   - ConfigMap has wrong format (should have 'overrides.yaml' key)"
echo "   - ConfigMap is in different namespace than expected"
echo
echo "2. 🔍 overrides-sync Issues:"
echo "   - Pod not running or crashing"
echo "   - No RBAC permissions to read ConfigMaps"
echo "   - Cannot connect to Kubernetes API"
echo "   - Parsing errors in ConfigMap format"
echo
echo "3. 🔍 RLS Issues:"
echo "   - RLS and overrides-sync not communicating"
echo "   - RLS not receiving tenant updates"
echo "   - Network connectivity issues"
echo
echo "Recommended next steps:"
echo
echo "🔧 If ConfigMap is missing:"
echo "   kubectl create configmap mimir-overrides -n $MIMIR_NAMESPACE --from-file=examples/production-mimir-overrides.yaml"
echo
echo "🔧 If RBAC issues:"
echo "   kubectl apply -f charts/overrides-sync/templates/rbac.yaml"
echo
echo "🔧 If parsing issues:"
echo "   kubectl logs -l app.kubernetes.io/name=overrides-sync -n $NAMESPACE | grep -E '(error|parsing|tenant)'"
echo
echo "🔧 To restart components:"
echo "   kubectl rollout restart deployment/overrides-sync -n $NAMESPACE"
echo "   kubectl rollout restart deployment/mimir-rls -n $NAMESPACE"
echo

success "🎉 Tenant data diagnosis completed!"
