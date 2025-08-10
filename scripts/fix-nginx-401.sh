#!/bin/bash

# 🔧 NGINX 401 Authentication Fix Script
# ======================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE=${1:-mimir}
CONFIGMAP_NAME=${2:-nginx-config-with-auth-fix}
BACKUP_FILE="backup-nginx-config-$(date +%Y%m%d-%H%M%S).yaml"

echo -e "${BLUE}🔧 NGINX 401 Authentication Fix${NC}"
echo "====================================="
echo -e "${YELLOW}Namespace: ${NAMESPACE}${NC}"
echo -e "${YELLOW}ConfigMap: ${CONFIGMAP_NAME}${NC}"
echo ""

# Function to check prerequisites
check_prerequisites() {
    echo -e "${BLUE}[$(date +%H:%M:%S)] 🔍 Checking prerequisites${NC}"
    echo "------------------------"
    
    # Check kubectl connection
    if ! kubectl cluster-info >/dev/null 2>&1; then
        echo -e "${RED}❌ kubectl not connected to cluster${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ kubectl connected${NC}"
    
    # Check if namespace exists
    if ! kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
        echo -e "${RED}❌ Namespace $NAMESPACE not found${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Namespace $NAMESPACE exists${NC}"
    
    # Check if .htpasswd secret exists
    if ! kubectl get secret nginx-auth -n $NAMESPACE >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  nginx-auth secret not found${NC}"
        echo "You may need to create it:"
        echo "kubectl create secret generic nginx-auth -n $NAMESPACE --from-file=.htpasswd=/path/to/.htpasswd"
    else
        echo -e "${GREEN}✅ nginx-auth secret exists${NC}"
    fi
    
    echo ""
}

# Function to backup current configuration
backup_config() {
    echo -e "${BLUE}[$(date +%H:%M:%S)] 💾 Backing up current configuration${NC}"
    echo "------------------------"
    
    # Find current NGINX ConfigMap
    CURRENT_CONFIGMAP=$(kubectl get configmap -n $NAMESPACE --no-headers -o custom-columns=":metadata.name" | grep -E "(nginx|config)" | head -1)
    
    if [ -z "$CURRENT_CONFIGMAP" ]; then
        echo -e "${YELLOW}⚠️  No existing NGINX ConfigMap found${NC}"
        return
    fi
    
    echo "Found current ConfigMap: $CURRENT_CONFIGMAP"
    
    # Backup current ConfigMap
    kubectl get configmap $CURRENT_CONFIGMAP -n $NAMESPACE -o yaml > $BACKUP_FILE
    echo -e "${GREEN}✅ Backup saved to: $BACKUP_FILE${NC}"
    echo ""
}

# Function to apply the fix
apply_fix() {
    echo -e "${BLUE}[$(date +%H:%M:%S)] 🔧 Applying 401 authentication fix${NC}"
    echo "------------------------"
    
    # Apply the fixed ConfigMap
    echo "Applying ConfigMap with Authorization header fix..."
    kubectl apply -f examples/nginx-auth-header-fix.yaml
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ ConfigMap applied successfully${NC}"
    else
        echo -e "${RED}❌ Failed to apply ConfigMap${NC}"
        exit 1
    fi
    
    echo ""
}

# Function to update NGINX deployment
update_nginx_deployment() {
    echo -e "${BLUE}[$(date +%H:%M:%S)] 🔄 Updating NGINX deployment${NC}"
    echo "------------------------"
    
    # Find NGINX deployment
    NGINX_DEPLOYMENT=$(kubectl get deployment -n $NAMESPACE --no-headers -o custom-columns=":metadata.name" | grep -E "(nginx|ingress)" | head -1)
    
    if [ -z "$NGINX_DEPLOYMENT" ]; then
        echo -e "${YELLOW}⚠️  No NGINX deployment found${NC}"
        echo "You may need to manually update your NGINX deployment to use the new ConfigMap"
        return
    fi
    
    echo "Found NGINX deployment: $NGINX_DEPLOYMENT"
    
    # Update deployment to use new ConfigMap
    echo "Updating deployment to use new ConfigMap..."
    kubectl patch deployment $NGINX_DEPLOYMENT -n $NAMESPACE -p "{\"spec\":{\"template\":{\"spec\":{\"volumes\":[{\"name\":\"nginx-config\",\"configMap\":{\"name\":\"$CONFIGMAP_NAME\"}}]}}}}"
    
    # Restart deployment
    echo "Restarting NGINX deployment..."
    kubectl rollout restart deployment $NGINX_DEPLOYMENT -n $NAMESPACE
    
    # Wait for rollout
    echo "Waiting for rollout to complete..."
    kubectl rollout status deployment $NGINX_DEPLOYMENT -n $NAMESPACE --timeout=300s
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ NGINX deployment updated successfully${NC}"
    else
        echo -e "${RED}❌ Failed to update NGINX deployment${NC}"
        exit 1
    fi
    
    echo ""
}

# Function to verify the fix
verify_fix() {
    echo -e "${BLUE}[$(date +%H:%M:%S)] ✅ Verifying the fix${NC}"
    echo "------------------------"
    
    # Wait a moment for NGINX to reload
    sleep 5
    
    # Get NGINX pod
    NGINX_POD=$(kubectl get pods -n $NAMESPACE --no-headers -o custom-columns=":metadata.name" | grep -E "(nginx|ingress)" | head -1)
    
    if [ -z "$NGINX_POD" ]; then
        echo -e "${YELLOW}⚠️  No NGINX pod found for verification${NC}"
        return
    fi
    
    echo "Verifying configuration in pod: $NGINX_POD"
    
    # Check if Authorization header forwarding is configured
    echo "Checking for Authorization header forwarding..."
    kubectl exec -n $NAMESPACE $NGINX_POD -- grep -q "proxy_set_header Authorization" /etc/nginx/nginx.conf && {
        echo -e "${GREEN}✅ Authorization header forwarding configured${NC}"
    } || {
        echo -e "${RED}❌ Authorization header forwarding not found${NC}"
    }
    
    # Check NGINX configuration syntax
    echo "Checking NGINX configuration syntax..."
    kubectl exec -n $NAMESPACE $NGINX_POD -- nginx -t && {
        echo -e "${GREEN}✅ NGINX configuration syntax is valid${NC}"
    } || {
        echo -e "${RED}❌ NGINX configuration syntax error${NC}"
    }
    
    # Check NGINX process
    echo "Checking NGINX process status..."
    kubectl exec -n $NAMESPACE $NGINX_POD -- pgrep nginx >/dev/null && {
        echo -e "${GREEN}✅ NGINX process is running${NC}"
    } || {
        echo -e "${RED}❌ NGINX process not running${NC}"
    }
    
    echo ""
}

# Function to test the fix
test_fix() {
    echo -e "${BLUE}[$(date +%H:%M:%S)] 🧪 Testing the fix${NC}"
    echo "------------------------"
    
    # Get NGINX service
    NGINX_SVC=$(kubectl get svc -n $NAMESPACE | grep -E "(nginx|ingress)" | head -1 | awk '{print $1}')
    
    if [ -z "$NGINX_SVC" ]; then
        echo -e "${YELLOW}⚠️  No NGINX service found for testing${NC}"
        return
    fi
    
    echo "Testing with service: $NGINX_SVC"
    
    # Test health endpoint (should work without auth)
    echo "1. Testing health endpoint (no auth required):"
    kubectl run test-health --rm -i --restart=Never --image=curlimages/curl -- \
        curl -s -w "HTTP %{http_code}\n" -o /dev/null \
        http://$NGINX_SVC.$NAMESPACE.svc.cluster.local/health || true
    
    echo ""
    echo "2. Testing API endpoint (should require auth):"
    kubectl run test-api --rm -i --restart=Never --image=curlimages/curl -- \
        curl -s -w "HTTP %{http_code}\n" -o /dev/null \
        http://$NGINX_SVC.$NAMESPACE.svc.cluster.local/api/v1/push || true
    
    echo ""
    echo -e "${YELLOW}Note:${NC} The API endpoint should return 401 without authentication."
    echo "This is expected behavior. The fix ensures that when valid credentials"
    echo "are provided, the Authorization header is properly forwarded to Envoy."
    echo ""
}

# Function to provide manual steps
provide_manual_steps() {
    echo -e "${BLUE}[$(date +%H:%M:%S)] 📋 Manual steps if needed${NC}"
    echo "------------------------"
    
    echo -e "${YELLOW}If the automatic fix didn't work, try these manual steps:${NC}"
    echo ""
    echo "1. ${BLUE}Check your NGINX deployment:${NC}"
    echo "   kubectl get deployment -n $NAMESPACE"
    echo ""
    echo "2. ${BLUE}Update the ConfigMap volume mount:${NC}"
    echo "   kubectl edit deployment <nginx-deployment> -n $NAMESPACE"
    echo "   # Change the configMap name to: $CONFIGMAP_NAME"
    echo ""
    echo "3. ${BLUE}Verify .htpasswd secret exists:${NC}"
    echo "   kubectl get secret nginx-auth -n $NAMESPACE"
    echo ""
    echo "4. ${BLUE}Test with valid credentials:${NC}"
    echo "   curl -u username:password http://your-nginx-service/api/v1/push"
    echo ""
    echo "5. ${BLUE}Check NGINX logs for 401 errors:${NC}"
    echo "   kubectl logs -f deployment/<nginx-deployment> -n $NAMESPACE | grep 401"
    echo ""
}

# Function to rollback
rollback() {
    echo -e "${BLUE}[$(date +%H:%M:%S)] 🔄 Rollback instructions${NC}"
    echo "------------------------"
    
    if [ -f "$BACKUP_FILE" ]; then
        echo -e "${YELLOW}To rollback to previous configuration:${NC}"
        echo "kubectl apply -f $BACKUP_FILE"
        echo ""
    fi
    
    echo -e "${YELLOW}To remove the fixed ConfigMap:${NC}"
    echo "kubectl delete configmap $CONFIGMAP_NAME -n $NAMESPACE"
    echo ""
}

# Main execution
main() {
    check_prerequisites
    backup_config
    apply_fix
    update_nginx_deployment
    verify_fix
    test_fix
    provide_manual_steps
    rollback
    
    echo -e "${GREEN}✅ 401 authentication fix applied!${NC}"
    echo ""
    echo -e "${YELLOW}Key changes made:${NC}"
    echo "1. ✅ Added Authorization header forwarding to all proxy routes"
    echo "2. ✅ Ensured auth headers are preserved in canary routing"
    echo "3. ✅ Added emergency endpoints for testing"
    echo "4. ✅ Maintained existing authentication configuration"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Test with valid credentials"
    echo "2. Monitor NGINX logs for 401 errors"
    echo "3. Verify canary routing works with authentication"
    echo "4. Check that route=edge traffic no longer gets 401 errors"
}

# Run main function
main "$@"
