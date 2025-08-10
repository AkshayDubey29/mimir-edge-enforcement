#!/bin/bash

# 🔍 Debug Envoy from Admin UI Container
# Use Admin UI container (which has curl) to diagnose Envoy issues

echo "🔍 Debugging Envoy from Admin UI Container"
echo "=========================================="

echo "📋 STEP 1: Test Network Connectivity"
echo "------------------------------------"

# Test RLS service connectivity (most critical)
echo "Testing RLS gRPC service (port 8080):"
if curl -s -m 5 --connect-timeout 2 http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8080 >/dev/null 2>&1; then
    echo "✅ RLS gRPC port 8080 is reachable"
else
    echo "❌ RLS gRPC port 8080 is NOT reachable - THIS IS THE PROBLEM!"
fi

echo ""
echo "Testing RLS admin/health endpoint (port 8082):"
curl -s -m 5 http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8082/health
echo ""

echo "Testing Mimir distributor (port 8080):"
if curl -s -m 5 --connect-timeout 2 http://mimir-distributor.mimir.svc.cluster.local:8080 >/dev/null 2>&1; then
    echo "✅ Mimir distributor is reachable"
else
    echo "❌ Mimir distributor is NOT reachable"
fi

echo ""
echo "📋 STEP 2: Test Envoy Admin Interface"
echo "-------------------------------------"

# Test Envoy admin interface
echo "Testing Envoy admin interface:"
if curl -s -m 5 http://mimir-envoy.mimir-edge-enforcement.svc.cluster.local:9901/ready; then
    echo ""
    echo "✅ Envoy admin interface is accessible"
else
    echo "❌ Envoy admin interface is NOT accessible"
fi

echo ""
echo "📋 STEP 3: Check Envoy Statistics"
echo "---------------------------------"

echo "Envoy ext_authz statistics:"
curl -s -m 10 http://mimir-envoy.mimir-edge-enforcement.svc.cluster.local:9901/stats | grep ext_authz

echo ""
echo "Envoy cluster health:"
curl -s -m 10 http://mimir-envoy.mimir-edge-enforcement.svc.cluster.local:9901/clusters | grep -E "(rls_ext_authz|mimir_distributor)"

echo ""
echo "📋 STEP 4: Test Envoy Request Processing"
echo "----------------------------------------"

echo "Testing Envoy /ready endpoint:"
curl -s -w "HTTP Status: %{http_code}, Response Time: %{time_total}s\n" \
  http://mimir-envoy.mimir-edge-enforcement.svc.cluster.local:8080/ready

echo ""
echo "Testing Envoy /api/v1/push endpoint:"
curl -s -w "HTTP Status: %{http_code}, Response Time: %{time_total}s\n" \
  -H "X-Scope-OrgID: test-tenant" \
  -H "Content-Type: application/x-protobuf" \
  -X POST \
  -d "test-minimal-payload" \
  http://mimir-envoy.mimir-edge-enforcement.svc.cluster.local:8080/api/v1/push

echo ""
echo "📋 STEP 5: Check RLS Service Status"
echo "-----------------------------------"

echo "RLS tenants endpoint:"
curl -s -m 10 http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8082/api/tenants | head -200

echo ""
echo "RLS health endpoint:"
curl -s -m 10 http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8082/health

echo ""
echo "📋 STEP 6: Detailed Envoy Configuration Check"
echo "---------------------------------------------"

echo "Envoy route configuration (looking for /api/v1/push):"
curl -s -m 10 http://mimir-envoy.mimir-edge-enforcement.svc.cluster.local:9901/config_dump | grep -A 5 -B 5 "api/v1/push"

echo ""
echo "Envoy listeners:"
curl -s -m 10 http://mimir-envoy.mimir-edge-enforcement.svc.cluster.local:9901/listeners

echo ""
echo "📋 DIAGNOSIS SUMMARY"
echo "===================="

# Test RLS connectivity and provide diagnosis
RLS_GRPC_TEST=$(curl -s -m 5 --connect-timeout 2 http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8080 >/dev/null 2>&1 && echo "REACHABLE" || echo "NOT_REACHABLE")
RLS_HTTP_TEST=$(curl -s -m 5 http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8082/health >/dev/null 2>&1 && echo "REACHABLE" || echo "NOT_REACHABLE")

echo "RLS gRPC (port 8080): $RLS_GRPC_TEST"
echo "RLS HTTP (port 8082): $RLS_HTTP_TEST"

if [ "$RLS_GRPC_TEST" = "NOT_REACHABLE" ]; then
    echo ""
    echo "🔥 PROBLEM FOUND: RLS gRPC Service Not Reachable"
    echo "==============================================="
    echo "The RLS service on port 8080 (gRPC) is not reachable from Admin UI."
    echo "This explains the symptoms:"
    echo ""
    echo "1. NGINX routes traffic to Envoy (route=edge 200) ✅"
    echo "2. Envoy receives the requests ✅"
    echo "3. ext_authz filter tries to contact RLS gRPC ❌"
    echo "4. ext_authz fails, denies request (failure_mode_allow: false) ❌"
    echo "5. Request never reaches Mimir ❌"
    echo "6. Only /ready health checks work (bypass ext_authz) ✅"
    echo ""
    echo "IMMEDIATE FIXES TO TRY:"
    echo "1. Check RLS pod status:"
    echo "   kubectl get pods -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement"
    echo ""
    echo "2. Check RLS service and endpoints:"
    echo "   kubectl get svc mimir-rls -n mimir-edge-enforcement"
    echo "   kubectl get endpoints mimir-rls -n mimir-edge-enforcement"
    echo ""
    echo "3. Temporarily bypass ext_authz to confirm:"
    echo "   kubectl patch configmap mimir-envoy-config -n mimir-edge-enforcement --type='json'"
    echo "   # Set failure_mode_allow: true to bypass ext_authz temporarily"
    echo "   kubectl rollout restart deployment/mimir-envoy -n mimir-edge-enforcement"

elif [ "$RLS_HTTP_TEST" = "NOT_REACHABLE" ]; then
    echo ""
    echo "⚠️  RLS gRPC reachable but HTTP admin not working"
    echo "This suggests RLS is partially working but may have issues"
    echo "Check RLS logs for errors"

else
    echo ""
    echo "✅ RLS appears reachable - issue may be elsewhere"
    echo "Check ext_authz statistics above for denied/error counts"
    echo "Check Envoy route configuration for /api/v1/push matching"
fi

echo ""
echo "🔍 Debug complete from Admin UI!"
