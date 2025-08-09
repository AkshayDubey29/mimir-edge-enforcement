#!/bin/bash
set -euo pipefail

# Production Deployment Script for mimir-edge-enforcement
# Complete one-shot deployment of entire system including Admin UI
# Usage: ./scripts/deploy-production.sh [namespace] [domain] [admin-domain] [deployment-mode]

NAMESPACE=${1:-mimir-edge-enforcement}
DOMAIN=${2:-your-domain.com}
ADMIN_DOMAIN=${3:-mimir-admin.your-domain.com}
DEPLOYMENT_MODE=${4:-complete}  # Options: complete, core-only, admin-only

# Environment variables
GITHUB_USERNAME=${GITHUB_USERNAME:-""}
GITHUB_TOKEN=${GITHUB_TOKEN:-""}
MIMIR_NAMESPACE=${MIMIR_NAMESPACE:-"mimir"}
MIMIR_CONFIGMAP=${MIMIR_CONFIGMAP:-"mimir-overrides"}
VALUES_FILE=${VALUES_FILE:-"examples/values/production.yaml"}

echo "🚀 Deploying mimir-edge-enforcement to production"
echo "📦 Namespace: $NAMESPACE"
echo "🌐 Main Domain: $DOMAIN"
echo "🎨 Admin UI Domain: $ADMIN_DOMAIN"
echo "🔧 Deployment Mode: $DEPLOYMENT_MODE"
echo "📋 Values File: $VALUES_FILE"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

log_step() {
    echo -e "${PURPLE}🔧 $1${NC}"
}

log_highlight() {
    echo -e "${CYAN}🌟 $1${NC}"
}

# Prerequisites check
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
    
    # Check if values file exists
    if [[ ! -f "$VALUES_FILE" ]]; then
        log_error "Values file not found: $VALUES_FILE"
        log_info "Available values files:"
        find examples/values/ -name "*.yaml" -type f | sed 's/^/  - /'
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Create namespace and setup
setup_namespace() {
    log_step "Setting up namespace: $NAMESPACE"
    
    # Create namespace if it doesn't exist
    if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
        kubectl create namespace "$NAMESPACE"
        log_success "Created namespace: $NAMESPACE"
    else
        log_info "Namespace $NAMESPACE already exists"
    fi
    
    # Label namespace for network policies
    kubectl label namespace "$NAMESPACE" name="$NAMESPACE" --overwrite
    log_success "Namespace labeled for network policies"
}

# Create image pull secrets
create_image_pull_secrets() {
    if [[ -n "$GITHUB_USERNAME" && -n "$GITHUB_TOKEN" ]]; then
        log_step "Creating image pull secrets..."
        
        kubectl create secret docker-registry ghcr-secret \
            --docker-server=ghcr.io \
            --docker-username="$GITHUB_USERNAME" \
            --docker-password="$GITHUB_TOKEN" \
            --docker-email="$GITHUB_USERNAME@users.noreply.github.com" \
            --namespace="$NAMESPACE" \
            --dry-run=client -o yaml | kubectl apply -f -
        
        log_success "Image pull secret created"
    else
        log_warning "GITHUB_USERNAME or GITHUB_TOKEN not set. Skipping image pull secret creation."
        log_info "If using private registry, set these environment variables:"
        log_info "  export GITHUB_USERNAME=your-username"
        log_info "  export GITHUB_TOKEN=your-token"
    fi
}

# Create basic auth secret for Admin UI
create_admin_auth() {
    log_step "Creating Admin UI authentication..."
    
    # Generate random password
    local PASSWORD=$(openssl rand -base64 16 | tr -d '/' | tr '+' '-')
    local USERNAME="admin"
    
    # Check if htpasswd is available
    if command -v htpasswd &> /dev/null; then
        local HTPASSWD=$(htpasswd -nb "$USERNAME" "$PASSWORD")
    else
        # Fallback to Python for htpasswd generation
        local HTPASSWD=$(python3 -c "
import crypt
import getpass
password = '$PASSWORD'
salt = crypt.mksalt(crypt.METHOD_SHA512)
hashed = crypt.crypt(password, salt)
print(f'$USERNAME:{hashed}')
")
    fi
    
    # Create or update secret
    kubectl create secret generic admin-ui-auth \
        --from-literal=auth="$HTPASSWD" \
        --namespace="$NAMESPACE" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "Admin UI authentication configured"
    echo ""
    log_highlight "🔐 Admin UI Credentials (SAVE THESE!):"
    echo "   Username: $USERNAME"
    echo "   Password: $PASSWORD"
    echo "   URL: https://$ADMIN_DOMAIN"
    echo ""
    
    # Save credentials to file
    cat > "${NAMESPACE}-admin-credentials.txt" << EOF
Mimir Edge Enforcement Admin UI Credentials
==========================================
Namespace: $NAMESPACE
URL: https://$ADMIN_DOMAIN
Username: $USERNAME
Password: $PASSWORD
Generated: $(date)

Keep these credentials secure!
EOF
    log_info "Credentials also saved to: ${NAMESPACE}-admin-credentials.txt"
}

# Deploy core components (RLS, Overrides-Sync, Envoy)
deploy_core_components() {
    log_step "Deploying core components..."
    
    # Create values override for dynamic configuration
    local TEMP_VALUES=$(mktemp)
    cat > "$TEMP_VALUES" << EOF
# Dynamic overrides for production deployment
global:
  cluster:
    name: "production"
  imageCredentials:
    username: "$GITHUB_USERNAME"

# Core components
rls:
  mimir:
    namespace: "$MIMIR_NAMESPACE"
    overridesConfigMap: "$MIMIR_CONFIGMAP"

overridesSync:
  mimir:
    namespace: "$MIMIR_NAMESPACE"
    overridesConfigMap: "$MIMIR_CONFIGMAP"
  rls:
    host: "mimir-rls.$NAMESPACE.svc.cluster.local"

envoy:
  mimir:
    distributorHost: "mimir-distributor.$MIMIR_NAMESPACE.svc.cluster.local"
  rls:
    host: "mimir-rls.$NAMESPACE.svc.cluster.local"
EOF
    
    # Deploy RLS
    log_info "Deploying RLS (Rate Limiting Service)..."
    helm upgrade --install mimir-rls charts/mimir-rls \
        --namespace="$NAMESPACE" \
        --values="$VALUES_FILE" \
        --values="$TEMP_VALUES" \
        --wait --timeout=300s
    log_success "RLS deployed successfully"
    
    # Deploy Overrides Sync Controller
    log_info "Deploying Overrides Sync Controller..."
    helm upgrade --install overrides-sync charts/overrides-sync \
        --namespace="$NAMESPACE" \
        --values="$VALUES_FILE" \
        --values="$TEMP_VALUES" \
        --wait --timeout=300s
    log_success "Overrides Sync Controller deployed successfully"
    
    # Deploy Envoy
    log_info "Deploying Envoy Proxy..."
    helm upgrade --install mimir-envoy charts/envoy \
        --namespace="$NAMESPACE" \
        --values="$VALUES_FILE" \
        --values="$TEMP_VALUES" \
        --wait --timeout=300s
    log_success "Envoy Proxy deployed successfully"
    
    # Cleanup
    rm -f "$TEMP_VALUES"
}

# Deploy Admin UI
deploy_admin_ui() {
    log_step "Deploying Admin UI..."
    
    # Create values override for Admin UI
    local TEMP_VALUES=$(mktemp)
    cat > "$TEMP_VALUES" << EOF
# Dynamic overrides for Admin UI
config:
  apiBaseUrl: "http://mimir-rls.$NAMESPACE.svc.cluster.local:8082"
  serverName: "$ADMIN_DOMAIN"

ingress:
  hosts:
    - host: "$ADMIN_DOMAIN"
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: mimir-admin-tls
      hosts:
        - "$ADMIN_DOMAIN"

networkPolicy:
  egress:
    - to:
      - namespaceSelector:
          matchLabels:
            name: "$NAMESPACE"
      ports:
      - protocol: TCP
        port: 8082
    - to: []  # Allow DNS
      ports:
      - protocol: UDP
        port: 53
EOF
    
    # Deploy Admin UI
    log_info "Deploying Admin UI..."
    helm upgrade --install admin-ui charts/admin-ui \
        --namespace="$NAMESPACE" \
        --values="$VALUES_FILE" \
        --values="$TEMP_VALUES" \
        --wait --timeout=300s
    log_success "Admin UI deployed successfully"
    
    # Cleanup
    rm -f "$TEMP_VALUES"
}

# Verify all deployments
verify_deployments() {
    log_step "Verifying deployments..."
    
    local ALL_READY=true
    
    # Check each component
    for component in mimir-rls overrides-sync mimir-envoy; do
        local READY_PODS=$(kubectl get pods -l "app.kubernetes.io/name=$component" -n "$NAMESPACE" -o jsonpath='{.items[*].status.containerStatuses[*].ready}' | tr ' ' '\n' | grep -c true || true)
        local TOTAL_PODS=$(kubectl get pods -l "app.kubernetes.io/name=$component" -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l || echo "0")
        
        if [[ "$READY_PODS" -eq "$TOTAL_PODS" && "$TOTAL_PODS" -gt 0 ]]; then
            log_success "$component: $READY_PODS/$TOTAL_PODS pods ready"
        else
            log_warning "$component: $READY_PODS/$TOTAL_PODS pods ready"
            ALL_READY=false
        fi
    done
    
    # Check Admin UI if deployed
    if [[ "$DEPLOYMENT_MODE" == "complete" || "$DEPLOYMENT_MODE" == "admin-only" ]]; then
        local ADMIN_READY=$(kubectl get pods -l "app.kubernetes.io/name=admin-ui" -n "$NAMESPACE" -o jsonpath='{.items[*].status.containerStatuses[*].ready}' | tr ' ' '\n' | grep -c true || true)
        local ADMIN_TOTAL=$(kubectl get pods -l "app.kubernetes.io/name=admin-ui" -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l || echo "0")
        
        if [[ "$ADMIN_READY" -eq "$ADMIN_TOTAL" && "$ADMIN_TOTAL" -gt 0 ]]; then
            log_success "admin-ui: $ADMIN_READY/$ADMIN_TOTAL pods ready"
        else
            log_warning "admin-ui: $ADMIN_READY/$ADMIN_TOTAL pods ready"
            ALL_READY=false
        fi
    fi
    
    if [[ "$ALL_READY" == "true" ]]; then
        log_success "All components are ready!"
    else
        log_warning "Some components are still starting. This is normal for initial deployment."
    fi
}

# Display access information
show_access_info() {
    log_highlight "🎉 Deployment Summary"
    echo "====================="
    echo ""
    
    # Core components info
    echo "📦 Core Components:"
    echo "   Namespace: $NAMESPACE"
    echo "   RLS Service: mimir-rls.$NAMESPACE.svc.cluster.local:8080"
    echo "   Envoy Proxy: mimir-envoy.$NAMESPACE.svc.cluster.local:8080"
    echo ""
    
    # Admin UI info
    if [[ "$DEPLOYMENT_MODE" == "complete" || "$DEPLOYMENT_MODE" == "admin-only" ]]; then
        echo "🎨 Admin UI Access:"
        echo "   URL: https://$ADMIN_DOMAIN"
        echo "   Credentials: See ${NAMESPACE}-admin-credentials.txt"
        echo ""
        
        # Check Ingress status
        if kubectl get ingress admin-ui -n "$NAMESPACE" &>/dev/null; then
            local INGRESS_IP=$(kubectl get ingress admin-ui -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
            if [[ "$INGRESS_IP" == "pending" || -z "$INGRESS_IP" ]]; then
                INGRESS_IP=$(kubectl get ingress admin-ui -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
            fi
            echo "   Ingress IP: $INGRESS_IP"
        fi
        echo ""
    fi
    
    # Monitoring commands
    echo "📊 Monitoring Commands:"
    echo "   Check pods:     kubectl get pods -n $NAMESPACE"
    echo "   Check services: kubectl get svc -n $NAMESPACE"
    echo "   Check ingress:  kubectl get ingress -n $NAMESPACE"
    echo "   View RLS logs:  kubectl logs -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE"
    echo "   Port forward:   kubectl port-forward svc/mimir-rls 9090:9090 -n $NAMESPACE"
    echo ""
    
    # Health check URLs
    echo "🔍 Health Check URLs (via port-forward):"
    echo "   RLS Health:     http://localhost:8082/health"
    echo "   RLS Metrics:    http://localhost:9090/metrics"
    echo "   RLS Admin API:  http://localhost:8082/api/tenants"
    echo ""
    
    # Next steps
    echo "🚀 Next Steps:"
    echo "1. Update your DNS to point $ADMIN_DOMAIN to the Ingress IP"
    echo "2. Configure your monitoring to scrape metrics from $NAMESPACE"
    echo "3. Update your Alloy/Prometheus config to send traffic through Envoy"
    echo "4. Test rate limiting with sample workloads"
    echo ""
    
    log_success "mimir-edge-enforcement is ready for production!"
}

# Cleanup function for exit
cleanup() {
    log_info "Cleaning up temporary files..."
    # Remove any temporary files if they exist
    rm -f /tmp/mimir-edge-*.yaml 2>/dev/null || true
}

# Handle errors
error_handler() {
    log_error "Deployment failed on line $1"
    cleanup
    exit 1
}

# Print usage
print_usage() {
    echo "Usage: $0 [namespace] [domain] [admin-domain] [deployment-mode]"
    echo ""
    echo "Arguments:"
    echo "  namespace       Kubernetes namespace (default: mimir-edge-enforcement)"
    echo "  domain          Main domain for your services (default: your-domain.com)"
    echo "  admin-domain    Domain for Admin UI (default: mimir-admin.your-domain.com)"
    echo "  deployment-mode Deployment mode (default: complete)"
    echo ""
    echo "Deployment Modes:"
    echo "  complete    - Deploy all components including Admin UI (default)"
    echo "  core-only   - Deploy only core components (RLS, Envoy, Overrides-Sync)"
    echo "  admin-only  - Deploy only Admin UI (requires core components)"
    echo ""
    echo "Environment Variables:"
    echo "  GITHUB_USERNAME    - GitHub username for image pull secrets"
    echo "  GITHUB_TOKEN       - GitHub token for image pull secrets"
    echo "  MIMIR_NAMESPACE    - Namespace where Mimir is deployed (default: mimir)"
    echo "  MIMIR_CONFIGMAP    - Name of Mimir overrides ConfigMap (default: mimir-overrides)"
    echo "  VALUES_FILE        - Custom values file (default: examples/values/production.yaml)"
    echo ""
    echo "Examples:"
    echo "  # Complete deployment"
    echo "  $0 production mycompany.com mimir-admin.mycompany.com"
    echo ""
    echo "  # Core components only"
    echo "  $0 staging staging.mycompany.com '' core-only"
    echo ""
    echo "  # Admin UI only (after core is deployed)"
    echo "  $0 production mycompany.com admin.mycompany.com admin-only"
    echo ""
    echo "  # With custom values"
    echo "  VALUES_FILE=my-custom-values.yaml $0"
    echo ""
}

# Main execution
main() {
    # Handle help
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        print_usage
        exit 0
    fi
    
    # Set error handling
    trap 'error_handler $LINENO' ERR
    trap cleanup EXIT
    
    echo "🚀 Starting complete mimir-edge-enforcement deployment"
    echo "====================================================="
    
    # Validate deployment mode
    case "$DEPLOYMENT_MODE" in
        "complete"|"core-only"|"admin-only")
            log_info "Deployment mode: $DEPLOYMENT_MODE"
            ;;
        *)
            log_error "Invalid deployment mode: $DEPLOYMENT_MODE"
            log_info "Valid modes: complete, core-only, admin-only"
            exit 1
            ;;
    esac
    
    # Run deployment steps
    check_prerequisites
    setup_namespace
    create_image_pull_secrets
    
    # Deploy based on mode
    case "$DEPLOYMENT_MODE" in
        "complete")
            create_admin_auth
            deploy_core_components
            deploy_admin_ui
            ;;
        "core-only")
            deploy_core_components
            ;;
        "admin-only")
            create_admin_auth
            deploy_admin_ui
            ;;
    esac
    
    verify_deployments
    show_access_info
    
    echo ""
    log_success "Deployment completed successfully! 🎉"
}

# Run main function with all arguments
main "$@"