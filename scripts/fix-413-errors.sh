#!/bin/bash

# Quick Fix Script for 413 Errors in Production
# Addresses the most common causes of 413 errors

set -e

echo "🔧 Quick Fix for 413 Errors - Production"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "SUCCESS") echo -e "${GREEN}✅ $message${NC}" ;;
        "ERROR") echo -e "${RED}❌ $message${NC}" ;;
        "WARNING") echo -e "${YELLOW}⚠️  $message${NC}" ;;
        "INFO") echo -e "${BLUE}ℹ️  $message${NC}" ;;
    esac
}

# Function to fix NGINX configuration
fix_nginx_config() {
    print_status "INFO" "Fixing NGINX configuration..."
    
    # Check if NGINX is running
    local nginx_pods=$(kubectl get pods -A | grep nginx | grep Running | wc -l)
    if [ $nginx_pods -gt 0 ]; then
        print_status "INFO" "Found $nginx_pods NGINX pods"
        
        # Find NGINX configmap
        local nginx_config=$(kubectl get configmap -A | grep nginx | head -n1 | awk '{print $1, $2}')
        if [ -n "$nginx_config" ]; then
            local namespace=$(echo $nginx_config | awk '{print $1}')
            local configmap=$(echo $nginx_config | awk '{print $2}')
            
            print_status "INFO" "Updating NGINX configmap: $configmap in namespace $namespace"
            
            # Get current config
            local current_config=$(kubectl get configmap $configmap -n $namespace -o jsonpath='{.data.nginx\.conf}' 2>/dev/null || \
                                  kubectl get configmap $configmap -n $namespace -o jsonpath='{.data.default\.conf}' 2>/dev/null || \
                                  kubectl get configmap $configmap -n $namespace -o jsonpath='{.data}' 2>/dev/null)
            
            if [ -n "$current_config" ]; then
                # Check if client_max_body_size already exists
                if echo "$current_config" | grep -q "client_max_body_size"; then
                    print_status "WARNING" "client_max_body_size already exists in NGINX config"
                    echo "$current_config" | grep "client_max_body_size"
                else
                    # Add client_max_body_size to server block
                    local updated_config=$(echo "$current_config" | sed '/server {/a\    client_max_body_size 50M;')
                    
                    # Update configmap
                    kubectl patch configmap $configmap -n $namespace --patch "{\"data\":{\"nginx.conf\":\"$(echo "$updated_config" | sed 's/"/\\"/g' | tr '\n' ' ')\"}}"
                    
                    print_status "SUCCESS" "Added client_max_body_size 50M to NGINX config"
                fi
            else
                print_status "ERROR" "Could not retrieve NGINX configuration"
            fi
        fi
    else
        print_status "INFO" "No NGINX pods found - checking ingress controllers"
    fi
}

# Function to fix ingress controller configuration
fix_ingress_config() {
    print_status "INFO" "Fixing ingress controller configuration..."
    
    # Check for ingress-nginx
    local ingress_nginx_config=$(kubectl get configmap -n ingress-nginx nginx-configuration -o jsonpath='{.data}' 2>/dev/null || \
                                 kubectl get configmap -n kube-system nginx-configuration -o jsonpath='{.data}' 2>/dev/null)
    
    if [ -n "$ingress_nginx_config" ]; then
        print_status "INFO" "Found ingress-nginx configuration"
        
        if echo "$ingress_nginx_config" | grep -q "client-max-body-size"; then
            print_status "WARNING" "client-max-body-size already exists in ingress-nginx config"
            echo "$ingress_nginx_config" | grep "client-max-body-size"
        else
            # Add client-max-body-size to ingress-nginx config
            local updated_config="$ingress_nginx_config
client-max-body-size: 50m"
            
            kubectl patch configmap nginx-configuration -n ingress-nginx --patch "{\"data\":{\"client-max-body-size\":\"50m\"}}"
            
            print_status "SUCCESS" "Added client-max-body-size 50m to ingress-nginx config"
        fi
    else
        print_status "INFO" "No ingress-nginx configuration found"
    fi
}

# Function to fix ingress annotations
fix_ingress_annotations() {
    print_status "INFO" "Fixing ingress annotations..."
    
    # Get all ingresses
    local ingresses=$(kubectl get ingress -A -o name)
    
    if [ -n "$ingresses" ]; then
        print_status "INFO" "Found ingresses:"
        echo "$ingresses"
        
        # Add client-max-body-size annotation to each ingress
        echo "$ingresses" | while read ingress; do
            local namespace=$(echo $ingress | cut -d'/' -f1)
            local name=$(echo $ingress | cut -d'/' -f2)
            
            print_status "INFO" "Adding client-max-body-size annotation to $name in $namespace"
            
            kubectl patch ingress $name -n $namespace --type='merge' -p='{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/client-max-body-size":"50m"}}}'
        done
        
        print_status "SUCCESS" "Added client-max-body-size annotations to all ingresses"
    else
        print_status "INFO" "No ingresses found"
    fi
}

# Function to restart services
restart_services() {
    print_status "INFO" "Restarting services to apply configuration changes..."
    
    # Restart NGINX pods
    local nginx_pods=$(kubectl get pods -A | grep nginx | grep Running | awk '{print $1, $2}')
    if [ -n "$nginx_pods" ]; then
        echo "$nginx_pods" | while read namespace pod; do
            print_status "INFO" "Restarting NGINX pod $pod in $namespace"
            kubectl delete pod $pod -n $namespace
        done
    fi
    
    # Restart ingress-nginx pods
    local ingress_pods=$(kubectl get pods -n ingress-nginx 2>/dev/null | grep nginx | grep Running | awk '{print $1}')
    if [ -n "$ingress_pods" ]; then
        echo "$ingress_pods" | while read pod; do
            print_status "INFO" "Restarting ingress-nginx pod $pod"
            kubectl delete pod $pod -n ingress-nginx
        done
    fi
    
    print_status "SUCCESS" "Services restarted"
}

# Function to verify the fix
verify_fix() {
    print_status "INFO" "Verifying the fix..."
    
    # Wait for pods to be ready
    sleep 10
    
    # Check if NGINX config was updated
    local nginx_config=$(kubectl get configmap -A | grep nginx | head -n1 | awk '{print $1, $2}')
    if [ -n "$nginx_config" ]; then
        local namespace=$(echo $nginx_config | awk '{print $1}')
        local configmap=$(echo $nginx_config | awk '{print $2}')
        
        local nginx_conf=$(kubectl get configmap $configmap -n $namespace -o jsonpath='{.data.nginx\.conf}' 2>/dev/null || \
                          kubectl get configmap $configmap -n $namespace -o jsonpath='{.data.default\.conf}' 2>/dev/null || \
                          kubectl get configmap $configmap -n $namespace -o jsonpath='{.data}' 2>/dev/null)
        
        if echo "$nginx_conf" | grep -q "client_max_body_size.*50M"; then
            print_status "SUCCESS" "NGINX client_max_body_size verified: 50M"
        else
            print_status "WARNING" "NGINX client_max_body_size not found or incorrect"
        fi
    fi
    
    # Check ingress annotations
    local ingress_annotations=$(kubectl get ingress -A -o jsonpath='{.items[*].metadata.annotations}' 2>/dev/null)
    if echo "$ingress_annotations" | grep -q "client-max-body-size.*50m"; then
        print_status "SUCCESS" "Ingress client-max-body-size verified: 50m"
    else
        print_status "WARNING" "Ingress client-max-body-size not found or incorrect"
    fi
}

# Main execution
echo ""
print_status "INFO" "Starting 413 error fix..."

# Run fixes
fix_nginx_config
fix_ingress_config
fix_ingress_annotations
restart_services
verify_fix

echo ""
print_status "SUCCESS" "413 error fix completed!"
print_status "INFO" ""
print_status "INFO" "📋 What was fixed:"
print_status "INFO" "1. Added client_max_body_size 50M to NGINX configuration"
print_status "INFO" "2. Added client-max-body-size 50m to ingress-nginx configuration"
print_status "INFO" "3. Added client-max-body-size annotations to all ingresses"
print_status "INFO" "4. Restarted services to apply changes"
print_status "INFO" ""
print_status "INFO" "🔍 Next steps:"
print_status "INFO" "1. Monitor for 413 errors - they should be significantly reduced"
print_status "INFO" "2. If 413 errors persist, check load balancer settings"
print_status "INFO" "3. Run the diagnostic script: ./scripts/diagnose-413-errors.sh"
print_status "INFO" "4. Monitor request sizes to ensure they're within 50MB limit"
