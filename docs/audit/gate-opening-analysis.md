# Gate-Opening Analysis

Updated: 2026-07-26

## Current result

- Overall: `86%`.
- Canonical external audit: `docs/runtime-state/external-gate-audit-v2.json`.
- Audit status: `blocked`.
- Sole active external failure:
  `cloudflare_native_zero_card_hosted_runtime`.
- `production_deploy_claim_allowed=false`.
- Fly.io evidence is `historical_only` and cannot close an active gate.

## Read-only Cloudflare evidence

The sanitized O2' scope report is
`.codex/runs/CURRENT/p5/cloudflare-scope-readiness/report.json`.

- Method set: GET only.
- Cloud mutation: false.
- Secret output: false.
- Resource families inventoryable: `0/6`.
- Result: current token-management scopes are insufficient.
- Non-claim: HTTP 401/403 does not prove that resources are absent.

## Owner boundary

Open Owner actions are O1 through O5. O6 is `resolved_verified` with zero
percentage credit. Exact actions, scopes, and post-action verifiers are in
`docs/runtime-state/owner-input-manifest.json`.

No production deploy, registry push, main write, hosted write, live MCP write,
scope expansion, payment, or secret output is authorized by this analysis.

## Next proof

After O2' is explicitly approved and completed in the Owner environment:

1. Prove Cloudflare hosted source parity and stateful roundtrip.
2. Regenerate the sanitized scope report.
3. Run `scripts/verify-external-gates.ps1`.
4. Run the hosted browser contract against `STAGING_BASE_URL`.
5. Re-run `scripts/verify-market-ready.ps1`.

Until then: `DEV-ONLY; hosted proof still blocked`.
