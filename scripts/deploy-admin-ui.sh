#!/bin/bash
set -euo pipefail

# Admin UI Deployment Script for mimir-edge-enforcement
# Usage: ./scripts/deploy-admin-ui.sh [deployment-type] [domain] [namespace]

DEPLOYMENT_TYPE=${1:-ingress}  # ingress, loadbalancer, or nodeport
DOMAIN=${2:-mimir-admin.local}
NAMESPACE=${3:-mimir-edge-enforcement}

echo "🚀 Deploying Admin UI for mimir-edge-enforcement"
echo "📦 Deployment Type: $DEPLOYMENT_TYPE"
echo "🌐 Domain: $DOMAIN"
echo "📦 Namespace: $NAMESPACE"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        log_error "helm not found. Please install Helm 3.x."
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Check your kubeconfig."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Create basic auth secret (if using ingress with auth)
create_basic_auth() {
    if [[ "$DEPLOYMENT_TYPE" == "ingress" ]]; then
        log_info "Creating basic auth secret for Admin UI..."
        
        # Generate random password
        local PASSWORD=$(openssl rand -base64 12)
        local USERNAME="admin"
        
        # Create htpasswd entry
        local HTPASSWD=$(htpasswd -nb "$USERNAME" "$PASSWORD")
        
        # Create secret
        kubectl create secret generic admin-ui-auth \
            --from-literal=auth="$HTPASSWD" \
            --namespace="$NAMESPACE" \
            --dry-run=client -o yaml | kubectl apply -f -
        
        log_success "Basic auth created: Username=$USERNAME, Password=$PASSWORD"
        echo "💾 Save these credentials: Username=$USERNAME, Password=$PASSWORD"
    fi
}

# Deploy Admin UI
deploy_admin_ui() {
    log_info "Deploying Admin UI with $DEPLOYMENT_TYPE configuration..."
    
    local VALUES_FILE=""
    local EXTRA_ARGS=""
    
    case $DEPLOYMENT_TYPE in
        "ingress")
            VALUES_FILE="examples/values/admin-ui-ingress.yaml"
            EXTRA_ARGS="--set ingress.hosts[0].host=$DOMAIN --set ingress.tls[0].hosts[0]=$DOMAIN --set config.serverName=$DOMAIN"
            ;;
        "loadbalancer")
            VALUES_FILE="examples/values/admin-ui-loadbalancer.yaml"
            ;;
        "nodeport")
            EXTRA_ARGS="--set service.type=NodePort --set service.nodePort=30080 --set ingress.enabled=false"
            ;;
        *)
            log_error "Invalid deployment type: $DEPLOYMENT_TYPE. Use: ingress, loadbalancer, or nodeport"
            exit 1
            ;;
    esac
    
    # Build helm command
    local HELM_CMD="helm upgrade --install admin-ui charts/admin-ui --namespace $NAMESPACE"
    
    if [[ -n "$VALUES_FILE" && -f "$VALUES_FILE" ]]; then
        HELM_CMD="$HELM_CMD --values $VALUES_FILE"
    fi
    
    if [[ -n "$EXTRA_ARGS" ]]; then
        HELM_CMD="$HELM_CMD $EXTRA_ARGS"
    fi
    
    HELM_CMD="$HELM_CMD --wait --timeout=300s"
    
    # Execute deployment
    eval $HELM_CMD
    
    log_success "Admin UI deployed successfully"
}

# Get access information
get_access_info() {
    log_info "Getting access information..."
    
    echo ""
    echo "📋 Admin UI Access Information:"
    echo "================================"
    
    case $DEPLOYMENT_TYPE in
        "ingress")
            echo "🌐 URL: https://$DOMAIN"
            echo "🔒 Authentication: Basic Auth (see credentials above)"
            echo ""
            echo "🔍 Check Ingress status:"
            echo "   kubectl get ingress admin-ui -n $NAMESPACE"
            echo ""
            echo "📜 Check certificate status:"
            echo "   kubectl get certificate mimir-admin-tls -n $NAMESPACE"
            ;;
        "loadbalancer")
            echo "🌐 Getting LoadBalancer IP..."
            local LB_IP
            LB_IP=$(kubectl get svc admin-ui -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
            if [[ "$LB_IP" == "pending" || -z "$LB_IP" ]]; then
                LB_IP=$(kubectl get svc admin-ui -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
            fi
            echo "🌐 URL: http://$LB_IP"
            echo ""
            echo "🔍 Check LoadBalancer status:"
            echo "   kubectl get svc admin-ui -n $NAMESPACE"
            ;;
        "nodeport")
            local NODE_IP
            NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' || kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
            echo "🌐 URL: http://$NODE_IP:30080"
            echo ""
            echo "🔍 Check NodePort service:"
            echo "   kubectl get svc admin-ui -n $NAMESPACE"
            ;;
    esac
    
    echo ""
    echo "🔍 Check pod status:"
    echo "   kubectl get pods -l app.kubernetes.io/name=admin-ui -n $NAMESPACE"
    echo ""
    echo "📜 View logs:"
    echo "   kubectl logs -l app.kubernetes.io/name=admin-ui -n $NAMESPACE"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment..."
    
    # Check pods
    local READY_PODS
    READY_PODS=$(kubectl get pods -l app.kubernetes.io/name=admin-ui -n "$NAMESPACE" -o jsonpath='{.items[*].status.containerStatuses[*].ready}' | tr ' ' '\n' | grep -c true || true)
    local TOTAL_PODS
    TOTAL_PODS=$(kubectl get pods -l app.kubernetes.io/name=admin-ui -n "$NAMESPACE" --no-headers | wc -l)
    
    if [[ "$READY_PODS" -eq "$TOTAL_PODS" && "$TOTAL_PODS" -gt 0 ]]; then
        log_success "All $TOTAL_PODS Admin UI pods are ready!"
    else
        log_warning "$READY_PODS/$TOTAL_PODS pods are ready. Some pods may still be starting."
    fi
    
    # Check service
    if kubectl get svc admin-ui -n "$NAMESPACE" &>/dev/null; then
        log_success "Admin UI service is created"
    else
        log_error "Admin UI service not found"
    fi
    
    # Check ingress (if enabled)
    if [[ "$DEPLOYMENT_TYPE" == "ingress" ]]; then
        if kubectl get ingress admin-ui -n "$NAMESPACE" &>/dev/null; then
            log_success "Admin UI ingress is created"
        else
            log_warning "Admin UI ingress not found"
        fi
    fi
}

# Print usage
print_usage() {
    echo "Usage: $0 [deployment-type] [domain] [namespace]"
    echo ""
    echo "Deployment Types:"
    echo "  ingress      - Deploy with Ingress (recommended for production)"
    echo "  loadbalancer - Deploy with LoadBalancer service (cloud environments)"
    echo "  nodeport     - Deploy with NodePort service (development/testing)"
    echo ""
    echo "Examples:"
    echo "  $0 ingress mimir-admin.mycompany.com production"
    echo "  $0 loadbalancer '' staging"
    echo "  $0 nodeport"
    echo ""
}

# Main execution
main() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        print_usage
        exit 0
    fi
    
    echo "🚀 Starting Admin UI deployment"
    echo "==============================="
    
    check_prerequisites
    
    # Create namespace if it doesn't exist
    if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
        log_info "Creating namespace: $NAMESPACE"
        kubectl create namespace "$NAMESPACE"
    fi
    
    if [[ "$DEPLOYMENT_TYPE" == "ingress" ]]; then
        create_basic_auth
    fi
    
    deploy_admin_ui
    verify_deployment
    get_access_info
    
    echo ""
    log_success "Admin UI deployment completed successfully!"
    echo ""
    echo "🎉 Your Mimir Edge Enforcement Admin UI is ready!"
}

# Run main function
main "$@"
