#!/bin/bash
set -euo pipefail

# Production Deployment Script for mimir-edge-enforcement
# Usage: ./scripts/deploy-production.sh [namespace] [domain]

NAMESPACE=${1:-mimir-edge-enforcement}
DOMAIN=${2:-your-domain.com}
GITHUB_USERNAME=${GITHUB_USERNAME:-""}
GITHUB_TOKEN=${GITHUB_TOKEN:-""}

echo "🚀 Deploying mimir-edge-enforcement to production"
echo "📦 Namespace: $NAMESPACE"
echo "🌐 Domain: $DOMAIN"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
    
    log_success "Prerequisites check passed"
}

# Create namespace
create_namespace() {
    log_info "Creating namespace: $NAMESPACE"
    
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_warning "Namespace $NAMESPACE already exists"
    else
        kubectl create namespace "$NAMESPACE"
        log_success "Namespace $NAMESPACE created"
    fi
}

# Create image pull secret
create_image_pull_secret() {
    if [[ -n "$GITHUB_USERNAME" && -n "$GITHUB_TOKEN" ]]; then
        log_info "Creating image pull secret..."
        
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
        log_warning "If using private registry, create the secret manually."
    fi
}

# Deploy RLS
deploy_rls() {
    log_info "Deploying RLS (Rate Limiting Service)..."
    
    cat > /tmp/rls-values.yaml <<EOF
replicaCount: 3
image:
  repository: ghcr.io/akshaydubey29/mimir-rls
  tag: "latest"
  pullPolicy: IfNotPresent
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi
hpa:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
pdb:
  enabled: true
  minAvailable: 2
securityContext:
  runAsNonRoot: true
  runAsUser: 65532
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
service:
  type: ClusterIP
mimir:
  namespace: "mimir"
  overridesConfigMap: "mimir-overrides"
defaultSamplesPerSecond: 0
defaultBurstPercent: 0
maxBodyBytes: 0
log:
  level: "info"
  format: "json"
networkPolicy:
  enabled: true
EOF

    if [[ -n "$GITHUB_USERNAME" ]]; then
        echo "imagePullSecrets:" >> /tmp/rls-values.yaml
        echo "  - name: ghcr-secret" >> /tmp/rls-values.yaml
    fi
    
    helm upgrade --install mimir-rls charts/mimir-rls \
        --namespace "$NAMESPACE" \
        --values /tmp/rls-values.yaml \
        --wait --timeout=300s
        
    log_success "RLS deployed successfully"
}

# Deploy Overrides Sync
deploy_overrides_sync() {
    log_info "Deploying Overrides Sync Controller..."
    
    cat > /tmp/sync-values.yaml <<EOF
replicaCount: 2
image:
  repository: ghcr.io/akshaydubey29/overrides-sync
  tag: "latest"
  pullPolicy: IfNotPresent
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi
mimir:
  namespace: "mimir"
  overridesConfigMap: "mimir-overrides"
rls:
  host: "mimir-rls.$NAMESPACE.svc.cluster.local"
  adminPort: "8082"
pollFallbackSeconds: 30
securityContext:
  runAsNonRoot: true
  runAsUser: 65532
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
serviceAccount:
  create: true
EOF

    if [[ -n "$GITHUB_USERNAME" ]]; then
        echo "imagePullSecrets:" >> /tmp/sync-values.yaml
        echo "  - name: ghcr-secret" >> /tmp/sync-values.yaml
    fi
    
    helm upgrade --install overrides-sync charts/overrides-sync \
        --namespace "$NAMESPACE" \
        --values /tmp/sync-values.yaml \
        --wait --timeout=300s
        
    log_success "Overrides Sync deployed successfully"
}

# Deploy Envoy
deploy_envoy() {
    log_info "Deploying Envoy Proxy..."
    
    cat > /tmp/envoy-values.yaml <<EOF
replicaCount: 3
image:
  repository: ghcr.io/akshaydubey29/mimir-envoy
  tag: "latest"
  pullPolicy: IfNotPresent
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 200m
    memory: 256Mi
hpa:
  enabled: true
  minReplicas: 3
  maxReplicas: 15
  targetCPUUtilizationPercentage: 80
pdb:
  enabled: true
  minAvailable: 2
service:
  type: ClusterIP
  port: 8080
mimir:
  distributorHost: "mimir-distributor.mimir.svc.cluster.local"
  distributorPort: 8080
rls:
  host: "mimir-rls.$NAMESPACE.svc.cluster.local"
  extAuthzPort: 8080
  rateLimitPort: 8081
extAuthz:
  maxRequestBytes: 4194304
  failureModeAllow: false
rateLimit:
  failureModeDeny: true
tenantHeader: "X-Scope-OrgID"
securityContext:
  runAsNonRoot: true
  runAsUser: 65532
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
EOF

    if [[ -n "$GITHUB_USERNAME" ]]; then
        echo "imagePullSecrets:" >> /tmp/envoy-values.yaml
        echo "  - name: ghcr-secret" >> /tmp/envoy-values.yaml
    fi
    
    helm upgrade --install mimir-envoy charts/envoy \
        --namespace "$NAMESPACE" \
        --values /tmp/envoy-values.yaml \
        --wait --timeout=300s
        
    log_success "Envoy deployed successfully"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment..."
    
    echo ""
    echo "📋 Deployment Status:"
    echo "===================="
    kubectl get pods -n "$NAMESPACE" -o wide
    echo ""
    kubectl get services -n "$NAMESPACE"
    echo ""
    
    # Check if all pods are ready
    local ready_pods
    ready_pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].status.containerStatuses[*].ready}' | tr ' ' '\n' | grep -c true || true)
    local total_pods
    total_pods=$(kubectl get pods -n "$NAMESPACE" --no-headers | wc -l)
    
    if [[ "$ready_pods" -eq "$total_pods" ]]; then
        log_success "All $total_pods pods are ready!"
    else
        log_warning "$ready_pods/$total_pods pods are ready. Some pods may still be starting."
    fi
}

# Print next steps
print_next_steps() {
    echo ""
    echo "🎉 Deployment completed!"
    echo ""
    echo "📋 Next Steps:"
    echo "=============="
    echo "1. Update your NGINX configuration:"
    echo "   upstream mimir_with_enforcement {"
    echo "       server mimir-envoy.$NAMESPACE.svc.cluster.local:8080;"
    echo "   }"
    echo ""
    echo "2. Test the deployment:"
    echo "   kubectl port-forward svc/mimir-rls 8082:8082 -n $NAMESPACE"
    echo "   curl http://localhost:8082/api/overview"
    echo ""
    echo "3. View logs:"
    echo "   kubectl logs -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE"
    echo "   kubectl logs -l app.kubernetes.io/name=overrides-sync -n $NAMESPACE"
    echo "   kubectl logs -l app.kubernetes.io/name=mimir-envoy -n $NAMESPACE"
    echo ""
    echo "4. Monitor metrics:"
    echo "   kubectl port-forward svc/mimir-rls 9090:9090 -n $NAMESPACE"
    echo "   curl http://localhost:9090/metrics"
    echo ""
    echo "🚀 Your mimir-edge-enforcement system is ready for production!"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary files..."
    rm -f /tmp/rls-values.yaml /tmp/sync-values.yaml /tmp/envoy-values.yaml
}

# Trap cleanup on exit
trap cleanup EXIT

# Main execution
main() {
    echo "🚀 Starting mimir-edge-enforcement production deployment"
    echo "================================================================"
    
    check_prerequisites
    create_namespace
    create_image_pull_secret
    deploy_rls
    deploy_overrides_sync
    deploy_envoy
    verify_deployment
    print_next_steps
    
    log_success "Deployment script completed successfully!"
}

# Run main function
main "$@"
