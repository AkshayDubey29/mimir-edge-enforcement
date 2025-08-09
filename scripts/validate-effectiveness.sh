#!/bin/bash

# 🎯 Validate Edge Enforcement Effectiveness
# Comprehensive test to ensure the system is protecting Mimir efficiently

set -euo pipefail

# Configuration
NAMESPACE=${NAMESPACE:-mimir-edge-enforcement}
TEST_TENANT=${TEST_TENANT:-validation-test}
LOAD_DURATION=${LOAD_DURATION:-60} # seconds
SAMPLES_PER_REQUEST=${SAMPLES_PER_REQUEST:-1000}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

error() {
    echo -e "${RED}❌${NC} $1"
}

info() {
    echo -e "${PURPLE}ℹ️${NC} $1"
}

# Cleanup function
cleanup() {
    if [[ -n "${PF_PID:-}" ]]; then
        kill $PF_PID 2>/dev/null || true
        wait $PF_PID 2>/dev/null || true
    fi
}
trap cleanup EXIT

echo -e "${BLUE}🎯 Edge Enforcement Effectiveness Validation${NC}"
echo -e "${BLUE}=============================================${NC}"
echo

# 1. Pre-test system check
log "🔍 Pre-test System Check"
echo "-------------------------"

# Check if RLS is ready
RLS_POD=$(kubectl get pods -l app.kubernetes.io/name=mimir-rls -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -z "$RLS_POD" ]]; then
    error "No RLS pod found"
    exit 1
fi

# Start port-forward for testing
kubectl port-forward "$RLS_POD" 8082:8082 -n "$NAMESPACE" &
PF_PID=$!
sleep 3

# Get baseline metrics
BASELINE_OVERVIEW=$(curl -s --max-time 5 "http://localhost:8082/api/overview" || echo '{"stats":{"total_requests":0,"denied_requests":0}}')
BASELINE_TOTAL=$(echo "$BASELINE_OVERVIEW" | jq -r '.stats.total_requests // 0')
BASELINE_DENIED=$(echo "$BASELINE_OVERVIEW" | jq -r '.stats.denied_requests // 0')

success "Baseline captured: $BASELINE_TOTAL total requests, $BASELINE_DENIED denied"
echo

# 2. Check tenant configuration
log "👥 Checking Test Tenant Configuration"
echo "--------------------------------------"

TENANTS_RESPONSE=$(curl -s --max-time 5 "http://localhost:8082/api/tenants" || echo '{"tenants":[]}')
TEST_TENANT_CONFIG=$(echo "$TENANTS_RESPONSE" | jq -r ".tenants[] | select(.id == \"$TEST_TENANT\")")

if [[ -n "$TEST_TENANT_CONFIG" && "$TEST_TENANT_CONFIG" != "null" ]]; then
    success "Test tenant '$TEST_TENANT' found with configuration"
    
    SAMPLES_LIMIT=$(echo "$TEST_TENANT_CONFIG" | jq -r '.limits.samples_per_second // 0')
    MAX_BODY_BYTES=$(echo "$TEST_TENANT_CONFIG" | jq -r '.limits.max_body_bytes // 0')
    ENFORCEMENT_ENABLED=$(echo "$TEST_TENANT_CONFIG" | jq -r '.enforcement.enabled // false')
    
    info "Samples limit: $SAMPLES_LIMIT/sec"
    info "Max body size: $MAX_BODY_BYTES bytes"
    info "Enforcement enabled: $ENFORCEMENT_ENABLED"
    
    if [[ "$ENFORCEMENT_ENABLED" != "true" ]]; then
        warning "Enforcement is disabled for test tenant"
    fi
else
    warning "Test tenant '$TEST_TENANT' not found, will test with unknown tenant"
    SAMPLES_LIMIT=1000  # Default for testing
    MAX_BODY_BYTES=4194304  # Default 4MB
fi
echo

# 3. Test enforcement effectiveness
log "🧪 Testing Enforcement Effectiveness"
echo "------------------------------------"

# Create test payload that should be within limits
NORMAL_PAYLOAD_SIZE=1000
NORMAL_PAYLOAD=$(printf '{"streams":[{"stream":{"__name__":"test_metric","job":"validation"},"values":[]}]}%.0s' $(seq 1 $((NORMAL_PAYLOAD_SIZE/80))))

# Create test payload that exceeds body size limit
OVERSIZED_PAYLOAD_SIZE=$((MAX_BODY_BYTES + 1000))
OVERSIZED_PAYLOAD=$(printf 'A%.0s' $(seq 1 $OVERSIZED_PAYLOAD_SIZE))

echo "Testing normal request (should be allowed)..."
NORMAL_START_TIME=$(date +%s)

# Test normal request
NORMAL_RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null -X POST \
    "http://localhost:8082/api/tenants/$TEST_TENANT" \
    -H "Content-Type: application/json" \
    -d "$NORMAL_PAYLOAD" 2>/dev/null || echo "000")

if [[ "$NORMAL_RESPONSE" == "200" || "$NORMAL_RESPONSE" == "404" ]]; then
    success "Normal request processed (HTTP $NORMAL_RESPONSE)"
else
    warning "Normal request unexpected response: HTTP $NORMAL_RESPONSE"
fi

echo "Testing oversized request (should be denied)..."

# Test oversized request
OVERSIZED_RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null -X POST \
    "http://localhost:8082/api/tenants/$TEST_TENANT" \
    -H "Content-Type: application/json" \
    -d "$OVERSIZED_PAYLOAD" 2>/dev/null || echo "000")

if [[ "$OVERSIZED_RESPONSE" == "413" || "$OVERSIZED_RESPONSE" == "429" ]]; then
    success "Oversized request properly denied (HTTP $OVERSIZED_RESPONSE)"
else
    warning "Oversized request unexpected response: HTTP $OVERSIZED_RESPONSE"
fi

sleep 2  # Allow metrics to update
echo

# 4. Verify metrics updated
log "📊 Verifying Metrics Update"
echo "----------------------------"

UPDATED_OVERVIEW=$(curl -s --max-time 5 "http://localhost:8082/api/overview" || echo '{"stats":{"total_requests":0,"denied_requests":0}}')
UPDATED_TOTAL=$(echo "$UPDATED_OVERVIEW" | jq -r '.stats.total_requests // 0')
UPDATED_DENIED=$(echo "$UPDATED_OVERVIEW" | jq -r '.stats.denied_requests // 0')

REQUESTS_INCREASE=$((UPDATED_TOTAL - BASELINE_TOTAL))
DENIALS_INCREASE=$((UPDATED_DENIED - BASELINE_DENIED))

if [[ "$REQUESTS_INCREASE" -gt 0 ]]; then
    success "Request count increased by $REQUESTS_INCREASE"
else
    warning "Request count did not increase (may indicate routing issue)"
fi

if [[ "$DENIALS_INCREASE" -gt 0 ]]; then
    success "Denial count increased by $DENIALS_INCREASE (enforcement working)"
else
    warning "No new denials recorded"
fi

echo "📈 Metrics Summary:"
echo "  Total requests: $BASELINE_TOTAL → $UPDATED_TOTAL (+$REQUESTS_INCREASE)"
echo "  Denied requests: $BASELINE_DENIED → $UPDATED_DENIED (+$DENIALS_INCREASE)"
echo

# 5. Check recent denials for our test
log "🔍 Checking Recent Denials"
echo "---------------------------"

DENIALS_RESPONSE=$(curl -s --max-time 5 "http://localhost:8082/api/denials" || echo '[]')
RECENT_TEST_DENIALS=$(echo "$DENIALS_RESPONSE" | jq -r --arg tenant "$TEST_TENANT" 'map(select(.tenant_id == $tenant and (.timestamp | fromdateiso8601) > (now - 300)))')
TEST_DENIAL_COUNT=$(echo "$RECENT_TEST_DENIALS" | jq 'length')

if [[ "$TEST_DENIAL_COUNT" -gt 0 ]]; then
    success "Found $TEST_DENIAL_COUNT recent denials for test tenant"
    echo "Recent denial reasons:"
    echo "$RECENT_TEST_DENIALS" | jq -r '.[] | "  - \(.reason) at \(.timestamp)"'
else
    warning "No recent denials found for test tenant (check if limits are configured)"
fi
echo

# 6. Performance impact assessment
log "⚡ Performance Impact Assessment"
echo "--------------------------------"

# Test response time with small load
echo "Measuring response times..."
RESPONSE_TIMES=()

for i in {1..5}; do
    START_TIME=$(date +%s%N)
    curl -s -o /dev/null "http://localhost:8082/api/health" 2>/dev/null || true
    END_TIME=$(date +%s%N)
    RESPONSE_TIME=$(((END_TIME - START_TIME) / 1000000))  # Convert to milliseconds
    RESPONSE_TIMES+=($RESPONSE_TIME)
done

# Calculate average response time
TOTAL_TIME=0
for time in "${RESPONSE_TIMES[@]}"; do
    TOTAL_TIME=$((TOTAL_TIME + time))
done
AVERAGE_TIME=$((TOTAL_TIME / ${#RESPONSE_TIMES[@]}))

echo "📊 Response Time Analysis:"
echo "  Average response time: ${AVERAGE_TIME}ms"
echo "  Individual times: ${RESPONSE_TIMES[*]} ms"

if [[ "$AVERAGE_TIME" -lt 100 ]]; then
    success "Excellent response time (<100ms)"
elif [[ "$AVERAGE_TIME" -lt 500 ]]; then
    success "Good response time (<500ms)"
else
    warning "High response time (${AVERAGE_TIME}ms) - may need optimization"
fi
echo

# 7. Resource usage check
log "💾 Resource Usage Check"
echo "------------------------"

# Get resource usage
RESOURCE_USAGE=$(kubectl top pods -l app.kubernetes.io/name=mimir-rls -n "$NAMESPACE" 2>/dev/null || echo "NAME CPU MEMORY")
if [[ "$RESOURCE_USAGE" != "NAME CPU MEMORY" ]]; then
    success "Resource usage retrieved"
    echo "$RESOURCE_USAGE"
    
    # Extract CPU and memory usage
    CPU_USAGE=$(echo "$RESOURCE_USAGE" | tail -1 | awk '{print $2}' | sed 's/m$//')
    MEMORY_USAGE=$(echo "$RESOURCE_USAGE" | tail -1 | awk '{print $3}' | sed 's/Mi$//')
    
    if [[ "$CPU_USAGE" =~ ^[0-9]+$ ]] && [[ "$CPU_USAGE" -lt 1000 ]]; then
        success "CPU usage optimal: ${CPU_USAGE}m cores"
    elif [[ "$CPU_USAGE" =~ ^[0-9]+$ ]]; then
        warning "High CPU usage: ${CPU_USAGE}m cores"
    fi
    
    if [[ "$MEMORY_USAGE" =~ ^[0-9]+$ ]] && [[ "$MEMORY_USAGE" -lt 500 ]]; then
        success "Memory usage optimal: ${MEMORY_USAGE}Mi"
    elif [[ "$MEMORY_USAGE" =~ ^[0-9]+$ ]]; then
        warning "High memory usage: ${MEMORY_USAGE}Mi"
    fi
else
    warning "Unable to retrieve resource usage (kubectl top not available)"
fi
echo

# 8. Overall effectiveness score
log "🎯 Overall Effectiveness Assessment"
echo "-----------------------------------"

SCORE=0
MAX_SCORE=8

# Scoring criteria
[[ "$REQUESTS_INCREASE" -gt 0 ]] && ((SCORE++))  # Traffic flowing
[[ "$DENIALS_INCREASE" -gt 0 ]] && ((SCORE++))   # Enforcement working
[[ "$TEST_DENIAL_COUNT" -gt 0 ]] && ((SCORE++))  # Test denials recorded
[[ "$AVERAGE_TIME" -lt 500 ]] && ((SCORE++))     # Good response time
[[ "$NORMAL_RESPONSE" == "200" ]] && ((SCORE++)) # Normal requests allowed
[[ "$OVERSIZED_RESPONSE" =~ ^(413|429)$ ]] && ((SCORE++)) # Oversized requests denied
[[ "$UPDATED_TOTAL" -gt "$BASELINE_TOTAL" ]] && ((SCORE++)) # Metrics updating
[[ -n "$TEST_TENANT_CONFIG" && "$TEST_TENANT_CONFIG" != "null" ]] && ((SCORE++)) # Tenant configured

EFFECTIVENESS_PERCENTAGE=$((SCORE * 100 / MAX_SCORE))

echo "🏆 Effectiveness Score: $SCORE/$MAX_SCORE ($EFFECTIVENESS_PERCENTAGE%)"
echo

if [[ "$EFFECTIVENESS_PERCENTAGE" -ge 85 ]]; then
    success "🎉 Edge enforcement is highly effective!"
    echo
    echo "✅ Key Success Indicators:"
    echo "  • Traffic is being processed and evaluated"
    echo "  • Enforcement decisions are being made"
    echo "  • Metrics are updating in real-time"
    echo "  • Response times are acceptable"
    echo "  • Protection is actively blocking violations"
    echo
    echo "🛡️ Your Mimir system is efficiently protected!"
    
elif [[ "$EFFECTIVENESS_PERCENTAGE" -ge 60 ]]; then
    warning "⚠️ Edge enforcement is partially effective"
    echo
    echo "🔧 Areas for improvement:"
    [[ "$REQUESTS_INCREASE" -eq 0 ]] && echo "  • Traffic routing may need verification"
    [[ "$DENIALS_INCREASE" -eq 0 ]] && echo "  • Enforcement rules may need adjustment"
    [[ "$TEST_DENIAL_COUNT" -eq 0 ]] && echo "  • Tenant limits may need configuration"
    [[ "$AVERAGE_TIME" -ge 500 ]] && echo "  • Response time optimization needed"
    echo
    echo "📋 Recommendation: Review configuration and run detailed diagnostics"
    
else
    error "❌ Edge enforcement effectiveness is low"
    echo
    echo "🚨 Critical issues detected:"
    echo "  • System may not be properly configured"
    echo "  • Traffic routing needs verification"
    echo "  • Enforcement rules need review"
    echo
    echo "🔧 Immediate actions needed:"
    echo "  1. Run: ./scripts/production-health-check.sh"
    echo "  2. Run: ./scripts/debug-404-issue.sh"
    echo "  3. Check component logs for errors"
    echo "  4. Verify tenant configuration in Mimir ConfigMap"
fi

echo
info "📊 For continuous monitoring:"
echo "     Admin UI: kubectl port-forward svc/admin-ui 3000:80 -n $NAMESPACE"
echo "     Metrics: ./scripts/extract-protection-metrics.sh"
echo "     Health: ./scripts/production-health-check.sh"
