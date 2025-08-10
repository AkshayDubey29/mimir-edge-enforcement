#!/bin/bash

# Debug NGINX to Envoy Traffic Flow
# This script helps identify why NGINX is not sending traffic to Envoy

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${PURPLE}=== NGINX TO ENVOY TRAFFIC FLOW DEBUG ===${NC}"
echo -e "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo ""

# Configuration
NAMESPACE="mimir"
EDGE_NAMESPACE="mimir-edge-enforcement"

# =================================================================
# 1. CHECK NGINX CONFIGURATION
# =================================================================

echo -e "${BLUE}=== 1. NGINX CONFIGURATION ANALYSIS ===${NC}"

# Check if NGINX ConfigMap exists
if kubectl get configmap mimir-nginx -n $NAMESPACE > /dev/null 2>&1; then
    echo -e "${GREEN}✅ NGINX ConfigMap exists${NC}"
    
    # Get NGINX configuration
    NGINX_CONFIG=$(kubectl get configmap mimir-nginx -n $NAMESPACE -o jsonpath='{.data.nginx\.conf}')
    
    echo -e "${CYAN}Analyzing NGINX configuration...${NC}"
    
    # Check canary hash configuration
    echo -e "${CYAN}Canary hash configuration:${NC}"
    echo "$NGINX_CONFIG" | grep -A 5 -B 5 "canary_hash" || echo "No canary_hash found"
    
    # Check route decision configuration
    echo -e "${CYAN}Route decision configuration:${NC}"
    echo "$NGINX_CONFIG" | grep -A 5 -B 5 "route_decision" || echo "No route_decision found"
    
    # Check upstream configuration
    echo -e "${CYAN}Upstream configuration:${NC}"
    echo "$NGINX_CONFIG" | grep -A 10 -B 5 "upstream" || echo "No upstream found"
    
    # Check /api/v1/push location
    echo -e "${CYAN}/api/v1/push location configuration:${NC}"
    echo "$NGINX_CONFIG" | grep -A 15 -B 5 "location.*api/v1/push" || echo "No /api/v1/push location found"
    
    # Check for edge enforcement routing
    if echo "$NGINX_CONFIG" | grep -q "mimir_via_edge_enforcement"; then
        echo -e "${GREEN}✅ Edge enforcement upstream configured${NC}"
    else
        echo -e "${RED}❌ Edge enforcement upstream NOT configured${NC}"
    fi
    
    # Check for route decision logic
    if echo "$NGINX_CONFIG" | grep -q 'default "edge"'; then
        echo -e "${GREEN}✅ Route decision defaults to edge enforcement${NC}"
    else
        echo -e "${RED}❌ Route decision does NOT default to edge enforcement${NC}"
    fi
    
else
    echo -e "${RED}❌ NGINX ConfigMap not found${NC}"
    echo -e "${YELLOW}   This means NGINX is not configured for edge enforcement${NC}"
fi

echo ""

# =================================================================
# 2. CHECK NGINX LOGS FOR TRAFFIC
# =================================================================

echo -e "${BLUE}=== 2. NGINX TRAFFIC ANALYSIS ===${NC}"

# Check NGINX pods
NGINX_PODS=$(kubectl get pods -n $NAMESPACE -l app=nginx 2>/dev/null | grep -v NAME | wc -l || echo "0")

if [ "$NGINX_PODS" -gt 0 ]; then
    echo -e "${GREEN}✅ Found $NGINX_PODS NGINX pod(s)${NC}"
    
    # Get recent NGINX logs
    echo -e "${CYAN}Recent NGINX logs (last 20 lines):${NC}"
    NGINX_LOGS=$(kubectl logs -n $NAMESPACE -l app=nginx --tail=20 2>/dev/null || echo "")
    
    if [ -n "$NGINX_LOGS" ]; then
        echo "$NGINX_LOGS"
        
        # Analyze traffic patterns
        echo -e "${CYAN}Traffic pattern analysis:${NC}"
        
        # Count different types of requests
        TOTAL_REQUESTS=$(echo "$NGINX_LOGS" | grep -c "HTTP/[0-9]" || echo "0")
        EDGE_REQUESTS=$(echo "$NGINX_LOGS" | grep -c "route=edge" || echo "0")
        DIRECT_REQUESTS=$(echo "$NGINX_LOGS" | grep -c "route=direct" || echo "0")
        PUSH_REQUESTS=$(echo "$NGINX_LOGS" | grep -c "/api/v1/push" || echo "0")
        
        echo -e "  • Total HTTP requests: $TOTAL_REQUESTS"
        echo -e "  • Edge enforcement requests: $EDGE_REQUESTS"
        echo -e "  • Direct requests: $DIRECT_REQUESTS"
        echo -e "  • /api/v1/push requests: $PUSH_REQUESTS"
        
        if [ "$PUSH_REQUESTS" -gt 0 ]; then
            echo -e "${GREEN}✅ NGINX is receiving /api/v1/push requests${NC}"
            
            if [ "$EDGE_REQUESTS" -gt 0 ]; then
                echo -e "${GREEN}✅ Some requests are being routed to edge enforcement${NC}"
            else
                echo -e "${RED}❌ No requests are being routed to edge enforcement${NC}"
                echo -e "${YELLOW}   All /api/v1/push requests are going direct${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  No /api/v1/push requests found in NGINX logs${NC}"
            echo -e "${YELLOW}   This could mean:${NC}"
            echo -e "     • No traffic is being sent to NGINX"
            echo -e "     • Traffic is going to a different endpoint"
            echo -e "     • NGINX is not the entry point"
        fi
        
        # Show recent /api/v1/push requests
        if [ "$PUSH_REQUESTS" -gt 0 ]; then
            echo -e "${CYAN}Recent /api/v1/push requests:${NC}"
            echo "$NGINX_LOGS" | grep "/api/v1/push" | tail -5
        fi
        
    else
        echo -e "${YELLOW}⚠️  No NGINX logs available${NC}"
    fi
else
    echo -e "${RED}❌ No NGINX pods found${NC}"
fi

echo ""

# =================================================================
# 3. CHECK ENVOY LOGS
# =================================================================

echo -e "${BLUE}=== 3. ENVOY LOGS ANALYSIS ===${NC}"

# Check Envoy pods
ENVOY_PODS=$(kubectl get pods -n $EDGE_NAMESPACE -l app.kubernetes.io/name=mimir-envoy 2>/dev/null | grep -v NAME | wc -l || echo "0")

if [ "$ENVOY_PODS" -gt 0 ]; then
    echo -e "${GREEN}✅ Found $ENVOY_PODS Envoy pod(s)${NC}"
    
    # Get recent Envoy logs
    echo -e "${CYAN}Recent Envoy logs (last 20 lines):${NC}"
    ENVOY_LOGS=$(kubectl logs -n $EDGE_NAMESPACE -l app.kubernetes.io/name=mimir-envoy --tail=20 2>/dev/null || echo "")
    
    if [ -n "$ENVOY_LOGS" ]; then
        echo "$ENVOY_LOGS"
        
        # Analyze Envoy traffic
        echo -e "${CYAN}Envoy traffic analysis:${NC}"
        
        # Count different types of requests
        TOTAL_ENVOY_REQUESTS=$(echo "$ENVOY_LOGS" | grep -c "HTTP/[0-9]" || echo "0")
        READY_REQUESTS=$(echo "$ENVOY_LOGS" | grep -c "/ready" || echo "0")
        PUSH_ENVOY_REQUESTS=$(echo "$ENVOY_LOGS" | grep -c "/api/v1/push" || echo "0")
        EXT_AUTHZ_REQUESTS=$(echo "$ENVOY_LOGS" | grep -c "ext_authz" || echo "0")
        
        echo -e "  • Total HTTP requests: $TOTAL_ENVOY_REQUESTS"
        echo -e "  • /ready health checks: $READY_REQUESTS"
        echo -e "  • /api/v1/push requests: $PUSH_ENVOY_REQUESTS"
        echo -e "  • ext_authz requests: $EXT_AUTHZ_REQUESTS"
        
        if [ "$PUSH_ENVOY_REQUESTS" -gt 0 ]; then
            echo -e "${GREEN}✅ Envoy is receiving /api/v1/push requests${NC}"
        else
            echo -e "${RED}❌ Envoy is NOT receiving /api/v1/push requests${NC}"
            echo -e "${YELLOW}   Only health checks (/ready) are reaching Envoy${NC}"
        fi
        
        if [ "$EXT_AUTHZ_REQUESTS" -gt 0 ]; then
            echo -e "${GREEN}✅ Envoy is making ext_authz calls to RLS${NC}"
        else
            echo -e "${RED}❌ Envoy is NOT making ext_authz calls to RLS${NC}"
        fi
        
    else
        echo -e "${YELLOW}⚠️  No Envoy logs available${NC}"
    fi
else
    echo -e "${RED}❌ No Envoy pods found${NC}"
fi

echo ""

# =================================================================
# 4. TEST NGINX TO ENVOY CONNECTIVITY
# =================================================================

echo -e "${BLUE}=== 4. NGINX TO ENVOY CONNECTIVITY TEST ===${NC}"

# Get NGINX pod
NGINX_POD=$(kubectl get pods -n $NAMESPACE -l app=nginx -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$NGINX_POD" ]; then
    echo -e "${CYAN}Testing NGINX to Envoy connectivity from pod: $NGINX_POD${NC}"
    
    # Test basic connectivity
    echo -e "${CYAN}Testing basic connectivity to Envoy service...${NC}"
    CONNECTIVITY_TEST=$(kubectl exec -n $NAMESPACE $NGINX_POD -- curl -s -o /dev/null -w "%{http_code}" \
        http://mimir-envoy.mimir-edge-enforcement.svc.cluster.local:8080/ready 2>/dev/null || echo "000")
    
    if [ "$CONNECTIVITY_TEST" = "200" ]; then
        echo -e "${GREEN}✅ NGINX can reach Envoy /ready endpoint${NC}"
    else
        echo -e "${RED}❌ NGINX cannot reach Envoy (HTTP $CONNECTIVITY_TEST)${NC}"
    fi
    
    # Test the actual endpoint that should be routed
    echo -e "${CYAN}Testing /api/v1/push endpoint routing...${NC}"
    PUSH_TEST=$(kubectl exec -n $NAMESPACE $NGINX_POD -- curl -s -o /dev/null -w "%{http_code}" \
        -H "X-Scope-OrgID: test-tenant" \
        http://mimir-envoy.mimir-edge-enforcement.svc.cluster.local:8080/api/v1/push 2>/dev/null || echo "000")
    
    if [ "$PUSH_TEST" != "000" ]; then
        echo -e "${GREEN}✅ NGINX can reach Envoy /api/v1/push endpoint (HTTP $PUSH_TEST)${NC}"
    else
        echo -e "${RED}❌ NGINX cannot reach Envoy /api/v1/push endpoint${NC}"
    fi
    
else
    echo -e "${YELLOW}⚠️  Could not find NGINX pod for connectivity test${NC}"
fi

echo ""

# =================================================================
# 5. CHECK NGINX ROUTING LOGIC
# =================================================================

echo -e "${BLUE}=== 5. NGINX ROUTING LOGIC DEBUG ===${NC}"

if [ -n "$NGINX_CONFIG" ]; then
    echo -e "${CYAN}Analyzing NGINX routing logic...${NC}"
    
    # Check if the routing logic is correct
    echo -e "${CYAN}Current routing configuration:${NC}"
    
    # Extract the canary hash logic
    CANARY_HASH=$(echo "$NGINX_CONFIG" | grep -A 3 "canary_hash" | head -4)
    if [ -n "$CANARY_HASH" ]; then
        echo -e "${CYAN}Canary hash logic:${NC}"
        echo "$CANARY_HASH"
    fi
    
    # Extract the route decision logic
    ROUTE_DECISION=$(echo "$NGINX_CONFIG" | grep -A 3 "route_decision" | head -4)
    if [ -n "$ROUTE_DECISION" ]; then
        echo -e "${CYAN}Route decision logic:${NC}"
        echo "$ROUTE_DECISION"
    fi
    
    # Extract the /api/v1/push location
    PUSH_LOCATION=$(echo "$NGINX_CONFIG" | grep -A 10 "location.*api/v1/push")
    if [ -n "$PUSH_LOCATION" ]; then
        echo -e "${CYAN}/api/v1/push location:${NC}"
        echo "$PUSH_LOCATION"
    fi
    
    # Check for potential issues
    echo -e "${CYAN}Potential issues:${NC}"
    
    if echo "$NGINX_CONFIG" | grep -q "default 0"; then
        echo -e "${RED}❌ Canary hash defaults to 0 (direct routing)${NC}"
        echo -e "${YELLOW}   This means most traffic goes direct, not to edge enforcement${NC}"
    fi
    
    if echo "$NGINX_CONFIG" | grep -q 'default "direct"'; then
        echo -e "${RED}❌ Route decision defaults to direct${NC}"
        echo -e "${YELLOW}   This means traffic bypasses edge enforcement${NC}"
    fi
    
    if ! echo "$NGINX_CONFIG" | grep -q "mimir_via_edge_enforcement"; then
        echo -e "${RED}❌ Edge enforcement upstream not configured${NC}"
        echo -e "${YELLOW}   NGINX doesn't know where to send edge enforcement traffic${NC}"
    fi
    
else
    echo -e "${YELLOW}⚠️  No NGINX configuration available for analysis${NC}"
fi

echo ""

# =================================================================
# 6. GENERATE TEST TRAFFIC
# =================================================================

echo -e "${BLUE}=== 6. GENERATE TEST TRAFFIC ===${NC}"

# Get NGINX service
NGINX_SERVICE=$(kubectl get svc -n $NAMESPACE -l app=nginx -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$NGINX_SERVICE" ]; then
    echo -e "${CYAN}Generating test traffic to NGINX...${NC}"
    
    # Make multiple test requests
    for i in {1..5}; do
        echo -e "${CYAN}Test request $i...${NC}"
        TEST_RESPONSE=$(kubectl run test-nginx-envoy-$i --rm -i --restart=Never --image=curlimages/curl -- \
            -s -o /dev/null -w "%{http_code}" \
            -H "X-Scope-OrgID: test-tenant-$i" \
            -H "Content-Type: application/x-protobuf" \
            -d "test-data-$i" \
            "http://$NGINX_SERVICE.$NAMESPACE.svc.cluster.local:8080/api/v1/push" 2>/dev/null || echo "000")
        
        echo -e "  Response: HTTP $TEST_RESPONSE"
    done
    
    # Wait for logs to propagate
    echo -e "${CYAN}Waiting for logs to propagate...${NC}"
    sleep 3
    
    # Check if test requests appeared in logs
    echo -e "${CYAN}Checking for test requests in NGINX logs...${NC}"
    TEST_LOGS=$(kubectl logs -n $NAMESPACE -l app=nginx --tail=10 2>/dev/null | grep "test-tenant" || echo "")
    
    if [ -n "$TEST_LOGS" ]; then
        echo -e "${GREEN}✅ Test requests found in NGINX logs:${NC}"
        echo "$TEST_LOGS"
    else
        echo -e "${YELLOW}⚠️  Test requests not found in recent NGINX logs${NC}"
    fi
    
    # Check if test requests appeared in Envoy logs
    echo -e "${CYAN}Checking for test requests in Envoy logs...${NC}"
    ENVOY_TEST_LOGS=$(kubectl logs -n $EDGE_NAMESPACE -l app.kubernetes.io/name=mimir-envoy --tail=10 2>/dev/null | grep "test-tenant" || echo "")
    
    if [ -n "$ENVOY_TEST_LOGS" ]; then
        echo -e "${GREEN}✅ Test requests found in Envoy logs:${NC}"
        echo "$ENVOY_TEST_LOGS"
    else
        echo -e "${RED}❌ Test requests NOT found in Envoy logs${NC}"
        echo -e "${YELLOW}   This confirms NGINX is not routing to Envoy${NC}"
    fi
    
else
    echo -e "${YELLOW}⚠️  Could not find NGINX service for testing${NC}"
fi

echo ""

# =================================================================
# 7. SUMMARY AND FIXES
# =================================================================

echo -e "${BLUE}=== 7. SUMMARY AND FIXES ===${NC}"

echo -e "${CYAN}Diagnosis Summary:${NC}"

# Determine the issue
if [ "$PUSH_REQUESTS" -gt 0 ] && [ "$PUSH_ENVOY_REQUESTS" -eq 0 ]; then
    echo -e "${RED}❌ ISSUE CONFIRMED: NGINX is receiving /api/v1/push requests but NOT routing them to Envoy${NC}"
    echo -e "${YELLOW}   NGINX is routing all traffic direct to Mimir, bypassing edge enforcement${NC}"
elif [ "$PUSH_REQUESTS" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No /api/v1/push requests are reaching NGINX${NC}"
    echo -e "${YELLOW}   This could be a different issue (traffic not reaching NGINX)${NC}"
else
    echo -e "${GREEN}✅ Traffic is flowing correctly through edge enforcement${NC}"
fi

echo ""
echo -e "${CYAN}Recommended Fixes:${NC}"

# Check if NGINX needs to be updated
if echo "$NGINX_CONFIG" | grep -q "default 0" || echo "$NGINX_CONFIG" | grep -q 'default "direct"'; then
    echo -e "${RED}1. UPDATE NGINX CONFIGURATION:${NC}"
    echo -e "   Run: ./scripts/deploy-100-percent-edge.sh"
    echo -e "   This will update NGINX to route 100% traffic through edge enforcement"
    echo ""
fi

if ! echo "$NGINX_CONFIG" | grep -q "mimir_via_edge_enforcement"; then
    echo -e "${RED}2. CONFIGURE EDGE ENFORCEMENT UPSTREAM:${NC}"
    echo -e "   The edge enforcement upstream is not configured in NGINX"
    echo -e "   Run: ./scripts/deploy-100-percent-edge.sh"
    echo ""
fi

echo -e "${CYAN}3. VERIFY AFTER FIX:${NC}"
echo -e "   • Check NGINX logs for 'route=edge' entries"
echo -e "   • Check Envoy logs for /api/v1/push requests"
echo -e "   • Check RLS logs for ext_authz calls"
echo -e "   • Monitor Admin UI traffic flow metrics"

echo ""
echo -e "${GREEN}=== NGINX TO ENVOY DEBUG COMPLETE ===${NC}"
