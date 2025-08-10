#!/bin/bash

# 🔍 Diagnose RLS Deployment Issues
echo "🔍 Diagnosing RLS Deployment and gRPC Connectivity"
echo "=================================================="

NAMESPACE="mimir-edge-enforcement"

echo "📋 STEP 1: RLS Pod Status and Details"
echo "-------------------------------------"
kubectl get pods -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE -o wide

RLS_POD=$(kubectl get pods -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}')
echo "RLS Pod: $RLS_POD"

echo ""
echo "📋 STEP 2: Check Container Ports Configuration"
echo "----------------------------------------------"
echo "Checking actual container ports from deployment:"
kubectl get deployment mimir-rls -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].ports}' | jq '.' 2>/dev/null || \
kubectl get deployment mimir-rls -n $NAMESPACE -o yaml | grep -A 10 "ports:"

echo ""
echo "📋 STEP 3: Check RLS Container Image"
echo "------------------------------------"
RLS_IMAGE=$(kubectl get deployment mimir-rls -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].image}')
echo "RLS Image: $RLS_IMAGE"

echo ""
echo "📋 STEP 4: Check RLS Pod Args (Port Configuration)"
echo "--------------------------------------------------"
echo "RLS startup args:"
kubectl get pod $RLS_POD -n $NAMESPACE -o jsonpath='{.spec.containers[0].args}' | tr ' ' '\n' | grep -E "port|Port"

echo ""
echo "📋 STEP 5: Check Recent RLS Logs"
echo "--------------------------------"
echo "Looking for gRPC server startup and health check messages:"
kubectl logs $RLS_POD -n $NAMESPACE --tail=50 | grep -E "(gRPC|health|started|listening|Failed|Error|Fatal)" || echo "No relevant startup messages found"

echo ""
echo "📋 STEP 6: Test Port Connectivity from Inside Cluster"
echo "-----------------------------------------------------"

# Get any pod that has curl/nc for testing
TEST_POD=$(kubectl get pods -l app.kubernetes.io/name=mimir-admin -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$TEST_POD" ]; then
    echo "Admin UI pod not found, checking for other pods with curl..."
    TEST_POD=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}')
fi

echo "Using test pod: $TEST_POD"

if [ -n "$TEST_POD" ]; then
    echo ""
    echo "Testing RLS gRPC port 8080 connectivity:"
    kubectl exec $TEST_POD -n $NAMESPACE -- timeout 5 nc -zv mimir-rls.mimir-edge-enforcement.svc.cluster.local 8080 2>&1 || \
    echo "❌ Port 8080 not reachable or nc not available"
    
    echo ""
    echo "Testing RLS rate limit port 8081 connectivity:"
    kubectl exec $TEST_POD -n $NAMESPACE -- timeout 5 nc -zv mimir-rls.mimir-edge-enforcement.svc.cluster.local 8081 2>&1 || \
    echo "❌ Port 8081 not reachable or nc not available"
    
    echo ""
    echo "Testing RLS admin port 8082 connectivity:"
    kubectl exec $TEST_POD -n $NAMESPACE -- curl -s -m 5 http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8082/health 2>/dev/null && \
    echo "✅ RLS admin port reachable" || echo "❌ RLS admin port not reachable"
fi

echo ""
echo "📋 STEP 7: Check Service Endpoints"
echo "----------------------------------"
echo "RLS Service endpoints (should show pod IPs):"
kubectl get endpoints mimir-rls -n $NAMESPACE -o yaml

echo ""
echo "📋 STEP 8: Check if New RLS Image is Deployed"
echo "---------------------------------------------"
echo "Checking if the deployment has the latest image with gRPC health fixes..."

# Check if the image tag indicates it has our fixes
if echo "$RLS_IMAGE" | grep -E "(latest|main|gRPC|health)" >/dev/null; then
    echo "✅ RLS appears to be using recent image: $RLS_IMAGE"
else
    echo "⚠️  RLS may be using old image: $RLS_IMAGE"
    echo "   Consider rebuilding and redeploying with latest gRPC health fixes"
fi

echo ""
echo "📋 STEP 9: Validate Pod is Actually Running"
echo "-------------------------------------------"
POD_STATUS=$(kubectl get pod $RLS_POD -n $NAMESPACE -o jsonpath='{.status.phase}')
READY_STATUS=$(kubectl get pod $RLS_POD -n $NAMESPACE -o jsonpath='{.status.containerStatuses[0].ready}')

echo "Pod Status: $POD_STATUS"
echo "Container Ready: $READY_STATUS"

if [ "$POD_STATUS" != "Running" ] || [ "$READY_STATUS" != "true" ]; then
    echo ""
    echo "❌ RLS Pod Issues Detected:"
    kubectl describe pod $RLS_POD -n $NAMESPACE | grep -A 10 -B 5 -E "(Events|Conditions|State)"
fi

echo ""
echo "📋 DIAGNOSIS SUMMARY"
echo "====================

The issue is likely one of these:

1. **RLS Image Missing gRPC Health Fixes**
   - Current image: $RLS_IMAGE
   - Solution: Rebuild and deploy RLS with latest code
   
2. **RLS gRPC Servers Not Starting**
   - Check logs above for 'gRPC server started' messages
   - Should see 2 messages: ext_authz and rate limit servers
   
3. **Container Port vs Service Port Mismatch**
   - Service expects named ports: ext-authz, ratelimit, admin, metrics
   - Container should expose same named ports
   
4. **Pod Not Ready**
   - Pod Status: $POD_STATUS
   - Container Ready: $READY_STATUS
   
5. **Firewall/Network Policy Issues**
   - Service endpoints should list pod IP addresses
   - Connectivity tests should succeed

NEXT STEPS:
===========
1. If no 'gRPC server started' logs → Rebuild RLS image with fixes
2. If connectivity fails → Check service/endpoints configuration  
3. If pod not ready → Check pod events and container logs
4. If image is old → Deploy latest image with gRPC health checks"

echo ""
echo "🔍 RLS deployment diagnosis complete!"
