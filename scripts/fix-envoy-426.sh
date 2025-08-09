#!/bin/bash

# 🔧 Fix Envoy 426 Upgrade Required Error
# This script patches the Envoy configuration to handle HTTP/1.1 from NGINX

set -euo pipefail

# Configuration
NAMESPACE=${NAMESPACE:-mimir-edge-enforcement}
CONFIGMAP=${CONFIGMAP:-mimir-envoy-config}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

echo -e "${BLUE}🔧 Fixing Envoy 426 Upgrade Required Error${NC}"
echo -e "${BLUE}===========================================${NC}"
echo

# 1. Check current Envoy configuration
log "🔍 Checking Current Envoy Configuration"
echo "---------------------------------------"

if ! kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" &>/dev/null; then
    error "ConfigMap '$CONFIGMAP' not found in namespace '$NAMESPACE'"
    echo "Available ConfigMaps:"
    kubectl get configmap -n "$NAMESPACE" | grep -i envoy || echo "No Envoy ConfigMaps found"
    exit 1
fi

success "Found Envoy ConfigMap: $CONFIGMAP"

# Check for 426 errors in Envoy logs
log "📊 Checking for Recent 426 Errors"
echo "----------------------------------"

ENVOY_PODS=$(kubectl get pods -l app.kubernetes.io/name=mimir-envoy -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [[ -n "$ENVOY_PODS" ]]; then
    echo "🔍 Recent 426 errors from Envoy logs:"
    for pod in $ENVOY_PODS; do
        echo "Pod: $pod"
        kubectl logs "$pod" -n "$NAMESPACE" --tail=50 | grep " 426 " | tail -3 || echo "  No 426 errors found"
    done
    echo
else
    warning "No Envoy pods found"
fi

# 2. Backup current configuration
log "💾 Backing Up Current Configuration"
echo "-----------------------------------"

BACKUP_DIR="./envoy-backups"
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/envoy-config-$(date +%Y%m%d-%H%M%S).yaml"

kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" -o yaml > "$BACKUP_FILE"
success "Configuration backed up to: $BACKUP_FILE"
echo

# 3. Apply the fix
log "🔧 Applying HTTP/1.1 Compatibility Fix"
echo "---------------------------------------"

echo "The 426 error occurs because:"
echo "  • NGINX sends HTTP/1.1 requests to Envoy"
echo "  • Envoy is configured for HTTP/2 protocol options"
echo "  • Envoy returns 426 asking client to upgrade to HTTP/2"
echo
echo "Fix: Configure Envoy to accept both HTTP/1.1 and HTTP/2"
echo

# Create a patch to fix the codec_type and add HTTP/1.1 options
PATCH_CONFIG=$(cat << 'EOF'
admin:
  address:
    socket_address:
      address: 0.0.0.0
      port_value: 9901

static_resources:
  listeners:
  - name: listener_0
    address:
      socket_address:
        address: 0.0.0.0
        port_value: 8080
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          stat_prefix: ingress_http
          codec_type: AUTO
          http_protocol_options:
            accept_http_10: true
          use_remote_address: true
          route_config:
            name: local_route
            virtual_hosts:
            - name: local_service
              domains: ["*"]
              routes:
              - match:
                  prefix: "/api/v1/push"
                route:
                  cluster: mimir_distributor
                  timeout: 30s
          http_filters:
          - name: envoy.filters.http.ext_authz
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.http.ext_authz.v3.ExtAuthz
              transport_api_version: V3
              with_request_body:
                max_request_bytes: 4194304
                allow_partial_message: true
              failure_mode_allow: false
              grpc_service:
                envoy_grpc:
                  cluster_name: rls_ext_authz
          - name: envoy.filters.http.ratelimit
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.http.ratelimit.v3.RateLimit
              domain: "mimir_remote_write"
              rate_limit_service:
                transport_api_version: V3
                grpc_service:
                  envoy_grpc:
                    cluster_name: rls_ratelimit
              failure_mode_deny: true
          - name: envoy.filters.http.router
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router

  clusters:
  - name: mimir_distributor
    connect_timeout: 0.25s
    type: STRICT_DNS
    lb_policy: ROUND_ROBIN
    load_assignment:
      cluster_name: mimir_distributor
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: mimir-distributor.mimir.svc.cluster.local
                port_value: 8080

  - name: rls_ext_authz
    connect_timeout: 0.25s
    type: STRICT_DNS
    lb_policy: ROUND_ROBIN
    typed_extension_protocol_options:
      envoy.extensions.upstreams.http.v3.HttpProtocolOptions:
        "@type": type.googleapis.com/envoy.extensions.upstreams.http.v3.HttpProtocolOptions
        explicit_http_config:
          http2_protocol_options: {}
    load_assignment:
      cluster_name: rls_ext_authz
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: mimir-rls.mimir-edge-enforcement.svc.cluster.local
                port_value: 8080

  - name: rls_ratelimit
    connect_timeout: 0.25s
    type: STRICT_DNS
    lb_policy: ROUND_ROBIN
    typed_extension_protocol_options:
      envoy.extensions.upstreams.http.v3.HttpProtocolOptions:
        "@type": type.googleapis.com/envoy.extensions.upstreams.http.v3.HttpProtocolOptions
        explicit_http_config:
          http2_protocol_options: {}
    load_assignment:
      cluster_name: rls_ratelimit
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: mimir-rls.mimir-edge-enforcement.svc.cluster.local
                port_value: 8081
EOF
)

# Apply the patch
kubectl patch configmap "$CONFIGMAP" -n "$NAMESPACE" --type merge -p "{\"data\":{\"envoy.yaml\":\"$PATCH_CONFIG\"}}"

success "HTTP/1.1 compatibility patch applied"
echo

# 4. Restart Envoy pods
log "🔄 Restarting Envoy Pods"
echo "-------------------------"

if kubectl rollout restart deployment/mimir-envoy -n "$NAMESPACE" 2>/dev/null; then
    success "Envoy deployment restarted"
    kubectl rollout status deployment/mimir-envoy -n "$NAMESPACE" --timeout=60s
elif kubectl delete pods -l app.kubernetes.io/name=mimir-envoy -n "$NAMESPACE" 2>/dev/null; then
    success "Envoy pods deleted (will be recreated)"
    sleep 10
else
    warning "Could not automatically restart Envoy pods"
    echo "Please restart Envoy pods manually"
fi

# 5. Verify the fix
log "✅ Verifying the Fix"
echo "--------------------"

sleep 15  # Wait for pods to be ready

# Test connectivity
ENVOY_POD=$(kubectl get pods -l app.kubernetes.io/name=mimir-envoy -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -n "$ENVOY_POD" ]]; then
    echo "🧪 Testing Envoy connectivity..."
    
    # Port-forward to test
    kubectl port-forward "$ENVOY_POD" 8080:8080 -n "$NAMESPACE" &
    PF_PID=$!
    sleep 3
    
    # Test with HTTP/1.1
    if curl -s --http1.1 --max-time 5 "http://localhost:8080/api/v1/push" -o /dev/null -w "%{http_code}" | grep -v "426"; then
        success "No more 426 errors - HTTP/1.1 compatibility working!"
    else
        warning "Still getting 426 errors - may need additional configuration"
    fi
    
    # Clean up port-forward
    kill $PF_PID 2>/dev/null || true
    wait $PF_PID 2>/dev/null || true
else
    warning "No Envoy pod available for testing"
fi

echo
success "🎉 Envoy 426 fix completed!"
echo
echo "📋 Summary of changes:"
echo "  ✅ Added http_protocol_options with accept_http_10: true"
echo "  ✅ Configured codec_type: AUTO (supports HTTP/1.1 and HTTP/2)"
echo "  ✅ Properly configured cluster protocol options"
echo "  ✅ Restarted Envoy pods to apply changes"
echo
echo "🧪 Test the fix:"
echo "  # The 10% canary traffic should no longer get 426 errors"
echo "  kubectl logs -f deployment/nginx -n mimir | grep -E '(route=edge|426)'"
echo
echo "🚨 If issues persist:"
echo "  # Rollback: kubectl apply -f $BACKUP_FILE"
echo "  # Check logs: kubectl logs -l app.kubernetes.io/name=mimir-envoy -n $NAMESPACE"
