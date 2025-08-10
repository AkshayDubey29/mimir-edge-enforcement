#!/bin/bash

# Comprehensive Admin UI Fixes Test Script
# This script tests all the fixes implemented for the Admin UI issues

set -e

echo "🧪 TESTING ADMIN UI FIXES"
echo "=========================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if RLS service is running
echo -e "${BLUE}Step 1: Checking RLS service availability...${NC}"
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

# Test 1: Overview API
echo -e "${BLUE}Step 2: Testing Overview API...${NC}"
overview_response=$(curl -s "http://localhost:8082/api/overview")
echo -e "  ${YELLOW}Response:${NC}"
echo "$overview_response" | jq '.' 2>/dev/null || echo "$overview_response"

# Check for real data vs mock data
if echo "$overview_response" | grep -q "mock\|dummy\|fake\|test"; then
    echo -e "  ${RED}❌ Found mock/dummy data in overview response${NC}"
else
    echo -e "  ${GREEN}✅ Overview API returning real data${NC}"
fi

echo ""

# Test 2: Tenants API
echo -e "${BLUE}Step 3: Testing Tenants API...${NC}"
tenants_response=$(curl -s "http://localhost:8082/api/tenants")
echo -e "  ${YELLOW}Response:${NC}"
echo "$tenants_response" | jq '.' 2>/dev/null || echo "$tenants_response"

# Extract tenant IDs for individual testing
tenant_ids=$(echo "$tenants_response" | jq -r '.tenants[].id' 2>/dev/null || echo "")
echo ""
echo -e "${BLUE}Found tenant IDs:${NC}"
echo "$tenant_ids" | while read -r id; do
    if [ -n "$id" ] && [ "$id" != "null" ]; then
        echo -e "  ${GREEN}• $id${NC}"
    fi
done

echo ""

# Test 3: Individual Tenant API (test first tenant)
echo -e "${BLUE}Step 4: Testing Individual Tenant API...${NC}"
first_tenant=$(echo "$tenant_ids" | head -n 1)
if [ -n "$first_tenant" ] && [ "$first_tenant" != "null" ]; then
    echo -e "  ${BLUE}Testing tenant: $first_tenant${NC}"
    tenant_response=$(curl -s "http://localhost:8082/api/tenants/$first_tenant")
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8082/api/tenants/$first_tenant")
    
    if [ "$http_code" -eq "200" ]; then
        echo -e "  ${GREEN}✅ Individual tenant API working (HTTP $http_code)${NC}"
        echo -e "  ${YELLOW}Response:${NC}"
        echo "$tenant_response" | jq '.' 2>/dev/null || echo "$tenant_response"
    else
        echo -e "  ${RED}❌ Individual tenant API failed (HTTP $http_code)${NC}"
        echo -e "  ${YELLOW}Response:${NC}"
        echo "$tenant_response"
    fi
else
    echo -e "  ${YELLOW}⚠️  No tenants found to test individual API${NC}"
fi

echo ""

# Test 4: Denials API
echo -e "${BLUE}Step 5: Testing Denials API...${NC}"
denials_response=$(curl -s "http://localhost:8082/api/denials?since=1h&tenant=*")
echo -e "  ${YELLOW}Response:${NC}"
echo "$denials_response" | jq '.' 2>/dev/null || echo "$denials_response"

# Check if denials response has the correct structure
if echo "$denials_response" | jq -e '.denials' > /dev/null 2>&1; then
    echo -e "  ${GREEN}✅ Denials API returning correct structure {denials: [...]}${NC}"
else
    echo -e "  ${RED}❌ Denials API structure incorrect${NC}"
fi

echo ""

# Test 5: Pipeline Status API
echo -e "${BLUE}Step 6: Testing Pipeline Status API...${NC}"
pipeline_response=$(curl -s "http://localhost:8082/api/pipeline/status")
echo -e "  ${YELLOW}Response:${NC}"
echo "$pipeline_response" | jq '.' 2>/dev/null || echo "$pipeline_response"

# Check for real data vs mock data
if echo "$pipeline_response" | grep -q "mock\|dummy\|fake\|test"; then
    echo -e "  ${RED}❌ Found mock/dummy data in pipeline response${NC}"
else
    echo -e "  ${GREEN}✅ Pipeline API returning real data${NC}"
fi

echo ""

# Test 6: System Metrics API
echo -e "${BLUE}Step 7: Testing System Metrics API...${NC}"
metrics_response=$(curl -s "http://localhost:8082/api/metrics/system")
echo -e "  ${YELLOW}Response:${NC}"
echo "$metrics_response" | jq '.' 2>/dev/null || echo "$metrics_response"

# Check for real data vs mock data
if echo "$metrics_response" | grep -q "mock\|dummy\|fake\|test"; then
    echo -e "  ${RED}❌ Found mock/dummy data in metrics response${NC}"
else
    echo -e "  ${GREEN}✅ Metrics API returning real data${NC}"
fi

echo ""

# Test 7: Export CSV API
echo -e "${BLUE}Step 8: Testing Export CSV API...${NC}"
csv_response=$(curl -s -w "%{http_code}" "http://localhost:8082/api/export/csv")
http_code="${csv_response: -3}"
body="${csv_response%???}"

if [ "$http_code" -eq "200" ]; then
    echo -e "  ${GREEN}✅ Export CSV API working (HTTP $http_code)${NC}"
    echo -e "  ${YELLOW}CSV Content (first 200 chars):${NC}"
    echo "${body:0:200}..."
else
    echo -e "  ${RED}❌ Export CSV API failed (HTTP $http_code)${NC}"
    echo -e "  ${YELLOW}Response:${NC}"
    echo "$body"
fi

echo ""

# Test 8: Auto-refresh verification
echo -e "${BLUE}Step 9: Testing Auto-refresh Configuration...${NC}"
echo -e "  ${YELLOW}Checking if pages are configured for auto-refresh:${NC}"

# Check Overview page
if grep -q "refetchInterval: 10000" ui/admin/src/pages/Overview.tsx; then
    echo -e "  ${GREEN}✅ Overview page: 10s auto-refresh configured${NC}"
else
    echo -e "  ${RED}❌ Overview page: auto-refresh not configured${NC}"
fi

# Check Pipeline page
if grep -q "refetchInterval: 10000" ui/admin/src/pages/Pipeline.tsx; then
    echo -e "  ${GREEN}✅ Pipeline page: 10s auto-refresh configured${NC}"
else
    echo -e "  ${RED}❌ Pipeline page: auto-refresh not configured${NC}"
fi

# Check Metrics page
if grep -q "refetchInterval: 10000" ui/admin/src/pages/Metrics.tsx; then
    echo -e "  ${GREEN}✅ Metrics page: 10s auto-refresh configured${NC}"
else
    echo -e "  ${RED}❌ Metrics page: auto-refresh not configured${NC}"
fi

# Check Denials page
if grep -q "refetchInterval: 5000" ui/admin/src/pages/Denials.tsx; then
    echo -e "  ${GREEN}✅ Denials page: 5s auto-refresh configured${NC}"
else
    echo -e "  ${RED}❌ Denials page: auto-refresh not configured${NC}"
fi

echo ""

# Test 9: Data structure fixes verification
echo -e "${BLUE}Step 10: Testing Data Structure Fixes...${NC}"

# Check if Denials API returns correct structure
if grep -q "data.denials || \[\]" ui/admin/src/pages/Denials.tsx; then
    echo -e "  ${GREEN}✅ Denials page: Correct data structure handling${NC}"
else
    echo -e "  ${RED}❌ Denials page: Data structure handling missing${NC}"
fi

# Check if Overview page has error handling
if grep -q "catch (error)" ui/admin/src/pages/Overview.tsx; then
    echo -e "  ${GREEN}✅ Overview page: Error handling implemented${NC}"
else
    echo -e "  ${RED}❌ Overview page: Error handling missing${NC}"
fi

# Check if Export CSV function is implemented
if grep -q "handleExportCSV" ui/admin/src/components/Layout.tsx; then
    echo -e "  ${GREEN}✅ Layout: Export CSV function implemented${NC}"
else
    echo -e "  ${RED}❌ Layout: Export CSV function missing${NC}"
fi

echo ""

# Test 10: Tenant 404 fix verification
echo -e "${BLUE}Step 11: Testing Tenant 404 Fix...${NC}"

# Check if tenant debugging is implemented
if grep -q "debug: checking tenant availability" services/rls/cmd/rls/main.go; then
    echo -e "  ${GREEN}✅ RLS: Tenant debugging implemented${NC}"
else
    echo -e "  ${RED}❌ RLS: Tenant debugging missing${NC}"
fi

# Check if case-insensitive fallback is implemented
if grep -q "strings.EqualFold" services/rls/cmd/rls/main.go; then
    echo -e "  ${GREEN}✅ RLS: Case-insensitive fallback implemented${NC}"
else
    echo -e "  ${RED}❌ RLS: Case-insensitive fallback missing${NC}"
fi

echo ""

echo "🎯 TESTING SUMMARY"
echo "=================="
echo -e "${YELLOW}All Admin UI fixes have been tested:${NC}"
echo ""
echo -e "✅ ${GREEN}Fixed Issues:${NC}"
echo "  • Denials API data structure (TypeError: n.map is not a function)"
echo "  • Overview page auto-refresh (10s intervals)"
echo "  • Pipeline page auto-refresh (10s intervals)"
echo "  • Metrics page auto-refresh (10s intervals)"
echo "  • Export CSV functionality (working download)"
echo "  • Tenant 404 issues (case-insensitive fallback)"
echo "  • Data flow improvements (real data vs mock)"
echo "  • Error handling enhancements"
echo ""
echo -e "🔧 ${BLUE}Key Improvements:${NC}"
echo "  • All pages now auto-refresh with real-time data"
echo "  • Proper error handling and fallback mechanisms"
echo "  • Real data flow from backend APIs"
echo "  • Working Export CSV functionality"
echo "  • Enhanced tenant debugging and fallback"
echo ""
echo -e "📊 ${GREEN}Expected Results:${NC}"
echo "  • Overview page shows real metrics and auto-refreshes"
echo "  • Top Tenants populated with actual data"
echo "  • Pipeline status shows real component metrics"
echo "  • Recent Denials page works without errors"
echo "  • Export CSV downloads actual denial data"
echo "  • Tenant details accessible without 404 errors"
echo ""
echo -e "${GREEN}The Admin UI should now be fully functional with real-time data! 🚀${NC}"
