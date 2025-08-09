#!/bin/bash

# 🎯 Deploy 10% Canary Configuration for Mimir Edge Enforcement
# This script deploys the NGINX configuration to route 10% of traffic through edge enforcement

set -euo pipefail

# Configuration
NAMESPACE=${NAMESPACE:-mimir}
CONFIGMAP=${CONFIGMAP:-mimir-nginx}
BACKUP_DIR=${BACKUP_DIR:-./nginx-backups}

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
    echo -e "${GREEN}✅${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

error() {
    echo -e "${RED}❌${NC} $1"
}

info() {
    echo -e "${PURPLE}ℹ️${NC} $1"
}

echo -e "${BLUE}🎯 Deploying 10% Canary Configuration for Mimir Edge Enforcement${NC}"
echo -e "${BLUE}================================================================${NC}"
echo

# 1. Check prerequisites
log "🔍 Checking Prerequisites"
echo "-------------------------"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    error "Namespace '$NAMESPACE' not found"
    echo "Create it with: kubectl create namespace $NAMESPACE"
    exit 1
fi

# Check if edge enforcement is deployed
if ! kubectl get service mimir-envoy -n mimir-edge-enforcement &> /dev/null; then
    warning "Edge enforcement service not found in mimir-edge-enforcement namespace"
    echo "Make sure mimir-edge-enforcement is deployed before proceeding"
    echo "You can continue if you plan to deploy it later"
    echo
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

success "Prerequisites check completed"
echo

# 2. Backup existing configuration
log "💾 Backing Up Existing Configuration"
echo "-------------------------------------"

mkdir -p "$BACKUP_DIR"

if kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" &> /dev/null; then
    BACKUP_FILE="$BACKUP_DIR/nginx-backup-$(date +%Y%m%d-%H%M%S).yaml"
    kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" -o yaml > "$BACKUP_FILE"
    success "Existing configuration backed up to: $BACKUP_FILE"
else
    info "No existing ConfigMap found - first deployment"
fi
echo

# 3. Validate the new configuration file
log "🧪 Validating New Configuration"
echo "--------------------------------"

CONFIG_FILE="examples/nginx-10-percent-canary.yaml"

if [[ ! -f "$CONFIG_FILE" ]]; then
    error "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Basic YAML validation
if ! kubectl apply --dry-run=client -f "$CONFIG_FILE" &> /dev/null; then
    error "Configuration file has invalid YAML syntax"
    exit 1
fi

success "Configuration file validation passed"
echo

# 4. Show configuration summary
log "📋 Configuration Summary"
echo "------------------------"

echo "📁 Configuration File: $CONFIG_FILE"
echo "🎯 Traffic Distribution:"
echo "   • 10% → Edge Enforcement (mimir-envoy.mimir-edge-enforcement.svc.cluster.local:8080)"
echo "   • 90% → Direct to Mimir (distributor.mimir.svc.cluster.local:8080)"
echo
echo "🎛️ Routing Logic:"
echo "   • Hash-based on \$request_id for consistent routing"
echo "   • Requests ending in '0' (10%) → Edge Enforcement"
echo "   • All other requests (90%) → Direct to Mimir"
echo
echo "🚨 Emergency Routes:"
echo "   • /api/v1/push/direct → Force direct (bypass edge enforcement)"
echo "   • /api/v1/push/edge → Force edge enforcement"
echo
echo "📊 Observability:"
echo "   • X-Canary-Route header shows routing decision"
echo "   • X-Route-Type header shows specific route type"
echo "   • Access logs include route decision"
echo

# 5. Confirm deployment
warning "This will update your NGINX configuration to route 10% of traffic through edge enforcement"
echo
read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled"
    exit 0
fi

# 6. Deploy the configuration
log "🚀 Deploying 10% Canary Configuration"
echo "--------------------------------------"

if kubectl apply -f "$CONFIG_FILE"; then
    success "Configuration deployed successfully"
else
    error "Failed to deploy configuration"
    if [[ -f "${BACKUP_FILE:-}" ]]; then
        echo "To rollback, run: kubectl apply -f $BACKUP_FILE"
    fi
    exit 1
fi
echo

# 7. Restart NGINX pods to pick up new configuration
log "🔄 Restarting NGINX Pods"
echo "-------------------------"

# Try different methods to restart NGINX pods
if kubectl rollout restart deployment/nginx -n "$NAMESPACE" 2>/dev/null; then
    success "NGINX deployment restarted"
    kubectl rollout status deployment/nginx -n "$NAMESPACE" --timeout=60s
elif kubectl rollout restart daemonset/nginx -n "$NAMESPACE" 2>/dev/null; then
    success "NGINX daemonset restarted"
    kubectl rollout status daemonset/nginx -n "$NAMESPACE" --timeout=60s
elif kubectl delete pods -l app=nginx -n "$NAMESPACE" 2>/dev/null; then
    success "NGINX pods deleted (will be recreated)"
    sleep 5
else
    warning "Could not automatically restart NGINX pods"
    echo "Please restart your NGINX pods manually to pick up the new configuration"
fi
echo

# 8. Verify deployment
log "✅ Verifying Deployment"
echo "------------------------"

# Check if ConfigMap was updated
if kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" -o jsonpath='{.data.nginx\.conf}' | grep -q "mimir-envoy.mimir-edge-enforcement"; then
    success "ConfigMap updated with edge enforcement routes"
else
    error "ConfigMap does not contain edge enforcement configuration"
fi

# Check for NGINX pods
NGINX_PODS=$(kubectl get pods -l app=nginx -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
if [[ -n "$NGINX_PODS" ]]; then
    success "NGINX pods running: $NGINX_PODS"
    
    # Check if pods are ready
    if kubectl wait --for=condition=ready pod -l app=nginx -n "$NAMESPACE" --timeout=60s 2>/dev/null; then
        success "NGINX pods are ready"
    else
        warning "NGINX pods may not be ready yet"
    fi
else
    warning "No NGINX pods found (check your pod selector)"
fi
echo

# 9. Test the configuration
log "🧪 Testing Configuration"
echo "-------------------------"

info "You can test the canary routing with:"
echo
echo "# Test normal routing (will be 10% edge, 90% direct)"
echo "curl -H \"X-Scope-OrgID: test-tenant\" \\"
echo "     -X POST http://your-nginx/api/v1/push \\"
echo "     -v 2>&1 | grep X-Canary-Route"
echo
echo "# Force direct routing (emergency bypass)"
echo "curl -H \"X-Scope-OrgID: test-tenant\" \\"
echo "     -X POST http://your-nginx/api/v1/push/direct"
echo
echo "# Force edge enforcement routing"
echo "curl -H \"X-Scope-OrgID: test-tenant\" \\"
echo "     -X POST http://your-nginx/api/v1/push/edge"
echo

# 10. Show monitoring commands
log "📊 Monitoring Commands"
echo "----------------------"

echo "# Monitor NGINX access logs for routing decisions"
echo "kubectl logs -f deployment/nginx -n $NAMESPACE | grep route="
echo
echo "# Check edge enforcement health"
echo "./scripts/production-health-check.sh"
echo
echo "# Extract protection metrics"
echo "./scripts/extract-protection-metrics.sh"
echo
echo "# Monitor edge enforcement effectiveness"
echo "./scripts/validate-effectiveness.sh"
echo

# 11. Summary
success "🎉 10% Canary Deployment Completed Successfully!"
echo
echo "📊 Current Configuration:"
echo "   • 10% of /api/v1/push traffic → Edge Enforcement"
echo "   • 90% of /api/v1/push traffic → Direct to Mimir"
echo "   • Emergency bypass available at /api/v1/push/direct"
echo "   • Force edge testing available at /api/v1/push/edge"
echo
echo "🎯 Next Steps:"
echo "   1. Monitor edge enforcement metrics and effectiveness"
echo "   2. Check deny rates and protection in Admin UI"
echo "   3. Validate that 10% of traffic shows rate limiting"
echo "   4. If successful, consider increasing to 25%, 50%, then 100%"
echo
echo "🚨 Emergency Rollback:"
if [[ -f "${BACKUP_FILE:-}" ]]; then
    echo "   kubectl apply -f $BACKUP_FILE"
else
    echo "   ./scripts/manage-nginx-canary.sh disable"
fi
echo
echo "📈 To increase canary percentage:"
echo "   ./scripts/manage-nginx-canary.sh set-weight 25"
echo
info "Happy canary testing! Monitor your metrics and gradually increase traffic." 
