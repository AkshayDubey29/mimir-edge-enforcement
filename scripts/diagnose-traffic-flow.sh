#!/bin/bash

# Diagnose Traffic Flow Issues
# This script helps identify why traffic flow metrics are showing zeros

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${PURPLE}=== TRAFFIC FLOW DIAGNOSIS ===${NC}"
echo -e "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo ""

# Configuration
NAMESPACE="mimir"
EDGE_NAMESPACE="mimir-edge-enforcement"

# =================================================================
# 1. CHECK NGINX CONFIGURATION
# =================================================================

echo -e "${BLUE}=== 1. NGINX CONFIGURATION CHECK ===${NC}"

# Check if NGINX ConfigMap exists
if kubectl get configmap mimir-nginx -n $NAMESPACE > /dev/null 2>&1; then
    echo -e "${GREEN}✅ NGINX ConfigMap exists${NC}"
    
    # Check the routing configuration
    echo -e "${CYAN}Checking NGINX routing configuration...${NC}"
    NGINX_CONFIG=$(kubectl get configmap mimir-nginx -n $NAMESPACE -o jsonpath='{.data.nginx\.conf}')
    
    # Check for canary hash configuration
    if echo "$NGINX_CONFIG" | grep -q "default 1"; then
        echo -e "${GREEN}✅ NGINX configured for 100% edge enforcement${NC}"
    elif echo "$NGINX_CONFIG" | grep -q "default 0"; then
        echo -e "${RED}❌ NGINX still configured for canary (10% traffic)${NC}"
        echo -e "${YELLOW}   Need to update to 100% edge enforcement${NC}"
    else
        echo -e "${YELLOW}⚠️  Could not determine NGINX routing configuration${NC}"
    fi
    
    # Check for route decision mapping
    if echo "$NGINX_CONFIG" | grep -q 'default "edge"'; then
        echo -e "${GREEN}✅ Route decision mapped to edge enforcement${NC}"
    else
        echo -e "${RED}❌ Route decision not mapped to edge enforcement${NC}"
    fi
    
    # Check for upstream configuration
    if echo "$NGINX_CONFIG" | grep -q "mimir_via_edge_enforcement"; then
        echo -e "${GREEN}✅ Edge enforcement upstream configured${NC}"
    else
        echo -e "${RED}❌ Edge enforcement upstream not found${NC}"
    fi
else
    echo -e "${RED}❌ NGINX ConfigMap not found${NC}"
fi

echo ""

# =================================================================
# 2. CHECK NGINX PODS AND LOGS
# =================================================================

echo -e "${BLUE}=== 2. NGINX PODS AND LOGS ===${NC}"

# Check NGINX pods
NGINX_PODS=$(kubectl get pods -n $NAMESPACE -l app=nginx 2>/dev/null | grep -v NAME | wc -l || echo "0")

if [ "$NGINX_PODS" -gt 0 ]; then
    echo -e "${GREEN}✅ Found $NGINX_PODS NGINX pod(s)${NC}"
    
    # Check pod status
    kubectl get pods -n $NAMESPACE -l app=nginx
    
    # Check recent NGINX logs for traffic
    echo -e "${CYAN}Checking recent NGINX logs for traffic...${NC}"
    NGINX_LOGS=$(kubectl logs -n $NAMESPACE -l app=nginx --tail=20 2>/dev/null || echo "")
    
    if [ -n "$NGINX_LOGS" ]; then
        echo -e "${CYAN}Recent NGINX logs:${NC}"
        echo "$NGINX_LOGS" | tail -10
        
        # Check for edge enforcement traffic
        EDGE_TRAFFIC=$(echo "$NGINX_LOGS" | grep -c "route=edge" || echo "0")
        DIRECT_TRAFFIC=$(echo "$NGINX_LOGS" | grep -c "route=direct" || echo "0")
        
        echo -e "${CYAN}Traffic breakdown:${NC}"
        echo -e "  • Edge enforcement traffic: $EDGE_TRAFFIC requests"
        echo -e "  • Direct traffic: $DIRECT_TRAFFIC requests"
        
        if [ "$EDGE_TRAFFIC" -gt 0 ]; then
            echo -e "${GREEN}✅ NGINX is routing traffic to edge enforcement${NC}"
        else
            echo -e "${RED}❌ No edge enforcement traffic found in NGINX logs${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  No NGINX logs available${NC}"
    fi
else
    echo -e "${RED}❌ No NGINX pods found${NC}"
fi

echo ""

# =================================================================
# 3. CHECK ENVOY SERVICE
# =================================================================

echo -e "${BLUE}=== 3. ENVOY SERVICE CHECK ===${NC}"

# Check Envoy pods
ENVOY_PODS=$(kubectl get pods -n $EDGE_NAMESPACE -l app.kubernetes.io/name=mimir-envoy 2>/dev/null | grep -v NAME | wc -l || echo "0")

if [ "$ENVOY_PODS" -gt 0 ]; then
    echo -e "${GREEN}✅ Found $ENVOY_PODS Envoy pod(s)${NC}"
    
    # Check pod status
    kubectl get pods -n $EDGE_NAMESPACE -l app.kubernetes.io/name=mimir-envoy
    
    # Check Envoy logs
    echo -e "${CYAN}Checking recent Envoy logs...${NC}"
    ENVOY_LOGS=$(kubectl logs -n $EDGE_NAMESPACE -l app.kubernetes.io/name=mimir-envoy --tail=10 2>/dev/null || echo "")
    
    if [ -n "$ENVOY_LOGS" ]; then
        echo -e "${CYAN}Recent Envoy logs:${NC}"
        echo "$ENVOY_LOGS" | tail -5
    else
        echo -e "${YELLOW}⚠️  No Envoy logs available${NC}"
    fi
    
    # Check Envoy stats
    echo -e "${CYAN}Checking Envoy stats...${NC}"
    ENVOY_POD=$(kubectl get pods -n $EDGE_NAMESPACE -l app.kubernetes.io/name=mimir-envoy -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$ENVOY_POD" ]; then
        ENVOY_STATS=$(kubectl exec -n $EDGE_NAMESPACE $ENVOY_POD -- curl -s http://localhost:8080/stats 2>/dev/null || echo "")
        
        if [ -n "$ENVOY_STATS" ]; then
            echo -e "${CYAN}Envoy stats summary:${NC}"
            echo "$ENVOY_STATS" | grep -E "(http|ext_authz)" | head -10
        else
            echo -e "${YELLOW}⚠️  Could not fetch Envoy stats${NC}"
        fi
    fi
else
    echo -e "${RED}❌ No Envoy pods found${NC}"
fi

echo ""

# =================================================================
# 4. CHECK RLS SERVICE
# =================================================================

echo -e "${BLUE}=== 4. RLS SERVICE CHECK ===${NC}"

# Check RLS pods
RLS_PODS=$(kubectl get pods -n $EDGE_NAMESPACE -l app.kubernetes.io/name=mimir-rls 2>/dev/null | grep -v NAME | wc -l || echo "0")

if [ "$RLS_PODS" -gt 0 ]; then
    echo -e "${GREEN}✅ Found $RLS_PODS RLS pod(s)${NC}"
    
    # Check pod status
    kubectl get pods -n $EDGE_NAMESPACE -l app.kubernetes.io/name=mimir-rls
    
    # Check RLS logs
    echo -e "${CYAN}Checking recent RLS logs...${NC}"
    RLS_LOGS=$(kubectl logs -n $EDGE_NAMESPACE -l app.kubernetes.io/name=mimir-rls --tail=10 2>/dev/null || echo "")
    
    if [ -n "$RLS_LOGS" ]; then
        echo -e "${CYAN}Recent RLS logs:${NC}"
        echo "$RLS_LOGS" | tail -5
    else
        echo -e "${YELLOW}⚠️  No RLS logs available${NC}"
    fi
    
    # Check RLS metrics
    echo -e "${CYAN}Checking RLS metrics...${NC}"
    RLS_POD=$(kubectl get pods -n $EDGE_NAMESPACE -l app.kubernetes.io/name=mimir-rls -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$RLS_POD" ]; then
        RLS_METRICS=$(kubectl exec -n $EDGE_NAMESPACE $RLS_POD -- curl -s http://localhost:8080/metrics 2>/dev/null || echo "")
        
        if [ -n "$RLS_METRICS" ]; then
            echo -e "${CYAN}RLS metrics summary:${NC}"
            echo "$RLS_METRICS" | grep -E "(rls_|traffic_flow_)" | head -10
        else
            echo -e "${YELLOW}⚠️  Could not fetch RLS metrics${NC}"
        fi
    fi
else
    echo -e "${RED}❌ No RLS pods found${NC}"
fi

echo ""

# =================================================================
# 5. CHECK NETWORK CONNECTIVITY
# =================================================================

echo -e "${BLUE}=== 5. NETWORK CONNECTIVITY CHECK ===${NC}"

# Check if NGINX can reach Envoy
echo -e "${CYAN}Testing NGINX to Envoy connectivity...${NC}"
NGINX_POD=$(kubectl get pods -n $NAMESPACE -l app=nginx -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$NGINX_POD" ]; then
    # Test connectivity to Envoy service
    CONNECTIVITY_TEST=$(kubectl exec -n $NAMESPACE $NGINX_POD -- curl -s -o /dev/null -w "%{http_code}" \
        http://mimir-envoy.mimir-edge-enforcement.svc.cluster.local:8080/ 2>/dev/null || echo "000")
    
    if [ "$CONNECTIVITY_TEST" != "000" ]; then
        echo -e "${GREEN}✅ NGINX can reach Envoy (HTTP $CONNECTIVITY_TEST)${NC}"
    else
        echo -e "${RED}❌ NGINX cannot reach Envoy${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Could not find NGINX pod for connectivity test${NC}"
fi

# Check if Envoy can reach RLS
echo -e "${CYAN}Testing Envoy to RLS connectivity...${NC}"
ENVOY_POD=$(kubectl get pods -n $EDGE_NAMESPACE -l app.kubernetes.io/name=mimir-envoy -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$ENVOY_POD" ]; then
    # Test connectivity to RLS service
    RLS_CONNECTIVITY=$(kubectl exec -n $EDGE_NAMESPACE $ENVOY_POD -- curl -s -o /dev/null -w "%{http_code}" \
        http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8080/health 2>/dev/null || echo "000")
    
    if [ "$RLS_CONNECTIVITY" != "000" ]; then
        echo -e "${GREEN}✅ Envoy can reach RLS (HTTP $RLS_CONNECTIVITY)${NC}"
    else
        echo -e "${RED}❌ Envoy cannot reach RLS${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Could not find Envoy pod for connectivity test${NC}"
fi

echo ""

# =================================================================
# 6. TEST TRAFFIC FLOW
# =================================================================

echo -e "${BLUE}=== 6. TRAFFIC FLOW TEST ===${NC}"

# Get NGINX service
NGINX_SERVICE=$(kubectl get svc -n $NAMESPACE -l app=nginx -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$NGINX_SERVICE" ]; then
    echo -e "${CYAN}Testing traffic flow through edge enforcement...${NC}"
    
    # Make a test request
    TEST_RESPONSE=$(kubectl run test-traffic-flow --rm -i --restart=Never --image=curlimages/curl -- \
        -s -o /dev/null -w "%{http_code}" \
        -H "X-Scope-OrgID: test-tenant" \
        -H "Content-Type: application/x-protobuf" \
        -d "test-data" \
        "http://$NGINX_SERVICE.$NAMESPACE.svc.cluster.local:8080/api/v1/push" 2>/dev/null || echo "000")
    
    if [ "$TEST_RESPONSE" != "000" ]; then
        echo -e "${GREEN}✅ Test request completed (HTTP $TEST_RESPONSE)${NC}"
        
        # Wait a moment for logs to propagate
        sleep 2
        
        # Check if the request appeared in logs
        RECENT_LOGS=$(kubectl logs -n $NAMESPACE -l app=nginx --tail=5 2>/dev/null | grep "test-tenant" || echo "")
        if [ -n "$RECENT_LOGS" ]; then
            echo -e "${GREEN}✅ Test request found in NGINX logs${NC}"
        else
            echo -e "${YELLOW}⚠️  Test request not found in recent NGINX logs${NC}"
        fi
    else
        echo -e "${RED}❌ Test request failed${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Could not find NGINX service for testing${NC}"
fi

echo ""

# =================================================================
# 7. CHECK TRAFFIC FLOW API
# =================================================================

echo -e "${BLUE}=== 7. TRAFFIC FLOW API CHECK ===${NC}"

# Check the traffic flow API
RLS_POD=$(kubectl get pods -n $EDGE_NAMESPACE -l app.kubernetes.io/name=mimir-rls -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$RLS_POD" ]; then
    echo -e "${CYAN}Checking traffic flow API...${NC}"
    
    TRAFFIC_FLOW_RESPONSE=$(kubectl exec -n $EDGE_NAMESPACE $RLS_POD -- curl -s \
        http://localhost:8080/api/traffic/flow 2>/dev/null || echo "{}")
    
    if [ "$TRAFFIC_FLOW_RESPONSE" != "{}" ]; then
        echo -e "${GREEN}✅ Traffic flow API is responding${NC}"
        echo -e "${CYAN}Traffic flow data:${NC}"
        echo "$TRAFFIC_FLOW_RESPONSE" | jq '.flow_metrics' 2>/dev/null || echo "$TRAFFIC_FLOW_RESPONSE"
    else
        echo -e "${RED}❌ Traffic flow API not responding${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Could not find RLS pod for API test${NC}"
fi

echo ""

# =================================================================
# 8. SUMMARY AND RECOMMENDATIONS
# =================================================================

echo -e "${BLUE}=== 8. SUMMARY AND RECOMMENDATIONS ===${NC}"

echo -e "${CYAN}Diagnosis Summary:${NC}"

# Check if all components are running
if [ "$NGINX_PODS" -gt 0 ] && [ "$ENVOY_PODS" -gt 0 ] && [ "$RLS_PODS" -gt 0 ]; then
    echo -e "${GREEN}✅ All components are running${NC}"
else
    echo -e "${RED}❌ Some components are not running${NC}"
fi

# Check if NGINX is configured correctly
if echo "$NGINX_CONFIG" | grep -q "default 1" && echo "$NGINX_CONFIG" | grep -q 'default "edge"'; then
    echo -e "${GREEN}✅ NGINX is configured for 100% edge enforcement${NC}"
else
    echo -e "${RED}❌ NGINX is not configured for 100% edge enforcement${NC}"
    echo -e "${YELLOW}   Run: ./scripts/deploy-100-percent-edge.sh${NC}"
fi

# Check if there's traffic
if [ "$EDGE_TRAFFIC" -gt 0 ]; then
    echo -e "${GREEN}✅ Traffic is flowing through edge enforcement${NC}"
else
    echo -e "${RED}❌ No traffic flowing through edge enforcement${NC}"
    echo -e "${YELLOW}   Possible causes:${NC}"
    echo -e "     • No requests being sent to NGINX"
    echo -e "     • NGINX not configured correctly"
    echo -e "     • Network connectivity issues"
    echo -e "     • Services not ready"
fi

echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo -e "1. If NGINX is not configured correctly, run: ./scripts/deploy-100-percent-edge.sh"
echo -e "2. If no traffic is flowing, check if requests are being sent to NGINX"
echo -e "3. If connectivity issues exist, check network policies and service endpoints"
echo -e "4. Monitor the Admin UI for traffic flow metrics"
echo -e "5. Check NGINX logs for routing decisions"

echo ""
echo -e "${GREEN}=== DIAGNOSIS COMPLETE ===${NC}"
