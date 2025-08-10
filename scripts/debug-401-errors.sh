#!/bin/bash

# 🔍 401 Authentication Error Debugging Script
# ============================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE=${1:-mimir}
EDGE_NAMESPACE=${2:-mimir-edge-enforcement}

echo -e "${BLUE}🔍 401 Authentication Error Debugging${NC}"
echo "============================================="
echo -e "${YELLOW}Namespace: ${NAMESPACE}${NC}"
echo -e "${YELLOW}Edge Namespace: ${EDGE_NAMESPACE}${NC}"
echo ""

# Function to check if kubectl is connected
check_kubectl() {
    echo -e "${BLUE}[$(date +%H:%M:%S)] 🔗 Checking kubectl connection${NC}"
    echo "------------------------"
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        echo -e "${RED}❌ kubectl not connected to cluster${NC}"
        echo "Please ensure:"
        echo "1. kubectl is installed and configured"
        echo "2. You have access to the cluster"
        echo "3. Run: kubectl config current-context"
        exit 1
    fi
    
    echo -e "${GREEN}✅ kubectl connected successfully${NC}"
    kubectl cluster-info | head -1
    echo ""
}

# Function to find NGINX pods
find_nginx_pods() {
    echo -e "${BLUE}[$(date +%H:%M:%S)] 📦 Finding NGINX pods${NC}"
    echo "------------------------"
    
    # Try different common NGINX selectors
    NGINX_PODS=""
    
    # Check for common NGINX labels
    for selector in "app=nginx" "app.kubernetes.io/name=nginx" "component=nginx" "name=nginx" "app=mimir-nginx"; do
        echo "Trying selector: $selector"
        PODS=$(kubectl get pods -n $NAMESPACE -l "$selector" --no-headers -o custom-columns=":metadata.name" 2>/dev/null || true)
        if [ ! -z "$PODS" ]; then
            NGINX_PODS="$PODS"
            echo -e "${GREEN}✅ Found NGINX pods with selector: $selector${NC}"
            break
        fi
    done
    
    # If still not found, try to find any pod with nginx in the name
    if [ -z "$NGINX_PODS" ]; then
        echo "Trying to find pods with 'nginx' in name..."
        NGINX_PODS=$(kubectl get pods -n $NAMESPACE --no-headers -o custom-columns=":metadata.name" | grep -i nginx || true)
        if [ ! -z "$NGINX_PODS" ]; then
            echo -e "${GREEN}✅ Found NGINX pods by name pattern${NC}"
        fi
    fi
    
    if [ -z "$NGINX_PODS" ]; then
        echo -e "${RED}❌ No NGINX pods found in namespace: $NAMESPACE${NC}"
        echo "Available pods:"
        kubectl get pods -n $NAMESPACE --no-headers -o custom-columns=":metadata.name" | head -10
        exit 1
    fi
    
    echo "NGINX pods found:"
    echo "$NGINX_PODS" | while read pod; do
        echo "  - $pod"
    done
    echo ""
}

# Function to check NGINX authentication configuration
check_nginx_auth() {
    echo -e "${BLUE}[$(date +%H:%M:%S)] 🔐 Checking NGINX authentication${NC}"
    echo "------------------------"
    
    NGINX_POD=$(echo "$NGINX_PODS" | head -1)
    
    echo "Checking NGINX configuration in pod: $NGINX_POD"
    
    # Check if .htpasswd secret exists
    echo "1. Checking .htpasswd secret..."
    if kubectl get secret nginx-auth -n $NAMESPACE >/dev/null 2>&1; then
        echo -e "${GREEN}✅ nginx-auth secret exists${NC}"
    else
        echo -e "${RED}❌ nginx-auth secret not found${NC}"
        echo "Available secrets:"
        kubectl get secrets -n $NAMESPACE | grep -E "(auth|passwd|nginx)" || echo "No auth-related secrets found"
    fi
    
    # Check NGINX configuration for auth
    echo ""
    echo "2. Checking NGINX configuration for auth directives..."
    kubectl exec -n $NAMESPACE $NGINX_POD -- cat /etc/nginx/nginx.conf 2>/dev/null | grep -A 5 -B 5 -E "(auth_basic|auth_basic_user_file|\.htpasswd)" || {
        echo -e "${YELLOW}⚠️  No auth directives found in NGINX config${NC}"
    }
    
    # Check if .htpasswd file is mounted
    echo ""
    echo "3. Checking if .htpasswd is mounted..."
    kubectl exec -n $NAMESPACE $NGINX_POD -- ls -la /etc/nginx/.htpasswd 2>/dev/null && {
        echo -e "${GREEN}✅ .htpasswd file is mounted${NC}"
        echo "File contents (first line):"
        kubectl exec -n $NAMESPACE $NGINX_POD -- head -1 /etc/nginx/.htpasswd 2>/dev/null || echo "Cannot read .htpasswd"
    } || {
        echo -e "${RED}❌ .htpasswd file not mounted${NC}"
    }
    
    echo ""
}

# Function to check recent 401 errors
check_401_errors() {
    echo -e "${BLUE}[$(date +%H:%M:%S)] 🚨 Checking recent 401 errors${NC}"
    echo "------------------------"
    
    NGINX_POD=$(echo "$NGINX_PODS" | head -1)
    
    echo "Recent NGINX logs with 401 errors:"
    kubectl logs -n $NAMESPACE $NGINX_POD --tail=50 2>/dev/null | grep -E "(401|Unauthorized|route=edge)" || {
        echo -e "${YELLOW}⚠️  No recent 401 errors found in logs${NC}"
    }
    
    echo ""
    echo "Recent NGINX logs with route=edge:"
    kubectl logs -n $NAMESPACE $NGINX_POD --tail=20 2>/dev/null | grep "route=edge" || {
        echo -e "${YELLOW}⚠️  No route=edge entries found in logs${NC}"
    }
    
    echo ""
}

# Function to check edge enforcement components
check_edge_components() {
    echo -e "${BLUE}[$(date +%H:%M:%S)] 🛡️ Checking edge enforcement components${NC}"
    echo "------------------------"
    
    echo "1. Checking edge enforcement namespace..."
    if kubectl get namespace $EDGE_NAMESPACE >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Edge enforcement namespace exists${NC}"
    else
        echo -e "${RED}❌ Edge enforcement namespace not found: $EDGE_NAMESPACE${NC}"
        return
    fi
    
    echo ""
    echo "2. Checking edge enforcement pods..."
    kubectl get pods -n $EDGE_NAMESPACE --no-headers -o custom-columns=":metadata.name,:status.phase" || {
        echo -e "${RED}❌ No pods found in edge enforcement namespace${NC}"
        return
    }
    
    echo ""
    echo "3. Checking Envoy service..."
    if kubectl get svc -n $EDGE_NAMESPACE | grep -q envoy; then
        echo -e "${GREEN}✅ Envoy service exists${NC}"
        kubectl get svc -n $EDGE_NAMESPACE | grep envoy
    else
        echo -e "${RED}❌ Envoy service not found${NC}"
    fi
    
    echo ""
    echo "4. Checking RLS service..."
    if kubectl get svc -n $EDGE_NAMESPACE | grep -q rls; then
        echo -e "${GREEN}✅ RLS service exists${NC}"
        kubectl get svc -n $EDGE_NAMESPACE | grep rls
    else
        echo -e "${RED}❌ RLS service not found${NC}"
    fi
    
    echo ""
}

# Function to test authentication
test_auth() {
    echo -e "${BLUE}[$(date +%H:%M:%S)] 🧪 Testing authentication${NC}"
    echo "------------------------"
    
    # Get NGINX service
    NGINX_SVC=$(kubectl get svc -n $NAMESPACE | grep -E "(nginx|ingress)" | head -1 | awk '{print $1}')
    
    if [ -z "$NGINX_SVC" ]; then
        echo -e "${RED}❌ No NGINX service found${NC}"
        return
    fi
    
    echo "Testing authentication with service: $NGINX_SVC"
    
    # Test without auth (should get 401)
    echo "1. Testing without authentication (should get 401):"
    kubectl run test-401 --rm -i --restart=Never --image=curlimages/curl -- \
        curl -s -w "HTTP %{http_code}\n" -o /dev/null \
        http://$NGINX_SVC.$NAMESPACE.svc.cluster.local/api/v1/push || true
    
    echo ""
    echo "2. Testing with basic auth (if credentials available):"
    echo "Note: You'll need to provide valid credentials for this test"
    echo "Example: curl -u username:password http://service/api/v1/push"
    
    echo ""
}

# Function to provide solutions
provide_solutions() {
    echo -e "${BLUE}[$(date +%H:%M:%S)] 💡 Solutions for 401 errors${NC}"
    echo "------------------------"
    
    echo -e "${YELLOW}Common causes and solutions:${NC}"
    echo ""
    echo "1. ${BLUE}Missing .htpasswd secret:${NC}"
    echo "   kubectl create secret generic nginx-auth -n $NAMESPACE \\"
    echo "     --from-file=.htpasswd=/path/to/.htpasswd"
    echo ""
    echo "2. ${BLUE}NGINX config not mounting .htpasswd:${NC}"
    echo "   Add to NGINX ConfigMap:"
    echo "   auth_basic 'Restricted Access';"
    echo "   auth_basic_user_file /etc/nginx/.htpasswd;"
    echo ""
    echo "3. ${BLUE}Wrong credentials being sent:${NC}"
    echo "   Check client is sending correct Authorization header"
    echo "   Format: Authorization: Basic <base64(username:password)>"
    echo ""
    echo "4. ${BLUE}Edge enforcement bypassing auth:${NC}"
    echo "   Ensure NGINX canary config preserves auth headers"
    echo "   Add: proxy_set_header Authorization \$http_authorization;"
    echo ""
    echo "5. ${BLUE}Test with direct Mimir access:${NC}"
    echo "   kubectl port-forward svc/distributor 8080:8080 -n mimir"
    echo "   curl -u username:password http://localhost:8080/api/v1/push"
    echo ""
}

# Main execution
main() {
    check_kubectl
    find_nginx_pods
    check_nginx_auth
    check_401_errors
    check_edge_components
    test_auth
    provide_solutions
    
    echo -e "${GREEN}✅ 401 debugging complete!${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Check the solutions above"
    echo "2. Verify NGINX configuration"
    echo "3. Test authentication manually"
    echo "4. Check if auth headers are preserved in canary routing"
}

# Run main function
main "$@"
