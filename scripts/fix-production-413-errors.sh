#!/bin/bash

# Production 413 Error Fix Script
# This script addresses 413 errors in production environments

set -e

echo "🔧 Production 413 Error Fix Script"
echo "=================================="

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

# Function to check and fix NGINX ingress controller
fix_nginx_ingress() {
    print_status "INFO" "Checking NGINX Ingress Controller..."
    
    # Check if nginx-ingress is installed
    local nginx_namespace=$(kubectl get namespaces | grep -E "(ingress-nginx|nginx-ingress)" | awk '{print $1}' | head -n1)
    
    if [ -n "$nginx_namespace" ]; then
        print_status "SUCCESS" "Found NGINX ingress in namespace: $nginx_namespace"
        
        # Check current configmap
        local configmap_name="nginx-configuration"
        if ! kubectl get configmap $configmap_name -n $nginx_namespace >/dev/null 2>&1; then
            configmap_name="nginx-configuration"
        fi
        
        # Get current configuration
        local current_config=$(kubectl get configmap $configmap_name -n $nginx_namespace -o jsonpath='{.data}' 2>/dev/null)
        
        if [ -n "$current_config" ]; then
            if echo "$current_config" | grep -q "client-max-body-size"; then
                local current_size=$(echo "$current_config" | grep "client-max-body-size" | head -n1)
                print_status "WARNING" "Current client-max-body-size: $current_size"
                
                # Check if it's too small
                if echo "$current_size" | grep -q "1m\|1024k\|1048576"; then
                    print_status "ERROR" "NGINX client-max-body-size is too small (1MB) - updating to 50m"
                    
                    # Update the configmap
                    kubectl patch configmap $configmap_name -n $nginx_namespace --patch '{"data":{"client-max-body-size":"50m"}}'
                    print_status "SUCCESS" "Updated NGINX client-max-body-size to 50m"
                    
                    # Restart nginx pods
                    print_status "INFO" "Restarting NGINX pods to apply changes..."
                    kubectl rollout restart deployment -n $nginx_namespace
                else
                    print_status "SUCCESS" "NGINX client-max-body-size is already configured"
                fi
            else
                print_status "WARNING" "No client-max-body-size found - adding 50m"
                kubectl patch configmap $configmap_name -n $nginx_namespace --patch '{"data":{"client-max-body-size":"50m"}}'
                print_status "SUCCESS" "Added client-max-body-size: 50m"
                
                # Restart nginx pods
                print_status "INFO" "Restarting NGINX pods to apply changes..."
                kubectl rollout restart deployment -n $nginx_namespace
            fi
        else
            print_status "ERROR" "Could not retrieve NGINX configuration"
        fi
    else
        print_status "INFO" "No NGINX ingress controller found"
    fi
}

# Function to check and fix ingress annotations
fix_ingress_annotations() {
    print_status "INFO" "Checking Ingress Annotations..."
    
    # Get all ingresses
    local ingresses=$(kubectl get ingress -A -o name 2>/dev/null)
    
    if [ -n "$ingresses" ]; then
        print_status "INFO" "Found ingresses:"
        echo "$ingresses"
        
        # Add client-max-body-size annotation to each ingress
        echo "$ingresses" | while read ingress; do
            local namespace=$(echo $ingress | cut -d'/' -f1)
            local name=$(echo $ingress | cut -d'/' -f2)
            
            print_status "INFO" "Checking annotations for $name in $namespace"
            
            # Check current annotations
            local current_annotations=$(kubectl get ingress $name -n $namespace -o jsonpath='{.metadata.annotations}' 2>/dev/null)
            
            if echo "$current_annotations" | grep -q "client-max-body-size"; then
                local current_size=$(echo "$current_annotations" | grep -o 'client-max-body-size[^,]*' | head -n1)
                print_status "INFO" "Current annotation: $current_size"
                
                # Check if it's too small
                if echo "$current_size" | grep -q "1m\|1024k\|1048576"; then
                    print_status "WARNING" "Updating client-max-body-size for $name"
                    kubectl patch ingress $name -n $namespace --type='merge' -p='{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/client-max-body-size":"50m"}}}'
                fi
            else
                print_status "INFO" "Adding client-max-body-size annotation to $name"
                kubectl patch ingress $name -n $namespace --type='merge' -p='{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/client-max-body-size":"50m"}}}'
            fi
        done
        
        print_status "SUCCESS" "Updated ingress annotations"
    else
        print_status "INFO" "No ingresses found"
    fi
}

# Function to check and fix AWS ALB/NLB settings
fix_aws_load_balancer() {
    print_status "INFO" "Checking AWS Load Balancer Configuration..."
    
    # Check for AWS load balancer annotations
    local services=$(kubectl get svc -A -o jsonpath='{.items[*].metadata.annotations}' 2>/dev/null)
    
    if echo "$services" | grep -q "alb\|nlb\|aws"; then
        print_status "WARNING" "Found AWS load balancer annotations"
        echo "$services" | grep -E "alb|nlb|aws"
        
        print_status "INFO" "AWS Load Balancer Recommendations:"
        print_status "INFO" "1. Check AWS ALB/NLB target group settings"
        print_status "INFO" "2. Verify target group health check settings"
        print_status "INFO" "3. Check if target group has request size limits"
        print_status "INFO" "4. Consider using Application Load Balancer (ALB) instead of Network Load Balancer (NLB)"
        print_status "INFO" "5. ALB has a default limit of 1MB, NLB has no limit"
    else
        print_status "INFO" "No AWS load balancer annotations found"
    fi
}

# Function to check and fix GCP Load Balancer settings
fix_gcp_load_balancer() {
    print_status "INFO" "Checking GCP Load Balancer Configuration..."
    
    # Check for GCP load balancer annotations
    local services=$(kubectl get svc -A -o jsonpath='{.items[*].metadata.annotations}' 2>/dev/null)
    
    if echo "$services" | grep -q "gcp\|google"; then
        print_status "WARNING" "Found GCP load balancer annotations"
        echo "$services" | grep -E "gcp|google"
        
        print_status "INFO" "GCP Load Balancer Recommendations:"
        print_status "INFO" "1. Check GCP backend service settings"
        print_status "INFO" "2. Verify health check configurations"
        print_status "INFO" "3. Check if backend service has request size limits"
        print_status "INFO" "4. Consider using Cloud Load Balancing with proper timeout settings"
    else
        print_status "INFO" "No GCP load balancer annotations found"
    fi
}

# Function to check and fix Azure Load Balancer settings
fix_azure_load_balancer() {
    print_status "INFO" "Checking Azure Load Balancer Configuration..."
    
    # Check for Azure load balancer annotations
    local services=$(kubectl get svc -A -o jsonpath='{.items[*].metadata.annotations}' 2>/dev/null)
    
    if echo "$services" | grep -q "azure"; then
        print_status "WARNING" "Found Azure load balancer annotations"
        echo "$services" | grep -E "azure"
        
        print_status "INFO" "Azure Load Balancer Recommendations:"
        print_status "INFO" "1. Check Azure load balancer rules"
        print_status "INFO" "2. Verify health probe settings"
        print_status "INFO" "3. Check if load balancer has request size limits"
        print_status "INFO" "4. Consider using Application Gateway for better control"
    else
        print_status "INFO" "No Azure load balancer annotations found"
    fi
}

# Function to verify Envoy configuration
verify_envoy_config() {
    print_status "INFO" "Verifying Envoy Configuration..."
    
    # Check if Envoy is deployed
    local envoy_pods=$(kubectl get pods -A | grep envoy | grep Running | wc -l)
    
    if [ $envoy_pods -gt 0 ]; then
        print_status "SUCCESS" "Found $envoy_pods running Envoy pods"
        
        # Check Envoy configmap
        local envoy_config=$(kubectl get configmap -A | grep envoy | head -n1 | awk '{print $1, $2}')
        
        if [ -n "$envoy_config" ]; then
            local namespace=$(echo $envoy_config | awk '{print $1}')
            local configmap=$(echo $envoy_config | awk '{print $2}')
            
            # Check HTTP/2 buffer settings
            local config_data=$(kubectl get configmap $configmap -n $namespace -o jsonpath='{.data.envoy\.yaml}' 2>/dev/null)
            
            if echo "$config_data" | grep -q "initial_stream_window_size: 52428800"; then
                print_status "SUCCESS" "Envoy HTTP/2 stream window: 50MB"
            else
                print_status "ERROR" "Envoy HTTP/2 stream window not set to 50MB"
            fi
            
            if echo "$config_data" | grep -q "initial_connection_window_size: 52428800"; then
                print_status "SUCCESS" "Envoy HTTP/2 connection window: 50MB"
            else
                print_status "ERROR" "Envoy HTTP/2 connection window not set to 50MB"
            fi
        fi
    else
        print_status "INFO" "No Envoy pods found"
    fi
}

# Function to verify RLS configuration
verify_rls_config() {
    print_status "INFO" "Verifying RLS Configuration..."
    
    # Check if RLS is deployed
    local rls_pods=$(kubectl get pods -A | grep rls | grep Running | wc -l)
    
    if [ $rls_pods -gt 0 ]; then
        print_status "SUCCESS" "Found $rls_pods running RLS pods"
        
        # Get RLS pod
        local rls_pod=$(kubectl get pods -A | grep rls | grep Running | head -n1 | awk '{print $2}')
        local rls_namespace=$(kubectl get pods -A | grep rls | grep Running | head -n1 | awk '{print $1}')
        
        if [ -n "$rls_pod" ]; then
            # Check RLS configuration
            local config_log=$(kubectl logs $rls_pod -n $rls_namespace | grep "parsed configuration values" | tail -n1)
            
            if [ -n "$config_log" ]; then
                if echo "$config_log" | grep -q "default_max_body_bytes.*52428800"; then
                    print_status "SUCCESS" "RLS max body bytes: 50MB"
                else
                    print_status "ERROR" "RLS max body bytes not set to 50MB"
                fi
            fi
        fi
    else
        print_status "ERROR" "No RLS pods found"
    fi
}

# Function to provide production recommendations
provide_production_recommendations() {
    echo ""
    print_status "INFO" "🔧 PRODUCTION RECOMMENDATIONS:"
    echo ""
    
    print_status "INFO" "1. IMMEDIATE FIXES (Run these first):"
    print_status "INFO" "   - Update NGINX ingress client-max-body-size to 50m"
    print_status "INFO" "   - Add client-max-body-size annotations to all ingresses"
    print_status "INFO" "   - Restart NGINX ingress pods"
    echo ""
    
    print_status "INFO" "2. LOAD BALANCER FIXES:"
    print_status "INFO" "   - AWS ALB: Check target group settings, consider using ALB instead of NLB"
    print_status "INFO" "   - GCP LB: Check backend service settings and health checks"
    print_status "INFO" "   - Azure LB: Check load balancer rules and health probes"
    echo ""
    
    print_status "INFO" "3. MONITORING:"
    print_status "INFO" "   - Monitor request sizes in your application"
    print_status "INFO" "   - Set up alerts for 413 errors"
    print_status "INFO" "   - Check Envoy access logs for request patterns"
    echo ""
    
    print_status "INFO" "4. CLIENT-SIDE OPTIMIZATION:"
    print_status "INFO" "   - Implement request compression (snappy)"
    print_status "INFO" "   - Batch smaller requests together"
    print_status "INFO" "   - Monitor client timeout settings"
    echo ""
    
    print_status "INFO" "5. VERIFICATION:"
    print_status "INFO" "   - Test with various request sizes (1KB, 1MB, 5MB, 10MB)"
    print_status "INFO" "   - Monitor 413 error rates after fixes"
    print_status "INFO" "   - Check that 2XX responses increase"
}

# Main execution
echo ""
print_status "INFO" "Starting production 413 error fix..."

# Run all fixes
fix_nginx_ingress
fix_ingress_annotations
fix_aws_load_balancer
fix_gcp_load_balancer
fix_azure_load_balancer
verify_envoy_config
verify_rls_config

# Provide recommendations
provide_production_recommendations

echo ""
print_status "SUCCESS" "Production 413 error fix completed!"
print_status "INFO" ""
print_status "INFO" "📋 Next Steps:"
print_status "INFO" "1. Apply the fixes to your production cluster"
print_status "INFO" "2. Monitor 413 error rates"
print_status "INFO" "3. Test with real traffic patterns"
print_status "INFO" "4. If issues persist, check load balancer settings"
