#!/bin/bash

# Test script to identify and fix 413 errors in the nginx -> envoy -> rls -> mimir pipeline
# Tests different request sizes and checks each component

set -e

echo "🔍 Testing 413 Error Resolution - Complete Pipeline Test"
echo "========================================================"

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
        "SUCCESS") echo -e "${GREEN}✅ $message${NC}" ;;
        "ERROR") echo -e "${RED}❌ $message${NC}" ;;
        "WARNING") echo -e "${YELLOW}⚠️  $message${NC}" ;;
        "INFO") echo -e "${BLUE}ℹ️  $message${NC}" ;;
    esac
}

# Function to test request size
test_request_size() {
    local size=$1
    local description=$2
    local endpoint=$3
    
    echo ""
    print_status "INFO" "Testing $description ($size bytes) to $endpoint"
    
    # Create test data of specified size
    local test_data=$(head -c $size /dev/zero | tr '\0' 'A')
    
    # Test the request
    local response=$(curl -s -w "%{http_code}" -X POST "$endpoint" \
        -H "Content-Type: application/x-protobuf" \
        -H "X-Scope-OrgID: test-tenant" \
        -d "$test_data" \
        --max-time 10 \
        --connect-timeout 5)
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "202" ]; then
        print_status "SUCCESS" "Request succeeded with HTTP $http_code"
    elif [ "$http_code" = "413" ]; then
        print_status "ERROR" "413 Payload Too Large - Request size $size bytes"
        return 1
    elif [ "$http_code" = "400" ]; then
        print_status "WARNING" "400 Bad Request (expected for invalid protobuf data) - HTTP $http_code"
    else
        print_status "ERROR" "Unexpected response: HTTP $http_code"
        echo "Response body: $body"
        return 1
    fi
    
    return 0
}

# Function to check service status
check_service() {
    local service=$1
    local namespace=$2
    local port=$3
    
    print_status "INFO" "Checking $service status..."
    
    # Check if pods are running
    local running_pods=$(kubectl get pods -n $namespace | grep $service | grep Running | wc -l)
    if [ $running_pods -eq 0 ]; then
        print_status "ERROR" "$service has no running pods"
        return 1
    fi
    
    print_status "SUCCESS" "$service has $running_pods running pods"
    
    # Test service connectivity
    kubectl port-forward -n $namespace svc/$service $port:$port >/dev/null 2>&1 &
    local pf_pid=$!
    sleep 2
    
    if curl -s http://localhost:$port/readyz >/dev/null 2>&1; then
        print_status "SUCCESS" "$service is responding on port $port"
        kill $pf_pid 2>/dev/null || true
        return 0
    else
        print_status "ERROR" "$service is not responding on port $port"
        kill $pf_pid 2>/dev/null || true
        return 1
    fi
}

# Function to check Envoy configuration
check_envoy_config() {
    print_status "INFO" "Checking Envoy configuration..."
    
    # Get Envoy config
    local config=$(kubectl get configmap mimir-envoy-config -n mimir-edge-enforcement -o jsonpath='{.data.envoy\.yaml}')
    
    # Check for buffer settings
    if echo "$config" | grep -q "initial_stream_window_size: 52428800"; then
        print_status "SUCCESS" "Envoy HTTP/2 stream window size: 50MB"
    else
        print_status "ERROR" "Envoy HTTP/2 stream window size not set to 50MB"
        return 1
    fi
    
    if echo "$config" | grep -q "initial_connection_window_size: 52428800"; then
        print_status "SUCCESS" "Envoy HTTP/2 connection window size: 50MB"
    else
        print_status "ERROR" "Envoy HTTP/2 connection window size not set to 50MB"
        return 1
    fi
    
    return 0
}

# Function to check RLS configuration
check_rls_config() {
    print_status "INFO" "Checking RLS configuration..."
    
    # Get RLS pod logs to check configuration
    local rls_pod=$(kubectl get pods -n mimir-edge-enforcement | grep mimir-rls | grep Running | head -n1 | awk '{print $1}')
    
    if [ -z "$rls_pod" ]; then
        print_status "ERROR" "No running RLS pods found"
        return 1
    fi
    
    # Check RLS startup logs for configuration
    local config_log=$(kubectl logs $rls_pod -n mimir-edge-enforcement | grep "parsed configuration values" | tail -n1)
    
    if echo "$config_log" | grep -q "default_max_body_bytes.*52428800"; then
        print_status "SUCCESS" "RLS max body bytes: 50MB"
    else
        print_status "ERROR" "RLS max body bytes not set to 50MB"
        echo "Config log: $config_log"
        return 1
    fi
    
    return 0
}

# Main test execution
echo ""
print_status "INFO" "Starting comprehensive 413 error test..."

# Step 1: Check all services
echo ""
print_status "INFO" "Step 1: Checking service status"
check_service "mimir-envoy" "mimir-edge-enforcement" "8080" || exit 1
check_service "mimir-rls" "mimir-edge-enforcement" "8082" || exit 1

# Step 2: Check configurations
echo ""
print_status "INFO" "Step 2: Checking configurations"
check_envoy_config || exit 1
check_rls_config || exit 1

# Step 3: Test different request sizes
echo ""
print_status "INFO" "Step 3: Testing different request sizes"

# Test small request (1KB)
test_request_size 1024 "Small request (1KB)" "http://localhost:8080/api/v1/push" || {
    print_status "ERROR" "Small request failed - basic connectivity issue"
    exit 1
}

# Test medium request (1MB)
test_request_size 1048576 "Medium request (1MB)" "http://localhost:8080/api/v1/push" || {
    print_status "ERROR" "Medium request failed - possible buffer issue"
    exit 1
}

# Test large request (10MB)
test_request_size 10485760 "Large request (10MB)" "http://localhost:8080/api/v1/push" || {
    print_status "ERROR" "Large request failed - buffer limit issue"
    exit 1
}

# Test very large request (50MB)
test_request_size 52428800 "Very large request (50MB)" "http://localhost:8080/api/v1/push" || {
    print_status "ERROR" "Very large request failed - maximum buffer issue"
    exit 1
}

# Step 4: Test direct RLS endpoint
echo ""
print_status "INFO" "Step 4: Testing direct RLS endpoint"

# Test direct RLS with large request
test_request_size 10485760 "Direct RLS (10MB)" "http://localhost:8082/api/v1/push" || {
    print_status "ERROR" "Direct RLS request failed - RLS configuration issue"
    exit 1
}

# Step 5: Check for 413 errors in logs
echo ""
print_status "INFO" "Step 5: Checking for 413 errors in logs"

# Check Envoy logs for 413 errors
local envoy_pod=$(kubectl get pods -n mimir-edge-enforcement | grep mimir-envoy | grep Running | head -n1 | awk '{print $1}')
if [ -n "$envoy_pod" ]; then
    local envoy_413_count=$(kubectl logs $envoy_pod -n mimir-edge-enforcement --tail=100 | grep "413" | wc -l)
    if [ $envoy_413_count -gt 0 ]; then
        print_status "WARNING" "Found $envoy_413_count 413 errors in Envoy logs"
        kubectl logs $envoy_pod -n mimir-edge-enforcement --tail=50 | grep "413" | head -n5
    else
        print_status "SUCCESS" "No 413 errors found in Envoy logs"
    fi
fi

# Check RLS logs for 413 errors
local rls_pod=$(kubectl get pods -n mimir-edge-enforcement | grep mimir-rls | grep Running | head -n1 | awk '{print $1}')
if [ -n "$rls_pod" ]; then
    local rls_413_count=$(kubectl logs $rls_pod -n mimir-edge-enforcement --tail=100 | grep "413" | wc -l)
    if [ $rls_413_count -gt 0 ]; then
        print_status "WARNING" "Found $rls_413_count 413 errors in RLS logs"
        kubectl logs $rls_pod -n mimir-edge-enforcement --tail=50 | grep "413" | head -n5
    else
        print_status "SUCCESS" "No 413 errors found in RLS logs"
    fi
fi

echo ""
print_status "SUCCESS" "All tests completed successfully!"
print_status "INFO" "If you're still seeing 413 errors in production, they may be coming from:"
print_status "INFO" "1. NGINX upstream (before Envoy)"
print_status "INFO" "2. Load balancer/proxy in front of the cluster"
print_status "INFO" "3. Network policies or ingress controllers"
print_status "INFO" "4. Client-side timeouts or connection issues"

echo ""
print_status "INFO" "Next steps:"
print_status "INFO" "1. Check NGINX configuration for client_max_body_size"
print_status "INFO" "2. Check any load balancer/proxy settings"
print_status "INFO" "3. Monitor Envoy access logs for detailed request information"
print_status "INFO" "4. Test with real protobuf/snappy compressed data"
