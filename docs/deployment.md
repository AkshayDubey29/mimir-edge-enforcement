# Production Deployment Guide

This guide walks you through deploying **mimir-edge-enforcement** to a production Kubernetes cluster using Helm charts.

## Prerequisites

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

### 2. Cluster Access
```bash
# Verify cluster access
kubectl cluster-info
kubectl get nodes

# Ensure you have sufficient permissions
kubectl auth can-i create deployments --namespace=default
kubectl auth can-i create services --namespace=default
```

### 3. Container Registry Access
```bash
# Login to GitHub Container Registry (if using private repos)
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin

# Or create Kubernetes secret for image pulling
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=$GITHUB_USERNAME \
  --docker-password=$GITHUB_TOKEN \
  --docker-email=$GITHUB_EMAIL
```

## Deployment Steps

### Step 1: Create Namespace
```bash
# Create dedicated namespace for mimir edge enforcement
kubectl create namespace mimir-edge-enforcement

# Set as default context (optional)
kubectl config set-context --current --namespace=mimir-edge-enforcement
```

### Step 2: Configure Mimir Integration

Ensure your existing Mimir deployment has the required overrides ConfigMap:

```bash
# Check if Mimir overrides ConfigMap exists
kubectl get configmap mimir-overrides -n mimir

# If it doesn't exist, create a sample one
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: mimir-overrides
  namespace: mimir
data:
  overrides.yaml: |
    overrides:
      tenant-1:
        ingestion_rate: 10000
        ingestion_burst_size: 100000
        max_global_series_per_user: 1000000
      tenant-2:
        ingestion_rate: 5000
        ingestion_burst_size: 50000
        max_global_series_per_user: 500000
EOF
```

### Step 3: Deploy RLS (Rate Limiting Service)

```bash
# Clone the repository (if not already done)
git clone https://github.com/AkshayDubey29/mimir-edge-enforcement.git
cd mimir-edge-enforcement

# Create production values file
cat > values-production.yaml <<EOF
# Production configuration for RLS
replicaCount: 3

image:
  repository: ghcr.io/akshaydubey29/mimir-rls
  tag: "latest"  # Use specific SHA in production: "abc123def"
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

# Image pull secrets (if needed)
imagePullSecrets:
  - name: ghcr-secret
EOF

# Deploy RLS
helm install mimir-rls charts/mimir-rls \
  --namespace mimir-edge-enforcement \
  --values values-production.yaml \
  --wait --timeout=300s

# Verify deployment
kubectl get pods -l app.kubernetes.io/name=mimir-rls
kubectl get services -l app.kubernetes.io/name=mimir-rls
```

### Step 4: Deploy Overrides Sync Controller

```bash
# Create values for overrides-sync
cat > values-overrides-sync.yaml <<EOF
# Production configuration for overrides-sync
replicaCount: 2

image:
  repository: ghcr.io/akshaydubey29/overrides-sync
  tag: "latest"  # Use specific SHA in production
  pullPolicy: IfNotPresent

# Resource configuration
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

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
kubectl get pods -l app.kubernetes.io/name=overrides-sync
kubectl logs -l app.kubernetes.io/name=overrides-sync
```

### Step 5: Deploy Envoy Proxy

```bash
# Create values for Envoy
cat > values-envoy.yaml <<EOF
# Production configuration for Envoy
replicaCount: 3

image:
  repository: ghcr.io/akshaydubey29/mimir-envoy
  tag: "latest"  # Use specific SHA in production
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

# Mimir distributor configuration
mimir:
  distributorHost: "mimir-distributor.mimir.svc.cluster.local"
  distributorPort: 8080

# RLS configuration
rls:
  host: "mimir-rls.mimir-edge-enforcement.svc.cluster.local"
  extAuthzPort: 8080
  rateLimitPort: 8081

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
kubectl get pods -l app.kubernetes.io/name=mimir-envoy
kubectl get services -l app.kubernetes.io/name=mimir-envoy
```

### Step 6: Deploy Admin UI (Optional)

```bash
# Create values for Admin UI
cat > values-admin-ui.yaml <<EOF
# Production configuration for Admin UI
replicaCount: 2

image:
  repository: ghcr.io/akshaydubey29/mimir-edge-admin
  tag: "latest"  # Use specific SHA in production
  pullPolicy: IfNotPresent

# Resource configuration
resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 50m
    memory: 64Mi

# Service configuration
service:
  type: ClusterIP
  port: 80

# Ingress (configure based on your ingress controller)
ingress:
  enabled: true
  className: "nginx"  # or your ingress class
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
  hosts:
    - host: mimir-admin.your-domain.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: mimir-admin-tls
      hosts:
        - mimir-admin.your-domain.com

# Security
securityContext:
  runAsNonRoot: true
  runAsUser: 101  # nginx user

# Image pull secrets
imagePullSecrets:
  - name: ghcr-secret
EOF

# Deploy Admin UI
helm install mimir-admin charts/admin-ui \
  --namespace mimir-edge-enforcement \
  --values values-admin-ui.yaml \
  --wait --timeout=300s

# Verify deployment
kubectl get pods -l app.kubernetes.io/name=mimir-admin
kubectl get ingress
```

## Post-Deployment Configuration

### Step 7: Configure NGINX Upstream

Update your existing NGINX configuration to route through Envoy:

```nginx
# Add this upstream to your NGINX config
upstream mimir_with_enforcement {
    server mimir-envoy.mimir-edge-enforcement.svc.cluster.local:8080;
}

# Update your Mimir location block
location /api/v1/push {
    proxy_pass http://mimir_with_enforcement;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # Preserve tenant header
    proxy_set_header X-Scope-OrgID $http_x_scope_orgid;
}
```

### Step 8: Monitoring and Verification

```bash
# Check all pods are running
kubectl get pods -n mimir-edge-enforcement

# Check services
kubectl get services -n mimir-edge-enforcement

# View logs
kubectl logs -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement
kubectl logs -l app.kubernetes.io/name=overrides-sync -n mimir-edge-enforcement
kubectl logs -l app.kubernetes.io/name=mimir-envoy -n mimir-edge-enforcement

# Check metrics endpoints
kubectl port-forward svc/mimir-rls 9090:9090 -n mimir-edge-enforcement &
curl http://localhost:9090/metrics

# Test rate limiting (replace with actual tenant)
curl -H "X-Scope-OrgID: tenant-1" \
     -X POST \
     http://mimir-envoy.mimir-edge-enforcement.svc.cluster.local:8080/api/v1/push \
     --data-binary @sample-metrics.txt
```

## Production Best Practices

### Security
```bash
# Create network policies
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
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: mimir
EOF
```

### Monitoring
```bash
# Create ServiceMonitor for Prometheus
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: mimir-edge-enforcement
  namespace: mimir-edge-enforcement
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: mimir-rls
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
EOF
```

### Backup Values
```bash
# Save your production values
helm get values mimir-rls -n mimir-edge-enforcement > rls-values-backup.yaml
helm get values overrides-sync -n mimir-edge-enforcement > sync-values-backup.yaml
helm get values mimir-envoy -n mimir-edge-enforcement > envoy-values-backup.yaml
```

## Troubleshooting

### Common Issues

1. **Pods not starting**:
   ```bash
   kubectl describe pod <pod-name> -n mimir-edge-enforcement
   kubectl logs <pod-name> -n mimir-edge-enforcement
   ```

2. **Image pull errors**:
   ```bash
   # Check image pull secrets
   kubectl get secrets -n mimir-edge-enforcement
   kubectl describe secret ghcr-secret -n mimir-edge-enforcement
   ```

3. **Configuration issues**:
   ```bash
   # Check ConfigMaps
   kubectl get configmap -n mimir-edge-enforcement
   kubectl describe configmap <configmap-name> -n mimir-edge-enforcement
   ```

4. **Network connectivity**:
   ```bash
   # Test service DNS resolution
   kubectl exec -it <pod-name> -n mimir-edge-enforcement -- nslookup mimir-rls.mimir-edge-enforcement.svc.cluster.local
   ```

## Upgrading

```bash
# Update to new version
helm upgrade mimir-rls charts/mimir-rls \
  --namespace mimir-edge-enforcement \
  --values values-production.yaml \
  --set image.tag=new-sha-version

# Rollback if needed
helm rollback mimir-rls 1 -n mimir-edge-enforcement
```

## Clean Up

```bash
# Remove all components
helm uninstall mimir-rls -n mimir-edge-enforcement
helm uninstall overrides-sync -n mimir-edge-enforcement  
helm uninstall mimir-envoy -n mimir-edge-enforcement
helm uninstall mimir-admin -n mimir-edge-enforcement

# Remove namespace
kubectl delete namespace mimir-edge-enforcement
```

---

This deployment guide provides a complete production-ready setup for **mimir-edge-enforcement**. Adjust the values files according to your specific infrastructure requirements.
