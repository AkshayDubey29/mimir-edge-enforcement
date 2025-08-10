#!/bin/bash

# 🎯 Apply NGINX 10% Canary Configuration
# ========================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🎯 Applying NGINX 10% Canary Configuration${NC}"
echo "============================================="
echo ""
echo -e "${YELLOW}⚠️  WARNING: This will enable 10% traffic routing through edge enforcement${NC}"
echo -e "${YELLOW}Make sure edge enforcement is deployed and ready before proceeding${NC}"
echo ""

# Confirm before proceeding
read -p "Are you sure you want to enable 10% canary routing? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Operation cancelled${NC}"
    exit 0
fi

# Backup current configuration
echo -e "${BLUE}[$(date +%H:%M:%S)] 💾 Backing up current NGINX configuration${NC}"
echo "------------------------"
kubectl get configmap mimir-nginx -n mimir -o yaml > backup-mimir-nginx-$(date +%Y%m%d-%H%M%S).yaml
echo -e "${GREEN}✅ Backup saved${NC}"
echo ""

# Check if edge enforcement is ready
echo -e "${BLUE}[$(date +%H:%M:%S)] 🔍 Checking edge enforcement readiness${NC}"
echo "------------------------"

# Check if edge enforcement namespace exists
if ! kubectl get namespace mimir-edge-enforcement >/dev/null 2>&1; then
    echo -e "${RED}❌ Edge enforcement namespace not found${NC}"
    echo "Please deploy edge enforcement first:"
    echo "helm install mimir-edge-enforcement ./charts/ -n mimir-edge-enforcement"
    exit 1
fi

# Check if Envoy service is ready
if ! kubectl get svc mimir-envoy -n mimir-edge-enforcement >/dev/null 2>&1; then
    echo -e "${RED}❌ Envoy service not found in edge enforcement${NC}"
    echo "Please ensure edge enforcement is properly deployed"
    exit 1
fi

# Check if Envoy pods are ready
ENVOY_PODS=$(kubectl get pods -n mimir-edge-enforcement -l app.kubernetes.io/name=mimir-envoy --no-headers -o custom-columns=":metadata.name" 2>/dev/null || true)
if [ -z "$ENVOY_PODS" ]; then
    echo -e "${RED}❌ No Envoy pods found in edge enforcement${NC}"
    echo "Please ensure edge enforcement is properly deployed"
    exit 1
fi

echo -e "${GREEN}✅ Edge enforcement appears to be ready${NC}"
echo ""

# Apply the canary configuration
echo -e "${BLUE}[$(date +%H:%M:%S)] 🎯 Applying 10% canary configuration${NC}"
echo "------------------------"
kubectl apply -f examples/nginx-10-percent-canary.yaml
echo -e "${GREEN}✅ Clean 10% canary configuration applied${NC}"
echo ""

# Restart NGINX deployment
echo -e "${BLUE}[$(date +%H:%M:%S)] 🔄 Restarting NGINX deployment${NC}"
echo "------------------------"
kubectl rollout restart deployment -n mimir -l app=nginx
echo -e "${GREEN}✅ NGINX deployment restarted${NC}"
echo ""

# Wait for rollout
echo -e "${BLUE}[$(date +%H:%M:%S)] ⏳ Waiting for rollout to complete${NC}"
echo "------------------------"
kubectl rollout status deployment -n mimir -l app=nginx --timeout=300s
echo -e "${GREEN}✅ Rollout completed${NC}"
echo ""

# Verify the configuration
echo -e "${BLUE}[$(date +%H:%M:%S)] ✅ Verifying the configuration${NC}"
echo "------------------------"
NGINX_POD=$(kubectl get pods -n mimir -l app=nginx --no-headers -o custom-columns=":metadata.name" | head -1)

if [ ! -z "$NGINX_POD" ]; then
    echo "Checking canary routing configuration in pod: $NGINX_POD"
    
    # Check if canary routing is configured
    kubectl exec -n mimir $NGINX_POD -- grep -q "route_decision" /etc/nginx/nginx.conf && {
        echo -e "${GREEN}✅ Canary routing configured${NC}"
    } || {
        echo -e "${RED}❌ Canary routing not found${NC}"
    }
    
    # Check if Authorization header forwarding is configured
    kubectl exec -n mimir $NGINX_POD -- grep -q "proxy_set_header Authorization" /etc/nginx/nginx.conf && {
        echo -e "${GREEN}✅ Authorization header forwarding configured${NC}"
    } || {
        echo -e "${RED}❌ Authorization header forwarding not found${NC}"
    }
    
    # Check NGINX configuration syntax
    kubectl exec -n mimir $NGINX_POD -- nginx -t && {
        echo -e "${GREEN}✅ NGINX configuration syntax is valid${NC}"
    } || {
        echo -e "${RED}❌ NGINX configuration syntax error${NC}"
    }
else
    echo -e "${YELLOW}⚠️  No NGINX pod found for verification${NC}"
fi

echo ""
echo -e "${GREEN}✅ 10% canary configuration applied successfully!${NC}"
echo ""
echo -e "${YELLOW}Key changes made:${NC}"
echo "1. ✅ Added 10% canary routing (requests ending in '0' go to edge enforcement)"
echo "2. ✅ Added Authorization header forwarding to all proxy routes"
echo "3. ✅ Added observability headers for monitoring canary decisions"
echo "4. ✅ Added emergency endpoints for testing and rollback"
echo ""
echo -e "${YELLOW}Traffic distribution:${NC}"
echo "• 90% of requests → Direct to Mimir Distributor"
echo "• 10% of requests → Through Edge Enforcement (Envoy → RLS → Mimir)"
echo ""
echo -e "${YELLOW}Monitoring:${NC}"
echo "• Check NGINX logs: kubectl logs -f deployment/nginx -n mimir | grep route=edge"
echo "• Check Envoy logs: kubectl logs -f deployment/mimir-envoy -n mimir-edge-enforcement"
echo "• Check RLS logs: kubectl logs -f deployment/mimir-rls -n mimir-edge-enforcement"
echo ""
echo -e "${YELLOW}Testing endpoints:${NC}"
echo "• Force direct: curl -u username:password http://nginx-service/api/v1/push/direct"
echo "• Force edge: curl -u username:password http://nginx-service/api/v1/push/edge"
echo ""
echo -e "${YELLOW}To rollback if needed:${NC}"
echo "kubectl apply -f backup-mimir-nginx-YYYYMMDD-HHMMSS.yaml"
echo "kubectl rollout restart deployment -n mimir -l app=nginx"
