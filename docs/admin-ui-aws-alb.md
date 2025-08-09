# 🌐 Admin UI AWS ALB Deployment Guide

This guide shows how to deploy the Mimir Edge Enforcement Admin UI with **AWS Application Load Balancer (ALB)** for the domain `mimir-edge-enforcement.vzone1.kr.couwatchdev.net`.

## 🎯 Overview

The Admin UI will be deployed with:
- **AWS ALB Ingress** with internal scheme
- **ACM SSL Certificate** for HTTPS
- **VPC Security Groups** for network isolation  
- **Rate limiting** and security headers
- **Health checks** and monitoring
- **CORS configuration** for API access

## 📋 Prerequisites

### 1. AWS Infrastructure
- **AWS Load Balancer Controller** installed in cluster
- **ACM Certificate** for your domain: `arn:aws:acm:ap-northeast-2:138978013424:certificate/7b1c00f5-19ee-4e6c-9ca5-b30679ea6043`
- **VPC Subnets**: `subnet-01ab33de57fc8101`, `subnet-02487497d2f5e7469f8`, `subnet-0ebfe41b055fd0ec3`, `subnet-0971e77d71ee66018`
- **Security Groups**: `sg-0a537b10f8b71c3c`, `sg-05a0b6bb8700b4164`

### 2. Kubernetes Resources
- **Namespace**: `mimir-edge-enforcement`
- **RLS Service** deployed (Admin UI requires it)
- **Image Pull Secrets** for GitHub Container Registry

### 3. Tools
```bash
# Verify prerequisites
kubectl version --client
helm version
kubectl get deployment aws-load-balancer-controller -n kube-system
```

## 🚀 Deployment Options

### Option 1: Quick Deployment Script

```bash
# Deploy with automated script
./scripts/deploy-admin-ui-aws.sh

# Custom domain deployment
./scripts/deploy-admin-ui-aws.sh \
  --domain mimir-edge-enforcement.vzone1.kr.couwatchdev.net \
  --namespace mimir-edge-enforcement

# Preview deployment (dry-run)
./scripts/deploy-admin-ui-aws.sh --dry-run
```

### Option 2: Helm with Values File

```bash
# Deploy using pre-configured values
helm install mimir-edge-enforcement-admin-ui charts/admin-ui \
  --namespace mimir-edge-enforcement \
  --values examples/values/admin-ui-aws-alb.yaml \
  --wait --timeout=300s
```

### Option 3: Direct Ingress Application

```bash
# Apply pre-built Ingress YAML
kubectl apply -f examples/ingress/admin-ui-aws-alb.yaml

# Verify Ingress
kubectl get ingress -n mimir-edge-enforcement
kubectl describe ingress mimir-edge-enforcement-admin-ui -n mimir-edge-enforcement
```

## 🔧 Configuration Details

### ALB Ingress Configuration

```yaml
annotations:
  # AWS ALB Settings
  alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:ap-northeast-2:138978013424:certificate/7b1c00f5-19ee-4e6c-9ca5-b30679ea6043"
  alb.ingress.kubernetes.io/scheme: "internal"
  alb.ingress.kubernetes.io/inbound-cidrs: "10.0.0.0/8"
  alb.ingress.kubernetes.io/security-groups: "sg-0a537b10f8b71c3c,sg-05a0b6bb8700b4164"
  alb.ingress.kubernetes.io/subnets: "subnet-01ab33de57fc8101,subnet-02487497d2f5e7469f8,subnet-0ebfe41b055fd0ec3,subnet-0971e77d71ee66018"
  
  # Health Checks
  alb.ingress.kubernetes.io/healthcheck-path: "/healthz"
  alb.ingress.kubernetes.io/success-codes: "200"
  
  # Security
  nginx.ingress.kubernetes.io/rate-limit: "100"
  nginx.ingress.kubernetes.io/ssl-redirect: "true"
```

### Service Routes

| Path | Backend Service | Port | Purpose |
|------|----------------|------|---------|
| `/` | mimir-edge-enforcement-admin-ui | 80 | React Frontend |
| `/api` | mimir-rls | 8082 | Admin API |
| `/healthz` | mimir-edge-enforcement-admin-ui | 80 | Health Check |

### Security Features

- **Internal ALB**: Only accessible from VPC (10.0.0.0/8)
- **SSL/TLS**: HTTPS enforced with ACM certificate
- **Rate Limiting**: 100 requests/minute per IP
- **Security Headers**: XSS, CSRF, Content-Type protection
- **CORS**: Restricted to domain origin
- **Network Policies**: Pod-to-pod communication control

## 📊 Post-Deployment Verification

### 1. Check Deployment Status

```bash
# Verify pods are running
kubectl get pods -l app.kubernetes.io/name=mimir-edge-enforcement-admin-ui -n mimir-edge-enforcement

# Check service
kubectl get services -n mimir-edge-enforcement

# Verify ingress
kubectl get ingress -n mimir-edge-enforcement
kubectl describe ingress mimir-edge-enforcement-admin-ui -n mimir-edge-enforcement
```

### 2. ALB Status

```bash
# Get ALB URL
ALB_URL=$(kubectl get ingress mimir-edge-enforcement-admin-ui -n mimir-edge-enforcement -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "ALB URL: $ALB_URL"

# Check ALB health
curl -I https://$ALB_URL/healthz
```

### 3. Test Admin UI

```bash
# Health check
curl -k https://mimir-edge-enforcement.vzone1.kr.couwatchdev.net/healthz

# API endpoint
curl -k https://mimir-edge-enforcement.vzone1.kr.couwatchdev.net/api/tenants

# Access Admin UI in browser
open https://mimir-edge-enforcement.vzone1.kr.couwatchdev.net
```

## 🔍 Monitoring & Observability

### ALB Metrics

Monitor these CloudWatch metrics:
- `TargetResponseTime`
- `HTTPCode_Target_2XX_Count`
- `HTTPCode_Target_4XX_Count`  
- `HTTPCode_Target_5XX_Count`
- `RequestCount`
- `TargetHealthy/UnhealthyHostCount`

### Kubernetes Events

```bash
# Check ALB controller events
kubectl get events -n kube-system --sort-by='.lastTimestamp' | grep aws-load-balancer

# Check Admin UI events
kubectl get events -n mimir-edge-enforcement --sort-by='.lastTimestamp'

# Watch ingress status
kubectl get ingress -n mimir-edge-enforcement -w
```

### Application Logs

```bash
# Admin UI logs
kubectl logs -l app.kubernetes.io/name=mimir-edge-enforcement-admin-ui -n mimir-edge-enforcement

# ALB Controller logs  
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# RLS API logs (for Admin UI backend)
kubectl logs -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement
```

## 🚨 Troubleshooting

### Common Issues

#### 1. **ALB Not Provisioning**
```bash
# Check ALB controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verify IAM permissions for ALB controller
# Check subnet tags: kubernetes.io/role/elb=1
# Check security group rules
```

#### 2. **502 Bad Gateway**
```bash
# Check target group health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# Verify pod health
kubectl get pods -n mimir-edge-enforcement
curl -i http://<pod-ip>:80/healthz
```

#### 3. **SSL/TLS Issues**
```bash
# Verify certificate ARN is correct
aws acm describe-certificate --certificate-arn arn:aws:acm:ap-northeast-2:138978013424:certificate/7b1c00f5-19ee-4e6c-9ca5-b30679ea6043

# Check domain validation
nslookup mimir-edge-enforcement.vzone1.kr.couwatchdev.net
```

#### 4. **CORS Errors**
```bash
# Verify CORS headers
curl -H "Origin: https://mimir-edge-enforcement.vzone1.kr.couwatchdev.net" \
     -I https://mimir-edge-enforcement.vzone1.kr.couwatchdev.net/api/tenants
```

### Debug Commands

```bash
# Full ingress configuration
kubectl get ingress mimir-edge-enforcement-admin-ui -n mimir-edge-enforcement -o yaml

# ALB target groups
aws elbv2 describe-target-groups --names k8s-mimiRedg-mimiRedg-*

# Security group rules
aws ec2 describe-security-groups --group-ids sg-0a537b10f8b71c3c sg-05a0b6bb8700b4164
```

## 🔄 Updates & Maintenance

### Updating Admin UI

```bash
# Update with new image
helm upgrade mimir-edge-enforcement-admin-ui charts/admin-ui \
  --namespace mimir-edge-enforcement \
  --values examples/values/admin-ui-aws-alb.yaml \
  --set image.tag=v1.2.3

# Rolling restart
kubectl rollout restart deployment/mimir-edge-enforcement-admin-ui -n mimir-edge-enforcement
```

### Certificate Renewal

ACM certificates auto-renew, but verify:
```bash
aws acm describe-certificate --certificate-arn arn:aws:acm:ap-northeast-2:138978013424:certificate/7b1c00f5-19ee-4e6c-9ca5-b30679ea6043
```

## 🛡️ Security Best Practices

1. **Network Security**
   - Use internal ALB scheme
   - Restrict security groups to necessary ports
   - Enable VPC Flow Logs

2. **Application Security**  
   - Enable rate limiting
   - Use security headers
   - Implement basic auth if needed
   - Regular security updates

3. **Monitoring**
   - Set up CloudWatch alarms
   - Monitor access logs
   - Track error rates and latency

This configuration provides a **production-ready** Admin UI deployment with AWS ALB integration, following your existing infrastructure patterns! 🚀
