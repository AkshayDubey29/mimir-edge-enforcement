# RLS Monitoring Dashboard for Grafana

This directory contains a comprehensive Grafana dashboard for monitoring the Rate Limiting Service (RLS) in your Mimir Edge Enforcement system.

## 📊 Dashboard Overview

The **RLS Monitoring Dashboard** provides deep insights into:

- **Request Processing**: Decision rates, allow/deny ratios
- **Performance Metrics**: Response times, throughput
- **Enforcement Status**: Limit violations, denial reasons
- **Tenant Analytics**: Per-tenant metrics and limits
- **System Health**: Error rates, parse failures

## 🚀 Quick Start

### 1. Import the Dashboard

1. Open Grafana in your browser
2. Navigate to **Dashboards** → **Import**
3. Click **Upload JSON file** and select `rls-monitoring-dashboard.json`
4. Configure the data source:
   - **Data Source**: Select your Prometheus data source (e.g., `mimir-couwatch`)
   - **Folder**: Choose where to save the dashboard
   - **Name**: "RLS Monitoring Dashboard" (or your preferred name)

### 2. Verify Data Source

Ensure your Prometheus data source is configured with:
- **Name**: `mimir-couwatch` (or update the dashboard JSON)
- **URL**: Your Prometheus endpoint
- **Access**: Server (default) or Browser (if CORS enabled)

## 📈 Dashboard Panels

### **Top Row - Overview**
1. **RLS Decision Rate**: Total requests per second
2. **Denial Rate**: Percentage of requests being denied

### **Second Row - Enforcement Analysis**
3. **Denial Reasons Breakdown**: Stacked chart showing why requests are denied
4. **Requests by Tenant**: Traffic distribution across tenants

### **Third Row - Performance**
5. **95th Percentile Response Time**: Performance indicator
6. **Total Request Rate**: Overall throughput

### **Fourth Row - Series Tracking**
7. **Series Count by Tenant**: Current series counts
8. **Limit Thresholds by Tenant**: Configured limits

### **Fifth Row - Violations**
9. **Limit Violations by Tenant and Reason**: Detailed violation tracking

### **Bottom Row - System Health**
10. **Body Parse Errors**: Parsing failure count
11. **Average Request Body Size**: Request size monitoring

## 🔧 Key Metrics Explained

### **Core RLS Metrics**
- `rls_decisions_total`: Total authorization decisions (allow/deny)
- `rls_authz_check_duration_seconds`: Response time histogram
- `rls_body_parse_errors_total`: Body parsing failures

### **Enforcement Metrics**
- `rls_limit_violations_total`: Limit violation counters
- `rls_series_count_gauge`: Current series counts
- `rls_limit_threshold_gauge`: Configured limit thresholds

### **Performance Metrics**
- `rls_traffic_flow_total`: Traffic flow counters
- `rls_traffic_flow_latency`: Latency measurements

## 🎯 Key Insights to Monitor

### **1. Denial Rate Analysis**
- **Green**: < 10% denial rate
- **Yellow**: 10-50% denial rate
- **Red**: > 50% denial rate

### **2. Performance Thresholds**
- **Response Time**: < 100ms (95th percentile)
- **Throughput**: Monitor for bottlenecks
- **Error Rate**: < 1% parse errors

### **3. Enforcement Effectiveness**
- **Limit Violations**: Track which limits are being hit
- **Series Growth**: Monitor cardinality trends
- **Tenant Behavior**: Identify problematic tenants

## 🔍 Troubleshooting

### **No Data Showing**
1. Check Prometheus data source connection
2. Verify RLS metrics are being scraped
3. Check time range (default: last 1 hour)

### **Missing Metrics**
1. Ensure RLS service is running
2. Check Prometheus scrape configuration
3. Verify metric names match your RLS version

### **High Denial Rates**
1. Review tenant limits in ConfigMap
2. Check for misconfigured limits
3. Analyze denial reasons breakdown

## 📋 Alerting Recommendations

### **Critical Alerts**
```promql
# High denial rate
rate(rls_decisions_total{decision="deny"}[5m]) / rate(rls_decisions_total[5m]) > 0.5

# High response time
histogram_quantile(0.95, rate(rls_authz_check_duration_seconds_bucket[5m])) > 0.5

# High error rate
rate(rls_body_parse_errors_total[5m]) > 10
```

### **Warning Alerts**
```promql
# Moderate denial rate
rate(rls_decisions_total{decision="deny"}[5m]) / rate(rls_decisions_total[5m]) > 0.1

# High series count approaching limits
rls_series_count_gauge / rls_limit_threshold_gauge > 0.8
```

## 🎨 Customization

### **Adding New Panels**
1. Edit the JSON file
2. Add new panel definitions
3. Import updated dashboard

### **Modifying Queries**
1. Open panel edit mode
2. Modify PromQL expressions
3. Save changes

### **Changing Time Ranges**
- **Short-term**: 1 hour (default)
- **Medium-term**: 6 hours
- **Long-term**: 24 hours

## 📚 Additional Resources

- **PromQL Reference**: [Prometheus Query Language](https://prometheus.io/docs/prometheus/latest/querying/)
- **Grafana Documentation**: [Grafana Dashboards](https://grafana.com/docs/grafana/latest/dashboards/)
- **RLS Metrics**: Check your RLS service documentation for available metrics

## 🤝 Support

If you encounter issues:
1. Check the troubleshooting section above
2. Verify your Prometheus data source configuration
3. Ensure RLS metrics are being exposed correctly
4. Review the RLS service logs for any errors

---

**Dashboard Version**: 1.0  
**Compatible RLS Version**: Latest  
**Last Updated**: August 2025
