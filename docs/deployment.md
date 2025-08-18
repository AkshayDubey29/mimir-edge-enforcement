# 🚀 Production Deployment Guide

This comprehensive guide walks you through deploying **mimir-edge-enforcement** to a production Kubernetes cluster with **canary rollout** support and **real Mimir ConfigMap integration**.

## 📋 Prerequisites

### 1. Required Tools
```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm 3.x
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installations
kubectl version --client
helm version
```

### 2. Cluster Access & Permissions
```bash
# Verify cluster access
kubectl cluster-info
kubectl get nodes

# Ensure sufficient permissions
kubectl auth can-i create deployments --namespace=default
kubectl auth can-i create services --namespace=default
kubectl auth can-i create configmaps --namespace=mimir
kubectl auth can-i watch configmaps --namespace=mimir

# Verify AWS Load Balancer Controller (for ALB Ingress)
kubectl get deployment aws-load-balancer-controller -n kube-system
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

### 3. Container Registry Access
```bash
# Login to GitHub Container Registry (if using private repos)
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin

# Create Kubernetes secret for image pulling
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=$GITHUB_USERNAME \
  --docker-password=$GITHUB_TOKEN \
  --docker-email=$GITHUB_EMAIL \
  --namespace=mimir-edge-enforcement
```

## 🎯 Quick Start Options

### Option 1: One-Shot Complete Deployment
For a complete system deployment with production settings:

```bash
# Clone the repository
git clone https://github.com/AkshayDubey29/mimir-edge-enforcement.git
cd mimir-edge-enforcement

# Deploy complete system with Admin UI and canary support
./scripts/deploy-complete.sh production \
  --domain your-domain.com \
  --admin-password your-secure-password \
  --github-token $GITHUB_TOKEN

# This deploys:
# ✅ RLS (Rate Limiting Service)
# ✅ Overrides-Sync Controller  
# ✅ Envoy Proxy (v0.2.0+ with HTTP protocol fix)
# ✅ Admin UI with Ingress
# ✅ Production-ready configurations
```

### Option 2: Manual Step-by-Step Deployment
For customized deployment with full control:

```bash
# Use the production deployment script
./scripts/deploy-production.sh complete \
  --namespace mimir-edge-enforcement \
  --mimir-namespace mimir \
  --admin-domain admin.your-domain.com
```

### Option 3: Component-by-Component
Deploy individual components as needed:

```bash
# Deploy core components only
./scripts/deploy-production.sh core-only

# Deploy Admin UI separately  
./scripts/deploy-admin-ui.sh --type ingress --domain admin.your-domain.com
```

## 🔧 Component-by-Component Deployment

For users who want full control over each component deployment, follow these detailed steps:

### Step 1: Environment Setup
```bash
# Create namespace
kubectl create namespace mimir-edge-enforcement

# Set default context (optional)
kubectl config set-context --current --namespace=mimir-edge-enforcement

# Copy image pull secret if needed
kubectl get secret ghcr-secret -o yaml | \
  sed 's/namespace: default/namespace: mimir-edge-enforcement/' | \
  kubectl apply -f -
```

### Step 2: Verify Mimir Integration

Your Mimir deployment should have the overrides ConfigMap in the **real Mimir format**:

```bash
# Check existing Mimir overrides ConfigMap
kubectl get configmap mimir-overrides -n mimir -o yaml

# Expected format (this is what our parser now supports):
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: mimir-overrides
  namespace: mimir
data:
  mimir.yaml: |
    metrics:
      per_tenant_metrics_enabled: true
  overrides.yaml: |
    overrides:
      tenant-production:
        cardinality_analysis_enabled: true
        ingestion_burst_size: 3.5e+06
        ingestion_rate: 350000
        ingestion_tenant_shard_size: 8
        max_global_metadata_per_metric: 10
        max_global_metadata_per_user: 600000
        max_global_series_per_user: 3e+06
        max_label_names_per_series: 50
      tenant-staging:
        ingestion_burst_size: 1e+06
        ingestion_rate: 100000
        max_label_names_per_series: 30
        max_global_series_per_user: 1e+06
EOF
```

### Step 3: Deploy RLS (Rate Limiting Service)

```bash
# Create values file for RLS
cat > values-rls.yaml <<EOF
# Production configuration for RLS
replicaCount: 3

image:
  repository: ghcr.io/akshaydubey29/mimir-rls
  tag: "latest"  # 🔴 CHANGE: Use specific SHA in production: "abc123def"
  pullPolicy: IfNotPresent

# Production resource limits
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi

# High availability
hpa:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

# Pod disruption budget
pdb:
  enabled: true
  minAvailable: 2

# Security context
securityContext:
  runAsNonRoot: true
  runAsUser: 65532
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true

# Service configuration
service:
  type: ClusterIP
  extAuthzPort: 8080
  rateLimitPort: 8081
  adminPort: 8082

# Mimir configuration
mimir:
  namespace: "mimir"
  overridesConfigMap: "mimir-overrides"

# Default limits (0 = ConfigMap driven)
defaultSamplesPerSecond: 0
defaultBurstPercent: 0
maxBodyBytes: 0

# 🔧 Enhanced RLS Configuration (required for gRPC health checks)
limits:
  maxRequestBytes: 4194304      # 4 MiB - Maximum request body size for gRPC
  failureModeAllow: false       # Fail closed for security (set true for debugging)
  defaultMaxLabelsPerSeries: 60
  defaultMaxLabelValueLength: 2048
  defaultMaxSeriesPerRequest: 100000
  enforceBodyParsing: true

# Logging
log:
  level: "info"
  format: "json"

# Metrics
metrics:
  enabled: true
  port: 9090

# Network policy
networkPolicy:
  enabled: true

# Image pull secrets
imagePullSecrets:
  - name: ghcr-secret
EOF

# Deploy RLS with enhanced configuration
helm install mimir-rls charts/mimir-rls \
  --namespace mimir-edge-enforcement \
  --values values-rls.yaml \
  --wait --timeout=300s

# Verify deployment
kubectl get pods -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement
kubectl get services -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement

# Check logs
kubectl logs -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement --tail=50
```

### Step 4: Deploy Overrides-Sync Controller

```bash
# Create values file for overrides-sync
cat > values-overrides-sync.yaml <<EOF
# Production configuration for overrides-sync
replicaCount: 2

image:
  repository: ghcr.io/akshaydubey29/overrides-sync
  tag: "latest"  # 🔴 CHANGE: Use specific SHA in production
  pullPolicy: IfNotPresent

# Resource configuration
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

# Pod disruption budget for HA
pdb:
  enabled: true
  minAvailable: 1

# Controller configuration
mimir:
  namespace: "mimir"
  overridesConfigMap: "mimir-overrides"

rls:
  host: "mimir-rls.mimir-edge-enforcement.svc.cluster.local"
  adminPort: "8082"

# Polling configuration
pollFallbackSeconds: 30

# Security
securityContext:
  runAsNonRoot: true
  runAsUser: 65532
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true

# RBAC for ConfigMap access
serviceAccount:
  create: true
  annotations: {}

# Logging
log:
  level: "info"
  format: "json"

# Image pull secrets
imagePullSecrets:
  - name: ghcr-secret
EOF

# Deploy overrides-sync
helm install overrides-sync charts/overrides-sync \
  --namespace mimir-edge-enforcement \
  --values values-overrides-sync.yaml \
  --wait --timeout=300s

# Verify deployment
kubectl get pods -l app.kubernetes.io/name=overrides-sync -n mimir-edge-enforcement

# Check logs for tenant parsing
kubectl logs -l app.kubernetes.io/name=overrides-sync -n mimir-edge-enforcement --tail=50

# Expected logs:
# {"level":"info","message":"found overrides.yaml - parsing Mimir YAML format"}
# {"level":"info","message":"found tenants in overrides YAML","tenants_in_yaml":3}
# {"level":"info","message":"syncing overrides to RLS","tenant_count":3}
```

### Step 5: Deploy Envoy Proxy

> **🔧 IMPORTANT**: The Envoy chart now includes:
> - **Permanent fix for 426 Upgrade Required errors** when NGINX routes HTTP/1.1 traffic to Envoy
> - **Buffer overflow fixes** using 4MB max_request_bytes and proper timeouts
> - **gRPC timeout configurations** preventing hanging requests (5s ext_authz, 2s ratelimit)
> - **HTTP connection manager timeouts** for overall request handling (10s request, 300s stream idle)
> - **Resource limit corrections** matching container memory to heap size

#### **HTTP Protocol Configuration (v0.2.0+)**
The Envoy chart automatically configures:
- **Downstream**: Accepts HTTP/1.1 from NGINX (prevents 426 errors)
- **Upstream to Mimir**: Uses HTTP/1.1 (standard for Mimir deployments)  
- **Upstream to RLS**: Uses HTTP/2 (required for gRPC communication)

```bash
# Create values file for Envoy
cat > values-envoy.yaml <<EOF
# Production configuration for Envoy
replicaCount: 3

image:
  repository: ghcr.io/akshaydubey29/mimir-envoy
  tag: "latest"  # 🔴 CHANGE: Use specific SHA in production
  pullPolicy: IfNotPresent

# Resource configuration (adjusted for heap size fix)
resources:
  limits:
    cpu: 1000m
    memory: 512Mi          # Matches heap size (384Mi = 75% of 512Mi)
  requests:
    cpu: 200m
    memory: 256Mi

# High availability
hpa:
  enabled: true
  minReplicas: 3
  maxReplicas: 15
  targetCPUUtilizationPercentage: 80

# Pod disruption budget
pdb:
  enabled: true
  minAvailable: 2

# Service configuration
service:
  type: ClusterIP
  port: 8080
  annotations: {}

# Mimir distributor configuration
mimir:
  distributorHost: "distributor.mimir.svc.cluster.local"  # 🔴 CHANGE: Your Mimir service
  distributorPort: 8080

# RLS configuration
rls:
  host: "mimir-rls.mimir-edge-enforcement.svc.cluster.local"
  extAuthzPort: 8080
  rateLimitPort: 8081

# 🔧 HTTP Protocol Settings (fixes 426 Upgrade Required errors)
proxy:
  upstreamTimeout: "30s"
  httpProtocol:
    acceptHttp10: true          # Accept HTTP/1.0 and HTTP/1.1 from NGINX
    useRemoteAddress: true      # Use client IP from NGINX proxy
    xffNumTrustedHops: 1        # Trust X-Forwarded-For from NGINX

# Resource limits and overload protection (fixed for buffer overflow)
resourceLimits:
  maxHeapSizeBytes: 402653184          # 384 MiB (75% of 512Mi container) - FIXED
  shrinkHeapThreshold: 0.8             # Shrink heap at 80%
  heapStopAcceptingThreshold: 0.95     # Stop accepting at 95% heap

# External authorization (with buffer overflow fixes)
extAuthz:
  maxRequestBytes: 4194304  # 4 MiB (provides buffer management for large requests)
  failureModeAllow: false   # Fail closed for security - set to true for debugging
  # 🔧 TIMEOUT FIXES:
  timeout: "5s"             # gRPC service timeout - prevents hanging requests

# Rate limiting (with timeout fixes)
rateLimit:
  failureModeDeny: true     # Deny on rate limit service failure
  # 🔧 TIMEOUT FIXES:
  grpcTimeout: "2s"         # gRPC call timeout

# Logging configuration for troubleshooting
logging:
  level: "info"             # info, debug, trace, warn, error
  enableAccessLogs: true    # Enable HTTP access logs to see all requests
  enableDebugLogs: false    # Enable debug logging for filters

# Tenant configuration
tenantHeader: "X-Scope-OrgID"

# Security
securityContext:
  runAsNonRoot: true
  runAsUser: 65532
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true

# Image pull secrets
imagePullSecrets:
  - name: ghcr-secret
EOF

# Deploy Envoy
helm install mimir-envoy charts/envoy \
  --namespace mimir-edge-enforcement \
  --values values-envoy.yaml \
  --wait --timeout=300s

# Verify deployment
kubectl get pods -l app.kubernetes.io/name=mimir-envoy -n mimir-edge-enforcement
kubectl get services -l app.kubernetes.io/name=mimir-envoy -n mimir-edge-enforcement

# Test Envoy admin interface
kubectl port-forward svc/mimir-envoy 8001:8001 -n mimir-edge-enforcement &

# Basic health checks
curl http://localhost:8001/ready
curl http://localhost:8001/stats | grep -E "(ready|healthy)"

# 🔧 VERIFY BUFFER OVERFLOW FIXES:
echo "=== Verifying Buffer Overflow Fixes ==="

# 1. Check ext_authz configuration includes request buffer and timeouts
echo "Checking ext_authz request buffer configuration..."
kubectl get configmap mimir-envoy-config -n mimir-edge-enforcement -o yaml | \
  grep -A 10 -B 5 "max_request_bytes"

# 2. Verify timeout configurations in gRPC services
echo "Checking gRPC timeout configurations..."
kubectl get configmap mimir-envoy-config -n mimir-edge-enforcement -o yaml | \
  grep -A 5 -B 5 "timeout:"

# 3. Check heap size matches container memory
echo "Checking heap size configuration..."
kubectl get configmap mimir-envoy-config -n mimir-edge-enforcement -o yaml | \
  grep -A 5 -B 5 "maxHeapSizeBytes"

# 4. Verify RLS cluster health checks are configured
echo "Checking RLS cluster health checks..."
kubectl get configmap mimir-envoy-config -n mimir-edge-enforcement -o yaml | \
  grep -A 10 "health_checks"

# 5. Test that buffer overflow warnings are eliminated
echo "Checking for buffer overflow warnings (should be none)..."
kubectl logs -l app.kubernetes.io/name=mimir-envoy -n mimir-edge-enforcement --tail=50 | \
  grep -i "buffer.*size.*limit" || echo "✅ No buffer overflow warnings found"

# 6. Verify ext_authz metrics show successful processing
echo "Checking ext_authz stats..."
curl -s http://localhost:8001/stats | grep ext_authz | head -10

# 7. Check memory usage is within limits
echo "Checking memory usage..."
curl -s http://localhost:8001/stats | grep -E "(memory_heap_size|memory_allocated)"

# Stop port-forward
pkill -f "kubectl port-forward.*8001"

# ✅ Expected Results:
echo "=== Expected Configuration Verification ==="
echo "✅ max_request_bytes: 4194304 (4MB request buffer)"
echo "✅ timeout: 5s (ext_authz gRPC service)"
echo "✅ grpcTimeout: 2s (ratelimit gRPC service)"
echo "✅ request_timeout: 10s (HTTP connection manager)"
echo "✅ maxHeapSizeBytes: 402653184 (384MB)"
echo "✅ health_checks configured for RLS clusters"
echo "✅ No buffer overflow warnings in logs"
```

#### **Post-Deployment Buffer Overflow Testing**

After deploying Envoy with the buffer overflow fixes, run these additional tests:

```bash
# 🧪 COMPREHENSIVE BUFFER OVERFLOW TESTING

echo "=== Testing Buffer Overflow Fixes ==="

# Test 1: Send large request to verify buffer handling
echo "Testing large request handling..."
kubectl port-forward svc/mimir-envoy 8080:8080 -n mimir-edge-enforcement &
ENVOY_PID=$!

# Create a test payload (simulate large metrics payload)
python3 -c "
import requests
import time
# Large payload test (should not cause buffer overflow)
headers = {'X-Scope-OrgID': 'test-tenant', 'Content-Type': 'application/x-protobuf'}
# Simulate 2MB payload (under 4MB limit but large enough to test buffer)
payload = b'x' * (2 * 1024 * 1024)
try:
    response = requests.post('http://localhost:8080/api/v1/push', 
                           headers=headers, data=payload, timeout=10)
    print(f'✅ Large request handled: {response.status_code}')
except Exception as e:
    print(f'❌ Large request failed: {e}')
"

# Test 2: Concurrent requests to test buffer pool
echo "Testing concurrent request handling..."
for i in {1..5}; do
  curl -H "X-Scope-OrgID: test-tenant-$i" \
       -H "Content-Type: application/x-protobuf" \
       -X POST http://localhost:8080/api/v1/push \
       --data-binary "test-payload-$i" &
done
wait

# Test 3: Check buffer overflow warnings after testing
echo "Checking for buffer warnings after load test..."
kubectl logs -l app.kubernetes.io/name=mimir-envoy -n mimir-edge-enforcement --tail=20 | \
  grep -i "buffer.*size.*limit" && echo "❌ Buffer warnings found!" || echo "✅ No buffer warnings"

# Test 4: Verify ext_authz timeout handling
echo "Testing ext_authz timeout behavior..."
curl -s http://localhost:8001/stats | grep -E "ext_authz.*(timeout|retry|pending)" | head -5

# Test 5: Check memory usage under load
echo "Checking memory usage after load test..."
MEMORY_USAGE=$(curl -s http://localhost:8001/stats | grep "server.memory_heap_size" | awk '{print $2}')
MEMORY_LIMIT=402653184  # 384MB in bytes
echo "Current heap usage: $MEMORY_USAGE bytes"
echo "Configured limit: $MEMORY_LIMIT bytes"
if [ "$MEMORY_USAGE" -lt "$MEMORY_LIMIT" ]; then
  echo "✅ Memory usage within limits"
else
  echo "⚠️  Memory usage approaching limit"
fi

# Cleanup
kill $ENVOY_PID 2>/dev/null

echo "=== Buffer Overflow Testing Complete ==="
```

#### **Buffer Overflow Fix Validation Checklist**

Use this checklist to verify all fixes are working:

- [ ] **Request Buffer**: `max_request_bytes: 4194304` (4MB) configured in ext_authz
- [ ] **ext_authz Timeout**: 5s gRPC service timeout configured  
- [ ] **Rate Limit Timeout**: 2s gRPC timeout configured
- [ ] **HTTP Timeouts**: 10s request_timeout, 300s stream_idle_timeout configured
- [ ] **Heap Size**: 384MB (75% of 512MB container) configured
- [ ] **Health Checks**: RLS clusters have health check endpoints
- [ ] **Circuit Breakers**: Connection limits configured for RLS clusters
- [ ] **Access Logs**: HTTP access logs enabled and showing all requests
- [ ] **RLS Connectivity**: Envoy can reach RLS on port 8080 (test with nc -z)
- [ ] **ext_authz Working**: Authorization requests appear in RLS logs
- [ ] **No Buffer Warnings**: No "buffer size limit exceeded" in logs
- [ ] **Memory Usage**: Heap usage stays under 384MB limit
- [ ] **Request Processing**: Large requests (up to 4MB) processed successfully
- [ ] **Concurrent Handling**: Multiple concurrent requests handled without overflow
- [ ] **Timeout Handling**: No hanging requests or indefinite retries
- [ ] **Logs Show Traffic**: Actual /api/v1/push requests visible in Envoy logs (not just /ready)

#### **Production Readiness Validation**

```bash
# Final production readiness check
echo "=== Production Readiness Validation ==="

# 1. Verify all pods are ready and healthy
kubectl get pods -l app.kubernetes.io/name=mimir-envoy -n mimir-edge-enforcement
kubectl wait --for=condition=ready pods -l app.kubernetes.io/name=mimir-envoy -n mimir-edge-enforcement --timeout=120s

# 2. Check resource usage is within limits
kubectl top pods -l app.kubernetes.io/name=mimir-envoy -n mimir-edge-enforcement

# 3. Verify HPA and PDB are configured
kubectl get hpa mimir-envoy -n mimir-edge-enforcement
kubectl get pdb mimir-envoy-pdb -n mimir-edge-enforcement

# 4. Test service connectivity to RLS
kubectl exec -it deployment/mimir-envoy -n mimir-edge-enforcement -- \
  curl -s http://mimir-rls:8080/health

# 5. Verify network policies (if enabled)
kubectl describe networkpolicy -n mimir-edge-enforcement | grep mimir-envoy

echo "✅ Envoy deployment with buffer overflow fixes is production ready!"
```

### Step 6: Deploy Admin UI (Optional)

```bash
# Create values file for Admin UI
cat > values-admin-ui.yaml <<EOF
# Production configuration for Admin UI
replicaCount: 3

image:
  repository: ghcr.io/akshaydubey29/mimir-edge-admin
  tag: "latest"  # 🔴 CHANGE: Use specific SHA in production
  pullPolicy: IfNotPresent

# Resource configuration
resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 50m
    memory: 64Mi

# Auto-scaling
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80

# High availability
podDisruptionBudget:
  enabled: true
  minAvailable: 2

# Service configuration
service:
  type: ClusterIP
  port: 80

# AWS ALB Ingress configuration (production-ready default)
ingress:
  enabled: true
  className: "alb"  # AWS Application Load Balancer
  annotations:
    # AWS ALB Configuration
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:ap-northeast-2:138978013424:certificate/7b1c00f5-19ee-4e6c-9ca5-b30679ea6043"  # 🔴 CHANGE: Your ACM certificate ARN
    alb.ingress.kubernetes.io/healthcheck-path: "/healthz"
    alb.ingress.kubernetes.io/backend-protocol-version: "HTTP1"
    alb.ingress.kubernetes.io/target-group-attributes: "stickiness.enabled=false,deregistration_delay.timeout_seconds=30,stickiness.type=lb_cookie,stickiness.lb_cookie.duration_seconds=86400"
    alb.ingress.kubernetes.io/inbound-cidrs: "10.0.0.0/8"
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
    alb.ingress.kubernetes.io/scheme: "internal"
    alb.ingress.kubernetes.io/security-groups: "sg-03a537b10f8b71c3c,sg-0faab6bb8700b4164"  # 🔴 CHANGE: Your security groups
    alb.ingress.kubernetes.io/subnets: "subnet-01ab33de57fc8101,subnet-0247d97d25e7469f8,subnet-0ebfe41b055fd0ec3,subnet-0971e77d71ee66018"  # 🔴 CHANGE: Your subnets
    alb.ingress.kubernetes.io/success-codes: "200"
    alb.ingress.kubernetes.io/tags: "role=couwatch_mimir"
    alb.ingress.kubernetes.io/target-type: "ip"
    kubernetes.io/ingress.class: "alb"
    
    # Security and rate limiting
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    
    # CORS for Admin UI
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE, OPTIONS"
    nginx.ingress.kubernetes.io/cors-allow-headers: "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization,Content-Length"
    nginx.ingress.kubernetes.io/cors-allow-credentials: "true"
  hosts:
    - host: mimir-edge-enforcement.vzonel.kr.couwatchdev.net  # 🔴 CHANGE: Your domain
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: mimir-admin-tls
      hosts:
        - mimir-edge-enforcement.vzonel.kr.couwatchdev.net

# API configuration
config:
  apiBaseUrl: "http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8082"
  serverName: "mimir-edge-enforcement.vzonel.kr.couwatchdev.net"  # 🔴 CHANGE: Your domain

# Security
securityContext:
  runAsNonRoot: true
  runAsUser: 101  # nginx user
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true

# Image pull secrets
imagePullSecrets:
  - name: ghcr-secret
EOF

# Create basic auth secret for Admin UI (optional)
htpasswd -c auth admin
kubectl create secret generic admin-ui-auth --from-file=auth -n mimir-edge-enforcement
rm auth

# Deploy Admin UI
helm install mimir-admin charts/admin-ui \
  --namespace mimir-edge-enforcement \
  --values values-admin-ui.yaml \
  --wait --timeout=300s

# Verify deployment
kubectl get pods -l app.kubernetes.io/name=mimir-admin -n mimir-edge-enforcement
kubectl get ingress -n mimir-edge-enforcement

# Test Admin UI
curl https://mimir-admin.your-domain.com/api/tenants
```

### Step 7: Deploy with Production Values (All-in-One Alternative)

As an alternative to the component-by-component approach above, use the production values template:

```bash
# Use the production values file
cp examples/values/production.yaml values-production.yaml

# Customize for your environment
cat > values-production.yaml <<EOF
# 🎯 PRODUCTION CONFIGURATION
global:
  imageRegistry: ghcr.io/akshaydubey29
  imagePullSecrets:
    - name: ghcr-secret

# 🛡️ RLS (Rate Limiting Service)
rls:
  enabled: true
  replicaCount: 3
  image:
    tag: "latest"  # Use specific SHA: "abc123def456" in production
  
  resources:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 500m
      memory: 512Mi
  
  hpa:
    enabled: true
    minReplicas: 3
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
  
  pdb:
    enabled: true
    minAvailable: 2
  
  config:
    mimir:
      namespace: "mimir"
      overridesConfigMap: "mimir-overrides"
    
    # ConfigMap-driven limits (0 = read from Mimir ConfigMap)
    defaultSamplesPerSecond: 0
    defaultBurstPercent: 0
    maxBodyBytes: 0
    
    log:
      level: "info"
      format: "json"

# 🔄 Overrides-Sync Controller
overridesSync:
  enabled: true
  replicaCount: 2  # HA for production
  
  image:
    tag: "latest"  # Use specific SHA in production
  
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 128Mi
  
  pdb:
    enabled: true
    minAvailable: 1
  
  config:
    mimir:
      namespace: "mimir"
      overridesConfigMap: "mimir-overrides"
    pollFallbackSeconds: 30
    log:
      level: "info"

# 🌐 Envoy Proxy
envoy:
  enabled: true
  replicaCount: 3
  
  image:
    tag: "latest"  # Use specific SHA in production
  
  resources:
    limits:
      cpu: 1000m
      memory: 512Mi          # Fixed to match heap size configuration
    requests:
      cpu: 200m
      memory: 256Mi
  
  hpa:
    enabled: true
    minReplicas: 3
    maxReplicas: 15
    targetCPUUtilizationPercentage: 80
  
  pdb:
    enabled: true
    minAvailable: 2
  
  service:
    type: ClusterIP
    port: 8080
    annotations: {}
  
  config:
    mimir:
      distributorHost: "distributor.mimir.svc.cluster.local"
      distributorPort: 8080
    
    rls:
      host: "mimir-rls.mimir-edge-enforcement.svc.cluster.local"
      extAuthzPort: 8080
      rateLimitPort: 8081
    
    extAuthz:
      maxRequestBytes: 4194304  # 4 MiB (provides buffer management)
      failureModeAllow: false   # Fail closed for security - set to true for debugging
      # 🔧 TIMEOUT FIXES:
      timeout: "5s"             # gRPC service timeout prevents hanging
    
    rateLimit:
      failureModeDeny: true     # Deny on rate limit service failure
      # 🔧 TIMEOUT FIXES:
      grpcTimeout: "2s"         # gRPC call timeout
    
    # 🔧 DEBUG: Logging configuration for troubleshooting
    logging:
      level: "info"             # Change to "debug" for verbose logging
      enableAccessLogs: true    # Enable to see all HTTP requests
      enableDebugLogs: false    # Enable for detailed filter debugging
    
    tenantHeader: "X-Scope-OrgID"
  
  # Resource limits and overload protection (fixed for buffer overflow)
  resourceLimits:
    maxHeapSizeBytes: 402653184          # 384 MiB (75% of 512Mi container) - FIXED
    shrinkHeapThreshold: 0.8             # Shrink heap at 80%
    heapStopAcceptingThreshold: 0.95     # Stop accepting at 95% heap

# 📊 Admin UI  
adminUI:
  enabled: true
  replicaCount: 3
  
  image:
    tag: "latest"  # Use specific SHA in production
  
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 50m
      memory: 64Mi
  
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 10
    targetCPUUtilizationPercentage: 80
  
  podDisruptionBudget:
    enabled: true
    minAvailable: 2
  
  # 🌍 AWS ALB Ingress Configuration (Production Default)
  ingress:
    enabled: true
    className: "alb"  # AWS Application Load Balancer
    annotations:
      # AWS ALB Configuration
      alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:ap-northeast-2:138978013424:certificate/7b1c00f5-19ee-4e6c-9ca5-b30679ea6043"  # 🔴 CHANGE: Your ACM certificate
      alb.ingress.kubernetes.io/healthcheck-path: "/healthz"
      alb.ingress.kubernetes.io/backend-protocol-version: "HTTP1"
      alb.ingress.kubernetes.io/target-group-attributes: "stickiness.enabled=false,deregistration_delay.timeout_seconds=30"
      alb.ingress.kubernetes.io/inbound-cidrs: "10.0.0.0/8"
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
      alb.ingress.kubernetes.io/scheme: "internal"
      alb.ingress.kubernetes.io/security-groups: "sg-03a537b10f8b71c3c,sg-0faab6bb8700b4164"  # 🔴 CHANGE: Your security groups
      alb.ingress.kubernetes.io/subnets: "subnet-01ab33de57fc8101,subnet-0247d97d25e7469f8,subnet-0ebfe41b055fd0ec3,subnet-0971e77d71ee66018"  # 🔴 CHANGE: Your subnets
      alb.ingress.kubernetes.io/success-codes: "200"
      alb.ingress.kubernetes.io/tags: "role=couwatch_mimir"
      alb.ingress.kubernetes.io/target-type: "ip"
      kubernetes.io/ingress.class: "alb"
      
      # Security and rate limiting
      nginx.ingress.kubernetes.io/rate-limit: "100"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
    
    hosts:
      - host: mimir-edge-enforcement.vzonel.kr.couwatchdev.net  # 🔴 CHANGE: Your domain
        paths:
          - path: /
            pathType: Prefix
    
    tls:
      - secretName: mimir-admin-tls
        hosts:
          - mimir-edge-enforcement.vzonel.kr.couwatchdev.net
  
  # 🔐 Security
  auth:
    enabled: true
    type: "basic"
    credentials:
      admin: "$2y$10$..."  # htpasswd generated hash
  
  # 🛡️ Security Headers
  security:
    enabled: true
    headers:
      contentSecurityPolicy: "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'"
      xFrameOptions: "DENY"
      xContentTypeOptions: "nosniff"
  
  # 🌐 CORS Configuration
  cors:
    enabled: true
    allowedOrigins:
      - "https://mimir-admin.your-domain.com"
    allowedMethods: ["GET", "POST", "PUT", "DELETE"]
    allowedHeaders: ["Content-Type", "Authorization"]
  
  # 🔒 Network Policy
  networkPolicy:
    enabled: true
    ingress:
      - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
        ports:
        - protocol: TCP
          port: 80

# 🔒 Global Security Settings
securityContext:
  runAsNonRoot: true
  runAsUser: 65532
  fsGroup: 65532
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL

# 📊 Monitoring
monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s
    scrapeTimeout: 10s
  
  grafana:
    dashboards:
      enabled: true

# 🔗 Network Policies
networkPolicy:
  enabled: true
  policyTypes:
    - Ingress
    - Egress
  
  ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            name: mimir
      - namespaceSelector:
          matchLabels:
            name: ingress-nginx
  
  egress:
    - to:
      - namespaceSelector:
          matchLabels:
            name: mimir
    - to: []  # Allow DNS resolution
      ports:
      - protocol: UDP
        port: 53
EOF

# Deploy using Helm
helm install mimir-edge-enforcement . \
  --namespace mimir-edge-enforcement \
  --values values-production.yaml \
  --wait --timeout=600s
```

## 🎯 NGINX Canary Integration

### Step 8: Configure NGINX for Canary Rollout

Update your existing NGINX configuration for **safe canary deployment**:

```bash
# Backup current NGINX config
kubectl get configmap mimir-nginx -n mimir -o yaml > backup-nginx-config.yaml

# Apply canary-enabled NGINX configuration
kubectl apply -f examples/nginx-with-canary.yaml

# Restart NGINX to pick up changes
kubectl rollout restart deployment/mimir-nginx -n mimir
```

### Step 9: Manage Canary Rollout

Use the canary management script for **safe traffic migration**:

```bash
# Check current status
./scripts/manage-canary.sh status

# Start with shadow testing (non-blocking)
./scripts/manage-canary.sh mirror

# Monitor shadow traffic for 24 hours
kubectl logs -l app=mimir-rls -n mimir-edge-enforcement --tail=100 -f

# Begin gradual canary rollout
./scripts/manage-canary.sh set 10   # 10% through edge enforcement
./scripts/manage-canary.sh set 25   # Increase to 25%
./scripts/manage-canary.sh set 50   # 50% canary traffic
./scripts/manage-canary.sh set 100  # Full rollout

# Emergency rollback if needed
./scripts/manage-canary.sh bypass   # Instant bypass (0%)
```

## 📊 Post-Deployment Verification

### Step 10: Verify All Components

```bash
# Check all pods are running
kubectl get pods -n mimir-edge-enforcement

# Verify services
kubectl get services -n mimir-edge-enforcement

# Check ingress (if Admin UI enabled)
kubectl get ingress -n mimir-edge-enforcement

# Test service connectivity
kubectl exec -it deployment/mimir-rls -n mimir-edge-enforcement -- \
  wget -qO- http://mimir-envoy:8080/stats | grep -E "(ready|healthy)"
```

### Step 11: Verify Mimir ConfigMap Integration

```bash
# Check overrides-sync logs for tenant parsing
kubectl logs -l app.kubernetes.io/name=overrides-sync -n mimir-edge-enforcement

# Expected log output:
# {"level":"info","message":"found overrides.yaml - parsing Mimir YAML format"}
# {"level":"info","message":"found tenants in overrides YAML","tenants_in_yaml":2}
# {"level":"info","message":"syncing overrides to RLS","tenant_count":2}

# Verify RLS received tenant limits
kubectl exec -it deployment/mimir-rls -n mimir-edge-enforcement -- \
  wget -qO- http://localhost:8082/api/tenants | jq .
```

### Step 12: Test Rate Limiting

```bash
# Port forward for testing
kubectl port-forward svc/mimir-envoy 8080:8080 -n mimir-edge-enforcement &

# Test with valid tenant (should succeed)
curl -H "X-Scope-OrgID: tenant-production" \
     -H "Content-Type: application/x-protobuf" \
     -X POST \
     http://localhost:8080/api/v1/push \
     --data-binary @test-metrics.pb

# Test with unknown tenant (should be limited based on defaults)
curl -H "X-Scope-OrgID: unknown-tenant" \
     -X POST \
     http://localhost:8080/api/v1/push \
     --data-binary @test-metrics.pb

# Check RLS metrics
curl http://localhost:8082/metrics | grep -E "(tenant_requests|denied_requests)"
```

## 📈 Monitoring & Observability

### Metrics Endpoints
```bash
# RLS metrics
kubectl port-forward svc/mimir-rls 8082:8082 -n mimir-edge-enforcement
curl http://localhost:8082/metrics

# Envoy admin interface
kubectl port-forward svc/mimir-envoy 8001:8001 -n mimir-edge-enforcement  
curl http://localhost:8001/stats | grep -E "(ext_authz|ratelimit)"

# Admin UI (if deployed with Ingress)
curl https://mimir-admin.your-domain.com/api/tenants
```

### Key Metrics to Monitor
- **RLS**: `tenant_requests_total`, `rate_limit_decisions_total`, `denied_requests_total`
- **Envoy**: `ext_authz.allowed`, `ext_authz.denied`, `ratelimit.ok`, `ratelimit.over_limit`
- **Envoy Buffer**: `ext_authz.max_request_bytes`, `ext_authz.timeout`, `http.request_timeout` (should be stable)
- **Envoy Overload**: `overload.envoy.overload_actions.*.scale_timer`, `server.memory_heap_size`, `http.inbound.downstream_cx_active`
- **Overrides-Sync**: `config_map_syncs_total`, `tenant_count`, `sync_errors_total`

### Grafana Dashboards
```bash
# Import pre-built dashboards
# Note: Dashboard files are now in the dashboards/ folder

# Or access the Admin UI for real-time monitoring
open https://mimir-admin.your-domain.com
```

## 🛡️ Production Security

### Network Policies
```bash
# Apply comprehensive network policies
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: mimir-edge-enforcement-netpol
  namespace: mimir-edge-enforcement
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: mimir
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
    - protocol: TCP
      port: 8082
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: mimir
    ports:
    - protocol: TCP
      port: 8080
  - to: []  # DNS
    ports:
    - protocol: UDP
      port: 53
EOF
```

### RBAC (Already configured in Helm charts)
```bash
# Verify RBAC permissions
kubectl auth can-i get configmaps --as=system:serviceaccount:mimir-edge-enforcement:overrides-sync -n mimir
kubectl auth can-i watch configmaps --as=system:serviceaccount:mimir-edge-enforcement:overrides-sync -n mimir
```

## 🔄 Operational Procedures

### Upgrading
```bash
# Update image tags in values file
sed -i 's/tag: "latest"/tag: "v1.2.3"/' values-production.yaml

# Rolling upgrade
helm upgrade mimir-edge-enforcement . \
  --namespace mimir-edge-enforcement \
  --values values-production.yaml \
  --wait --timeout=600s

# Verify upgrade
kubectl rollout status deployment/mimir-rls -n mimir-edge-enforcement
kubectl rollout status deployment/overrides-sync -n mimir-edge-enforcement
kubectl rollout status deployment/mimir-envoy -n mimir-edge-enforcement
```

### Backup & Restore
```bash
# Backup Helm values and ConfigMaps
helm get values mimir-edge-enforcement -n mimir-edge-enforcement > backup-values.yaml
kubectl get configmap -n mimir-edge-enforcement -o yaml > backup-configmaps.yaml

# Backup Mimir overrides ConfigMap
kubectl get configmap mimir-overrides -n mimir -o yaml > backup-mimir-overrides.yaml
```

### Scaling
```bash
# Manual scaling
kubectl scale deployment/mimir-rls --replicas=5 -n mimir-edge-enforcement
kubectl scale deployment/mimir-envoy --replicas=8 -n mimir-edge-enforcement

# Or update HPA settings
kubectl patch hpa mimir-rls-hpa -n mimir-edge-enforcement -p '{"spec":{"maxReplicas":15}}'
```

## 🚨 Troubleshooting

### Common Issues & Solutions

1. **`tenant_count: 0` in overrides-sync logs**:
   ```bash
   # Check Mimir ConfigMap format
   kubectl get configmap mimir-overrides -n mimir -o yaml
   
   # Verify it has 'overrides.yaml' key with nested YAML structure
   # See docs/troubleshooting-overrides-sync.md for detailed guide
   ```

2. **Envoy returning 503 errors**:
   ```bash
   # Check RLS connectivity
   kubectl exec -it deployment/mimir-envoy -n mimir-edge-enforcement -- \
     wget -qO- http://mimir-rls:8080/health
   
   # Check Envoy admin interface
   kubectl port-forward svc/mimir-envoy 8001:8001 -n mimir-edge-enforcement
   curl http://localhost:8001/clusters | grep mimir-rls
   ```

3. **426 Upgrade Required errors (NGINX → Envoy)**:
   ```bash
   # Check if using latest Envoy chart (v0.2.0+)
   helm list -n mimir-edge-enforcement | grep mimir-envoy
   
   # Verify HTTP protocol configuration
   kubectl get configmap mimir-envoy-config -n mimir-edge-enforcement -o yaml | grep -A 10 "http_protocol_options"
   
   # Apply emergency fix if needed
   ./scripts/fix-envoy-426.sh
   
   # Test protocol compatibility
   kubectl port-forward svc/mimir-envoy 8080:8080 -n mimir-edge-enforcement &
   curl -v --http1.1 http://localhost:8080/api/v1/push
   # Should NOT return 426 Upgrade Required
   ```

4. **Buffer overflow errors (ext_authz retries exceeded)**:
   ```bash
   # Check for buffer overflow warnings in Envoy logs
   kubectl logs -l app.kubernetes.io/name=mimir-envoy -n mimir-edge-enforcement | grep "buffer.*size.*limit"
   
   # Verify request buffer configuration (should be 4MB)
   kubectl get configmap mimir-envoy-config -n mimir-edge-enforcement -o yaml | grep -A 5 "max_request_bytes"
   
   # Check timeout settings in gRPC services
   kubectl get configmap mimir-envoy-config -n mimir-edge-enforcement -o yaml | grep -A 3 "timeout"
   
   # Verify HTTP connection manager timeouts
   kubectl get configmap mimir-envoy-config -n mimir-edge-enforcement -o yaml | grep -A 3 "request_timeout"
   
   # Verify RLS service health
   kubectl exec -it deployment/mimir-envoy -n mimir-edge-enforcement -- \
     curl -s http://mimir-rls:8080/health
   ```

5. **ext_authz denying all requests (only /ready logs visible)**:
   ```bash
   # Quick diagnosis of ext_authz issues
   ./scripts/check-ext-authz-rls-connectivity.sh
   
   # Comprehensive diagnosis
   ./scripts/diagnose-envoy-ext-authz-issue.sh
   
   # Temporarily bypass ext_authz for testing
   ./scripts/temporarily-bypass-ext-authz.sh
   
   # Check if RLS is reachable from Envoy
   kubectl exec -it deployment/mimir-envoy -n mimir-edge-enforcement -- \
     nc -z mimir-rls.mimir-edge-enforcement.svc.cluster.local 8080
   
   # Enable access logging temporarily (if not already enabled)
   helm upgrade mimir-envoy charts/envoy \
     --set logging.enableAccessLogs=true \
     --set logging.level=debug \
     --namespace mimir-edge-enforcement
   
   # Check logs for actual request processing
   kubectl logs -l app.kubernetes.io/name=mimir-envoy -n mimir-edge-enforcement --tail=50
   
   # Restore normal logging settings
   helm upgrade mimir-envoy charts/envoy \
     --set logging.level=info \
     --namespace mimir-edge-enforcement
   ```

6. **Rate limits not applied**:
   ```bash
   # Check overrides-sync is running and syncing
   kubectl logs -l app.kubernetes.io/name=overrides-sync -n mimir-edge-enforcement
   
   # Verify RLS has received tenant data
   kubectl exec -it deployment/mimir-rls -n mimir-edge-enforcement -- \
     wget -qO- http://localhost:8082/api/tenants
   ```

7. **NGINX canary not routing correctly**:
   ```bash
   # Check canary status
   ./scripts/manage-canary.sh status
   
   # Verify NGINX configuration
   kubectl exec -it deployment/mimir-nginx -n mimir -- cat /etc/nginx/nginx.conf | grep -A 20 "canary"
   
   # Check canary routing logs
   kubectl logs -l app=mimir-nginx -n mimir --tail=100 | grep "X-Canary-Route"
   ```

8. **Envoy overload actions triggered**:
   ```bash
   # Check overload status
   kubectl port-forward svc/mimir-envoy 8001:8001 -n mimir-edge-enforcement
   curl http://localhost:8001/stats | grep overload
   
   # Check connection and memory usage
   curl http://localhost:8001/stats | grep -E "(downstream_cx_active|memory_heap_size)"
   
   # Scale up if needed
   kubectl scale deployment/mimir-envoy --replicas=5 -n mimir-edge-enforcement
   ```

### Emergency Procedures
```bash
# Instant bypass (route all traffic direct to Mimir)
./scripts/manage-canary.sh bypass

# Scale down problematic components
kubectl scale deployment/mimir-envoy --replicas=0 -n mimir-edge-enforcement

# Rollback to previous version
helm rollback mimir-edge-enforcement 1 -n mimir-edge-enforcement

# Emergency ConfigMap update (disable enforcement)
kubectl patch configmap mimir-rls-config -n mimir-edge-enforcement -p '{"data":{"default_samples_per_second":"999999999"}}'
```

## 🧹 Clean Up

```bash
# Remove the complete deployment
helm uninstall mimir-edge-enforcement -n mimir-edge-enforcement

# Remove namespace
kubectl delete namespace mimir-edge-enforcement

# Restore original NGINX configuration
kubectl apply -f backup-nginx-config.yaml
kubectl rollout restart deployment/mimir-nginx -n mimir
```

---

## 📚 Additional Resources

- **[NGINX Canary Setup Guide](nginx-canary-setup.md)**: Detailed canary rollout procedures
- **[Overrides-Sync Troubleshooting](troubleshooting-overrides-sync.md)**: Fix ConfigMap parsing issues
- **[Envoy Resource Limits](envoy-resource-limits.md)**: Configure overload protection and monitoring
- **[Envoy HTTP Protocol Fix](envoy-http-protocol-fix.md)**: Permanent solution for 426 Upgrade Required errors
- **[Envoy Buffer Overflow Fixes](envoy-buffer-overflow-fixes.md)**: Critical fixes for buffer size limit errors
- **[Production Values Examples](../examples/values/)**: Template configurations
- **[Monitoring & Dashboards](../examples/monitoring/)**: Grafana dashboards and alerts

This deployment guide provides a **complete production-ready setup** with **canary rollout capabilities**, **real Mimir ConfigMap integration**, and **comprehensive monitoring**. The system supports **zero-downtime deployment** with **instant rollback** capabilities for maximum operational safety! 🚀