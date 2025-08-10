#!/bin/bash

# 🔍 Test Admin UI to RLS Connectivity
echo "🔍 Testing Admin UI to RLS Connectivity"
echo "======================================"

NAMESPACE="mimir-edge-enforcement"

echo "📋 STEP 1: Check if both services are running"
echo "---------------------------------------------"
echo "Admin UI pods:"
kubectl get pods -l app.kubernetes.io/name=mimir-admin -n $NAMESPACE -o wide

echo ""
echo "RLS pods:"
kubectl get pods -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE -o wide

echo ""
echo "📋 STEP 2: Check services"
echo "-------------------------"
echo "Admin UI service:"
kubectl get svc -l app.kubernetes.io/name=mimir-admin -n $NAMESPACE

echo ""
echo "RLS service:"
kubectl get svc -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE

echo ""
echo "📋 STEP 3: Test RLS HTTP admin endpoints directly"
echo "------------------------------------------------"
RLS_POD=$(kubectl get pods -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}')
echo "Testing RLS pod: $RLS_POD"

if [ -n "$RLS_POD" ]; then
    echo ""
    echo "Testing RLS health endpoint (should return 'ok'):"
    kubectl exec $RLS_POD -n $NAMESPACE -- curl -s http://localhost:8082/healthz || echo "❌ Health check failed"
    
    echo ""
    echo "Testing RLS API health endpoint:"
    kubectl exec $RLS_POD -n $NAMESPACE -- curl -s http://localhost:8082/api/health || echo "❌ API health check failed"
    
    echo ""
    echo "Testing RLS tenants endpoint:"
    kubectl exec $RLS_POD -n $NAMESPACE -- curl -s http://localhost:8082/api/tenants || echo "❌ Tenants endpoint failed"
    
    echo ""
    echo "Testing RLS overview endpoint:"
    kubectl exec $RLS_POD -n $NAMESPACE -- curl -s http://localhost:8082/api/overview || echo "❌ Overview endpoint failed"
else
    echo "❌ No RLS pod found"
fi

echo ""
echo "📋 STEP 4: Test connectivity from Admin UI to RLS"
echo "-------------------------------------------------"
ADMIN_POD=$(kubectl get pods -l app.kubernetes.io/name=mimir-admin -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}')
echo "Testing from Admin UI pod: $ADMIN_POD"

if [ -n "$ADMIN_POD" ]; then
    echo ""
    echo "Testing DNS resolution from Admin UI to RLS:"
    kubectl exec $ADMIN_POD -n $NAMESPACE -- nslookup mimir-rls || echo "❌ DNS resolution failed"
    
    echo ""
    echo "Testing basic connectivity from Admin UI to RLS:"
    kubectl exec $ADMIN_POD -n $NAMESPACE -- curl -s -m 5 http://mimir-rls:8082/healthz || echo "❌ Basic connectivity failed"
    
    echo ""
    echo "Testing API endpoints from Admin UI to RLS:"
    kubectl exec $ADMIN_POD -n $NAMESPACE -- curl -s -m 5 http://mimir-rls:8082/api/health || echo "❌ API health from UI failed"
    
    echo ""
    echo "Testing tenants endpoint from Admin UI:"
    kubectl exec $ADMIN_POD -n $NAMESPACE -- curl -s -m 5 http://mimir-rls:8082/api/tenants || echo "❌ Tenants from UI failed"
else
    echo "❌ No Admin UI pod found"
fi

echo ""
echo "📋 STEP 5: Check RLS logs for HTTP server issues"
echo "------------------------------------------------"
if [ -n "$RLS_POD" ]; then
    echo "Recent RLS logs (looking for HTTP server startup and errors):"
    kubectl logs $RLS_POD -n $NAMESPACE --tail=50 | grep -E "(admin HTTP server|HTTP|error|Error|fail|Fail)" || echo "No HTTP-related logs found"
    
    echo ""
    echo "All recent RLS startup logs:"
    kubectl logs $RLS_POD -n $NAMESPACE --tail=20
else
    echo "❌ No RLS pod to check logs"
fi

echo ""
echo "📋 STEP 6: Check Admin UI nginx logs"
echo "------------------------------------"
if [ -n "$ADMIN_POD" ]; then
    echo "Recent Admin UI nginx logs (looking for proxy errors):"
    kubectl logs $ADMIN_POD -n $NAMESPACE --tail=20 | grep -E "(error|Error|fail|Fail|502|503|504)" || echo "No nginx error logs found"
    
    echo ""
    echo "All recent Admin UI logs:"
    kubectl logs $ADMIN_POD -n $NAMESPACE --tail=10
else
    echo "❌ No Admin UI pod to check logs"
fi

echo ""
echo "📋 DIAGNOSIS SUMMARY"
echo "====================" 

echo ""
echo "Common issues and fixes:"
echo "1. ❌ RLS HTTP admin server not starting → Check RLS pod logs"
echo "2. ❌ Service name resolution → Check if both pods are in same namespace"
echo "3. ❌ Port mismatch → RLS should be listening on 8082 for admin API"
echo "4. ❌ RLS service configuration → Check if HTTP admin server started"
echo "5. ❌ Network policies → Check if Admin UI can reach RLS service"

echo ""
echo "🔍 UI to RLS connectivity test complete!"
