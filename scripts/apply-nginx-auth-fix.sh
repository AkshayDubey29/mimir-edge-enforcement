#!/bin/bash

# 🔧 Apply NGINX Authorization Header Fix
# ======================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Applying NGINX Authorization Header Fix${NC}"
echo "============================================="
echo ""

# Backup current configuration
echo -e "${BLUE}[$(date +%H:%M:%S)] 💾 Backing up current NGINX configuration${NC}"
echo "------------------------"
kubectl get configmap mimir-nginx -n mimir -o yaml > backup-mimir-nginx-$(date +%Y%m%d-%H%M%S).yaml
echo -e "${GREEN}✅ Backup saved${NC}"
echo ""

# Apply the fix
echo -e "${BLUE}[$(date +%H:%M:%S)] 🔧 Applying Authorization header fix${NC}"
echo "------------------------"
kubectl apply -f examples/nginx-10-percent-canary.yaml
echo -e "${GREEN}✅ ConfigMap updated with 10% canary + auth fix${NC}"
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

# Verify the fix
echo -e "${BLUE}[$(date +%H:%M:%S)] ✅ Verifying the fix${NC}"
echo "------------------------"
NGINX_POD=$(kubectl get pods -n mimir -l app=nginx --no-headers -o custom-columns=":metadata.name" | head -1)

if [ ! -z "$NGINX_POD" ]; then
    echo "Checking Authorization header forwarding in pod: $NGINX_POD"
    
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
echo -e "${GREEN}✅ NGINX Authorization header fix applied!${NC}"
echo ""
echo -e "${YELLOW}Key changes made:${NC}"
echo "1. ✅ Added Authorization header forwarding to all proxy routes"
echo "2. ✅ Ensured auth headers are preserved in canary routing"
echo "3. ✅ Maintained existing authentication configuration"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Test with valid credentials"
echo "2. Monitor NGINX logs for 401 errors"
echo "3. Verify canary routing works with authentication"
echo "4. Check that route=edge traffic no longer gets 401 errors"
echo ""
echo -e "${YELLOW}To rollback if needed:${NC}"
echo "kubectl apply -f backup-mimir-nginx-YYYYMMDD-HHMMSS.yaml"
