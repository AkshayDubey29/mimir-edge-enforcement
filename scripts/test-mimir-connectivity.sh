#!/bin/bash

# Test Mimir distributor connectivity from Envoy
set -e

NAMESPACE="mimir-edge-enforcement"
ENVOY_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=envoy -o jsonpath='{.items[0].metadata.name}')

echo "🔧 Testing Mimir distributor connectivity from Envoy..."

echo "📋 1. Check if Mimir distributor is reachable:"
kubectl exec -it -n $NAMESPACE $ENVOY_POD -- curl -v --connect-timeout 10 --max-time 30 \
  http://mimir-distributor.mimir.svc.cluster.local:8080/ready

echo ""
echo "📋 2. Test /api/v1/push endpoint directly:"
kubectl exec -it -n $NAMESPACE $ENVOY_POD -- curl -v --connect-timeout 10 --max-time 30 \
  -X POST http://mimir-distributor.mimir.svc.cluster.local:8080/api/v1/push \
  -H "Content-Type: application/x-protobuf" \
  -H "X-Scope-OrgID: test-tenant" \
  -d "test data"

echo ""
echo "📋 3. Check Mimir distributor pod status:"
kubectl get pods -n mimir -l app.kubernetes.io/name=distributor

echo ""
echo "📋 4. Check Mimir distributor logs:"
kubectl logs -n mimir deployment/mimir-distributor --tail=20

echo ""
echo "📋 5. Test DNS resolution:"
kubectl exec -it -n $NAMESPACE $ENVOY_POD -- nslookup mimir-distributor.mimir.svc.cluster.local

echo ""
echo "📋 6. Check network connectivity:"
kubectl exec -it -n $NAMESPACE $ENVOY_POD -- ping -c 3 mimir-distributor.mimir.svc.cluster.local

echo ""
echo "🎯 Summary:"
echo "- If step 1 fails: Mimir distributor is not responding"
echo "- If step 2 fails: /api/v1/push endpoint has issues"
echo "- If step 5 fails: DNS resolution issues"
echo "- If step 6 fails: Network connectivity issues"
