#!/bin/bash

# Debug Envoy Configuration Issues
# This script helps identify why Envoy might be blocking /api/v1/push requests

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${PURPLE}=== ENVOY CONFIGURATION DEBUG ===${NC}"
echo -e "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo ""

# Configuration
EDGE_NAMESPACE="mimir-edge-enforcement"

# =================================================================
# 1. CHECK ENVOY PODS AND STATUS
# =================================================================

echo -e "${BLUE}=== 1. ENVOY PODS AND STATUS ===${NC}"

# Check Envoy pods
ENVOY_PODS=$(kubectl get pods -n $EDGE_NAMESPACE -l app.kubernetes.io/name=mimir-envoy 2>/dev/null | grep -v NAME | wc -l || echo "0")

if [ "$ENVOY_PODS" -gt 0 ]; then
    echo -e "${GREEN}✅ Found $ENVOY_PODS Envoy pod(s)${NC}"
    
    # Show pod status
    kubectl get pods -n $EDGE_NAMESPACE -l app.kubernetes.io/name=mimir-envoy
    
    # Check if pods are ready
    READY_PODS=$(kubectl get pods -n $EDGE_NAMESPACE -l app.kubernetes.io/name=mimir-envoy --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    if [ "$READY_PODS" -eq "$ENVOY_PODS" ]; then
        echo -e "${GREEN}✅ All Envoy pods are running${NC}"
    else
        echo -e "${RED}❌ Some Envoy pods are not ready${NC}"
    fi
else
    echo -e "${RED}❌ No Envoy pods found${NC}"
    exit 1
fi

echo ""

# =================================================================
# 2. CHECK ENVOY CONFIGURATION
# =================================================================

echo -e "${BLUE}=== 2. ENVOY CONFIGURATION ANALYSIS ===${NC}"

# Get Envoy pod
ENVOY_POD=$(kubectl get pods -n $EDGE_NAMESPACE -l app.kubernetes.io/name=mimir-envoy -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$ENVOY_POD" ]; then
    echo -e "${CYAN}Analyzing Envoy configuration for pod: $ENVOY_POD${NC}"
    
    # Check Envoy config
    echo -e "${CYAN}Checking Envoy configuration...${NC}"
    ENVOY_CONFIG=$(kubectl exec -n $EDGE_NAMESPACE $ENVOY_POD -- curl -s http://localhost:8080/config_dump 2>/dev/null || echo "{}")
    
    if [ "$ENVOY_CONFIG" != "{}" ]; then
        echo -e "${GREEN}✅ Envoy configuration accessible${NC}"
        
        # Check for listeners
        echo -e "${CYAN}Checking Envoy listeners...${NC}"
        LISTENERS=$(echo "$ENVOY_CONFIG" | jq -r '.configs[] | select(.["@type"] == "type.googleapis.com/envoy.admin.v3.ListenersConfigDump") | .dynamic_listeners[].active_state.listener.name' 2>/dev/null || echo "")
        
        if [ -n "$LISTENERS" ]; then
            echo -e "${CYAN}Active listeners:${NC}"
            echo "$LISTENERS"
        else
            echo -e "${YELLOW}⚠️  No active listeners found${NC}"
        fi
        
        # Check for routes
        echo -e "${CYAN}Checking Envoy routes...${NC}"
        ROUTES=$(echo "$ENVOY_CONFIG" | jq -r '.configs[] | select(.["@type"] == "type.googleapis.com/envoy.admin.v3.RoutesConfigDump") | .dynamic_route_configs[].route_config.virtual_hosts[].routes[].match.prefix' 2>/dev/null || echo "")
        
        if [ -n "$ROUTES" ]; then
            echo -e "${CYAN}Configured routes:${NC}"
            echo "$ROUTES"
        else
            echo -e "${YELLOW}⚠️  No routes found${NC}"
        fi
        
    else
        echo -e "${RED}❌ Could not access Envoy configuration${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Could not find Envoy pod for configuration analysis${NC}"
fi

echo ""

# =================================================================
# 3. CHECK ENVOY FILTERS AND POLICIES
# =================================================================

echo -e "${BLUE}=== 3. ENVOY FILTERS AND POLICIES ===${NC}"

if [ -n "$ENVOY_POD" ]; then
    echo -e "${CYAN}Checking Envoy filters...${NC}"
    
    # Check for ext_authz filter
    EXT_AUTHZ_FILTER=$(echo "$ENVOY_CONFIG" | jq -r '.configs[] | select(.["@type"] == "type.googleapis.com/envoy.admin.v3.ListenersConfigDump") | .dynamic_listeners[].active_state.listener.filter_chains[].filters[] | select(.name == "envoy.filters.network.http_connection_manager") | .typed_config.http_filters[] | select(.name == "envoy.filters.http.ext_authz")' 2>/dev/null || echo "")
    
    if [ -n "$EXT_AUTHZ_FILTER" ] && [ "$EXT_AUTHZ_FILTER" != "null" ]; then
        echo -e "${GREEN}✅ ext_authz filter is configured${NC}"
        
        # Check ext_authz configuration
        AUTHZ_CONFIG=$(echo "$EXT_AUTHZ_FILTER" | jq -r '.typed_config.grpc_service.envoy_grpc.cluster_name' 2>/dev/null || echo "")
        if [ -n "$AUTHZ_CONFIG" ] && [ "$AUTHZ_CONFIG" != "null" ]; then
            echo -e "${CYAN}ext_authz cluster: $AUTHZ_CONFIG${NC}"
        fi
    else
        echo -e "${RED}❌ ext_authz filter is NOT configured${NC}"
        echo -e "${YELLOW}   This means Envoy won't call RLS for authorization${NC}"
    fi
    
    # Check for rate limit filter
    RATE_LIMIT_FILTER=$(echo "$ENVOY_CONFIG" | jq -r '.configs[] | select(.["@type"] == "type.googleapis.com/envoy.admin.v3.ListenersConfigDump") | .dynamic_listeners[].active_state.listener.filter_chains[].filters[] | select(.name == "envoy.filters.network.http_connection_manager") | .typed_config.http_filters[] | select(.name == "envoy.filters.http.ratelimit")' 2>/dev/null || echo "")
    
    if [ -n "$RATE_LIMIT_FILTER" ] && [ "$RATE_LIMIT_FILTER" != "null" ]; then
        echo -e "${GREEN}✅ Rate limit filter is configured${NC}"
    else
        echo -e "${YELLOW}⚠️  Rate limit filter is NOT configured${NC}"
    fi
    
    # Check for CORS or other blocking filters
    BLOCKING_FILTERS=$(echo "$ENVOY_CONFIG" | jq -r '.configs[] | select(.["@type"] == "type.googleapis.com/envoy.admin.v3.ListenersConfigDump") | .dynamic_listeners[].active_state.listener.filter_chains[].filters[] | select(.name == "envoy.filters.network.http_connection_manager") | .typed_config.http_filters[].name' 2>/dev/null || echo "")
    
    if [ -n "$BLOCKING_FILTERS" ]; then
        echo -e "${CYAN}Configured HTTP filters:${NC}"
        echo "$BLOCKING_FILTERS"
    fi
fi

echo ""

# =================================================================
# 4. CHECK ENVOY CLUSTERS
# =================================================================

echo -e "${BLUE}=== 4. ENVOY CLUSTERS ===${NC}"

if [ -n "$ENVOY_POD" ]; then
    echo -e "${CYAN}Checking Envoy clusters...${NC}"
    
    # Get clusters
    CLUSTERS=$(kubectl exec -n $EDGE_NAMESPACE $ENVOY_POD -- curl -s http://localhost:8080/clusters 2>/dev/null || echo "")
    
    if [ -n "$CLUSTERS" ]; then
        echo -e "${CYAN}Available clusters:${NC}"
        echo "$CLUSTERS" | grep -E "^[a-zA-Z]" | head -10
        
        # Check for RLS cluster
        RLS_CLUSTER=$(echo "$CLUSTERS" | grep -E "^rls" || echo "")
        if [ -n "$RLS_CLUSTER" ]; then
            echo -e "${GREEN}✅ RLS cluster is available${NC}"
        else
            echo -e "${RED}❌ RLS cluster is NOT available${NC}"
        fi
        
        # Check for Mimir cluster
        MIMIR_CLUSTER=$(echo "$CLUSTERS" | grep -E "^mimir" || echo "")
        if [ -n "$MIMIR_CLUSTER" ]; then
            echo -e "${GREEN}✅ Mimir cluster is available${NC}"
        else
            echo -e "${RED}❌ Mimir cluster is NOT available${NC}"
        fi
    else
        echo -e "${RED}❌ Could not access Envoy clusters${NC}"
    fi
fi

echo ""

# =================================================================
# 5. CHECK ENVOY STATS
# =================================================================

echo -e "${BLUE}=== 5. ENVOY STATS ===${NC}"

if [ -n "$ENVOY_POD" ]; then
    echo -e "${CYAN}Checking Envoy statistics...${NC}"
    
    # Get stats
    STATS=$(kubectl exec -n $EDGE_NAMESPACE $ENVOY_POD -- curl -s http://localhost:8080/stats 2>/dev/null || echo "")
    
    if [ -n "$STATS" ]; then
        echo -e "${CYAN}HTTP request statistics:${NC}"
        echo "$STATS" | grep -E "(http|ext_authz)" | head -10
        
        # Check for specific metrics
        TOTAL_REQUESTS=$(echo "$STATS" | grep "http.requests_total" || echo "0")
        AUTHZ_REQUESTS=$(echo "$STATS" | grep "ext_authz.requests" || echo "0")
        RATE_LIMIT_REQUESTS=$(echo "$STATS" | grep "ratelimit.requests" || echo "0")
        
        echo -e "${CYAN}Key metrics:${NC}"
        echo -e "  • Total HTTP requests: $TOTAL_REQUESTS"
        echo -e "  • Authorization requests: $AUTHZ_REQUESTS"
        echo -e "  • Rate limit requests: $RATE_LIMIT_REQUESTS"
    else
        echo -e "${RED}❌ Could not access Envoy stats${NC}"
    fi
fi

echo ""

# =================================================================
# 6. TEST ENVOY ENDPOINTS DIRECTLY
# =================================================================

echo -e "${BLUE}=== 6. TEST ENVOY ENDPOINTS ===${NC}"

if [ -n "$ENVOY_POD" ]; then
    echo -e "${CYAN}Testing Envoy endpoints directly...${NC}"
    
    # Test /ready endpoint
    READY_TEST=$(kubectl exec -n $EDGE_NAMESPACE $ENVOY_POD -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ready 2>/dev/null || echo "000")
    echo -e "  • /ready endpoint: HTTP $READY_TEST"
    
    # Test /api/v1/push endpoint directly
    PUSH_TEST=$(kubectl exec -n $EDGE_NAMESPACE $ENVOY_POD -- curl -s -o /dev/null -w "%{http_code}" \
        -H "X-Scope-OrgID: test-tenant" \
        -H "Content-Type: application/x-protobuf" \
        -d "test-data" \
        http://localhost:8080/api/v1/push 2>/dev/null || echo "000")
    echo -e "  • /api/v1/push endpoint: HTTP $PUSH_TEST"
    
    if [ "$PUSH_TEST" = "000" ]; then
        echo -e "${RED}❌ Envoy is not accepting /api/v1/push requests directly${NC}"
    elif [ "$PUSH_TEST" = "403" ] || [ "$PUSH_TEST" = "401" ]; then
        echo -e "${YELLOW}⚠️  Envoy is rejecting /api/v1/push requests (auth/authorization issue)${NC}"
    else
        echo -e "${GREEN}✅ Envoy is accepting /api/v1/push requests (HTTP $PUSH_TEST)${NC}"
    fi
fi

echo ""

# =================================================================
# 7. CHECK ENVOY LOGS FOR ERRORS
# =================================================================

echo -e "${BLUE}=== 7. ENVOY LOGS ANALYSIS ===${NC}"

echo -e "${CYAN}Checking recent Envoy logs for errors...${NC}"
ENVOY_LOGS=$(kubectl logs -n $EDGE_NAMESPACE -l app.kubernetes.io/name=mimir-envoy --tail=20 2>/dev/null || echo "")

if [ -n "$ENVOY_LOGS" ]; then
    echo -e "${CYAN}Recent Envoy logs:${NC}"
    echo "$ENVOY_LOGS"
    
    # Check for errors
    ERRORS=$(echo "$ENVOY_LOGS" | grep -i "error\|failed\|denied\|blocked" || echo "")
    if [ -n "$ERRORS" ]; then
        echo -e "${RED}❌ Errors found in Envoy logs:${NC}"
        echo "$ERRORS"
    else
        echo -e "${GREEN}✅ No errors found in recent Envoy logs${NC}"
    fi
    
    # Check for authorization issues
    AUTH_ISSUES=$(echo "$ENVOY_LOGS" | grep -i "auth\|unauthorized\|forbidden" || echo "")
    if [ -n "$AUTH_ISSUES" ]; then
        echo -e "${YELLOW}⚠️  Authorization issues found:${NC}"
        echo "$AUTH_ISSUES"
    fi
else
    echo -e "${YELLOW}⚠️  No Envoy logs available${NC}"
fi

echo ""

# =================================================================
# 8. SUMMARY AND RECOMMENDATIONS
# =================================================================

echo -e "${BLUE}=== 8. SUMMARY AND RECOMMENDATIONS ===${NC}"

echo -e "${CYAN}Envoy Configuration Analysis Summary:${NC}"

# Check key components
if [ -n "$EXT_AUTHZ_FILTER" ] && [ "$EXT_AUTHZ_FILTER" != "null" ]; then
    echo -e "${GREEN}✅ ext_authz filter: CONFIGURED${NC}"
else
    echo -e "${RED}❌ ext_authz filter: MISSING${NC}"
fi

if [ -n "$RLS_CLUSTER" ]; then
    echo -e "${GREEN}✅ RLS cluster: AVAILABLE${NC}"
else
    echo -e "${RED}❌ RLS cluster: MISSING${NC}"
fi

if [ "$PUSH_TEST" != "000" ]; then
    echo -e "${GREEN}✅ /api/v1/push endpoint: ACCEPTING${NC}"
else
    echo -e "${RED}❌ /api/v1/push endpoint: BLOCKED${NC}"
fi

echo ""
echo -e "${CYAN}Common Envoy Issues That Block /api/v1/push:${NC}"

echo -e "1. ${RED}Missing ext_authz filter${NC}"
echo -e "   • Envoy won't call RLS for authorization"
echo -e "   • Solution: Check Envoy configuration for ext_authz setup"

echo -e "2. ${RED}RLS cluster not configured${NC}"
echo -e "   • ext_authz can't reach RLS service"
echo -e "   • Solution: Verify RLS service and cluster configuration"

echo -e "3. ${RED}Route configuration issues${NC}"
echo -e "   • /api/v1/push route not properly configured"
echo -e "   • Solution: Check Envoy route configuration"

echo -e "4. ${RED}Filter chain problems${NC}"
echo -e "   • HTTP filters blocking requests"
echo -e "   • Solution: Review filter chain configuration"

echo -e "5. ${RED}Authentication/Authorization failures${NC}"
echo -e "   • ext_authz returning 403/401"
echo -e "   • Solution: Check RLS logs and configuration"

echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo -e "1. If ext_authz is missing, check Envoy Helm chart configuration"
echo -e "2. If RLS cluster is missing, verify RLS service deployment"
echo -e "3. If /api/v1/push is blocked, check route and filter configuration"
echo -e "4. Check RLS logs for authorization failures"
echo -e "5. Verify Envoy configuration matches the expected setup"

echo ""
echo -e "${GREEN}=== ENVOY CONFIGURATION DEBUG COMPLETE ===${NC}"
