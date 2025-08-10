#!/bin/bash

# 🔄 Quick restart of RLS deployment to pick up latest image
echo "🔄 Restarting RLS Deployment to Pick Up Latest Image"
echo "===================================================="

NAMESPACE="mimir-edge-enforcement"

echo "📋 Current RLS deployment status:"
kubectl get deployment mimir-rls -n $NAMESPACE -o wide

echo ""
echo "📋 Current RLS pods:"
kubectl get pods -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE -o wide

echo ""
echo "🔄 Restarting RLS deployment..."
kubectl rollout restart deployment/mimir-rls -n $NAMESPACE

echo ""
echo "⏳ Waiting for rollout to complete..."
kubectl rollout status deployment/mimir-rls -n $NAMESPACE --timeout=300s

echo ""
echo "📋 New deployment status:"
kubectl get deployment mimir-rls -n $NAMESPACE -o wide

echo ""
echo "📋 New pod status:"
kubectl get pods -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE -o wide

# Get the new pod name
NEW_POD=$(kubectl get pods -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}')
echo ""
echo "🔍 New RLS Pod: $NEW_POD"

echo ""
echo "📋 Checking new pod image:"
POD_IMAGE=$(kubectl get pod $NEW_POD -n $NAMESPACE -o jsonpath='{.spec.containers[0].image}')
echo "Pod Image: $POD_IMAGE"

echo ""
echo "📋 Checking for gRPC health startup messages:"
echo "(Waiting 10 seconds for pod to fully start...)"
sleep 10

kubectl logs $NEW_POD -n $NAMESPACE | grep -E "(gRPC server started|health checks|started|listening)" || echo "No startup messages found yet"

echo ""
echo "🔧 Quick connectivity test:"

# Try to test connectivity if Admin UI is available
ADMIN_POD=$(kubectl get pods -l app.kubernetes.io/name=mimir-admin -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -n "$ADMIN_POD" ]; then
    echo "Testing connectivity from Admin UI..."
    sleep 5  # Give RLS a moment to start
    
    if kubectl exec $ADMIN_POD -n $NAMESPACE -- timeout 3 nc -zv mimir-rls.mimir-edge-enforcement.svc.cluster.local 8080 2>/dev/null; then
        echo "✅ RLS gRPC is now reachable!"
    else
        echo "❌ RLS gRPC still not reachable (may need more time or image rebuild)"
    fi
else
    echo "Admin UI not available for testing"
fi

echo ""
echo "🎯 RESTART SUMMARY"
echo "=================="
echo "✅ RLS deployment restarted"
echo "📍 New pod: $NEW_POD"
echo "🏷️  Image: $POD_IMAGE"
echo ""

GRPC_LOGS=$(kubectl logs $NEW_POD -n $NAMESPACE | grep -c "gRPC server started" 2>/dev/null || echo "0")

if [ "$GRPC_LOGS" -eq "2" ]; then
    echo "✅ SUCCESS: gRPC servers appear to be running with health checks"
    echo ""
    echo "🔄 Next steps:"
    echo "1. Test Admin UI diagnostics again"
    echo "2. Verify Envoy can now connect to RLS"
    echo "3. Check traffic flow through edge enforcement"
else
    echo "⚠️  WARNING: Expected 2 'gRPC server started' messages, found: $GRPC_LOGS"
    echo ""
    echo "This could mean:"
    echo "1. ⏳ Pod still starting up (check again in 30 seconds)"
    echo "2. 🏗️  New image with fixes not yet built (check GitHub Actions)"
    echo "3. 🔧 Additional fixes needed"
    echo ""
    echo "🔍 Debug commands:"
    echo "- kubectl logs $NEW_POD -n $NAMESPACE"
    echo "- kubectl describe pod $NEW_POD -n $NAMESPACE"
    echo "- ./scripts/diagnose-rls-deployment.sh"
fi

echo ""
echo "🔄 RLS restart complete!"
