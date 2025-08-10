#!/bin/bash

# Debug Tenant Details API Issue
# This script helps debug why /api/tenants/{id} returns 200 but UI shows "Tenant not found"

set -e

echo "🔍 DEBUGGING TENANT DETAILS API ISSUE"
echo "====================================="

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
TENANT_ID="${1:-couwatch}"  # Use provided tenant ID or default to couwatch

echo -e "${BLUE}Testing tenant ID: $TENANT_ID${NC}"
echo ""

# Test 1: Check if RLS service is running
echo -e "${BLUE}Step 1: Checking RLS service availability...${NC}"
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

# Test 2: Check if tenant exists in list
echo -e "${BLUE}Step 2: Checking if tenant exists in /api/tenants list...${NC}"
tenants_response=$(curl -s "${RLS_BASE_URL}/api/tenants")
tenants_status=$?

if [ $tenants_status -eq 0 ]; then
    echo -e "  ${GREEN}✅ /api/tenants endpoint accessible${NC}"
    
    # Check if tenant exists in list
    tenant_in_list=$(echo "$tenants_response" | jq -r --arg id "$TENANT_ID" '.tenants[] | select(.id == $id) | .id' 2>/dev/null)
    
    if [ -n "$tenant_in_list" ] && [ "$tenant_in_list" != "null" ]; then
        echo -e "  ${GREEN}✅ Tenant '$TENANT_ID' found in tenants list${NC}"
    else
        echo -e "  ${YELLOW}⚠️  Tenant '$TENANT_ID' NOT found in tenants list${NC}"
        echo -e "  ${CYAN}Available tenants:${NC}"
        echo "$tenants_response" | jq -r '.tenants[].id' 2>/dev/null | head -10
    fi
else
    echo -e "  ${RED}❌ /api/tenants endpoint failed${NC}"
fi

echo ""

# Test 3: Test individual tenant API
echo -e "${BLUE}Step 3: Testing /api/tenants/$TENANT_ID endpoint...${NC}"
tenant_response=$(curl -s -w "%{http_code}" "${RLS_BASE_URL}/api/tenants/$TENANT_ID")
http_code="${tenant_response: -3}"
response_body="${tenant_response%???}"

echo -e "  ${CYAN}HTTP Status Code: $http_code${NC}"

if [ "$http_code" -eq "200" ]; then
    echo -e "  ${GREEN}✅ /api/tenants/$TENANT_ID returned 200 OK${NC}"
    
    # Parse the response
    echo -e "  ${CYAN}Response body:${NC}"
    echo "$response_body" | jq '.' 2>/dev/null || echo "$response_body"
    
    # Check if tenant object exists
    tenant_object=$(echo "$response_body" | jq -r '.tenant' 2>/dev/null)
    if [ "$tenant_object" != "null" ] && [ -n "$tenant_object" ]; then
        echo -e "  ${GREEN}✅ Response contains 'tenant' object${NC}"
        
        # Check tenant ID
        response_tenant_id=$(echo "$response_body" | jq -r '.tenant.id' 2>/dev/null)
        if [ "$response_tenant_id" = "$TENANT_ID" ]; then
            echo -e "  ${GREEN}✅ Tenant ID matches: $response_tenant_id${NC}"
        else
            echo -e "  ${YELLOW}⚠️  Tenant ID mismatch: expected '$TENANT_ID', got '$response_tenant_id'${NC}"
        fi
        
        # Check if tenant has limits
        has_limits=$(echo "$response_body" | jq -r '.tenant.limits' 2>/dev/null)
        if [ "$has_limits" != "null" ] && [ -n "$has_limits" ]; then
            echo -e "  ${GREEN}✅ Tenant has limits configured${NC}"
        else
            echo -e "  ${YELLOW}⚠️  Tenant has no limits configured${NC}"
        fi
        
    else
        echo -e "  ${RED}❌ Response does NOT contain 'tenant' object${NC}"
    fi
    
    # Check if recent_denials exists
    recent_denials=$(echo "$response_body" | jq -r '.recent_denials' 2>/dev/null)
    if [ "$recent_denials" != "null" ]; then
        echo -e "  ${GREEN}✅ Response contains 'recent_denials' array${NC}"
    else
        echo -e "  ${YELLOW}⚠️  Response does NOT contain 'recent_denials' array${NC}"
    fi
    
elif [ "$http_code" -eq "404" ]; then
    echo -e "  ${RED}❌ /api/tenants/$TENANT_ID returned 404 Not Found${NC}"
    echo -e "  ${CYAN}Response body:${NC}"
    echo "$response_body" | jq '.' 2>/dev/null || echo "$response_body"
else
    echo -e "  ${RED}❌ /api/tenants/$TENANT_ID returned unexpected status: $http_code${NC}"
    echo -e "  ${CYAN}Response body:${NC}"
    echo "$response_body" | jq '.' 2>/dev/null || echo "$response_body"
fi

echo ""

# Test 4: Check RLS logs for debugging info
echo -e "${BLUE}Step 4: Checking RLS logs for debugging info...${NC}"
echo -e "  ${YELLOW}Look for these log messages in RLS logs:${NC}"
echo -e "    - 'handling /api/tenants/{id} request'"
echo -e "    - 'debug: checking tenant availability'"
echo -e "    - 'tenant found in list but not in snapshot'"
echo -e "    - 'tenant not found in GetTenantSnapshot or list'"
echo -e "    - 'tenant details API response'"

echo ""

# Test 5: Test with different tenant IDs
echo -e "${BLUE}Step 5: Testing with different tenant IDs...${NC}"
available_tenants=$(echo "$tenants_response" | jq -r '.tenants[].id' 2>/dev/null | head -3)

for test_tenant in $available_tenants; do
    if [ -n "$test_tenant" ] && [ "$test_tenant" != "null" ]; then
        echo -e "  ${CYAN}Testing tenant: $test_tenant${NC}"
        test_response=$(curl -s -w "%{http_code}" "${RLS_BASE_URL}/api/tenants/$test_tenant")
        test_http_code="${test_response: -3}"
        test_body="${test_response%???}"
        
        if [ "$test_http_code" -eq "200" ]; then
            test_tenant_id=$(echo "$test_body" | jq -r '.tenant.id' 2>/dev/null)
            echo -e "    ${GREEN}✅ 200 OK - Tenant ID: $test_tenant_id${NC}"
        else
            echo -e "    ${RED}❌ $test_http_code${NC}"
        fi
    fi
done

echo ""

# Test 6: Frontend simulation
echo -e "${BLUE}Step 6: Simulating frontend logic...${NC}"
echo -e "  ${YELLOW}Frontend checks:${NC}"

# Simulate the frontend logic
if [ "$http_code" -eq "200" ]; then
    tenant_object=$(echo "$response_body" | jq -r '.tenant' 2>/dev/null)
    
    if [ "$tenant_object" != "null" ] && [ -n "$tenant_object" ]; then
        echo -e "    ${GREEN}✅ API returned 200 with tenant object${NC}"
        
        # Check if tenant has status field
        tenant_status=$(echo "$response_body" | jq -r '.tenant.status' 2>/dev/null)
        if [ "$tenant_status" = "null" ] || [ -z "$tenant_status" ]; then
            echo -e "    ${YELLOW}⚠️  Tenant has no 'status' field (frontend expects this)${NC}"
        else
            echo -e "    ${GREEN}✅ Tenant has status: $tenant_status${NC}"
        fi
        
        # Check if tenant has limits
        tenant_limits=$(echo "$response_body" | jq -r '.tenant.limits' 2>/dev/null)
        if [ "$tenant_limits" = "null" ] || [ -z "$tenant_limits" ]; then
            echo -e "    ${YELLOW}⚠️  Tenant has no 'limits' field${NC}"
        else
            echo -e "    ${GREEN}✅ Tenant has limits configured${NC}"
        fi
        
    else
        echo -e "    ${RED}❌ API returned 200 but no tenant object (this is the issue!)${NC}"
    fi
else
    echo -e "    ${RED}❌ API returned $http_code (not 200)${NC}"
fi

echo ""

# Summary
echo -e "${PURPLE}SUMMARY${NC}"
echo "======="

if [ "$http_code" -eq "200" ]; then
    tenant_object=$(echo "$response_body" | jq -r '.tenant' 2>/dev/null)
    
    if [ "$tenant_object" != "null" ] && [ -n "$tenant_object" ]; then
        echo -e "${GREEN}✅ API is working correctly${NC}"
        echo -e "${YELLOW}The issue is likely in the frontend data transformation logic${NC}"
        echo -e "${CYAN}Check the fetchTenantDetails function in TenantDetails.tsx${NC}"
    else
        echo -e "${RED}❌ API returns 200 but no tenant object${NC}"
        echo -e "${YELLOW}This suggests a backend issue with GetTenantSnapshot()${NC}"
    fi
else
    echo -e "${RED}❌ API is not working (status: $http_code)${NC}"
fi

echo ""
echo -e "${GREEN}🎯 DEBUGGING COMPLETE!${NC}"
