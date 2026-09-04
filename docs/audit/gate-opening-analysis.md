# Gate-Opening Analysis

Updated: 2026-07-30

## Current result

- Overall: `86%`.
- Canonical external audit: `docs/runtime-state/external-gate-audit-v2.json`.
- Audit status: `blocked`.
- Active gate `cloudflare_native_zero_card_hosted_runtime`: `verified`.
- Remaining external failure: `ghcr_image_digest_verify`.
- Resolved 2026-07-31: `github_branch_protection_current_verify` is no longer a
  failure. The protection was always present; the probe defaulted its branch name
  to an empty string, and this repository has no `main` at all, so it reported a
  branch it never queried. With the real default branch `chore/repo-bootstrap`
  resolved, verification returns `status: verified` with zero mismatches. No
  GitHub write was performed.
- `production_deploy_claim_allowed=false`.
- Fly.io and R2 evidence are `historical_only` and cannot close an active gate.

## Cloudflare scope evidence

The historical sanitized O2' scope report is
`.codex/runs/CURRENT/p5/cloudflare-scope-readiness/report.json`.

- Method set: GET only.
- Cloud mutation: false.
- Secret output: false.
- Historical resource families inventoryable: `0/6`.
- Qualified active token: `O2Core 4/4` and `O5 1/1`.
- R2 is disabled, unbound and `historical_only`; `6/6` is not a target.
- Hosted write/read/delete succeeded; fail-closed promotion atomically replaced
  only the active management token and preserved a private rollback.
- Non-claim: HTTP 401/403 does not prove that resources are absent.

## Hosted O2Core evidence

- Worker:
  `https://cloud-superbrain-stateful-runtime.strazzusochr.workers.dev`.
- Source commit:
  `826a78b29a4dbf82a7115ecdd5562b238ade3594`.
- Source archive SHA-256:
  `f3d86b36883d743713c1c7e86477776dc575b87b9e941af849dfd2c4f94e325b`.
- Evidence:
  `.codex/runs/CURRENT/master-goal/t3/cloudflare-d1-hosted-v2/report.json`.
- Evidence SHA-256:
  `FEEE5D40E14E547C9B8EB5903B993E61BC324E2C2CAD64ECF8C7DF3BA9049D0B`.
- D1 W/R/D, Queue, SQLite Durable Object, source parity and zero-card execution:
  verified.
- Current tracked state:
  `docs/runtime-state/cloudflare-native-hosted-current.json`.

## Owner boundary

O2Core scopes and the bounded hosted proof are Owner-approved and the O2Core
runtime gate is verifier-open. The separate Phase-6 scale gate remains closed.
O4's bounded scope decision is recorded; O5 scope is present. O3 stays
release-gated. O6 is `resolved_verified` with zero percentage credit. Exact
actions, scopes, and post-action verifiers are in
`docs/runtime-state/owner-input-manifest.json`.

No production promotion, registry push, main write, unbounded hosted write,
live MCP write, scope expansion, payment, or secret output is authorized by
this analysis.

## Next proof

1. Commit and push the O2Core evidence-bound truth slice.
2. Wait for the new Vercel preview with the Preview-only runtime bindings.
3. Run hosted product acceptance and require `hosted_proof:true`.
4. Run the hosted 22-page action matrix with zero dead actions.
5. Prove O5 Vectorize semantic search, then re-run market readiness.

Until then: hosted O2Core is verified; hosted product proof and release remain
blocked.
