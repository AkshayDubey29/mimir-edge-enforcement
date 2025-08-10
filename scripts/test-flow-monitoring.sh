#!/bin/bash

# Test Flow Monitoring Dashboard
# This script validates the comprehensive flow monitoring functionality

set -e

echo "🧪 TESTING FLOW MONITORING DASHBOARD"
echo "===================================="

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
TEST_RESULTS=()

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# =================================================================
# TEST FUNCTIONS
# =================================================================

run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_status="$3"
    
    echo -e "${BLUE}Running: $test_name${NC}"
    
    if eval "$test_command" > /dev/null 2>&1; then
        if [ "$expected_status" = "success" ]; then
            echo -e "  ${GREEN}✅ PASSED${NC}"
            ((TESTS_PASSED++))
            TEST_RESULTS+=("✅ $test_name")
        else
            echo -e "  ${RED}❌ FAILED (expected failure but got success)${NC}"
            ((TESTS_FAILED++))
            TEST_RESULTS+=("❌ $test_name")
        fi
    else
        if [ "$expected_status" = "failure" ]; then
            echo -e "  ${GREEN}✅ PASSED (expected failure)${NC}"
            ((TESTS_PASSED++))
            TEST_RESULTS+=("✅ $test_name")
        else
            echo -e "  ${RED}❌ FAILED${NC}"
            ((TESTS_FAILED++))
            TEST_RESULTS+=("❌ $test_name")
        fi
    fi
    echo ""
}

# =================================================================
# API ENDPOINT TESTS
# =================================================================

test_rls_health() {
    echo -e "${PURPLE}Testing RLS Health Endpoints${NC}"
    echo "================================"
    
    run_test "RLS Health Check" "curl -s -f '${RLS_BASE_URL}/healthz' > /dev/null" "success"
    run_test "RLS Ready Check" "curl -s -f '${RLS_BASE_URL}/readyz' > /dev/null" "success"
    run_test "RLS Admin Health" "curl -s -f '${RLS_BASE_URL}/api/health' > /dev/null" "success"
}

test_flow_status_api() {
    echo -e "${PURPLE}Testing Flow Status API${NC}"
    echo "============================="
    
    run_test "Flow Status Endpoint" "curl -s -f '${RLS_BASE_URL}/api/flow/status' > /dev/null" "success"
    
    # Test JSON structure
    local flow_response=$(curl -s "${RLS_BASE_URL}/api/flow/status" 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo -e "${BLUE}Validating Flow Status JSON Structure${NC}"
        
        # Check required fields
        local has_flow_status=$(echo "$flow_response" | jq -r '.flow_status' 2>/dev/null)
        local has_health_checks=$(echo "$flow_response" | jq -r '.health_checks' 2>/dev/null)
        local has_flow_metrics=$(echo "$flow_response" | jq -r '.flow_metrics' 2>/dev/null)
        
        if [ "$has_flow_status" != "null" ] && [ -n "$has_flow_status" ]; then
            echo -e "  ${GREEN}✅ flow_status field present${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "  ${RED}❌ flow_status field missing${NC}"
            ((TESTS_FAILED++))
        fi
        
        if [ "$has_health_checks" != "null" ] && [ -n "$has_health_checks" ]; then
            echo -e "  ${GREEN}✅ health_checks field present${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "  ${RED}❌ health_checks field missing${NC}"
            ((TESTS_FAILED++))
        fi
        
        if [ "$has_flow_metrics" != "null" ] && [ -n "$has_flow_metrics" ]; then
            echo -e "  ${GREEN}✅ flow_metrics field present${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "  ${RED}❌ flow_metrics field missing${NC}"
            ((TESTS_FAILED++))
        fi
        
        # Check component statuses
        local components=("nginx" "envoy" "rls" "overrides_sync" "mimir")
        for component in "${components[@]}"; do
            local component_status=$(echo "$flow_response" | jq -r ".flow_status.components.$component.status" 2>/dev/null)
            if [ "$component_status" != "null" ] && [ -n "$component_status" ]; then
                echo -e "  ${GREEN}✅ $component status: $component_status${NC}"
                ((TESTS_PASSED++))
            else
                echo -e "  ${RED}❌ $component status missing${NC}"
                ((TESTS_FAILED++))
            fi
        done
        
        # Check overall status
        local overall_status=$(echo "$flow_response" | jq -r '.flow_status.overall' 2>/dev/null)
        if [ "$overall_status" != "null" ] && [ -n "$overall_status" ]; then
            echo -e "  ${GREEN}✅ Overall status: $overall_status${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "  ${RED}❌ Overall status missing${NC}"
            ((TESTS_FAILED++))
        fi
        
    else
        echo -e "  ${RED}❌ Could not fetch flow status${NC}"
        ((TESTS_FAILED++))
    fi
    echo ""
}

test_overview_api() {
    echo -e "${PURPLE}Testing Overview API${NC}"
    echo "========================"
    
    run_test "Overview Endpoint" "curl -s -f '${RLS_BASE_URL}/api/overview' > /dev/null" "success"
    
    # Test overview data structure
    local overview_response=$(curl -s "${RLS_BASE_URL}/api/overview" 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo -e "${BLUE}Validating Overview Data Structure${NC}"
        
        local has_stats=$(echo "$overview_response" | jq -r '.stats' 2>/dev/null)
        if [ "$has_stats" != "null" ] && [ -n "$has_stats" ]; then
            echo -e "  ${GREEN}✅ stats field present${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "  ${RED}❌ stats field missing${NC}"
            ((TESTS_FAILED++))
        fi
        
        local total_requests=$(echo "$overview_response" | jq -r '.stats.total_requests' 2>/dev/null)
        echo -e "  ${CYAN}Total requests: $total_requests${NC}"
        
    else
        echo -e "  ${RED}❌ Could not fetch overview data${NC}"
        ((TESTS_FAILED++))
    fi
    echo ""
}

test_tenants_api() {
    echo -e "${PURPLE}Testing Tenants API${NC}"
    echo "======================="
    
    run_test "Tenants List Endpoint" "curl -s -f '${RLS_BASE_URL}/api/tenants' > /dev/null" "success"
    
    # Test tenants data structure
    local tenants_response=$(curl -s "${RLS_BASE_URL}/api/tenants" 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo -e "${BLUE}Validating Tenants Data Structure${NC}"
        
        local has_tenants=$(echo "$tenants_response" | jq -r '.tenants' 2>/dev/null)
        if [ "$has_tenants" != "null" ] && [ -n "$has_tenants" ]; then
            echo -e "  ${GREEN}✅ tenants array present${NC}"
            ((TESTS_PASSED++))
            
            local tenant_count=$(echo "$tenants_response" | jq -r '.tenants | length' 2>/dev/null)
            echo -e "  ${CYAN}Tenant count: $tenant_count${NC}"
            
            if [ "$tenant_count" -gt 0 ]; then
                # Test individual tenant endpoint
                local first_tenant_id=$(echo "$tenants_response" | jq -r '.tenants[0].id' 2>/dev/null)
                if [ "$first_tenant_id" != "null" ] && [ -n "$first_tenant_id" ]; then
                    run_test "Individual Tenant Endpoint" "curl -s -f '${RLS_BASE_URL}/api/tenants/$first_tenant_id' > /dev/null" "success"
                fi
            fi
        else
            echo -e "  ${RED}❌ tenants array missing${NC}"
            ((TESTS_FAILED++))
        fi
        
    else
        echo -e "  ${RED}❌ Could not fetch tenants data${NC}"
        ((TESTS_FAILED++))
    fi
    echo ""
}

# =================================================================
# FLOW MONITORING SCRIPT TESTS
# =================================================================

test_flow_monitoring_script() {
    echo -e "${PURPLE}Testing Flow Monitoring Script${NC}"
    echo "====================================="
    
    # Test script exists and is executable
    if [ -f "scripts/flow-monitoring-dashboard.sh" ]; then
        echo -e "  ${GREEN}✅ Flow monitoring script exists${NC}"
        ((TESTS_PASSED++))
        
        if [ -x "scripts/flow-monitoring-dashboard.sh" ]; then
            echo -e "  ${GREEN}✅ Flow monitoring script is executable${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "  ${RED}❌ Flow monitoring script is not executable${NC}"
            ((TESTS_FAILED++))
        fi
    else
        echo -e "  ${RED}❌ Flow monitoring script not found${NC}"
        ((TESTS_FAILED++))
    fi
    
    # Test script help/usage
    if ./scripts/flow-monitoring-dashboard.sh --help > /dev/null 2>&1 || ./scripts/flow-monitoring-dashboard.sh > /dev/null 2>&1; then
        echo -e "  ${GREEN}✅ Flow monitoring script runs without errors${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}❌ Flow monitoring script has errors${NC}"
        ((TESTS_FAILED++))
    fi
    
    # Test JSON output
    local json_output=$(./scripts/flow-monitoring-dashboard.sh --json 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$json_output" ]; then
        echo -e "  ${GREEN}✅ Flow monitoring script produces JSON output${NC}"
        ((TESTS_PASSED++))
        
        # Validate JSON structure
        if echo "$json_output" | jq . > /dev/null 2>&1; then
            echo -e "  ${GREEN}✅ JSON output is valid${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "  ${RED}❌ JSON output is invalid${NC}"
            ((TESTS_FAILED++))
        fi
    else
        echo -e "  ${RED}❌ Flow monitoring script JSON output failed${NC}"
        ((TESTS_FAILED++))
    fi
    echo ""
}

# =================================================================
# UI INTEGRATION TESTS
# =================================================================

test_ui_integration() {
    echo -e "${PURPLE}Testing UI Integration${NC}"
    echo "========================"
    
    # Check if UI files exist
    if [ -f "ui/admin/src/pages/Overview.tsx" ]; then
        echo -e "  ${GREEN}✅ Overview page exists${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}❌ Overview page not found${NC}"
        ((TESTS_FAILED++))
    fi
    
    # Check for flow status interfaces
    if grep -q "interface FlowStatus" ui/admin/src/pages/Overview.tsx; then
        echo -e "  ${GREEN}✅ FlowStatus interface defined${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}❌ FlowStatus interface missing${NC}"
        ((TESTS_FAILED++))
    fi
    
    # Check for health checks interface
    if grep -q "interface HealthChecks" ui/admin/src/pages/Overview.tsx; then
        echo -e "  ${GREEN}✅ HealthChecks interface defined${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}❌ HealthChecks interface missing${NC}"
        ((TESTS_FAILED++))
    fi
    
    # Check for flow status API call
    if grep -q "/api/flow/status" ui/admin/src/pages/Overview.tsx; then
        echo -e "  ${GREEN}✅ Flow status API integration present${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}❌ Flow status API integration missing${NC}"
        ((TESTS_FAILED++))
    fi
    
    # Check for status badges
    if grep -q "StatusBadge" ui/admin/src/pages/Overview.tsx; then
        echo -e "  ${GREEN}✅ Status badges integrated${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}❌ Status badges missing${NC}"
        ((TESTS_FAILED++))
    fi
    echo ""
}

# =================================================================
# BACKEND INTEGRATION TESTS
# =================================================================

test_backend_integration() {
    echo -e "${PURPLE}Testing Backend Integration${NC}"
    echo "================================"
    
    # Check if RLS service has flow status method
    if grep -q "GetFlowStatus" services/rls/internal/service/rls.go; then
        echo -e "  ${GREEN}✅ GetFlowStatus method exists${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}❌ GetFlowStatus method missing${NC}"
        ((TESTS_FAILED++))
    fi
    
    # Check if flow status handler exists
    if grep -q "handleFlowStatus" services/rls/cmd/rls/main.go; then
        echo -e "  ${GREEN}✅ handleFlowStatus handler exists${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}❌ handleFlowStatus handler missing${NC}"
        ((TESTS_FAILED++))
    fi
    
    # Check if flow status route is registered
    if grep -q "/api/flow/status" services/rls/cmd/rls/main.go; then
        echo -e "  ${GREEN}✅ Flow status route registered${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}❌ Flow status route not registered${NC}"
        ((TESTS_FAILED++))
    fi
    echo ""
}

# =================================================================
# PERFORMANCE TESTS
# =================================================================

test_performance() {
    echo -e "${PURPLE}Testing Performance${NC}"
    echo "====================="
    
    # Test API response times
    local start_time=$(date +%s%3N)
    curl -s "${RLS_BASE_URL}/api/flow/status" > /dev/null 2>&1
    local end_time=$(date +%s%3N)
    local response_time=$((end_time - start_time))
    
    if [ $response_time -lt 1000 ]; then
        echo -e "  ${GREEN}✅ Flow status API response time: ${response_time}ms (good)${NC}"
        ((TESTS_PASSED++))
    elif [ $response_time -lt 5000 ]; then
        echo -e "  ${YELLOW}⚠️  Flow status API response time: ${response_time}ms (acceptable)${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}❌ Flow status API response time: ${response_time}ms (slow)${NC}"
        ((TESTS_FAILED++))
    fi
    
    # Test overview API response time
    start_time=$(date +%s%3N)
    curl -s "${RLS_BASE_URL}/api/overview" > /dev/null 2>&1
    end_time=$(date +%s%3N)
    response_time=$((end_time - start_time))
    
    if [ $response_time -lt 1000 ]; then
        echo -e "  ${GREEN}✅ Overview API response time: ${response_time}ms (good)${NC}"
        ((TESTS_PASSED++))
    elif [ $response_time -lt 5000 ]; then
        echo -e "  ${YELLOW}⚠️  Overview API response time: ${response_time}ms (acceptable)${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}❌ Overview API response time: ${response_time}ms (slow)${NC}"
        ((TESTS_FAILED++))
    fi
    echo ""
}

# =================================================================
# MAIN EXECUTION
# =================================================================

main() {
    echo -e "${BLUE}Starting comprehensive flow monitoring tests...${NC}"
    echo ""
    
    # Check if RLS service is running
    if ! curl -s -f "${RLS_BASE_URL}/healthz" > /dev/null 2>&1; then
        echo -e "${RED}❌ RLS service not running${NC}"
        echo -e "${YELLOW}Please start the RLS service first:${NC}"
        echo -e "  cd services/rls"
        echo -e "  ./rls"
        echo -e "  # Or in another terminal:"
        echo -e "  kubectl port-forward -n mimir-edge-enforcement svc/rls 8082:8082"
        exit 1
    fi
    
    echo -e "${GREEN}✅ RLS service is running${NC}"
    echo ""
    
    # Run all test suites
    test_rls_health
    test_flow_status_api
    test_overview_api
    test_tenants_api
    test_flow_monitoring_script
    test_ui_integration
    test_backend_integration
    test_performance
    
    # Summary
    echo -e "${PURPLE}TEST SUMMARY${NC}"
    echo "============"
    echo -e "Total tests: $((TESTS_PASSED + TESTS_FAILED))"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}🎉 ALL TESTS PASSED!${NC}"
        echo -e "${CYAN}Flow monitoring dashboard is working correctly.${NC}"
    else
        echo -e "${YELLOW}⚠️  Some tests failed. Please review the results above.${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}Detailed test results:${NC}"
    for result in "${TEST_RESULTS[@]}"; do
        echo "  $result"
    done
    
    echo ""
    echo -e "${GREEN}🧪 TESTING COMPLETE!${NC}"
}

# Run main function
main "$@"
