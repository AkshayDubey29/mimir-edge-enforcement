# Production Deployment Guide - Scientific Notation Fix

## 🎯 Overview

This guide provides instructions for deploying the scientific notation fix to production environments. The fix resolves the issue where overrides-sync couldn't parse scientific notation values like `5e+06` in the production ConfigMap.

## ✅ What's Fixed

- **Scientific notation parsing**: `5e+06` → `5000000`
- **Dual cardinality limits**: Both per-user and per-metric series limits
- **Production ConfigMap compatibility**: Works with existing production format
- **Backward compatibility**: No changes needed to existing ConfigMaps

## 🚀 Production Deployment Steps

### 1. Update Overrides-Sync Image

Update your production `values-overrides-sync.yaml` or Helm values:

```yaml
image:
  repository: ghcr.io/akshaydubey29/overrides-sync
  tag: "latest-scientific-notation-fix-arm64"  # 🔧 NEW: Scientific notation fix
  pullPolicy: IfNotPresent
```

### 2. Deploy the Update

```bash
# Update overrides-sync deployment
helm upgrade overrides-sync charts/overrides-sync -f values-overrides-sync.yaml -n <namespace>

# Verify deployment
kubectl rollout status deployment/overrides-sync -n <namespace>
```

### 3. Verify the Fix

Check the overrides-sync logs to confirm scientific notation parsing:

```bash
# Check parsing logs
kubectl logs -n <namespace> deployment/overrides-sync --tail=100 | grep "mapped max_global_series_per_user"

# Expected output:
# {"level":"debug","component":"overrides-sync","mimir_field":"max_global_series_per_user","mapped_value":5000000,"message":"mapped max_global_series_per_user to max_series_per_request (per-user limit)"}
```

### 4. Verify RLS Limits

Check that RLS is receiving the correct limits:

```bash
# Check RLS logs for tenant limits
kubectl logs -n <namespace> deployment/mimir-rls --tail=100 | grep "received tenant limits from overrides-sync"

# Generate test traffic to see current limits
./scripts/load-remote-write -samples 20 -series 15 -compression="none" -tenant="boltx"
```

## 📋 Production ConfigMap Format

Your existing production ConfigMap format is already correct:

```yaml
apiVersion: v1
data:
  overrides.yaml: |
    overrides:
      boltx:
        max_global_series_per_user: 5e+06      # ✅ Will now parse correctly
        max_label_names_per_series: 50         # ✅ Will map to max_labels_per_series
        # max_global_series_per_metric: NOT DEFINED → unlimited (0)
      benefit:
        max_global_series_per_user: 3e+06      # ✅ Will now parse correctly
        max_label_names_per_series: 50
      # ... other tenants
```

## 🔍 Expected Results

After deployment, you should see:

### Before Fix (Production Issue):
```json
{
  "tenant": "boltx",
  "max_series_per_request": 100000,        // ❌ Wrong (default value)
  "enforce_max_series_per_request": false, // ❌ Wrong (no enforcement)
  "max_series_per_metric": 0,              // ✅ Correct (unlimited)
  "enforce_max_series_per_metric": false   // ✅ Correct (no enforcement)
}
```

### After Fix (Expected):
```json
{
  "tenant": "boltx",
  "max_series_per_request": 5000000,       // ✅ Correct (from 5e+06)
  "enforce_max_series_per_request": true,  // ✅ Correct (enforcement enabled)
  "max_series_per_metric": 0,              // ✅ Correct (unlimited)
  "enforce_max_series_per_metric": false   // ✅ Correct (no enforcement)
}
```

## 🛠️ Troubleshooting

### Issue: Still seeing old values
```bash
# Restart RLS to clear cached values
kubectl rollout restart deployment/mimir-rls -n <namespace>

# Check overrides-sync is using new image
kubectl get deployment overrides-sync -n <namespace> -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### Issue: Parsing errors
```bash
# Check overrides-sync logs for parsing errors
kubectl logs -n <namespace> deployment/overrides-sync --tail=100 | grep -E "(error|failed|ERROR)"
```

### Issue: HTTP communication errors
```bash
# Check if overrides-sync can reach RLS
kubectl logs -n <namespace> deployment/overrides-sync --tail=100 | grep "successfully sent tenant limits to RLS"
```

## 📊 Monitoring

Monitor the deployment with these metrics:

1. **Overrides-sync parsing success rate**
2. **RLS limit enforcement effectiveness**
3. **Cardinality violation rates**
4. **Request denial rates**

## 🔄 Rollback Plan

If issues occur, rollback to the previous image:

```yaml
image:
  repository: ghcr.io/akshaydubey29/overrides-sync
  tag: "latest-dual-limits-arm64"  # Previous working version
```

## ✅ Success Criteria

- [ ] Overrides-sync parses `5e+06` as `5000000`
- [ ] RLS shows `max_series_per_request: 5000000` for boltx tenant
- [ ] RLS shows `enforce_max_series_per_request: true`
- [ ] No parsing errors in overrides-sync logs
- [ ] HTTP 200 responses from overrides-sync to RLS

## 🎉 Summary

This fix resolves the production issue where scientific notation values in the ConfigMap were not being parsed correctly, causing the dual cardinality limits to default to 0 and enforcement to be disabled.

**Production Ready**: ✅  
**Backward Compatible**: ✅  
**No ConfigMap Changes Required**: ✅
