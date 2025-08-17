#!/bin/bash

# Test RLS Fallback Mechanism
# This script tests the fallback mechanism when RLS returns 503 errors

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVOY_SERVICE="mimir-envoy.mimir-edge-enforcement.svc.cluster.local"
ENVOY_PORT="8080"
REMOTE_WRITE_PATH="/api/v1/push"
TEST_DURATION=60
CONCURRENT_REQUESTS=10

# Test payload (small for testing)
TEST_PAYLOAD='{
  "metrics": [
    {
      "name": "test_metric",
      "timestamp": 1640995200000,
      "value": 42.0,
      "labels": {
        "test": "fallback",
        "tenant": "test-tenant"
      }
    }
  ]
}'

echo -e "${BLUE}🔧 Testing RLS Fallback Mechanism${NC}"
echo "=================================="

# Function to check service health
check_service_health() {
    echo -e "${YELLOW}📋 Checking service health...${NC}"
    
    # Check Envoy pods
    echo "Checking Envoy pods..."
    kubectl get pods -n mimir-edge-enforcement -l app.kubernetes.io/name=mimir-envoy
    
    # Check RLS pods
    echo "Checking RLS pods..."
    kubectl get pods -n mimir-edge-enforcement -l app.kubernetes.io/name=mimir-rls
    
    # Check Mimir distributor pods
    echo "Checking Mimir distributor pods..."
    kubectl get pods -n mimir -l app.kubernetes.io/name=mimir-distributor
    
    echo ""
}

# Function to test normal flow (RLS working)
test_normal_flow() {
    echo -e "${YELLOW}🧪 Testing normal flow (RLS working)...${NC}"
    
    # Send a test request
    response=$(curl -s -w "%{http_code}" -o /tmp/normal_response.txt \
        -X POST \
        -H "Content-Type: application/json" \
        -H "X-Scope-OrgID: test-tenant" \
        -d "$TEST_PAYLOAD" \
        "http://$ENVOY_SERVICE:$ENVOY_PORT$REMOTE_WRITE_PATH")
    
    http_code="${response: -3}"
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✅ Normal flow working (HTTP $http_code)${NC}"
        return 0
    else
        echo -e "${RED}❌ Normal flow failed (HTTP $http_code)${NC}"
        cat /tmp/normal_response.txt
        return 1
    fi
}

# Function to test fallback flow (RLS returning 503)
test_fallback_flow() {
    echo -e "${YELLOW}🧪 Testing fallback flow (RLS returning 503)...${NC}"
    
    # Scale down RLS to simulate outage
    echo "Scaling down RLS to simulate outage..."
    kubectl scale deployment mimir-rls -n mimir-edge-enforcement --replicas=0
    
    # Wait for RLS pods to terminate
    echo "Waiting for RLS pods to terminate..."
    kubectl wait --for=delete pod -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement --timeout=60s || true
    
    # Send a test request (should trigger fallback)
    response=$(curl -s -w "%{http_code}" -o /tmp/fallback_response.txt \
        -X POST \
        -H "Content-Type: application/json" \
        -H "X-Scope-OrgID: test-tenant" \
        -d "$TEST_PAYLOAD" \
        "http://$ENVOY_SERVICE:$ENVOY_PORT$REMOTE_WRITE_PATH")
    
    http_code="${response: -3}"
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✅ Fallback flow working (HTTP $http_code)${NC}"
        
        # Check if fallback headers are present
        if grep -q "x-rls-bypass" /tmp/fallback_response.txt; then
            echo -e "${GREEN}✅ Fallback headers detected${NC}"
        else
            echo -e "${YELLOW}⚠️  Fallback headers not detected (may be normal)${NC}"
        fi
        
        return 0
    else
        echo -e "${RED}❌ Fallback flow failed (HTTP $http_code)${NC}"
        cat /tmp/fallback_response.txt
        return 1
    fi
}

# Function to restore RLS service
restore_rls_service() {
    echo -e "${YELLOW}🔄 Restoring RLS service...${NC}"
    
    # Scale up RLS
    kubectl scale deployment mimir-rls -n mimir-edge-enforcement --replicas=3
    
    # Wait for RLS pods to be ready
    echo "Waiting for RLS pods to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement --timeout=120s
    
    echo -e "${GREEN}✅ RLS service restored${NC}"
}

# Function to check Envoy logs for fallback events
check_fallback_logs() {
    echo -e "${YELLOW}📋 Checking Envoy logs for fallback events...${NC}"
    
    # Get Envoy logs
    kubectl logs -n mimir-edge-enforcement deployment/mimir-envoy --tail=50 | grep -i fallback || echo "No fallback events found in recent logs"
    
    echo ""
}

# Function to test recovery (RLS back online)
test_recovery() {
    echo -e "${YELLOW}🧪 Testing recovery (RLS back online)...${NC}"
    
    # Wait a bit for Envoy to detect RLS is back
    sleep 10
    
    # Send a test request
    response=$(curl -s -w "%{http_code}" -o /tmp/recovery_response.txt \
        -X POST \
        -H "Content-Type: application/json" \
        -H "X-Scope-OrgID: test-tenant" \
        -d "$TEST_PAYLOAD" \
        "http://$ENVOY_SERVICE:$ENVOY_PORT$REMOTE_WRITE_PATH")
    
    http_code="${response: -3}"
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✅ Recovery working (HTTP $http_code)${NC}"
        return 0
    else
        echo -e "${RED}❌ Recovery failed (HTTP $http_code)${NC}"
        cat /tmp/recovery_response.txt
        return 1
    fi
}

# Function to run load test with fallback
run_load_test_with_fallback() {
    echo -e "${YELLOW}🚀 Running load test with fallback scenario...${NC}"
    
    # Create a simple load test script
    cat > /tmp/load_test.go << 'EOF'
package main

import (
    "bytes"
    "fmt"
    "io"
    "net/http"
    "sync"
    "time"
)

func main() {
    const (
        envoyURL = "http://mimir-envoy.mimir-edge-enforcement.svc.cluster.local:8080/api/v1/push"
        payload  = `{"metrics":[{"name":"load_test_metric","timestamp":1640995200000,"value":42.0,"labels":{"test":"fallback","tenant":"test-tenant"}}]}`
        duration = 30 * time.Second
        workers  = 5
    )

    client := &http.Client{Timeout: 10 * time.Second}
    var wg sync.WaitGroup
    var successCount, errorCount int
    var mu sync.Mutex

    start := time.Now()
    
    for i := 0; i < workers; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            for time.Since(start) < duration {
                req, _ := http.NewRequest("POST", envoyURL, bytes.NewBufferString(payload))
                req.Header.Set("Content-Type", "application/json")
                req.Header.Set("X-Scope-OrgID", "test-tenant")
                
                resp, err := client.Do(req)
                if err != nil {
                    mu.Lock()
                    errorCount++
                    mu.Unlock()
                    fmt.Printf("Request failed: %v\n", err)
                    continue
                }
                
                io.Copy(io.Discard, resp.Body)
                resp.Body.Close()
                
                mu.Lock()
                if resp.StatusCode == 200 {
                    successCount++
                } else {
                    errorCount++
                }
                mu.Unlock()
                
                time.Sleep(100 * time.Millisecond)
            }
        }()
    }
    
    wg.Wait()
    
    fmt.Printf("Load test completed: %d successful, %d failed\n", successCount, errorCount)
}
EOF

    # Compile and run the load test
    echo "Running load test for 30 seconds..."
    cd /tmp && go run load_test.go
    
    echo ""
}

# Main test execution
main() {
    echo -e "${BLUE}🚀 Starting RLS Fallback Mechanism Test${NC}"
    echo "=============================================="
    
    # Check service health
    check_service_health
    
    # Test 1: Normal flow
    echo -e "${BLUE}📋 Test 1: Normal Flow${NC}"
    if test_normal_flow; then
        echo -e "${GREEN}✅ Test 1 PASSED${NC}"
    else
        echo -e "${RED}❌ Test 1 FAILED${NC}"
        return 1
    fi
    
    echo ""
    
    # Test 2: Fallback flow
    echo -e "${BLUE}📋 Test 2: Fallback Flow${NC}"
    if test_fallback_flow; then
        echo -e "${GREEN}✅ Test 2 PASSED${NC}"
    else
        echo -e "${RED}❌ Test 2 FAILED${NC}"
        # Restore RLS before exiting
        restore_rls_service
        return 1
    fi
    
    echo ""
    
    # Check fallback logs
    check_fallback_logs
    
    # Test 3: Load test with fallback
    echo -e "${BLUE}📋 Test 3: Load Test with Fallback${NC}"
    run_load_test_with_fallback
    
    # Test 4: Recovery
    echo -e "${BLUE}📋 Test 4: Recovery${NC}"
    restore_rls_service
    
    if test_recovery; then
        echo -e "${GREEN}✅ Test 4 PASSED${NC}"
    else
        echo -e "${RED}❌ Test 4 FAILED${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${GREEN}🎉 All tests completed successfully!${NC}"
    echo -e "${GREEN}✅ RLS Fallback Mechanism is working correctly${NC}"
}

# Cleanup function
cleanup() {
    echo -e "${YELLOW}🧹 Cleaning up...${NC}"
    
    # Restore RLS service if it was scaled down
    kubectl scale deployment mimir-rls -n mimir-edge-enforcement --replicas=3 2>/dev/null || true
    
    # Clean up temporary files
    rm -f /tmp/normal_response.txt /tmp/fallback_response.txt /tmp/recovery_response.txt /tmp/load_test.go
    
    echo -e "${GREEN}✅ Cleanup completed${NC}"
}

# Set up trap for cleanup
trap cleanup EXIT

# Run main function
main "$@"
