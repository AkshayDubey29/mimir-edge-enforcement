#!/bin/bash

# 🔍 Diagnose Envoy ext_authz Issue
# This script diagnoses why Envoy only shows /ready logs but NGINX shows route=edge 200

set -e

echo "🔍 Diagnosing Envoy ext_authz Issue"
echo "=================================================="

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
if ! command_exists kubectl; then
    echo "❌ kubectl not found. Please install kubectl."
    exit 1
fi

NAMESPACE="mimir-edge-enforcement"
ENVOY_APP="app.kubernetes.io/name=mimir-envoy"
RLS_APP="app.kubernetes.io/name=mimir-rls"

echo "📋 Step 1: Check Envoy Pod Status"
echo "--------------------------------------------------"
kubectl get pods -l "$ENVOY_APP" -n "$NAMESPACE" -o wide

echo ""
echo "📋 Step 2: Check RLS Pod Status" 
echo "--------------------------------------------------"
kubectl get pods -l "$RLS_APP" -n "$NAMESPACE" -o wide

echo ""
echo "📋 Step 3: Check Envoy ConfigMap Configuration"
echo "--------------------------------------------------"
echo "Checking route configuration..."
kubectl get configmap mimir-envoy-config -n "$NAMESPACE" -o yaml | grep -A 10 -B 5 "prefix.*api/v1/push" || echo "❌ No /api/v1/push route found!"

echo ""
echo "Checking ext_authz configuration..."
kubectl get configmap mimir-envoy-config -n "$NAMESPACE" -o yaml | grep -A 15 "ext_authz"

echo ""
echo "Checking failure_mode_allow setting..."
kubectl get configmap mimir-envoy-config -n "$NAMESPACE" -o yaml | grep -A 3 -B 3 "failure_mode_allow"

echo ""
echo "📋 Step 4: Check Envoy Logs for ext_authz Issues"
echo "--------------------------------------------------"
ENVOY_POD=$(kubectl get pods -l "$ENVOY_APP" -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
echo "Envoy pod: $ENVOY_POD"

echo ""
echo "Last 20 Envoy logs:"
kubectl logs "$ENVOY_POD" -n "$NAMESPACE" --tail=20

echo ""
echo "Checking for ext_authz related logs:"
kubectl logs "$ENVOY_POD" -n "$NAMESPACE" --tail=100 | grep -i "ext_authz\|authz\|authorization" || echo "❌ No ext_authz logs found"

echo ""
echo "Checking for error logs:"
kubectl logs "$ENVOY_POD" -n "$NAMESPACE" --tail=100 | grep -i "error\|fail\|denied\|reject" || echo "✅ No error logs found"

echo ""
echo "📋 Step 5: Check RLS Service Connectivity from Envoy"
echo "--------------------------------------------------"
echo "Testing RLS connectivity from Envoy pod..."
kubectl exec "$ENVOY_POD" -n "$NAMESPACE" -- curl -s -w "HTTP Code: %{http_code}\nResponse Time: %{time_total}s\n" \
  http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8080/health || echo "❌ Cannot reach RLS from Envoy"

echo ""
echo "Testing RLS ext_authz port from Envoy pod..."
kubectl exec "$ENVOY_POD" -n "$NAMESPACE" -- curl -s -w "HTTP Code: %{http_code}\nResponse Time: %{time_total}s\n" \
  http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8080/ready || echo "❌ Cannot reach RLS ext_authz port from Envoy"

echo ""
echo "📋 Step 6: Check RLS Logs for Authorization Requests"
echo "--------------------------------------------------"
RLS_POD=$(kubectl get pods -l "$RLS_APP" -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
echo "RLS pod: $RLS_POD"

echo ""
echo "Last 20 RLS logs:"
kubectl logs "$RLS_POD" -n "$NAMESPACE" --tail=20

echo ""
echo "Checking for authorization requests in RLS logs:"
kubectl logs "$RLS_POD" -n "$NAMESPACE" --tail=100 | grep -i "authz\|authorization\|check\|grpc" || echo "❌ No authorization requests in RLS logs"

echo ""
echo "📋 Step 7: Check Envoy Admin Interface"
echo "--------------------------------------------------"
echo "Starting port-forward to Envoy admin interface..."
kubectl port-forward "$ENVOY_POD" -n "$NAMESPACE" 9901:9901 &
PF_PID=$!
sleep 3

echo ""
echo "Checking Envoy clusters status:"
curl -s http://localhost:9901/clusters | grep -E "(rls_ext_authz|mimir_distributor)" || echo "❌ Clusters not found"

echo ""
echo "Checking ext_authz stats:"
curl -s http://localhost:9901/stats | grep ext_authz || echo "❌ No ext_authz stats found"

echo ""
echo "Checking route configuration:"
curl -s http://localhost:9901/config_dump | jq '.configs[] | select(.["@type"] | contains("RouteConfiguration"))' 2>/dev/null || echo "❌ Cannot parse route config (jq not available)"

echo ""
echo "Checking listener configuration:"
curl -s http://localhost:9901/config_dump | jq '.configs[] | select(.["@type"] | contains("Listener"))' 2>/dev/null || echo "❌ Cannot parse listener config (jq not available)"

# Cleanup
kill $PF_PID 2>/dev/null || true

echo ""
echo "📋 Step 8: Test Direct Request to Envoy"
echo "--------------------------------------------------"
echo "Starting port-forward to Envoy service..."
kubectl port-forward "svc/mimir-envoy" -n "$NAMESPACE" 8080:8080 &
PF_PID=$!
sleep 3

echo ""
echo "Testing /ready endpoint (should work):"
curl -s -w "HTTP Code: %{http_code}\nResponse Time: %{time_total}s\n" http://localhost:8080/ready || echo "❌ /ready endpoint failed"

echo ""
echo "Testing /api/v1/push endpoint with headers:"
curl -s -w "HTTP Code: %{http_code}\nResponse Time: %{time_total}s\n" \
  -H "X-Scope-OrgID: test-tenant" \
  -H "Content-Type: application/x-protobuf" \
  -X POST \
  -d "test-data" \
  http://localhost:8080/api/v1/push || echo "❌ /api/v1/push endpoint failed"

# Cleanup
kill $PF_PID 2>/dev/null || true

echo ""
echo "📋 Step 9: Diagnosis Summary"
echo "--------------------------------------------------"

# Check if ext_authz is the issue
if kubectl logs "$ENVOY_POD" -n "$NAMESPACE" --tail=100 | grep -q "ext_authz.*denied\|ext_authz.*error"; then
    echo "🔥 ISSUE FOUND: ext_authz filter is denying requests"
    echo "   - Check RLS service health"
    echo "   - Check ext_authz configuration"
    echo "   - Consider setting failure_mode_allow: true temporarily"
elif ! kubectl exec "$ENVOY_POD" -n "$NAMESPACE" -- curl -s http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8080/health >/dev/null 2>&1; then
    echo "🔥 ISSUE FOUND: RLS service is not reachable"
    echo "   - Check RLS pod status"
    echo "   - Check service configuration" 
    echo "   - Check network policies"
elif kubectl logs "$RLS_POD" -n "$NAMESPACE" --tail=100 | grep -q "error\|fail"; then
    echo "🔥 ISSUE FOUND: RLS service has errors"
    echo "   - Check RLS logs for detailed errors"
    echo "   - Check RLS configuration"
else
    echo "🤔 POTENTIAL ISSUES:"
    echo "   - ext_authz filter might be silently failing"
    echo "   - Route configuration might not match requests"
    echo "   - gRPC communication issues between Envoy and RLS"
    echo ""
    echo "💡 RECOMMENDED ACTIONS:"
    echo "   1. Temporarily set failure_mode_allow: true in ext_authz"
    echo "   2. Check if requests reach Envoy with verbose logging"
    echo "   3. Verify RLS gRPC service is working correctly"
fi

echo ""
echo "🔍 Diagnosis Complete!"
echo "=================================================="
