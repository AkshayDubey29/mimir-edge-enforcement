#!/bin/bash

# RLS Request Pattern Analysis Script
# This script analyzes RLS logs for request patterns, compression ratios, and processing statistics

set -e

echo "🔍 RLS Request Pattern Analysis Tool"
echo "===================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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
        "DEBUG") echo -e "${CYAN}🔍 $message${NC}" ;;
        "HEADER") echo -e "${PURPLE}📊 $message${NC}" ;;
    esac
}

# Function to get RLS pod name
get_rls_pod() {
    local pod=$(kubectl get pods -n mimir-edge-enforcement | grep rls | grep Running | head -n1 | awk '{print $1}')
    if [ -z "$pod" ]; then
        print_status "ERROR" "No running RLS pods found"
        exit 1
    fi
    echo $pod
}

# Function to analyze request processing patterns
analyze_request_processing() {
    print_status "HEADER" "Request Processing Analysis"
    echo ""
    
    local pod=$(get_rls_pod)
    print_status "INFO" "Analyzing RLS pod: $pod"
    
    # Get recent logs
    local recent_logs=$(kubectl logs -n mimir-edge-enforcement $pod --tail=1000)
    
    # Count different types of processing
    local parse_calls=$(echo "$recent_logs" | grep -c "ParseRemoteWriteRequest called" || echo "0")
    local decompress_calls=$(echo "$recent_logs" | grep -c "decompress called" || echo "0")
    local snappy_decompression=$(echo "$recent_logs" | grep -c "Attempting snappy decompression" || echo "0")
    local decompressed_sizes=$(echo "$recent_logs" | grep -c "Decompressed body size" || echo "0")
    
    print_status "INFO" "Processing Statistics:"
    echo "  - ParseRemoteWriteRequest calls: $parse_calls"
    echo "  - Decompress calls: $decompress_calls"
    echo "  - Snappy decompression attempts: $snappy_decompression"
    echo "  - Successfully decompressed: $decompressed_sizes"
    echo ""
}

# Function to analyze compression ratios
analyze_compression_ratios() {
    print_status "HEADER" "Compression Ratio Analysis"
    echo ""
    
    local pod=$(get_rls_pod)
    
    # Extract compression data
    local compression_data=$(kubectl logs -n mimir-edge-enforcement $pod --tail=1000 | \
        grep -E "(ParseRemoteWriteRequest called|Decompressed body size)" | \
        grep -v "Unexpected snappy frame header")
    
    if [ -n "$compression_data" ]; then
        print_status "SUCCESS" "Found compression data:"
        echo ""
        
        # Parse and analyze compression ratios
        echo "$compression_data" | while read line; do
            if echo "$line" | grep -q "ParseRemoteWriteRequest called"; then
                # Extract original size
                local original_size=$(echo "$line" | grep -o "body size: [0-9]*" | awk '{print $3}')
                echo "Original: ${original_size} bytes"
            elif echo "$line" | grep -q "Decompressed body size"; then
                # Extract decompressed size
                local decompressed_size=$(echo "$line" | grep -o "Decompressed body size: [0-9]*" | awk '{print $4}')
                local original_size=$(echo "$line" | grep -o "original: [0-9]*" | awk '{print $2}')
                
                if [ -n "$decompressed_size" ] && [ -n "$original_size" ] && [ "$original_size" -gt 0 ]; then
                    local ratio=$(echo "scale=2; $decompressed_size / $original_size" | bc -l 2>/dev/null || echo "N/A")
                    local original_mb=$(echo "scale=2; $original_size / 1024 / 1024" | bc -l 2>/dev/null || echo "N/A")
                    local decompressed_mb=$(echo "scale=2; $decompressed_size / 1024 / 1024" | bc -l 2>/dev/null || echo "N/A")
                    
                    echo "  Decompressed: ${decompressed_size} bytes (${decompressed_mb}MB)"
                    echo "  Compression ratio: ${ratio}x"
                    echo "  ---"
                fi
            fi
        done
    else
        print_status "INFO" "No compression data found"
    fi
    echo ""
}

# Function to analyze request size distribution
analyze_size_distribution() {
    print_status "HEADER" "Request Size Distribution"
    echo ""
    
    local pod=$(get_rls_pod)
    
    # Extract all body sizes
    local body_sizes=$(kubectl logs -n mimir-edge-enforcement $pod --tail=1000 | \
        grep -E "(body size: [0-9]+|Decompressed body size: [0-9]+)" | \
        grep -o '[0-9]*' | sort -n)
    
    if [ -n "$body_sizes" ]; then
        print_status "SUCCESS" "Size distribution analysis:"
        echo ""
        
        # Calculate statistics
        local count=$(echo "$body_sizes" | wc -l)
        local min=$(echo "$body_sizes" | head -n1)
        local max=$(echo "$body_sizes" | tail -n1)
        local avg=$(echo "$body_sizes" | awk '{sum+=$1} END {print sum/NR}')
        
        echo "  Total requests analyzed: $count"
        echo "  Minimum size: ${min} bytes"
        echo "  Maximum size: ${max} bytes"
        echo "  Average size: ${avg} bytes"
        echo ""
        
        # Size buckets
        echo "Size buckets:"
        echo "  < 1KB: $(echo "$body_sizes" | awk '$1 < 1024' | wc -l)"
        echo "  1KB - 10KB: $(echo "$body_sizes" | awk '$1 >= 1024 && $1 < 10240' | wc -l)"
        echo "  10KB - 100KB: $(echo "$body_sizes" | awk '$1 >= 10240 && $1 < 102400' | wc -l)"
        echo "  100KB - 1MB: $(echo "$body_sizes" | awk '$1 >= 102400 && $1 < 1048576' | wc -l)"
        echo "  1MB - 10MB: $(echo "$body_sizes" | awk '$1 >= 1048576 && $1 < 10485760' | wc -l)"
        echo "  > 10MB: $(echo "$body_sizes" | awk '$1 >= 10485760' | wc -l)"
        echo ""
    else
        print_status "INFO" "No size data found"
    fi
}

# Function to analyze content encoding patterns
analyze_content_encoding() {
    print_status "HEADER" "Content Encoding Analysis"
    echo ""
    
    local pod=$(get_rls_pod)
    
    # Extract content encoding information
    local encoding_data=$(kubectl logs -n mimir-edge-enforcement $pod --tail=1000 | \
        grep -E "content encoding:" | sort | uniq -c)
    
    if [ -n "$encoding_data" ]; then
        print_status "SUCCESS" "Content encoding distribution:"
        echo "$encoding_data"
        echo ""
    else
        print_status "INFO" "No content encoding data found"
    fi
}

# Function to analyze snappy frame headers
analyze_snappy_headers() {
    print_status "HEADER" "Snappy Frame Header Analysis"
    echo ""
    
    local pod=$(get_rls_pod)
    
    # Extract snappy frame header information
    local header_data=$(kubectl logs -n mimir-edge-enforcement $pod --tail=1000 | \
        grep "Unexpected snappy frame header" | sort | uniq -c)
    
    if [ -n "$header_data" ]; then
        print_status "SUCCESS" "Snappy frame header distribution:"
        echo "$header_data"
        echo ""
        
        # Analyze if this is normal or concerning
        local total_headers=$(echo "$header_data" | awk '{sum+=$1} END {print sum}')
        print_status "INFO" "Total snappy frame headers processed: $total_headers"
        
        if [ "$total_headers" -gt 0 ]; then
            print_status "INFO" "Note: 'Unexpected' snappy frame headers are normal for snappy compression"
        fi
    else
        print_status "INFO" "No snappy frame header data found"
    fi
}

# Function to analyze processing errors
analyze_processing_errors() {
    print_status "HEADER" "Processing Error Analysis"
    echo ""
    
    local pod=$(get_rls_pod)
    
    # Look for processing errors
    local error_patterns=(
        "error"
        "failed"
        "failed to"
        "parse.*error"
        "decompress.*error"
        "unexpected.*error"
    )
    
    local found_errors=false
    
    for pattern in "${error_patterns[@]}"; do
        local matches=$(kubectl logs -n mimir-edge-enforcement $pod --tail=1000 | \
            grep -i "$pattern" | grep -v "Unexpected snappy frame header" | wc -l)
        
        if [ $matches -gt 0 ]; then
            if [ "$found_errors" = false ]; then
                print_status "WARNING" "Found processing errors:"
                found_errors=true
            fi
            
            echo "  Pattern '$pattern': $matches occurrences"
            
            # Show recent examples
            kubectl logs -n mimir-edge-enforcement $pod --tail=1000 | \
                grep -i "$pattern" | grep -v "Unexpected snappy frame header" | \
                tail -n2 | while read line; do
                    echo "    $line"
                done
        fi
    done
    
    if [ "$found_errors" = false ]; then
        print_status "SUCCESS" "No processing errors found"
    fi
    echo ""
}

# Function to provide real-time monitoring
real_time_monitoring() {
    print_status "HEADER" "Real-time Request Processing Monitoring"
    echo ""
    
    local pod=$(get_rls_pod)
    
    print_status "INFO" "Starting real-time monitoring of RLS request processing..."
    print_status "INFO" "Press Ctrl+C to stop monitoring"
    echo ""
    
    # Monitor logs in real-time
    kubectl logs -n mimir-edge-enforcement $pod -f | \
        grep -E "(ParseRemoteWriteRequest called|Decompressed body size|decompress called)" | \
        while read line; do
            timestamp=$(date '+%H:%M:%S')
            echo "[$timestamp] $line"
        done
}

# Function to provide summary statistics
summary_statistics() {
    print_status "HEADER" "Summary Statistics"
    echo ""
    
    local pod=$(get_rls_pod)
    
    # Get recent logs
    local recent_logs=$(kubectl logs -n mimir-edge-enforcement $pod --tail=1000)
    
    # Calculate statistics
    local total_requests=$(echo "$recent_logs" | grep -c "ParseRemoteWriteRequest called" || echo "0")
    local total_decompressed=$(echo "$recent_logs" | grep -c "Decompressed body size" || echo "0")
    local total_errors=$(echo "$recent_logs" | grep -i "error" | grep -v "Unexpected snappy frame header" | wc -l)
    
    # Calculate average compression ratio
    local compression_ratios=$(echo "$recent_logs" | \
        grep -E "Decompressed body size: [0-9]+.*original: [0-9]+" | \
        awk '{if($6 > 0) print $4/$6}' | head -n10)
    
    local avg_ratio="N/A"
    if [ -n "$compression_ratios" ]; then
        avg_ratio=$(echo "$compression_ratios" | awk '{sum+=$1} END {if(NR>0) print sum/NR; else print "N/A"}')
    fi
    
    print_status "INFO" "Processing Summary:"
    echo "  - Total requests processed: $total_requests"
    echo "  - Successfully decompressed: $total_decompressed"
    echo "  - Processing errors: $total_errors"
    echo "  - Average compression ratio: ${avg_ratio}x"
    echo ""
    
    if [ $total_requests -gt 0 ]; then
        local success_rate=$(echo "scale=2; $total_decompressed * 100 / $total_requests" | bc -l 2>/dev/null || echo "N/A")
        echo "  - Success rate: ${success_rate}%"
    fi
    echo ""
}

# Main execution
main() {
    case "${1:-all}" in
        "processing")
            analyze_request_processing
            ;;
        "compression")
            analyze_compression_ratios
            ;;
        "sizes")
            analyze_size_distribution
            ;;
        "encoding")
            analyze_content_encoding
            ;;
        "headers")
            analyze_snappy_headers
            ;;
        "errors")
            analyze_processing_errors
            ;;
        "monitor")
            real_time_monitoring
            ;;
        "summary")
            summary_statistics
            ;;
        "all")
            analyze_request_processing
            analyze_compression_ratios
            analyze_size_distribution
            analyze_content_encoding
            analyze_snappy_headers
            analyze_processing_errors
            summary_statistics
            ;;
        *)
            echo "Usage: $0 [processing|compression|sizes|encoding|headers|errors|monitor|summary|all]"
            echo ""
            echo "Options:"
            echo "  processing   - Analyze request processing patterns"
            echo "  compression  - Analyze compression ratios"
            echo "  sizes        - Analyze request size distribution"
            echo "  encoding     - Analyze content encoding patterns"
            echo "  headers      - Analyze snappy frame headers"
            echo "  errors       - Analyze processing errors"
            echo "  monitor      - Real-time monitoring"
            echo "  summary      - Summary statistics"
            echo "  all          - Run all analyses (default)"
            ;;
    esac
}

# Run main function
main "$@"
