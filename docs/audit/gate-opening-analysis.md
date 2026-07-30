# Gate-Opening Analysis

Updated: 2026-07-30

## Current result

- Overall: `86%`.
- Canonical external audit: `docs/runtime-state/external-gate-audit-v2.json`.
- Audit status: `blocked`.
- Sole active external failure:
  `cloudflare_native_zero_card_hosted_runtime`.
- `production_deploy_claim_allowed=false`.
- Fly.io evidence is `historical_only` and cannot close an active gate.

## Cloudflare scope evidence

The historical sanitized O2' scope report is
`.codex/runs/CURRENT/p5/cloudflare-scope-readiness/report.json`.

- Method set: GET only.
- Cloud mutation: false.
- Secret output: false.
- Historical resource families inventoryable: `0/6`.
- Current candidate: `O2Core 4/4` and `O5 1/1`.
- R2 is disabled, unbound and `historical_only`; `6/6` is not a target.
- The weaker active token remains unchanged until hosted write/read/delete succeeds.
- Non-claim: HTTP 401/403 does not prove that resources are absent.

## Owner boundary

O2Core scopes and the bounded hosted proof are Owner-approved; O4's bounded
scope decision is recorded; O5 scope is present. Their runtime gates remain
closed until the exact live verifiers pass. O3 stays release-gated. O6 is
`resolved_verified` with zero percentage credit. Exact actions, scopes, and
post-action verifiers are in `docs/runtime-state/owner-input-manifest.json`.

No production promotion, registry push, main write, unbounded hosted write,
live MCP write, scope expansion, payment, or secret output is authorized by
this analysis.

## Next proof

Using the approved O2Core candidate:

1. Prove Cloudflare hosted source parity and stateful roundtrip.
2. Qualify and activate the candidate only after successful write/read/delete.
3. Run `scripts/verify-external-gates.ps1`.
4. Run the hosted browser contract against `STAGING_BASE_URL`.
5. Re-run `scripts/verify-market-ready.ps1`.

Until then: `DEV-ONLY; hosted proof still blocked`.
