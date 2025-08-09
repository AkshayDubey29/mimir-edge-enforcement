#!/bin/bash

# 🚀 Deploy Mimir Edge Enforcement Admin UI with AWS ALB
# Domain: mimir-edge-enforcement.vzone1.kr.couwatchdev.net

set -euo pipefail

# Configuration
NAMESPACE=${NAMESPACE:-mimir-edge-enforcement}
DOMAIN=${DOMAIN:-mimir-edge-enforcement.vzone1.kr.couwatchdev.net}
CERT_ARN=${CERT_ARN:-arn:aws:acm:ap-northeast-2:138978013424:certificate/7b1c00f5-19ee-4e6c-9ca5-b30679ea6043}
VALUES_FILE=${VALUES_FILE:-examples/values/admin-ui-aws-alb.yaml}

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
    exit 1
}

success() {
    echo -e "${GREEN}✅ SUCCESS:${NC} $1"
}

usage() {
    cat << EOF
🚀 Deploy Mimir Edge Enforcement Admin UI with AWS ALB

Usage: $0 [options]

Options:
  --namespace NAMESPACE     Kubernetes namespace (default: mimir-edge-enforcement)
  --domain DOMAIN          Domain name (default: mimir-edge-enforcement.vzone1.kr.couwatchdev.net)
  --cert-arn ARN           AWS ACM certificate ARN
  --values-file FILE       Helm values file (default: examples/values/admin-ui-aws-alb.yaml)
  --dry-run               Show what would be deployed without actually deploying
  --help                  Show this help message

Environment Variables:
  NAMESPACE=$NAMESPACE
  DOMAIN=$DOMAIN
  CERT_ARN=$CERT_ARN
  VALUES_FILE=$VALUES_FILE

Examples:
  $0                                    # Deploy with defaults
  $0 --domain myapp.example.com         # Custom domain
  $0 --dry-run                         # Preview deployment
EOF
}

# Parse command line arguments
DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --cert-arn)
            CERT_ARN="$2"
            shift 2
            ;;
        --values-file)
            VALUES_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

log "🚀 Deploying Mimir Edge Enforcement Admin UI"
echo "📊 Configuration:"
echo "  Namespace: $NAMESPACE"
echo "  Domain: $DOMAIN"
echo "  Certificate ARN: $CERT_ARN"
echo "  Values File: $VALUES_FILE"
echo "  Dry Run: $DRY_RUN"
echo

# Verify prerequisites
log "🔍 Checking prerequisites..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    error "kubectl is not installed or not in PATH"
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    error "helm is not installed or not in PATH"
fi

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    warn "Namespace '$NAMESPACE' does not exist. Creating it..."
    if [[ "$DRY_RUN" == "false" ]]; then
        kubectl create namespace "$NAMESPACE"
        success "Created namespace '$NAMESPACE'"
    else
        echo "  [DRY-RUN] Would create namespace '$NAMESPACE'"
    fi
fi

# Check if values file exists
if [[ ! -f "$VALUES_FILE" ]]; then
    error "Values file '$VALUES_FILE' not found"
fi

# Check AWS Load Balancer Controller
log "🔍 Checking AWS Load Balancer Controller..."
if ! kubectl get deployment aws-load-balancer-controller -n kube-system &> /dev/null; then
    warn "AWS Load Balancer Controller not found in kube-system namespace"
    warn "Make sure it's installed for ALB Ingress to work"
fi

# Verify RLS is deployed (Admin UI needs it)
log "🔍 Checking RLS deployment..."
if ! kubectl get deployment mimir-rls -n "$NAMESPACE" &> /dev/null; then
    warn "RLS deployment not found in '$NAMESPACE' namespace"
    warn "Admin UI requires RLS to be deployed first"
    echo "  Deploy RLS with: helm install mimir-rls charts/mimir-rls -n $NAMESPACE"
fi

# Deploy Admin UI
log "🚀 Deploying Admin UI with AWS ALB..."

if [[ "$DRY_RUN" == "true" ]]; then
    echo "🔍 DRY-RUN: Would execute the following Helm command:"
    echo "helm install mimir-edge-enforcement-admin-ui charts/admin-ui \\"
    echo "  --namespace $NAMESPACE \\"
    echo "  --values $VALUES_FILE \\"
    echo "  --set ingress.hosts[0].host=$DOMAIN \\"
    echo "  --set ingress.annotations.\"alb\.ingress\.kubernetes\.io/certificate-arn\"=$CERT_ARN \\"
    echo "  --set config.serverName=$DOMAIN \\"
    echo "  --wait --timeout=300s"
    echo
    echo "🔍 Generated values preview:"
    helm template mimir-edge-enforcement-admin-ui charts/admin-ui \
        --namespace "$NAMESPACE" \
        --values "$VALUES_FILE" \
        --set "ingress.hosts[0].host=$DOMAIN" \
        --set "ingress.annotations.alb\.ingress\.kubernetes\.io/certificate-arn=$CERT_ARN" \
        --set "config.serverName=$DOMAIN" | head -50
    echo "... (truncated for brevity)"
else
    helm install mimir-edge-enforcement-admin-ui charts/admin-ui \
        --namespace "$NAMESPACE" \
        --values "$VALUES_FILE" \
        --set "ingress.hosts[0].host=$DOMAIN" \
        --set "ingress.annotations.alb\.ingress\.kubernetes\.io/certificate-arn=$CERT_ARN" \
        --set "config.serverName=$DOMAIN" \
        --wait --timeout=300s

    success "Admin UI deployed successfully!"
fi

# Verify deployment
log "🔍 Verifying deployment..."

if [[ "$DRY_RUN" == "false" ]]; then
    # Wait for pods to be ready
    kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=mimir-edge-enforcement-admin-ui -n "$NAMESPACE" --timeout=120s

    # Check deployment status
    kubectl get pods -l app.kubernetes.io/name=mimir-edge-enforcement-admin-ui -n "$NAMESPACE"
    kubectl get services -l app.kubernetes.io/name=mimir-edge-enforcement-admin-ui -n "$NAMESPACE"
    kubectl get ingress -n "$NAMESPACE"

    # Get ALB URL
    log "📝 Getting ALB information..."
    INGRESS_NAME=$(kubectl get ingress -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$INGRESS_NAME" ]]; then
        echo "Ingress: $INGRESS_NAME"
        ALB_URL=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
        echo "ALB URL: $ALB_URL"
    fi

    success "✅ Deployment verification completed!"
else
    echo "  [DRY-RUN] Would verify deployment status"
fi

# Display access information
echo
echo "🎯 Access Information:"
echo "  Domain: https://$DOMAIN"
echo "  Health Check: https://$DOMAIN/healthz"
echo "  API Endpoint: https://$DOMAIN/api/tenants"
echo

if [[ "$DRY_RUN" == "false" ]]; then
    echo "📋 Next Steps:"
    echo "  1. Wait for ALB to be provisioned (~2-3 minutes)"
    echo "  2. Update your DNS to point $DOMAIN to the ALB"
    echo "  3. Test access: curl -k https://$DOMAIN/healthz"
    echo "  4. Access Admin UI: https://$DOMAIN"
    echo
    echo "🔍 Troubleshooting:"
    echo "  kubectl logs -l app.kubernetes.io/name=mimir-edge-enforcement-admin-ui -n $NAMESPACE"
    echo "  kubectl describe ingress -n $NAMESPACE"
    echo "  kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
else
    echo "📋 To actually deploy:"
    echo "  $0 $(echo "$@" | sed 's/--dry-run//')"
fi

echo
success "🎉 Admin UI AWS ALB deployment completed!"
