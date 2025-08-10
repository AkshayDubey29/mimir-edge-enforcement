#!/bin/bash

# Debug Tenant 404 Issue Script
# This script helps debug why a tenant shows up in the list but returns 404 for individual details

set -e

echo "🔍 DEBUGGING TENANT 404 ISSUE"
echo "============================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if RLS service is running
echo -e "${BLUE}Checking if RLS service is running...${NC}"
if ! curl -s -f "http://localhost:8082/healthz" > /dev/null 2>&1; then
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

# Test 1: Get all tenants
echo -e "${BLUE}Step 1: Getting all tenants...${NC}"
tenants_response=$(curl -s "http://localhost:8082/api/tenants")
echo -e "  ${YELLOW}Response:${NC}"
echo "$tenants_response" | jq '.' 2>/dev/null || echo "$tenants_response"

# Extract tenant IDs
tenant_ids=$(echo "$tenants_response" | jq -r '.tenants[].id' 2>/dev/null || echo "")
echo ""
echo -e "${BLUE}Found tenant IDs:${NC}"
echo "$tenant_ids" | while read -r id; do
    if [ -n "$id" ] && [ "$id" != "null" ]; then
        echo -e "  ${GREEN}• $id${NC}"
    fi
done

echo ""

# Test 2: Check for specific tenant (couwatch)
echo -e "${BLUE}Step 2: Testing specific tenant 'couwatch'...${NC}"

# Check if couwatch exists in the list
if echo "$tenants_response" | jq -e '.tenants[] | select(.id == "couwatch")' > /dev/null 2>&1; then
    echo -e "  ${GREEN}✅ 'couwatch' found in tenant list${NC}"
    
    # Try to get couwatch details
    echo -e "  ${BLUE}Trying to get couwatch details...${NC}"
    couwatch_response=$(curl -s -w "%{http_code}" "http://localhost:8082/api/tenants/couwatch" 2>/dev/null)
    http_code="${couwatch_response: -3}"
    body="${couwatch_response%???}"
    
    if [ "$http_code" -eq "200" ]; then
        echo -e "  ${GREEN}✅ couwatch details retrieved successfully${NC}"
        echo -e "  ${YELLOW}Response:${NC}"
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
    else
        echo -e "  ${RED}❌ couwatch details returned HTTP $http_code${NC}"
        echo -e "  ${YELLOW}Response:${NC}"
        echo "$body"
    fi
else
    echo -e "  ${RED}❌ 'couwatch' NOT found in tenant list${NC}"
fi

echo ""

# Test 3: Test all tenants individually
echo -e "${BLUE}Step 3: Testing all tenants individually...${NC}"
echo "$tenant_ids" | while read -r id; do
    if [ -n "$id" ] && [ "$id" != "null" ]; then
        echo -e "  ${BLUE}Testing tenant: $id${NC}"
        response=$(curl -s -w "%{http_code}" "http://localhost:8082/api/tenants/$id" 2>/dev/null)
        http_code="${response: -3}"
        
        if [ "$http_code" -eq "200" ]; then
            echo -e "    ${GREEN}✅ HTTP $http_code${NC}"
        else
            echo -e "    ${RED}❌ HTTP $http_code${NC}"
        fi
    fi
done

echo ""

# Test 4: Check RLS logs for debugging info
echo -e "${BLUE}Step 4: Checking for debugging information...${NC}"
echo -e "  ${YELLOW}Look for these log messages in your RLS service:${NC}"
echo -e "    • 'debug: checking tenant availability'"
echo -e "    • 'tenant found in list but not in snapshot (case sensitivity issue)'"
echo -e "    • 'tenant not found in GetTenantSnapshot or list'"
echo ""

# Test 5: Case sensitivity test
echo -e "${BLUE}Step 5: Testing case sensitivity...${NC}"
if [ -n "$tenant_ids" ]; then
    first_tenant=$(echo "$tenant_ids" | head -n 1)
    if [ -n "$first_tenant" ] && [ "$first_tenant" != "null" ]; then
        echo -e "  ${BLUE}Testing case variations for: $first_tenant${NC}"
        
        # Test original case
        response1=$(curl -s -w "%{http_code}" "http://localhost:8082/api/tenants/$first_tenant" 2>/dev/null)
        code1="${response1: -3}"
        echo -e "    Original case ($first_tenant): ${code1}"
        
        # Test uppercase
        response2=$(curl -s -w "%{http_code}" "http://localhost:8082/api/tenants/${first_tenant^^}" 2>/dev/null)
        code2="${response2: -3}"
        echo -e "    Uppercase (${first_tenant^^}): ${code2}"
        
        # Test lowercase
        response3=$(curl -s -w "%{http_code}" "http://localhost:8082/api/tenants/${first_tenant,,}" 2>/dev/null)
        code3="${response3: -3}"
        echo -e "    Lowercase (${first_tenant,,}): ${code3}"
    fi
fi

echo ""
echo "🔍 DEBUGGING SUMMARY"
echo "==================="
echo -e "${YELLOW}If you're seeing 404 errors for tenants that exist in the list:${NC}"
echo "1. Check RLS service logs for debugging messages"
echo "2. Look for case sensitivity issues"
echo "3. Check if there are race conditions between list and individual requests"
echo "4. Verify that the tenant data is consistent between endpoints"
echo ""
echo -e "${GREEN}The enhanced error handling should now provide better debugging information!${NC}"
