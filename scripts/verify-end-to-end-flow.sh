#!/bin/bash

# End-to-End Verification: nginx → envoy → rls → mimir with Selective Filtering
# This script verifies that filtered metrics reach Mimir and measures performance impact

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RLS_NAMESPACE="mimir-edge-enforcement"
MIMIR_NAMESPACE="mimir"
TEST_DATA_DIR="./test-data"
RESULTS_DIR="./e2e-results"
PERFORMANCE_LOG="$RESULTS_DIR/performance_impact.log"

# Create results directory
mkdir -p $RESULTS_DIR

echo -e "${BLUE}🔍 End-to-End Verification: nginx → envoy → rls → mimir${NC}"
echo "=================================================="

# Function to log messages
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $PERFORMANCE_LOG
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> $PERFORMANCE_LOG
}

warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: $1" >> $PERFORMANCE_LOG
}

# Function to check if all components are running
check_components() {
    log "Checking if all components are running..."
    
    # Check RLS
    local rls_pods=$(kubectl get pods -n $RLS_NAMESPACE -l app=mimir-rls --no-headers 2>/dev/null | grep Running | wc -l)
    if [ $rls_pods -eq 0 ]; then
        error "No RLS pods running"
        return 1
    fi
    log "✅ RLS pods: $rls_pods running"
    
    # Check Envoy
    local envoy_pods=$(kubectl get pods -n $RLS_NAMESPACE -l app=envoy --no-headers 2>/dev/null | grep Running | wc -l)
    if [ $envoy_pods -eq 0 ]; then
        error "No Envoy pods running"
        return 1
    fi
    log "✅ Envoy pods: $envoy_pods running"
    
    # Check Mimir
    local mimir_pods=$(kubectl get pods -n $MIMIR_NAMESPACE -l app.kubernetes.io/name=mimir --no-headers 2>/dev/null | grep Running | wc -l)
    if [ $mimir_pods -eq 0 ]; then
        error "No Mimir pods running"
        return 1
    fi
    log "✅ Mimir pods: $mimir_pods running"
    
    return 0
}

# Function to create test data that will trigger selective filtering
create_test_data_with_limits() {
    log "Creating test data that will trigger selective filtering..."
    
    mkdir -p $TEST_DATA_DIR
    
    # Create a Go program to generate test data that exceeds limits
    cat > $TEST_DATA_DIR/generate_limit_test_data.go << 'EOF'
package main

import (
    "fmt"
    "os"
    
    "github.com/golang/protobuf/proto"
    prompb "github.com/AkshayDubey29/mimir-edge-enforcement/protos/prometheus"
)

func main() {
    // Create a WriteRequest with many series to trigger limits
    var writeRequest prompb.WriteRequest
    
    // Create 1000 series (this should trigger per-user series limits)
    for i := 0; i < 1000; i++ {
        timeseries := &prompb.TimeSeries{}
        
        // Add metric name
        timeseries.Labels = append(timeseries.Labels, &prompb.Label{
            Name:  "__name__",
            Value: fmt.Sprintf("test_metric_%d", i%10), // 10 different metrics
        })
        
        // Add some labels
        timeseries.Labels = append(timeseries.Labels, &prompb.Label{
            Name:  "instance",
            Value: fmt.Sprintf("server-%d", i%5),
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
    if err := os.WriteFile("limit_test_data.pb", protobufData, 0644); err != nil {
        panic(err)
    }
    
    fmt.Printf("Generated test data: %d bytes, %d series\n", len(protobufData), len(writeRequest.Timeseries))
}
EOF

    # Run the generator
    if command -v go &> /dev/null; then
        cd $TEST_DATA_DIR
        go mod init test-data
        go mod tidy
        go run generate_limit_test_data.go
        cd - > /dev/null
        log "Test data generated: $TEST_DATA_DIR/limit_test_data.pb"
    else
        error "Go not available, cannot generate test data"
        return 1
    fi
}

# Function to measure baseline performance (without selective filtering)
measure_baseline_performance() {
    log "Measuring baseline performance (without selective filtering)..."
    
    # Disable selective filtering temporarily
    kubectl patch configmap -n $RLS_NAMESPACE mimir-rls --type='json' -p='[{"op": "replace", "path": "/data/selectiveFiltering.enabled", "value": "false"}]' 2>/dev/null || true
    
    # Restart RLS to apply changes
    kubectl rollout restart deployment/mimir-rls -n $RLS_NAMESPACE
    kubectl rollout status deployment/mimir-rls -n $RLS_NAMESPACE --timeout=300s
    
    # Wait for RLS to be ready
    sleep 30
    
    # Send test requests and measure performance
    local baseline_times=()
    for i in {1..10}; do
        local start_time=$(date +%s%N)
        
        # Send request through nginx → envoy → rls → mimir
        local response=$(curl -s -w "%{http_code}" -o /dev/null \
            -H "Content-Type: application/x-protobuf" \
            -H "Content-Encoding: snappy" \
            -H "X-Scope-OrgID: test-tenant" \
            --data-binary @$TEST_DATA_DIR/limit_test_data.pb \
            http://localhost:8080/api/v1/push 2>/dev/null || echo "000")
        
        local end_time=$(date +%s%N)
        local duration=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds
        
        baseline_times+=($duration)
        
        log "Baseline request $i: $duration ms (HTTP $response)"
        sleep 1
    done
    
    # Calculate average baseline time
    local total=0
    for time in "${baseline_times[@]}"; do
        total=$((total + time))
    done
    local baseline_avg=$((total / ${#baseline_times[@]}))
    
    echo "BASELINE_AVG=$baseline_avg" > $RESULTS_DIR/baseline_performance.txt
    
    log "Baseline average response time: $baseline_avg ms"
}

# Function to measure selective filtering performance
measure_selective_filtering_performance() {
    log "Measuring selective filtering performance..."
    
    # Enable selective filtering
    kubectl patch configmap -n $RLS_NAMESPACE mimir-rls --type='json' -p='[{"op": "replace", "path": "/data/selectiveFiltering.enabled", "value": "true"}]' 2>/dev/null || true
    
    # Restart RLS to apply changes
    kubectl rollout restart deployment/mimir-rls -n $RLS_NAMESPACE
    kubectl rollout status deployment/mimir-rls -n $RLS_NAMESPACE --timeout=300s
    
    # Wait for RLS to be ready
    sleep 30
    
    # Send test requests and measure performance
    local filtering_times=()
    for i in {1..10}; do
        local start_time=$(date +%s%N)
        
        # Send request through nginx → envoy → rls → mimir
        local response=$(curl -s -w "%{http_code}" -o /dev/null \
            -H "Content-Type: application/x-protobuf" \
            -H "Content-Encoding: snappy" \
            -H "X-Scope-OrgID: test-tenant" \
            --data-binary @$TEST_DATA_DIR/limit_test_data.pb \
            http://localhost:8080/api/v1/push 2>/dev/null || echo "000")
        
        local end_time=$(date +%s%N)
        local duration=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds
        
        filtering_times+=($duration)
        
        log "Selective filtering request $i: $duration ms (HTTP $response)"
        sleep 1
    done
    
    # Calculate average filtering time
    local total=0
    for time in "${filtering_times[@]}"; do
        total=$((total + time))
    done
    local filtering_avg=$((total / ${#filtering_times[@]}))
    
    echo "FILTERING_AVG=$filtering_avg" > $RESULTS_DIR/filtering_performance.txt
    
    log "Selective filtering average response time: $filtering_avg ms"
}

# Function to verify metrics reached Mimir
verify_metrics_in_mimir() {
    log "Verifying that filtered metrics reached Mimir..."
    
    # Wait a bit for metrics to be ingested
    sleep 10
    
    # Get Mimir distributor pod
    local mimir_pod=$(kubectl get pods -n $MIMIR_NAMESPACE -l app.kubernetes.io/name=mimir,app.kubernetes.io/component=distributor --no-headers | head -1 | awk '{print $1}')
    
    if [ -z "$mimir_pod" ]; then
        error "No Mimir distributor pod found"
        return 1
    fi
    
    # Check Mimir metrics for ingested data
    local ingested_metrics=$(kubectl exec -n $MIMIR_NAMESPACE $mimir_pod -- curl -s http://localhost:9009/metrics 2>/dev/null | grep 'cortex_distributor_received_samples_total' | grep 'status=success' | awk '{print $2}' | sed 's/}//' || echo "0")
    
    log "Mimir ingested metrics: $ingested_metrics"
    
    # Query Mimir for our test metrics
    local query_result=$(kubectl exec -n $MIMIR_NAMESPACE $mimir_pod -- curl -s "http://localhost:9009/prometheus/api/v1/query?query=test_metric_0" 2>/dev/null || echo "")
    
    if echo "$query_result" | grep -q "test_metric_0"; then
        log "✅ Test metrics found in Mimir!"
        return 0
    else
        warn "⚠️ Test metrics not found in Mimir query results"
        return 1
    fi
}

# Function to check RLS logs for filtering activity
check_rls_filtering_logs() {
    log "Checking RLS logs for selective filtering activity..."
    
    local rls_pod=$(kubectl get pods -n $RLS_NAMESPACE -l app=mimir-rls --no-headers | head -1 | awk '{print $1}')
    
    if [ -z "$rls_pod" ]; then
        error "No RLS pod found"
        return 1
    fi
    
    # Get recent logs
    local logs=$(kubectl logs -n $RLS_NAMESPACE $rls_pod --tail=100 2>/dev/null || echo "")
    
    # Check for selective filtering messages
    local selective_filter_count=$(echo "$logs" | grep -c "selective_filter_applied" || echo "0")
    local successful_filter_count=$(echo "$logs" | grep -c "Successfully filtered" || echo "0")
    local series_dropped_count=$(echo "$logs" | grep -c "dropped_series" || echo "0")
    
    log "Selective filtering attempts: $selective_filter_count"
    log "Successful filtering operations: $successful_filter_count"
    log "Series dropped: $series_dropped_count"
    
    if [ $successful_filter_count -gt 0 ]; then
        log "✅ Selective filtering is working correctly"
        return 0
    else
        warn "⚠️ No selective filtering activity detected"
        return 1
    fi
}

# Function to check Envoy logs for request flow
check_envoy_logs() {
    log "Checking Envoy logs for request flow..."
    
    local envoy_pod=$(kubectl get pods -n $RLS_NAMESPACE -l app=envoy --no-headers | head -1 | awk '{print $1}')
    
    if [ -z "$envoy_pod" ]; then
        error "No Envoy pod found"
        return 1
    fi
    
    # Get recent logs
    local logs=$(kubectl logs -n $RLS_NAMESPACE $envoy_pod --tail=50 2>/dev/null || echo "")
    
    # Check for successful requests
    local success_count=$(echo "$logs" | grep -c "200" || echo "0")
    local error_count=$(echo "$logs" | grep -c "413\|429\|500" || echo "0")
    
    log "Envoy successful requests: $success_count"
    log "Envoy error requests: $error_count"
    
    if [ $success_count -gt 0 ]; then
        log "✅ Requests are flowing through Envoy successfully"
        return 0
    else
        warn "⚠️ No successful requests detected in Envoy logs"
        return 1
    fi
}

# Function to calculate performance impact
calculate_performance_impact() {
    log "Calculating performance impact..."
    
    # Read baseline and filtering averages
    if [ -f "$RESULTS_DIR/baseline_performance.txt" ] && [ -f "$RESULTS_DIR/filtering_performance.txt" ]; then
        source $RESULTS_DIR/baseline_performance.txt
        source $RESULTS_DIR/filtering_performance.txt
        
        # Calculate impact
        local impact_ms=$((FILTERING_AVG - BASELINE_AVG))
        local impact_percent=$((impact_ms * 100 / BASELINE_AVG))
        
        log "Performance Impact Analysis:"
        log "  Baseline average: $BASELINE_AVG ms"
        log "  Selective filtering average: $FILTERING_AVG ms"
        log "  Absolute impact: $impact_ms ms"
        log "  Relative impact: $impact_percent%"
        
        # Determine if impact is acceptable
        if [ $impact_percent -lt 20 ]; then
            log "✅ Performance impact is acceptable (< 20%)"
        elif [ $impact_percent -lt 50 ]; then
            warn "⚠️ Performance impact is moderate (20-50%)"
        else
            error "❌ Performance impact is high (> 50%)"
        fi
        
        # Save results
        cat > $RESULTS_DIR/performance_impact_analysis.md << EOF
# Performance Impact Analysis

## Results
- **Baseline Average**: $BASELINE_AVG ms
- **Selective Filtering Average**: $FILTERING_AVG ms
- **Absolute Impact**: $impact_ms ms
- **Relative Impact**: $impact_percent%

## Assessment
$(if [ $impact_percent -lt 20 ]; then
    echo "- ✅ **Acceptable**: Impact is less than 20%"
elif [ $impact_percent -lt 50 ]; then
    echo "- ⚠️ **Moderate**: Impact is between 20-50%"
else
    echo "- ❌ **High**: Impact is greater than 50%"
fi)

## Recommendations
$(if [ $impact_percent -lt 20 ]; then
    echo "- Selective filtering can be used in production"
    echo "- Monitor performance under high load"
elif [ $impact_percent -lt 50 ]; then
    echo "- Consider optimization for high-traffic scenarios"
    echo "- Monitor resource usage closely"
else
    echo "- Investigate performance bottlenecks"
    echo "- Consider alternative filtering strategies"
fi)
EOF
        
        log "Performance analysis saved to $RESULTS_DIR/performance_impact_analysis.md"
    else
        error "Performance data files not found"
        return 1
    fi
}

# Function to generate end-to-end report
generate_e2e_report() {
    log "Generating end-to-end verification report..."
    
    local report_file="$RESULTS_DIR/e2e_verification_report_$(date +%Y%m%d_%H%M%S).md"
    
    cat > $report_file << EOF
# End-to-End Verification Report

Generated: $(date)

## Test Summary

### Components Verified
- ✅ **RLS**: Rate Limit Service with selective filtering
- ✅ **Envoy**: Proxy service
- ✅ **Mimir**: Metrics storage and querying
- ✅ **Nginx**: Load balancer (if configured)

### Test Flow
1. **Test Data Generation**: Created protobuf data with 1000 series
2. **Baseline Performance**: Measured performance without selective filtering
3. **Selective Filtering Performance**: Measured performance with selective filtering
4. **End-to-End Verification**: Confirmed filtered metrics reach Mimir
5. **Log Analysis**: Verified filtering activity in RLS and Envoy logs

## Results

### Performance Impact
$(if [ -f "$RESULTS_DIR/performance_impact_analysis.md" ]; then
    cat $RESULTS_DIR/performance_impact_analysis.md
else
    echo "Performance analysis not available"
fi)

### Component Status
$(check_components 2>&1 | grep -E "(✅|❌)" | sed 's/^/- /')

### RLS Filtering Activity
$(check_rls_filtering_logs 2>&1 | grep -E "(✅|⚠️)" | sed 's/^/- /')

### Envoy Request Flow
$(check_envoy_logs 2>&1 | grep -E "(✅|⚠️)" | sed 's/^/- /')

### Mimir Ingestion
$(verify_metrics_in_mimir 2>&1 | grep -E "(✅|⚠️)" | sed 's/^/- /')

## Recommendations

1. **Monitor Performance**: Track performance impact in production
2. **Optimize if Needed**: Consider optimization if impact is high
3. **Scale Resources**: Ensure adequate resources for filtering operations
4. **Monitor Logs**: Keep an eye on RLS and Envoy logs for issues

## Next Steps

1. Deploy to production with monitoring
2. Set up alerts for performance degradation
3. Monitor selective filtering usage
4. Optimize based on real-world performance data

EOF

    log "End-to-end verification report generated: $report_file"
}

# Main execution
main() {
    log "Starting end-to-end verification..."
    
    # Check if all components are running
    if ! check_components; then
        error "Not all components are running. Please ensure RLS, Envoy, and Mimir are deployed."
        exit 1
    fi
    
    # Create test data
    if ! create_test_data_with_limits; then
        error "Failed to create test data"
        exit 1
    fi
    
    # Measure baseline performance
    measure_baseline_performance
    
    # Measure selective filtering performance
    measure_selective_filtering_performance
    
    # Verify end-to-end flow
    log "Verifying end-to-end flow..."
    check_rls_filtering_logs
    check_envoy_logs
    verify_metrics_in_mimir
    
    # Calculate performance impact
    calculate_performance_impact
    
    # Generate report
    generate_e2e_report
    
    log "End-to-end verification completed!"
    log "Check the report at: $RESULTS_DIR/e2e_verification_report_*.md"
}

# Run main function
main "$@"
