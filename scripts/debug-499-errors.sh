#!/bin/bash

# 🔍 Debug 499 Errors in Admin UI
echo "🔍 Debugging 499 Errors in Admin UI"
echo "==================================="

NAMESPACE="mimir-edge-enforcement"

echo "📋 STEP 1: Check RLS response times"
echo "-----------------------------------"
RLS_POD=$(kubectl get pods -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}')
echo "Testing RLS pod: $RLS_POD"

if [ -n "$RLS_POD" ]; then
    echo ""
    echo "Testing RLS response times (should be < 5s):"
    
    echo "1. Health endpoint:"
    time kubectl exec $RLS_POD -n $NAMESPACE -- curl -s http://localhost:8082/healthz
    
    echo ""
    echo "2. API health endpoint:"
    time kubectl exec $RLS_POD -n $NAMESPACE -- curl -s http://localhost:8082/api/health
    
    echo ""
    echo "3. Tenants endpoint (might be slow):"
    timeout 30s time kubectl exec $RLS_POD -n $NAMESPACE -- curl -s http://localhost:8082/api/tenants || echo "❌ Tenants endpoint timed out (>30s)"
    
    echo ""
    echo "4. Overview endpoint (might be slow):"
    timeout 30s time kubectl exec $RLS_POD -n $NAMESPACE -- curl -s http://localhost:8082/api/overview || echo "❌ Overview endpoint timed out (>30s)"
else
    echo "❌ No RLS pod found"
fi

echo ""
echo "📋 STEP 2: Check RLS resource usage"
echo "-----------------------------------"
echo "RLS pod resource usage:"
kubectl top pod -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE || echo "Metrics not available"

echo ""
echo "RLS pod resource limits:"
kubectl describe pod -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE | grep -A 5 -B 5 "Limits:\|Requests:"

echo ""
echo "📋 STEP 3: Check RLS logs for performance issues"
echo "------------------------------------------------"
if [ -n "$RLS_POD" ]; then
    echo "Recent RLS logs (looking for slow operations):"
    kubectl logs $RLS_POD -n $NAMESPACE --tail=50 | grep -E "(timeout|slow|Timeout|Slow|taking|seconds|ms)" || echo "No performance warnings found"
    
    echo ""
    echo "Recent RLS errors:"
    kubectl logs $RLS_POD -n $NAMESPACE --tail=50 | grep -E "(error|Error|fail|Fail|panic|Panic)" || echo "No errors found"
    
    echo ""
    echo "RLS startup messages:"
    kubectl logs $RLS_POD -n $NAMESPACE | grep -E "(started|initialized|server)" || echo "No startup messages found"
else
    echo "❌ No RLS pod to check logs"
fi

echo ""
echo "📋 STEP 4: Test from Admin UI perspective"
echo "-----------------------------------------"
ADMIN_POD=$(kubectl get pods -l app.kubernetes.io/name=mimir-admin -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}')
echo "Testing from Admin UI pod: $ADMIN_POD"

if [ -n "$ADMIN_POD" ]; then
    echo ""
    echo "1. Quick health check from Admin UI (should be fast):"
    time kubectl exec $ADMIN_POD -n $NAMESPACE -- curl -s -m 10 http://mimir-rls:8082/healthz || echo "❌ Health check failed or timed out"
    
    echo ""
    echo "2. API endpoints from Admin UI (checking for slowness):"
    echo "   - Testing tenants endpoint with 30s timeout:"
    time kubectl exec $ADMIN_POD -n $NAMESPACE -- curl -s -m 30 http://mimir-rls:8082/api/tenants || echo "❌ Tenants endpoint failed or timed out"
    
    echo ""
    echo "   - Testing overview endpoint with 30s timeout:"
    time kubectl exec $ADMIN_POD -n $NAMESPACE -- curl -s -m 30 http://mimir-rls:8082/api/overview || echo "❌ Overview endpoint failed or timed out"
else
    echo "❌ No Admin UI pod found"
fi

echo ""
echo "📋 STEP 5: Check Admin UI nginx logs for 499 errors"
echo "----------------------------------------------------"
if [ -n "$ADMIN_POD" ]; then
    echo "Recent nginx access logs (looking for 499 errors):"
    kubectl logs $ADMIN_POD -n $NAMESPACE --tail=50 | grep -E "(499|timeout|Timeout)" || echo "No 499 errors found in recent logs"
    
    echo ""
    echo "All recent nginx logs:"
    kubectl logs $ADMIN_POD -n $NAMESPACE --tail=20
else
    echo "❌ No Admin UI pod to check logs"
fi

echo ""
echo "📋 DIAGNOSIS SUMMARY"
echo "===================="
echo ""
echo "499 Error Causes and Solutions:"
echo "1. 🐌 RLS endpoints taking >30s → Increase nginx timeouts (done)"
echo "2. 💾 Resource constraints → Check CPU/memory limits"
echo "3. 🔄 Tenant processing slow → Check tenant count and limits"
echo "4. 🐛 RLS startup issues → Check for errors in RLS logs"
echo "5. 🌐 Network issues → Check service connectivity"
echo ""
echo "If endpoints take >30s, the issue is likely:"
echo "- Large tenant list processing"
echo "- Resource constraints (CPU/memory)"
echo "- Database/storage performance issues"
echo "- RLS service startup problems"

echo ""
echo "🔍 499 error debugging complete!"
