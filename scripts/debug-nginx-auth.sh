#!/bin/bash

# 🔍 Debug NGINX Authentication Issues
# Helps diagnose 401 Unauthorized errors in NGINX logs

set -euo pipefail

# Configuration
NAMESPACE=${NAMESPACE:-mimir}
CONFIGMAP=${CONFIGMAP:-mimir-nginx}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

error() {
    echo -e "${RED}❌${NC} $1"
}

info() {
    echo -e "${PURPLE}ℹ️${NC} $1"
}

echo -e "${BLUE}🔍 NGINX Authentication Debugging${NC}"
echo -e "${BLUE}===================================${NC}"
echo

# 1. Check NGINX pods
log "📦 Checking NGINX Pods"
echo "-----------------------"

NGINX_PODS=$(kubectl get pods -l app=nginx -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [[ -n "$NGINX_PODS" ]]; then
    success "NGINX pods found: $NGINX_PODS"
    
    # Check pod status
    kubectl get pods -l app=nginx -n "$NAMESPACE" -o wide
else
    error "No NGINX pods found"
    echo "Check your pod selector label"
    exit 1
fi
echo

# 2. Check authentication configuration
log "🔐 Checking Authentication Configuration"
echo "----------------------------------------"

# Get NGINX config
NGINX_CONFIG=$(kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" -o jsonpath='{.data.nginx\.conf}' 2>/dev/null || echo "")

if [[ -n "$NGINX_CONFIG" ]]; then
    echo "🔍 Authentication settings in ConfigMap:"
    echo "$NGINX_CONFIG" | grep -A 2 -B 2 "auth_basic" || echo "No auth_basic found"
    echo
    echo "$NGINX_CONFIG" | grep -A 2 -B 2 "auth_basic_user_file" || echo "No auth_basic_user_file found"
    echo
else
    error "Could not retrieve NGINX configuration"
fi
echo

# 3. Check for .htpasswd secret
log "🗝️ Checking .htpasswd Secret"
echo "-----------------------------"

# Look for common secret names
SECRET_NAMES=("nginx-auth" "mimir-auth" "nginx-secrets" "mimir-nginx-auth")

FOUND_SECRET=""
for secret_name in "${SECRET_NAMES[@]}"; do
    if kubectl get secret "$secret_name" -n "$NAMESPACE" &>/dev/null; then
        FOUND_SECRET="$secret_name"
        break
    fi
done

if [[ -n "$FOUND_SECRET" ]]; then
    success "Found authentication secret: $FOUND_SECRET"
    
    echo "📄 Secret details:"
    kubectl describe secret "$FOUND_SECRET" -n "$NAMESPACE"
    echo
    
    # Check if .htpasswd key exists
    if kubectl get secret "$FOUND_SECRET" -n "$NAMESPACE" -o jsonpath='{.data}' | grep -q "htpasswd\|\.htpasswd"; then
        success "Secret contains .htpasswd data"
        
        # Show users (without passwords)
        echo "👥 Users in .htpasswd:"
        kubectl get secret "$FOUND_SECRET" -n "$NAMESPACE" -o jsonpath='{.data.\.htpasswd}' 2>/dev/null | base64 -d | cut -d: -f1 || \
        kubectl get secret "$FOUND_SECRET" -n "$NAMESPACE" -o jsonpath='{.data.htpasswd}' 2>/dev/null | base64 -d | cut -d: -f1 || \
        echo "Could not decode .htpasswd content"
    else
        warning "Secret exists but no .htpasswd key found"
        echo "Available keys:"
        kubectl get secret "$FOUND_SECRET" -n "$NAMESPACE" -o jsonpath='{.data}' | jq 'keys[]' 2>/dev/null || echo "Could not list keys"
    fi
else
    error "No authentication secret found"
    echo "Checked for secrets: ${SECRET_NAMES[*]}"
    echo
    echo "📝 Create authentication secret with:"
    echo "htpasswd -c auth tenant1"
    echo "kubectl create secret generic nginx-auth --from-file=.htpasswd=auth -n $NAMESPACE"
fi
echo

# 4. Check secret mount in pods
log "💾 Checking Secret Mount in NGINX Pods"
echo "---------------------------------------"

if [[ -n "$NGINX_PODS" ]]; then
    FIRST_POD=$(echo "$NGINX_PODS" | awk '{print $1}')
    
    echo "🔍 Checking volume mounts in pod: $FIRST_POD"
    kubectl describe pod "$FIRST_POD" -n "$NAMESPACE" | grep -A 10 -B 5 "Volume\|Mount" || echo "No volume information found"
    echo
    
    echo "📁 Checking if .htpasswd file exists in pod:"
    if kubectl exec "$FIRST_POD" -n "$NAMESPACE" -- test -f /etc/nginx/secrets/.htpasswd 2>/dev/null; then
        success ".htpasswd file exists at /etc/nginx/secrets/.htpasswd"
        
        echo "👥 Users in mounted .htpasswd:"
        kubectl exec "$FIRST_POD" -n "$NAMESPACE" -- cat /etc/nginx/secrets/.htpasswd 2>/dev/null | cut -d: -f1 || echo "Could not read file"
    else
        error ".htpasswd file not found at /etc/nginx/secrets/.htpasswd"
        
        echo "📁 Available files in /etc/nginx/secrets/:"
        kubectl exec "$FIRST_POD" -n "$NAMESPACE" -- ls -la /etc/nginx/secrets/ 2>/dev/null || echo "Directory not found"
        
        echo "📁 Available files in /etc/nginx/:"
        kubectl exec "$FIRST_POD" -n "$NAMESPACE" -- ls -la /etc/nginx/ 2>/dev/null || echo "Directory not found"
    fi
fi
echo

# 5. Analyze recent 401 errors
log "📊 Analyzing Recent 401 Errors"
echo "-------------------------------"

if [[ -n "$NGINX_PODS" ]]; then
    FIRST_POD=$(echo "$NGINX_PODS" | awk '{print $1}')
    
    echo "🔍 Recent 401 errors from NGINX logs:"
    kubectl logs "$FIRST_POD" -n "$NAMESPACE" --tail=50 | grep " 401 " | tail -10 || echo "No recent 401 errors found"
    echo
    
    echo "📈 401 error count in last 100 log lines:"
    ERROR_COUNT=$(kubectl logs "$FIRST_POD" -n "$NAMESPACE" --tail=100 | grep -c " 401 " || echo "0")
    echo "Total 401 errors: $ERROR_COUNT"
    
    if [[ "$ERROR_COUNT" -gt 0 ]]; then
        echo
        echo "🔍 Sample 401 request details:"
        kubectl logs "$FIRST_POD" -n "$NAMESPACE" --tail=100 | grep " 401 " | head -3
    fi
fi
echo

# 6. Test authentication
log "🧪 Authentication Test Suggestions"
echo "-----------------------------------"

echo "📝 Test authentication manually:"
echo
echo "1. Without credentials (should get 401):"
echo "   curl -X POST http://your-nginx:8080/api/v1/push"
echo
echo "2. With valid credentials:"
echo "   curl -X POST http://your-nginx:8080/api/v1/push \\"
echo "        -u 'tenant1:password' \\"
echo "        -H 'Content-Type: application/x-protobuf'"
echo
echo "3. Check if credentials work:"
echo "   kubectl port-forward svc/nginx 8080:8080 -n $NAMESPACE &"
echo "   curl -u 'tenant1:password' http://localhost:8080/api/v1/push -v"
echo
echo "4. Test specific tenant:"
echo "   curl -u 'your-tenant-id:password' http://localhost:8080/api/v1/push -v"
echo

# 7. Common solutions
log "🔧 Common Solutions for 401 Errors"
echo "-----------------------------------"

echo "1. 📝 Create .htpasswd file:"
echo "   htpasswd -c auth tenant1"
echo "   # Enter password when prompted"
echo
echo "2. 🗝️ Create Kubernetes secret:"
echo "   kubectl create secret generic nginx-auth \\"
echo "     --from-file=.htpasswd=auth -n $NAMESPACE"
echo
echo "3. 💾 Mount secret in NGINX deployment:"
echo "   # Add to nginx deployment volumes:"
echo "   volumes:"
echo "   - name: nginx-auth"
echo "     secret:"
echo "       secretName: nginx-auth"
echo "   # Add to container volumeMounts:"
echo "   volumeMounts:"
echo "   - name: nginx-auth"
echo "     mountPath: /etc/nginx/secrets"
echo "     readOnly: true"
echo
echo "4. 🔄 Restart NGINX pods:"
echo "   kubectl rollout restart deployment/nginx -n $NAMESPACE"
echo

# 8. Summary
echo -e "${BLUE}📋 Summary${NC}"
echo "==========="

if [[ -n "$FOUND_SECRET" ]]; then
    success "Authentication secret exists: $FOUND_SECRET"
else
    error "No authentication secret found - this is likely the cause"
fi

if kubectl exec "$FIRST_POD" -n "$NAMESPACE" -- test -f /etc/nginx/secrets/.htpasswd 2>/dev/null; then
    success ".htpasswd file is mounted in NGINX pod"
else
    error ".htpasswd file not found in NGINX pod - check secret mount"
fi

echo
warning "💡 Most common cause: Missing or incorrectly mounted .htpasswd secret"
echo
info "🔧 Quick fix if secret is missing:"
echo "   1. Create .htpasswd: htpasswd -c auth tenant1"
echo "   2. Create secret: kubectl create secret generic nginx-auth --from-file=.htpasswd=auth -n $NAMESPACE"
echo "   3. Update deployment to mount secret at /etc/nginx/secrets/"
echo "   4. Restart NGINX pods"
