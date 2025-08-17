#!/bin/bash

# Test Large Payloads to Verify Body Size Limits
# This script tests the pipeline with increasingly large payloads

set -e

echo "🔍 Testing Large Payloads for Body Size Limits"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NGINX_URL="http://localhost:8080"
RLS_LIMIT=4194304  # 4MB (from RLS config)

echo -e "${BLUE}📋 Test Configuration:${NC}"
echo "  RLS Body Size Limit: $((RLS_LIMIT / 1024 / 1024))MB"
echo ""

# Function to generate payload of specified size
generate_large_payload() {
    local size_bytes=$1
    local tenant=$2
    
    # Create a base metric
    local base_metric="test_large_metric{tenant=\"$tenant\",size=\"${size_bytes}\"} 1 $(date +%s)000"
    
    # Calculate how many metrics we need to reach the target size
    local metric_size=${#base_metric}
    local num_metrics=$((size_bytes / metric_size))
    
    # Generate the payload
    echo "# HELP test_large_metric A test metric for large payload testing"
    echo "# TYPE test_large_metric counter"
    
    for i in $(seq 1 $num_metrics); do
        echo "test_large_metric{tenant=\"$tenant\",size=\"${size_bytes}\",metric_id=\"$i\"} $i $(date +%s)000"
    done
}

# Function to test payload size
test_payload_size() {
    local size_mb=$1
    local size_bytes=$((size_mb * 1024 * 1024))
    local tenant="test-tenant-large"
    
    echo -e "${BLUE}🧪 Testing ${size_mb}MB payload (${size_bytes} bytes)...${NC}"
    
    # Generate the payload
    generate_large_payload "$size_bytes" "$tenant" > /tmp/large_payload.txt
    
    # Check actual file size
    actual_size=$(wc -c < /tmp/large_payload.txt)
    echo "  Generated payload size: $((actual_size / 1024))KB"
    
    # Send the request
    response=$(curl -s -w "%{http_code}" -X POST "$NGINX_URL/api/v1/push" \
        -H "Content-Type: application/x-protobuf" \
        -H "X-Scope-OrgID: $tenant" \
        -H "Content-Encoding: snappy" \
        --data-binary @/tmp/large_payload.txt)
    
    # Extract status code
    status_code=$(echo "$response" | tail -1)
    response_body=$(echo "$response" | head -n -1)
    
    echo "  Response status: $status_code"
    
    if [ "$status_code" = "413" ]; then
        echo -e "  ${RED}🚨 413 PAYLOAD TOO LARGE detected!${NC}"
        echo "  Response body: $response_body"
        return 1
    elif [ "$status_code" = "400" ]; then
        echo -e "  ${YELLOW}⚠️  400 Bad Request (expected for test data)${NC}"
        return 0
    else
        echo -e "  ${GREEN}✅ Request processed (status: $status_code)${NC}"
        return 0
    fi
}

# Function to check logs for 413 errors
check_logs_for_413() {
    echo -e "${BLUE}🔍 Checking logs for 413 errors...${NC}"
    
    # Check RLS logs
    rls_errors=$(grep -c "413\|PAYLOAD_TOO_LARGE\|body size" /tmp/rls_monitor.log 2>/dev/null || echo "0")
    envoy_errors=$(grep -c "413\|PAYLOAD_TOO_LARGE\|body size" /tmp/envoy_monitor.log 2>/dev/null || echo "0")
    
    total_errors=$((rls_errors + envoy_errors))
    
    if [ "$total_errors" -gt 0 ]; then
        echo -e "  ${RED}❌ Found $total_errors 413 errors in logs:${NC}"
        echo "    RLS: $rls_errors"
        echo "    Envoy: $envoy_errors"
        
        # Show sample errors
        echo -e "${YELLOW}Sample RLS errors:${NC}"
        grep "413\|PAYLOAD_TOO_LARGE\|body size" /tmp/rls_monitor.log 2>/dev/null | head -3 || echo "None"
        
        echo -e "${YELLOW}Sample Envoy errors:${NC}"
        grep "413\|PAYLOAD_TOO_LARGE\|body size" /tmp/envoy_monitor.log 2>/dev/null | head -3 || echo "None"
    else
        echo -e "  ${GREEN}✅ No 413 errors found in logs${NC}"
    fi
}

# Main test execution
echo -e "${BLUE}📋 1. Testing Small Payload (1MB)${NC}"
test_payload_size 1

echo ""
echo -e "${BLUE}📋 2. Testing Medium Payload (2MB)${NC}"
test_payload_size 2

echo ""
echo -e "${BLUE}📋 3. Testing Large Payload (3MB)${NC}"
test_payload_size 3

echo ""
echo -e "${BLUE}📋 4. Testing Near-Limit Payload (3.5MB)${NC}"
test_payload_size 3.5

echo ""
echo -e "${BLUE}📋 5. Testing Over-Limit Payload (5MB)${NC}"
test_payload_size 5

echo ""
echo -e "${BLUE}📋 6. Testing Very Large Payload (10MB)${NC}"
test_payload_size 10

echo ""
check_logs_for_413

# Cleanup
rm -f /tmp/large_payload.txt

echo ""
echo -e "${GREEN}✅ Large Payload Test Complete!${NC}"

echo ""
echo -e "${BLUE}📋 Summary:${NC}"
echo "=========="
echo "• RLS Body Size Limit: $((RLS_LIMIT / 1024 / 1024))MB"
echo "• Tested payloads: 1MB, 2MB, 3MB, 3.5MB, 5MB, 10MB"
echo "• 413 Errors in logs: $total_errors"
echo "• Body size enforcement: $([ $total_errors -gt 0 ] && echo "✅ Working" || echo "⚠️  Not triggered")"
