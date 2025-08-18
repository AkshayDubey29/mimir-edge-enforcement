# Grafana Dashboard Updates for Status Codes and Query Syntax

## 🎯 **Overview**

Updated all Grafana dashboards to reflect the new status code semantics and fix PromQL query syntax:

- **413 (Payload Too Large)**: Actual request body size issues
- **429 (Too Many Requests)**: Rate limiting and quota violations
- **Query Syntax**: Fixed `sum(...) by (...)` to `sum by (...) (...)`

## 📊 **Dashboards Updated**

### **1. RLS Comprehensive Dashboard** (`dashboards/rls-comprehensive.json`)

#### **Query Syntax Fixes**
- ✅ `sum(rate(rls_decisions_total[5m])) by (decision, tenant)` → `sum by (decision, tenant) (rate(rls_decisions_total[5m]))`
- ✅ `sum(rate(rls_decisions_total[5m])) by (reason)` → `sum by (reason) (rate(rls_decisions_total[5m]))`
- ✅ `histogram_quantile(0.95, sum(rate(rls_authz_check_duration_seconds_bucket[5m])) by (le, tenant))` → `histogram_quantile(0.95, sum by (le, tenant) (rate(rls_authz_check_duration_seconds_bucket[5m])))`
- ✅ `sum(rate(rls_traffic_flow_total[5m])) by (tenant, decision)` → `sum by (tenant, decision) (rate(rls_traffic_flow_total[5m]))`
- ✅ `sum(rate(rls_limit_violations_total[5m])) by (tenant, reason)` → `sum by (tenant, reason) (rate(rls_limit_violations_total[5m]))`

#### **Status Code Updates**
- ✅ Updated descriptions to clarify 429 for limit violations, 413 for size issues
- ✅ Added new panel: "RLS Status Code Analysis"
- ✅ Added new panel: "RLS 413 vs 429 Distribution"

### **2. Overview Comprehensive Dashboard** (`dashboards/overview-comprehensive.json`)

#### **Query Syntax Fixes**
- ✅ `sum(rate(rls_decisions_total{decision="deny"}[5m])) by (tenant)` → `sum by (tenant) (rate(rls_decisions_total{decision="deny"}[5m]))`
- ✅ `sum(rate(envoy_http_downstream_rq_xx{envoy_response_code_class="4"}[5m])) by (route)` → `sum by (route) (rate(envoy_http_downstream_rq_xx{envoy_response_code_class="4"}[5m]))`
- ✅ `histogram_quantile(0.95, sum(rate(envoy_http_downstream_rq_time_bucket[5m])) by (le, route))` → `histogram_quantile(0.95, sum by (le, route) (rate(envoy_http_downstream_rq_time_bucket[5m])))`
- ✅ `sum(rate(rls_traffic_flow_total[5m])) by (tenant, decision)` → `sum by (tenant, decision) (rate(rls_traffic_flow_total[5m]))`
- ✅ `sum(rate(rls_limit_violations_total[5m])) by (reason)` → `sum by (reason) (rate(rls_limit_violations_total[5m]))`

#### **Status Code Updates**
- ✅ Updated "Rate Limiting Effectiveness" description
- ✅ Updated "Error Rates" description to clarify 413 vs 429
- ✅ Updated "Limit Violations by Type" description

### **3. Tenant Deny Spikes Dashboard** (`dashboards/tenant-deny-spikes.json`)

#### **Query Syntax Fixes**
- ✅ `rate(rls_decisions_total{decision="deny"}[5m]) by (tenant)` → `sum by (tenant) (rate(rls_decisions_total{decision="deny"}[5m]))`
- ✅ `rate(rls_limit_violations_total[5m]) by (tenant, reason)` → `sum by (tenant, reason) (rate(rls_limit_violations_total[5m]))`
- ✅ `rate(rls_traffic_flow_total[5m]) by (tenant, decision)` → `sum by (tenant, decision) (rate(rls_traffic_flow_total[5m]))`
- ✅ `rate(rls_traffic_flow_bytes[5m]) by (tenant)` → `sum by (tenant) (rate(rls_traffic_flow_bytes[5m]))`

#### **Status Code Updates**
- ✅ Updated "Denies by Tenant" description
- ✅ Updated "Limit Violations by Tenant" description

### **4. Envoy Comprehensive Dashboard** (`dashboards/envoy-comprehensive.json`)

#### **Status Code Updates**
- ✅ Updated "Envoy HTTP 429 Rate Limited" description to clarify 413 vs 429

### **5. Grafana RLS Monitoring Dashboard** (`dashboards/rls-monitoring-dashboard.json`)

#### **Query Syntax Fixes**
- ✅ `rate(rls_decisions_total{decision="deny"}[5m]) by (reason, tenant)` → `sum by (reason, tenant) (rate(rls_decisions_total{decision="deny"}[5m]))`
- ✅ `rate(rls_decisions_total[5m]) by (tenant, decision)` → `sum by (tenant, decision) (rate(rls_decisions_total[5m]))`
- ✅ `rate(rls_limit_violations_total[5m]) by (tenant, reason)` → `sum by (tenant, reason) (rate(rls_limit_violations_total[5m]))`

### **6. Grafana RLS Redis Monitoring Dashboard** (`dashboards/rls-redis-monitoring-dashboard.json`)

#### **Query Syntax Fixes**
- ✅ `rate(rls_traffic_flow_total[5m]) by (tenant)` → `sum by (tenant) (rate(rls_traffic_flow_total[5m]))`

## 🎯 **Status Code Semantics**

### **413 (Payload Too Large)**
- **When to use**: Actual request body size exceeds server limits
- **Example**: Request body is 60MB when server limit is 50MB
- **Dashboard indication**: Size-related errors, actual payload issues

### **429 (Too Many Requests)**
- **When to use**: Rate limiting, quota violations, or limit breaches
- **Examples**: 
  - Body size exceeds tenant's configured limit
  - Labels per series exceeds tenant's configured limit
  - Samples per second exceeds rate limit
  - Bytes per second exceeds rate limit
- **Dashboard indication**: Limit violations, rate limiting

## 📈 **Expected Dashboard Behavior**

### **Before (Incorrect)**
```
413 errors: High (limit violations + actual size issues)
429 errors: Low (only rate limiting)
Query syntax: sum(...) by (...) (incorrect)
```

### **After (Correct)**
```
413 errors: Low (only actual size issues)
429 errors: High (limit violations + rate limiting)
Query syntax: sum by (...) (...) (correct)
```

## 🔧 **New Dashboard Panels**

### **RLS Comprehensive Dashboard**
1. **RLS Status Code Analysis**: Shows denied requests by tenant and reason
2. **RLS 413 vs 429 Distribution**: Shows distribution of 413 vs 429 errors

## 📊 **Monitoring Benefits**

### **1. Better Error Classification**
- **413 errors**: Indicate actual payload size issues (rare, needs investigation)
- **429 errors**: Indicate limit violations (expected, can be monitored for trends)

### **2. Improved Debugging**
- Clear distinction between size issues and limit issues
- Better capacity planning and limit tuning
- More accurate alerting

### **3. Correct Query Syntax**
- All PromQL queries now use correct `sum by (...) (...)` syntax
- Better performance and compatibility
- Follows Prometheus best practices

## 🚀 **Deployment Status**

- ✅ **All dashboards updated**: Status codes and query syntax fixed
- ✅ **Descriptions updated**: Clear indication of 413 vs 429 semantics
- ✅ **New panels added**: Status code analysis panels
- ✅ **Query syntax corrected**: All `sum(...) by (...)` → `sum by (...) (...)`

## 📋 **Next Steps**

1. **Import updated dashboards** into Grafana
2. **Verify query syntax** works correctly
3. **Monitor status code distribution** (should see shift from 413 to 429)
4. **Update alerts** if needed based on new status code semantics
5. **Document the changes** for team reference

## 🎉 **Summary**

All Grafana dashboards have been updated to:

- ✅ **Correct status code semantics**: 413 for size issues, 429 for limit violations
- ✅ **Fixed query syntax**: Proper PromQL `sum by (...) (...)` syntax
- ✅ **Enhanced descriptions**: Clear indication of what each status code means
- ✅ **Added analysis panels**: Better visibility into status code distribution

The dashboards now provide accurate monitoring and better debugging capabilities for the RLS service!
