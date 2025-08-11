#!/bin/bash

# Fix overrides-sync deployment by deleting existing resources and redeploying
set -e

NAMESPACE="mimir-edge-enforcement"
RELEASE_NAME="mimir-overrides-sync"

echo "🔧 Fixing overrides-sync deployment..."

# Check if namespace exists
if ! kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
    echo "❌ Namespace $NAMESPACE does not exist"
    exit 1
fi

echo "📋 Current resources in namespace $NAMESPACE:"
kubectl get all -n $NAMESPACE -l app.kubernetes.io/name=overrides-sync

echo "🗑️  Deleting existing overrides-sync resources..."

# Delete deployment
kubectl delete deployment $RELEASE_NAME -n $NAMESPACE --ignore-not-found=true

# Delete service
kubectl delete service $RELEASE_NAME -n $NAMESPACE --ignore-not-found=true

# Delete service account
kubectl delete serviceaccount $RELEASE_NAME -n $NAMESPACE --ignore-not-found=true

# Delete role and role binding
kubectl delete role $RELEASE_NAME -n mimir --ignore-not-found=true
kubectl delete rolebinding $RELEASE_NAME -n mimir --ignore-not-found=true

# Delete service monitor
kubectl delete servicemonitor $RELEASE_NAME -n $NAMESPACE --ignore-not-found=true

# Delete pod disruption budget
kubectl delete poddisruptionbudget $RELEASE_NAME -n $NAMESPACE --ignore-not-found=true

echo "⏳ Waiting for resources to be deleted..."
sleep 5

echo "🚀 Deploying overrides-sync with fixed configuration..."

# Deploy with the fixed configuration
helm upgrade --install $RELEASE_NAME charts/overrides-sync \
  --namespace $NAMESPACE \
  --values values-overrides-sync.yaml \
  --wait \
  --timeout 5m

echo "✅ Deployment completed!"

echo "📊 Checking deployment status..."
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=overrides-sync

echo "🔍 Checking service configuration..."
kubectl get service $RELEASE_NAME -n $NAMESPACE -o yaml | grep -A 10 "ports:"

echo "🎉 Overrides-sync deployment fixed successfully!"
