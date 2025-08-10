#!/bin/bash

# 🔍 Diagnose 4e+06 Scientific Notation Error
# This script helps identify where the problematic value is coming from

set -e

NAMESPACE="mimir-edge-enforcement"
RELEASE_NAME="mimir-rls"

echo "🔍 Diagnosing 4e+06 scientific notation error..."

echo ""
echo "📋 1. Checking current Helm release values:"
helm get values $RELEASE_NAME -n $NAMESPACE | grep -A 5 -B 5 "maxRequestBytes" || echo "No maxRequestBytes found in Helm values"

echo ""
echo "📋 2. Checking current deployment arguments:"
kubectl get deployment $RELEASE_NAME -n $NAMESPACE -o yaml | grep -A 20 "args:" | grep -E "(max-request-bytes|4194304|4e\+06)" || echo "No problematic values found in deployment"

echo ""
echo "📋 3. Checking current pod arguments:"
POD_NAME=$(kubectl get pods -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "No pod found")
if [ "$POD_NAME" != "No pod found" ]; then
    echo "Pod: $POD_NAME"
    kubectl get pod $POD_NAME -n $NAMESPACE -o yaml | grep -A 20 "args:" | grep -E "(max-request-bytes|4194304|4e\+06)" || echo "No problematic values found in pod"
else
    echo "No RLS pod found"
fi

echo ""
echo "📋 4. Checking Helm release history:"
helm history $RELEASE_NAME -n $NAMESPACE --max=3

echo ""
echo "📋 5. Checking if any ConfigMaps contain the old value:"
kubectl get configmaps -n $NAMESPACE -o yaml | grep -E "(4194304|4e\+06)" || echo "No problematic values found in ConfigMaps"

echo ""
echo "📋 6. Checking current pod logs for the error:"
if [ "$POD_NAME" != "No pod found" ]; then
    kubectl logs $POD_NAME -n $NAMESPACE 2>&1 | grep -E "(4e\+06|invalid value|parse error)" || echo "No 4e+06 errors found in logs"
else
    echo "No pod to check logs"
fi

echo ""
echo "📋 7. Checking Helm chart values:"
echo "Chart values.yaml maxRequestBytes:"
grep "maxRequestBytes:" charts/mimir-rls/values.yaml || echo "Not found in chart values"

echo ""
echo "📋 8. Checking deployment template:"
echo "Deployment template max-request-bytes:"
grep "max-request-bytes" charts/mimir-rls/templates/deployment.yaml || echo "Not found in deployment template"

echo ""
echo "🎯 Diagnosis complete!"
echo ""
echo "🔧 If you see 4194304 or 4e+06 in any of the above, run:"
echo "./fix-4e06-error.sh"
echo ""
echo "🔧 Or manually fix with:"
echo "helm upgrade $RELEASE_NAME charts/mimir-rls -n $NAMESPACE --values values-rls-fixed.yaml"
