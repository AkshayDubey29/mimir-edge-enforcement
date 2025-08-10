#!/bin/bash

# 🔧 Fix RLS gRPC Service Issue
# The RLS HTTP admin (8082) works but gRPC (8080) doesn't

echo "🔧 Fixing RLS gRPC Service Issue"
echo "================================="

NAMESPACE="mimir-edge-enforcement"

echo "📋 STEP 1: Diagnose RLS Service"
echo "-------------------------------"

echo "Check RLS pods:"
kubectl get pods -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE -o wide

echo ""
echo "Check RLS service configuration:"
kubectl get svc mimir-rls -n $NAMESPACE -o yaml

echo ""
echo "Check RLS service endpoints:"
kubectl get endpoints mimir-rls -n $NAMESPACE

echo ""
echo "📋 STEP 2: Check RLS Pod Logs"
echo "-----------------------------"
RLS_POD=$(kubectl get pods -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}')
echo "RLS Pod: $RLS_POD"

echo ""
echo "Recent RLS logs:"
kubectl logs $RLS_POD -n $NAMESPACE --tail=20

echo ""
echo "Check for gRPC server startup:"
kubectl logs $RLS_POD -n $NAMESPACE | grep -i "grpc\|8080\|listening\|started"

echo ""
echo "📋 STEP 3: Test RLS Ports Directly"
echo "----------------------------------"
echo "Port-forward RLS gRPC port for testing:"
kubectl port-forward $RLS_POD -n $NAMESPACE 8080:8080 &
PF_PID=$!
sleep 3

echo ""
echo "Test gRPC port locally:"
curl -v http://localhost:8080 2>&1 | head -10

# Cleanup
kill $PF_PID 2>/dev/null || true

echo ""
echo "📋 STEP 4: Check RLS Configuration"
echo "----------------------------------"
echo "RLS ConfigMap:"
kubectl get configmap -n $NAMESPACE | grep rls

echo ""
echo "Check RLS environment variables:"
kubectl describe pod $RLS_POD -n $NAMESPACE | grep -A 10 "Environment:"

echo ""
echo "📋 STEP 5: Immediate Fixes to Try"
echo "==================================="

echo "FIX 1: Restart RLS service"
echo "kubectl rollout restart deployment/mimir-rls -n $NAMESPACE"

echo ""
echo "FIX 2: Check if RLS is binding to correct port"
echo "kubectl exec $RLS_POD -n $NAMESPACE -- netstat -ln | grep 8080"

echo ""
echo "FIX 3: Temporarily bypass ext_authz (immediate workaround)"
echo "kubectl patch configmap mimir-envoy-config -n $NAMESPACE --type='json' -p='[{\"op\": \"replace\", \"path\": \"/data/envoy.yaml\", \"value\": \"'$(kubectl get configmap mimir-envoy-config -n $NAMESPACE -o jsonpath='{.data.envoy\.yaml}' | sed 's/failure_mode_allow: false/failure_mode_allow: true/g')'"}]'"
echo "kubectl rollout restart deployment/mimir-envoy -n $NAMESPACE"

echo ""
echo "FIX 4: Check RLS service definition ports"
echo "kubectl get svc mimir-rls -n $NAMESPACE -o jsonpath='{.spec.ports}' | jq ."

echo ""
echo "📋 VERIFICATION COMMANDS"
echo "========================"
echo "After applying fixes, verify from Admin UI:"
echo ""
echo "# Test RLS gRPC connectivity"
echo "curl -s -m 5 --connect-timeout 2 http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8080"
echo ""
echo "# Test Envoy request processing"
echo "curl -s -w 'Status: %{http_code}' -H 'X-Scope-OrgID: test' -X POST -d 'test' http://mimir-envoy.mimir-edge-enforcement.svc.cluster.local:8080/api/v1/push"
echo ""
echo "🔧 Fix script complete!"
