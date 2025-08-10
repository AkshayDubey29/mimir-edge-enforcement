#!/bin/bash

# 🔍 Envoy Ultra-Minimal Diagnostics (No curl, vi, vim, wget)
# Use only the most basic commands that should exist in ANY container

echo "🔍 Envoy Ultra-Minimal Diagnostics"
echo "=================================="

echo "📋 STEP 1: Check what commands are available"
echo "--------------------------------------------"
echo "Available basic commands:"
ls /bin/ /usr/bin/ 2>/dev/null | grep -E "(nc|netcat|telnet|cat|echo|ps|ls)"

echo ""
echo "📋 STEP 2: Check if Envoy process is running"
echo "--------------------------------------------"
ps aux | grep envoy || ps | grep envoy || echo "ps command not available"

echo ""
echo "📋 STEP 3: Test network connectivity with basic tools"
echo "-----------------------------------------------------"

# Test RLS connectivity with nc (netcat)
echo "Testing RLS gRPC connectivity (port 8080):"
if command -v nc >/dev/null 2>&1; then
    if nc -z mimir-rls.mimir-edge-enforcement.svc.cluster.local 8080; then
        echo "✅ RLS gRPC port 8080 is REACHABLE"
    else
        echo "❌ RLS gRPC port 8080 is NOT REACHABLE"
        echo "   THIS IS LIKELY THE PROBLEM!"
    fi
else
    echo "❌ nc (netcat) not available"
fi

# Test with telnet if nc not available
if command -v telnet >/dev/null 2>&1; then
    echo "Testing with telnet..."
    timeout 3 telnet mimir-rls.mimir-edge-enforcement.svc.cluster.local 8080 && echo "✅ RLS reachable via telnet" || echo "❌ RLS not reachable via telnet"
fi

echo ""
echo "📋 STEP 4: Check listening ports"
echo "--------------------------------"
if command -v netstat >/dev/null 2>&1; then
    echo "Ports Envoy is listening on:"
    netstat -ln 2>/dev/null | grep ":8080\|:9901" || echo "netstat not available"
elif command -v ss >/dev/null 2>&1; then
    echo "Ports Envoy is listening on (ss):"
    ss -ln 2>/dev/null | grep ":8080\|:9901" || echo "ss not available"
else
    echo "No network port checking tools available"
fi

echo ""
echo "📋 STEP 5: Check filesystem for config"
echo "--------------------------------------"
echo "Looking for Envoy config files:"
ls -la /etc/envoy* 2>/dev/null || echo "No /etc/envoy config found"
ls -la /config* 2>/dev/null || echo "No /config found"
find / -name "*envoy*" -type f 2>/dev/null | head -5 || echo "find not available"

echo ""
echo "📋 STEP 6: Check environment variables"
echo "--------------------------------------"
echo "Envoy-related environment variables:"
env | grep -i envoy || echo "No envoy environment variables"

echo ""
echo "📋 STEP 7: Test basic network connectivity"
echo "------------------------------------------"
echo "Testing basic DNS resolution:"
if command -v nslookup >/dev/null 2>&1; then
    nslookup mimir-rls.mimir-edge-enforcement.svc.cluster.local || echo "nslookup failed"
elif command -v dig >/dev/null 2>&1; then
    dig mimir-rls.mimir-edge-enforcement.svc.cluster.local || echo "dig failed"
else
    echo "No DNS lookup tools available"
fi

echo ""
echo "📋 DIAGNOSIS WITHOUT CURL"
echo "========================="

if command -v nc >/dev/null 2>&1; then
    RLS_STATUS=$(nc -z mimir-rls.mimir-edge-enforcement.svc.cluster.local 8080 && echo "REACHABLE" || echo "NOT_REACHABLE")
    echo "RLS Service Status: $RLS_STATUS"
    
    if [ "$RLS_STATUS" = "NOT_REACHABLE" ]; then
        echo ""
        echo "🔥 PROBLEM IDENTIFIED: RLS Service Unreachable"
        echo "=============================================="
        echo "The RLS service cannot be reached from Envoy."
        echo "This explains why only /ready health checks work:"
        echo ""
        echo "1. NGINX forwards requests to Envoy ✅"
        echo "2. Envoy receives requests ✅"  
        echo "3. ext_authz tries to contact RLS ❌"
        echo "4. ext_authz fails, denies request ❌"
        echo "5. No request reaches Mimir ❌"
        echo "6. Only /ready bypasses ext_authz ✅"
        echo ""
        echo "IMMEDIATE FIX NEEDED:"
        echo "- Check RLS pod status"
        echo "- Check RLS service endpoints"
        echo "- Check network policies"
        echo "- Or temporarily set failureModeAllow: true"
    else
        echo ""
        echo "✅ RLS is reachable - need to investigate further"
        echo "Run these external commands to check Envoy admin:"
        echo "kubectl port-forward <envoy-pod> 9901:9901"
        echo "curl http://localhost:9901/stats | grep ext_authz"
    fi
else
    echo ""
    echo "⚠️  Cannot test connectivity without nc/netcat"
    echo "Available container debugging approach:"
    echo "1. Check from outside: kubectl exec <envoy-pod> -- nc -z <rls-service> 8080"
    echo "2. Port-forward admin: kubectl port-forward <envoy-pod> 9901:9901"
    echo "3. Check admin stats: curl http://localhost:9901/stats"
fi

echo ""
echo "📋 EXTERNAL COMMANDS TO RUN"
echo "============================"
echo "Since curl is not available in the container, run these from outside:"
echo ""
echo "# Test RLS connectivity from Envoy"
echo "kubectl exec <envoy-pod-name> -n mimir-edge-enforcement -- nc -z mimir-rls.mimir-edge-enforcement.svc.cluster.local 8080"
echo ""
echo "# Port-forward Envoy admin interface"
echo "kubectl port-forward <envoy-pod-name> -n mimir-edge-enforcement 9901:9901"
echo ""
echo "# Check Envoy admin stats (from your local machine)"
echo "curl http://localhost:9901/stats | grep ext_authz"
echo "curl http://localhost:9901/clusters"
echo ""
echo "# Test request processing (from your local machine)"
echo "kubectl port-forward <envoy-pod-name> -n mimir-edge-enforcement 8080:8080"
echo "curl -H 'X-Scope-OrgID: test' -X POST -d 'test' http://localhost:8080/api/v1/push"
