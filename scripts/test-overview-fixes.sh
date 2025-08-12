#!/bin/bash

# Test script for Overview Page Fixes
# This script tests the fixes for top tenant RPS, RLS endpoint status, flow timeline, and data consistency

set -e

echo "🧪 Testing Overview Page Fixes"
echo "================================"

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

# Function to test top tenant RPS data
test_top_tenant_rps() {
    local time_range=$1
    
    echo -e "\n${BLUE}Testing Top Tenant RPS data for time range '$time_range'${NC}"
    
    local response
    local status_code
    
    # Make API call
    response=$(curl -s -w "%{http_code}" "http://localhost:8082/api/tenants?range=$time_range" -o /tmp/tenants_response.json)
    status_code="${response: -3}"
    
    echo "Status Code: $status_code"
    
    if [ "$status_code" = "200" ]; then
        print_status "SUCCESS" "Tenants API returned 200"
        
        # Check if tenants have RPS data
        local tenants_with_rps=$(jq -r '.tenants[] | select(.metrics.rps > 0) | .id' /tmp/tenants_response.json | wc -l)
        local total_tenants=$(jq -r '.tenants | length' /tmp/tenants_response.json)
        
        echo "Total tenants: $total_tenants"
        echo "Tenants with RPS > 0: $tenants_with_rps"
        
        if [ "$tenants_with_rps" -gt 0 ]; then
            print_status "SUCCESS" "Found $tenants_with_rps tenants with RPS data"
            
            # Check for unique RPS values
            local unique_rps=$(jq -r '.tenants[] | select(.metrics.rps > 0) | .metrics.rps' /tmp/tenants_response.json | sort -u | wc -l)
            echo "Unique RPS values: $unique_rps"
            
            if [ "$unique_rps" -gt 1 ]; then
                print_status "SUCCESS" "RPS values are unique (not all the same)"
            else
                print_status "WARNING" "All tenants have the same RPS value"
            fi
            
            # Display top 3 tenants by RPS
            echo "Top 3 tenants by RPS:"
            jq -r '.tenants[] | select(.metrics.rps > 0) | "  \(.id): \(.metrics.rps) RPS"' /tmp/tenants_response.json | sort -k3 -nr | head -3
            
        else
            print_status "WARNING" "No tenants with RPS data found"
        fi
        
    else
        print_status "ERROR" "Expected status code 200, got $status_code"
        return 1
    fi
    
    return 0
}

# Function to test RLS endpoint status
test_rls_endpoint_status() {
    echo -e "\n${BLUE}Testing RLS Endpoint Status${NC}"
    
    local endpoints=(
        "/api/health"
        "/api/ready"
        "/api/overview"
        "/api/tenants"
        "/api/debug/traffic-flow"
    )
    
    local all_healthy=true
    
    for endpoint in "${endpoints[@]}"; do
        echo -n "Testing $endpoint... "
        
        local start_time=$(date +%s%N)
        local response=$(curl -s -w "%{http_code}" "http://localhost:8082$endpoint" -o /tmp/endpoint_response.json)
        local end_time=$(date +%s%N)
        local duration=$(( (end_time - start_time) / 1000000 ))
        local status_code="${response: -3}"
        
        if [ "$status_code" = "200" ]; then
            print_status "SUCCESS" "✅ $endpoint (${duration}ms)"
        else
            print_status "ERROR" "❌ $endpoint returned $status_code"
            all_healthy=false
        fi
    done
    
    if [ "$all_healthy" = true ]; then
        print_status "SUCCESS" "All RLS endpoints are healthy"
    else
        print_status "ERROR" "Some RLS endpoints are unhealthy"
        return 1
    fi
    
    return 0
}

# Function to test flow timeline data
test_flow_timeline() {
    local time_range=$1
    
    echo -e "\n${BLUE}Testing Flow Timeline data for time range '$time_range'${NC}"
    
    local response
    local status_code
    
    # Make API call
    response=$(curl -s -w "%{http_code}" "http://localhost:8082/api/timeseries/$time_range/flow" -o /tmp/flow_timeline.json)
    status_code="${response: -3}"
    
    echo "Status Code: $status_code"
    
    if [ "$status_code" = "200" ]; then
        print_status "SUCCESS" "Flow timeline API returned 200"
        
        # Check response structure
        if jq -e '.points' /tmp/flow_timeline.json > /dev/null 2>&1; then
            print_status "SUCCESS" "Response contains points array"
        else
            print_status "ERROR" "Response missing points array"
            return 1
        fi
        
        if jq -e '.time_range' /tmp/flow_timeline.json > /dev/null 2>&1; then
            print_status "SUCCESS" "Response contains time_range field"
        else
            print_status "ERROR" "Response missing time_range field"
            return 1
        fi
        
        # Check if we have timeline data
        local points_count=$(jq -r '.points | length' /tmp/flow_timeline.json)
        echo "Timeline points: $points_count"
        
        if [ "$points_count" -gt 0 ]; then
            print_status "SUCCESS" "Flow timeline has $points_count data points"
            
            # Check for data consistency (not all zeros)
            local non_zero_points=$(jq -r '.points[] | select(.envoy_requests > 0 or .mimir_requests > 0) | .timestamp' /tmp/flow_timeline.json | wc -l)
            echo "Non-zero data points: $non_zero_points"
            
            if [ "$non_zero_points" -gt 0 ]; then
                print_status "SUCCESS" "Flow timeline contains real data (not all zeros)"
            else
                print_status "WARNING" "Flow timeline contains only zero values"
            fi
            
        else
            print_status "WARNING" "Flow timeline is empty"
        fi
        
    else
        print_status "ERROR" "Expected status code 200, got $status_code"
        return 1
    fi
    
    return 0
}

# Function to test data consistency
test_data_consistency() {
    local time_range=$1
    
    echo -e "\n${BLUE}Testing Data Consistency for time range '$time_range'${NC}"
    
    # Test overview data consistency
    local overview_response=$(curl -s -w "%{http_code}" "http://localhost:8082/api/overview?range=$time_range" -o /tmp/overview_consistency.json)
    local overview_status="${overview_response: -3}"
    
    if [ "$overview_status" = "200" ]; then
        print_status "SUCCESS" "Overview API returned 200"
        
        # Extract key metrics
        local total_requests=$(jq -r '.stats.total_requests' /tmp/overview_consistency.json)
        local allowed_requests=$(jq -r '.stats.allowed_requests' /tmp/overview_consistency.json)
        local denied_requests=$(jq -r '.stats.denied_requests' /tmp/overview_consistency.json)
        local allow_percentage=$(jq -r '.stats.allow_percentage' /tmp/overview_consistency.json)
        local active_tenants=$(jq -r '.stats.active_tenants' /tmp/overview_consistency.json)
        
        echo "Overview Metrics:"
        echo "  Total Requests: $total_requests"
        echo "  Allowed Requests: $allowed_requests"
        echo "  Denied Requests: $denied_requests"
        echo "  Allow Percentage: $allow_percentage%"
        echo "  Active Tenants: $active_tenants"
        
        # Check data consistency
        local calculated_total=$((allowed_requests + denied_requests))
        local calculated_percentage=0
        
        if [ "$calculated_total" -gt 0 ]; then
            calculated_percentage=$(echo "scale=1; $allowed_requests * 100 / $calculated_total" | bc -l)
        fi
        
        echo "Calculated Total: $calculated_total"
        echo "Calculated Percentage: $calculated_percentage%"
        
        # Check if calculated values match API values
        if [ "$calculated_total" = "$total_requests" ]; then
            print_status "SUCCESS" "Total requests calculation matches API"
        else
            print_status "WARNING" "Total requests calculation mismatch: API=$total_requests, Calculated=$calculated_total"
        fi
        
        # Allow some tolerance for percentage calculation
        local percentage_diff=$(echo "scale=1; $allow_percentage - $calculated_percentage" | bc -l | sed 's/-//')
        if (( $(echo "$percentage_diff < 1" | bc -l) )); then
            print_status "SUCCESS" "Allow percentage calculation matches API (within 1%)"
        else
            print_status "WARNING" "Allow percentage calculation mismatch: API=$allow_percentage%, Calculated=$calculated_percentage%"
        fi
        
    else
        print_status "ERROR" "Overview API returned $overview_status"
        return 1
    fi
    
    return 0
}

# Function to test auto-refresh functionality
test_auto_refresh() {
    local time_range=$1
    
    echo -e "\n${BLUE}Testing Auto-Refresh Functionality for time range '$time_range'${NC}"
    
    # Make two requests in quick succession to test caching
    local start_time=$(date +%s%N)
    curl -s "http://localhost:8082/api/overview?range=$time_range" > /dev/null
    local end_time=$(date +%s%N)
    local first_duration=$(( (end_time - start_time) / 1000000 ))
    
    local start_time2=$(date +%s%N)
    curl -s "http://localhost:8082/api/overview?range=$time_range" > /dev/null
    local end_time2=$(date +%s%N)
    local second_duration=$(( (end_time2 - start_time2) / 1000000 ))
    
    echo "First request: ${first_duration}ms"
    echo "Second request: ${second_duration}ms"
    
    # Check if second request is faster (indicating caching)
    if [ "$second_duration" -lt "$first_duration" ]; then
        print_status "SUCCESS" "Caching is working (second request faster)"
    else
        print_status "INFO" "No significant caching improvement detected"
    fi
    
    # Test data freshness
    local response=$(curl -s "http://localhost:8082/api/overview?range=$time_range")
    local data_freshness=$(echo "$response" | jq -r '.data_freshness')
    local current_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    echo "Data freshness: $data_freshness"
    echo "Current time: $current_time"
    
    # Check if data freshness is recent (within last 10 minutes)
    local freshness_epoch=$(date -d "$data_freshness" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$data_freshness" +%s 2>/dev/null)
    local current_epoch=$(date +%s)
    local time_diff=$((current_epoch - freshness_epoch))
    
    if [ "$time_diff" -lt 600 ]; then # 10 minutes
        print_status "SUCCESS" "Data is fresh (within 10 minutes)"
    else
        print_status "WARNING" "Data may be stale (older than 10 minutes)"
    fi
}

# Main test execution
main() {
    echo "Starting Overview page fixes tests..."
    
    # Check if RLS service is running
    if ! check_service 8082 "RLS Admin Server"; then
        print_status "ERROR" "Please start the RLS service first"
        exit 1
    fi
    
    # Test different time ranges
    for time_range in "15m" "1h" "24h"; do
        print_status "INFO" "Testing time range: $time_range"
        
        # Test top tenant RPS
        test_top_tenant_rps "$time_range"
        
        # Test flow timeline
        test_flow_timeline "$time_range"
        
        # Test data consistency
        test_data_consistency "$time_range"
        
        # Test auto-refresh
        test_auto_refresh "$time_range"
    done
    
    # Test RLS endpoint status
    test_rls_endpoint_status
    
    print_status "SUCCESS" "All Overview page fixes tests completed!"
}

# Run the tests
main "$@"
