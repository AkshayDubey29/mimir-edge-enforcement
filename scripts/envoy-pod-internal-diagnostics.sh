#!/bin/bash

# 🔍 Envoy Pod Internal Diagnostics
# Run these commands inside the Envoy pod to validate configuration

echo "🔍 Envoy Internal Configuration Diagnostics"
echo "=============================================="

echo "📋 Step 1: Check Envoy Admin Interface Status"
echo "----------------------------------------------"
echo "Checking if admin interface is accessible..."
curl -s http://localhost:9901/ready && echo " ✅ Admin interface ready" || echo " ❌ Admin interface not ready"

echo ""
echo "📋 Step 2: Validate Listeners Configuration"
echo "--------------------------------------------"
echo "Active listeners:"
curl -s http://localhost:9901/listeners | jq '.' 2>/dev/null || curl -s http://localhost:9901/listeners

echo ""
echo "Listener summary:"
curl -s http://localhost:9901/listeners?format=json | jq '.listener_statuses[] | {name: .name, local_address: .local_address}' 2>/dev/null || curl -s http://localhost:9901/listeners

echo ""
echo "📋 Step 3: Validate Route Configuration"
echo "----------------------------------------"
echo "Route configuration:"
curl -s http://localhost:9901/config_dump | jq '.configs[] | select(."@type" | contains("RouteConfiguration")) | .route_config' 2>/dev/null || {
    echo "Route config (raw):"
    curl -s http://localhost:9901/config_dump | grep -A 50 "RouteConfiguration"
}

echo ""
echo "📋 Step 4: Check Cluster Status"
echo "--------------------------------"
echo "All clusters status:"
curl -s http://localhost:9901/clusters

echo ""
echo "RLS ext_authz cluster specific:"
curl -s http://localhost:9901/clusters | grep -A 5 -B 5 "rls_ext_authz"

echo ""
echo "Mimir distributor cluster specific:"
curl -s http://localhost:9901/clusters | grep -A 5 -B 5 "mimir_distributor"

echo ""
echo "📋 Step 5: Check Filter Configuration"
echo "-------------------------------------"
echo "HTTP filters configuration:"
curl -s http://localhost:9901/config_dump | jq '.configs[] | select(."@type" | contains("Listener")) | .active_state.listener.filter_chains[0].filters[0].typed_config.http_filters' 2>/dev/null || {
    echo "HTTP filters (raw):"
    curl -s http://localhost:9901/config_dump | grep -A 20 "http_filters"
}

echo ""
echo "📋 Step 6: Check ext_authz Statistics"
echo "--------------------------------------"
echo "ext_authz stats:"
curl -s http://localhost:9901/stats | grep ext_authz

echo ""
echo "📋 Step 7: Test Upstream Connectivity"
echo "--------------------------------------"
echo "Testing RLS gRPC port (8080):"
nc -z mimir-rls.mimir-edge-enforcement.svc.cluster.local 8080 && echo "✅ RLS gRPC reachable" || echo "❌ RLS gRPC not reachable"

echo ""
echo "Testing RLS HTTP admin port (8082):"
curl -s -m 5 http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8082/health && echo " ✅ RLS HTTP reachable" || echo " ❌ RLS HTTP not reachable"

echo ""
echo "Testing Mimir distributor:"
nc -z mimir-distributor.mimir.svc.cluster.local 8080 && echo "✅ Mimir distributor reachable" || echo "❌ Mimir distributor not reachable"

echo ""
echo "📋 Step 8: Check Internal Request Processing"
echo "--------------------------------------------"
echo "Testing internal /ready endpoint:"
curl -s -w "Status: %{http_code}, Time: %{time_total}s\n" http://localhost:8080/ready

echo ""
echo "Testing internal /api/v1/push endpoint with minimal payload:"
curl -s -w "Status: %{http_code}, Time: %{time_total}s\n" \
  -H "X-Scope-OrgID: test-tenant" \
  -H "Content-Type: application/x-protobuf" \
  -X POST \
  -d "test-data" \
  http://localhost:8080/api/v1/push

echo ""
echo "📋 Step 9: Check Recent Envoy Logs"
echo "-----------------------------------"
echo "Recent access logs (if enabled):"
tail -20 /dev/stdout 2>/dev/null || echo "Access logs not available in stdout"

echo ""
echo "📋 Step 10: Check Memory and Resource Usage"
echo "--------------------------------------------"
echo "Memory statistics:"
curl -s http://localhost:9901/stats | grep -E "(memory|heap)" | head -10

echo ""
echo "Request/Response statistics:"
curl -s http://localhost:9901/stats | grep -E "(request|response)" | head -10

echo ""
echo "📋 Step 11: Validate gRPC Communication"
echo "----------------------------------------"
echo "Testing gRPC connectivity to RLS using grpcurl (if available):"
which grpcurl >/dev/null 2>&1 && {
    echo "Testing gRPC health check:"
    grpcurl -plaintext mimir-rls.mimir-edge-enforcement.svc.cluster.local:8080 grpc.health.v1.Health/Check 2>/dev/null || echo "gRPC health check failed"
} || echo "grpcurl not available"

echo ""
echo "📋 Step 12: Check DNS Resolution"
echo "--------------------------------"
echo "DNS resolution for RLS:"
nslookup mimir-rls.mimir-edge-enforcement.svc.cluster.local || echo "DNS resolution failed for RLS"

echo ""
echo "DNS resolution for Mimir:"
nslookup mimir-distributor.mimir.svc.cluster.local || echo "DNS resolution failed for Mimir"

echo ""
echo "📋 SUMMARY AND DIAGNOSIS"
echo "========================="

# Check if ext_authz stats show any activity
EXT_AUTHZ_TOTAL=$(curl -s http://localhost:9901/stats | grep "ext_authz.*total" | head -1 | awk '{print $2}' || echo "0")
if [ "$EXT_AUTHZ_TOTAL" = "0" ]; then
    echo "🔥 ISSUE: ext_authz filter shows zero requests"
    echo "   This means requests are not reaching the ext_authz filter"
    echo "   Possible causes:"
    echo "   1. Route configuration is not matching /api/v1/push"
    echo "   2. Requests are being handled by a different route"
    echo "   3. HTTP filters are not being applied"
else
    echo "✅ ext_authz filter is receiving requests"
fi

# Check if RLS is reachable
if nc -z mimir-rls.mimir-edge-enforcement.svc.cluster.local 8080; then
    echo "✅ RLS is reachable via gRPC"
else
    echo "🔥 ISSUE: RLS gRPC service is not reachable"
    echo "   This will cause ext_authz to deny all requests"
    echo "   Check RLS pod status and service configuration"
fi

# Check route configuration
ROUTE_COUNT=$(curl -s http://localhost:9901/config_dump | grep -c "/api/v1/push" || echo "0")
if [ "$ROUTE_COUNT" = "0" ]; then
    echo "🔥 ISSUE: No route found for /api/v1/push"
    echo "   Check route configuration in ConfigMap"
else
    echo "✅ Route for /api/v1/push is configured"
fi

echo ""
echo "🔍 Diagnostics Complete!"
echo "Run these commands one by one inside the Envoy pod for detailed analysis."
