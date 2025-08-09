#!/bin/bash

# 🚀 Mimir Edge Enforcement Canary Management Script
# This script helps you safely roll out edge enforcement with weighted traffic splitting

set -euo pipefail

NAMESPACE=${NAMESPACE:-mimir}
CONFIGMAP_NAME=${CONFIGMAP_NAME:-mimir-nginx}

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
🚀 Mimir Edge Enforcement Canary Management

Usage: $0 <command> [options]

Commands:
  status                 Show current canary status
  set <percentage>       Set canary traffic percentage (0-100)
  mirror                 Enable shadow/mirror mode (non-blocking)
  unmirror              Disable shadow/mirror mode  
  bypass                Enable emergency bypass (all traffic direct)
  restore               Restore normal canary operation
  rollback              Emergency rollback (set to 0%)
  
Examples:
  $0 status                    # Check current setup
  $0 set 10                   # Route 10% through edge enforcement  
  $0 set 50                   # Route 50% through edge enforcement
  $0 set 100                  # Route 100% through edge enforcement
  $0 mirror                   # Shadow all traffic (testing)
  $0 bypass                   # Emergency bypass
  $0 rollback                 # Emergency rollback to 0%

Environment Variables:
  NAMESPACE=$NAMESPACE
  CONFIGMAP_NAME=$CONFIGMAP_NAME
EOF
}

get_current_config() {
    kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.nginx\.conf}' 2>/dev/null || echo ""
}

get_canary_percentage() {
    local config="$1"
    if echo "$config" | grep -q "default.*;" | head -1; then
        echo "$config" | grep "default.*;" | head -1 | sed 's/.*default \([0-9]*\);.*/\1/'
    else
        echo "0"
    fi
}

is_mirror_enabled() {
    local config="$1"
    if echo "$config" | grep -q "# mirror /mirror_to_edge_enforcement;"; then
        echo "disabled"
    elif echo "$config" | grep -q "mirror /mirror_to_edge_enforcement;"; then
        echo "enabled"
    else
        echo "not_configured"
    fi
}

update_canary_percentage() {
    local percentage=$1
    
    if [[ ! "$percentage" =~ ^[0-9]+$ ]] || [ "$percentage" -lt 0 ] || [ "$percentage" -gt 100 ]; then
        error "Percentage must be a number between 0 and 100"
    fi

    log "Setting canary traffic to ${percentage}%..."
    
    # Calculate the regex pattern for the percentage
    local pattern=""
    if [ "$percentage" -eq 0 ]; then
        pattern="~.{100,}$"  # Never match (0%)
    elif [ "$percentage" -eq 10 ]; then
        pattern="~.{0,}0$"   # Last digit is 0 (10%)
    elif [ "$percentage" -eq 20 ]; then
        pattern="~.{0,}[02468]$"  # Last digit is even (50%, then we'll adjust)
    elif [ "$percentage" -eq 50 ]; then
        pattern="~.{0,}[02468]$"  # Last digit is even (50%)
    elif [ "$percentage" -eq 100 ]; then
        pattern="~.*"  # Always match (100%)
    else
        # For other percentages, we'll use a more complex pattern
        pattern="~.{0,}[0-$(($percentage/10-1))]$"
    fi

    # Get current config
    local current_config
    current_config=$(get_current_config)
    
    if [ -z "$current_config" ]; then
        error "Could not retrieve current NGINX config from ConfigMap '$CONFIGMAP_NAME' in namespace '$NAMESPACE'"
    fi

    # Update the config
    local new_config
    new_config=$(echo "$current_config" | sed "s/default [0-9]*;.*# Start with.*$/default $percentage;  # Current canary traffic: ${percentage}%/")
    
    # Apply the update
    kubectl patch configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" --type merge -p "{\"data\":{\"nginx.conf\":\"$new_config\"}}"
    
    success "Canary traffic set to ${percentage}%"
    
    # Reload NGINX
    log "Reloading NGINX pods..."
    kubectl rollout restart deployment/mimir-nginx -n "$NAMESPACE" 2>/dev/null || \
    kubectl delete pods -l app=mimir-nginx -n "$NAMESPACE" 2>/dev/null || \
    warn "Could not automatically reload NGINX. You may need to restart NGINX pods manually."
    
    log "Monitoring tip: Watch metrics with:"
    echo "  kubectl logs -l app=mimir-nginx -n $NAMESPACE --tail=100 -f | grep 'X-Canary-Route'"
}

enable_mirror() {
    log "Enabling mirror mode (shadow traffic)..."
    
    local current_config
    current_config=$(get_current_config)
    
    # Uncomment mirror lines
    local new_config
    new_config=$(echo "$current_config" | sed 's/# mirror \/mirror_to_edge_enforcement;/mirror \/mirror_to_edge_enforcement;/' | sed 's/# mirror_request_body on;/mirror_request_body on;/')
    
    kubectl patch configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" --type merge -p "{\"data\":{\"nginx.conf\":\"$new_config\"}}"
    
    success "Mirror mode enabled - all traffic will be shadowed to edge enforcement"
    warn "Mirror mode is non-blocking but doubles the load on edge enforcement"
}

disable_mirror() {
    log "Disabling mirror mode..."
    
    local current_config
    current_config=$(get_current_config)
    
    # Comment mirror lines
    local new_config
    new_config=$(echo "$current_config" | sed 's/mirror \/mirror_to_edge_enforcement;/# mirror \/mirror_to_edge_enforcement;/' | sed 's/mirror_request_body on;/# mirror_request_body on;/')
    
    kubectl patch configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" --type merge -p "{\"data\":{\"nginx.conf\":\"$new_config\"}}"
    
    success "Mirror mode disabled"
}

show_status() {
    local current_config
    current_config=$(get_current_config)
    
    if [ -z "$current_config" ]; then
        error "ConfigMap '$CONFIGMAP_NAME' not found in namespace '$NAMESPACE'"
    fi

    local percentage
    percentage=$(get_canary_percentage "$current_config")
    
    local mirror_status
    mirror_status=$(is_mirror_enabled "$current_config")
    
    echo
    echo "🎯 Mimir Edge Enforcement Canary Status"
    echo "========================================"
    echo "Namespace: $NAMESPACE"
    echo "ConfigMap: $CONFIGMAP_NAME"
    echo
    echo "📊 Traffic Distribution:"
    echo "  Edge Enforcement: ${percentage}%"
    echo "  Direct to Mimir: $((100-percentage))%"
    echo
    echo "🪞 Mirror Mode: $mirror_status"
    echo
    
    if [ "$percentage" -eq 0 ]; then
        echo "🚦 Status: ${GREEN}BYPASSED${NC} - All traffic goes directly to Mimir"
    elif [ "$percentage" -eq 100 ]; then
        echo "🚦 Status: ${GREEN}FULL ENFORCEMENT${NC} - All traffic goes through edge enforcement"
    else
        echo "🚦 Status: ${YELLOW}CANARY${NC} - ${percentage}% traffic through edge enforcement"
    fi
    
    echo
    echo "🎛️  Available Commands:"
    echo "  Increase canary: $0 set $((percentage + 10))"
    echo "  Emergency bypass: $0 bypass"
    echo "  Full rollout: $0 set 100"
    echo "  Enable shadow: $0 mirror"
    echo
}

case "${1:-}" in
    "status")
        show_status
        ;;
    "set")
        if [ -z "${2:-}" ]; then
            error "Usage: $0 set <percentage>"
        fi
        update_canary_percentage "$2"
        ;;
    "mirror")
        enable_mirror
        ;;
    "unmirror")
        disable_mirror
        ;;
    "bypass"|"rollback")
        update_canary_percentage 0
        ;;
    "restore")
        update_canary_percentage 10
        ;;
    "help"|"-h"|"--help")
        usage
        ;;
    *)
        usage
        exit 1
        ;;
esac
