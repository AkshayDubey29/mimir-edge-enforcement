#!/bin/bash

# 🔍 Check ext_authz RLS Connectivity Issue
# This script specifically checks why ext_authz is failing

set -e

echo "🔍 Checking ext_authz RLS Connectivity"
echo "=================================================="

NAMESPACE="mimir-edge-enforcement"
ENVOY_APP="app.kubernetes.io/name=mimir-envoy"
RLS_APP="app.kubernetes.io/name=mimir-rls"

# Get pod names
ENVOY_POD=$(kubectl get pods -l "$ENVOY_APP" -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
RLS_POD=$(kubectl get pods -l "$RLS_APP" -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$ENVOY_POD" ]; then
    echo "❌ No Envoy pod found!"
    exit 1
fi

if [ -z "$RLS_POD" ]; then
    echo "❌ No RLS pod found!"
    exit 1
fi

echo "📋 Pods Found:"
echo "   Envoy: $ENVOY_POD"
echo "   RLS: $RLS_POD"

echo ""
echo "📋 Step 1: Check RLS Service Endpoints"
echo "--------------------------------------------------"
kubectl get endpoints mimir-rls -n "$NAMESPACE" || echo "❌ RLS service endpoints not found"

echo ""
echo "📋 Step 2: Check RLS Pod Health"
echo "--------------------------------------------------"
echo "RLS Pod Status:"
kubectl get pod "$RLS_POD" -n "$NAMESPACE" -o wide

echo ""
echo "RLS Pod Events:"
kubectl describe pod "$RLS_POD" -n "$NAMESPACE" | tail -10

echo ""
echo "📋 Step 3: Test RLS HTTP Health Endpoint"
echo "--------------------------------------------------"
echo "Testing RLS /health endpoint from Envoy pod..."
if kubectl exec "$ENVOY_POD" -n "$NAMESPACE" -- curl -s -m 5 http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8082/health; then
    echo ""
    echo "✅ RLS HTTP health endpoint is reachable"
else
    echo ""
    echo "❌ RLS HTTP health endpoint is NOT reachable"
fi

echo ""
echo "📋 Step 4: Test RLS gRPC Port (ext_authz)"
echo "--------------------------------------------------"
echo "Testing RLS gRPC port 8080 from Envoy pod..."
if kubectl exec "$ENVOY_POD" -n "$NAMESPACE" -- nc -z mimir-rls.mimir-edge-enforcement.svc.cluster.local 8080; then
    echo "✅ RLS gRPC port 8080 is reachable"
else
    echo "❌ RLS gRPC port 8080 is NOT reachable"
fi

echo ""
echo "📋 Step 5: Check RLS Logs for gRPC Issues"
echo "--------------------------------------------------"
echo "Recent RLS logs:"
kubectl logs "$RLS_POD" -n "$NAMESPACE" --tail=20

echo ""
echo "Checking for gRPC/authorization logs in RLS:"
if kubectl logs "$RLS_POD" -n "$NAMESPACE" --tail=100 | grep -i "grpc\|authz\|authorization\|check"; then
    echo "✅ Found gRPC/authorization activity in RLS"
else
    echo "❌ No gRPC/authorization activity in RLS logs"
fi

echo ""
echo "📋 Step 6: Check Envoy ext_authz Cluster Status"
echo "--------------------------------------------------"
echo "Starting port-forward to Envoy admin..."
kubectl port-forward "$ENVOY_POD" -n "$NAMESPACE" 9901:9901 &
PF_PID=$!
sleep 3

echo ""
echo "Envoy rls_ext_authz cluster status:"
if curl -s http://localhost:9901/clusters | grep rls_ext_authz; then
    echo "✅ Found rls_ext_authz cluster"
else
    echo "❌ rls_ext_authz cluster not found or unhealthy"
fi

echo ""
echo "Envoy ext_authz filter stats:"
if curl -s http://localhost:9901/stats | grep ext_authz; then
    echo "✅ Found ext_authz stats"
else
    echo "❌ No ext_authz stats found"
fi

kill $PF_PID 2>/dev/null || true

echo ""
echo "📋 Step 7: Check Current Configuration"
echo "--------------------------------------------------"
echo "Current failure_mode_allow setting:"
kubectl get configmap mimir-envoy-config -n "$NAMESPACE" -o yaml | grep -A 2 -B 2 "failure_mode_allow"

echo ""
echo "Current ext_authz cluster configuration:"
kubectl get configmap mimir-envoy-config -n "$NAMESPACE" -o yaml | grep -A 10 -B 5 "rls_ext_authz"

echo ""
echo "📋 DIAGNOSIS SUMMARY"
echo "=================================================="

# Check if RLS is reachable
if ! kubectl exec "$ENVOY_POD" -n "$NAMESPACE" -- nc -z mimir-rls.mimir-edge-enforcement.svc.cluster.local 8080 2>/dev/null; then
    echo "🔥 ROOT CAUSE: RLS gRPC service (port 8080) is not reachable from Envoy"
    echo ""
    echo "💡 POSSIBLE FIXES:"
    echo "   1. Check if RLS pod is running: kubectl get pods -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE"
    echo "   2. Check RLS service: kubectl get svc mimir-rls -n $NAMESPACE"
    echo "   3. Check RLS pod logs: kubectl logs $RLS_POD -n $NAMESPACE"
    echo "   4. Verify RLS is listening on port 8080"
    
elif ! kubectl logs "$RLS_POD" -n "$NAMESPACE" --tail=100 | grep -q "started\|listening\|ready"; then
    echo "🔥 ROOT CAUSE: RLS service is not properly started"
    echo ""
    echo "💡 POSSIBLE FIXES:"
    echo "   1. Check RLS startup logs: kubectl logs $RLS_POD -n $NAMESPACE"
    echo "   2. Check RLS configuration"
    echo "   3. Restart RLS: kubectl rollout restart deployment/mimir-rls -n $NAMESPACE"
    
else
    echo "🤔 RLS appears to be running and reachable"
    echo ""
    echo "💡 RECOMMENDED ACTIONS:"
    echo "   1. Temporarily set failure_mode_allow: true to test"
    echo "   2. Run: ./scripts/temporarily-bypass-ext-authz.sh"
    echo "   3. If that works, debug RLS gRPC communication"
    echo "   4. Check RLS ext_authz endpoint implementation"
fi

echo ""
echo "🔍 Connectivity Check Complete!"
