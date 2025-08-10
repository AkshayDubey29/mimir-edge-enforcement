#!/bin/bash

# 🔧 Fix 4e+06 Scientific Notation Error Script
# This script forces the correct maxRequestBytes value and restarts the deployment

set -e

NAMESPACE="mimir-edge-enforcement"
RELEASE_NAME="mimir-rls"

echo "🔧 Fixing 4e+06 scientific notation error..."

# Create a temporary values file with the correct values
cat > /tmp/fix-4e06-values.yaml << 'EOF'
# Fixed values to resolve 4e+06 scientific notation error
limits:
  maxRequestBytes: 4000000  # Fixed: Use 4000000 instead of 4194304
  maxBodyBytes: 0
  failureModeAllow: false
  defaultSamplesPerSecond: 0
  defaultBurstPercent: 0
  enforceBodyParsing: true
  defaultMaxLabelsPerSeries: 60
  defaultMaxLabelValueLength: 2048
  defaultMaxSeriesPerRequest: 100000

# Force latest image
image:
  tag: "latest"
  pullPolicy: Always

# Ensure proper service configuration
service:
  type: ClusterIP
  ports:
    extAuthz: 8080
    rateLimit: 8081
    admin: 8082
    metrics: 9090

# Tenant configuration
tenantHeader: "X-Scope-OrgID"

# Logging
log:
  level: "info"

# Resources
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 200m
    memory: 256Mi
EOF

echo "📋 Created fixed values file: /tmp/fix-4e06-values.yaml"

# Check current deployment
echo ""
echo "📋 Current deployment status:"
kubectl get deployment $RELEASE_NAME -n $NAMESPACE

echo ""
echo "📋 Current pod arguments (showing the problematic value):"
kubectl get deployment $RELEASE_NAME -n $NAMESPACE -o yaml | grep -A 20 "args:" | grep "max-request-bytes"

echo ""
echo "🚀 Upgrading Helm release with fixed values..."

# Upgrade the Helm release with the fixed values
if helm upgrade $RELEASE_NAME charts/mimir-rls \
  --namespace $NAMESPACE \
  --values /tmp/fix-4e06-values.yaml \
  --wait --timeout=300s; then
    echo "✅ Helm upgrade successful!"
else
    echo "❌ Helm upgrade failed!"
    echo ""
    echo "🔍 Trying alternative approach..."
    
    # Alternative: Delete and reinstall
    echo "🗑️  Uninstalling current release..."
    helm uninstall $RELEASE_NAME -n $NAMESPACE --wait
    
    echo "🚀 Installing with fixed values..."
    helm install $RELEASE_NAME charts/mimir-rls \
      --namespace $NAMESPACE \
      --values /tmp/fix-4e06-values.yaml \
      --wait --timeout=300s
fi

echo ""
echo "📋 Waiting for new pod to start..."
sleep 10

# Force restart to ensure new image is used
echo "🔄 Forcing deployment restart..."
kubectl rollout restart deployment/$RELEASE_NAME -n $NAMESPACE

echo ""
echo "📋 Waiting for rollout to complete..."
kubectl rollout status deployment/$RELEASE_NAME -n $NAMESPACE

echo ""
echo "📋 Verifying new pod arguments:"
kubectl get deployment $RELEASE_NAME -n $NAMESPACE -o yaml | grep -A 20 "args:" | grep "max-request-bytes"

echo ""
echo "📋 Checking pod logs for 4e+06 error:"
NEW_POD=$(kubectl get pods -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}')
echo "New pod: $NEW_POD"

# Wait a bit for logs to appear
sleep 5

# Check for the error
if kubectl logs $NEW_POD -n $NAMESPACE 2>&1 | grep -q "4e+06"; then
    echo "❌ Still seeing 4e+06 error in logs!"
    echo "🔍 Full pod logs:"
    kubectl logs $NEW_POD -n $NAMESPACE
else
    echo "✅ No 4e+06 error found in logs!"
    echo "✅ 4e+06 error should be resolved!"
fi

echo ""
echo "🧹 Cleaning up temporary file..."
rm -f /tmp/fix-4e06-values.yaml

echo ""
echo "🎯 Fix complete! If you still see 4e+06 errors, check:"
echo "1. Are you using a custom values file with 4194304?"
echo "2. Is there a cached Helm release?"
echo "3. Run: kubectl get deployment $RELEASE_NAME -n $NAMESPACE -o yaml | grep -A 20 'args:'"
