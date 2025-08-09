# 🎯 NGINX 10% Canary Configuration Explanation

## 📊 **Traffic Distribution**

**10% → Edge Enforcement** (with rate limiting)  
**90% → Direct to Mimir** (original behavior)

## 🔧 **Key Changes Made**

### **1. Added Canary Routing Logic**
```nginx
# Hash-based routing for consistent distribution
map $request_id $canary_hash {
    default 0;
    ~.*0$ 1;   # 10% of requests (last digit is 0)
}

# Routing decision
map $canary_hash $route_decision {
    0 "direct";
    1 "edge";
    default "direct";
}
```

**How it works:**
- Uses `$request_id` for consistent hash-based routing
- Requests ending in '0' (10%) → Edge Enforcement
- All other requests (90%) → Direct to Mimir
- Same request always takes the same path

### **2. Defined Upstream Services**
```nginx
upstream mimir_direct {
    # Original path - 90% of traffic
    server distributor.mimir.svc.cluster.local:8080;
    keepalive 16;
}

upstream mimir_via_edge_enforcement {
    # Through edge enforcement - 10% of traffic
    server mimir-envoy.mimir-edge-enforcement.svc.cluster.local:8080;
    keepalive 16;
}
```

### **3. Updated Critical Endpoints**

#### **Main Ingestion Endpoint: `/api/v1/push`**
```nginx
location = /api/v1/push {
    # Route based on canary decision  
    set $target_upstream "";
    if ($route_decision = "edge") {
        set $target_upstream "mimir_via_edge_enforcement";
    }
    if ($route_decision = "direct") {
        set $target_upstream "mimir_direct";
    }
    
    proxy_pass http://$target_upstream$request_uri;
}
```

#### **Distributor Endpoints: `/distributor`**
```nginx
location /distributor {
    # Same canary logic applied
    set $target_upstream "";
    if ($route_decision = "edge") {
        set $target_upstream "mimir_via_edge_enforcement";
    }
    if ($route_decision = "direct") {
        set $target_upstream "mimir_direct";
    }
    
    proxy_pass http://$target_upstream$request_uri;
}
```

### **4. Added Emergency Controls**

#### **Emergency Bypass: `/api/v1/push/direct`**
```nginx
location = /api/v1/push/direct {
    # Force direct routing (bypass edge enforcement)
    rewrite ^/api/v1/push/direct$ /api/v1/push break;
    proxy_pass http://mimir_direct;
}
```

#### **Force Edge Testing: `/api/v1/push/edge`**
```nginx
location = /api/v1/push/edge {
    # Force edge enforcement routing
    rewrite ^/api/v1/push/edge$ /api/v1/push break;
    proxy_pass http://mimir_via_edge_enforcement;
}
```

### **5. Enhanced Observability**
```nginx
# Add routing headers
add_header X-Canary-Route $route_decision always;
proxy_set_header X-Route-Decision $route_decision;

# Enhanced access logs
log_format main '$remote_addr - $remote_user [$time_local]  $status '
                '"$request" $body_bytes_sent "$http_referer" '
                '"$http_user_agent" "$http_x_forwarded_for" [$http_x_boltx_cluster] '
                'route=$route_decision';
```

## 🎛️ **What Stays the Same**

All other endpoints remain **unchanged** and route directly to Mimir:
- ✅ **Query endpoints** (`/prometheus`) → query-frontend
- ✅ **Alertmanager** (`/alertmanager`, `/api/v1/alerts`) → alertmanager  
- ✅ **Ruler** (`/api/v1/rules`, `/prometheus/rules`) → ruler
- ✅ **Runtime config** (`/runtime_config`) → distributor
- ✅ **Status endpoints** (`/status/ingester-zone-*`) → respective services

**Why:** These endpoints don't need rate limiting - only ingestion endpoints benefit from edge enforcement.

## 📊 **Expected Behavior**

### **Normal Operations**
- **90% of metrics ingestion** goes directly to Mimir (existing behavior)
- **10% of metrics ingestion** goes through edge enforcement (new protection)
- Queries, alerts, and configuration remain unaffected

### **Edge Enforcement Protection**
- **10% of traffic** gets rate limiting based on tenant limits
- **Overloaded tenants** get denied at the edge (protect Mimir)
- **Well-behaved tenants** pass through normally
- **Mimir sees reduced load** from the 10% that's processed by edge enforcement

### **Monitoring**
- **Access logs** show `route=edge` or `route=direct`
- **Response headers** include `X-Canary-Route: edge|direct`
- **Admin UI** shows metrics from the 10% of traffic being processed
- **Edge enforcement metrics** show protection effectiveness

## 🚀 **Deployment**

### **1. Deploy the Configuration**
```bash
# Automated deployment
./scripts/deploy-10-percent-canary.sh

# Or manual deployment
kubectl apply -f examples/nginx-10-percent-canary.yaml
kubectl rollout restart deployment/nginx -n mimir
```

### **2. Verify Traffic Distribution**
```bash
# Check routing headers
curl -H "X-Scope-OrgID: test-tenant" \
     -X POST http://your-nginx/api/v1/push \
     -v 2>&1 | grep X-Canary-Route

# Monitor access logs
kubectl logs -f deployment/nginx -n mimir | grep route=
```

### **3. Monitor Edge Enforcement**
```bash
# Check if 10% of traffic is being processed
./scripts/production-health-check.sh

# Verify protection is working
./scripts/validate-effectiveness.sh
```

## 🎯 **Success Criteria**

After deployment, you should see:

1. **✅ Traffic Split**: ~10% showing `route=edge`, ~90% showing `route=direct`
2. **✅ Edge Processing**: RLS metrics showing incoming requests
3. **✅ Protection Active**: Some denials for violating tenants
4. **✅ Mimir Stable**: No increase in errors from the 90% direct traffic
5. **✅ Performance**: No significant latency impact

## 📈 **Next Steps**

If 10% canary is successful:

1. **Monitor for 24-48 hours** to ensure stability
2. **Increase gradually**: 25% → 50% → 75% → 100%
3. **Use management script**: `./scripts/manage-nginx-canary.sh set-weight 25`
4. **Monitor effectiveness** at each stage
5. **Emergency rollback** if issues: `./scripts/manage-nginx-canary.sh disable`

## 🚨 **Emergency Procedures**

### **Instant Bypass (0% canary)**
```bash
# Disable all edge enforcement
./scripts/manage-nginx-canary.sh disable

# Or use direct URLs for critical clients
curl -X POST http://your-nginx/api/v1/push/direct
```

### **Rollback to Previous Config**
```bash
# Automatic rollback
./scripts/manage-nginx-canary.sh rollback

# Or manual rollback using backup
kubectl apply -f nginx-backups/nginx-backup-TIMESTAMP.yaml
```

Perfect for safe, controlled rollout of edge enforcement! 🛡️🎯
