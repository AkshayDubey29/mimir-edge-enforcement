#!/bin/bash

# Test Realistic Pipeline with Monitoring
# This script tests the complete pipeline: nginx → envoy → rls → mimir
# with realistic traffic patterns and monitors for 413 errors

set -e

echo "🔍 Testing Complete Pipeline with Realistic Traffic Patterns"
echo "=========================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NGINX_SERVICE="mimir-nginx.mimir.svc.cluster.local:8080"
ENVOY_SERVICE="mimir-envoy.mimir-edge-enforcement.svc.cluster.local:8080"
RLS_SERVICE="mimir-rls.mimir-edge-enforcement.svc.cluster.local:8082"
MIMIR_SERVICE="mimir-distributor.mimir.svc.cluster.local:8080"

# Test parameters
CONCURRENCY=5
DURATION=120  # 2 minutes
REQUESTS_PER_SEC=10
TENANTS=("tenant-1" "tenant-2" "tenant-3")

echo -e "${BLUE}📋 Test Configuration:${NC}"
echo "  Concurrency: $CONCURRENCY"
echo "  Duration: ${DURATION}s"
echo "  Requests/sec: $REQUESTS_PER_SEC"
echo "  Tenants: ${TENANTS[*]}"
echo ""

# Function to check service health
check_service_health() {
    local service_name=$1
    local service_url=$2
    local description=$3
    
    echo -e "${BLUE}🔍 Checking $description...${NC}"
    
    # Try to connect to the service
    if kubectl exec -n mimir-edge-enforcement deployment/mimir-rls -- wget -q --timeout=5 --tries=1 -O- "$service_url/readyz" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✅ $description is healthy${NC}"
        return 0
    else
        echo -e "  ${RED}❌ $description is not responding${NC}"
        return 1
    fi
}

# Function to monitor logs for specific errors
monitor_logs() {
    local service_name=$1
    local namespace=$2
    local duration=$3
    local error_pattern=$4
    
    echo -e "${BLUE}📊 Monitoring $service_name logs for $duration seconds...${NC}"
    
    # Start monitoring in background
    kubectl logs -n "$namespace" deployment/"$service_name" --follow --tail=0 > "/tmp/${service_name}_logs.txt" 2>&1 &
    local log_pid=$!
    
    # Wait for specified duration
    sleep "$duration"
    
    # Stop monitoring
    kill $log_pid 2>/dev/null || true
    
    # Check for errors
    if grep -q "$error_pattern" "/tmp/${service_name}_logs.txt" 2>/dev/null; then
        echo -e "  ${RED}❌ Found errors matching pattern: $error_pattern${NC}"
        grep "$error_pattern" "/tmp/${service_name}_logs.txt" | head -5
        return 1
    else
        echo -e "  ${GREEN}✅ No errors found matching pattern: $error_pattern${NC}"
        return 0
    fi
}

# Function to generate realistic metrics payload
generate_metrics_payload() {
    local tenant=$1
    local timestamp=$(date +%s)
    
    # Create a realistic Prometheus remote write payload
    cat <<EOF
{
  "metrics": [
    {
      "name": "http_requests_total",
      "type": "counter",
      "help": "Total number of HTTP requests",
      "unit": "",
      "data": [
        {
          "type": "counter",
          "labels": {
            "tenant": "$tenant",
            "method": "POST",
            "endpoint": "/api/v1/push",
            "status": "200"
          },
          "value": $((RANDOM % 1000 + 100)),
          "timestamp": $timestamp
        }
      ]
    },
    {
      "name": "http_request_duration_seconds",
      "type": "histogram",
      "help": "HTTP request duration in seconds",
      "unit": "seconds",
      "data": [
        {
          "type": "histogram",
          "labels": {
            "tenant": "$tenant",
            "method": "POST",
            "endpoint": "/api/v1/push"
          },
          "value": $((RANDOM % 100 + 1)).$((RANDOM % 100)),
          "timestamp": $timestamp
        }
      ]
    }
  ]
}
EOF
}

# Function to send realistic traffic
send_realistic_traffic() {
    local duration=$1
    local concurrency=$2
    local requests_per_sec=$3
    
    echo -e "${BLUE}🚀 Sending realistic traffic for ${duration}s...${NC}"
    
    # Create a temporary script for sending traffic
    cat > /tmp/send_traffic.go <<'EOF'
package main

import (
    "bytes"
    "encoding/json"
    "fmt"
    "io"
    "math/rand"
    "net/http"
    "os"
    "strconv"
    "strings"
    "sync"
    "time"
)

type Metric struct {
    Name   string            `json:"name"`
    Type   string            `json:"type"`
    Help   string            `json:"help"`
    Unit   string            `json:"unit"`
    Data   []MetricData      `json:"data"`
}

type MetricData struct {
    Type      string            `json:"type"`
    Labels    map[string]string `json:"labels"`
    Value     float64           `json:"value"`
    Timestamp int64             `json:"timestamp"`
}

type Payload struct {
    Metrics []Metric `json:"metrics"`
}

func main() {
    if len(os.Args) < 5 {
        fmt.Println("Usage: go run script.go <duration> <concurrency> <requests_per_sec> <target_url>")
        os.Exit(1)
    }
    
    duration, _ := strconv.Atoi(os.Args[1])
    concurrency, _ := strconv.Atoi(os.Args[2])
    requestsPerSec, _ := strconv.Atoi(os.Args[3])
    targetURL := os.Args[4]
    
    tenants := []string{"tenant-1", "tenant-2", "tenant-3"}
    endpoints := []string{"/api/v1/push", "/api/v1/write", "/api/v1/metrics"}
    
    var wg sync.WaitGroup
    stopCh := make(chan bool)
    
    // Start workers
    for i := 0; i < concurrency; i++ {
        wg.Add(1)
        go func(workerID int) {
            defer wg.Done()
            
            client := &http.Client{
                Timeout: 30 * time.Second,
            }
            
            ticker := time.NewTicker(time.Duration(1000/requestsPerSec) * time.Millisecond)
            defer ticker.Stop()
            
            for {
                select {
                case <-stopCh:
                    return
                case <-ticker.C:
                    tenant := tenants[rand.Intn(len(tenants))]
                    endpoint := endpoints[rand.Intn(len(endpoints))]
                    
                    // Generate realistic payload
                    payload := generatePayload(tenant)
                    jsonData, _ := json.Marshal(payload)
                    
                    // Create request
                    req, err := http.NewRequest("POST", targetURL+endpoint, bytes.NewBuffer(jsonData))
                    if err != nil {
                        fmt.Printf("Error creating request: %v\n", err)
                        continue
                    }
                    
                    req.Header.Set("Content-Type", "application/json")
                    req.Header.Set("X-Scope-OrgID", tenant)
                    req.Header.Set("User-Agent", "pipeline-test/1.0")
                    
                    // Send request
                    resp, err := client.Do(req)
                    if err != nil {
                        fmt.Printf("Request failed: %v\n", err)
                        continue
                    }
                    
                    // Check for 413 errors
                    if resp.StatusCode == 413 {
                        fmt.Printf("🚨 413 PAYLOAD TOO LARGE detected! Tenant: %s, Endpoint: %s\n", tenant, endpoint)
                    }
                    
                    resp.Body.Close()
                }
            }
        }(i)
    }
    
    // Run for specified duration
    time.Sleep(time.Duration(duration) * time.Second)
    close(stopCh)
    wg.Wait()
    
    fmt.Println("Load test completed")
}

func generatePayload(tenant string) Payload {
    timestamp := time.Now().Unix()
    
    return Payload{
        Metrics: []Metric{
            {
                Name: "http_requests_total",
                Type: "counter",
                Help: "Total number of HTTP requests",
                Unit: "",
                Data: []MetricData{
                    {
                        Type: "counter",
                        Labels: map[string]string{
                            "tenant":   tenant,
                            "method":   "POST",
                            "endpoint": "/api/v1/push",
                            "status":   "200",
                        },
                        Value:     float64(rand.Intn(1000) + 100),
                        Timestamp: timestamp,
                    },
                },
            },
            {
                Name: "http_request_duration_seconds",
                Type: "histogram",
                Help: "HTTP request duration in seconds",
                Unit: "seconds",
                Data: []MetricData{
                    {
                        Type: "histogram",
                        Labels: map[string]string{
                            "tenant":   tenant,
                            "method":   "POST",
                            "endpoint": "/api/v1/push",
                        },
                        Value:     float64(rand.Intn(100)+1) + rand.Float64(),
                        Timestamp: timestamp,
                    },
                },
            },
        },
    }
}
EOF
    
    # Run the traffic generator
    go run /tmp/send_traffic.go "$duration" "$concurrency" "$requests_per_sec" "$ENVOY_SERVICE"
}

# Main test execution
echo -e "${BLUE}📋 1. Checking Service Health${NC}"
echo "=================================="

# Check all services
check_service_health "nginx" "$NGINX_SERVICE" "NGINX Service"
check_service_health "envoy" "$ENVOY_SERVICE" "Envoy Service"
check_service_health "rls" "$RLS_SERVICE" "RLS Service"
check_service_health "mimir" "$MIMIR_SERVICE" "Mimir Distributor"

echo ""
echo -e "${BLUE}📋 2. Starting Log Monitoring${NC}"
echo "=================================="

# Start monitoring logs for errors in background
monitor_logs "mimir-envoy" "mimir-edge-enforcement" "$DURATION" "413\|PAYLOAD_TOO_LARGE\|body size" &
envoy_monitor_pid=$!

monitor_logs "mimir-rls" "mimir-edge-enforcement" "$DURATION" "413\|PAYLOAD_TOO_LARGE\|body size" &
rls_monitor_pid=$!

monitor_logs "mimir-nginx" "mimir" "$DURATION" "413\|PAYLOAD_TOO_LARGE\|body size" &
nginx_monitor_pid=$!

echo ""
echo -e "${BLUE}📋 3. Running Realistic Load Test${NC}"
echo "=========================================="

# Send realistic traffic
send_realistic_traffic "$DURATION" "$CONCURRENCY" "$REQUESTS_PER_SEC"

echo ""
echo -e "${BLUE}📋 4. Waiting for Monitoring to Complete${NC}"
echo "=============================================="

# Wait for monitoring to complete
wait $envoy_monitor_pid $rls_monitor_pid $nginx_monitor_pid

echo ""
echo -e "${BLUE}📋 5. Analyzing Results${NC}"
echo "=============================="

# Check for 413 errors in logs
echo -e "${BLUE}🔍 Checking for 413 errors in logs...${NC}"

envoy_errors=$(grep -c "413\|PAYLOAD_TOO_LARGE" /tmp/mimir-envoy_logs.txt 2>/dev/null || echo "0")
rls_errors=$(grep -c "413\|PAYLOAD_TOO_LARGE" /tmp/mimir-rls_logs.txt 2>/dev/null || echo "0")
nginx_errors=$(grep -c "413\|PAYLOAD_TOO_LARGE" /tmp/mimir-nginx_logs.txt 2>/dev/null || echo "0")

total_errors=$((envoy_errors + rls_errors + nginx_errors))

if [ "$total_errors" -gt 0 ]; then
    echo -e "  ${RED}❌ Found $total_errors 413 errors:${NC}"
    echo "    Envoy: $envoy_errors"
    echo "    RLS: $rls_errors"
    echo "    NGINX: $nginx_errors"
else
    echo -e "  ${GREEN}✅ No 413 errors detected${NC}"
fi

# Check service metrics
echo ""
echo -e "${BLUE}📊 Service Metrics Summary${NC}"
echo "================================"

# Get current pod status
echo -e "${BLUE}Pod Status:${NC}"
kubectl get pods -n mimir-edge-enforcement -l app.kubernetes.io/name=mimir-envoy
kubectl get pods -n mimir-edge-enforcement -l app.kubernetes.io/name=mimir-rls
kubectl get pods -n mimir -l app.kubernetes.io/name=mimir-nginx

# Check service endpoints
echo ""
echo -e "${BLUE}Service Endpoints:${NC}"
kubectl get endpoints -n mimir-edge-enforcement mimir-envoy
kubectl get endpoints -n mimir-edge-enforcement mimir-rls
kubectl get endpoints -n mimir mimir-nginx

echo ""
echo -e "${GREEN}✅ Pipeline Test Complete!${NC}"

# Cleanup
rm -f /tmp/send_traffic.go /tmp/*_logs.txt

echo ""
echo -e "${BLUE}📋 Summary:${NC}"
echo "=========="
echo "• Test Duration: ${DURATION}s"
echo "• Concurrency: $CONCURRENCY"
echo "• Requests/sec: $REQUESTS_PER_SEC"
echo "• 413 Errors: $total_errors"
echo "• Pipeline Status: $([ $total_errors -eq 0 ] && echo "✅ Healthy" || echo "❌ Issues Detected")"
