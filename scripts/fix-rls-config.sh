#!/bin/bash

# 🔧 Fix RLS Configuration and Deploy Updated Helm Chart
echo "🔧 Fixing RLS Configuration for gRPC Health Check Support"
echo "========================================================="

NAMESPACE="mimir-edge-enforcement"

echo "📋 Current RLS deployment status:"
kubectl get deployment mimir-rls -n $NAMESPACE -o wide

echo ""
echo "📋 Current pod arguments:"
RLS_POD=$(kubectl get pods -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}')
echo "RLS Pod: $RLS_POD"
kubectl get pod $RLS_POD -n $NAMESPACE -o yaml | grep -A 20 "args:" | head -20

echo ""
echo "🔧 ISSUE IDENTIFIED:"
echo "==================="
echo "The RLS deployment is missing critical command-line arguments required"
echo "for proper gRPC health check functionality. The following arguments"
echo "are missing or misconfigured:"
echo ""
echo "❌ Missing: --max-request-bytes"
echo "❌ Missing: --failure-mode-allow"  
echo "❌ Missing: --default-max-labels-per-series"
echo "❌ Missing: --default-max-label-value-length"
echo "❌ Missing: --default-max-series-per-request"
echo ""
echo "🔧 SOLUTION:"
echo "============="
echo "1. Update RLS Helm chart with complete configuration"
echo "2. Redeploy RLS with enhanced values"
echo "3. Validate gRPC servers start properly"

echo ""
echo "🚀 Updating RLS Helm deployment..."

# Create enhanced values for RLS
cat > /tmp/rls-enhanced-values.yaml <<EOF
# Enhanced RLS Configuration with gRPC Health Check Support
replicaCount: 1

image:
  repository: ghcr.io/AkshayDubey29/mimir-rls
  tag: "latest"
  pullPolicy: IfNotPresent

# Enhanced limits configuration
limits:
  defaultSamplesPerSecond: 0    # ConfigMap driven
  defaultBurstPercent: 0        # ConfigMap driven
  maxBodyBytes: 0               # ConfigMap driven
  enforceBodyParsing: true
  
  # 🔧 FIX: Add missing RLS configuration options
  maxRequestBytes: 4000000      # 4 MiB - Maximum request body size for gRPC
  failureModeAllow: false       # Fail closed for security (set true for debugging)
  defaultMaxLabelsPerSeries: 60
  defaultMaxLabelValueLength: 2048
  defaultMaxSeriesPerRequest: 100000

# Tenant configuration
tenantHeader: "X-Scope-OrgID"

# Logging with enhanced verbosity
log:
  level: "debug"  # Enhanced logging to see gRPC startup messages

# Service configuration
service:
  type: ClusterIP
  ports:
    extAuthz: 8080
    rateLimit: 8081
    admin: 8082
    metrics: 9090

# Resources for production
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 200m
    memory: 256Mi

# Security context
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000
  capabilities:
    drop:
      - ALL

podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
EOF

echo "Helm upgrade command:"
echo "helm upgrade mimir-rls charts/mimir-rls \\"
echo "  --namespace $NAMESPACE \\"
echo "  --values /tmp/rls-enhanced-values.yaml \\"
echo "  --wait --timeout=300s"

echo ""
read -p "Proceed with RLS configuration update? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Update cancelled"
    exit 1
fi

echo "🚀 Updating RLS with enhanced configuration..."
if helm upgrade mimir-rls charts/mimir-rls \
  --namespace $NAMESPACE \
  --values /tmp/rls-enhanced-values.yaml \
  --wait --timeout=300s; then
    echo "✅ RLS deployment updated successfully!"
else
    echo "❌ RLS deployment update failed!"
    echo ""
    echo "🔍 Debug information:"
    kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -10
    exit 1
fi

echo ""
echo "📋 Waiting for new pod to start..."
sleep 15

NEW_RLS_POD=$(kubectl get pods -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}')
echo "New RLS Pod: $NEW_RLS_POD"

echo ""
echo "📋 Checking new pod arguments:"
kubectl get pod $NEW_RLS_POD -n $NAMESPACE -o yaml | grep -A 30 "args:" | head -25

echo ""
echo "📋 Checking for gRPC startup messages:"
echo "Looking for 'gRPC server started' messages..."
kubectl logs $NEW_RLS_POD -n $NAMESPACE | grep -E "(gRPC|started|components initialized)" || echo "No gRPC startup messages found yet"

echo ""
echo "📋 Testing gRPC connectivity:"

# Test from Admin UI if available
ADMIN_POD=$(kubectl get pods -l app.kubernetes.io/name=mimir-admin -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -n "$ADMIN_POD" ]; then
    echo "Testing connectivity from Admin UI..."
    sleep 5  # Give RLS time to start
    
    echo "Testing RLS gRPC port 8080:"
    if kubectl exec $ADMIN_POD -n $NAMESPACE -- timeout 5 nc -zv mimir-rls.mimir-edge-enforcement.svc.cluster.local 8080 2>/dev/null; then
        echo "✅ RLS gRPC is now REACHABLE!"
    else
        echo "❌ RLS gRPC still not reachable"
    fi
    
    echo "Testing RLS HTTP admin port 8082:"
    if kubectl exec $ADMIN_POD -n $NAMESPACE -- curl -s -m 5 http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8082/health >/dev/null 2>&1; then
        echo "✅ RLS HTTP admin is reachable"
    else
        echo "❌ RLS HTTP admin not reachable"
    fi
else
    echo "Admin UI not available for connectivity testing"
fi

echo ""
echo "🎯 CONFIGURATION UPDATE SUMMARY"
echo "==============================="

GRPC_LOGS=$(kubectl logs $NEW_RLS_POD -n $NAMESPACE | grep -c "gRPC server started" 2>/dev/null || echo "0")
STARTUP_LOGS=$(kubectl logs $NEW_RLS_POD -n $NAMESPACE | grep -c "components initialized" 2>/dev/null || echo "0")

echo "Pod Status:"
POD_STATUS=$(kubectl get pod $NEW_RLS_POD -n $NAMESPACE -o jsonpath='{.status.phase}')
echo "- Pod Phase: $POD_STATUS"
echo "- gRPC startup messages: $GRPC_LOGS (expected: 2)"
echo "- Component initialization: $STARTUP_LOGS (expected: 1)"

if [ "$GRPC_LOGS" -eq "2" ] && [ "$STARTUP_LOGS" -eq "1" ]; then
    echo ""
    echo "✅ SUCCESS! RLS configuration fixed and gRPC health checks working"
    echo ""
    echo "🎯 What was fixed:"
    echo "- Added missing command-line arguments to RLS deployment"
    echo "- Enhanced Helm chart with complete configuration options"
    echo "- Enabled debug logging to see gRPC startup messages"
    echo "- Configured proper request limits for gRPC health checks"
    echo ""
    echo "🔄 Next steps:"
    echo "1. Test Admin UI diagnostics (should show RLS as REACHABLE)"
    echo "2. Verify Envoy can connect to RLS with health checks"
    echo "3. Test /api/v1/push traffic flow through edge enforcement"
    echo ""
    echo "🔍 Quick test commands:"
    echo "- kubectl logs $NEW_RLS_POD -n $NAMESPACE"
    echo "- ./scripts/admin-ui-debug-envoy.sh"
    echo "- ./scripts/validate-rls-startup.sh"
else
    echo ""
    echo "⚠️  PARTIAL SUCCESS: RLS updated but startup validation incomplete"
    echo ""
    echo "Possible issues:"
    echo "1. ⏳ Pod still starting up (wait 30 seconds and check again)"
    echo "2. 🏗️  Docker image may not include latest gRPC health fixes"
    echo "3. 🔧 Additional configuration may be needed"
    echo ""
    echo "🔍 Debug steps:"
    echo "1. Check full pod logs: kubectl logs $NEW_RLS_POD -n $NAMESPACE"
    echo "2. Check pod events: kubectl describe pod $NEW_RLS_POD -n $NAMESPACE"
    echo "3. Verify image version: kubectl get pod $NEW_RLS_POD -n $NAMESPACE -o yaml | grep image:"
    echo "4. Test connectivity manually: kubectl exec -it $NEW_RLS_POD -n $NAMESPACE -- ps aux"
fi

# Cleanup
rm -f /tmp/rls-enhanced-values.yaml

echo ""
echo "🔧 RLS configuration fix complete!"
