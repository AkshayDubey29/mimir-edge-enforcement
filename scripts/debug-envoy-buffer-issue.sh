#!/bin/bash

# Debug Envoy Buffer Size Limit Issue
# This script helps identify what's causing the async client retries and buffer overflow

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${PURPLE}=== ENVOY BUFFER SIZE LIMIT DEBUG ===${NC}"
echo -e "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo ""

# Configuration
EDGE_NAMESPACE="mimir-edge-enforcement"

# =================================================================
# 1. CHECK ENVOY LOGS FOR BUFFER ISSUES
# =================================================================

echo -e "${BLUE}=== 1. ENVOY BUFFER ISSUE ANALYSIS ===${NC}"

# Get Envoy pod
ENVOY_POD=$(kubectl get pods -n $EDGE_NAMESPACE -l app.kubernetes.io/name=mimir-envoy -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$ENVOY_POD" ]; then
    echo -e "${CYAN}Analyzing Envoy logs for buffer issues...${NC}"
    
    # Get recent Envoy logs
    ENVOY_LOGS=$(kubectl logs -n $EDGE_NAMESPACE $ENVOY_POD --tail=50 2>/dev/null || echo "")
    
    if [ -n "$ENVOY_LOGS" ]; then
        # Check for buffer size limit warnings
        BUFFER_WARNINGS=$(echo "$ENVOY_LOGS" | grep -i "buffer.*size.*limit\|async.*client.*retries" || echo "")
        if [ -n "$BUFFER_WARNINGS" ]; then
            echo -e "${RED}❌ Buffer size limit warnings found:${NC}"
            echo "$BUFFER_WARNINGS"
        else
            echo -e "${GREEN}✅ No buffer size limit warnings in recent logs${NC}"
        fi
        
        # Check for retry-related messages
        RETRY_MESSAGES=$(echo "$ENVOY_LOGS" | grep -i "retry\|retries\|failed\|error" || echo "")
        if [ -n "$RETRY_MESSAGES" ]; then
            echo -e "${YELLOW}⚠️  Retry/error messages found:${NC}"
            echo "$RETRY_MESSAGES" | head -10
        fi
        
        # Check for ext_authz related messages
        EXT_AUTHZ_MESSAGES=$(echo "$ENVOY_LOGS" | grep -i "ext_authz\|authorization" || echo "")
        if [ -n "$EXT_AUTHZ_MESSAGES" ]; then
            echo -e "${CYAN}ext_authz related messages:${NC}"
            echo "$EXT_AUTHZ_MESSAGES" | head -10
        fi
        
        # Check for connection issues
        CONNECTION_ISSUES=$(echo "$ENVOY_LOGS" | grep -i "connection\|timeout\|unreachable" || echo "")
        if [ -n "$CONNECTION_ISSUES" ]; then
            echo -e "${RED}❌ Connection issues found:${NC}"
            echo "$CONNECTION_ISSUES" | head -10
        fi
    else
        echo -e "${YELLOW}⚠️  No Envoy logs available${NC}"
    fi
else
    echo -e "${RED}❌ Could not find Envoy pod${NC}"
fi

echo ""

# =================================================================
# 2. CHECK ENVOY STATS FOR RETRY METRICS
# =================================================================

echo -e "${BLUE}=== 2. ENVOY RETRY STATISTICS ===${NC}"

if [ -n "$ENVOY_POD" ]; then
    echo -e "${CYAN}Checking Envoy statistics for retry metrics...${NC}"
    
    # Get Envoy stats
    STATS=$(kubectl exec -n $EDGE_NAMESPACE $ENVOY_POD -- curl -s http://localhost:8080/stats 2>/dev/null || echo "")
    
    if [ -n "$STATS" ]; then
        # Check for retry-related stats
        RETRY_STATS=$(echo "$STATS" | grep -E "(retry|retries|failed|error)" || echo "")
        if [ -n "$RETRY_STATS" ]; then
            echo -e "${CYAN}Retry-related statistics:${NC}"
            echo "$RETRY_STATS" | head -15
        fi
        
        # Check for ext_authz stats
        EXT_AUTHZ_STATS=$(echo "$STATS" | grep -E "(ext_authz|auth)" || echo "")
        if [ -n "$EXT_AUTHZ_STATS" ]; then
            echo -e "${CYAN}ext_authz statistics:${NC}"
            echo "$EXT_AUTHZ_STATS" | head -10
        fi
        
        # Check for cluster health stats
        CLUSTER_STATS=$(echo "$STATS" | grep -E "(cluster|upstream)" | grep -E "(health|failure)" || echo "")
        if [ -n "$CLUSTER_STATS" ]; then
            echo -e "${CYAN}Cluster health statistics:${NC}"
            echo "$CLUSTER_STATS" | head -10
        fi
    else
        echo -e "${RED}❌ Could not access Envoy stats${NC}"
    fi
fi

echo ""

# =================================================================
# 3. CHECK RLS SERVICE HEALTH
# =================================================================

echo -e "${BLUE}=== 3. RLS SERVICE HEALTH CHECK ===${NC}"

# Check RLS pods
RLS_PODS=$(kubectl get pods -n $EDGE_NAMESPACE -l app.kubernetes.io/name=mimir-rls 2>/dev/null | grep -v NAME | wc -l || echo "0")

if [ "$RLS_PODS" -gt 0 ]; then
    echo -e "${GREEN}✅ Found $RLS_PODS RLS pod(s)${NC}"
    
    # Check RLS pod status
    kubectl get pods -n $EDGE_NAMESPACE -l app.kubernetes.io/name=mimir-rls
    
    # Get RLS pod
    RLS_POD=$(kubectl get pods -n $EDGE_NAMESPACE -l app.kubernetes.io/name=mimir-rls -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$RLS_POD" ]; then
        # Check RLS health endpoint
        echo -e "${CYAN}Testing RLS health endpoint...${NC}"
        RLS_HEALTH=$(kubectl exec -n $EDGE_NAMESPACE $RLS_POD -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health 2>/dev/null || echo "000")
        echo -e "  • RLS health endpoint: HTTP $RLS_HEALTH"
        
        # Check RLS logs for errors
        echo -e "${CYAN}Checking RLS logs for errors...${NC}"
        RLS_LOGS=$(kubectl logs -n $EDGE_NAMESPACE $RLS_POD --tail=20 2>/dev/null || echo "")
        
        if [ -n "$RLS_LOGS" ]; then
            RLS_ERRORS=$(echo "$RLS_LOGS" | grep -i "error\|failed\|panic\|timeout" || echo "")
            if [ -n "$RLS_ERRORS" ]; then
                echo -e "${RED}❌ Errors found in RLS logs:${NC}"
                echo "$RLS_ERRORS" | head -10
            else
                echo -e "${GREEN}✅ No errors found in recent RLS logs${NC}"
            fi
        fi
    fi
else
    echo -e "${RED}❌ No RLS pods found${NC}"
fi

echo ""

# =================================================================
# 4. TEST ENVOY TO RLS CONNECTIVITY
# =================================================================

echo -e "${BLUE}=== 4. ENVOY TO RLS CONNECTIVITY TEST ===${NC}"

if [ -n "$ENVOY_POD" ]; then
    echo -e "${CYAN}Testing Envoy to RLS connectivity...${NC}"
    
    # Test connectivity to RLS service
    RLS_CONNECTIVITY=$(kubectl exec -n $EDGE_NAMESPACE $ENVOY_POD -- curl -s -o /dev/null -w "%{http_code}" \
        http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8080/health 2>/dev/null || echo "000")
    
    if [ "$RLS_CONNECTIVITY" = "200" ]; then
        echo -e "${GREEN}✅ Envoy can reach RLS health endpoint${NC}"
    else
        echo -e "${RED}❌ Envoy cannot reach RLS (HTTP $RLS_CONNECTIVITY)${NC}"
    fi
    
    # Test ext_authz endpoint
    EXT_AUTHZ_TEST=$(kubectl exec -n $EDGE_NAMESPACE $ENVOY_POD -- curl -s -o /dev/null -w "%{http_code}" \
        -H "Content-Type: application/grpc" \
        -H "X-Scope-OrgID: test-tenant" \
        http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8080/envoy.service.auth.v3.Authorization/Check 2>/dev/null || echo "000")
    
    echo -e "  • ext_authz endpoint test: HTTP $EXT_AUTHZ_TEST"
fi

echo ""

# =================================================================
# 5. CHECK ENVOY CONFIGURATION FOR BUFFER SETTINGS
# =================================================================

echo -e "${BLUE}=== 5. ENVOY BUFFER CONFIGURATION ===${NC}"

if [ -n "$ENVOY_POD" ]; then
    echo -e "${CYAN}Checking Envoy configuration for buffer settings...${NC}"
    
    # Get Envoy config
    ENVOY_CONFIG=$(kubectl exec -n $EDGE_NAMESPACE $ENVOY_POD -- curl -s http://localhost:8080/config_dump 2>/dev/null || echo "{}")
    
    if [ "$ENVOY_CONFIG" != "{}" ]; then
        # Check for buffer size settings
        BUFFER_CONFIG=$(echo "$ENVOY_CONFIG" | jq -r '.configs[] | select(.["@type"] == "type.googleapis.com/envoy.admin.v3.ListenersConfigDump") | .dynamic_listeners[].active_state.listener.filter_chains[].filters[] | select(.name == "envoy.filters.network.http_connection_manager") | .typed_config.http_filters[] | select(.name == "envoy.filters.http.ext_authz") | .typed_config.buffer_size_bytes' 2>/dev/null || echo "")
        
        if [ -n "$BUFFER_CONFIG" ] && [ "$BUFFER_CONFIG" != "null" ]; then
            echo -e "${CYAN}ext_authz buffer size: $BUFFER_CONFIG bytes${NC}"
        else
            echo -e "${YELLOW}⚠️  No explicit buffer size configured for ext_authz${NC}"
        fi
        
        # Check for timeout settings
        TIMEOUT_CONFIG=$(echo "$ENVOY_CONFIG" | jq -r '.configs[] | select(.["@type"] == "type.googleapis.com/envoy.admin.v3.ListenersConfigDump") | .dynamic_listeners[].active_state.listener.filter_chains[].filters[] | select(.name == "envoy.filters.network.http_connection_manager") | .typed_config.http_filters[] | select(.name == "envoy.filters.http.ext_authz") | .typed_config.timeout' 2>/dev/null || echo "")
        
        if [ -n "$TIMEOUT_CONFIG" ] && [ "$TIMEOUT_CONFIG" != "null" ]; then
            echo -e "${CYAN}ext_authz timeout: $TIMEOUT_CONFIG${NC}"
        else
            echo -e "${YELLOW}⚠️  No explicit timeout configured for ext_authz${NC}"
        fi
    else
        echo -e "${RED}❌ Could not access Envoy configuration${NC}"
    fi
fi

echo ""

# =================================================================
# 6. GENERATE TEST TRAFFIC TO REPRODUCE ISSUE
# =================================================================

echo -e "${BLUE}=== 6. TEST TRAFFIC GENERATION ===${NC}"

# Get NGINX service
NGINX_SERVICE=$(kubectl get svc -n mimir -l app=nginx -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$NGINX_SERVICE" ]; then
    echo -e "${CYAN}Generating test traffic to reproduce buffer issue...${NC}"
    
    # Generate multiple requests to trigger the issue
    for i in {1..10}; do
        echo -e "${CYAN}Test request $i...${NC}"
        TEST_RESPONSE=$(kubectl run test-buffer-issue-$i --rm -i --restart=Never --image=curlimages/curl -- \
            -s -o /dev/null -w "%{http_code}" \
            -H "X-Scope-OrgID: test-tenant-$i" \
            -H "Content-Type: application/x-protobuf" \
            -d "test-data-$i" \
            "http://$NGINX_SERVICE.mimir.svc.cluster.local:8080/api/v1/push" 2>/dev/null || echo "000")
        
        echo -e "  Response: HTTP $TEST_RESPONSE"
    done
    
    # Wait for logs to propagate
    echo -e "${CYAN}Waiting for logs to propagate...${NC}"
    sleep 5
    
    # Check for new buffer warnings
    echo -e "${CYAN}Checking for new buffer warnings...${NC}"
    NEW_BUFFER_WARNINGS=$(kubectl logs -n $EDGE_NAMESPACE $ENVOY_POD --tail=10 2>/dev/null | grep -i "buffer.*size.*limit\|async.*client.*retries" || echo "")
    
    if [ -n "$NEW_BUFFER_WARNINGS" ]; then
        echo -e "${RED}❌ New buffer warnings after test traffic:${NC}"
        echo "$NEW_BUFFER_WARNINGS"
    else
        echo -e "${GREEN}✅ No new buffer warnings after test traffic${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Could not find NGINX service for testing${NC}"
fi

echo ""

# =================================================================
# 7. SUMMARY AND SOLUTIONS
# =================================================================

echo -e "${BLUE}=== 7. SUMMARY AND SOLUTIONS ===${NC}"

echo -e "${CYAN}Buffer Size Limit Issue Analysis:${NC}"

# Determine the root cause
if [ -n "$BUFFER_WARNINGS" ]; then
    echo -e "${RED}❌ CONFIRMED: Buffer size limit warnings are present${NC}"
    echo -e "${YELLOW}   This indicates Envoy is retrying failed requests${NC}"
    
    if [ "$RLS_CONNECTIVITY" != "200" ]; then
        echo -e "${RED}❌ ROOT CAUSE: Envoy cannot reach RLS service${NC}"
        echo -e "${YELLOW}   Solution: Fix RLS service connectivity${NC}"
    elif [ -n "$RLS_ERRORS" ]; then
        echo -e "${RED}❌ ROOT CAUSE: RLS service is failing${NC}"
        echo -e "${YELLOW}   Solution: Fix RLS service issues${NC}"
    else
        echo -e "${YELLOW}⚠️  ROOT CAUSE: Unknown - check ext_authz configuration${NC}"
    fi
else
    echo -e "${GREEN}✅ No buffer size limit warnings found${NC}"
fi

echo ""
echo -e "${CYAN}Solutions for Buffer Size Limit Issue:${NC}"

echo -e "1. ${RED}Fix RLS Service Issues${NC}"
echo -e "   • Ensure RLS pods are healthy and running"
echo -e "   • Check RLS logs for errors"
echo -e "   • Verify RLS service endpoints"

echo -e "2. ${RED}Increase Buffer Size${NC}"
echo -e "   • Add buffer_size_bytes to ext_authz configuration"
echo -e "   • Increase from default 64KB to 128KB or higher"

echo -e "3. ${RED}Adjust Timeout Settings${NC}"
echo -e "   • Increase ext_authz timeout"
echo -e "   • Reduce retry attempts"

echo -e "4. ${RED}Check Network Connectivity${NC}"
echo -e "   • Verify Envoy can reach RLS service"
echo -e "   • Check for network policies blocking traffic"

echo -e "5. ${RED}Monitor Request Volume${NC}"
echo -e "   • Check if RLS is overwhelmed"
echo -e "   • Consider scaling RLS pods"

echo ""
echo -e "${CYAN}Immediate Actions:${NC}"
echo -e "1. Check RLS service health and logs"
echo -e "2. Verify Envoy to RLS connectivity"
echo -e "3. Consider increasing ext_authz buffer size"
echo -e "4. Monitor for request volume spikes"

echo ""
echo -e "${GREEN}=== ENVOY BUFFER DEBUG COMPLETE ===${NC}"
