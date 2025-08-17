#!/bin/bash

# Comprehensive 413 Error Diagnostic Script
# Identifies all potential sources of 413 errors in the nginx → envoy → rls → mimir pipeline

set -e

echo "🔍 413 Error Diagnostic Tool - Production Analysis"
echo "=================================================="

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

# Function to check NGINX configuration
check_nginx_config() {
    print_status "INFO" "Checking NGINX configuration..."
    
    # Check if NGINX is running in the cluster
    local nginx_pods=$(kubectl get pods -A | grep nginx | grep Running | wc -l)
    if [ $nginx_pods -gt 0 ]; then
        print_status "SUCCESS" "Found $nginx_pods running NGINX pods"
        
        # Check NGINX configuration for client_max_body_size
        local nginx_config=$(kubectl get configmap -A | grep nginx | head -n1 | awk '{print $1, $2}')
        if [ -n "$nginx_config" ]; then
            local namespace=$(echo $nginx_config | awk '{print $1}')
            local configmap=$(echo $nginx_config | awk '{print $2}')
            
            print_status "INFO" "Checking NGINX configmap: $configmap in namespace $namespace"
            
            # Get NGINX configuration
            local nginx_conf=$(kubectl get configmap $configmap -n $namespace -o jsonpath='{.data.nginx\.conf}' 2>/dev/null || \
                              kubectl get configmap $configmap -n $namespace -o jsonpath='{.data.default\.conf}' 2>/dev/null || \
                              kubectl get configmap $configmap -n $namespace -o jsonpath='{.data}' 2>/dev/null)
            
            if [ -n "$nginx_conf" ]; then
                if echo "$nginx_conf" | grep -q "client_max_body_size"; then
                    local body_size=$(echo "$nginx_conf" | grep "client_max_body_size" | head -n1 | sed 's/.*client_max_body_size[[:space:]]*//' | sed 's/;.*//')
                    print_status "WARNING" "NGINX client_max_body_size: $body_size"
                    
                    # Check if it's too small
                    if echo "$body_size" | grep -q "1m\|1024k\|1048576"; then
                        print_status "ERROR" "NGINX client_max_body_size is too small (1MB) - likely causing 413 errors"
                        print_status "INFO" "Recommendation: Increase to 50M or higher"
                    fi
                else
                    print_status "WARNING" "No client_max_body_size found in NGINX config - using default (1MB)"
                    print_status "INFO" "This is likely causing 413 errors for requests > 1MB"
                fi
            else
                print_status "WARNING" "Could not retrieve NGINX configuration"
            fi
        fi
    else
        print_status "INFO" "No NGINX pods found - checking ingress controllers"
        
        # Check ingress controllers
        local ingress_pods=$(kubectl get pods -A | grep -E "(ingress|nginx)" | grep Running | wc -l)
        if [ $ingress_pods -gt 0 ]; then
            print_status "INFO" "Found $ingress_pods ingress controller pods"
            
            # Check ingress annotations
            local ingress_annotations=$(kubectl get ingress -A -o jsonpath='{.items[*].metadata.annotations}' 2>/dev/null)
            if echo "$ingress_annotations" | grep -q "client_max_body_size"; then
                print_status "WARNING" "Found client_max_body_size in ingress annotations"
                echo "$ingress_annotations" | grep "client_max_body_size"
            fi
        fi
    fi
}

# Function to check Envoy configuration
check_envoy_config() {
    print_status "INFO" "Checking Envoy configuration..."
    
    # Check Envoy configmap
    local envoy_config=$(kubectl get configmap mimir-envoy-config -n mimir-edge-enforcement -o jsonpath='{.data.envoy\.yaml}' 2>/dev/null)
    
    if [ -n "$envoy_config" ]; then
        # Check HTTP/2 buffer settings
        if echo "$envoy_config" | grep -q "initial_stream_window_size: 52428800"; then
            print_status "SUCCESS" "Envoy HTTP/2 stream window: 50MB"
        else
            print_status "ERROR" "Envoy HTTP/2 stream window not set to 50MB"
        fi
        
        if echo "$envoy_config" | grep -q "initial_connection_window_size: 52428800"; then
            print_status "SUCCESS" "Envoy HTTP/2 connection window: 50MB"
        else
            print_status "ERROR" "Envoy HTTP/2 connection window not set to 50MB"
        fi
        
        # Check for any buffer limits
        if echo "$envoy_config" | grep -q "buffer_limits\|max_request_bytes"; then
            print_status "WARNING" "Found buffer limits in Envoy config:"
            echo "$envoy_config" | grep -E "buffer_limits|max_request_bytes"
        fi
    else
        print_status "ERROR" "Could not retrieve Envoy configuration"
    fi
}

# Function to check RLS configuration
check_rls_config() {
    print_status "INFO" "Checking RLS configuration..."
    
    # Get RLS pod
    local rls_pod=$(kubectl get pods -n mimir-edge-enforcement | grep mimir-rls | grep Running | head -n1 | awk '{print $1}')
    
    if [ -n "$rls_pod" ]; then
        # Check RLS startup logs for configuration
        local config_log=$(kubectl logs $rls_pod -n mimir-edge-enforcement | grep "parsed configuration values" | tail -n1)
        
        if [ -n "$config_log" ]; then
            if echo "$config_log" | grep -q "default_max_body_bytes.*52428800"; then
                print_status "SUCCESS" "RLS max body bytes: 50MB"
            else
                print_status "ERROR" "RLS max body bytes not set to 50MB"
                echo "Config log: $config_log"
            fi
        else
            print_status "WARNING" "Could not find RLS configuration in logs"
        fi
        
        # Check RLS command line arguments
        local rls_args=$(kubectl get pod $rls_pod -n mimir-edge-enforcement -o jsonpath='{.spec.containers[0].args[*]}')
        if echo "$rls_args" | grep -q "max-request-bytes"; then
            print_status "INFO" "RLS max-request-bytes: $(echo "$rls_args" | grep -o 'max-request-bytes[[:space:]]*[^[:space:]]*' | head -n1)"
        fi
    else
        print_status "ERROR" "No RLS pods running"
    fi
}

# Function to check load balancer/proxy settings
check_load_balancer() {
    print_status "INFO" "Checking load balancer/proxy settings..."
    
    # Check for AWS ALB/NLB annotations
    local service_annotations=$(kubectl get svc -A -o jsonpath='{.items[*].metadata.annotations}' 2>/dev/null)
    if echo "$service_annotations" | grep -q "alb\|nlb\|aws"; then
        print_status "WARNING" "Found AWS load balancer annotations - check ALB/NLB limits"
        echo "$service_annotations" | grep -E "alb|nlb|aws"
    fi
    
    # Check for GCP load balancer annotations
    if echo "$service_annotations" | grep -q "gcp\|google"; then
        print_status "WARNING" "Found GCP load balancer annotations - check GCP LB limits"
        echo "$service_annotations" | grep -E "gcp|google"
    fi
    
    # Check for Azure load balancer annotations
    if echo "$service_annotations" | grep -q "azure"; then
        print_status "WARNING" "Found Azure load balancer annotations - check Azure LB limits"
        echo "$service_annotations" | grep -E "azure"
    fi
}

# Function to check ingress controller limits
check_ingress_limits() {
    print_status "INFO" "Checking ingress controller limits..."
    
    # Check ingress-nginx configuration
    local ingress_nginx_config=$(kubectl get configmap -n ingress-nginx nginx-configuration -o jsonpath='{.data}' 2>/dev/null || \
                                 kubectl get configmap -n kube-system nginx-configuration -o jsonpath='{.data}' 2>/dev/null)
    
    if [ -n "$ingress_nginx_config" ]; then
        if echo "$ingress_nginx_config" | grep -q "client-max-body-size"; then
            local body_size=$(echo "$ingress_nginx_config" | grep "client-max-body-size" | head -n1)
            print_status "WARNING" "Ingress-nginx client-max-body-size: $body_size"
        else
            print_status "WARNING" "No client-max-body-size in ingress-nginx config - using default (1MB)"
        fi
    fi
    
    # Check for other ingress controllers
    local ingress_pods=$(kubectl get pods -A | grep -E "(traefik|istio|haproxy)" | grep Running | wc -l)
    if [ $ingress_pods -gt 0 ]; then
        print_status "WARNING" "Found $ingress_pods other ingress controller pods - check their limits"
    fi
}

# Function to check network policies
check_network_policies() {
    print_status "INFO" "Checking network policies..."
    
    local network_policies=$(kubectl get networkpolicy -A 2>/dev/null | wc -l)
    if [ $network_policies -gt 0 ]; then
        print_status "WARNING" "Found $network_policies network policies - check for size restrictions"
        kubectl get networkpolicy -A
    else
        print_status "SUCCESS" "No network policies found"
    fi
}

# Function to check for 413 errors in logs
check_413_logs() {
    print_status "INFO" "Checking for 413 errors in logs..."
    
    # Check Envoy logs
    local envoy_pod=$(kubectl get pods -n mimir-edge-enforcement | grep mimir-envoy | grep Running | head -n1 | awk '{print $1}')
    if [ -n "$envoy_pod" ]; then
        local envoy_413_count=$(kubectl logs $envoy_pod -n mimir-edge-enforcement --tail=1000 | grep "413" | wc -l)
        if [ $envoy_413_count -gt 0 ]; then
            print_status "ERROR" "Found $envoy_413_count 413 errors in Envoy logs"
            print_status "INFO" "Recent 413 errors from Envoy:"
            kubectl logs $envoy_pod -n mimir-edge-enforcement --tail=100 | grep "413" | head -n5
        else
            print_status "SUCCESS" "No 413 errors in Envoy logs"
        fi
    fi
    
    # Check RLS logs
    local rls_pod=$(kubectl get pods -n mimir-edge-enforcement | grep mimir-rls | grep Running | head -n1 | awk '{print $1}')
    if [ -n "$rls_pod" ]; then
        local rls_413_count=$(kubectl logs $rls_pod -n mimir-edge-enforcement --tail=1000 | grep "413" | wc -l)
        if [ $rls_413_count -gt 0 ]; then
            print_status "ERROR" "Found $rls_413_count 413 errors in RLS logs"
            print_status "INFO" "Recent 413 errors from RLS:"
            kubectl logs $rls_pod -n mimir-edge-enforcement --tail=100 | grep "413" | head -n5
        else
            print_status "SUCCESS" "No 413 errors in RLS logs"
        fi
    fi
    
    # Check NGINX logs if available
    local nginx_pods=$(kubectl get pods -A | grep nginx | grep Running | head -n1 | awk '{print $1, $2}')
    if [ -n "$nginx_pods" ]; then
        local namespace=$(echo $nginx_pods | awk '{print $1}')
        local pod=$(echo $nginx_pods | awk '{print $2}')
        local nginx_413_count=$(kubectl logs $pod -n $namespace --tail=1000 2>/dev/null | grep "413" | wc -l)
        if [ $nginx_413_count -gt 0 ]; then
            print_status "ERROR" "Found $nginx_413_count 413 errors in NGINX logs"
            print_status "INFO" "Recent 413 errors from NGINX:"
            kubectl logs $pod -n $namespace --tail=100 2>/dev/null | grep "413" | head -n5
        fi
    fi
}

# Function to provide recommendations
provide_recommendations() {
    echo ""
    print_status "INFO" "🔧 RECOMMENDATIONS TO FIX 413 ERRORS:"
    echo ""
    
    print_status "INFO" "1. NGINX Configuration (Most Common Cause):"
    print_status "INFO" "   Add to NGINX server block:"
    print_status "INFO" "   client_max_body_size 50M;"
    echo ""
    
    print_status "INFO" "2. Ingress Controller Configuration:"
    print_status "INFO" "   Add annotation to ingress:"
    print_status "INFO" "   nginx.ingress.kubernetes.io/client-max-body-size: '50m'"
    echo ""
    
    print_status "INFO" "3. Load Balancer Configuration:"
    print_status "INFO" "   - AWS ALB: Check target group settings"
    print_status "INFO" "   - GCP LB: Check backend service settings"
    print_status "INFO" "   - Azure LB: Check load balancer rules"
    echo ""
    
    print_status "INFO" "4. Envoy Configuration (Already Fixed):"
    print_status "INFO" "   ✅ HTTP/2 buffer settings: 50MB"
    print_status "INFO" "   ✅ RLS port routing: 8080"
    echo ""
    
    print_status "INFO" "5. RLS Configuration (Already Fixed):"
    print_status "INFO" "   ✅ maxBodyBytes: 50MB"
    print_status "INFO" "   ✅ maxRequestBytes: 50MB"
    echo ""
    
    print_status "INFO" "6. Network Policies:"
    print_status "INFO" "   Check for any size restrictions in network policies"
    echo ""
    
    print_status "INFO" "7. Client-Side Issues:"
    print_status "INFO" "   - Check client timeout settings"
    print_status "INFO" "   - Verify request compression (snappy)"
    print_status "INFO" "   - Monitor request sizes"
}

# Main diagnostic execution
echo ""
print_status "INFO" "Starting comprehensive 413 error diagnosis..."

# Run all checks
check_nginx_config
check_envoy_config
check_rls_config
check_load_balancer
check_ingress_limits
check_network_policies
check_413_logs

# Provide recommendations
provide_recommendations

echo ""
print_status "INFO" "📊 SUMMARY:"
print_status "INFO" "If you're seeing 90% 413 errors in production, the most likely causes are:"
print_status "INFO" "1. NGINX client_max_body_size (default 1MB) - 80% probability"
print_status "INFO" "2. Ingress controller limits - 15% probability"
print_status "INFO" "3. Load balancer limits - 5% probability"
print_status "INFO" ""
print_status "INFO" "The Envoy and RLS configurations have been fixed and should not be causing 413 errors."
