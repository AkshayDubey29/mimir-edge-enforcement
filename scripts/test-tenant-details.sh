#!/bin/bash

# Test script for Tenant Details API with time-based data
# This script tests the enhanced tenant details API that now supports time ranges

set -e

echo "🧪 Testing Tenant Details API with Time-Based Data"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "SUCCESS")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "ERROR")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
    esac
}

# Function to check if a service is running
check_service() {
    local port=$1
    local service_name=$2
    
    if curl -s "http://localhost:$port/healthz" > /dev/null 2>&1; then
        print_status "SUCCESS" "$service_name is running on port $port"
        return 0
    else
        print_status "ERROR" "$service_name is not running on port $port"
        return 1
    fi
}

# Function to test tenant details API
test_tenant_details() {
    local tenant_id=$1
    local time_range=$2
    local expected_status=$3
    
    echo -e "\n${BLUE}Testing tenant details for '$tenant_id' with time range '$time_range'${NC}"
    
    local response
    local status_code
    
    # Make API call
    response=$(curl -s -w "%{http_code}" "http://localhost:8082/api/tenants/$tenant_id?range=$time_range" -o /tmp/tenant_response.json)
    status_code="${response: -3}"
    
    echo "Status Code: $status_code"
    
    if [ "$status_code" = "$expected_status" ]; then
        print_status "SUCCESS" "Expected status code $expected_status received"
        
        if [ "$status_code" = "200" ]; then
            # Check response structure
            if jq -e '.tenant' /tmp/tenant_response.json > /dev/null 2>&1; then
                print_status "SUCCESS" "Response contains tenant data"
            else
                print_status "ERROR" "Response missing tenant data"
                return 1
            fi
            
            if jq -e '.time_range' /tmp/tenant_response.json > /dev/null 2>&1; then
                print_status "SUCCESS" "Response contains time_range field"
            else
                print_status "ERROR" "Response missing time_range field"
                return 1
            fi
            
            if jq -e '.data_freshness' /tmp/tenant_response.json > /dev/null 2>&1; then
                print_status "SUCCESS" "Response contains data_freshness field"
            else
                print_status "ERROR" "Response missing data_freshness field"
                return 1
            fi
            
            if jq -e '.request_history' /tmp/tenant_response.json > /dev/null 2>&1; then
                print_status "SUCCESS" "Response contains request_history field"
            else
                print_status "ERROR" "Response missing request_history field"
                return 1
            fi
            
            # Display some key metrics
            local tenant_id_response=$(jq -r '.tenant.id' /tmp/tenant_response.json)
            local samples_per_sec=$(jq -r '.tenant.metrics.samples_per_sec' /tmp/tenant_response.json)
            local allow_rate=$(jq -r '.tenant.metrics.allow_rate' /tmp/tenant_response.json)
            local deny_rate=$(jq -r '.tenant.metrics.deny_rate' /tmp/tenant_response.json)
            local utilization=$(jq -r '.tenant.metrics.utilization_pct' /tmp/tenant_response.json)
            
            echo "  Tenant ID: $tenant_id_response"
            echo "  Samples/sec: $samples_per_sec"
            echo "  Allow Rate: $allow_rate"
            echo "  Deny Rate: $deny_rate"
            echo "  Utilization: $utilization%"
            
        fi
    else
        print_status "ERROR" "Expected status code $expected_status, got $status_code"
        return 1
    fi
    
    return 0
}

# Function to test data stability
test_data_stability() {
    local tenant_id=$1
    local time_range=$2
    local iterations=$3
    
    echo -e "\n${BLUE}Testing data stability for '$tenant_id' with time range '$time_range' ($iterations iterations)${NC}"
    
    local first_response=""
    local all_same=true
    
    for i in $(seq 1 $iterations); do
        local response=$(curl -s "http://localhost:8082/api/tenants/$tenant_id?range=$time_range" | jq -c '.tenant.metrics')
        
        if [ "$i" = "1" ]; then
            first_response="$response"
        elif [ "$response" != "$first_response" ]; then
            all_same=false
            print_status "WARNING" "Data changed between iteration 1 and $i"
            break
        fi
        
        echo -n "."
        sleep 0.1
    done
    
    echo ""
    
    if [ "$all_same" = true ]; then
        print_status "SUCCESS" "Data remained stable across $iterations iterations"
    else
        print_status "WARNING" "Data was not stable across $iterations iterations"
    fi
}

# Main test execution
main() {
    echo "Starting tenant details API tests..."
    
    # Check if RLS service is running
    if ! check_service 8082 "RLS Admin Server"; then
        print_status "ERROR" "Please start the RLS service first"
        exit 1
    fi
    
    # Test with different time ranges
    print_status "INFO" "Testing with different time ranges..."
    
    # Test with a known tenant (adjust as needed)
    local test_tenant="test-tenant"
    
    # Test different time ranges
    for time_range in "15m" "1h" "24h" "1w"; do
        test_tenant_details "$test_tenant" "$time_range" "200"
    done
    
    # Test with invalid tenant
    test_tenant_details "non-existent-tenant" "24h" "404"
    
    # Test data stability
    test_data_stability "$test_tenant" "24h" 5
    
    # Test cache effectiveness
    echo -e "\n${BLUE}Testing cache effectiveness...${NC}"
    local start_time=$(date +%s%N)
    curl -s "http://localhost:8082/api/tenants/$test_tenant?range=24h" > /dev/null
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))
    
    if [ "$duration" -lt 100 ]; then
        print_status "SUCCESS" "API response time: ${duration}ms (cached response)"
    else
        print_status "INFO" "API response time: ${duration}ms (uncached response)"
    fi
    
    print_status "SUCCESS" "All tenant details API tests completed!"
}

# Run the tests
main "$@"
