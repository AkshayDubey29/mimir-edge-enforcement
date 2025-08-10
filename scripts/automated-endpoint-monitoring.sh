#!/bin/bash

# Automated Endpoint Monitoring System
# This script runs at regular intervals to validate all endpoints and their responses
# Provides comprehensive monitoring for the entire Edge Enforcement System

set -e

# Configuration
RLS_BASE_URL="http://localhost:8082"
ENVOY_BASE_URL="http://localhost:8080"
MIMIR_BASE_URL="http://localhost:9009"
UI_BASE_URL="http://localhost:3000"
OVERRIDES_SYNC_BASE_URL="http://localhost:8084"

# Logging
LOG_FILE="/tmp/endpoint-monitoring.log"
MAX_LOG_SIZE=10485760  # 10MB

# Test results storage
RESULTS_DIR="/tmp/endpoint-monitoring-results"
mkdir -p "$RESULTS_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# =================================================================
# LOGGING FUNCTIONS
# =================================================================

log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    echo -e "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
    log_message "INFO" "$1"
}

log_warn() {
    log_message "WARN" "$1"
}

log_error() {
    log_message "ERROR" "$1"
}

log_success() {
    log_message "SUCCESS" "$1"
}

# Rotate log file if it's too large
rotate_log() {
    if [ -f "$LOG_FILE" ] && [ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null) -gt $MAX_LOG_SIZE ]; then
        mv "$LOG_FILE" "${LOG_FILE}.old"
        log_info "Log file rotated"
    fi
}

# =================================================================
# ENDPOINT VALIDATION FUNCTIONS
# =================================================================

validate_endpoint() {
    local service="$1"
    local endpoint="$2"
    local url="$3"
    local method="${4:-GET}"
    local expected_status="${5:-200}"
    local timeout="${6:-10}"
    local headers="${7:-}"
    
    local start_time=$(date +%s%3N)
    local result_file="$RESULTS_DIR/${service}_${endpoint}_$(date +%Y%m%d_%H%M%S).json"
    
    # Create curl command
    local curl_cmd="curl -s -w '%{http_code}|%{time_total}|%{size_download}'"
    curl_cmd="$curl_cmd -X $method"
    curl_cmd="$curl_cmd --connect-timeout $timeout"
    curl_cmd="$curl_cmd --max-time $timeout"
    
    if [ -n "$headers" ]; then
        curl_cmd="$curl_cmd -H '$headers'"
    fi
    
    curl_cmd="$curl_cmd '$url'"
    
    # Execute request
    local response=$(eval $curl_cmd 2>/dev/null)
    local end_time=$(date +%s%3N)
    local response_time=$((end_time - start_time))
    
    # Parse response
    local http_code=$(echo "$response" | tail -c 50 | cut -d'|' -f1)
    local curl_time=$(echo "$response" | tail -c 50 | cut -d'|' -f2)
    local size=$(echo "$response" | tail -c 50 | cut -d'|' -f3)
    local body=$(echo "$response" | head -c -50)
    
    # Determine status
    local status="unknown"
    local message=""
    
    if [ -z "$http_code" ] || [ "$http_code" = "000" ]; then
        status="error"
        message="Connection failed"
    elif [ "$http_code" = "$expected_status" ]; then
        status="healthy"
        message="Endpoint responding correctly"
    else
        status="degraded"
        message="Expected status $expected_status, got $http_code"
    fi
    
    # Check response time
    if [ "$response_time" -gt 1000 ]; then
        status="degraded"
        message="$message (slow response: ${response_time}ms)"
    fi
    
    # Validate JSON for API endpoints
    if [[ "$url" == *"/api/"* ]] && [ "$http_code" = "200" ]; then
        if ! echo "$body" | jq . > /dev/null 2>&1; then
            status="error"
            message="Invalid JSON response"
        fi
    fi
    
    # Create result object
    local result=$(cat << EOF
{
  "service": "$service",
  "endpoint": "$endpoint",
  "url": "$url",
  "method": "$method",
  "status": "$status",
  "message": "$message",
  "http_code": "$http_code",
  "expected_status": "$expected_status",
  "response_time_ms": $response_time,
  "curl_time_s": "$curl_time",
  "response_size": "$size",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "headers": "$headers"
}
EOF
)
    
    # Save result
    echo "$result" > "$result_file"
    
    # Log result
    case "$status" in
        "healthy")
            log_success "$service/$endpoint: $message (${response_time}ms)"
            ;;
        "degraded")
            log_warn "$service/$endpoint: $message (${response_time}ms)"
            ;;
        "error")
            log_error "$service/$endpoint: $message (${response_time}ms)"
            ;;
    esac
    
    echo "$result"
}

# =================================================================
# SERVICE-SPECIFIC VALIDATION
# =================================================================

validate_rls_service() {
    log_info "Validating RLS Service endpoints..."
    
    local endpoints=(
        "healthz:${RLS_BASE_URL}/healthz:GET:200"
        "readyz:${RLS_BASE_URL}/readyz:GET:200"
        "api_health:${RLS_BASE_URL}/api/health:GET:200"
        "api_overview:${RLS_BASE_URL}/api/overview:GET:200"
        "api_tenants:${RLS_BASE_URL}/api/tenants:GET:200"
        "api_flow_status:${RLS_BASE_URL}/api/flow/status:GET:200"
        "api_system_status:${RLS_BASE_URL}/api/system/status:GET:200"
        "api_pipeline_status:${RLS_BASE_URL}/api/pipeline/status:GET:200"
        "api_system_metrics:${RLS_BASE_URL}/api/metrics/system:GET:200"
        "api_denials:${RLS_BASE_URL}/api/denials:GET:200"
        "api_export_csv:${RLS_BASE_URL}/api/export/csv:GET:200"
    )
    
    for endpoint_spec in "${endpoints[@]}"; do
        IFS=':' read -r name url method expected_status <<< "$endpoint_spec"
        validate_endpoint "rls" "$name" "$url" "$method" "$expected_status"
    done
}

validate_envoy_service() {
    log_info "Validating Envoy Proxy endpoints..."
    
    local endpoints=(
        "admin_stats:${ENVOY_BASE_URL}/stats:GET:200"
        "admin_health:${ENVOY_BASE_URL}/health:GET:200"
        "ext_authz:${ENVOY_BASE_URL}:8081/health:GET:200"
        "ratelimit:${ENVOY_BASE_URL}:8083/health:GET:200"
    )
    
    for endpoint_spec in "${endpoints[@]}"; do
        IFS=':' read -r name url method expected_status <<< "$endpoint_spec"
        validate_endpoint "envoy" "$name" "$url" "$method" "$expected_status"
    done
}

validate_mimir_service() {
    log_info "Validating Mimir Backend endpoints..."
    
    local endpoints=(
        "ready:${MIMIR_BASE_URL}/ready:GET:200"
        "health:${MIMIR_BASE_URL}/health:GET:200"
        "metrics:${MIMIR_BASE_URL}/metrics:GET:200"
        "remote_write:${MIMIR_BASE_URL}/api/v1/push:GET:405"
    )
    
    for endpoint_spec in "${endpoints[@]}"; do
        IFS=':' read -r name url method expected_status <<< "$endpoint_spec"
        validate_endpoint "mimir" "$name" "$url" "$method" "$expected_status"
    done
}

validate_ui_service() {
    log_info "Validating UI endpoints..."
    
    local endpoints=(
        "overview:${UI_BASE_URL}/:GET:200"
        "tenants:${UI_BASE_URL}/tenants:GET:200"
        "denials:${UI_BASE_URL}/denials:GET:200"
        "health:${UI_BASE_URL}/health:GET:200"
        "pipeline:${UI_BASE_URL}/pipeline:GET:200"
        "metrics:${UI_BASE_URL}/metrics:GET:200"
    )
    
    for endpoint_spec in "${endpoints[@]}"; do
        IFS=':' read -r name url method expected_status <<< "$endpoint_spec"
        validate_endpoint "ui" "$name" "$url" "$method" "$expected_status"
    done
}

validate_overrides_sync_service() {
    log_info "Validating Overrides Sync Service endpoints..."
    
    local endpoints=(
        "health:${OVERRIDES_SYNC_BASE_URL}/health:GET:200"
        "ready:${OVERRIDES_SYNC_BASE_URL}/ready:GET:200"
        "metrics:${OVERRIDES_SYNC_BASE_URL}/metrics:GET:200"
    )
    
    for endpoint_spec in "${endpoints[@]}"; do
        IFS=':' read -r name url method expected_status <<< "$endpoint_spec"
        validate_endpoint "overrides_sync" "$name" "$url" "$method" "$expected_status"
    done
}

# =================================================================
# DATA VALIDATION FUNCTIONS
# =================================================================

validate_api_responses() {
    log_info "Validating API response structures..."
    
    # Validate overview endpoint
    local overview_response=$(curl -s "${RLS_BASE_URL}/api/overview" 2>/dev/null)
    if [ $? -eq 0 ]; then
        local required_fields=("stats" "total_requests" "allowed_requests" "denied_requests")
        for field in "${required_fields[@]}"; do
            if ! echo "$overview_response" | jq -e ".$field" > /dev/null 2>&1; then
                log_error "Overview API missing required field: $field"
            else
                log_success "Overview API field validated: $field"
            fi
        done
    fi
    
    # Validate tenants endpoint
    local tenants_response=$(curl -s "${RLS_BASE_URL}/api/tenants" 2>/dev/null)
    if [ $? -eq 0 ]; then
        if ! echo "$tenants_response" | jq -e ".tenants" > /dev/null 2>&1; then
            log_error "Tenants API missing tenants array"
        else
            log_success "Tenants API structure validated"
        fi
    fi
    
    # Validate flow status endpoint
    local flow_response=$(curl -s "${RLS_BASE_URL}/api/flow/status" 2>/dev/null)
    if [ $? -eq 0 ]; then
        local required_fields=("flow_status" "health_checks" "flow_metrics")
        for field in "${required_fields[@]}"; do
            if ! echo "$flow_response" | jq -e ".$field" > /dev/null 2>&1; then
                log_error "Flow status API missing required field: $field"
            else
                log_success "Flow status API field validated: $field"
            fi
        done
    fi
}

# =================================================================
# PERFORMANCE VALIDATION
# =================================================================

validate_performance() {
    log_info "Validating performance metrics..."
    
    # Test response times for critical endpoints
    local critical_endpoints=(
        "${RLS_BASE_URL}/api/overview"
        "${RLS_BASE_URL}/api/tenants"
        "${RLS_BASE_URL}/api/flow/status"
        "${RLS_BASE_URL}/healthz"
    )
    
    for endpoint in "${critical_endpoints[@]}"; do
        local start_time=$(date +%s%3N)
        curl -s "$endpoint" > /dev/null 2>&1
        local end_time=$(date +%s%3N)
        local response_time=$((end_time - start_time))
        
        if [ $response_time -lt 500 ]; then
            log_success "Performance OK: $endpoint (${response_time}ms)"
        elif [ $response_time -lt 1000 ]; then
            log_warn "Performance degraded: $endpoint (${response_time}ms)"
        else
            log_error "Performance critical: $endpoint (${response_time}ms)"
        fi
    done
}

# =================================================================
# SUMMARY AND REPORTING
# =================================================================

generate_summary_report() {
    log_info "Generating summary report..."
    
    local report_file="$RESULTS_DIR/summary_$(date +%Y%m%d_%H%M%S).json"
    local healthy_count=0
    local degraded_count=0
    local error_count=0
    local total_count=0
    
    # Count results from all result files
    for result_file in "$RESULTS_DIR"/*.json; do
        if [ -f "$result_file" ] && [[ "$result_file" != *"summary_"* ]]; then
            local status=$(jq -r '.status' "$result_file" 2>/dev/null)
            case "$status" in
                "healthy")
                    ((healthy_count++))
                    ;;
                "degraded")
                    ((degraded_count++))
                    ;;
                "error")
                    ((error_count++))
                    ;;
            esac
            ((total_count++))
        fi
    done
    
    # Calculate health percentage
    local health_percentage=0
    if [ $total_count -gt 0 ]; then
        health_percentage=$(echo "scale=2; $healthy_count * 100 / $total_count" | bc -l 2>/dev/null || echo "0")
    fi
    
    # Determine overall status
    local overall_status="unknown"
    if [ $total_count -eq 0 ]; then
        overall_status="unknown"
    elif [ $error_count -gt $((total_count / 2)) ]; then
        overall_status="critical"
    elif [ $degraded_count -gt 0 ] || [ $error_count -gt 0 ]; then
        overall_status="degraded"
    else
        overall_status="healthy"
    fi
    
    # Generate summary
    local summary=$(cat << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "overall_status": "$overall_status",
  "health_percentage": $health_percentage,
  "total_endpoints": $total_count,
  "healthy_endpoints": $healthy_count,
  "degraded_endpoints": $degraded_count,
  "error_endpoints": $error_count,
  "services": {
    "rls": {
      "status": "$(get_service_status rls)",
      "endpoints_checked": $(count_service_endpoints rls)
    },
    "envoy": {
      "status": "$(get_service_status envoy)",
      "endpoints_checked": $(count_service_endpoints envoy)
    },
    "mimir": {
      "status": "$(get_service_status mimir)",
      "endpoints_checked": $(count_service_endpoints mimir)
    },
    "ui": {
      "status": "$(get_service_status ui)",
      "endpoints_checked": $(count_service_endpoints ui)
    },
    "overrides_sync": {
      "status": "$(get_service_status overrides_sync)",
      "endpoints_checked": $(count_service_endpoints overrides_sync)
    }
  }
}
EOF
)
    
    echo "$summary" > "$report_file"
    
    # Log summary
    log_info "=== ENDPOINT MONITORING SUMMARY ==="
    log_info "Overall Status: $overall_status"
    log_info "Health Percentage: ${health_percentage}%"
    log_info "Total Endpoints: $total_count"
    log_info "Healthy: $healthy_count, Degraded: $degraded_count, Errors: $error_count"
    
    if [ "$overall_status" = "healthy" ]; then
        log_success "All systems operational!"
    elif [ "$overall_status" = "degraded" ]; then
        log_warn "Some issues detected - review logs"
    else
        log_error "Critical issues detected - immediate attention required!"
    fi
    
    echo "$summary"
}

get_service_status() {
    local service="$1"
    local healthy=0
    local total=0
    
    for result_file in "$RESULTS_DIR"/${service}_*.json; do
        if [ -f "$result_file" ]; then
            local status=$(jq -r '.status' "$result_file" 2>/dev/null)
            ((total++))
            if [ "$status" = "healthy" ]; then
                ((healthy++))
            fi
        fi
    done
    
    if [ $total -eq 0 ]; then
        echo "unknown"
    elif [ $healthy -eq $total ]; then
        echo "healthy"
    elif [ $healthy -gt 0 ]; then
        echo "degraded"
    else
        echo "critical"
    fi
}

count_service_endpoints() {
    local service="$1"
    local count=0
    
    for result_file in "$RESULTS_DIR"/${service}_*.json; do
        if [ -f "$result_file" ]; then
            ((count++))
        fi
    done
    
    echo $count
}

# =================================================================
# CLEANUP FUNCTIONS
# =================================================================

cleanup_old_results() {
    # Keep only last 24 hours of results
    find "$RESULTS_DIR" -name "*.json" -mtime +1 -delete 2>/dev/null || true
    log_info "Cleaned up old result files"
}

# =================================================================
# MAIN EXECUTION
# =================================================================

main() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    log_info "=== STARTING AUTOMATED ENDPOINT MONITORING ==="
    log_info "Timestamp: $timestamp"
    
    # Rotate log if needed
    rotate_log
    
    # Clean up old results
    cleanup_old_results
    
    # Validate all services
    validate_rls_service
    validate_envoy_service
    validate_mimir_service
    validate_ui_service
    validate_overrides_sync_service
    
    # Validate API responses
    validate_api_responses
    
    # Validate performance
    validate_performance
    
    # Generate summary report
    local summary=$(generate_summary_report)
    
    # Send summary to RLS for integration
    if command -v curl > /dev/null 2>&1; then
        echo "$summary" | curl -s -X POST \
            -H "Content-Type: application/json" \
            -d @- \
            "${RLS_BASE_URL}/api/monitoring/report" > /dev/null 2>&1 || true
    fi
    
    log_info "=== ENDPOINT MONITORING COMPLETE ==="
}

# Handle command line arguments
case "${1:-}" in
    "once")
        main
        ;;
    "daemon")
        log_info "Starting daemon mode - monitoring every 30 seconds"
        while true; do
            main
            sleep 30
        done
        ;;
    "cleanup")
        cleanup_old_results
        ;;
    *)
        echo "Usage: $0 {once|daemon|cleanup}"
        echo "  once    - Run monitoring once"
        echo "  daemon  - Run monitoring continuously every 30 seconds"
        echo "  cleanup - Clean up old result files"
        exit 1
        ;;
esac
