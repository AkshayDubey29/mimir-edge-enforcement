#!/bin/bash

# 🔄 Restore ext_authz Configuration
# This script restores failure_mode_allow: false after testing

set -e

NAMESPACE="mimir-edge-enforcement"
CONFIGMAP="mimir-envoy-config"

echo "🔄 Restoring ext_authz Configuration"
echo "=================================================="

echo "📋 Step 1: Restore failure_mode_allow to false"
kubectl patch configmap "$CONFIGMAP" -n "$NAMESPACE" --type='json' -p='[
  {
    "op": "replace",
    "path": "/data/envoy.yaml",
    "value": "'$(kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" -o jsonpath='{.data.envoy\.yaml}' | sed 's/failure_mode_allow: true/failure_mode_allow: false/g' | tr '\n' '\001' | sed 's/\001/\\n/g')'"
  }
]'

echo "✅ Restored failure_mode_allow to false"

echo ""
echo "📋 Step 2: Restart Envoy Deployment"
kubectl rollout restart deployment/mimir-envoy -n "$NAMESPACE"
kubectl rollout status deployment/mimir-envoy -n "$NAMESPACE" --timeout=120s

echo ""
echo "✅ ext_authz Configuration Restored!"
echo "=================================================="
echo ""
echo "📌 NEXT STEPS:"
echo "   - ext_authz is now back in secure mode (failure_mode_allow: false)"
echo "   - Fix the RLS connectivity issue identified during testing"
echo "   - Verify that RLS service is working correctly"
