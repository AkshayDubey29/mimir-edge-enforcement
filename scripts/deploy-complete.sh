#!/bin/bash
set -euo pipefail

# One-Shot Complete Deployment Script for mimir-edge-enforcement
# This script deploys ALL components with minimal configuration needed
# Usage: ./scripts/deploy-complete.sh [namespace] [admin-domain]

NAMESPACE=${1:-mimir-edge-enforcement}
ADMIN_DOMAIN=${2:-mimir-admin.your-domain.com}

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🚀 MIMIR EDGE ENFORCEMENT - COMPLETE DEPLOYMENT${NC}"
echo "=================================================="
echo ""
echo "This script will deploy the complete mimir-edge-enforcement system:"
echo "✅ RLS (Rate Limiting Service)"
echo "✅ Overrides Sync Controller" 
echo "✅ Envoy Proxy"
echo "✅ Admin UI with Ingress"
echo ""
echo "Namespace: $NAMESPACE"
echo "Admin UI: https://$ADMIN_DOMAIN"
echo ""

# Check if we have the required environment variables
if [[ -z "${GITHUB_USERNAME:-}" || -z "${GITHUB_TOKEN:-}" ]]; then
    echo -e "${YELLOW}⚠️  GitHub credentials not set. You may see image pull errors.${NC}"
    echo "To fix this, run:"
    echo "  export GITHUB_USERNAME=your-username"
    echo "  export GITHUB_TOKEN=your-personal-access-token"
    echo ""
fi

# Ask for confirmation
read -p "Continue with deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo -e "${BLUE}🔧 Starting deployment...${NC}"

# Run the main deployment script with complete mode
exec ./scripts/deploy-production.sh "$NAMESPACE" "your-domain.com" "$ADMIN_DOMAIN" "complete"
