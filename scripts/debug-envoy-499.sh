#!/bin/bash

# Debug script for Envoy 499 errors
set -e

NAMESPACE="mimir-edge-enforcement"
ENVOY_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=envoy -o jsonpath='{.items[0].metadata.name}')

echo "🔧 Debugging Envoy 499 errors..."

echo "📋 1. Check Envoy pod status:"
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=envoy

echo ""
echo "📋 2. Check Envoy logs for errors:"
kubectl logs -n $NAMESPACE $ENVOY_POD --tail=50 | grep -E "(error|ERROR|failed|FAILED|499|timeout)"

echo ""
echo "📋 3. Check if Envoy can reach Mimir distributor:"
kubectl exec -it -n $NAMESPACE $ENVOY_POD -- curl -v --connect-timeout 10 http://mimir-distributor.mimir.svc.cluster.local:8080/ready

echo ""
echo "📋 4. Check Envoy admin interface:"
kubectl port-forward -n $NAMESPACE $ENVOY_POD 9901:9901 &
PF_PID=$!
sleep 3

echo "   - Cluster status:"
curl -s http://localhost:9901/clusters | grep -E "(mimir_distributor|rls_ext_authz)"

echo "   - Stats:"
curl -s http://localhost:9901/stats | grep -E "(http|downstream|upstream|cluster)"

echo "   - Config dump:"
curl -s http://localhost:9901/config_dump | jq '.configs[] | select(.["@type"] | contains("listener")) | .active_state.listener.filter_chains[0].filters[0].typed_config.route_config.virtual_hosts[0].routes'

kill $PF_PID

echo ""
echo "📋 5. Test direct request to Envoy:"
kubectl port-forward -n $NAMESPACE $ENVOY_POD 8080:8080 &
PF2_PID=$!
sleep 3

echo "   - Testing debug endpoint:"
curl -v http://localhost:8080/debug

echo "   - Testing /api/v1/push endpoint:"
curl -v -X POST http://localhost:8080/api/v1/push \
  -H "Content-Type: application/x-protobuf" \
  -H "X-Scope-OrgID: test-tenant" \
  -d "test data" \
  --max-time 30

kill $PF2_PID

echo ""
echo "📋 6. Check Mimir distributor status:"
kubectl get pods -n mimir -l app.kubernetes.io/name=distributor

echo ""
echo "📋 7. Check network connectivity:"
echo "   - From Envoy to Mimir distributor:"
kubectl exec -it -n $NAMESPACE $ENVOY_POD -- nslookup mimir-distributor.mimir.svc.cluster.local

echo "   - From Envoy to RLS:"
kubectl exec -it -n $NAMESPACE $ENVOY_POD -- nslookup mimir-rls.mimir-edge-enforcement.svc.cluster.local

echo ""
echo "🎯 Summary:"
echo "- If step 3 fails: Envoy cannot reach Mimir distributor"
echo "- If step 4 shows unhealthy clusters: Cluster health check issues"
echo "- If step 5 fails: Envoy configuration issues"
echo "- If step 7 fails: DNS resolution issues"
