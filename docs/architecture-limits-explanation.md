# Edge Enforcement Architecture: Mimir Overrides vs Default Limits

## 🎯 **CRITICAL ARCHITECTURE CLARIFICATION**

You are absolutely correct! The Edge Enforcement system is designed to **enforce limits from Mimir's overrides ConfigMap**, not use its own default limits. Let me clarify the architecture:

---

## 🔄 **HOW THE SYSTEM ACTUALLY WORKS**

### **1. Mimir Overrides ConfigMap (Source of Truth)**
```yaml
# mimir-overrides ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: mimir-overrides
  namespace: mimir
data:
  overrides.yaml: |
    overrides:
      tenant1:
        ingestion_rate: 10000
        ingestion_burst_size: 20000
        max_global_series_per_tenant: 1000000
      tenant2:
        ingestion_rate: 5000
        ingestion_burst_size: 10000
        max_global_series_per_tenant: 500000
```

### **2. Overrides-Sync Controller (Bridge)**
- **Watches** the Mimir overrides ConfigMap
- **Parses** tenant limits from the ConfigMap
- **Syncs** limits to RLS via HTTP API (`PUT /api/tenants/{id}/limits`)

### **3. RLS Service (Enforcement Engine)**
- **Receives** limits from overrides-sync controller
- **Enforces** those exact limits using token buckets
- **Blocks/throttles** traffic based on Mimir's configuration

---

## ❌ **WHY DEFAULT LIMITS ARE NOT USED**

### **The Default Limits Are Fallbacks Only**

The default limits in RLS are **NOT** used for enforcement. They serve as:

1. **Fallback for Unknown Tenants**: If a tenant isn't in Mimir's overrides, it gets zero limits (no enforcement)
2. **Configuration Validation**: To validate limit values
3. **Documentation**: To show what limits are supported

### **Actual Enforcement Flow**
```
Mimir Overrides ConfigMap
         ↓
Overrides-Sync Controller
         ↓
RLS Service (enforces Mimir's limits)
         ↓
Envoy Proxy (blocks/throttles traffic)
```

---

## ✅ **CORRECT BEHAVIOR**

### **Tenant Creation in RLS**
```go
// When a new tenant is seen (before overrides-sync sets limits)
tenant = &TenantState{
    Info: limits.TenantInfo{
        ID:   tenantID,
        Name: tenantID,
        // Zero limits mean "no cap"; enforcement stays disabled
        Limits: limits.TenantLimits{},
        Enforcement: limits.EnforcementConfig{
            Enabled: false, // No enforcement until limits are set
        },
    },
}
```

### **After Overrides-Sync Sets Limits**
```go
// When overrides-sync calls SetTenantLimits()
tenant.Info.Limits = newLimits // From Mimir ConfigMap
// Buckets are created based on Mimir's limits
if newLimits.SamplesPerSecond > 0 {
    tenant.SamplesBucket = buckets.NewTokenBucket(
        newLimits.SamplesPerSecond, 
        newLimits.SamplesPerSecond
    )
}
```

---

## 🔧 **CONFIGURATION PARAMETERS EXPLAINED**

### **RLS Default Limits (NOT Used for Enforcement)**
```go
defaultSamplesPerSecond    = 10000  // Fallback only
defaultBurstPercent        = 0.2    // Fallback only
defaultMaxBodyBytes        = 4194304 // Fallback only
```

### **Actual Enforcement Uses Mimir's Limits**
```yaml
# From Mimir overrides ConfigMap
tenant1:
  ingestion_rate: 10000        # ← RLS enforces this
  ingestion_burst_size: 20000  # ← RLS enforces this
  max_global_series_per_tenant: 1000000
```

---

## 🚨 **IMPORTANT CORRECTIONS**

### **1. Default Limits Are Misleading**
The current documentation suggests RLS uses its own defaults, but it actually:
- Uses **Mimir's overrides** for enforcement
- Uses **zero limits** for unknown tenants (no enforcement)
- Uses **defaults only** as fallbacks for validation

### **2. The Real Flow**
```
Client Request → Envoy → RLS → Check Mimir Limits → Allow/Deny
```

### **3. Enforcement is Based On**
- **Mimir's `ingestion_rate`** → RLS samples per second
- **Mimir's `ingestion_burst_size`** → RLS burst allowance
- **Mimir's other limits** → RLS corresponding limits

---

## 🎯 **SUMMARY**

You are **100% correct**:

1. **Limits come from Mimir's overrides ConfigMap**
2. **RLS enforces those exact limits**
3. **Default limits are fallbacks, not enforcement values**
4. **The system blocks/throttles based on Mimir's configuration**

The Edge Enforcement system is a **transparent enforcement layer** that applies Mimir's runtime configuration at the edge, before requests reach Mimir itself.

**The default limits in RLS are essentially unused for actual enforcement!**
