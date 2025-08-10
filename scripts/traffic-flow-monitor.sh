#!/bin/bash

# Traffic Flow Monitor
# This script monitors NGINX logs and correlates traffic flow with RLS metrics
# to provide accurate visibility into the actual traffic flow

set -e

# Configuration
NGINX_LOG_PATH="/var/log/nginx/access.log"
RLS_BASE_URL="http://localhost:8082"
ENVOY_BASE_URL="http://localhost:8080"
MIMIR_BASE_URL="http://localhost:9009"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# =================================================================
# NGINX LOG PARSING
# =================================================================

parse_nginx_logs() {
    echo -e "${BLUE}=== NGINX TRAFFIC ANALYSIS ===${NC}"
    
    if [ ! -f "$NGINX_LOG_PATH" ]; then
        echo -e "${YELLOW}Warning: NGINX log file not found at $NGINX_LOG_PATH${NC}"
        echo -e "${CYAN}Checking for alternative log locations...${NC}"
        
        # Try common NGINX log locations
        for log_path in "/var/log/nginx/access.log" "/var/log/nginx/nginx-access.log" "/var/log/nginx/access.log.1"; do
            if [ -f "$log_path" ]; then
                NGINX_LOG_PATH="$log_path"
                echo -e "${GREEN}Found NGINX log at: $log_path${NC}"
                break
            fi
        done
    fi
    
    if [ ! -f "$NGINX_LOG_PATH" ]; then
        echo -e "${RED}Error: Could not find NGINX log file${NC}"
        return 1
    fi
    
    # Analyze NGINX logs for the last 5 minutes
    echo -e "${CYAN}Analyzing NGINX logs for the last 5 minutes...${NC}"
    
    # Count total requests to /api/v1/push
    total_requests=$(tail -n 1000 "$NGINX_LOG_PATH" | grep "/api/v1/push" | wc -l)
    
    # Count requests by status code
    status_200=$(tail -n 1000 "$NGINX_LOG_PATH" | grep "/api/v1/push" | grep " 200 " | wc -l)
    status_4xx=$(tail -n 1000 "$NGINX_LOG_PATH" | grep "/api/v1/push" | grep " 4[0-9][0-9] " | wc -l)
    status_5xx=$(tail -n 1000 "$NGINX_LOG_PATH" | grep "/api/v1/push" | grep " 5[0-9][0-9] " | wc -l)
    
    # Count requests by route (if available in logs)
    route_edge=$(tail -n 1000 "$NGINX_LOG_PATH" | grep "/api/v1/push" | grep "route=edge" | wc -l)
    route_direct=$(tail -n 1000 "$NGINX_LOG_PATH" | grep "/api/v1/push" | grep -v "route=edge" | wc -l)
    
    echo -e "${GREEN}NGINX Traffic Summary:${NC}"
    echo -e "  Total /api/v1/push requests: $total_requests"
    echo -e "  200 OK responses: $status_200"
    echo -e "  4xx error responses: $status_4xx"
    echo -e "  5xx error responses: $status_5xx"
    echo -e "  Route=edge requests: $route_edge"
    echo -e "  Route=direct requests: $route_direct"
    
    # Show recent requests
    echo -e "${CYAN}Recent NGINX requests:${NC}"
    tail -n 10 "$NGINX_LOG_PATH" | grep "/api/v1/push" | while read line; do
        echo -e "  $line"
    done
}

# =================================================================
# RLS METRICS ANALYSIS
# =================================================================

analyze_rls_metrics() {
    echo -e "${BLUE}=== RLS METRICS ANALYSIS ===${NC}"
    
    # Check if RLS service is available
    if ! curl -s -f "${RLS_BASE_URL}/healthz" > /dev/null 2>&1; then
        echo -e "${RED}Error: RLS service not available at ${RLS_BASE_URL}${NC}"
        return 1
    fi
    
    # Get RLS overview data
    echo -e "${CYAN}Fetching RLS overview data...${NC}"
    overview_response=$(curl -s "${RLS_BASE_URL}/api/overview")
    
    if [ $? -eq 0 ]; then
        total_requests=$(echo "$overview_response" | jq -r '.stats.total_requests // 0')
        allowed_requests=$(echo "$overview_response" | jq -r '.stats.allowed_requests // 0')
        denied_requests=$(echo "$overview_response" | jq -r '.stats.denied_requests // 0')
        allow_percentage=$(echo "$overview_response" | jq -r '.stats.allow_percentage // 0')
        active_tenants=$(echo "$overview_response" | jq -r '.stats.active_tenants // 0')
        
        echo -e "${GREEN}RLS Metrics Summary:${NC}"
        echo -e "  Total requests processed: $total_requests"
        echo -e "  Allowed requests: $allowed_requests"
        echo -e "  Denied requests: $denied_requests"
        echo -e "  Allow percentage: ${allow_percentage}%"
        echo -e "  Active tenants: $active_tenants"
    else
        echo -e "${RED}Error: Failed to fetch RLS overview data${NC}"
    fi
    
    # Get RLS Prometheus metrics
    echo -e "${CYAN}Fetching RLS Prometheus metrics...${NC}"
    metrics_response=$(curl -s "${RLS_BASE_URL}/metrics")
    
    if [ $? -eq 0 ]; then
        # Extract traffic flow metrics
        traffic_flow_total=$(echo "$metrics_response" | grep "rls_traffic_flow_total" | grep -v "#" | awk '{sum += $2} END {print sum}')
        traffic_flow_latency=$(echo "$metrics_response" | grep "rls_traffic_flow_latency_seconds_sum" | grep -v "#" | awk '{sum += $2} END {print sum}')
        traffic_flow_bytes=$(echo "$metrics_response" | grep "rls_traffic_flow_bytes" | grep -v "#" | awk '{sum += $2} END {print sum}')
        
        echo -e "${GREEN}RLS Traffic Flow Metrics:${NC}"
        echo -e "  Total traffic flow requests: ${traffic_flow_total:-0}"
        echo -e "  Total latency (seconds): ${traffic_flow_latency:-0}"
        echo -e "  Total bytes processed: ${traffic_flow_bytes:-0}"
    else
        echo -e "${RED}Error: Failed to fetch RLS metrics${NC}"
    fi
}

# =================================================================
# ENVOY METRICS ANALYSIS
# =================================================================

analyze_envoy_metrics() {
    echo -e "${BLUE}=== ENVOY METRICS ANALYSIS ===${NC}"
    
    # Check if Envoy service is available
    if ! curl -s -f "${ENVOY_BASE_URL}/stats" > /dev/null 2>&1; then
        echo -e "${YELLOW}Warning: Envoy service not available at ${ENVOY_BASE_URL}${NC}"
        return 1
    fi
    
    # Get Envoy stats
    echo -e "${CYAN}Fetching Envoy statistics...${NC}"
    envoy_stats=$(curl -s "${ENVOY_BASE_URL}/stats")
    
    if [ $? -eq 0 ]; then
        # Extract relevant metrics
        http_requests=$(echo "$envoy_stats" | grep "http.downstream_rq_total" | awk -F: '{print $2}' | head -1)
        http_2xx=$(echo "$envoy_stats" | grep "http.downstream_rq_2xx" | awk -F: '{print $2}' | head -1)
        http_4xx=$(echo "$envoy_stats" | grep "http.downstream_rq_4xx" | awk -F: '{print $2}' | head -1)
        http_5xx=$(echo "$envoy_stats" | grep "http.downstream_rq_5xx" | awk -F: '{print $2}' | head -1)
        ext_authz_total=$(echo "$envoy_stats" | grep "ext_authz.total" | awk -F: '{print $2}' | head -1)
        ext_authz_ok=$(echo "$envoy_stats" | grep "ext_authz.ok" | awk -F: '{print $2}' | head -1)
        ext_authz_denied=$(echo "$envoy_stats" | grep "ext_authz.denied" | awk -F: '{print $2}' | head -1)
        
        echo -e "${GREEN}Envoy Metrics Summary:${NC}"
        echo -e "  Total HTTP requests: ${http_requests:-0}"
        echo -e "  2xx responses: ${http_2xx:-0}"
        echo -e "  4xx responses: ${http_4xx:-0}"
        echo -e "  5xx responses: ${http_5xx:-0}"
        echo -e "  External authz total: ${ext_authz_total:-0}"
        echo -e "  External authz OK: ${ext_authz_ok:-0}"
        echo -e "  External authz denied: ${ext_authz_denied:-0}"
    else
        echo -e "${RED}Error: Failed to fetch Envoy statistics${NC}"
    fi
}

# =================================================================
# TRAFFIC FLOW CORRELATION
# =================================================================

correlate_traffic_flow() {
    echo -e "${BLUE}=== TRAFFIC FLOW CORRELATION ===${NC}"
    
    # Get NGINX traffic data
    nginx_total=$(tail -n 1000 "$NGINX_LOG_PATH" 2>/dev/null | grep "/api/v1/push" | wc -l || echo "0")
    nginx_200=$(tail -n 1000 "$NGINX_LOG_PATH" 2>/dev/null | grep "/api/v1/push" | grep " 200 " | wc -l || echo "0")
    
    # Get RLS data
    rls_total=$(curl -s "${RLS_BASE_URL}/api/overview" 2>/dev/null | jq -r '.stats.total_requests // 0' || echo "0")
    rls_allowed=$(curl -s "${RLS_BASE_URL}/api/overview" 2>/dev/null | jq -r '.stats.allowed_requests // 0' || echo "0")
    
    # Get Envoy data
    envoy_total=$(curl -s "${ENVOY_BASE_URL}/stats" 2>/dev/null | grep "http.downstream_rq_total" | awk -F: '{print $2}' | head -1 || echo "0")
    envoy_2xx=$(curl -s "${ENVOY_BASE_URL}/stats" 2>/dev/null | grep "http.downstream_rq_2xx" | awk -F: '{print $2}' | head -1 || echo "0")
    
    echo -e "${GREEN}Traffic Flow Correlation:${NC}"
    echo -e "  NGINX → Envoy: $nginx_total requests (${nginx_200} successful)"
    echo -e "  Envoy → RLS: $envoy_total requests (${envoy_2xx} successful)"
    echo -e "  RLS Decisions: $rls_total total ($rls_allowed allowed)"
    
    # Calculate discrepancies
    if [ "$nginx_total" -gt 0 ] && [ "$rls_total" -eq 0 ]; then
        echo -e "${RED}🚨 ISSUE DETECTED: NGINX shows $nginx_total requests but RLS shows 0 decisions${NC}"
        echo -e "${YELLOW}This indicates traffic is not reaching the RLS service properly${NC}"
        echo -e "${CYAN}Possible causes:${NC}"
        echo -e "  1. Envoy ext_authz filter not configured correctly"
        echo -e "  2. RLS service not accessible from Envoy"
        echo -e "  3. Traffic bypassing Envoy entirely"
        echo -e "  4. NGINX routing configuration issue"
    elif [ "$nginx_total" -gt 0 ] && [ "$rls_total" -gt 0 ]; then
        echo -e "${GREEN}✅ Traffic flow appears normal${NC}"
        echo -e "  NGINX → Envoy → RLS → Mimir"
    else
        echo -e "${YELLOW}⚠️  No recent traffic detected${NC}"
    fi
}

# =================================================================
# DIAGNOSTIC CHECKS
# =================================================================

run_diagnostic_checks() {
    echo -e "${BLUE}=== DIAGNOSTIC CHECKS ===${NC}"
    
    # Check service connectivity
    echo -e "${CYAN}Checking service connectivity...${NC}"
    
    # RLS service
    if curl -s -f "${RLS_BASE_URL}/healthz" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ RLS service is accessible${NC}"
    else
        echo -e "${RED}❌ RLS service is not accessible${NC}"
    fi
    
    # Envoy service
    if curl -s -f "${ENVOY_BASE_URL}/stats" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Envoy service is accessible${NC}"
    else
        echo -e "${RED}❌ Envoy service is not accessible${NC}"
    fi
    
    # Mimir service
    if curl -s -f "${MIMIR_BASE_URL}/ready" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Mimir service is accessible${NC}"
    else
        echo -e "${RED}❌ Mimir service is not accessible${NC}"
    fi
    
    # Check NGINX configuration
    echo -e "${CYAN}Checking NGINX configuration...${NC}"
    if command -v nginx > /dev/null 2>&1; then
        if nginx -t > /dev/null 2>&1; then
            echo -e "${GREEN}✅ NGINX configuration is valid${NC}"
        else
            echo -e "${RED}❌ NGINX configuration has errors${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  NGINX not found in PATH${NC}"
    fi
}

# =================================================================
# MAIN EXECUTION
# =================================================================

main() {
    echo -e "${PURPLE}=== MIMIR EDGE ENFORCEMENT TRAFFIC FLOW MONITOR ===${NC}"
    echo -e "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo ""
    
    # Run all analysis functions
    parse_nginx_logs
    echo ""
    
    analyze_rls_metrics
    echo ""
    
    analyze_envoy_metrics
    echo ""
    
    correlate_traffic_flow
    echo ""
    
    run_diagnostic_checks
    echo ""
    
    echo -e "${GREEN}=== TRAFFIC FLOW MONITORING COMPLETE ===${NC}"
}

# Handle command line arguments
case "${1:-}" in
    "once")
        main
        ;;
    "daemon")
        echo -e "${BLUE}Starting traffic flow monitoring daemon (every 30 seconds)...${NC}"
        while true; do
            main
            echo ""
            echo -e "${CYAN}Waiting 30 seconds before next check...${NC}"
            sleep 30
        done
        ;;
    "nginx")
        parse_nginx_logs
        ;;
    "rls")
        analyze_rls_metrics
        ;;
    "envoy")
        analyze_envoy_metrics
        ;;
    "correlate")
        correlate_traffic_flow
        ;;
    "diagnose")
        run_diagnostic_checks
        ;;
    *)
        echo "Usage: $0 {once|daemon|nginx|rls|envoy|correlate|diagnose}"
        echo "  once      - Run monitoring once"
        echo "  daemon    - Run monitoring continuously every 30 seconds"
        echo "  nginx     - Analyze NGINX logs only"
        echo "  rls       - Analyze RLS metrics only"
        echo "  envoy     - Analyze Envoy metrics only"
        echo "  correlate - Correlate traffic flow only"
        echo "  diagnose  - Run diagnostic checks only"
        exit 1
        ;;
esac
