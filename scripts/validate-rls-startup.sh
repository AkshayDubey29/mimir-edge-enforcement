#!/bin/bash

# 🔍 Validate RLS Startup with Enhanced Health Checks
# This script validates that RLS gRPC services are properly started

echo "🔍 Validating RLS Startup with gRPC Health Checks"
echo "================================================="

NAMESPACE="mimir-edge-enforcement"

echo "📋 STEP 1: Check RLS Pod Status"
echo "-------------------------------"
kubectl get pods -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE -o wide

RLS_POD=$(kubectl get pods -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}')
echo "RLS Pod: $RLS_POD"

echo ""
echo "📋 STEP 2: Check RLS Startup Logs"
echo "---------------------------------"
echo "Looking for gRPC server startup messages:"
kubectl logs $RLS_POD -n $NAMESPACE | grep -E "(gRPC server started|health checks|components initialized)" || echo "No startup messages found"

echo ""
echo "📋 STEP 3: Test gRPC Health Checks"
echo "----------------------------------"

# Port-forward for gRPC health check testing
echo "Testing ext_authz gRPC health (port 8080)..."
kubectl port-forward $RLS_POD -n $NAMESPACE 8080:8080 &
PF_PID_8080=$!
sleep 3

# Test gRPC health check (requires grpcurl)
if command -v grpcurl >/dev/null 2>&1; then
    echo "Testing gRPC health check with grpcurl:"
    grpcurl -plaintext localhost:8080 grpc.health.v1.Health/Check || echo "grpcurl health check failed"
else
    echo "grpcurl not available - testing with curl (should show gRPC error):"
    curl -v localhost:8080 2>&1 | head -5
fi

kill $PF_PID_8080 2>/dev/null || true

echo ""
echo "Testing rate limit gRPC health (port 8081)..."
kubectl port-forward $RLS_POD -n $NAMESPACE 8081:8081 &
PF_PID_8081=$!
sleep 3

if command -v grpcurl >/dev/null 2>&1; then
    echo "Testing rate limit gRPC health check:"
    grpcurl -plaintext localhost:8081 grpc.health.v1.Health/Check || echo "grpcurl health check failed"
else
    echo "Testing with curl (should show gRPC error):"
    curl -v localhost:8081 2>&1 | head -5
fi

kill $PF_PID_8081 2>/dev/null || true

echo ""
echo "📋 STEP 4: Test from Admin UI (if available)"
echo "--------------------------------------------"
echo "Testing RLS connectivity from Admin UI perspective:"

# Get Admin UI pod
ADMIN_POD=$(kubectl get pods -l app.kubernetes.io/name=mimir-admin -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$ADMIN_POD" ]; then
    echo "Admin UI Pod: $ADMIN_POD"
    
    echo ""
    echo "Testing RLS gRPC connectivity from Admin UI:"
    kubectl exec $ADMIN_POD -n $NAMESPACE -- curl -s -m 5 --connect-timeout 2 \
        http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8080 >/dev/null 2>&1 && \
        echo "✅ RLS gRPC reachable from Admin UI" || \
        echo "❌ RLS gRPC NOT reachable from Admin UI"
    
    echo ""
    echo "Testing RLS HTTP admin from Admin UI:"
    kubectl exec $ADMIN_POD -n $NAMESPACE -- curl -s -m 5 \
        http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8082/health 2>/dev/null && \
        echo " ✅ RLS HTTP admin reachable" || \
        echo " ❌ RLS HTTP admin NOT reachable"
else
    echo "Admin UI pod not found - skipping connectivity test"
fi

echo ""
echo "📋 STEP 5: Check Service and Endpoints"
echo "--------------------------------------"
echo "RLS Service configuration:"
kubectl get svc mimir-rls -n $NAMESPACE -o yaml | grep -A 10 -B 5 "ports:"

echo ""
echo "RLS Service endpoints:"
kubectl get endpoints mimir-rls -n $NAMESPACE

echo ""
echo "📋 STEP 6: Validate Port Binding in Pod"
echo "---------------------------------------"
echo "Checking what ports RLS is actually listening on:"
kubectl exec $RLS_POD -n $NAMESPACE -- netstat -ln 2>/dev/null | grep -E ":808[0-2]" || echo "netstat not available in container"

echo ""
echo "📋 VALIDATION SUMMARY"
echo "====================="

# Check if all expected logs are present
STARTUP_LOGS=$(kubectl logs $RLS_POD -n $NAMESPACE | grep -c "gRPC server started" || echo "0")
HEALTH_LOGS=$(kubectl logs $RLS_POD -n $NAMESPACE | grep -c "health checks" || echo "0")

echo "Startup validation results:"
echo "- gRPC server startup logs: $STARTUP_LOGS (expected: 2)"
echo "- Health check logs: $HEALTH_LOGS (expected: 2)"

if [ "$STARTUP_LOGS" -eq "2" ] && [ "$HEALTH_LOGS" -eq "2" ]; then
    echo ""
    echo "✅ RLS STARTUP VALIDATION PASSED"
    echo "   Both ext_authz and rate limit gRPC servers started with health checks"
    echo ""
    echo "Next steps:"
    echo "1. Test Envoy connectivity with updated health checks"
    echo "2. Verify ext_authz requests are now working"
    echo "3. Check Envoy cluster health shows RLS as healthy"
else
    echo ""
    echo "❌ RLS STARTUP VALIDATION FAILED"
    echo "   Missing expected startup or health check logs"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Check RLS container logs for errors:"
    echo "   kubectl logs $RLS_POD -n $NAMESPACE"
    echo ""
    echo "2. Check if RLS image includes gRPC health fixes:"
    echo "   kubectl describe pod $RLS_POD -n $NAMESPACE | grep Image"
    echo ""
    echo "3. Rebuild and redeploy RLS with fixes:"
    echo "   # Build new RLS image with gRPC health checks"
    echo "   # Update helm chart with new image tag"
fi

echo ""
echo "🔍 RLS startup validation complete!"
