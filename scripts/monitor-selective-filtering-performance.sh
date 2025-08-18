#!/bin/bash

# Monitor Selective Filtering Performance
# This script monitors the performance and effectiveness of RLS selective filtering

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RLS_NAMESPACE="mimir-edge-enforcement"
MONITORING_INTERVAL=30  # seconds
LOG_FILE="./monitoring/selective_filtering_performance.log"
METRICS_FILE="./monitoring/selective_filtering_metrics.csv"

# Create monitoring directory
mkdir -p ./monitoring

echo -e "${BLUE}📊 Monitoring RLS Selective Filtering Performance${NC}"
echo "=================================================="

# Function to log messages
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOG_FILE
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> $LOG_FILE
}

warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: $1" >> $LOG_FILE
}

# Function to get RLS metrics
get_rls_metrics() {
    local metrics=$(kubectl get pods -n $RLS_NAMESPACE -l app=mimir-rls -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -z "$metrics" ]; then
        error "No RLS pod found"
        return 1
    fi
    
    # Get metrics from RLS pod
    kubectl exec -n $RLS_NAMESPACE $metrics -- curl -s http://localhost:9090/metrics 2>/dev/null || echo ""
}

# Function to extract selective filtering metrics
extract_selective_filtering_metrics() {
    local metrics=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Extract key metrics
    local selective_filter_requests=$(echo "$metrics" | grep 'rls_decisions_total{decision="selective_filter"' | awk '{print $2}' | sed 's/}//' || echo "0")
    local traditional_denies=$(echo "$metrics" | grep 'rls_decisions_total{decision="deny"' | awk '{print $2}' | sed 's/}//' || echo "0")
    local traditional_allows=$(echo "$metrics" | grep 'rls_decisions_total{decision="allow"' | awk '{print $2}' | sed 's/}//' || echo "0")
    local series_filtered=$(echo "$metrics" | grep 'rls_series_count_gauge' | awk '{print $2}' | sed 's/}//' || echo "0")
    local samples_filtered=$(echo "$metrics" | grep 'rls_samples_count_gauge' | awk '{print $2}' | sed 's/}//' || echo "0")
    local authz_check_duration=$(echo "$metrics" | grep 'rls_authz_check_duration_seconds_sum' | awk '{print $2}' | sed 's/}//' || echo "0")
    
    # Calculate percentages
    local total_requests=$((selective_filter_requests + traditional_denies + traditional_allows))
    local selective_filter_percentage=0
    if [ $total_requests -gt 0 ]; then
        selective_filter_percentage=$((selective_filter_requests * 100 / total_requests))
    fi
    
    # Write to CSV file
    echo "$timestamp,$selective_filter_requests,$traditional_denies,$traditional_allows,$series_filtered,$samples_filtered,$authz_check_duration,$selective_filter_percentage" >> $METRICS_FILE
    
    # Log current metrics
    log "Selective Filter Requests: $selective_filter_requests"
    log "Traditional Denies: $traditional_denies"
    log "Traditional Allows: $traditional_allows"
    log "Series Filtered: $series_filtered"
    log "Samples Filtered: $samples_filtered"
    log "Authz Check Duration: $authz_check_duration seconds"
    log "Selective Filter Usage: $selective_filter_percentage%"
    
    return 0
}

# Function to check RLS logs for filtering activity
check_rls_logs() {
    local rls_pod=$(kubectl get pods -n $RLS_NAMESPACE -l app=mimir-rls -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -z "$rls_pod" ]; then
        error "No RLS pod found"
        return 1
    fi
    
    # Get recent logs
    local logs=$(kubectl logs -n $RLS_NAMESPACE $rls_pod --tail=50 2>/dev/null || echo "")
    
    # Count selective filtering messages
    local selective_filter_count=$(echo "$logs" | grep -c "selective_filter_applied" || echo "0")
    local successful_filter_count=$(echo "$logs" | grep -c "Successfully filtered" || echo "0")
    local error_count=$(echo "$logs" | grep -c "ERROR" || echo "0")
    
    log "Selective Filter Messages: $selective_filter_count"
    log "Successful Filtering Operations: $successful_filter_count"
    log "Error Count: $error_count"
    
    # Check for specific filtering types
    local per_user_filter_count=$(echo "$logs" | grep -c "dropped excess series" || echo "0")
    local per_metric_filter_count=$(echo "$logs" | grep -c "dropped excess metric series" || echo "0")
    local label_filter_count=$(echo "$logs" | grep -c "dropped series with excess labels" || echo "0")
    
    log "Per-User Series Filtering: $per_user_filter_count"
    log "Per-Metric Series Filtering: $per_metric_filter_count"
    log "Label-Based Filtering: $label_filter_count"
}

# Function to check performance indicators
check_performance_indicators() {
    local rls_pod=$(kubectl get pods -n $RLS_NAMESPACE -l app=mimir-rls -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -z "$rls_pod" ]; then
        error "No RLS pod found"
        return 1
    fi
    
    # Get pod resource usage
    local cpu_usage=$(kubectl top pod -n $RLS_NAMESPACE $rls_pod --no-headers 2>/dev/null | awk '{print $2}' || echo "N/A")
    local memory_usage=$(kubectl top pod -n $RLS_NAMESPACE $rls_pod --no-headers 2>/dev/null | awk '{print $3}' || echo "N/A")
    
    log "CPU Usage: $cpu_usage"
    log "Memory Usage: $memory_usage"
    
    # Check pod status
    local pod_status=$(kubectl get pod -n $RLS_NAMESPACE $rls_pod -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    log "Pod Status: $pod_status"
    
    # Check restart count
    local restart_count=$(kubectl get pod -n $RLS_NAMESPACE $rls_pod -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || echo "0")
    log "Restart Count: $restart_count"
}

# Function to generate performance report
generate_performance_report() {
    local report_file="./monitoring/performance_report_$(date +%Y%m%d_%H%M%S).md"
    
    cat > $report_file << EOF
# RLS Selective Filtering Performance Report

Generated: $(date)

## Performance Summary

### Metrics Overview
- **Monitoring Duration**: $MONITORING_INTERVAL seconds
- **Log File**: $LOG_FILE
- **Metrics File**: $METRICS_FILE

### Key Performance Indicators

#### Selective Filtering Usage
$(if [ -f "$METRICS_FILE" ]; then
    echo "| Timestamp | Selective Filter Requests | Traditional Denies | Traditional Allows | Selective Filter % |"
    echo "|-----------|---------------------------|-------------------|-------------------|-------------------|"
    tail -n 5 "$METRICS_FILE" | while IFS=',' read -r timestamp sf_requests t_denies t_allows sf_percentage; do
        echo "| $timestamp | $sf_requests | $t_denies | $t_allows | $sf_percentage% |"
    done
else
    echo "No metrics data available"
fi)

#### Resource Usage
$(check_performance_indicators 2>&1 | grep -E "(CPU|Memory|Status)" | sed 's/^/- /')

#### Filtering Activity
$(check_rls_logs 2>&1 | grep -E "(Filter|Error)" | sed 's/^/- /')

## Recommendations

1. **Monitor Selective Filter Usage**: Track the percentage of requests using selective filtering
2. **Resource Optimization**: Monitor CPU and memory usage during filtering operations
3. **Error Rate Monitoring**: Watch for errors in selective filtering operations
4. **Performance Tuning**: Adjust filtering strategies based on performance metrics

## Alerts

- **High Error Rate**: If error count > 10% of total operations
- **Low Selective Filter Usage**: If selective filter usage < 5%
- **High Resource Usage**: If CPU > 80% or Memory > 80%
- **Pod Restarts**: If restart count increases

EOF

    log "Performance report generated: $report_file"
}

# Function to initialize monitoring
initialize_monitoring() {
    log "Initializing selective filtering performance monitoring..."
    
    # Create CSV header
    echo "Timestamp,SelectiveFilterRequests,TraditionalDenies,TraditionalAllows,SeriesFiltered,SamplesFiltered,AuthzCheckDuration,SelectiveFilterPercentage" > $METRICS_FILE
    
    log "Monitoring initialized. Metrics will be collected every $MONITORING_INTERVAL seconds."
    log "Log file: $LOG_FILE"
    log "Metrics file: $METRICS_FILE"
}

# Function to run monitoring loop
run_monitoring_loop() {
    local iteration=1
    
    while true; do
        log "=== Monitoring Iteration $iteration ==="
        
        # Get RLS metrics
        local metrics=$(get_rls_metrics)
        if [ $? -eq 0 ]; then
            extract_selective_filtering_metrics "$metrics"
        else
            error "Failed to get RLS metrics"
        fi
        
        # Check RLS logs
        check_rls_logs
        
        # Check performance indicators
        check_performance_indicators
        
        # Generate report every 10 iterations
        if [ $((iteration % 10)) -eq 0 ]; then
            generate_performance_report
        fi
        
        log "Waiting $MONITORING_INTERVAL seconds before next check..."
        sleep $MONITORING_INTERVAL
        
        ((iteration++))
    done
}

# Function to show real-time monitoring
show_real_time_monitoring() {
    log "Starting real-time monitoring..."
    
    # Clear screen
    clear
    
    while true; do
        # Get current metrics
        local metrics=$(get_rls_metrics)
        if [ $? -eq 0 ]; then
            local timestamp=$(date '+%H:%M:%S')
            
            # Extract key metrics
            local selective_filter_requests=$(echo "$metrics" | grep 'rls_decisions_total{decision="selective_filter"' | awk '{print $2}' | sed 's/}//' || echo "0")
            local traditional_denies=$(echo "$metrics" | grep 'rls_decisions_total{decision="deny"' | awk '{print $2}' | sed 's/}//' || echo "0")
            local traditional_allows=$(echo "$metrics" | grep 'rls_decisions_total{decision="allow"' | awk '{print $2}' | sed 's/}//' || echo "0")
            
            # Calculate percentage
            local total_requests=$((selective_filter_requests + traditional_denies + traditional_allows))
            local selective_filter_percentage=0
            if [ $total_requests -gt 0 ]; then
                selective_filter_percentage=$((selective_filter_requests * 100 / total_requests))
            fi
            
            # Display real-time dashboard
            clear
            echo -e "${BLUE}🔄 RLS Selective Filtering - Real-Time Monitor${NC}"
            echo "=================================================="
            echo -e "${GREEN}Time: $timestamp${NC}"
            echo ""
            echo -e "${YELLOW}Requests:${NC}"
            echo "  Selective Filter: $selective_filter_requests"
            echo "  Traditional Deny: $traditional_denies"
            echo "  Traditional Allow: $traditional_allows"
            echo "  Total: $total_requests"
            echo ""
            echo -e "${YELLOW}Selective Filter Usage:${NC} $selective_filter_percentage%"
            echo ""
            echo -e "${YELLOW}Press Ctrl+C to exit${NC}"
        else
            echo -e "${RED}Failed to get metrics${NC}"
        fi
        
        sleep 5
    done
}

# Main execution
main() {
    case "${1:-monitor}" in
        "init")
            initialize_monitoring
            ;;
        "monitor")
            initialize_monitoring
            run_monitoring_loop
            ;;
        "realtime")
            show_real_time_monitoring
            ;;
        "report")
            generate_performance_report
            ;;
        *)
            echo "Usage: $0 {init|monitor|realtime|report}"
            echo ""
            echo "Commands:"
            echo "  init     - Initialize monitoring files"
            echo "  monitor  - Run continuous monitoring (default)"
            echo "  realtime - Show real-time monitoring dashboard"
            echo "  report   - Generate performance report"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
