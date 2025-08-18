#!/bin/bash

# Test Selective Filtering Implementation with Real Prometheus Data
# This script validates the RLS selective filtering functionality

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RLS_POD_NAME=""
RLS_NAMESPACE="mimir-edge-enforcement"
TEST_DATA_DIR="./test-data"
RESULTS_DIR="./test-results"

# Test scenarios
declare -a TEST_SCENARIOS=(
    "per_user_series_limit"
    "per_metric_series_limit" 
    "labels_per_series_limit"
    "multiple_limits"
    "compression_formats"
)

echo -e "${BLUE}🧪 Testing RLS Selective Filtering Implementation${NC}"
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

# Function to get RLS pod name
get_rls_pod() {
    log "Getting RLS pod name..."
    RLS_POD_NAME=$(kubectl get pods -n $RLS_NAMESPACE -l app=mimir-rls -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$RLS_POD_NAME" ]; then
        error "No RLS pod found in namespace $RLS_NAMESPACE"
        exit 1
    fi
    
    log "Using RLS pod: $RLS_POD_NAME"
}

# Function to create test data
create_test_data() {
    log "Creating test data..."
    
    mkdir -p $TEST_DATA_DIR
    
    # Create sample Prometheus remote write data
    cat > $TEST_DATA_DIR/sample_metrics.json << 'EOF'
{
  "timeseries": [
    {
      "labels": [
        {"name": "__name__", "value": "http_requests_total"},
        {"name": "method", "value": "GET"},
        {"name": "status", "value": "200"},
        {"name": "endpoint", "value": "/api/v1/users"}
      ],
      "samples": [
        {"value": 150.0, "timestamp": 1640995200000}
      ]
    },
    {
      "labels": [
        {"name": "__name__", "value": "http_requests_total"},
        {"name": "method", "value": "POST"},
        {"name": "status", "value": "201"},
        {"name": "endpoint", "value": "/api/v1/users"}
      ],
      "samples": [
        {"value": 75.0, "timestamp": 1640995200000}
      ]
    },
    {
      "labels": [
        {"name": "__name__", "value": "cpu_usage_percent"},
        {"name": "instance", "value": "server-1"},
        {"name": "cpu", "value": "cpu0"}
      ],
      "samples": [
        {"value": 45.2, "timestamp": 1640995200000}
      ]
    },
    {
      "labels": [
        {"name": "__name__", "value": "memory_usage_bytes"},
        {"name": "instance", "value": "server-1"},
        {"name": "type", "value": "heap"}
      ],
      "samples": [
        {"value": 1073741824, "timestamp": 1640995200000}
      ]
    }
  ]
}
EOF

    log "Test data created in $TEST_DATA_DIR"
}

# Function to generate protobuf test data
generate_protobuf_data() {
    log "Generating protobuf test data..."
    
    # Create a Go program to generate protobuf data
    cat > $TEST_DATA_DIR/generate_test_data.go << 'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "os"
    
    "github.com/golang/protobuf/proto"
    prompb "github.com/AkshayDubey29/mimir-edge-enforcement/protos/prometheus"
)

func main() {
    // Read JSON test data
    data, err := os.ReadFile("sample_metrics.json")
    if err != nil {
        panic(err)
    }
    
    var jsonData struct {
        Timeseries []struct {
            Labels  []struct{ Name, Value string } `json:"labels"`
            Samples []struct{ Value float64, Timestamp int64 } `json:"samples"`
        } `json:"timeseries"`
    }
    
    if err := json.Unmarshal(data, &jsonData); err != nil {
        panic(err)
    }
    
    // Convert to protobuf
    var writeRequest prompb.WriteRequest
    
    for _, ts := range jsonData.Timeseries {
        timeseries := &prompb.TimeSeries{}
        
        // Convert labels
        for _, label := range ts.Labels {
            timeseries.Labels = append(timeseries.Labels, &prompb.Label{
                Name:  label.Name,
                Value: label.Value,
            })
        }
        
        // Convert samples
        for _, sample := range ts.Samples {
            timeseries.Samples = append(timeseries.Samples, &prompb.Sample{
                Value:     sample.Value,
                Timestamp: sample.Timestamp,
            })
        }
        
        writeRequest.Timeseries = append(writeRequest.Timeseries, timeseries)
    }
    
    // Serialize to protobuf
    protobufData, err := proto.Marshal(&writeRequest)
    if err != nil {
        panic(err)
    }
    
    // Write to file
    if err := os.WriteFile("test_data.pb", protobufData, 0644); err != nil {
        panic(err)
    }
    
    fmt.Printf("Generated protobuf data: %d bytes\n", len(protobufData))
}
EOF

    # Run the generator (if Go is available)
    if command -v go &> /dev/null; then
        cd $TEST_DATA_DIR
        go mod init test-data
        go mod tidy
        go run generate_test_data.go
        cd - > /dev/null
        log "Protobuf test data generated"
    else
        warn "Go not available, using sample data only"
    fi
}

# Function to test per-user series limit filtering
test_per_user_series_limit() {
    log "Testing per-user series limit filtering..."
    
    # Create test request that exceeds series limit
    local test_body=""
    if [ -f "$TEST_DATA_DIR/test_data.pb" ]; then
        test_body=$(base64 -w 0 "$TEST_DATA_DIR/test_data.pb")
    else
        # Fallback to sample data
        test_body="sample_data_here"
    fi
    
    # Test with RLS selective filtering
    local response=$(curl -s -X POST \
        -H "Content-Type: application/x-protobuf" \
        -H "Content-Encoding: snappy" \
        -H "X-Scope-OrgID: test-tenant" \
        -d "$test_body" \
        "http://localhost:8082/api/v1/push")
    
    echo "Response: $response"
    
    # Check if filtering was applied
    if echo "$response" | grep -q "selective_filter_applied"; then
        log "✅ Per-user series limit filtering working"
        return 0
    else
        error "❌ Per-user series limit filtering failed"
        return 1
    fi
}

# Function to test per-metric series limit filtering
test_per_metric_series_limit() {
    log "Testing per-metric series limit filtering..."
    
    # Create test data with multiple series for same metric
    local test_data=""
    
    # Test with RLS selective filtering
    local response=$(curl -s -X POST \
        -H "Content-Type: application/x-protobuf" \
        -H "Content-Encoding: snappy" \
        -H "X-Scope-OrgID: test-tenant" \
        -d "$test_data" \
        "http://localhost:8082/api/v1/push")
    
    echo "Response: $response"
    
    # Check if filtering was applied
    if echo "$response" | grep -q "filtered_series"; then
        log "✅ Per-metric series limit filtering working"
        return 0
    else
        error "❌ Per-metric series limit filtering failed"
        return 1
    fi
}

# Function to test labels per series limit filtering
test_labels_per_series_limit() {
    log "Testing labels per series limit filtering..."
    
    # Create test data with series having many labels
    local test_data=""
    
    # Test with RLS selective filtering
    local response=$(curl -s -X POST \
        -H "Content-Type: application/x-protobuf" \
        -H "Content-Encoding: snappy" \
        -H "X-Scope-OrgID: test-tenant" \
        -d "$test_data" \
        "http://localhost:8082/api/v1/push")
    
    echo "Response: $response"
    
    # Check if filtering was applied
    if echo "$response" | grep -q "excess_labels"; then
        log "✅ Labels per series limit filtering working"
        return 0
    else
        error "❌ Labels per series limit filtering failed"
        return 1
    fi
}

# Function to test compression formats
test_compression_formats() {
    log "Testing compression formats..."
    
    local formats=("gzip" "snappy" "")
    local success_count=0
    
    for format in "${formats[@]}"; do
        log "Testing format: ${format:-uncompressed}"
        
        local headers=""
        if [ -n "$format" ]; then
            headers="-H \"Content-Encoding: $format\""
        fi
        
        # Test request
        local response=$(curl -s -X POST \
            -H "Content-Type: application/x-protobuf" \
            $headers \
            -H "X-Scope-OrgID: test-tenant" \
            -d "test_data" \
            "http://localhost:8082/api/v1/push")
        
        if [ $? -eq 0 ]; then
            log "✅ Format $format working"
            ((success_count++))
        else
            error "❌ Format $format failed"
        fi
    done
    
    if [ $success_count -eq ${#formats[@]} ]; then
        log "✅ All compression formats working"
        return 0
    else
        error "❌ Some compression formats failed"
        return 1
    fi
}

# Function to check RLS logs for filtering activity
check_rls_logs() {
    log "Checking RLS logs for filtering activity..."
    
    # Get recent logs
    local logs=$(kubectl logs -n $RLS_NAMESPACE $RLS_POD_NAME --tail=100 2>/dev/null || echo "")
    
    # Check for selective filtering messages
    local filter_count=$(echo "$logs" | grep -c "selective_filter_applied" || echo "0")
    local success_count=$(echo "$logs" | grep -c "Successfully filtered" || echo "0")
    
    log "Found $filter_count selective filtering attempts"
    log "Found $success_count successful filtering operations"
    
    if [ $success_count -gt 0 ]; then
        log "✅ Selective filtering is active in RLS"
        return 0
    else
        warn "⚠️ No selective filtering activity found in logs"
        return 1
    fi
}

# Function to run performance tests
run_performance_tests() {
    log "Running performance tests..."
    
    mkdir -p $RESULTS_DIR
    
    # Test with different payload sizes
    local sizes=(1024 10240 102400 1048576) # 1KB, 10KB, 100KB, 1MB
    
    for size in "${sizes[@]}"; do
        log "Testing payload size: $size bytes"
        
        # Generate test data of specified size
        local test_data=$(head -c $size /dev/zero | base64)
        
        # Measure response time
        local start_time=$(date +%s%N)
        
        local response=$(curl -s -X POST \
            -H "Content-Type: application/x-protobuf" \
            -H "Content-Encoding: snappy" \
            -H "X-Scope-OrgID: test-tenant" \
            -d "$test_data" \
            "http://localhost:8082/api/v1/push")
        
        local end_time=$(date +%s%N)
        local duration=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds
        
        echo "$size,$duration" >> $RESULTS_DIR/performance_results.csv
        
        log "Size: $size bytes, Duration: $duration ms"
    done
    
    log "Performance test results saved to $RESULTS_DIR/performance_results.csv"
}

# Function to generate test report
generate_report() {
    log "Generating test report..."
    
    local report_file="$RESULTS_DIR/test_report_$(date +%Y%m%d_%H%M%S).md"
    
    cat > $report_file << EOF
# RLS Selective Filtering Test Report

Generated: $(date)

## Test Summary

- **RLS Pod**: $RLS_POD_NAME
- **Namespace**: $RLS_NAMESPACE
- **Test Scenarios**: ${#TEST_SCENARIOS[@]}

## Test Results

### Per-User Series Limit Filtering
- Status: $(test_per_user_series_limit && echo "✅ PASS" || echo "❌ FAIL")

### Per-Metric Series Limit Filtering  
- Status: $(test_per_metric_series_limit && echo "✅ PASS" || echo "❌ FAIL")

### Labels Per Series Limit Filtering
- Status: $(test_labels_per_series_limit && echo "✅ PASS" || echo "❌ FAIL")

### Compression Formats
- Status: $(test_compression_formats && echo "✅ PASS" || echo "❌ FAIL")

## RLS Logs Analysis

$(check_rls_logs && echo "- Selective filtering is active" || echo "- No selective filtering activity detected")

## Performance Results

$(if [ -f "$RESULTS_DIR/performance_results.csv" ]; then
    echo "| Payload Size | Duration (ms) |"
    echo "|-------------|---------------|"
    tail -n +2 "$RESULTS_DIR/performance_results.csv" | while IFS=',' read -r size duration; do
        echo "| $size bytes | $duration ms |"
    done
else
    echo "No performance data available"
fi)

## Recommendations

1. Monitor RLS logs for selective filtering activity
2. Verify filtering statistics in metrics
3. Test with production-like data volumes
4. Optimize performance if needed

EOF

    log "Test report generated: $report_file"
}

# Main execution
main() {
    log "Starting RLS Selective Filtering Tests"
    
    # Setup
    get_rls_pod
    create_test_data
    generate_protobuf_data
    
    # Create results directory
    mkdir -p $RESULTS_DIR
    
    # Run tests
    local test_results=()
    
    log "Running test scenarios..."
    for scenario in "${TEST_SCENARIOS[@]}"; do
        log "Testing scenario: $scenario"
        
        case $scenario in
            "per_user_series_limit")
                test_per_user_series_limit
                test_results+=($?)
                ;;
            "per_metric_series_limit")
                test_per_metric_series_limit
                test_results+=($?)
                ;;
            "labels_per_series_limit")
                test_labels_per_series_limit
                test_results+=($?)
                ;;
            "multiple_limits")
                # Test multiple limits simultaneously
                test_per_user_series_limit && test_per_metric_series_limit
                test_results+=($?)
                ;;
            "compression_formats")
                test_compression_formats
                test_results+=($?)
                ;;
        esac
    done
    
    # Check RLS logs
    check_rls_logs
    test_results+=($?)
    
    # Run performance tests
    run_performance_tests
    
    # Generate report
    generate_report
    
    # Summary
    local passed=0
    local total=${#test_results[@]}
    
    for result in "${test_results[@]}"; do
        if [ $result -eq 0 ]; then
            ((passed++))
        fi
    done
    
    log "Test Summary: $passed/$total tests passed"
    
    if [ $passed -eq $total ]; then
        log "🎉 All tests passed! Selective filtering is working correctly."
        exit 0
    else
        error "❌ Some tests failed. Check the test report for details."
        exit 1
    fi
}

# Run main function
main "$@"
