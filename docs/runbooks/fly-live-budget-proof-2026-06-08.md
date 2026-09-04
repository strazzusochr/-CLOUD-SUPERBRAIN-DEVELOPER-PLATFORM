# Fly.io/Vercel/GHCR/Grafana Budget Proof - 2026-06-08

Status: `historical_only`; superseded by `cloudflare_native_zero_card_hosted_runtime`.
Current gate truth: `external-gate-audit-v2`.

Historical infrastructure baseline: Vercel/Fly.io/GHCR/Grafana Cloud.

Projected Fly.io monthly server cost: EUR 9.00

Budget guard:
- Warning threshold: EUR 16.00
- Hard limit: EUR 20.00
- Result: under warning threshold

Planned monthly items:
- fly-production-shared-cpu-1x: EUR 5.00
- fly-staging-shared-cpu-1x: EUR 4.00
- cloudflare-free-tier: EUR 0.00
- ghcr-free-tier: EUR 0.00
- grafana-cloud-free-first: EUR 0.00
- vercel-free-first: EUR 0.00

Live Fly.io token probe: external-gated

No token value is stored in this document. The token is not persisted. A live
Fly.io API proof can only close through `scripts/verify-external-gates.ps1`
with `FLY_API_TOKEN` provided in the process environment or external secret
store.

Non-claims:
- This file does not define the active infrastructure baseline or close an active gate.
- This file does not claim production deployment.
- This file does not claim live provider mutation.
- This file does not replace hosted staging proof.
