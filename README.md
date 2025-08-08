# Mimir Edge Enforcement

A production-ready, cloud-agnostic Kubernetes solution that enforces Mimir tenant ingestion limits at the edge using Envoy, Rate/Authorization Service (RLS), overrides-sync controller, and React Admin UI.

## Architecture

```
Alloy → NGINX → Envoy → Mimir Distributor
              ↓
           RLS (ext_authz + ratelimit)
              ↓
        overrides-sync (watches ConfigMap)
              ↓
         Admin UI (monitoring & controls)
```

## Features

- **Zero client changes**: Bump-in-the-wire enforcement behind NGINX
- **Accurate enforcement**: Parses remote_write protobuf to count samples per request
- **Observability-first**: Prometheus metrics, dashboards, structured logs
- **Security & production-ready**: Minimal RBAC, resource limits, HPA, PDB
- **Portable Helm charts**: Works on any Kubernetes cluster
- **Admin UI**: Monitor allows/denies, drill down by tenant, emergency overrides

## Quick Start

```bash
# Clone and setup
git clone <repo>
cd mimir-edge-enforcement

# Build all components
make all

# Deploy to kind cluster
scripts/kind-up.sh

# Access Admin UI
kubectl port-forward svc/mimir-rls 8080:8080
open http://localhost:8080
```

## Components

- **Envoy**: HTTP proxy with ext_authz and ratelimit filters
- **RLS**: Go service providing authorization and rate limiting
- **overrides-sync**: Controller watching Mimir overrides ConfigMap
- **Admin UI**: React dashboard for monitoring and controls

## Documentation

- [Architecture](docs/architecture.md)
- [Rollout Guide](docs/rollout.md)
- [Tuning Guide](docs/tuning.md)
- [Alerts](docs/alerts.md)

## License

Apache-2.0