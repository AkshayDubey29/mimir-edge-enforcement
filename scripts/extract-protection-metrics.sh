#!/bin/bash

# 📊 Extract Protection Metrics from Edge Enforcement System
# Provides detailed operational metrics and effectiveness analysis

set -euo pipefail

# Configuration
NAMESPACE=${NAMESPACE:-mimir-edge-enforcement}
TIMEFRAME=${TIMEFRAME:-1h}
OUTPUT_DIR=${OUTPUT_DIR:-./metrics-output}

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

info() {
    echo -e "${PURPLE}ℹ️${NC} $1"
}

error() {
    echo -e "${RED}❌${NC} $1"
}

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo -e "${BLUE}📊 Edge Protection Metrics Extraction (Last $TIMEFRAME)${NC}"
echo -e "${BLUE}=============================================${NC}"
echo

# 1. Extract current overview stats
log "📋 Extracting Current Overview Stats"
echo "-------------------------------------"

RLS_POD=$(kubectl get pods -l app.kubernetes.io/name=mimir-rls -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -n "$RLS_POD" ]]; then
    info "Using RLS pod: $RLS_POD"
    
    # Start port-forward
    kubectl port-forward "$RLS_POD" 8082:8082 -n "$NAMESPACE" &
    PF_PID=$!
    
    # Wait for port-forward
    sleep 3
    
    # Extract overview data
    OVERVIEW_FILE="$OUTPUT_DIR/overview-$(date +%Y%m%d-%H%M%S).json"
    if curl -s --max-time 10 "http://localhost:8082/api/overview" > "$OVERVIEW_FILE"; then
        success "Overview stats saved to: $OVERVIEW_FILE"
        
        # Parse and display key metrics
        TOTAL_REQUESTS=$(jq -r '.stats.total_requests // 0' "$OVERVIEW_FILE")
        ALLOWED_REQUESTS=$(jq -r '.stats.allowed_requests // 0' "$OVERVIEW_FILE")
        DENIED_REQUESTS=$(jq -r '.stats.denied_requests // 0' "$OVERVIEW_FILE")
        ALLOW_PERCENTAGE=$(jq -r '.stats.allow_percentage // 0' "$OVERVIEW_FILE")
        ACTIVE_TENANTS=$(jq -r '.stats.active_tenants // 0' "$OVERVIEW_FILE")
        
        echo "📈 Key Metrics:"
        echo "  Total Requests: $(printf "%'d" "$TOTAL_REQUESTS")"
        echo "  Allowed: $(printf "%'d" "$ALLOWED_REQUESTS") (${ALLOW_PERCENTAGE}%)"
        echo "  Denied: $(printf "%'d" "$DENIED_REQUESTS") ($((100 - ${ALLOW_PERCENTAGE%.*}))%)"
        echo "  Active Tenants: $ACTIVE_TENANTS"
        
        # Calculate protection effectiveness
        if [[ "$TOTAL_REQUESTS" -gt 0 ]]; then
            PROTECTION_RATE=$((DENIED_REQUESTS * 100 / TOTAL_REQUESTS))
            if [[ "$PROTECTION_RATE" -ge 5 && "$PROTECTION_RATE" -le 30 ]]; then
                success "Protection rate optimal: ${PROTECTION_RATE}%"
            elif [[ "$PROTECTION_RATE" -gt 30 ]]; then
                echo -e "${YELLOW}⚠️ High protection rate: ${PROTECTION_RATE}% (may need limit adjustment)${NC}"
            else
                echo -e "${YELLOW}⚠️ Low protection rate: ${PROTECTION_RATE}% (check if enforcement needed)${NC}"
            fi
        fi
    else
        error "Failed to retrieve overview stats"
    fi
    echo
    
    # Extract tenant details
    log "👥 Extracting Tenant Details"
    echo "-----------------------------"
    
    TENANTS_FILE="$OUTPUT_DIR/tenants-$(date +%Y%m%d-%H%M%S).json"
    if curl -s --max-time 10 "http://localhost:8082/api/tenants" > "$TENANTS_FILE"; then
        success "Tenant details saved to: $TENANTS_FILE"
        
        TENANT_COUNT=$(jq '.tenants | length' "$TENANTS_FILE")
        echo "📊 Tenant Analysis:"
        echo "  Total Tenants: $TENANT_COUNT"
        
        if [[ "$TENANT_COUNT" -gt 0 ]]; then
            # Top violators
            echo "  Top Violators (by deny rate):"
            jq -r '.tenants | sort_by(.metrics.deny_rate) | reverse | .[0:5] | .[] | "    \(.id): \(.metrics.deny_rate) denials/sec"' "$TENANTS_FILE"
            
            # High utilization tenants
            echo "  High Utilization (>80%):"
            jq -r '.tenants | map(select(.metrics.utilization_pct > 80)) | .[] | "    \(.id): \(.metrics.utilization_pct)% utilization"' "$TENANTS_FILE"
            
            # Tenants with enforcement disabled
            DISABLED_COUNT=$(jq '[.tenants | map(select(.enforcement.enabled == false)) | length] | .[0]' "$TENANTS_FILE")
            if [[ "$DISABLED_COUNT" -gt 0 ]]; then
                echo -e "${YELLOW}  ⚠️ Tenants with enforcement disabled: $DISABLED_COUNT${NC}"
            fi
        fi
    else
        error "Failed to retrieve tenant details"
    fi
    echo
    
    # Extract recent denials
    log "🚫 Extracting Recent Denials"
    echo "-----------------------------"
    
    DENIALS_FILE="$OUTPUT_DIR/denials-$(date +%Y%m%d-%H%M%S).json"
    if curl -s --max-time 10 "http://localhost:8082/api/denials" > "$DENIALS_FILE"; then
        success "Denial details saved to: $DENIALS_FILE"
        
        DENIAL_COUNT=$(jq '. | length' "$DENIALS_FILE")
        echo "🚫 Denial Analysis:"
        echo "  Recent Denials: $DENIAL_COUNT"
        
        if [[ "$DENIAL_COUNT" -gt 0 ]]; then
            # Most common denial reasons
            echo "  Common Denial Reasons:"
            jq -r 'group_by(.reason) | map({reason: .[0].reason, count: length}) | sort_by(.count) | reverse | .[0:5] | .[] | "    \(.reason): \(.count) occurrences"' "$DENIALS_FILE"
            
            # Most denied tenants
            echo "  Most Denied Tenants:"
            jq -r 'group_by(.tenant_id) | map({tenant: .[0].tenant_id, count: length}) | sort_by(.count) | reverse | .[0:5] | .[] | "    \(.tenant): \(.count) denials"' "$DENIALS_FILE"
        fi
    else
        error "Failed to retrieve denial details"
    fi
    echo
    
    # Extract system health
    log "❤️ Extracting System Health"
    echo "----------------------------"
    
    HEALTH_FILE="$OUTPUT_DIR/health-$(date +%Y%m%d-%H%M%S).json"
    if curl -s --max-time 10 "http://localhost:8082/api/health" > "$HEALTH_FILE"; then
        success "Health details saved to: $HEALTH_FILE"
        
        echo "🏥 System Health:"
        jq -r 'to_entries | .[] | "  \(.key): \(.value)"' "$HEALTH_FILE"
    else
        error "Failed to retrieve health details"
    fi
    
    # Clean up port-forward
    kill $PF_PID 2>/dev/null || true
    wait $PF_PID 2>/dev/null || true
    
else
    error "No RLS pod found for metrics extraction"
    exit 1
fi

echo

# 2. Extract Kubernetes metrics
log "☸️ Extracting Kubernetes Metrics"
echo "----------------------------------"

K8S_METRICS_FILE="$OUTPUT_DIR/k8s-metrics-$(date +%Y%m%d-%H%M%S).txt"

{
    echo "=== POD STATUS ==="
    kubectl get pods -n "$NAMESPACE" -o wide
    echo
    
    echo "=== RESOURCE USAGE ==="
    kubectl top pods -n "$NAMESPACE" 2>/dev/null || echo "kubectl top not available"
    echo
    
    echo "=== SERVICE STATUS ==="
    kubectl get svc -n "$NAMESPACE"
    echo
    
    echo "=== INGRESS STATUS ==="
    kubectl get ingress -n "$NAMESPACE" 2>/dev/null || echo "No ingress found"
    echo
    
    echo "=== RECENT EVENTS ==="
    kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -10
    
} > "$K8S_METRICS_FILE"

success "Kubernetes metrics saved to: $K8S_METRICS_FILE"
echo

# 3. Extract component logs
log "📝 Extracting Component Logs (Last ${TIMEFRAME})"
echo "-----------------------------------------------"

LOGS_DIR="$OUTPUT_DIR/logs-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LOGS_DIR"

# Calculate log extraction time
if [[ "$TIMEFRAME" == "1h" ]]; then
    SINCE_TIME="1h"
elif [[ "$TIMEFRAME" == "24h" ]]; then
    SINCE_TIME="24h"
else
    SINCE_TIME="1h"
fi

# Extract RLS logs
if kubectl logs -l app.kubernetes.io/name=mimir-rls -n "$NAMESPACE" --since="$SINCE_TIME" > "$LOGS_DIR/rls.log" 2>/dev/null; then
    success "RLS logs saved to: $LOGS_DIR/rls.log"
    
    # Analyze RLS logs
    RLS_ERRORS=$(grep -c "ERROR" "$LOGS_DIR/rls.log" || echo "0")
    RLS_DECISIONS=$(grep -c -E "(ALLOW|DENY)" "$LOGS_DIR/rls.log" || echo "0")
    
    echo "  RLS Analysis: $RLS_ERRORS errors, $RLS_DECISIONS decisions"
fi

# Extract overrides-sync logs
if kubectl logs -l app.kubernetes.io/name=overrides-sync -n "$NAMESPACE" --since="$SINCE_TIME" > "$LOGS_DIR/overrides-sync.log" 2>/dev/null; then
    success "Overrides-sync logs saved to: $LOGS_DIR/overrides-sync.log"
    
    # Analyze overrides-sync logs
    SYNC_ERRORS=$(grep -c "ERROR" "$LOGS_DIR/overrides-sync.log" || echo "0")
    SYNC_SUCCESS=$(grep -c "successfully synced" "$LOGS_DIR/overrides-sync.log" || echo "0")
    
    echo "  Sync Analysis: $SYNC_ERRORS errors, $SYNC_SUCCESS successful syncs"
fi

# Extract Envoy logs
if kubectl logs -l app.kubernetes.io/name=mimir-envoy -n "$NAMESPACE" --since="$SINCE_TIME" > "$LOGS_DIR/envoy.log" 2>/dev/null; then
    success "Envoy logs saved to: $LOGS_DIR/envoy.log"
    
    # Analyze Envoy logs
    ENVOY_ERRORS=$(grep -c -i "error" "$LOGS_DIR/envoy.log" || echo "0")
    EXT_AUTHZ_CALLS=$(grep -c "ext_authz" "$LOGS_DIR/envoy.log" || echo "0")
    
    echo "  Envoy Analysis: $ENVOY_ERRORS errors, $EXT_AUTHZ_CALLS ext_authz calls"
fi

echo

# 4. Generate CSV export
log "📄 Generating CSV Export"
echo "-------------------------"

CSV_FILE="$OUTPUT_DIR/protection-summary-$(date +%Y%m%d-%H%M%S).csv"

{
    echo "timestamp,total_requests,allowed_requests,denied_requests,allow_percentage,active_tenants,protection_rate"
    if [[ -f "$OVERVIEW_FILE" ]]; then
        TIMESTAMP=$(date -Iseconds)
        PROTECTION_RATE=$((DENIED_REQUESTS * 100 / (TOTAL_REQUESTS > 0 ? TOTAL_REQUESTS : 1)))
        echo "$TIMESTAMP,$TOTAL_REQUESTS,$ALLOWED_REQUESTS,$DENIED_REQUESTS,$ALLOW_PERCENTAGE,$ACTIVE_TENANTS,$PROTECTION_RATE"
    fi
} > "$CSV_FILE"

success "CSV summary saved to: $CSV_FILE"
echo

# 5. Generate executive summary
log "📊 Generating Executive Summary"
echo "--------------------------------"

SUMMARY_FILE="$OUTPUT_DIR/executive-summary-$(date +%Y%m%d-%H%M%S).md"

{
    echo "# Edge Enforcement Effectiveness Report"
    echo "Generated: $(date)"
    echo
    echo "## Executive Summary"
    echo
    if [[ "$TOTAL_REQUESTS" -gt 0 ]]; then
        echo "✅ **System Status**: Active and processing traffic"
        echo "📊 **Protection Rate**: ${PROTECTION_RATE}% of requests blocked at edge"
        echo "👥 **Tenant Coverage**: $ACTIVE_TENANTS tenants actively monitored"
        echo "🛡️ **Mimir Protection**: $(printf "%'d" "$DENIED_REQUESTS") overload requests prevented"
        echo
        echo "## Key Metrics"
        echo "- **Total Requests Processed**: $(printf "%'d" "$TOTAL_REQUESTS")"
        echo "- **Requests Allowed to Mimir**: $(printf "%'d" "$ALLOWED_REQUESTS") (${ALLOW_PERCENTAGE}%)"
        echo "- **Requests Blocked at Edge**: $(printf "%'d" "$DENIED_REQUESTS") (${PROTECTION_RATE}%)"
        echo "- **System Efficiency**: Prevented $(printf "%'d" "$DENIED_REQUESTS") potentially harmful requests"
        echo
        echo "## Health Assessment"
        if [[ "$PROTECTION_RATE" -ge 5 && "$PROTECTION_RATE" -le 30 ]]; then
            echo "🟢 **Status**: Healthy - Optimal protection rate"
        elif [[ "$PROTECTION_RATE" -gt 30 ]]; then
            echo "🟡 **Status**: Caution - High blocking rate may indicate aggressive limits"
        else
            echo "🟡 **Status**: Monitor - Low blocking rate, ensure enforcement is needed"
        fi
    else
        echo "⚠️ **System Status**: No traffic processed yet"
        echo "🔍 **Action Required**: Verify traffic routing and system configuration"
    fi
    echo
    echo "## Files Generated"
    echo "- Detailed metrics: $OVERVIEW_FILE"
    echo "- Tenant analysis: $TENANTS_FILE"
    echo "- Denial patterns: $DENIALS_FILE"
    echo "- System logs: $LOGS_DIR/"
    echo "- CSV export: $CSV_FILE"
    
} > "$SUMMARY_FILE"

success "Executive summary saved to: $SUMMARY_FILE"
echo

# 6. Display summary
echo -e "${BLUE}📋 Metrics Extraction Complete${NC}"
echo "==============================="
echo
echo "📁 Output directory: $OUTPUT_DIR"
echo "📊 Files generated:"
echo "  - Overview stats: $(basename "$OVERVIEW_FILE")"
echo "  - Tenant details: $(basename "$TENANTS_FILE")"
echo "  - Denial analysis: $(basename "$DENIALS_FILE")"
echo "  - System health: $(basename "$HEALTH_FILE")"
echo "  - K8s metrics: $(basename "$K8S_METRICS_FILE")"
echo "  - Component logs: $(basename "$LOGS_DIR")"
echo "  - CSV export: $(basename "$CSV_FILE")"
echo "  - Executive summary: $(basename "$SUMMARY_FILE")"
echo
echo "💡 Quick analysis:"
if [[ "$TOTAL_REQUESTS" -gt 0 ]]; then
    echo "  Edge enforcement is actively protecting Mimir"
    echo "  Processing $(printf "%'d" "$TOTAL_REQUESTS") requests with ${PROTECTION_RATE}% blocked"
    echo "  Monitoring $ACTIVE_TENANTS tenants with $DENIAL_COUNT recent denials"
else
    echo "  No traffic processed yet - verify system configuration"
fi
echo
info "📈 For real-time monitoring, access Admin UI:"
echo "     kubectl port-forward svc/admin-ui 3000:80 -n $NAMESPACE"
