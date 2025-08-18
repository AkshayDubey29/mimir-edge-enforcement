# Critical Bug Fix: Selective Filtering Not Working

## 🚨 **Issue Identified**

The selective filtering implementation had a **critical bug** that prevented it from actually filtering metrics before they reached Mimir. This is why you were still seeing metrics being dropped at the Mimir distributor/ingester level.

## 🔍 **Root Cause Analysis**

### **The Problem**

The selective filtering logic was implemented but **the filtered body was never used**. Here's what was happening:

1. **Request Flow:**
   ```
   handleRemoteWrite() 
   → CheckRemoteWriteLimits() 
   → SelectiveFilterRequest() 
   → Creates SelectiveFilterResult with FilteredBody
   → CheckRemoteWriteLimits() returns only Decision (not filtered body)
   → handleRemoteWrite() uses original body (not filtered)
   → Original body sent to Mimir
   ```

2. **The Bug:**
   - `SelectiveFilterRequest()` correctly created a filtered body in `SelectiveFilterResult.FilteredBody`
   - But `CheckRemoteWriteLimits()` only returned a `limits.Decision` (not the filtered body)
   - `handleRemoteWrite()` used the **original body** instead of the filtered body
   - **Result: Unfiltered metrics reached Mimir and got discarded there**

### **Evidence**

- RLS logs showed selective filtering activity
- But Mimir distributor logs showed metrics being received and discarded
- `cortex_discarded_samples_total` was still high
- Metrics were reaching Mimir instead of being filtered at RLS

## 🛠️ **The Fix**

### **Solution Overview**

1. **Created new function** `CheckRemoteWriteLimitsWithFiltering()` that returns both decision and filtered body
2. **Updated `handleRemoteWrite()`** to use the filtered body when available
3. **Maintained backward compatibility** with existing `CheckRemoteWriteLimits()` function

### **Code Changes**

#### **1. New Function Signature**
```go
// Before
func (rls *RLS) CheckRemoteWriteLimits(tenantID string, body []byte, contentEncoding string) limits.Decision

// After  
func (rls *RLS) CheckRemoteWriteLimitsWithFiltering(tenantID string, body []byte, contentEncoding string) (limits.Decision, []byte)
```

#### **2. Updated Request Handler**
```go
// Before
decision := rls.CheckRemoteWriteLimits(tenantID, body, r.Header.Get("Content-Encoding"))
mimirReq, err := http.NewRequest("POST", mimirURL, bytes.NewReader(body))

// After
decision, filteredBody := rls.CheckRemoteWriteLimitsWithFiltering(tenantID, body, r.Header.Get("Content-Encoding"))
bodyToSend := filteredBody
if len(filteredBody) == 0 {
    bodyToSend = body
}
mimirReq, err := http.NewRequest("POST", mimirURL, bytes.NewReader(bodyToSend))
```

#### **3. Selective Filtering Return**
```go
// In selective filtering branch
if rls.config.SelectiveFiltering.Enabled {
    selectiveResult := rls.SelectiveFilterRequest(tenantID, body, contentEncoding)
    // ...
    return decision, selectiveResult.FilteredBody  // Return filtered body
} else {
    // ...
    return decision, body  // Return original body
}
```

## 🎯 **Expected Behavior After Fix**

### **Before Fix (Broken)**
```
Request: 150 series (limit: 100)
RLS: Creates filtered body with 100 series
RLS: Discards filtered body (bug!)
RLS: Sends original 150 series to Mimir
Mimir: Receives 150 series, drops 50
Result: ❌ Metrics still dropped at Mimir level
```

### **After Fix (Working)**
```
Request: 150 series (limit: 100)
RLS: Creates filtered body with 100 series
RLS: Sends filtered body (100 series) to Mimir
Mimir: Receives 100 series, no drops needed
Result: ✅ Metrics filtered at RLS level
```

## 📊 **Verification Steps**

### **1. Check RLS Logs**
Look for selective filtering activity:
```bash
kubectl logs -n mimir-edge-enforcement deployment/mimir-rls | grep -i "selective"
```

### **2. Check Mimir Distributor Logs**
Should see fewer incoming metrics:
```bash
kubectl logs -n mimir-edge-enforcement deployment/mimir-distributor | grep -i "received"
```

### **3. Monitor Metrics**
- `cortex_discarded_samples_total` should decrease
- RLS selective filtering metrics should increase
- Mimir ingestion metrics should show filtered data

## 🚀 **Deployment**

The fix is now ready for deployment. The selective filtering will work correctly:

1. **Metrics exceeding limits** will be filtered at RLS level
2. **Only compliant metrics** will reach Mimir
3. **Reduced load** on Mimir distributor/ingester
4. **Better resource utilization** across the pipeline

## 🔧 **Configuration**

The lenient selective filtering configuration remains the same:
```yaml
selectiveFiltering:
  enabled: true
  seriesSelectionStrategy: "random"
  maxFilteringPercentage: 100
  minSeriesToKeep: 1
```

This fix ensures that the selective filtering logic actually works as intended, preventing metrics from reaching Mimir when they exceed configured limits.
