#!/bin/bash

# 🔍 Enable Debug Logging for RLS Service
# This script helps enable detailed logging to see what RLS is returning

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
🔍 Enable Debug Logging for RLS Service

Usage: $0 [options]

Options:
  --enable-debug       Enable debug level logging (default)
  --enable-info        Enable info level logging
  --show-logs          Show recent RLS logs
  --follow-logs        Follow RLS logs in real-time
  --namespace NS       Kubernetes namespace (default: mimir-edge-enforcement)
  --help               Show this help message

Examples:
  $0                   # Enable debug logging and show recent logs
  $0 --follow-logs     # Follow logs in real-time
  $0 --enable-info     # Set to info level (less verbose)
EOF
}

# Parse command line arguments
ENABLE_DEBUG=true
ENABLE_INFO=false
SHOW_LOGS=false
FOLLOW_LOGS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --enable-debug)
            ENABLE_DEBUG=true
            ENABLE_INFO=false
            shift
            ;;
        --enable-info)
            ENABLE_DEBUG=false
            ENABLE_INFO=true
            shift
            ;;
        --show-logs)
            SHOW_LOGS=true
            shift
            ;;
        --follow-logs)
            FOLLOW_LOGS=true
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

log "🔍 Configuring RLS logging in namespace: $NAMESPACE"
echo

# Check if RLS deployment exists
if ! kubectl get deployment mimir-rls -n "$NAMESPACE" &> /dev/null; then
    error "RLS deployment 'mimir-rls' not found in namespace '$NAMESPACE'"
    exit 1
fi

# Set log level
if [[ "$ENABLE_DEBUG" == "true" ]]; then
    LOG_LEVEL="debug"
    log "📋 Enabling DEBUG level logging for detailed API response information"
elif [[ "$ENABLE_INFO" == "true" ]]; then
    LOG_LEVEL="info"
    log "📋 Enabling INFO level logging"
else
    LOG_LEVEL="info"
    log "📋 Using default INFO level logging"
fi

# Update the deployment to set log level
log "🔧 Updating RLS deployment with log-level=$LOG_LEVEL..."

kubectl patch deployment mimir-rls -n "$NAMESPACE" -p "{
  \"spec\": {
    \"template\": {
      \"spec\": {
        \"containers\": [{
          \"name\": \"rls\",
          \"args\": [
            \"--log-level=$LOG_LEVEL\",
            \"--ext-authz-port=8080\",
            \"--rate-limit-port=8081\",
            \"--admin-port=8082\",
            \"--metrics-port=9090\"
          ]
        }]
      }
    }
  }
}"

# Wait for rollout to complete
log "⏳ Waiting for RLS rollout to complete..."
kubectl rollout status deployment/mimir-rls -n "$NAMESPACE" --timeout=120s

success "RLS deployment updated with log-level=$LOG_LEVEL"
echo

# Show what logs to expect
log "💡 Expected Log Messages:"
echo
echo "📊 API Response Logs (when accessing Admin UI):"
echo "   - 'overview API response' with tenant counts and request stats"
echo "   - 'tenants API response' with detailed tenant information"
echo "   - 'NO TENANTS FOUND - this explains zero active tenants!' if no tenants"
echo
echo "🔄 Tenant Loading Logs (from overrides-sync):"
echo "   - 'RLS: creating new tenant from overrides-sync'"
echo "   - 'RLS: received tenant limits from overrides-sync' with full limit details"
echo "   - 'RLS: created samples bucket' for each tenant"
echo
echo "⏰ Periodic Status Logs (every minute):"
echo "   - 'RLS: periodic tenant status - TENANTS LOADED' if tenants exist"
echo "   - 'RLS: periodic tenant status - NO TENANTS (check overrides-sync)' if empty"
echo

# Show recent logs if requested or by default
if [[ "$SHOW_LOGS" == "true" ]] || [[ "$FOLLOW_LOGS" == "false" && "$1" != "--enable-info" && "$1" != "--enable-debug" ]]; then
    log "📄 Recent RLS logs (last 20 lines):"
    echo "----------------------------------------"
    kubectl logs -l app.kubernetes.io/name=mimir-rls -n "$NAMESPACE" --tail=20 --timestamps || warn "Could not retrieve logs"
    echo "----------------------------------------"
    echo
fi

# Follow logs if requested
if [[ "$FOLLOW_LOGS" == "true" ]]; then
    log "📺 Following RLS logs in real-time (Ctrl+C to stop):"
    echo "=========================================="
    kubectl logs -l app.kubernetes.io/name=mimir-rls -n "$NAMESPACE" -f --timestamps
fi

# Show helpful commands
log "🛠️  Helpful Commands:"
echo
echo "📄 View recent logs:"
echo "   kubectl logs -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE --tail=50"
echo
echo "📺 Follow logs in real-time:"
echo "   kubectl logs -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE -f"
echo
echo "🔍 Filter for specific log types:"
echo "   kubectl logs -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE | grep 'API response'"
echo "   kubectl logs -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE | grep 'tenant'"
echo "   kubectl logs -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE | grep 'overrides-sync'"
echo
echo "🌐 Test API endpoints:"
echo "   kubectl port-forward svc/mimir-rls 8082:8082 -n $NAMESPACE &"
echo "   curl http://localhost:8082/api/overview"
echo "   curl http://localhost:8082/api/tenants"
echo

success "🎉 RLS debug logging configured! Check logs to see API responses and tenant loading."
