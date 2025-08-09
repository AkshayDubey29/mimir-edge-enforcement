# Troubleshooting overrides-sync tenant_count: 0

If your overrides-sync is showing `tenant_count: 0` but you have tenants configured in your Mimir overrides ConfigMap, follow this guide to diagnose and fix the issue.

## 🔍 Quick Diagnosis Steps

### 1. Check overrides-sync Logs
```bash
# Check if overrides-sync is running
kubectl get pods -n mimir-edge-enforcement -l app.kubernetes.io/name=overrides-sync

# View detailed logs
kubectl logs -n mimir-edge-enforcement -l app.kubernetes.io/name=overrides-sync --tail=100

# Enable debug logging (if needed)
kubectl set env deployment/overrides-sync LOG_LEVEL=debug -n mimir-edge-enforcement
```

### 2. Verify ConfigMap Access
```bash
# Check if ConfigMap exists
kubectl get configmap mimir-overrides -n mimir

# View ConfigMap contents
kubectl get configmap mimir-overrides -n mimir -o yaml

# Check RBAC permissions
kubectl auth can-i get configmaps --as=system:serviceaccount:mimir-edge-enforcement:overrides-sync -n mimir
```

### 3. Test ConfigMap Format
Run the test script to verify your ConfigMap format:
```bash
# From the mimir-edge-enforcement directory
go run scripts/test-overrides-parsing.go
```

## 🐛 Common Issues & Solutions

### Issue 1: Wrong ConfigMap Format

**Symptoms:**
- Logs show: `skipping non-tenant-specific key`
- `tenant_count: 0` in logs

**Cause:** ConfigMap format doesn't match expected patterns

**Solution:** Update your ConfigMap to use supported formats:

✅ **Supported Formats:**

**Format 1: Real Mimir Production Format (Recommended)**
```yaml
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
      tenant-a:
        ingestion_rate: 350000
        ingestion_burst_size: 3.5e+06
        max_label_names_per_series: 50
        ingestion_tenant_shard_size: 8
        max_global_series_per_user: 3e+06
      tenant-b:
        ingestion_rate: 1e+07
        ingestion_burst_size: 3.5e+06
        max_label_names_per_series: 250
        cardinality_analysis_enabled: true
```

**Format 2: Legacy Flat Format (Backward Compatibility)**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mimir-overrides
  namespace: mimir
data:
  # Colon format
  "tenant-1:samples_per_second": "5000"
  "tenant-1:burst_percent": "0.1"
  "tenant-1:max_body_bytes": "1048576"
  
  # Dot format
  "tenant-2.ingestion_rate": "10000"
  "tenant-2.burst_pct": "0.2"
```

❌ **Unsupported Formats:**
```yaml
data:
  # YAML nested format (not supported)
  tenant-1:
    samples_per_second: 5000
    burst_percent: 0.1
  
  # Single values without tenant prefix
  samples_per_second: "5000"
  burst_percent: "0.1"
```

### Issue 2: RBAC Permissions

**Symptoms:**
- Logs show: `failed to get ConfigMap: configmaps "mimir-overrides" is forbidden`

**Solution:** Ensure overrides-sync has proper RBAC:
```bash
# Check current permissions
kubectl describe clusterrole overrides-sync

# Should have these permissions in target namespace:
# - get, list, watch on configmaps
```

### Issue 3: Wrong Namespace Configuration

**Symptoms:**
- Logs show: `failed to get ConfigMap: configmaps "mimir-overrides" not found`

**Solution:** Verify namespace configuration:
```bash
# Check deployment environment variables
kubectl get deployment overrides-sync -n mimir-edge-enforcement -o yaml | grep -A 10 env:

# Should show:
# - name: MIMIR_NAMESPACE
#   value: "mimir"  # Your actual Mimir namespace
# - name: OVERRIDES_CONFIGMAP
#   value: "mimir-overrides"  # Your actual ConfigMap name
```

### Issue 4: Unknown Limit Fields

**Symptoms:**
- Logs show: `unknown limit type - skipping` for valid Mimir fields

**Solution:** Check supported field names in logs. The parser supports:

**Samples per second:**
- `samples_per_second`, `ingestion_rate`, `samples_per_sec`, `sps`

**Burst percentage:**
- `burst_percent`, `burst_pct`, `burst_percentage`, `ingestion_burst_size`

**Body size limits:**
- `max_body_bytes`, `max_request_size`, `request_rate_limit`, `max_request_body_size`

**Series limits:**
- `max_series_per_request`, `max_series_per_metric`, `max_series_per_query`, `series_limit`

**Label limits:**
- `max_labels_per_series`, `max_labels_per_metric`, `labels_limit`
- `max_label_value_length`, `max_label_name_length`, `label_length_limit`

## 🔧 Configuration Examples

### Example 1: Basic Tenant Overrides
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mimir-overrides
  namespace: mimir
data:
  "team-a:ingestion_rate": "10000"
  "team-a:burst_percent": "0.2"
  "team-b:ingestion_rate": "5000"
  "team-b:burst_percent": "0.1"
```

### Example 2: Comprehensive Limits
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mimir-overrides
  namespace: mimir
data:
  "production:samples_per_second": "50000"
  "production:burst_percent": "0.3"
  "production:max_body_bytes": "4194304"
  "production:max_labels_per_series": "100"
  "production:max_series_per_request": "100000"
  
  "staging:samples_per_second": "10000"
  "staging:burst_percent": "0.2"
  "staging:max_body_bytes": "1048576"
```

## 📊 Expected Log Output

**For Real Mimir Format (overrides.yaml):**
```
{"level":"info","time":"...","message":"parsing ConfigMap data","configmap_keys":2}
{"level":"debug","time":"...","message":"found ConfigMap entry","key":"mimir.yaml","value_length":45}
{"level":"debug","time":"...","message":"found ConfigMap entry","key":"overrides.yaml","value_length":1234}
{"level":"info","time":"...","message":"found overrides.yaml - parsing Mimir YAML format"}
{"level":"info","time":"...","message":"found tenants in overrides YAML","tenants_in_yaml":3}
{"level":"debug","time":"...","message":"processing tenant overrides","tenant":"benefit","config_fields":8}
{"level":"debug","time":"...","message":"parsing tenant field","tenant":"benefit","field":"ingestion_rate","value":"350000"}
{"level":"debug","time":"...","message":"set samples_per_second","parsed_value":350000}
{"level":"debug","time":"...","message":"parsing tenant field","tenant":"benefit","field":"ingestion_burst_size","value":"3.5e+06"}
{"level":"debug","time":"...","message":"converted ingestion_burst_size to burst_percent","burst_size":3500000,"ingestion_rate":350000,"calculated_burst_percent":10}
{"level":"info","time":"...","message":"processed tenant overrides","tenant":"benefit"}
{"level":"info","time":"...","message":"completed parsing Mimir YAML overrides","total_tenants":3}
{"level":"info","time":"...","message":"syncing overrides to RLS","tenant_count":3}
```

**For Legacy Flat Format:**
```
{"level":"info","time":"...","message":"parsing ConfigMap data","configmap_keys":6}
{"level":"info","time":"...","message":"no overrides.yaml found - trying legacy flat format"}
{"level":"info","time":"...","message":"parsing tenant limit","tenant":"tenant-1","limit":"samples_per_second","value":"5000"}
{"level":"debug","time":"...","message":"set samples_per_second","parsed_value":5000}
{"level":"info","time":"...","message":"completed parsing flat overrides","total_tenants":3}
{"level":"info","time":"...","message":"syncing overrides to RLS","tenant_count":3}
```

## 🆘 Still Having Issues?

1. **Enable debug logging:**
   ```bash
   kubectl set env deployment/overrides-sync LOG_LEVEL=debug -n mimir-edge-enforcement
   ```

2. **Check all logs:**
   ```bash
   kubectl logs -f deployment/overrides-sync -n mimir-edge-enforcement
   ```

3. **Verify ConfigMap manually:**
   ```bash
   kubectl get configmap mimir-overrides -n mimir -o json | jq '.data'
   ```

4. **Test with our mock ConfigMap:**
   ```bash
   kubectl apply -f examples/mock-mimir.yaml
   ```

The enhanced parsing should now handle most common Mimir ConfigMap formats and provide detailed debug information to help identify any remaining issues.
