# Tuning Guide

## Request size limits
- Envoy ext_authz `with_request_body.max_request_bytes`: set to upper bound of expected remote_write body size. Start with 4 MiB.
- RLS `limits.maxBodyBytes`: set per-tenant if you want coarse bytes/s enforcement; 0 disables it.

## Parsing toggle
- `enforceBodyParsing`: true for accurate sample counting; false for minimal CPU cost.

## Token buckets
- Samples/s: size capacity equals rate to allow 1s of burst by default. Increase capacity for more burst tolerance.
- Bytes/s: similarly, capacity equals rate.

## Store backend
- memory: simplest; single-replica or stateless multi-replica with eventual consistency.
- redis: use for strict shared buckets; configure TLS.

## HPA
- Target CPU 70–80%. Ensure resources.requests are realistic so HPA can scale.

## Failure modes
- Envoy ext_authz `failure_mode_allow`: false for fail-closed; true for canary or mirror.
- Ratellimit failure mode deny: true to be conservative.

