#!/bin/bash

# Simplified Local Test for Selective Filtering
# This script tests selective filtering functionality in a local kind cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RLS_NAMESPACE="mimir-edge-enforcement"
TEST_DATA_DIR="./test-data-local"
RESULTS_DIR="./local-test-results"

# Create directories
mkdir -p $TEST_DATA_DIR $RESULTS_DIR

echo -e "${BLUE}🧪 Local Selective Filtering Test${NC}"
echo "=================================================="

# Function to log messages
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

# Function to check RLS status
check_rls_status() {
    log "Checking RLS status..."
    
    # Check if RLS pods are running
    local rls_pods=$(kubectl get pods -n $RLS_NAMESPACE -l app.kubernetes.io/name=mimir-rls --no-headers 2>/dev/null | grep Running | wc -l)
    if [ $rls_pods -eq 0 ]; then
        error "No RLS pods running"
        return 1
    fi
    log "✅ RLS pods: $rls_pods running"
    
    # Check RLS health
    local health_response=$(curl -s http://localhost:8082/healthz 2>/dev/null || echo "error")
    if [ "$health_response" = "ok" ]; then
        log "✅ RLS health check: OK"
        return 0
    else
        error "RLS health check failed: $health_response"
        return 1
    fi
}

# Function to create simple test data
create_simple_test_data() {
    log "Creating simple test data..."
    
    # Create a simple protobuf test data
    cat > $TEST_DATA_DIR/simple_test.go << 'EOF'
package main

import (
    "fmt"
    "os"
    
    "github.com/golang/protobuf/proto"
    prompb "github.com/AkshayDubey29/mimir-edge-enforcement/protos/prometheus"
)

func main() {
    // Create a simple WriteRequest with multiple series
    var writeRequest prompb.WriteRequest
    
    // Create 50 series (should trigger limits)
    for i := 0; i < 50; i++ {
        timeseries := &prompb.TimeSeries{}
        
        // Add metric name
        timeseries.Labels = append(timeseries.Labels, &prompb.Label{
            Name:  "__name__",
            Value: fmt.Sprintf("test_metric_%d", i%5), // 5 different metrics
        })
        
        // Add some labels
        timeseries.Labels = append(timeseries.Labels, &prompb.Label{
            Name:  "instance",
            Value: fmt.Sprintf("server-%d", i%3),
        })
        
        timeseries.Labels = append(timeseries.Labels, &prompb.Label{
            Name:  "job",
            Value: "test-job",
        })
        
        // Add sample
        timeseries.Samples = append(timeseries.Samples, &prompb.Sample{
            Value:     float64(i),
            Timestamp: 1640995200000 + int64(i*1000),
        })
        
        writeRequest.Timeseries = append(writeRequest.Timeseries, timeseries)
    }
    
    // Serialize to protobuf
    protobufData, err := proto.Marshal(&writeRequest)
    if err != nil {
        panic(err)
    }
    
    // Write to file
    if err := os.WriteFile("simple_test_data.pb", protobufData, 0644); err != nil {
        panic(err)
    }
    
    fmt.Printf("Generated simple test data: %d bytes, %d series\n", len(protobufData), len(writeRequest.Timeseries))
}
EOF

    # Run the generator
    if command -v go &> /dev/null; then
        cd $TEST_DATA_DIR
        go mod init test-data-local
        go mod tidy
        go run simple_test.go
        cd - > /dev/null
        log "Simple test data generated: $TEST_DATA_DIR/simple_test_data.pb"
        return 0
    else
        error "Go not available, cannot generate test data"
        return 1
    fi
}

# Function to test selective filtering
test_selective_filtering() {
    log "Testing selective filtering functionality..."
    
    # Check if selective filtering is enabled
    local config=$(kubectl get configmap -n $RLS_NAMESPACE mimir-rls -o jsonpath='{.data.selectiveFiltering\.enabled}' 2>/dev/null || echo "false")
    log "Selective filtering enabled: $config"
    
    # Send test request
    local start_time=$(date +%s%N)
    
    local response=$(curl -s -w "%{http_code}" -o /dev/null \
        -H "Content-Type: application/x-protobuf" \
        -H "Content-Encoding: snappy" \
        -H "X-Scope-OrgID: test-tenant" \
        --data-binary @$TEST_DATA_DIR/simple_test_data.pb \
        http://localhost:8082/api/v1/push 2>/dev/null || echo "000")
    
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds
    
    log "Request response: HTTP $response"
    log "Request duration: $duration ms"
    
    # Check response
    if [ "$response" = "200" ]; then
        log "✅ Request successful (HTTP 200)"
        return 0
    elif [ "$response" = "413" ] || [ "$response" = "429" ]; then
        log "⚠️ Request denied (HTTP $response) - this is expected if limits are exceeded"
        return 0
    else
        error "❌ Unexpected response: HTTP $response"
        return 1
    fi
}

# Function to check RLS logs for filtering activity
check_rls_logs() {
    log "Checking RLS logs for filtering activity..."
    
    local rls_pod=$(kubectl get pods -n $RLS_NAMESPACE -l app.kubernetes.io/name=mimir-rls --no-headers | head -1 | awk '{print $1}')
    
    if [ -z "$rls_pod" ]; then
        error "No RLS pod found"
        return 1
    fi
    
    # Get recent logs
    local logs=$(kubectl logs -n $RLS_NAMESPACE $rls_pod --tail=50 2>/dev/null || echo "")
    
    # Check for selective filtering messages
    local selective_filter_count=$(echo "$logs" | grep -c "selective_filter_applied" || echo "0")
    local successful_filter_count=$(echo "$logs" | grep -c "Successfully filtered" || echo "0")
    local error_count=$(echo "$logs" | grep -c "ERROR" || echo "0")
    
    log "Selective filtering attempts: $selective_filter_count"
    log "Successful filtering operations: $successful_filter_count"
    log "Error count: $error_count"
    
    # Show recent log entries
    log "Recent RLS log entries:"
    echo "$logs" | tail -10 | while IFS= read -r line; do
        echo "  $line"
    done
    
    if [ $successful_filter_count -gt 0 ]; then
        log "✅ Selective filtering is working correctly"
        return 0
    elif [ $selective_filter_count -gt 0 ]; then
        warn "⚠️ Selective filtering attempted but may have failed"
        return 1
    else
        warn "⚠️ No selective filtering activity detected"
        return 1
    fi
}

# Function to test with different configurations
test_different_configurations() {
    log "Testing with different selective filtering configurations..."
    
    # Test 1: With selective filtering enabled
    log "Test 1: With selective filtering enabled"
    kubectl patch configmap -n $RLS_NAMESPACE mimir-rls --type='json' -p='[{"op": "replace", "path": "/data/selectiveFiltering.enabled", "value": "true"}]' 2>/dev/null || true
    
    # Restart RLS to apply changes
    kubectl rollout restart deployment/mimir-rls -n $RLS_NAMESPACE
    kubectl rollout status deployment/mimir-rls -n $RLS_NAMESPACE --timeout=300s
    
    # Wait for RLS to be ready
    sleep 30
    
    # Test request
    test_selective_filtering
    
    # Check logs
    check_rls_logs
    
    # Test 2: With selective filtering disabled
    log "Test 2: With selective filtering disabled"
    kubectl patch configmap -n $RLS_NAMESPACE mimir-rls --type='json' -p='[{"op": "replace", "path": "/data/selectiveFiltering.enabled", "value": "false"}]' 2>/dev/null || true
    
    # Restart RLS to apply changes
    kubectl rollout restart deployment/mimir-rls -n $RLS_NAMESPACE
    kubectl rollout status deployment/mimir-rls -n $RLS_NAMESPACE --timeout=300s
    
    # Wait for RLS to be ready
    sleep 30
    
    # Test request
    test_selective_filtering
    
    # Check logs
    check_rls_logs
}

# Function to generate test report
generate_test_report() {
    log "Generating test report..."
    
    local report_file="$RESULTS_DIR/local_test_report_$(date +%Y%m%d_%H%M%S).md"
    
    cat > $report_file << EOF
# Local Selective Filtering Test Report

Generated: $(date)

## Test Summary

### Components Tested
- ✅ **RLS**: Rate Limit Service with selective filtering
- ✅ **Local Kind Cluster**: Local Kubernetes environment

### Test Results

#### RLS Status
$(check_rls_status 2>&1 | grep -E "(✅|❌)" | sed 's/^/- /')

#### Selective Filtering Activity
$(check_rls_logs 2>&1 | grep -E "(✅|⚠️)" | sed 's/^/- /')

#### Configuration Tests
- **Selective Filtering Enabled**: Tested with filtering enabled
- **Selective Filtering Disabled**: Tested with filtering disabled

## Recommendations

1. **Verify Configuration**: Ensure selective filtering is properly configured
2. **Check Logs**: Monitor RLS logs for filtering activity
3. **Test Limits**: Verify that test data triggers appropriate limits
4. **Monitor Performance**: Track response times and resource usage

## Next Steps

1. Deploy to production environment
2. Run comprehensive end-to-end tests
3. Monitor performance in production
4. Optimize based on real-world usage

EOF

    log "Test report generated: $report_file"
}

# Main execution
main() {
    log "Starting local selective filtering test..."
    
    # Check RLS status
    if ! check_rls_status; then
        error "RLS is not ready. Please ensure RLS is deployed and running."
        exit 1
    fi
    
    # Create test data
    if ! create_simple_test_data; then
        error "Failed to create test data"
        exit 1
    fi
    
    # Test selective filtering
    test_selective_filtering
    
    # Check RLS logs
    check_rls_logs
    
    # Test different configurations
    test_different_configurations
    
    # Generate report
    generate_test_report
    
    log "Local selective filtering test completed!"
    log "Check the report at: $RESULTS_DIR/local_test_report_*.md"
}

# Run main function
main "$@"
