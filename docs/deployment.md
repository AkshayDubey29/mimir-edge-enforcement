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
# ✅ Envoy Proxy
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

# Deploy RLS
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

```bash
# Create values file for Envoy
cat > values-envoy.yaml <<EOF
# Production configuration for Envoy
replicaCount: 3

image:
  repository: ghcr.io/akshaydubey29/mimir-envoy
  tag: "latest"  # 🔴 CHANGE: Use specific SHA in production
  pullPolicy: IfNotPresent

# Resource configuration
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
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

# Resource limits and overload protection
resourceLimits:
  maxDownstreamConnections: 25000      # High for production traffic
  maxHeapSizeBytes: 838860800          # 800 MiB (80% of 1Gi container)
  disableKeepaliveThreshold: 0.8       # Disable keepalive at 80%
  stopAcceptingRequestsThreshold: 0.95 # Stop accepting at 95%
  shrinkHeapThreshold: 0.8             # Shrink heap at 80%
  heapStopAcceptingThreshold: 0.95     # Stop accepting at 95% heap

# External authorization
extAuthz:
  maxRequestBytes: 4194304  # 4 MiB
  failureModeAllow: false   # Fail closed for security

# Rate limiting
rateLimit:
  failureModeDeny: true     # Deny on rate limit service failure

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
curl http://localhost:8001/ready
curl http://localhost:8001/stats | grep -E "(ready|healthy)"
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

# Ingress configuration (customize for your setup)
ingress:
  enabled: true
  className: "nginx"  # 🔧 CUSTOMIZE: Your ingress class
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: admin-ui-auth
    nginx.ingress.kubernetes.io/rate-limit: "100"
  hosts:
    - host: mimir-admin.your-domain.com  # 🔴 CHANGE: Your domain
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: mimir-admin-tls
      hosts:
        - mimir-admin.your-domain.com

# API configuration
config:
  apiBaseUrl: "http://mimir-rls.mimir-edge-enforcement.svc.cluster.local:8082"
  serverName: "mimir-admin.your-domain.com"  # 🔴 CHANGE: Your domain

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
      memory: 1Gi
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
      maxRequestBytes: 4194304  # 4 MiB
      failureModeAllow: false   # Fail closed for security
    
    rateLimit:
      failureModeDeny: true     # Deny on rate limit service failure
    
    tenantHeader: "X-Scope-OrgID"
  
  # Resource limits and overload protection
  resourceLimits:
    maxDownstreamConnections: 25000      # High for production traffic
    maxHeapSizeBytes: 838860800          # 800 MiB (80% of 1Gi container)
    disableKeepaliveThreshold: 0.8       # Disable keepalive at 80%
    stopAcceptingRequestsThreshold: 0.95 # Stop accepting at 95%
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
  
  # 🌍 Ingress Configuration
  ingress:
    enabled: true
    className: "nginx"  # Adjust for your ingress controller
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      nginx.ingress.kubernetes.io/auth-type: basic
      nginx.ingress.kubernetes.io/auth-secret: admin-ui-auth
      nginx.ingress.kubernetes.io/rate-limit: "100"
      nginx.ingress.kubernetes.io/rate-limit-window: "1m"
    
    hosts:
      - host: mimir-admin.your-domain.com
        paths:
          - path: /
            pathType: Prefix
    
    tls:
      - secretName: mimir-admin-tls
        hosts:
          - mimir-admin.your-domain.com
  
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
- **Envoy Overload**: `overload.envoy.overload_actions.*.scale_timer`, `server.memory_heap_size`, `http.inbound.downstream_cx_active`
- **Overrides-Sync**: `config_map_syncs_total`, `tenant_count`, `sync_errors_total`

### Grafana Dashboards
```bash
# Import pre-built dashboards
kubectl apply -f examples/monitoring/grafana-dashboards.yaml

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

3. **Rate limits not applied**:
   ```bash
   # Check overrides-sync is running and syncing
   kubectl logs -l app.kubernetes.io/name=overrides-sync -n mimir-edge-enforcement
   
   # Verify RLS has received tenant data
   kubectl exec -it deployment/mimir-rls -n mimir-edge-enforcement -- \
     wget -qO- http://localhost:8082/api/tenants
   ```

4. **NGINX canary not routing correctly**:
   ```bash
   # Check canary status
   ./scripts/manage-canary.sh status
   
   # Verify NGINX configuration
   kubectl exec -it deployment/mimir-nginx -n mimir -- cat /etc/nginx/nginx.conf | grep -A 20 "canary"
   
   # Check canary routing logs
   kubectl logs -l app=mimir-nginx -n mimir --tail=100 | grep "X-Canary-Route"
   ```

5. **Envoy overload actions triggered**:
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
- **[Production Values Examples](../examples/values/)**: Template configurations
- **[Monitoring & Dashboards](../examples/monitoring/)**: Grafana dashboards and alerts

This deployment guide provides a **complete production-ready setup** with **canary rollout capabilities**, **real Mimir ConfigMap integration**, and **comprehensive monitoring**. The system supports **zero-downtime deployment** with **instant rollback** capabilities for maximum operational safety! 🚀