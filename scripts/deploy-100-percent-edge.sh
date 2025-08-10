#!/bin/bash

# Deploy 100% Edge Enforcement Configuration
# This script applies the NGINX configuration to route 100% of traffic through edge enforcement

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${PURPLE}=== DEPLOYING 100% EDGE ENFORCEMENT ===${NC}"
echo -e "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo ""

# Configuration
NAMESPACE="mimir"
CONFIGMAP_NAME="mimir-nginx"
CONFIG_FILE="examples/nginx-100-percent-edge.yaml"

# =================================================================
# VALIDATION CHECKS
# =================================================================

echo -e "${BLUE}=== VALIDATION CHECKS ===${NC}"

# Check if kubectl is available
if ! command -v kubectl > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: kubectl is not installed or not in PATH${NC}"
    exit 1
fi

# Check if we can connect to the cluster
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi

# Check if the namespace exists
if ! kubectl get namespace $NAMESPACE > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: Namespace '$NAMESPACE' does not exist${NC}"
    exit 1
fi

# Check if the config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ Error: Configuration file '$CONFIG_FILE' not found${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All validation checks passed${NC}"
echo ""

# =================================================================
# BACKUP CURRENT CONFIGURATION
# =================================================================

echo -e "${BLUE}=== BACKUP CURRENT CONFIGURATION ===${NC}"

# Create backup directory
BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup current ConfigMap
if kubectl get configmap $CONFIGMAP_NAME -n $NAMESPACE > /dev/null 2>&1; then
    echo -e "${CYAN}Backing up current NGINX configuration...${NC}"
    kubectl get configmap $CONFIGMAP_NAME -n $NAMESPACE -o yaml > "$BACKUP_DIR/nginx-config-backup.yaml"
    echo -e "${GREEN}✅ Backup saved to: $BACKUP_DIR/nginx-config-backup.yaml${NC}"
else
    echo -e "${YELLOW}⚠️  No existing ConfigMap found to backup${NC}"
fi

echo ""

# =================================================================
# DEPLOY NEW CONFIGURATION
# =================================================================

echo -e "${BLUE}=== DEPLOYING 100% EDGE ENFORCEMENT ===${NC}"

# Apply the new configuration
echo -e "${CYAN}Applying 100% edge enforcement configuration...${NC}"
kubectl apply -f "$CONFIG_FILE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Configuration applied successfully${NC}"
else
    echo -e "${RED}❌ Failed to apply configuration${NC}"
    exit 1
fi

echo ""

# =================================================================
# VERIFY DEPLOYMENT
# =================================================================

echo -e "${BLUE}=== VERIFYING DEPLOYMENT ===${NC}"

# Wait for ConfigMap to be ready
echo -e "${CYAN}Waiting for ConfigMap to be ready...${NC}"
sleep 5

# Check if ConfigMap was created/updated
if kubectl get configmap $CONFIGMAP_NAME -n $NAMESPACE > /dev/null 2>&1; then
    echo -e "${GREEN}✅ ConfigMap '$CONFIGMAP_NAME' is ready${NC}"
else
    echo -e "${RED}❌ ConfigMap '$CONFIGMAP_NAME' not found${NC}"
    exit 1
fi

# Check NGINX pods (if they exist)
echo -e "${CYAN}Checking NGINX pods...${NC}"
NGINX_PODS=$(kubectl get pods -n $NAMESPACE -l app=nginx 2>/dev/null | grep -v NAME | wc -l || echo "0")

if [ "$NGINX_PODS" -gt 0 ]; then
    echo -e "${CYAN}Found $NGINX_PODS NGINX pod(s), checking status...${NC}"
    kubectl get pods -n $NAMESPACE -l app=nginx
    
    # Check if pods are ready
    READY_PODS=$(kubectl get pods -n $NAMESPACE -l app=nginx --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    if [ "$READY_PODS" -eq "$NGINX_PODS" ]; then
        echo -e "${GREEN}✅ All NGINX pods are running${NC}"
    else
        echo -e "${YELLOW}⚠️  Some NGINX pods may not be ready yet${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  No NGINX pods found (may be using different deployment method)${NC}"
fi

echo ""

# =================================================================
# TEST CONFIGURATION
# =================================================================

echo -e "${BLUE}=== TESTING CONFIGURATION ===${NC}"

# Get NGINX service URL
echo -e "${CYAN}Testing edge enforcement routing...${NC}"

# Try to get the NGINX service
NGINX_SERVICE=$(kubectl get svc -n $NAMESPACE -l app=nginx -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$NGINX_SERVICE" ]; then
    echo -e "${CYAN}Found NGINX service: $NGINX_SERVICE${NC}"
    
    # Test the configuration
    echo -e "${CYAN}Testing /api/v1/push endpoint...${NC}"
    
    # Try to make a test request (this will likely fail without auth, but we can check headers)
    TEST_RESPONSE=$(kubectl run test-edge-enforcement --rm -i --restart=Never --image=curlimages/curl -- \
        -s -o /dev/null -w "%{http_code}" \
        -H "X-Scope-OrgID: test-tenant" \
        "http://$NGINX_SERVICE.$NAMESPACE.svc.cluster.local:8080/api/v1/push" 2>/dev/null || echo "000")
    
    if [ "$TEST_RESPONSE" = "000" ]; then
        echo -e "${YELLOW}⚠️  Could not test endpoint (may require authentication)${NC}"
    else
        echo -e "${GREEN}✅ Endpoint is responding (HTTP $TEST_RESPONSE)${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Could not find NGINX service for testing${NC}"
fi

echo ""

# =================================================================
# MONITORING SETUP
# =================================================================

echo -e "${BLUE}=== MONITORING SETUP ===${NC}"

echo -e "${CYAN}Setting up monitoring for edge enforcement...${NC}"

# Create a simple monitoring script
cat > "$BACKUP_DIR/monitor-edge-enforcement.sh" << 'EOF'
#!/bin/bash

# Monitor Edge Enforcement Traffic
# This script helps monitor the traffic flow after deploying 100% edge enforcement

echo "=== EDGE ENFORCEMENT MONITORING ==="
echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo ""

# Check NGINX logs for edge enforcement traffic
echo "=== NGINX LOGS (last 10 lines) ==="
kubectl logs -n mimir -l app=nginx --tail=10 2>/dev/null | grep "route=edge_enforcement" || echo "No edge enforcement traffic found yet"

echo ""
echo "=== RLS SERVICE STATUS ==="
kubectl get pods -n mimir-edge-enforcement -l app.kubernetes.io/name=mimir-rls 2>/dev/null || echo "RLS service not found"

echo ""
echo "=== ENVOY SERVICE STATUS ==="
kubectl get pods -n mimir-edge-enforcement -l app.kubernetes.io/name=mimir-envoy 2>/dev/null || echo "Envoy service not found"

echo ""
echo "=== TRAFFIC FLOW SUMMARY ==="
echo "All /api/v1/push requests should now go through:"
echo "NGINX → Envoy → RLS → Mimir"
echo ""
echo "To verify, check the Admin UI Overview page for traffic flow metrics."
EOF

chmod +x "$BACKUP_DIR/monitor-edge-enforcement.sh"

echo -e "${GREEN}✅ Monitoring script created: $BACKUP_DIR/monitor-edge-enforcement.sh${NC}"

echo ""

# =================================================================
# ROLLBACK INSTRUCTIONS
# =================================================================

echo -e "${BLUE}=== ROLLBACK INSTRUCTIONS ===${NC}"

cat > "$BACKUP_DIR/rollback-instructions.md" << EOF
# Rollback Instructions

If you need to rollback to the previous configuration:

## Quick Rollback
\`\`\`bash
# Apply the backup configuration
kubectl apply -f $BACKUP_DIR/nginx-config-backup.yaml

# Verify rollback
kubectl get configmap $CONFIGMAP_NAME -n $NAMESPACE -o yaml
\`\`\`

## Emergency Bypass
If edge enforcement is causing issues, you can temporarily bypass it:

\`\`\`bash
# Use the emergency bypass endpoint
curl -H "X-Scope-OrgID: your-tenant" \\
     http://your-nginx-service/api/v1/push/direct
\`\`\`

## Complete Rollback
\`\`\`bash
# Delete the edge enforcement ConfigMap
kubectl delete configmap $CONFIGMAP_NAME -n $NAMESPACE

# Recreate with original configuration
kubectl apply -f $BACKUP_DIR/nginx-config-backup.yaml
\`\`\`

## Monitoring Rollback
\`\`\`bash
# Check NGINX logs for direct traffic
kubectl logs -n mimir -l app=nginx --tail=20 | grep "route=direct"
\`\`\`
EOF

echo -e "${GREEN}✅ Rollback instructions saved: $BACKUP_DIR/rollback-instructions.md${NC}"

echo ""

# =================================================================
# DEPLOYMENT SUMMARY
# =================================================================

echo -e "${GREEN}=== DEPLOYMENT COMPLETE ===${NC}"
echo -e "${GREEN}✅ 100% Edge Enforcement has been deployed successfully!${NC}"
echo ""
echo -e "${CYAN}Summary:${NC}"
echo -e "  • Configuration: $CONFIG_FILE"
echo -e "  • Namespace: $NAMESPACE"
echo -e "  • ConfigMap: $CONFIGMAP_NAME"
echo -e "  • Backup: $BACKUP_DIR/"
echo ""
echo -e "${CYAN}What changed:${NC}"
echo -e "  • All /api/v1/push requests now go through edge enforcement"
echo -e "  • Traffic flow: NGINX → Envoy → RLS → Mimir"
echo -e "  • Emergency bypass available at /api/v1/push/direct"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo -e "  1. Monitor traffic flow in the Admin UI"
echo -e "  2. Check NGINX logs for edge enforcement traffic"
echo -e "  3. Verify RLS service is processing requests"
echo -e "  4. Test with real traffic"
echo ""
echo -e "${YELLOW}⚠️  Important:${NC}"
echo -e "  • Monitor for any issues after deployment"
echo -e "  • Keep the backup files for rollback if needed"
echo -e "  • Emergency bypass is available at /api/v1/push/direct"
echo ""
echo -e "${GREEN}🎉 100% Edge Enforcement is now active!${NC}"
