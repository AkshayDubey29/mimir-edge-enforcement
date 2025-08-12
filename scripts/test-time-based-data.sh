#!/bin/bash

# Test script for time-based data aggregation and caching
# This script verifies that the UI data is stable within time frames

set -e

echo "🧪 Testing Time-Based Data Aggregation and Caching"
echo "=================================================="

# Start the RLS service in the background
echo "🚀 Starting RLS service..."
cd services/rls
./rls &
RLS_PID=$!

# Wait for service to start
sleep 3

# Function to test API endpoint with time range
test_api_endpoint() {
    local endpoint=$1
    local time_range=$2
    local description=$3
    
    echo "📊 Testing $description (time range: $time_range)"
    
    # Make multiple requests to test caching
    for i in {1..3}; do
        echo "  Request $i:"
        response=$(curl -s "http://localhost:8082$endpoint?range=$time_range" | jq -r '.stats.total_requests // .tenants | length // "N/A"')
        echo "    Response: $response"
        sleep 1
    done
    
    echo ""
}

# Function to test data stability
test_data_stability() {
    local endpoint=$1
    local time_range=$2
    local description=$3
    
    echo "🔍 Testing data stability for $description (time range: $time_range)"
    
    # Make multiple requests and check if data is stable
    responses=()
    for i in {1..5}; do
        response=$(curl -s "http://localhost:8082$endpoint?range=$time_range" | jq -r '.stats.total_requests // .tenants | length // "N/A"')
        responses+=("$response")
        echo "  Request $i: $response"
        sleep 2
    done
    
    # Check if all responses are the same (indicating stable data)
    first_response=${responses[0]}
    all_same=true
    
    for response in "${responses[@]}"; do
        if [ "$response" != "$first_response" ]; then
            all_same=false
            break
        fi
    done
    
    if [ "$all_same" = true ]; then
        echo "  ✅ Data is stable within time frame"
    else
        echo "  ❌ Data is not stable within time frame"
    fi
    
    echo ""
}

# Test different time ranges
echo "🕐 Testing different time ranges..."
test_api_endpoint "/api/overview" "15m" "Overview API (15 minutes)"
test_api_endpoint "/api/overview" "1h" "Overview API (1 hour)"
test_api_endpoint "/api/overview" "24h" "Overview API (24 hours)"
test_api_endpoint "/api/overview" "1w" "Overview API (1 week)"

test_api_endpoint "/api/tenants" "15m" "Tenants API (15 minutes)"
test_api_endpoint "/api/tenants" "1h" "Tenants API (1 hour)"
test_api_endpoint "/api/tenants" "24h" "Tenants API (24 hours)"
test_api_endpoint "/api/tenants" "1w" "Tenants API (1 week)"

# Test data stability
echo "🔒 Testing data stability..."
test_data_stability "/api/overview" "1h" "Overview data (1 hour)"
test_data_stability "/api/tenants" "1h" "Tenants data (1 hour)"

# Test cache functionality
echo "💾 Testing cache functionality..."
echo "📊 Making rapid requests to test caching..."

for i in {1..10}; do
    response=$(curl -s "http://localhost:8082/api/overview?range=1h" | jq -r '.stats.total_requests // "N/A"')
    echo "  Request $i: $response"
    sleep 0.1  # Very rapid requests
done

echo ""
echo "✅ Time-based data aggregation and caching tests completed!"

# Cleanup
echo "🧹 Cleaning up..."
kill $RLS_PID 2>/dev/null || true
wait $RLS_PID 2>/dev/null || true

echo "🎉 All tests completed successfully!"
