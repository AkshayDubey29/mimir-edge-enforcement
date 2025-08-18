#!/bin/bash

# Performance Impact Analysis for Selective Filtering
# This script measures the performance impact of selective filtering vs traditional allow/deny

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RLS_NAMESPACE="mimir-edge-enforcement"
TEST_ITERATIONS=50
PAYLOAD_SIZES=(1024 10240 102400 1048576) # 1KB, 10KB, 100KB, 1MB
RESULTS_FILE="./performance_impact_results.csv"

echo -e "${BLUE}📊 Performance Impact Analysis for Selective Filtering${NC}"
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

# Function to generate test payload
generate_test_payload() {
    local size=$1
    local payload_file="/tmp/test_payload_${size}.bin"
    
    # Generate random data of specified size
    head -c $size /dev/urandom > $payload_file
    echo $payload_file
}

# Function to measure request performance
measure_request_performance() {
    local url=$1
    local payload_file=$2
    local iterations=$3
    
    local times=()
    local success_count=0
    local error_count=0
    
    for i in $(seq 1 $iterations); do
        local start_time=$(date +%s%N)
        
        # Send request
        local response=$(curl -s -w "%{http_code}" -o /dev/null \
            -H "Content-Type: application/x-protobuf" \
            -H "Content-Encoding: snappy" \
            -H "X-Scope-OrgID: test-tenant" \
            --data-binary @$payload_file \
            $url 2>/dev/null || echo "000")
        
        local end_time=$(date +%s%N)
        local duration=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds
        
        times+=($duration)
        
        if [ "$response" = "200" ]; then
            ((success_count++))
        else
            ((error_count++))
        fi
        
        # Small delay between requests
        sleep 0.1
    done
    
    # Calculate statistics
    local total=0
    local min=${times[0]}
    local max=${times[0]}
    
    for time in "${times[@]}"; do
        total=$((total + time))
        if [ $time -lt $min ]; then
            min=$time
        fi
        if [ $time -gt $max ]; then
            max=$time
        fi
    done
    
    local avg=$((total / ${#times[@]}))
    
    echo "$avg,$min,$max,$success_count,$error_count"
}

# Function to test baseline performance (without selective filtering)
test_baseline_performance() {
    log "Testing baseline performance (without selective filtering)..."
    
    # Disable selective filtering
    kubectl patch configmap -n $RLS_NAMESPACE mimir-rls --type='json' -p='[{"op": "replace", "path": "/data/selectiveFiltering.enabled", "value": "false"}]' 2>/dev/null || true
    
    # Restart RLS
    kubectl rollout restart deployment/mimir-rls -n $RLS_NAMESPACE
    kubectl rollout status deployment/mimir-rls -n $RLS_NAMESPACE --timeout=300s
    
    # Wait for RLS to be ready
    sleep 30
    
    # Test each payload size
    for size in "${PAYLOAD_SIZES[@]}"; do
        log "Testing baseline with payload size: $size bytes"
        
        local payload_file=$(generate_test_payload $size)
        local results=$(measure_request_performance "http://localhost:8080/api/v1/push" $payload_file $TEST_ITERATIONS)
        
        echo "baseline,$size,$results" >> $RESULTS_FILE
        
        # Cleanup
        rm -f $payload_file
    done
}

# Function to test selective filtering performance
test_selective_filtering_performance() {
    log "Testing selective filtering performance..."
    
    # Enable selective filtering
    kubectl patch configmap -n $RLS_NAMESPACE mimir-rls --type='json' -p='[{"op": "replace", "path": "/data/selectiveFiltering.enabled", "value": "true"}]' 2>/dev/null || true
    
    # Restart RLS
    kubectl rollout restart deployment/mimir-rls -n $RLS_NAMESPACE
    kubectl rollout status deployment/mimir-rls -n $RLS_NAMESPACE --timeout=300s
    
    # Wait for RLS to be ready
    sleep 30
    
    # Test each payload size
    for size in "${PAYLOAD_SIZES[@]}"; do
        log "Testing selective filtering with payload size: $size bytes"
        
        local payload_file=$(generate_test_payload $size)
        local results=$(measure_request_performance "http://localhost:8080/api/v1/push" $payload_file $TEST_ITERATIONS)
        
        echo "selective_filtering,$size,$results" >> $RESULTS_FILE
        
        # Cleanup
        rm -f $payload_file
    done
}

# Function to analyze results
analyze_results() {
    log "Analyzing performance results..."
    
    # Create analysis report
    local report_file="./performance_impact_analysis_$(date +%Y%m%d_%H%M%S).md"
    
    cat > $report_file << EOF
# Performance Impact Analysis Report

Generated: $(date)

## Test Configuration
- **Test Iterations**: $TEST_ITERATIONS per payload size
- **Payload Sizes**: ${PAYLOAD_SIZES[@]} bytes
- **Test URL**: http://localhost:8080/api/v1/push

## Results Summary

| Payload Size | Mode | Avg (ms) | Min (ms) | Max (ms) | Success Rate | Impact (%) |
|-------------|------|----------|----------|----------|--------------|------------|
EOF

    # Parse results and calculate impact
    local baseline_data=()
    local filtering_data=()
    
    while IFS=',' read -r mode size avg min max success error; do
        if [ "$mode" = "baseline" ]; then
            baseline_data+=("$size:$avg:$min:$max:$success:$error")
        elif [ "$mode" = "selective_filtering" ]; then
            filtering_data+=("$size:$avg:$min:$max:$success:$error")
        fi
    done < $RESULTS_FILE
    
    # Calculate impact for each payload size
    for i in "${!baseline_data[@]}"; do
        IFS=':' read -r size baseline_avg baseline_min baseline_max baseline_success baseline_error <<< "${baseline_data[$i]}"
        IFS=':' read -r size2 filtering_avg filtering_min filtering_max filtering_success filtering_error <<< "${filtering_data[$i]}"
        
        if [ "$size" = "$size2" ]; then
            # Calculate impact
            local impact_ms=$((filtering_avg - baseline_avg))
            local impact_percent=0
            if [ $baseline_avg -gt 0 ]; then
                impact_percent=$((impact_ms * 100 / baseline_avg))
            fi
            
            # Calculate success rates
            local baseline_success_rate=$((baseline_success * 100 / TEST_ITERATIONS))
            local filtering_success_rate=$((filtering_success * 100 / TEST_ITERATIONS))
            
            # Format the row
            printf "| %s bytes | Baseline | %d | %d | %d | %d%% | - |\n" "$size" "$baseline_avg" "$baseline_min" "$baseline_max" "$baseline_success_rate" >> $report_file
            printf "| %s bytes | Selective Filtering | %d | %d | %d | %d%% | %+d%% |\n" "$size" "$filtering_avg" "$filtering_min" "$filtering_max" "$filtering_success_rate" "$impact_percent" >> $report_file
        fi
    done
    
    cat >> $report_file << EOF

## Performance Impact Assessment

### Latency Impact
- **Small Payloads (1-10KB)**: $(if [ $impact_percent -lt 20 ]; then echo "✅ Acceptable"; else echo "⚠️ Moderate"; fi)
- **Medium Payloads (100KB)**: $(if [ $impact_percent -lt 30 ]; then echo "✅ Acceptable"; else echo "⚠️ Moderate"; fi)
- **Large Payloads (1MB+)**: $(if [ $impact_percent -lt 50 ]; then echo "✅ Acceptable"; else echo "⚠️ High"; fi)

### Success Rate Impact
- **Baseline Success Rate**: $baseline_success_rate%
- **Selective Filtering Success Rate**: $filtering_success_rate%
- **Improvement**: $((filtering_success_rate - baseline_success_rate))%

## Recommendations

$(if [ $impact_percent -lt 20 ]; then
    echo "- ✅ **Deploy to Production**: Performance impact is acceptable"
    echo "- 📊 **Monitor**: Track performance under production load"
elif [ $impact_percent -lt 50 ]; then
    echo "- ⚠️ **Optimize**: Consider performance optimizations"
    echo "- 📊 **Monitor Closely**: Watch for performance degradation"
    echo "- 🔧 **Tune Configuration**: Adjust filtering parameters"
else
    echo "- ❌ **Investigate**: Performance impact is too high"
    echo "- 🔧 **Optimize**: Implement performance improvements"
    echo "- 📊 **Test More**: Run additional performance tests"
fi)

## Detailed Results

\`\`\`csv
$(cat $RESULTS_FILE)
\`\`\`

EOF

    log "Performance analysis report generated: $report_file"
}

# Function to create CSV header
create_csv_header() {
    echo "mode,payload_size,avg_ms,min_ms,max_ms,success_count,error_count" > $RESULTS_FILE
}

# Main execution
main() {
    log "Starting performance impact analysis..."
    
    # Create CSV header
    create_csv_header
    
    # Test baseline performance
    test_baseline_performance
    
    # Test selective filtering performance
    test_selective_filtering_performance
    
    # Analyze results
    analyze_results
    
    log "Performance impact analysis completed!"
    log "Check the report for detailed results."
}

# Run main function
main "$@"
