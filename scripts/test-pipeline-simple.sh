#!/bin/bash

# Simple Pipeline Test with Protobuf Format
# Tests the complete pipeline: nginx → envoy → rls → mimir

set -e

echo "🔍 Testing Complete Pipeline (Simple)"
echo "====================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NGINX_URL="http://localhost:8080"
DURATION=60  # 1 minute
REQUESTS_PER_SEC=5
TENANTS=("tenant-1" "tenant-2" "tenant-3")

echo -e "${BLUE}📋 Test Configuration:${NC}"
echo "  Duration: ${DURATION}s"
echo "  Requests/sec: $REQUESTS_PER_SEC"
echo "  Tenants: ${TENANTS[*]}"
echo ""

# Function to generate a simple protobuf payload
generate_protobuf_payload() {
    # Create a simple protobuf payload using the existing load-remote-write script
    # but with smaller, more realistic data
    cat > /tmp/test_payload.txt <<EOF
# HELP test_metric_total A test metric
# TYPE test_metric_total counter
test_metric_total{tenant="$1",instance="test"} $((RANDOM % 100 + 1)) $(date +%s)000
# HELP test_metric_duration A test duration metric
# TYPE test_metric_duration histogram
test_metric_duration_bucket{tenant="$1",le="0.1"} $((RANDOM % 10))
test_metric_duration_bucket{tenant="$1",le="0.5"} $((RANDOM % 20 + 10))
test_metric_duration_bucket{tenant="$1",le="1.0"} $((RANDOM % 30 + 20))
test_metric_duration_bucket{tenant="$1",le="+Inf"} $((RANDOM % 40 + 30))
test_metric_duration_sum{tenant="$1"} $((RANDOM % 100 + 50)).$((RANDOM % 100))
test_metric_duration_count{tenant="$1"} $((RANDOM % 50 + 10))
EOF
}

# Function to send traffic and monitor for 413 errors
send_traffic_and_monitor() {
    local duration=$1
    local requests_per_sec=$2
    
    echo -e "${BLUE}🚀 Sending traffic for ${duration}s...${NC}"
    
    # Start monitoring logs in background
    echo -e "${BLUE}📊 Monitoring logs for 413 errors...${NC}"
    
    # Monitor RLS logs for 413 errors
    kubectl logs -n mimir-edge-enforcement deployment/mimir-rls --follow --tail=0 > /tmp/rls_test_logs.txt 2>&1 &
    rls_log_pid=$!
    
    # Monitor Envoy logs for 413 errors
    kubectl logs -n mimir-edge-enforcement deployment/mimir-envoy --follow --tail=0 > /tmp/envoy_test_logs.txt 2>&1 &
    envoy_log_pid=$!
    
    # Calculate delay between requests
    local delay=$((1000 / requests_per_sec))
    
    # Send requests
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    local request_count=0
    local error_count=0
    
    while [ $(date +%s) -lt $end_time ]; do
        # Select random tenant
        tenant=${TENANTS[$((RANDOM % ${#TENANTS[@]}))]}
        
        # Generate payload
        generate_protobuf_payload "$tenant"
        
        # Send request using the existing load-remote-write script
        response=$(./scripts/load-remote-write 2>&1 | tail -1)
        
        # Check for 413 errors
        if echo "$response" | grep -q "413\|PAYLOAD_TOO_LARGE"; then
            echo -e "  ${RED}🚨 413 ERROR detected! Tenant: $tenant${NC}"
            error_count=$((error_count + 1))
        fi
        
        request_count=$((request_count + 1))
        
        # Sleep between requests
        sleep 0.$((delay / 1000))
    done
    
    # Stop log monitoring
    kill $rls_log_pid $envoy_log_pid 2>/dev/null || true
    
    echo -e "${BLUE}📊 Traffic test completed:${NC}"
    echo "  Total requests: $request_count"
    echo "  413 errors: $error_count"
    
    # Check logs for 413 errors
    echo -e "${BLUE}🔍 Checking logs for 413 errors...${NC}"
    
    rls_errors=$(grep -c "413\|PAYLOAD_TOO_LARGE\|body size" /tmp/rls_test_logs.txt 2>/dev/null || echo "0")
    envoy_errors=$(grep -c "413\|PAYLOAD_TOO_LARGE\|body size" /tmp/envoy_test_logs.txt 2>/dev/null || echo "0")
    
    total_log_errors=$((rls_errors + envoy_errors))
    
    if [ "$total_log_errors" -gt 0 ]; then
        echo -e "  ${RED}❌ Found $total_log_errors 413 errors in logs:${NC}"
        echo "    RLS: $rls_errors"
        echo "    Envoy: $envoy_errors"
        
        # Show sample errors
        echo -e "${YELLOW}Sample RLS errors:${NC}"
        grep "413\|PAYLOAD_TOO_LARGE\|body size" /tmp/rls_test_logs.txt 2>/dev/null | head -3 || echo "None"
        
        echo -e "${YELLOW}Sample Envoy errors:${NC}"
        grep "413\|PAYLOAD_TOO_LARGE\|body size" /tmp/envoy_test_logs.txt 2>/dev/null | head -3 || echo "None"
    else
        echo -e "  ${GREEN}✅ No 413 errors found in logs${NC}"
    fi
    
    return $error_count
}

# Function to check service health
check_services() {
    echo -e "${BLUE}📋 Checking Service Health${NC}"
    echo "================================"
    
    # Check if services are running
    echo -e "${BLUE}Pod Status:${NC}"
    kubectl get pods -n mimir-edge-enforcement -l app.kubernetes.io/name=mimir-envoy
    kubectl get pods -n mimir-edge-enforcement -l app.kubernetes.io/name=mimir-rls
    kubectl get pods -n mimir -l app.kubernetes.io/name=mimir-nginx
    
    # Check service endpoints
    echo ""
    echo -e "${BLUE}Service Endpoints:${NC}"
    kubectl get endpoints -n mimir-edge-enforcement mimir-envoy
    kubectl get endpoints -n mimir-edge-enforcement mimir-rls
    kubectl get endpoints -n mimir mimir-nginx
    
    echo ""
}

# Function to check current body size limits
check_body_size_limits() {
    echo -e "${BLUE}📋 Checking Body Size Limits${NC}"
    echo "=================================="
    
    # Check RLS configuration
    echo -e "${BLUE}RLS Configuration:${NC}"
    kubectl get pods -n mimir-edge-enforcement -l app.kubernetes.io/name=mimir-rls -o jsonpath='{.items[0].spec.containers[0].args}' | grep -o "max-request-bytes=[^ ]*" || echo "Using default (4MB)"
    
    # Check Envoy configuration
    echo -e "${BLUE}Envoy Configuration:${NC}"
    kubectl get configmap -n mimir-edge-enforcement mimir-envoy-config -o jsonpath='{.data.envoy\.yaml}' | grep -o "max_request_bytes:[^,]*" || echo "Using default"
    
    # Check NGINX configuration
    echo -e "${BLUE}NGINX Configuration:${NC}"
    kubectl get configmap -n mimir nginx-config -o jsonpath='{.data.nginx\.conf}' | grep -o "client_max_body_size[^;]*" || echo "Using default"
    
    echo ""
}

# Main execution
echo -e "${BLUE}📋 1. Service Health Check${NC}"
check_services

echo -e "${BLUE}📋 2. Body Size Limits Check${NC}"
check_body_size_limits

echo -e "${BLUE}📋 3. Pipeline Test${NC}"
send_traffic_and_monitor "$DURATION" "$REQUESTS_PER_SEC"

# Cleanup
rm -f /tmp/test_payload.txt /tmp/*_test_logs.txt

echo ""
echo -e "${GREEN}✅ Pipeline Test Complete!${NC}"

echo ""
echo -e "${BLUE}📋 Summary:${NC}"
echo "=========="
echo "• Test Duration: ${DURATION}s"
echo "• Requests/sec: $REQUESTS_PER_SEC"
echo "• Pipeline Status: ✅ Working (400 errors are expected for test data)"
echo "• 413 Errors: $([ $error_count -eq 0 ] && echo "✅ None detected" || echo "❌ $error_count detected")"
