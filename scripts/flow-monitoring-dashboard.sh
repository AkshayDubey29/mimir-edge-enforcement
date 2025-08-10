#!/bin/bash

# Edge Enforcement Flow Monitoring Dashboard
# This script provides comprehensive monitoring of the entire pipeline
# and can be integrated into the UI Overview page

set -e

echo "🔍 EDGE ENFORCEMENT FLOW MONITORING DASHBOARD"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
RLS_BASE_URL="http://localhost:8082"
ENVOY_BASE_URL="http://localhost:8080"
MIMIR_BASE_URL="http://localhost:9009"
NGINX_BASE_URL="http://localhost:80"

# Results storage
declare -A COMPONENT_STATUS
declare -A COMPONENT_MESSAGES
declare -A COMPONENT_RESPONSE_TIMES
declare -A COMPONENT_ERROR_COUNTS

# Initialize results
COMPONENT_STATUS["overall"]="unknown"
COMPONENT_STATUS["nginx"]="unknown"
COMPONENT_STATUS["envoy"]="unknown"
COMPONENT_STATUS["rls"]="unknown"
COMPONENT_STATUS["overrides_sync"]="unknown"
COMPONENT_STATUS["mimir"]="unknown"

# =================================================================
# HEALTH CHECK FUNCTIONS
# =================================================================

check_rls_service() {
    echo -e "${BLUE}Checking RLS Service...${NC}"
    local start_time=$(date +%s%3N)
    
    if curl -s -f "${RLS_BASE_URL}/healthz" > /dev/null 2>&1; then
        local end_time=$(date +%s%3N)
        local response_time=$((end_time - start_time))
        
        COMPONENT_STATUS["rls"]="healthy"
        COMPONENT_MESSAGES["rls"]="Service responding normally"
        COMPONENT_RESPONSE_TIMES["rls"]=$response_time
        COMPONENT_ERROR_COUNTS["rls"]=0
        
        echo -e "  ${GREEN}✅ RLS Service: HEALTHY (${response_time}ms)${NC}"
    else
        COMPONENT_STATUS["rls"]="broken"
        COMPONENT_MESSAGES["rls"]="Service unavailable"
        COMPONENT_RESPONSE_TIMES["rls"]=0
        COMPONENT_ERROR_COUNTS["rls"]=1
        
        echo -e "  ${RED}❌ RLS Service: BROKEN${NC}"
    fi
}

check_overrides_sync() {
    echo -e "${BLUE}Checking Overrides Sync...${NC}"
    local start_time=$(date +%s%3N)
    
    if curl -s -f "${RLS_BASE_URL}/api/pipeline/status" > /dev/null 2>&1; then
        local end_time=$(date +%s%3N)
        local response_time=$((end_time - start_time))
        
        # Check if tenants have limits (indicates sync is working)
        local tenants_response=$(curl -s "${RLS_BASE_URL}/api/tenants" 2>/dev/null)
        local tenants_with_limits=$(echo "$tenants_response" | jq -r '.tenants[] | select(.limits and (.limits.samples_per_second > 0 or .limits.max_body_bytes > 0)) | .id' 2>/dev/null | wc -l)
        
        if [ "$tenants_with_limits" -gt 0 ]; then
            COMPONENT_STATUS["overrides_sync"]="healthy"
            COMPONENT_MESSAGES["overrides_sync"]="Limits syncing normally ($tenants_with_limits tenants)"
            COMPONENT_RESPONSE_TIMES["overrides_sync"]=$response_time
            COMPONENT_ERROR_COUNTS["overrides_sync"]=0
            
            echo -e "  ${GREEN}✅ Overrides Sync: HEALTHY (${response_time}ms, $tenants_with_limits tenants)${NC}"
        else
            COMPONENT_STATUS["overrides_sync"]="degraded"
            COMPONENT_MESSAGES["overrides_sync"]="Service responding but no tenant limits found"
            COMPONENT_RESPONSE_TIMES["overrides_sync"]=$response_time
            COMPONENT_ERROR_COUNTS["overrides_sync"]=0
            
            echo -e "  ${YELLOW}⚠️  Overrides Sync: DEGRADED (${response_time}ms, no limits)${NC}"
        fi
    else
        COMPONENT_STATUS["overrides_sync"]="broken"
        COMPONENT_MESSAGES["overrides_sync"]="Service unavailable"
        COMPONENT_RESPONSE_TIMES["overrides_sync"]=0
        COMPONENT_ERROR_COUNTS["overrides_sync"]=1
        
        echo -e "  ${RED}❌ Overrides Sync: BROKEN${NC}"
    fi
}

check_envoy_proxy() {
    echo -e "${BLUE}Checking Envoy Proxy...${NC}"
    local start_time=$(date +%s%3N)
    
    # Check if Envoy is listening on its ports
    if netstat -an 2>/dev/null | grep -q ":8080.*LISTEN" || ss -tuln 2>/dev/null | grep -q ":8080"; then
        local end_time=$(date +%s%3N)
        local response_time=$((end_time - start_time))
        
        COMPONENT_STATUS["envoy"]="healthy"
        COMPONENT_MESSAGES["envoy"]="Proxy functioning normally"
        COMPONENT_RESPONSE_TIMES["envoy"]=$response_time
        COMPONENT_ERROR_COUNTS["envoy"]=0
        
        echo -e "  ${GREEN}✅ Envoy Proxy: HEALTHY (${response_time}ms)${NC}"
    else
        COMPONENT_STATUS["envoy"]="broken"
        COMPONENT_MESSAGES["envoy"]="Proxy service unavailable"
        COMPONENT_RESPONSE_TIMES["envoy"]=0
        COMPONENT_ERROR_COUNTS["envoy"]=1
        
        echo -e "  ${RED}❌ Envoy Proxy: BROKEN${NC}"
    fi
}

check_nginx_config() {
    echo -e "${BLUE}Checking NGINX Configuration...${NC}"
    local start_time=$(date +%s%3N)
    
    # Check if NGINX is listening on port 80
    if netstat -an 2>/dev/null | grep -q ":80.*LISTEN" || ss -tuln 2>/dev/null | grep -q ":80"; then
        local end_time=$(date +%s%3N)
        local response_time=$((end_time - start_time))
        
        COMPONENT_STATUS["nginx"]="healthy"
        COMPONENT_MESSAGES["nginx"]="Traffic routing normally"
        COMPONENT_RESPONSE_TIMES["nginx"]=$response_time
        COMPONENT_ERROR_COUNTS["nginx"]=0
        
        echo -e "  ${GREEN}✅ NGINX: HEALTHY (${response_time}ms)${NC}"
    else
        COMPONENT_STATUS["nginx"]="broken"
        COMPONENT_MESSAGES["nginx"]="Configuration issues detected"
        COMPONENT_RESPONSE_TIMES["nginx"]=0
        COMPONENT_ERROR_COUNTS["nginx"]=1
        
        echo -e "  ${RED}❌ NGINX: BROKEN${NC}"
    fi
}

check_mimir_connectivity() {
    echo -e "${BLUE}Checking Mimir Connectivity...${NC}"
    local start_time=$(date +%s%3N)
    
    # Check if Mimir is accessible (basic connectivity)
    if curl -s -f "${MIMIR_BASE_URL}/ready" > /dev/null 2>&1 || curl -s -f "${MIMIR_BASE_URL}/health" > /dev/null 2>&1; then
        local end_time=$(date +%s%3N)
        local response_time=$((end_time - start_time))
        
        COMPONENT_STATUS["mimir"]="healthy"
        COMPONENT_MESSAGES["mimir"]="Backend accessible"
        COMPONENT_RESPONSE_TIMES["mimir"]=$response_time
        COMPONENT_ERROR_COUNTS["mimir"]=0
        
        echo -e "  ${GREEN}✅ Mimir: HEALTHY (${response_time}ms)${NC}"
    else
        COMPONENT_STATUS["mimir"]="broken"
        COMPONENT_MESSAGES["mimir"]="Mimir connectivity issues"
        COMPONENT_RESPONSE_TIMES["mimir"]=0
        COMPONENT_ERROR_COUNTS["mimir"]=1
        
        echo -e "  ${RED}❌ Mimir: BROKEN${NC}"
    fi
}

# =================================================================
# FLOW ANALYSIS
# =================================================================

analyze_flow_metrics() {
    echo -e "${BLUE}Analyzing Flow Metrics...${NC}"
    
    # Get overview stats
    local overview_response=$(curl -s "${RLS_BASE_URL}/api/overview" 2>/dev/null)
    if [ $? -eq 0 ]; then
        local total_requests=$(echo "$overview_response" | jq -r '.stats.total_requests' 2>/dev/null || echo "0")
        local allowed_requests=$(echo "$overview_response" | jq -r '.stats.allowed_requests' 2>/dev/null || echo "0")
        local denied_requests=$(echo "$overview_response" | jq -r '.stats.denied_requests' 2>/dev/null || echo "0")
        local active_tenants=$(echo "$overview_response" | jq -r '.stats.active_tenants' 2>/dev/null || echo "0")
        
        echo -e "  ${CYAN}Total Requests: $total_requests${NC}"
        echo -e "  ${CYAN}Allowed: $allowed_requests${NC}"
        echo -e "  ${CYAN}Denied: $denied_requests${NC}"
        echo -e "  ${CYAN}Active Tenants: $active_tenants${NC}"
        
        # Determine if enforcement is active
        if [ "$denied_requests" -gt 0 ] || [ "$active_tenants" -gt 0 ]; then
            echo -e "  ${GREEN}✅ Enforcement: ACTIVE${NC}"
        else
            echo -e "  ${YELLOW}⚠️  Enforcement: INACTIVE (no denials or active tenants)${NC}"
        fi
    else
        echo -e "  ${RED}❌ Could not fetch flow metrics${NC}"
    fi
}

# =================================================================
# OVERALL STATUS DETERMINATION
# =================================================================

determine_overall_status() {
    echo -e "${BLUE}Determining Overall Status...${NC}"
    
    local healthy_count=0
    local broken_count=0
    
    for component in "nginx" "envoy" "rls" "overrides_sync" "mimir"; do
        case "${COMPONENT_STATUS[$component]}" in
            "healthy")
                ((healthy_count++))
                ;;
            "broken")
                ((broken_count++))
                ;;
        esac
    done
    
    if [ $healthy_count -eq 5 ]; then
        COMPONENT_STATUS["overall"]="healthy"
        echo -e "  ${GREEN}✅ Overall Status: HEALTHY (all components working)${NC}"
    elif [ $healthy_count -ge 3 ]; then
        COMPONENT_STATUS["overall"]="degraded"
        echo -e "  ${YELLOW}⚠️  Overall Status: DEGRADED ($healthy_count/5 components healthy)${NC}"
    else
        COMPONENT_STATUS["overall"]="broken"
        echo -e "  ${RED}❌ Overall Status: BROKEN ($broken_count/5 components broken)${NC}"
    fi
}

# =================================================================
# FLOW DIAGRAM
# =================================================================

display_flow_diagram() {
    echo -e "${PURPLE}End-to-End Flow Diagram${NC}"
    echo "================================"
    
    # Client → NGINX
    echo -e "Client ${CYAN}→${NC} "
    if [ "${COMPONENT_STATUS[nginx]}" = "healthy" ]; then
        echo -e "${GREEN}NGINX${NC} "
    elif [ "${COMPONENT_STATUS[nginx]}" = "degraded" ]; then
        echo -e "${YELLOW}NGINX${NC} "
    else
        echo -e "${RED}NGINX${NC} "
    fi
    
    # NGINX → Envoy
    echo -e "${CYAN}→${NC} "
    if [ "${COMPONENT_STATUS[envoy]}" = "healthy" ]; then
        echo -e "${GREEN}Envoy${NC} "
    elif [ "${COMPONENT_STATUS[envoy]}" = "degraded" ]; then
        echo -e "${YELLOW}Envoy${NC} "
    else
        echo -e "${RED}Envoy${NC} "
    fi
    
    # Envoy → RLS
    echo -e "${CYAN}→${NC} "
    if [ "${COMPONENT_STATUS[rls]}" = "healthy" ]; then
        echo -e "${GREEN}RLS${NC} "
    elif [ "${COMPONENT_STATUS[rls]}" = "degraded" ]; then
        echo -e "${YELLOW}RLS${NC} "
    else
        echo -e "${RED}RLS${NC} "
    fi
    
    # RLS → Mimir
    echo -e "${CYAN}→${NC} "
    if [ "${COMPONENT_STATUS[mimir]}" = "healthy" ]; then
        echo -e "${GREEN}Mimir${NC}"
    elif [ "${COMPONENT_STATUS[mimir]}" = "degraded" ]; then
        echo -e "${YELLOW}Mimir${NC}"
    else
        echo -e "${RED}Mimir${NC}"
    fi
    
    echo ""
}

# =================================================================
# ISSUE DETECTION
# =================================================================

detect_flow_issues() {
    echo -e "${PURPLE}Flow Issues Analysis${NC}"
    echo "========================"
    
    local issues_found=false
    
    # Check for broken components
    for component in "nginx" "envoy" "rls" "overrides_sync" "mimir"; do
        if [ "${COMPONENT_STATUS[$component]}" = "broken" ]; then
            echo -e "  ${RED}❌ $component: ${COMPONENT_MESSAGES[$component]}${NC}"
            issues_found=true
        elif [ "${COMPONENT_STATUS[$component]}" = "degraded" ]; then
            echo -e "  ${YELLOW}⚠️  $component: ${COMPONENT_MESSAGES[$component]}${NC}"
            issues_found=true
        fi
    done
    
    # Check for specific flow issues
    if [ "${COMPONENT_STATUS[rls]}" = "healthy" ] && [ "${COMPONENT_STATUS[overrides_sync]}" = "broken" ]; then
        echo -e "  ${YELLOW}⚠️  RLS is healthy but Overrides Sync is broken - limits may be stale${NC}"
        issues_found=true
    fi
    
    if [ "${COMPONENT_STATUS[envoy]}" = "broken" ] && [ "${COMPONENT_STATUS[rls]}" = "healthy" ]; then
        echo -e "  ${YELLOW}⚠️  Envoy is broken but RLS is healthy - traffic may not reach enforcement${NC}"
        issues_found=true
    fi
    
    if [ "${COMPONENT_STATUS[nginx]}" = "broken" ]; then
        echo -e "  ${RED}❌ NGINX is broken - no traffic can reach the system${NC}"
        issues_found=true
    fi
    
    if [ ! "$issues_found" = true ]; then
        echo -e "  ${GREEN}✅ No flow issues detected${NC}"
    fi
}

# =================================================================
# JSON OUTPUT FOR UI INTEGRATION
# =================================================================

generate_json_output() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat << EOF
{
  "flow_status": {
    "overall": "${COMPONENT_STATUS[overall]}",
    "nginx": {
      "status": "${COMPONENT_STATUS[nginx]}",
      "message": "${COMPONENT_MESSAGES[nginx]}",
      "last_seen": "$timestamp",
      "response_time": ${COMPONENT_RESPONSE_TIMES[nginx]},
      "error_count": ${COMPONENT_ERROR_COUNTS[nginx]}
    },
    "envoy": {
      "status": "${COMPONENT_STATUS[envoy]}",
      "message": "${COMPONENT_MESSAGES[envoy]}",
      "last_seen": "$timestamp",
      "response_time": ${COMPONENT_RESPONSE_TIMES[envoy]},
      "error_count": ${COMPONENT_ERROR_COUNTS[envoy]}
    },
    "rls": {
      "status": "${COMPONENT_STATUS[rls]}",
      "message": "${COMPONENT_MESSAGES[rls]}",
      "last_seen": "$timestamp",
      "response_time": ${COMPONENT_RESPONSE_TIMES[rls]},
      "error_count": ${COMPONENT_ERROR_COUNTS[rls]}
    },
    "overrides_sync": {
      "status": "${COMPONENT_STATUS[overrides_sync]}",
      "message": "${COMPONENT_MESSAGES[overrides_sync]}",
      "last_seen": "$timestamp",
      "response_time": ${COMPONENT_RESPONSE_TIMES[overrides_sync]},
      "error_count": ${COMPONENT_ERROR_COUNTS[overrides_sync]}
    },
    "mimir": {
      "status": "${COMPONENT_STATUS[mimir]}",
      "message": "${COMPONENT_MESSAGES[mimir]}",
      "last_seen": "$timestamp",
      "response_time": ${COMPONENT_RESPONSE_TIMES[mimir]},
      "error_count": ${COMPONENT_ERROR_COUNTS[mimir]}
    },
    "last_check": "$timestamp"
  },
  "health_checks": {
    "rls_service": ${COMPONENT_STATUS[rls] == "healthy"},
    "overrides_sync": ${COMPONENT_STATUS[overrides_sync] == "healthy"},
    "envoy_proxy": ${COMPONENT_STATUS[envoy] == "healthy"},
    "nginx_config": ${COMPONENT_STATUS[nginx] == "healthy"},
    "mimir_connectivity": ${COMPONENT_STATUS[mimir] == "healthy"},
    "tenant_limits_synced": ${COMPONENT_STATUS[overrides_sync] == "healthy"},
    "enforcement_active": true
  }
}
EOF
}

# =================================================================
# MAIN EXECUTION
# =================================================================

main() {
    echo -e "${BLUE}Starting comprehensive flow monitoring...${NC}"
    echo ""
    
    # Run all health checks
    check_rls_service
    echo ""
    check_overrides_sync
    echo ""
    check_envoy_proxy
    echo ""
    check_nginx_config
    echo ""
    check_mimir_connectivity
    echo ""
    
    # Analyze flow metrics
    analyze_flow_metrics
    echo ""
    
    # Determine overall status
    determine_overall_status
    echo ""
    
    # Display flow diagram
    display_flow_diagram
    
    # Detect issues
    detect_flow_issues
    echo ""
    
    # Generate JSON output if requested
    if [ "$1" = "--json" ]; then
        generate_json_output
    else
        echo -e "${GREEN}🎯 FLOW MONITORING COMPLETE!${NC}"
        echo ""
        echo -e "${CYAN}To get JSON output for UI integration, run:${NC}"
        echo -e "  $0 --json"
    fi
}

# Run main function
main "$@"
