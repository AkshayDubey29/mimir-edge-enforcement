#!/bin/bash

# 🔧 Temporarily Bypass ext_authz for Testing
# This script temporarily sets failure_mode_allow: true to test if ext_authz is blocking requests

set -e

NAMESPACE="mimir-edge-enforcement"
CONFIGMAP="mimir-envoy-config"

echo "🔧 Temporarily Bypassing ext_authz Filter"
echo "=================================================="

echo "📋 Step 1: Backup Current Configuration"
kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" -o yaml > "backup-envoy-config-$(date +%Y%m%d-%H%M%S).yaml"
echo "✅ Configuration backed up"

echo ""
echo "📋 Step 2: Update failure_mode_allow to true"
kubectl patch configmap "$CONFIGMAP" -n "$NAMESPACE" --type='json' -p='[
  {
    "op": "replace",
    "path": "/data/envoy.yaml",
    "value": "'$(kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" -o jsonpath='{.data.envoy\.yaml}' | sed 's/failure_mode_allow: false/failure_mode_allow: true/g' | tr '\n' '\001' | sed 's/\001/\\n/g')'"
  }
]'

echo "✅ Updated failure_mode_allow to true"

echo ""
echo "📋 Step 3: Restart Envoy Deployment"
kubectl rollout restart deployment/mimir-envoy -n "$NAMESPACE"
kubectl rollout status deployment/mimir-envoy -n "$NAMESPACE" --timeout=120s

echo ""
echo "📋 Step 4: Test Request Processing"
echo "Waiting for deployment to be ready..."
sleep 10

ENVOY_POD=$(kubectl get pods -l "app.kubernetes.io/name=mimir-envoy" -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
echo "Testing with Envoy pod: $ENVOY_POD"

echo ""
echo "Starting port-forward..."
kubectl port-forward "$ENVOY_POD" -n "$NAMESPACE" 8080:8080 &
PF_PID=$!
sleep 5

echo ""
echo "Testing /api/v1/push endpoint (should now work):"
curl -s -w "HTTP Code: %{http_code}\nResponse Time: %{time_total}s\n" \
  -H "X-Scope-OrgID: test-tenant" \
  -H "Content-Type: application/x-protobuf" \
  -X POST \
  -d "test-payload" \
  http://localhost:8080/api/v1/push

kill $PF_PID 2>/dev/null || true

echo ""
echo "📋 Step 5: Check Envoy Logs After Test"
kubectl logs "$ENVOY_POD" -n "$NAMESPACE" --tail=10

echo ""
echo "🔧 Bypass Applied Successfully!"
echo "=================================================="
echo ""
echo "📌 IMPORTANT NOTES:"
echo "   - ext_authz is now in ALLOW mode (bypassed)"
echo "   - If requests now work, the issue is with RLS connectivity"
echo "   - Remember to restore the original configuration after testing"
echo ""
echo "📌 TO RESTORE ORIGINAL CONFIGURATION:"
echo "   kubectl apply -f backup-envoy-config-*.yaml"
echo "   kubectl rollout restart deployment/mimir-envoy -n $NAMESPACE"
echo ""
echo "📌 IF REQUESTS STILL DON'T WORK:"
echo "   - The issue is not with ext_authz"
echo "   - Check route configuration"
echo "   - Check Mimir distributor connectivity"
