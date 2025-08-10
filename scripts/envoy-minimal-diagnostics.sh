#!/bin/bash

# 🔍 Envoy Minimal Diagnostics (No vi/vim/wget required)
# Use only basic commands available in distroless Envoy container

echo "🔍 Envoy Minimal Diagnostics (Distroless Container)"
echo "=================================================="

echo "Available commands in this container:"
echo "curl, nc (netcat), ls, cat, echo, grep, awk, sed"
echo ""

echo "📋 STEP 1: Test Admin Interface"
echo "-------------------------------"
curl -s http://localhost:9901/ready

echo ""
echo "📋 STEP 2: Test RLS Connectivity (CRITICAL)"
echo "--------------------------------------------"
echo "Testing RLS gRPC port (this is the most important test):"
if nc -z mimir-rls.mimir-edge-enforcement.svc.cluster.local 8080; then
    echo "✅ RLS gRPC is REACHABLE"
else
    echo "❌ RLS gRPC is NOT REACHABLE - THIS IS THE PROBLEM!"
    echo "   ext_authz will deny ALL requests when RLS is unreachable"
fi

echo ""
echo "📋 STEP 3: Check ext_authz Statistics"
echo "--------------------------------------"
echo "ext_authz filter statistics:"
curl -s http://localhost:9901/stats | grep ext_authz

echo ""
echo "📋 STEP 4: Test Internal Request Processing"
echo "--------------------------------------------"
echo "Testing /ready (should work):"
curl -s -w "HTTP Status: %{http_code}\n" http://localhost:8080/ready

echo ""
echo "Testing /api/v1/push (may fail if ext_authz blocks):"
curl -s -w "HTTP Status: %{http_code}\n" \
  -H "X-Scope-OrgID: test-tenant" \
  -H "Content-Type: application/x-protobuf" \
  -X POST \
  -d "test-data" \
  http://localhost:8080/api/v1/push

echo ""
echo "📋 STEP 5: Check Cluster Health"
echo "--------------------------------"
echo "RLS ext_authz cluster:"
curl -s http://localhost:9901/clusters | grep -A 3 -B 1 "rls_ext_authz"

echo ""
echo "Mimir distributor cluster:"
curl -s http://localhost:9901/clusters | grep -A 3 -B 1 "mimir_distributor"

echo ""
echo "📋 STEP 6: Check Route Configuration"
echo "------------------------------------"
echo "Looking for /api/v1/push route:"
curl -s http://localhost:9901/config_dump | grep -c "/api/v1/push"
echo "Routes found: $?"

echo ""
echo "📋 DIAGNOSIS SUMMARY"
echo "===================="

# Simple diagnosis without complex tools
RLS_REACHABLE=$(nc -z mimir-rls.mimir-edge-enforcement.svc.cluster.local 8080 && echo "YES" || echo "NO")
echo "RLS Reachable: $RLS_REACHABLE"

if [ "$RLS_REACHABLE" = "NO" ]; then
    echo ""
    echo "🔥 PROBLEM IDENTIFIED: RLS Service Not Reachable"
    echo "================================================"
    echo "The RLS service on port 8080 is not reachable from Envoy."
    echo "This causes ext_authz to deny ALL requests (failure_mode_allow: false)"
    echo ""
    echo "WHAT YOU'LL SEE:"
    echo "- Only /ready health checks in Envoy logs"
    echo "- No /api/v1/push requests processed"
    echo "- NGINX shows route=edge 200 (traffic reaches Envoy)"
    echo "- But Envoy silently drops requests after failed ext_authz"
    echo ""
    echo "NEXT STEPS:"
    echo "1. Check if RLS pods are running"
    echo "2. Check if RLS service exists and has endpoints"
    echo "3. Check if RLS is listening on port 8080"
    echo "4. Temporarily set failureModeAllow: true to test"
else
    echo ""
    echo "✅ RLS is reachable - issue is elsewhere"
    echo "Check ext_authz stats above for denied/error counts"
fi
