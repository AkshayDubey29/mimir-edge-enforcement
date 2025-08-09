# 📋 RLS Logging Guide

This guide explains how to enable and interpret RLS logs to troubleshoot API responses and tenant data issues.

## 🎯 **Quick Start: Enable Debug Logging**

```bash
# Enable detailed debug logging
./scripts/enable-rls-debug-logs.sh

# Follow logs in real-time
./scripts/enable-rls-debug-logs.sh --follow-logs

# Show recent logs only
./scripts/enable-rls-debug-logs.sh --show-logs
```

## 📊 **Log Types and What They Tell You**

### **1. API Response Logs**

These logs show exactly what the RLS is returning to the Admin UI:

#### **Overview API (`/api/overview`)**
```json
{
  "level": "info",
  "total_requests": 1250,
  "allowed_requests": 1180,
  "denied_requests": 70,
  "allow_percentage": 94.4,
  "active_tenants": 3,
  "message": "overview API response"
}
```

**What this tells you:**
- ✅ **`active_tenants: 3`** = RLS has 3 tenants loaded (good!)
- ❌ **`active_tenants: 0`** = No tenants loaded (check overrides-sync)

#### **Tenants API (`/api/tenants`)**
```json
// When tenants exist:
{
  "level": "info",
  "tenant_count": 2,
  "tenant_0_id": "tenant-production",
  "tenant_0_samples_limit": 350000,
  "tenant_0_allow_rate": 1250.5,
  "tenant_0_deny_rate": 15.2,
  "tenant_0_enforcement": true,
  "message": "tenants API response with tenant details"
}

// When NO tenants exist:
{
  "level": "info",
  "tenant_count": 0,
  "message": "tenants API response: NO TENANTS FOUND - this explains zero active tenants!"
}
```

**What this tells you:**
- ✅ **`tenant_count > 0`** = RLS has tenant data
- ❌ **`tenant_count: 0`** = No tenant data (overrides-sync issue)

### **2. Tenant Loading Logs**

These logs show when RLS receives tenant data from overrides-sync:

#### **New Tenant Creation**
```json
{
  "level": "info",
  "tenant_id": "tenant-production",
  "message": "RLS: creating new tenant from overrides-sync"
}
```

#### **Tenant Limits Received**
```json
{
  "level": "info",
  "tenant_id": "tenant-production",
  "is_new_tenant": true,
  "samples_per_second": 350000,
  "burst_percent": 0.2,
  "max_body_bytes": 4194304,
  "total_tenants_after": 1,
  "message": "RLS: received tenant limits from overrides-sync"
}
```

**What this tells you:**
- ✅ **Seeing these logs** = overrides-sync is working and sending data
- ❌ **Not seeing these logs** = overrides-sync not communicating with RLS

### **3. Periodic Status Logs**

Every minute, RLS logs its current tenant status:

#### **With Tenants Loaded**
```json
{
  "level": "info",
  "tenant_count": 2,
  "active_counters": 2,
  "tenant_ids": ["tenant-production", "tenant-staging"],
  "message": "RLS: periodic tenant status - TENANTS LOADED"
}
```

#### **No Tenants Loaded**
```json
{
  "level": "info",
  "tenant_count": 0,
  "active_counters": 0,
  "message": "RLS: periodic tenant status - NO TENANTS (check overrides-sync)"
}
```

**What this tells you:**
- ✅ **"TENANTS LOADED"** = RLS is healthy with tenant data
- ❌ **"NO TENANTS"** = Persistent issue with tenant loading

## 🔧 **Log Level Configuration**

### **Debug Level (Most Detailed)**
```bash
# Enable debug logging
./scripts/enable-rls-debug-logs.sh --enable-debug
```

**Shows:**
- All API requests and responses
- Bucket creation/updates for each tenant
- Detailed tenant limit processing
- HTTP request handling details

### **Info Level (Recommended)**
```bash
# Enable info logging  
./scripts/enable-rls-debug-logs.sh --enable-info
```

**Shows:**
- API response summaries
- Tenant loading events
- Periodic status updates
- Important system events

## 🔍 **Troubleshooting with Logs**

### **Problem: Admin UI shows "Active tenants: 0"**

#### **Step 1: Check API Response Logs**
```bash
# Enable debug logging if not already enabled
./scripts/enable-rls-debug-logs.sh

# Test the API and watch logs
kubectl port-forward svc/mimir-rls 8082:8082 -n mimir-edge-enforcement &
curl http://localhost:8082/api/overview
curl http://localhost:8082/api/tenants
```

#### **Step 2: Look for These Log Patterns**

**✅ If you see:**
```
"tenants API response with tenant details" tenant_count=2
```
→ **RLS has tenants** - UI issue, check Admin UI logs

**❌ If you see:**
```
"tenants API response: NO TENANTS FOUND"
```
→ **RLS has no tenants** - overrides-sync issue

#### **Step 3: Check Tenant Loading**
```bash
# Look for tenant loading logs
kubectl logs -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement | grep "overrides-sync"
```

**✅ If you see:**
```
"RLS: received tenant limits from overrides-sync" tenant_id=tenant-production
```
→ **overrides-sync is working**

**❌ If you don't see these logs:**
```
"RLS: periodic tenant status - NO TENANTS (check overrides-sync)"
```
→ **overrides-sync not sending data to RLS**

### **Problem: Tenants page shows map error**

#### **Check API Response Structure**
```bash
# Enable debug logging and test
./scripts/enable-rls-debug-logs.sh --follow-logs &

# In another terminal, test the API
curl http://localhost:8082/api/tenants | jq '.'
```

**Expected response:**
```json
{
  "tenants": [
    {
      "id": "tenant-production",
      "name": "tenant-production",
      "limits": { "samples_per_second": 350000 },
      "metrics": { "allow_rate": 150.5, "deny_rate": 5.2 },
      "enforcement": { "enabled": true }
    }
  ]
}
```

## 📱 **Real-Time Monitoring Commands**

### **Follow All RLS Logs**
```bash
kubectl logs -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement -f --timestamps
```

### **Filter for Specific Events**
```bash
# API responses only
kubectl logs -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement -f | grep "API response"

# Tenant loading only  
kubectl logs -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement -f | grep "overrides-sync"

# Periodic status only
kubectl logs -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement -f | grep "periodic tenant status"

# Error logs only
kubectl logs -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement -f | grep -E "(error|ERROR|panic)"
```

### **Search Recent Logs**
```bash
# Last hour of logs
kubectl logs -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement --since=1h | grep "tenant"

# Last 100 lines with tenant info
kubectl logs -l app.kubernetes.io/name=mimir-rls -n mimir-edge-enforcement --tail=100 | grep -E "(tenant|API response)"
```

## 🎯 **Expected Healthy Log Flow**

When everything is working correctly, you should see this sequence:

### **1. Startup**
```
"RLS service started"
"admin HTTP server started" port=8082
```

### **2. Tenant Loading (from overrides-sync)**
```
"RLS: creating new tenant from overrides-sync" tenant_id=tenant-production
"RLS: received tenant limits from overrides-sync" tenant_id=tenant-production samples_per_second=350000
"RLS: created samples bucket" tenant_id=tenant-production rate=350000
```

### **3. Periodic Status (every minute)**
```
"RLS: periodic tenant status - TENANTS LOADED" tenant_count=2 tenant_ids=["tenant-production","tenant-staging"]
```

### **4. API Requests (when Admin UI accesses)**
```
"handling /api/overview request"
"overview API response" active_tenants=2 total_requests=1250
"handling /api/tenants request"  
"tenants API response with tenant details" tenant_count=2
```

## 🚨 **Common Log Patterns for Issues**

### **🔍 Issue: overrides-sync not working**
```
"RLS: periodic tenant status - NO TENANTS (check overrides-sync)" tenant_count=0
```
**Solution:** Check overrides-sync deployment and logs

### **🔍 Issue: RLS API server not starting**
```
"failed to serve admin" error="listen tcp :8082: bind: address already in use"
```
**Solution:** Port conflict, check for existing processes

### **🔍 Issue: API request errors**
```
"panic in handleListTenants" panic="runtime error: nil pointer dereference"
```
**Solution:** Code bug, check for nil pointer access

### **🔍 Issue: Tenant limits not being applied**
```
"RLS: received tenant limits from overrides-sync" samples_per_second=0
"RLS: removed samples bucket (zero limit)"
```
**Solution:** Check Mimir ConfigMap format and overrides-sync parsing

---

**💡 Pro Tip:** Keep debug logging enabled during initial setup and troubleshooting, then switch to info level for production monitoring! 🎯
