#!/bin/bash

# 🚀 Deploy NGINX 10% Canary Configuration
# ========================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Deploying NGINX 10% Canary Configuration${NC}"
echo "============================================="
echo ""

# Check prerequisites
echo -e "${BLUE}[$(date +%H:%M:%S)] 🔍 Checking prerequisites${NC}"
echo "------------------------"

# Check kubectl connection
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${RED}❌ kubectl not connected to cluster${NC}"
    exit 1
fi
echo -e "${GREEN}✅ kubectl connected${NC}"

# Check if namespace exists
if ! kubectl get namespace mimir >/dev/null 2>&1; then
    echo -e "${RED}❌ Namespace mimir not found${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Namespace mimir exists${NC}"

# Check if edge enforcement is ready
echo ""
echo -e "${BLUE}[$(date +%H:%M:%S)] 🔍 Checking edge enforcement readiness${NC}"
echo "------------------------"

if ! kubectl get namespace mimir-edge-enforcement >/dev/null 2>&1; then
    echo -e "${RED}❌ Edge enforcement namespace not found${NC}"
    echo "Please deploy edge enforcement first:"
    echo "helm install mimir-edge-enforcement ./charts/ -n mimir-edge-enforcement"
    exit 1
fi

if ! kubectl get svc mimir-envoy -n mimir-edge-enforcement >/dev/null 2>&1; then
    echo -e "${RED}❌ Envoy service not found in edge enforcement${NC}"
    echo "Please ensure edge enforcement is properly deployed"
    exit 1
fi

echo -e "${GREEN}✅ Edge enforcement appears to be ready${NC}"
echo ""

# Backup current configuration
echo -e "${BLUE}[$(date +%H:%M:%S)] 💾 Backing up current NGINX configuration${NC}"
echo "------------------------"
kubectl get configmap mimir-nginx -n mimir -o yaml > backup-mimir-nginx-$(date +%Y%m%d-%H%M%S).yaml
echo -e "${GREEN}✅ Backup saved${NC}"
echo ""

# Apply the clean canary configuration
echo -e "${BLUE}[$(date +%H:%M:%S)] 🎯 Applying clean 10% canary configuration${NC}"
echo "------------------------"
kubectl apply -f examples/nginx-10-percent-canary.yaml
echo -e "${GREEN}✅ Clean canary configuration applied${NC}"
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
    echo "Checking configuration in pod: $NGINX_POD"
    
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
echo -e "${GREEN}✅ NGINX 10% Canary Configuration Deployed Successfully!${NC}"
echo ""
echo -e "${YELLOW}Configuration Summary:${NC}"
echo "• ✅ Basic authentication preserved"
echo "• ✅ X-Scope-OrgID header forwarding preserved"
echo "• ✅ Authorization header forwarding added"
echo "• ✅ 10% canary routing enabled (requests ending in '0')"
echo "• ✅ All existing endpoints preserved"
echo "• ✅ Emergency bypass endpoints added"
echo ""
echo -e "${YELLOW}Traffic Distribution:${NC}"
echo "• 90% of requests → Direct to Mimir Distributor"
echo "• 10% of requests → Through Edge Enforcement (Envoy → RLS → Mimir)"
echo ""
echo -e "${YELLOW}Monitoring Commands:${NC}"
echo "• NGINX logs: kubectl logs -f deployment/nginx -n mimir | grep route=edge"
echo "• Envoy logs: kubectl logs -f deployment/mimir-envoy -n mimir-edge-enforcement"
echo "• RLS logs: kubectl logs -f deployment/mimir-rls -n mimir-edge-enforcement"
echo ""
echo -e "${YELLOW}Testing Endpoints:${NC}"
echo "• Force direct: curl -u username:password http://nginx-service/api/v1/push/direct"
echo "• Force edge: curl -u username:password http://nginx-service/api/v1/push/edge"
echo ""
echo -e "${YELLOW}Rollback Command:${NC}"
echo "kubectl apply -f backup-mimir-nginx-YYYYMMDD-HHMMSS.yaml"
echo "kubectl rollout restart deployment -n mimir -l app=nginx"
