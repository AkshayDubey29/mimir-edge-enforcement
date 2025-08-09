#!/bin/bash

# 🎯 Manage NGINX Canary Rollout for Mimir Edge Enforcement
# Controls the percentage of traffic routed through edge enforcement

set -euo pipefail

# Configuration
NAMESPACE=${NAMESPACE:-mimir}
CONFIGMAP=${CONFIGMAP:-mimir-nginx-canary}
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

# Help function
show_help() {
    echo -e "${BLUE}🎯 NGINX Canary Management for Mimir Edge Enforcement${NC}"
    echo
    echo "Usage: $0 <command> [options]"
    echo
    echo "Commands:"
    echo "  status                     Show current canary configuration"
    echo "  set-weight <0-100>         Set canary traffic percentage"
    echo "  disable                    Disable edge enforcement (0% traffic)"
    echo "  enable-full               Enable full edge enforcement (100% traffic)"
    echo "  rollback                  Rollback to previous configuration"
    echo "  test-config               Test NGINX configuration syntax"
    echo "  apply-fixed               Apply the fixed production configuration"
    echo "  monitor                   Monitor traffic distribution"
    echo
    echo "Options:"
    echo "  --namespace=NAMESPACE     Kubernetes namespace (default: mimir)"
    echo "  --configmap=NAME          ConfigMap name (default: mimir-nginx-canary)"
    echo "  --dry-run                 Show changes without applying"
    echo
    echo "Examples:"
    echo "  $0 set-weight 10          # Route 10% through edge enforcement"
    echo "  $0 set-weight 50          # Route 50% through edge enforcement"
    echo "  $0 enable-full            # Route 100% through edge enforcement"
    echo "  $0 disable               # Bypass edge enforcement (emergency)"
    echo
}

# Create backup directory
create_backup() {
    mkdir -p "$BACKUP_DIR"
    BACKUP_FILE="$BACKUP_DIR/nginx-config-$(date +%Y%m%d-%H%M%S).yaml"
    
    kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" -o yaml > "$BACKUP_FILE"
    success "Configuration backed up to: $BACKUP_FILE"
}

# Get current canary weight
get_current_weight() {
    kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" -o jsonpath='{.data.nginx\.conf}' 2>/dev/null | \
        grep -o 'default [0-9]*;.*# Start with.*canary traffic' | \
        head -1 | grep -o '[0-9]*' || echo "unknown"
}

# Show current status
show_status() {
    log "📊 Current NGINX Canary Status"
    echo "==============================="
    
    # Check if ConfigMap exists
    if ! kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" &>/dev/null; then
        error "ConfigMap '$CONFIGMAP' not found in namespace '$NAMESPACE'"
        return 1
    fi
    
    CURRENT_WEIGHT=$(get_current_weight)
    
    echo "Namespace: $NAMESPACE"
    echo "ConfigMap: $CONFIGMAP"
    echo "Current Canary Weight: $CURRENT_WEIGHT%"
    echo
    
    if [[ "$CURRENT_WEIGHT" == "0" ]]; then
        echo -e "${RED}🚫 Edge enforcement DISABLED${NC} (all traffic direct to Mimir)"
    elif [[ "$CURRENT_WEIGHT" == "100" ]]; then
        echo -e "${GREEN}🛡️ Edge enforcement FULL${NC} (all traffic through edge enforcement)"
    elif [[ "$CURRENT_WEIGHT" =~ ^[0-9]+$ ]] && [[ "$CURRENT_WEIGHT" -gt 0 ]]; then
        echo -e "${YELLOW}⚖️ Edge enforcement CANARY${NC} ($CURRENT_WEIGHT% through edge enforcement, $((100-CURRENT_WEIGHT))% direct)"
    else
        echo -e "${RED}❓ Unknown configuration${NC}"
    fi
    
    echo
    echo "Traffic Distribution:"
    echo "  → Edge Enforcement: $CURRENT_WEIGHT%"
    echo "  → Direct to Mimir: $((100-CURRENT_WEIGHT))%"
    echo
    
    # Check if pods are running
    NGINX_PODS=$(kubectl get pods -l app=nginx -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$NGINX_PODS" ]]; then
        success "NGINX pods running: $NGINX_PODS"
    else
        warning "No NGINX pods found (check pod selector)"
    fi
}

# Set canary weight
set_weight() {
    local weight=$1
    
    if [[ ! "$weight" =~ ^[0-9]+$ ]] || [[ "$weight" -lt 0 ]] || [[ "$weight" -gt 100 ]]; then
        error "Weight must be a number between 0-100"
        return 1
    fi
    
    log "🎯 Setting canary weight to ${weight}%"
    
    # Create backup
    create_backup
    
    # Get current config
    CURRENT_CONFIG=$(kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" -o jsonpath='{.data.nginx\.conf}')
    
    # Update the canary weight
    UPDATED_CONFIG=$(echo "$CURRENT_CONFIG" | sed "s/default [0-9]*;.*# Start with.*canary traffic/default $weight;  # Start with ${weight}% canary traffic/")
    
    # Also update the regex pattern for the percentage
    if [[ "$weight" -eq 0 ]]; then
        # 0% - no traffic to edge
        PATTERN="~.*x$ 1;"  # Never match
    elif [[ "$weight" -eq 10 ]]; then
        # 10% - last digit is 0
        PATTERN="~.*0$ 1;"
    elif [[ "$weight" -eq 20 ]]; then
        # 20% - last digit is 0 or 5
        PATTERN="~.*[05]$ 1;"
    elif [[ "$weight" -eq 50 ]]; then
        # 50% - last digit is even
        PATTERN="~.*[02468]$ 1;"
    elif [[ "$weight" -eq 100 ]]; then
        # 100% - all traffic
        PATTERN="~.* 1;"
    else
        # Custom percentage - approximate with available patterns
        if [[ "$weight" -le 30 ]]; then
            PATTERN="~.*[0-2]$ 1;"
        elif [[ "$weight" -le 70 ]]; then
            PATTERN="~.*[0-6]$ 1;"
        else
            PATTERN="~.*[0-8]$ 1;"
        fi
    fi
    
    # Update the regex pattern
    UPDATED_CONFIG=$(echo "$UPDATED_CONFIG" | sed "s/~\.\*[^$]*\$ 1;   # [0-9]*% of requests/$PATTERN   # ${weight}% of requests/")
    
    if [[ "${DRY_RUN:-}" == "true" ]]; then
        info "DRY RUN: Would update canary weight to ${weight}%"
        echo "New pattern: $PATTERN"
        return 0
    fi
    
    # Apply the updated config
    kubectl patch configmap "$CONFIGMAP" -n "$NAMESPACE" --type merge -p "{\"data\":{\"nginx.conf\":\"$UPDATED_CONFIG\"}}"
    
    success "Canary weight updated to ${weight}%"
    
    # Restart NGINX pods to pick up new config
    log "🔄 Restarting NGINX pods to apply new configuration..."
    kubectl rollout restart deployment/nginx -n "$NAMESPACE" 2>/dev/null || \
    kubectl delete pods -l app=nginx -n "$NAMESPACE" 2>/dev/null || \
    warning "Could not restart NGINX pods automatically - please restart manually"
    
    success "✅ Canary rollout updated successfully!"
    echo
    show_status
}

# Apply the fixed configuration
apply_fixed_config() {
    log "🔧 Applying fixed NGINX configuration"
    
    if [[ ! -f "examples/nginx-production-canary-fixed.yaml" ]]; then
        error "Fixed configuration file not found: examples/nginx-production-canary-fixed.yaml"
        return 1
    fi
    
    # Create backup
    create_backup
    
    if [[ "${DRY_RUN:-}" == "true" ]]; then
        info "DRY RUN: Would apply fixed configuration"
        return 0
    fi
    
    # Apply the fixed configuration
    kubectl apply -f examples/nginx-production-canary-fixed.yaml
    
    success "Fixed NGINX configuration applied"
    
    # Restart NGINX pods
    log "🔄 Restarting NGINX pods..."
    kubectl rollout restart deployment/nginx -n "$NAMESPACE" 2>/dev/null || \
    kubectl delete pods -l app=nginx -n "$NAMESPACE" 2>/dev/null || \
    warning "Could not restart NGINX pods automatically"
    
    success "✅ Fixed configuration deployed successfully!"
}

# Test NGINX configuration
test_config() {
    log "🧪 Testing NGINX configuration syntax"
    
    # Get a running NGINX pod
    NGINX_POD=$(kubectl get pods -l app=nginx -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -z "$NGINX_POD" ]]; then
        error "No NGINX pods found for testing"
        return 1
    fi
    
    # Test the configuration
    kubectl exec "$NGINX_POD" -n "$NAMESPACE" -- nginx -t
    
    if [[ $? -eq 0 ]]; then
        success "NGINX configuration syntax is valid"
    else
        error "NGINX configuration has syntax errors"
        return 1
    fi
}

# Monitor traffic distribution
monitor_traffic() {
    log "📊 Monitoring NGINX traffic distribution"
    echo "======================================="
    echo "Press Ctrl+C to stop monitoring"
    echo
    
    # Get NGINX pod for log monitoring
    NGINX_POD=$(kubectl get pods -l app=nginx -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -z "$NGINX_POD" ]]; then
        error "No NGINX pods found for monitoring"
        return 1
    fi
    
    # Monitor NGINX access logs
    kubectl logs -f "$NGINX_POD" -n "$NAMESPACE" | grep -E "(X-Route-Type|X-Canary)" || true
}

# Rollback configuration
rollback_config() {
    log "🔄 Rolling back NGINX configuration"
    
    if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        error "No backups found in $BACKUP_DIR"
        return 1
    fi
    
    # Get the latest backup
    LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/nginx-config-*.yaml | head -1)
    
    if [[ -z "$LATEST_BACKUP" ]]; then
        error "No backup files found"
        return 1
    fi
    
    info "Rolling back to: $(basename "$LATEST_BACKUP")"
    
    if [[ "${DRY_RUN:-}" == "true" ]]; then
        info "DRY RUN: Would rollback to $LATEST_BACKUP"
        return 0
    fi
    
    # Apply the backup
    kubectl apply -f "$LATEST_BACKUP"
    
    success "Configuration rolled back successfully"
    
    # Restart NGINX pods
    log "🔄 Restarting NGINX pods..."
    kubectl rollout restart deployment/nginx -n "$NAMESPACE" 2>/dev/null || \
    kubectl delete pods -l app=nginx -n "$NAMESPACE" 2>/dev/null || \
    warning "Could not restart NGINX pods automatically"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --namespace=*)
            NAMESPACE="${1#*=}"
            shift
            ;;
        --configmap=*)
            CONFIGMAP="${1#*=}"
            shift
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

# Main command handling
case "${1:-}" in
    status)
        show_status
        ;;
    set-weight)
        if [[ -z "${2:-}" ]]; then
            error "Weight value required"
            echo "Usage: $0 set-weight <0-100>"
            exit 1
        fi
        set_weight "$2"
        ;;
    disable)
        set_weight 0
        ;;
    enable-full)
        set_weight 100
        ;;
    apply-fixed)
        apply_fixed_config
        ;;
    test-config)
        test_config
        ;;
    monitor)
        monitor_traffic
        ;;
    rollback)
        rollback_config
        ;;
    "")
        show_help
        exit 1
        ;;
    *)
        error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
