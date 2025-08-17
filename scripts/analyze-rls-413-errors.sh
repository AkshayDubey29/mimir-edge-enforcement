#!/bin/bash

# RLS 413 Error Analysis Script
# This script analyzes RLS logs to understand 413 errors, request sizes, and rejection reasons

set -e

echo "🔍 RLS 413 Error Analysis Tool"
echo "=============================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "SUCCESS") echo -e "${GREEN}✅ $message${NC}" ;;
        "ERROR") echo -e "${RED}❌ $message${NC}" ;;
        "WARNING") echo -e "${YELLOW}⚠️  $message${NC}" ;;
        "INFO") echo -e "${BLUE}ℹ️  $message${NC}" ;;
        "DEBUG") echo -e "${CYAN}🔍 $message${NC}" ;;
        "HEADER") echo -e "${PURPLE}📊 $message${NC}" ;;
    esac
}

# Function to get RLS pod name
get_rls_pod() {
    local pod=$(kubectl get pods -n mimir-edge-enforcement | grep rls | grep Running | head -n1 | awk '{print $1}')
    if [ -z "$pod" ]; then
        print_status "ERROR" "No running RLS pods found"
        exit 1
    fi
    echo $pod
}

# Function to analyze RLS configuration
analyze_rls_config() {
    print_status "HEADER" "RLS Configuration Analysis"
    echo ""
    
    local pod=$(get_rls_pod)
    print_status "INFO" "Analyzing RLS pod: $pod"
    
    # Get configuration values
    local config_log=$(kubectl logs -n mimir-edge-enforcement $pod | grep "parsed configuration values" | tail -n1)
    
    if [ -n "$config_log" ]; then
        print_status "SUCCESS" "Found RLS configuration:"
        echo "$config_log" | jq '.' 2>/dev/null || echo "$config_log"
        
        # Extract key values
        local max_body_bytes=$(echo "$config_log" | grep -o '"default_max_body_bytes":[0-9]*' | cut -d':' -f2)
        local max_request_bytes=$(echo "$config_log" | grep -o '"max_request_bytes":[0-9]*' | cut -d':' -f2)
        
        if [ -n "$max_body_bytes" ]; then
            local max_body_mb=$((max_body_bytes / 1024 / 1024))
            print_status "INFO" "Configured max body bytes: ${max_body_bytes} (${max_body_mb}MB)"
        fi
        
        if [ -n "$max_request_bytes" ]; then
            local max_request_mb=$((max_request_bytes / 1024 / 1024))
            print_status "INFO" "Configured max request bytes: ${max_request_bytes} (${max_request_mb}MB)"
        fi
    else
        print_status "WARNING" "No configuration log found"
    fi
    echo ""
}

# Function to analyze 413 errors
analyze_413_errors() {
    print_status "HEADER" "413 Error Analysis"
    echo ""
    
    local pod=$(get_rls_pod)
    
    # Get all 413-related logs
    print_status "INFO" "Searching for 413 errors in RLS logs..."
    
    # Search for different 413 error patterns
    local patterns=(
        "413"
        "request body too large"
        "body_size_exceeded"
        "labels_per_series_exceeded"
        "request_too_large"
        "deny.*413"
        "reject.*413"
    )
    
    for pattern in "${patterns[@]}"; do
        print_status "DEBUG" "Searching for pattern: $pattern"
        local matches=$(kubectl logs -n mimir-edge-enforcement $pod --tail=1000 | grep -i "$pattern" | wc -l)
        if [ $matches -gt 0 ]; then
            print_status "WARNING" "Found $matches matches for pattern: $pattern"
            
            # Show recent examples
            echo "Recent examples:"
            kubectl logs -n mimir-edge-enforcement $pod --tail=1000 | grep -i "$pattern" | tail -n3 | while read line; do
                echo "  $line"
            done
            echo ""
        fi
    done
}

# Function to analyze request sizes
analyze_request_sizes() {
    print_status "HEADER" "Request Size Analysis"
    echo ""
    
    local pod=$(get_rls_pod)
    
    # Search for request size information
    print_status "INFO" "Searching for request size information..."
    
    # Look for body size logs
    local body_size_logs=$(kubectl logs -n mimir-edge-enforcement $pod --tail=1000 | grep -E "(body.*bytes|request.*bytes|size.*bytes)" | grep -v "parsed configuration")
    
    if [ -n "$body_size_logs" ]; then
        print_status "SUCCESS" "Found request size logs:"
        echo "$body_size_logs" | tail -n10
        echo ""
        
        # Extract and analyze sizes
        echo "Size distribution:"
        echo "$body_size_logs" | grep -o '[0-9]*' | sort -n | uniq -c | tail -n10
        echo ""
    else
        print_status "INFO" "No request size logs found"
    fi
}

# Function to analyze decision logs
analyze_decision_logs() {
    print_status "HEADER" "Decision Analysis"
    echo ""
    
    local pod=$(get_rls_pod)
    
    # Search for decision logs
    print_status "INFO" "Searching for decision logs..."
    
    # Look for decision patterns
    local decision_patterns=(
        "decision.*deny"
        "decision.*allow"
        "allowed.*false"
        "allowed.*true"
        "reason.*"
    )
    
    for pattern in "${decision_patterns[@]}"; do
        print_status "DEBUG" "Searching for pattern: $pattern"
        local matches=$(kubectl logs -n mimir-edge-enforcement $pod --tail=1000 | grep -i "$pattern" | wc -l)
        if [ $matches -gt 0 ]; then
            print_status "INFO" "Found $matches matches for pattern: $pattern"
            
            # Show recent examples
            echo "Recent examples:"
            kubectl logs -n mimir-edge-enforcement $pod --tail=1000 | grep -i "$pattern" | tail -n3 | while read line; do
                echo "  $line"
            done
            echo ""
        fi
    done
}

# Function to analyze metrics
analyze_metrics() {
    print_status "HEADER" "Metrics Analysis"
    echo ""
    
    local pod=$(get_rls_pod)
    
    # Get metrics endpoint
    print_status "INFO" "Checking RLS metrics..."
    
    # Port forward to access metrics
    local port=9090
    print_status "DEBUG" "Setting up port forward to $pod:$port"
    
    # Start port forward in background
    kubectl port-forward -n mimir-edge-enforcement $pod $port:$port > /dev/null 2>&1 &
    local pf_pid=$!
    
    # Wait for port forward to be ready
    sleep 2
    
    # Get metrics
    if curl -s http://localhost:$port/metrics > /dev/null 2>&1; then
        print_status "SUCCESS" "Metrics endpoint accessible"
        
        # Get specific metrics
        local metrics=$(curl -s http://localhost:$port/metrics)
        
        # Analyze decision metrics
        echo "Decision metrics:"
        echo "$metrics" | grep -E "(decisions_total|traffic_flow_total)" | head -n10
        echo ""
        
        # Analyze limit violation metrics
        echo "Limit violation metrics:"
        echo "$metrics" | grep -E "(limit_violations_total|body_size_gauge)" | head -n10
        echo ""
        
    else
        print_status "WARNING" "Could not access metrics endpoint"
    fi
    
    # Kill port forward
    kill $pf_pid 2>/dev/null || true
}

# Function to create regex patterns for analysis
create_regex_patterns() {
    print_status "HEADER" "Regex Patterns for Analysis"
    echo ""
    
    print_status "INFO" "Use these regex patterns to analyze RLS logs:"
    echo ""
    
    echo "1. 413 Errors:"
    echo "   grep -E '(413|request body too large|body_size_exceeded)'"
    echo ""
    
    echo "2. Request Sizes:"
    echo "   grep -E '(body.*bytes|request.*bytes|size.*bytes)'"
    echo ""
    
    echo "3. Decision Logs:"
    echo "   grep -E '(decision.*deny|decision.*allow|allowed.*false|allowed.*true)'"
    echo ""
    
    echo "4. Limit Violations:"
    echo "   grep -E '(limit.*violation|exceeded|too.*large)'"
    echo ""
    
    echo "5. Tenant Information:"
    echo "   grep -E '(tenant.*ID|X-Scope-OrgID)'"
    echo ""
    
    echo "6. Request Processing:"
    echo "   grep -E '(processing.*request|parsing.*body|extracting.*body)'"
    echo ""
    
    echo "7. Error Reasons:"
    echo "   grep -E '(reason.*|error.*|fail.*)'"
    echo ""
}

# Function to provide real-time monitoring
real_time_monitoring() {
    print_status "HEADER" "Real-time 413 Error Monitoring"
    echo ""
    
    local pod=$(get_rls_pod)
    
    print_status "INFO" "Starting real-time monitoring of RLS logs for 413 errors..."
    print_status "INFO" "Press Ctrl+C to stop monitoring"
    echo ""
    
    # Monitor logs in real-time
    kubectl logs -n mimir-edge-enforcement $pod -f | grep -E "(413|deny|reject|too large|body.*size|request.*size)" | while read line; do
        timestamp=$(date '+%H:%M:%S')
        echo "[$timestamp] $line"
    done
}

# Function to provide comprehensive analysis
comprehensive_analysis() {
    print_status "HEADER" "Comprehensive RLS 413 Error Analysis"
    echo ""
    
    local pod=$(get_rls_pod)
    
    # Get all recent logs
    print_status "INFO" "Analyzing recent RLS logs..."
    
    local recent_logs=$(kubectl logs -n mimir-edge-enforcement $pod --tail=1000)
    
    # Count different types of errors
    local total_413=$(echo "$recent_logs" | grep -c "413" || echo "0")
    local total_deny=$(echo "$recent_logs" | grep -c "deny" || echo "0")
    local total_allow=$(echo "$recent_logs" | grep -c "allow" || echo "0")
    local total_reject=$(echo "$recent_logs" | grep -c "reject" || echo "0")
    
    print_status "INFO" "Summary of recent activity:"
    echo "  - 413 errors: $total_413"
    echo "  - Deny decisions: $total_deny"
    echo "  - Allow decisions: $total_allow"
    echo "  - Reject decisions: $total_reject"
    echo ""
    
    # Analyze error reasons
    print_status "INFO" "Error reason analysis:"
    echo "$recent_logs" | grep -E "(reason.*|error.*|fail.*)" | grep -v "parsed configuration" | tail -n10
    echo ""
    
    # Analyze request patterns
    print_status "INFO" "Request pattern analysis:"
    echo "$recent_logs" | grep -E "(processing.*request|parsing.*body)" | tail -n5
    echo ""
}

# Main execution
main() {
    case "${1:-all}" in
        "config")
            analyze_rls_config
            ;;
        "413")
            analyze_413_errors
            ;;
        "sizes")
            analyze_request_sizes
            ;;
        "decisions")
            analyze_decision_logs
            ;;
        "metrics")
            analyze_metrics
            ;;
        "regex")
            create_regex_patterns
            ;;
        "monitor")
            real_time_monitoring
            ;;
        "comprehensive")
            comprehensive_analysis
            ;;
        "all")
            analyze_rls_config
            analyze_413_errors
            analyze_request_sizes
            analyze_decision_logs
            create_regex_patterns
            comprehensive_analysis
            ;;
        *)
            echo "Usage: $0 [config|413|sizes|decisions|metrics|regex|monitor|comprehensive|all]"
            echo ""
            echo "Options:"
            echo "  config        - Analyze RLS configuration"
            echo "  413          - Analyze 413 errors specifically"
            echo "  sizes        - Analyze request sizes"
            echo "  decisions    - Analyze decision logs"
            echo "  metrics      - Analyze RLS metrics"
            echo "  regex        - Show regex patterns for analysis"
            echo "  monitor      - Real-time monitoring"
            echo "  comprehensive - Comprehensive analysis"
            echo "  all          - Run all analyses (default)"
            ;;
    esac
}

# Run main function
main "$@"
