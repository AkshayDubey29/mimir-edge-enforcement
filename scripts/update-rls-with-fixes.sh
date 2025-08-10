#!/bin/bash

# 🔧 Update RLS Deployment with gRPC Health Check Fixes
echo "🔧 Updating RLS Deployment with gRPC Health Check Fixes"
echo "======================================================="

NAMESPACE="mimir-edge-enforcement"
COMMIT_SHA=$(git rev-parse HEAD)

echo "📋 Current status:"
echo "- Current commit: $COMMIT_SHA"
echo "- Namespace: $NAMESPACE"

# Function to check if image exists
check_image_exists() {
    local image_tag=$1
    echo "🔍 Checking if image exists: $image_tag"
    
    # Try to pull the image (this checks if it exists without actually pulling)
    if docker manifest inspect "$image_tag" >/dev/null 2>&1; then
        echo "✅ Image exists: $image_tag"
        return 0
    else
        echo "❌ Image not found: $image_tag"
        return 1
    fi
}

echo ""
echo "📋 STEP 1: Check if new RLS image with fixes is available"
echo "---------------------------------------------------------"

NEW_IMAGE="ghcr.io/akshaydubey29/mimir-rls:$COMMIT_SHA"
LATEST_IMAGE="ghcr.io/akshaydubey29/mimir-rls:latest"

echo "Checking for images with our gRPC health fixes..."

if check_image_exists "$NEW_IMAGE"; then
    TARGET_IMAGE="$NEW_IMAGE"
    echo "✅ Using commit-specific image: $TARGET_IMAGE"
elif check_image_exists "$LATEST_IMAGE"; then
    TARGET_IMAGE="$LATEST_IMAGE"
    echo "✅ Using latest image: $TARGET_IMAGE"
    echo "⚠️  Note: This may not include the very latest fixes"
else
    echo ""
    echo "❌ NEW RLS IMAGES NOT YET AVAILABLE"
    echo "====================================="
    echo ""
    echo "The GitHub Actions build is likely still in progress."
    echo "Our gRPC health check fixes were just pushed, and the Docker images"
    echo "are being built automatically."
    echo ""
    echo "OPTIONS:"
    echo "1. ⏰ WAIT FOR AUTOMATIC BUILD (recommended):"
    echo "   - Check GitHub Actions: https://github.com/AkshayDubey29/mimir-edge-enforcement/actions"
    echo "   - Wait 5-10 minutes for build to complete"
    echo "   - Run this script again: ./scripts/update-rls-with-fixes.sh"
    echo ""
    echo "2. 🔧 MANUAL BUILD (if urgent):"
    echo "   - cd services/rls"
    echo "   - docker build -t temp-rls-fix ."
    echo "   - Use local image for testing"
    echo ""
    echo "3. 🚀 FORCE UPDATE WITH CURRENT LATEST (may not have fixes):"
    echo "   - helm upgrade mimir-rls charts/mimir-rls --namespace $NAMESPACE --set image.tag=latest --force"
    echo ""
    echo "✋ STOPPING HERE - Please choose an option above"
    exit 1
fi

echo ""
echo "📋 STEP 2: Update RLS Helm deployment with new image"
echo "----------------------------------------------------"

echo "Updating RLS deployment to use: $TARGET_IMAGE"

# Extract the tag from the target image
IMAGE_TAG=$(echo "$TARGET_IMAGE" | cut -d':' -f2)

echo "Helm upgrade command:"
echo "helm upgrade mimir-rls charts/mimir-rls \\"
echo "  --namespace $NAMESPACE \\"
echo "  --set image.tag=$IMAGE_TAG \\"
echo "  --wait --timeout=300s"

echo ""
read -p "Proceed with deployment update? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deployment update cancelled"
    exit 1
fi

echo "🚀 Updating RLS deployment..."
if helm upgrade mimir-rls charts/mimir-rls \
  --namespace $NAMESPACE \
  --set image.tag=$IMAGE_TAG \
  --wait --timeout=300s; then
    echo "✅ RLS deployment updated successfully!"
else
    echo "❌ RLS deployment update failed!"
    exit 1
fi

echo ""
echo "📋 STEP 3: Verify deployment with new image"
echo "-------------------------------------------"

echo "Waiting for new pod to start..."
sleep 10

RLS_POD=$(kubectl get pods -l app.kubernetes.io/name=mimir-rls -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}')
echo "New RLS Pod: $RLS_POD"

echo ""
echo "Checking pod image:"
POD_IMAGE=$(kubectl get pod $RLS_POD -n $NAMESPACE -o jsonpath='{.spec.containers[0].image}')
echo "Pod Image: $POD_IMAGE"

if [[ "$POD_IMAGE" == *"$IMAGE_TAG"* ]]; then
    echo "✅ Pod is using correct image with tag: $IMAGE_TAG"
else
    echo "⚠️  Pod image mismatch. Expected tag: $IMAGE_TAG, Got: $POD_IMAGE"
fi

echo ""
echo "📋 STEP 4: Validate gRPC health check fixes"
echo "-------------------------------------------"

echo "Checking for gRPC health check startup messages:"
kubectl logs $RLS_POD -n $NAMESPACE | grep -E "(gRPC server started|health checks)" || echo "No gRPC health messages found yet"

echo ""
echo "Waiting for services to fully start..."
sleep 5

echo ""
echo "Testing gRPC connectivity from cluster:"

# Test from Admin UI if available
ADMIN_POD=$(kubectl get pods -l app.kubernetes.io/name=mimir-admin -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -n "$ADMIN_POD" ]; then
    echo "Testing RLS gRPC connectivity from Admin UI..."
    
    if kubectl exec $ADMIN_POD -n $NAMESPACE -- timeout 5 nc -zv mimir-rls.mimir-edge-enforcement.svc.cluster.local 8080 2>/dev/null; then
        echo "✅ RLS gRPC (port 8080) is now REACHABLE!"
    else
        echo "❌ RLS gRPC (port 8080) still NOT reachable"
    fi
    
    if kubectl exec $ADMIN_POD -n $NAMESPACE -- curl -s -m 5 http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8082/health >/dev/null 2>&1; then
        echo "✅ RLS HTTP admin (port 8082) is reachable"
    else
        echo "❌ RLS HTTP admin (port 8082) not reachable"
    fi
else
    echo "⚠️  Admin UI pod not found - skipping connectivity test"
fi

echo ""
echo "📋 UPDATE SUMMARY"
echo "================="

GRPC_LOGS=$(kubectl logs $RLS_POD -n $NAMESPACE | grep -c "gRPC server started" || echo "0")

if [ "$GRPC_LOGS" -eq "2" ]; then
    echo "✅ SUCCESS! RLS deployment updated with gRPC health check fixes"
    echo ""
    echo "🎯 What was fixed:"
    echo "- Added gRPC health check services for ext_authz and rate limit"
    echo "- Implemented graceful shutdown for gRPC servers"
    echo "- Enhanced startup logging and validation"
    echo "- Improved error handling"
    echo ""
    echo "🔄 Next steps:"
    echo "1. Test Envoy connectivity to RLS (should work now)"
    echo "2. Verify /api/v1/push requests flow through properly"
    echo "3. Check Admin UI shows traffic flow metrics"
    echo ""
    echo "🔍 Validation commands:"
    echo "- Check RLS logs: kubectl logs $RLS_POD -n $NAMESPACE"
    echo "- Run full diagnostic: ./scripts/validate-rls-startup.sh"
    echo "- Test Admin UI: (run diagnostics from UI)"
else
    echo "❌ ISSUE: Expected 2 'gRPC server started' messages, found: $GRPC_LOGS"
    echo ""
    echo "🔍 Troubleshooting:"
    echo "1. Check RLS pod logs: kubectl logs $RLS_POD -n $NAMESPACE"
    echo "2. Verify image tag: kubectl describe pod $RLS_POD -n $NAMESPACE | grep Image"
    echo "3. Check for build errors in GitHub Actions"
    echo "4. Consider manual rebuild if needed"
fi

echo ""
echo "🔧 RLS update process complete!"
