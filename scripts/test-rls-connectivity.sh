#!/bin/bash

# Test RLS Connectivity and Service Health
# This script helps debug why ext_authz is not working

set -e

NAMESPACE="mimir-edge-enforcement"
RLS_SERVICE="mimir-rls"
ENVOY_POD="mimir-envoy"

echo "🔍 Testing RLS Connectivity and Service Health"
echo "=============================================="

# 1. Check if RLS pods are running
echo "📋 1. Checking RLS Pod Status:"
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=mimir-rls -o wide

# 2. Check RLS service
echo -e "\n📋 2. Checking RLS Service:"
kubectl get svc -n $NAMESPACE -l app.kubernetes.io/name=mimir-rls -o wide

# 3. Check RLS logs
echo -e "\n📋 3. Checking RLS Logs (last 20 lines):"
kubectl logs -n $NAMESPACE deployment/mimir-rls --tail=20

# 4. Test HTTP connectivity to RLS admin port
echo -e "\n📋 4. Testing HTTP connectivity to RLS admin port (8082):"
kubectl exec -it -n $NAMESPACE deployment/$ENVOY_POD -- \
  curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" \
  http://$RLS_SERVICE.$NAMESPACE.svc.cluster.local:8082/readyz || echo "❌ Failed to connect"

# 5. Test HTTP connectivity to RLS metrics port
echo -e "\n📋 5. Testing HTTP connectivity to RLS metrics port (9090):"
kubectl exec -it -n $NAMESPACE deployment/$ENVOY_POD -- \
  curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" \
  http://$RLS_SERVICE.$NAMESPACE.svc.cluster.local:9090/metrics || echo "❌ Failed to connect"

# 6. Test gRPC connectivity to ext_authz port
echo -e "\n📋 6. Testing gRPC connectivity to ext_authz port (8080):"
kubectl exec -it -n $NAMESPACE deployment/$ENVOY_POD -- \
  curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" \
  http://$RLS_SERVICE.$NAMESPACE.svc.cluster.local:8080/ || echo "❌ Failed to connect"

# 7. Check if gRPC services are registered
echo -e "\n📋 7. Checking if gRPC services are registered:"
if command -v grpcurl &> /dev/null; then
    kubectl exec -it -n $NAMESPACE deployment/$ENVOY_POD -- \
      grpcurl -plaintext $RLS_SERVICE.$NAMESPACE.svc.cluster.local:8080 list || echo "❌ grpcurl not available or failed"
else
    echo "⚠️  grpcurl not available - install it to test gRPC services"
fi

# 8. Check DNS resolution
echo -e "\n📋 8. Testing DNS resolution:"
kubectl exec -it -n $NAMESPACE deployment/$ENVOY_POD -- \
  nslookup $RLS_SERVICE.$NAMESPACE.svc.cluster.local || echo "❌ DNS resolution failed"

# 9. Check network connectivity
echo -e "\n📋 9. Testing network connectivity:"
kubectl exec -it -n $NAMESPACE deployment/$ENVOY_POD -- \
  ping -c 3 $RLS_SERVICE.$NAMESPACE.svc.cluster.local || echo "❌ Ping failed"

# 10. Check RLS service endpoints
echo -e "\n📋 10. Checking RLS Service Endpoints:"
kubectl get endpoints -n $NAMESPACE $RLS_SERVICE -o yaml

# 11. Check RLS pod readiness
echo -e "\n📋 11. Checking RLS Pod Readiness:"
kubectl describe pod -n $NAMESPACE -l app.kubernetes.io/name=mimir-rls

echo -e "\n✅ RLS Connectivity Test Complete!"
echo "If any tests failed, check the RLS deployment and service configuration."
