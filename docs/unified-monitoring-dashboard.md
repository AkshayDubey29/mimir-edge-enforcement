# Unified Monitoring Dashboard

## Overview

The **Unified Monitoring Dashboard** provides complete visibility into every endpoint across all services in the Edge Enforcement System. It serves as a **single source of truth** for monitoring the entire pipeline with automated validation and testing.

## 🎯 Key Features

### **Complete Endpoint Visibility**
- **All Services Monitored**: RLS, Envoy, Mimir, UI, Overrides-Sync
- **Every Endpoint Tracked**: Health checks, APIs, admin interfaces
- **Real-time Status**: Live updates every 10 seconds
- **Response Validation**: JSON validation, status codes, response times

### **Automated Testing**
- **Continuous Monitoring**: Runs every 30 seconds automatically
- **Request/Response Validation**: Ensures correct data structures
- **Performance Monitoring**: Tracks response times and throughput
- **Error Detection**: Immediate alerts for broken endpoints

### **Comprehensive Reporting**
- **Service Health**: Overall status for each service
- **Endpoint Details**: Individual endpoint performance and status
- **Validation Results**: API structure and data consistency checks
- **Performance Metrics**: Response times and throughput analysis

## 🏗️ Architecture

### **Backend Components**

#### **1. RLS Service (`/api/system/status`)**
```go
// Comprehensive system status endpoint
func (rls *RLS) GetComprehensiveSystemStatus() map[string]any {
    // Performs real-time endpoint checks
    // Validates all service responses
    // Calculates overall system health
    // Returns detailed status for UI
}
```

**Features:**
- **Real-time endpoint validation** for all services
- **Response structure validation** for API endpoints
- **Performance monitoring** with response time tracking
- **Health calculation** based on component status

#### **2. Automated Monitoring Script**
```bash
# scripts/automated-endpoint-monitoring.sh
# Runs continuously to validate all endpoints
./scripts/automated-endpoint-monitoring.sh daemon
```

**Features:**
- **30-second intervals** for continuous monitoring
- **Comprehensive logging** with rotation
- **JSON result storage** for historical analysis
- **Performance thresholds** with alerts

#### **3. Systemd Service**
```ini
# deploy/endpoint-monitoring.service
# Automated service for production deployment
[Unit]
Description=Edge Enforcement Endpoint Monitoring Service
After=network.target
```

## 📊 Dashboard Sections

### **1. Service Status Overview**
Displays health status for all services:
- **RLS Service**: Authorization and rate limiting
- **Envoy Proxy**: Traffic routing and enforcement
- **Mimir Backend**: Metrics storage and querying
- **UI Admin**: Web interface for management
- **Overrides Sync**: Configuration synchronization

**Status Indicators:**
- 🟢 **Healthy**: All endpoints responding correctly
- 🟡 **Degraded**: Some issues detected
- 🔴 **Critical**: Multiple failures detected
- ⚪ **Unknown**: Status unclear

### **2. Endpoint Details**
Comprehensive view of every endpoint:

#### **RLS Service Endpoints**
```
✅ /healthz - Service health check
✅ /readyz - Service readiness check
✅ /api/health - Admin health check
✅ /api/overview - System overview data
✅ /api/tenants - Tenant management
✅ /api/flow/status - Flow monitoring
✅ /api/system/status - Comprehensive status
✅ /api/pipeline/status - Pipeline health
✅ /api/metrics/system - System metrics
✅ /api/denials - Recent denials
✅ /api/export/csv - Data export
```

#### **Envoy Proxy Endpoints**
```
✅ /stats - Proxy statistics
✅ /health - Proxy health check
✅ :8081/health - External authorization
✅ :8083/health - Rate limiting service
```

#### **Mimir Backend Endpoints**
```
✅ /ready - Backend readiness
✅ /health - Backend health check
✅ /metrics - Prometheus metrics
✅ /api/v1/push - Remote write (405 for GET)
```

#### **UI Admin Endpoints**
```
✅ / - Overview page
✅ /tenants - Tenant management
✅ /denials - Denials monitoring
✅ /health - UI health check
✅ /pipeline - Pipeline status
✅ /metrics - System metrics
```

#### **Overrides Sync Endpoints**
```
✅ /health - Sync service health
✅ /ready - Sync service readiness
✅ /metrics - Sync metrics
```

### **3. Validation Results**
Three categories of validation:

#### **API Validation**
- **Overview Endpoint**: Validates required fields (stats, total_requests, etc.)
- **Tenants Endpoint**: Ensures tenants array structure
- **Flow Status Endpoint**: Validates flow_status, health_checks, flow_metrics

#### **Data Validation**
- **Tenant Limits**: Ensures proper configuration
- **Enforcement Logic**: Validates decision consistency
- **Metrics Consistency**: Cross-endpoint data validation

#### **Performance Validation**
- **Response Times**: Ensures < 1000ms threshold
- **Throughput**: Validates system capacity

## 🔧 Configuration

### **Service URLs**
```bash
# Default configuration
RLS_BASE_URL="http://localhost:8082"
ENVOY_BASE_URL="http://localhost:8080"
MIMIR_BASE_URL="http://localhost:9009"
UI_BASE_URL="http://localhost:3000"
OVERRIDES_SYNC_BASE_URL="http://localhost:8084"
```

### **Monitoring Intervals**
- **UI Auto-refresh**: 10 seconds
- **Automated Monitoring**: 30 seconds
- **Log Rotation**: 10MB threshold
- **Result Cleanup**: 24 hours retention

### **Performance Thresholds**
- **Excellent**: < 500ms response time
- **Good**: < 1000ms response time
- **Degraded**: > 1000ms response time
- **Critical**: > 5000ms response time

## 🚀 Usage

### **1. Start the Monitoring System**

#### **Manual Monitoring**
```bash
# Run once
./scripts/automated-endpoint-monitoring.sh once

# Run continuously
./scripts/automated-endpoint-monitoring.sh daemon

# Clean up old results
./scripts/automated-endpoint-monitoring.sh cleanup
```

#### **Systemd Service (Production)**
```bash
# Install service
sudo cp deploy/endpoint-monitoring.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable endpoint-monitoring
sudo systemctl start endpoint-monitoring

# Check status
sudo systemctl status endpoint-monitoring
sudo journalctl -u endpoint-monitoring -f
```

### **2. Access the Dashboard**

#### **Overview Page**
Navigate to the **Overview** page in the Admin UI to see:
- **Real-time service status**
- **Endpoint health indicators**
- **Performance metrics**
- **Validation results**
- **Flow monitoring**

#### **API Access**
```bash
# Get comprehensive system status
curl http://localhost:8082/api/system/status

# Get flow status
curl http://localhost:8082/api/flow/status

# Get overview data
curl http://localhost:8082/api/overview
```

### **3. Monitor Logs**

#### **Monitoring Logs**
```bash
# View monitoring logs
tail -f /tmp/endpoint-monitoring.log

# View results directory
ls -la /tmp/endpoint-monitoring-results/
```

#### **Service Logs**
```bash
# RLS service logs
kubectl logs -n mimir-edge-enforcement deployment/rls

# Envoy proxy logs
kubectl logs -n mimir-edge-enforcement deployment/envoy

# UI logs
kubectl logs -n mimir-edge-enforcement deployment/admin-ui
```

## 📈 Monitoring Metrics

### **Health Percentage Calculation**
```
Health % = (Healthy Endpoints / Total Endpoints) × 100

Status Levels:
- 95-100%: Healthy (All systems operational)
- 80-94%: Degraded (Some issues detected)
- 0-79%: Critical (Multiple failures)
```

### **Response Time Monitoring**
```
Performance Levels:
- < 500ms: Excellent
- 500-1000ms: Good
- 1000-5000ms: Degraded
- > 5000ms: Critical
```

### **Endpoint Validation**
```
Validation Checks:
- HTTP Status Codes: Expected vs Actual
- JSON Structure: Valid JSON for API endpoints
- Response Size: Content length validation
- Response Time: Performance threshold checking
```

## 🚨 Alerting and Troubleshooting

### **Common Issues**

#### **1. Service Unavailable**
```
Status: 🔴 Critical
Message: "Service unavailable"
Action: Check if service is running
```

**Troubleshooting:**
```bash
# Check service status
kubectl get pods -n mimir-edge-enforcement

# Check service logs
kubectl logs -n mimir-edge-enforcement deployment/[service-name]

# Check service endpoints
kubectl get endpoints -n mimir-edge-enforcement
```

#### **2. Slow Response Times**
```
Status: 🟡 Degraded
Message: "Slow response time: 1500ms"
Action: Investigate performance issues
```

**Troubleshooting:**
```bash
# Check resource usage
kubectl top pods -n mimir-edge-enforcement

# Check service metrics
curl http://localhost:8082/api/metrics/system

# Check network connectivity
kubectl exec -n mimir-edge-enforcement deployment/[service] -- ping [target]
```

#### **3. Invalid JSON Responses**
```
Status: 🔴 Error
Message: "Invalid JSON response"
Action: Check API implementation
```

**Troubleshooting:**
```bash
# Test endpoint directly
curl -v http://localhost:8082/api/overview

# Check API implementation
kubectl logs -n mimir-edge-enforcement deployment/rls | grep "panic"

# Validate JSON structure
curl http://localhost:8082/api/overview | jq .
```

### **Alerting Integration**

#### **Prometheus Alerts**
```yaml
# Example alert rules
groups:
  - name: endpoint-monitoring
    rules:
      - alert: EndpointDown
        expr: endpoint_status{status="error"} > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Endpoint {{ $labels.endpoint }} is down"
          description: "Service {{ $labels.service }} endpoint {{ $labels.endpoint }} is not responding"

      - alert: SlowResponse
        expr: endpoint_response_time > 1000
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Slow response time for {{ $labels.endpoint }}"
          description: "Response time is {{ $value }}ms"
```

#### **Slack/Email Integration**
```bash
# Send alerts to external systems
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"🚨 Edge Enforcement Alert: Service degraded"}' \
  https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
```

## 🔄 Continuous Improvement

### **Monitoring Enhancements**

#### **1. Custom Endpoints**
Add new endpoints to monitor:
```bash
# Edit monitoring script
vim scripts/automated-endpoint-monitoring.sh

# Add new endpoint validation
validate_custom_service() {
    local endpoints=(
        "custom_endpoint:http://localhost:8085/health:GET:200"
    )
    # ... validation logic
}
```

#### **2. Custom Validation Rules**
Add new validation criteria:
```go
// In RLS service
func (rls *RLS) validateCustomEndpoint(url string) map[string]any {
    // Custom validation logic
    return map[string]any{
        "status": "healthy",
        "message": "Custom validation passed",
        "custom_metric": "value",
    }
}
```

#### **3. Performance Tuning**
Adjust monitoring parameters:
```bash
# Modify monitoring intervals
MONITORING_INTERVAL=30  # seconds
PERFORMANCE_THRESHOLD=1000  # milliseconds
LOG_ROTATION_SIZE=10485760  # bytes
```

## 📚 Best Practices

### **1. Production Deployment**
- **Use systemd service** for automated monitoring
- **Configure log rotation** to prevent disk space issues
- **Set up alerting** for critical failures
- **Monitor resource usage** of monitoring system itself

### **2. Performance Optimization**
- **Use connection pooling** for HTTP clients
- **Implement caching** for frequently accessed data
- **Optimize JSON parsing** for large responses
- **Use async operations** where possible

### **3. Security Considerations**
- **Validate all inputs** to prevent injection attacks
- **Use HTTPS** for all external communications
- **Implement rate limiting** on monitoring endpoints
- **Secure sensitive data** in logs and responses

### **4. Maintenance**
- **Regular log cleanup** to prevent disk space issues
- **Monitor monitoring system** performance
- **Update endpoint lists** when services change
- **Review and adjust thresholds** based on usage patterns

## 🎉 Benefits

### **1. Complete Visibility**
- **Every endpoint monitored** across all services
- **Real-time status updates** with detailed information
- **Historical data** for trend analysis
- **Comprehensive reporting** for decision making

### **2. Proactive Monitoring**
- **Automated detection** of issues before they impact users
- **Performance monitoring** to prevent degradation
- **Validation checks** to ensure data integrity
- **Immediate alerts** for critical failures

### **3. Operational Excellence**
- **Single dashboard** for all monitoring needs
- **Automated testing** reduces manual effort
- **Detailed logging** for troubleshooting
- **Scalable architecture** for growth

### **4. Business Value**
- **Reduced downtime** through proactive monitoring
- **Improved performance** through continuous optimization
- **Better user experience** with reliable services
- **Operational efficiency** with automated processes

## 🔗 Related Documentation

- [Edge Enforcement Architecture](./architecture.md)
- [RLS Service Documentation](./rls-service.md)
- [Admin UI Guide](./admin-ui.md)
- [Deployment Guide](./deployment.md)
- [Troubleshooting Guide](./troubleshooting.md)

---

**The Unified Monitoring Dashboard provides the foundation for reliable, observable, and maintainable Edge Enforcement operations.**
