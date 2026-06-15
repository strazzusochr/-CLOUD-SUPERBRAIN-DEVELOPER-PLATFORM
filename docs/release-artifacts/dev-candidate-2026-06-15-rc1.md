# Release Artifact

release_id: `dev-candidate-2026-06-15-rc1`
scope: `DEV-ONLY runtime + browser proof; release-boundary parity refresh; autonomous prepush workflow wiring`
environment: `dev-only`
source_branch: `fly-cloud-redirect`
source_commit_sha: `7be0ac03de2a5f435d98629de3d310253c00e3f3`
source_commit_semantics: `Local build + runtime + browser contract verifiers for 22 pages and 7 layers; no hosted staging or production rollout proof`
owner_decision: `approved`
production_rollout_claimed: `false`

## Verification Evidence (DEV-ONLY)

- Frontend production build: `npm run build`
- Runtime verifier: `npm run verify:runtime`
- Browser contract (human-flow): `npm run verify:browser`
- Worktree boundary report: `scripts/verify-worktree-release-boundary.ps1 -JsonOnly -ReportOnly`

## Guardrails / Non-Claims

- DEV-ONLY; hosted proof still blocked.
- No hosted staging claim is made without a real HTTPS `STAGING_BASE_URL` and passing hosted verifiers.
- No production deployment, release promotion, registry push, live LLM provider call, or live MCP write is performed or claimed by this candidate.
