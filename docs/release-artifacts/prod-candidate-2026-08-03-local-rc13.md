# Release Artifact

release_id: `prod-candidate-2026-08-03-local-rc13`
scope: `Organism visual-v2 slice: seven completed telemetry effects, race-safe paused-clock camera proof, OAuth verifier lint cleanup, and measured L4/L5 substance gaps`
environment: `production-candidate`
source_branch: `codex/organism-visual-v2`
source_commit_sha: `db631ab3ffe2254309ae80aadc691b0bba6c372d`
source_commit_semantics: `frozen organism-visual-v2 source with the completed seven-effect organism presentation, paused-clock camera-test repair, OAuth verifier lint cleanup, and canonical five-axis substance measurement`
immutable_image_commit_sha: `db631ab3ffe2254309ae80aadc691b0bba6c372d`
workflow_run_url: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/30815984573`
pipeline_status: `GitHub Actions pr-check run 30815984573 passed with binding_mode source_checkout_attestation_v1; checked_out_sha equals the candidate and the control delta is a single allowed path`
smoke_result: `passed DEV-ONLY; six-service candidate images and candidate runtime verified, full runtime chain green, full browser chain green with real Cloudflare Workers AI generation, 22 routes, 161 page-local actions, and O4 write proof; hosted proof still blocked`
observability_check: `present`
rollback_note: `local rollback target is RC12 source 6261f9f89d803c36b449ba87a4d93e14411b31d0; no hosted rollback is authorized or executed`
rollback_target_commit_sha: `6261f9f89d803c36b449ba87a4d93e14411b31d0`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:db631ab3ffe2254309ae80aadc691b0bba6c372d`
immutable_tag_publish_status: `unpublished`
rollback_drill_proof: `docs/runbooks/rollback-deploy.md`
executed_rollback_rerun_proof: `docs/release-artifacts/prod-candidate-2026-08-03-local-rc13-readiness.json`
owner_decision_proof: `docs/runtime-state/owner-input-manifest.json`
budget_review_proof: `docs/release-artifacts/prod-candidate-2026-08-03-local-rc13-readiness.json`
open_questions_acceptance_proof: `docs/release-artifacts/prod-candidate-2026-08-03-local-rc13-readiness.json`
risk_review_recheck_proof: `docs/release-artifacts/prod-candidate-2026-08-03-local-rc13-readiness.json`
provenance_review_proof: `docs/release-artifacts/prod-candidate-2026-08-03-local-rc13-readiness.json`
smoke_recheck_proof: `docs/release-artifacts/prod-candidate-2026-08-03-local-rc13-readiness.json`
observability_recheck_proof: `docs/release-artifacts/prod-candidate-2026-08-03-local-rc13-readiness.json`
browser_evidence_reactivation_proof: `docs/release-artifacts/prod-candidate-2026-08-03-local-rc13-readiness.json`
browser_proof: `docs/release-artifacts/prod-candidate-2026-08-03-local-rc13-readiness.json`
post_rollback_browser_revalidation_proof: `not-applicable-retired-rc1-boundary`
final_browser_e2e_recheck_proof: `docs/release-artifacts/prod-candidate-2026-08-03-local-rc13-readiness.json`
full_verifier_sweep_proof: `docs/release-artifacts/prod-candidate-2026-08-03-local-rc13-readiness.json`
truth_mirror_rebaseline_proof: `docs/runtime-state/phase5-credit-itemization.json`
release_readiness_rerun_proof: `docs/release-artifacts/prod-candidate-2026-08-03-local-rc13-readiness.json`
browser_rerun_status: `passed DEV-ONLY on 2026-08-03; browser contract, product acceptance with a real Cloudflare Workers AI generation, 22-page actions, and the O4 write proof are green against this exact source`
review_gate: `pending`
owner_decision: `no-release`
hosted_staging_parity: `false`
production_rollout_claimed: `false`
checklist_verified_count: `17`
checklist_blocked_count: `2`
phase5_computed_percent: `89`

## Phase-5 Readiness Checklist

| ID | JA/NEIN | Beleg |
| --- | --- | --- |
| C1 | JA | Source-bound GitHub Actions run 30815984573 is recorded in the readiness evidence through the source-checkout attestation. |
| C2 | JA | Runtime, browser, security, candidate-image, and candidate-runtime chains are bound as hashed evidence. |
| C3 | JA | Manifest, state, handoff, register, and release documents remain synchronized. |
| C4 | JA | Runtime-source parity is fail-closed against the frozen candidate source. |
| C5 | JA | npm audit and the canonical secret scan are candidate-bound gates. |
| I1 | NEIN | No non-local HTTPS hosted stack is bound exactly to RC13. |
| I2 | JA | Six clean-archive images are locally content-addressed; GHCR remains Post-Market. |
| I3 | JA | RC12 source is named as the immutable local rollback anchor. |
| I4 | JA | No new provider, paid tier, card requirement, or recurring amount is introduced. |
| I5 | NEIN | `production_auth_identity` remains closed without Owner OAuth consent. |
| V1 | JA | Health, metrics, and audit paths are named below. |
| V2 | JA | Error, rate, session, request, and trace contracts remain bound. |
| V3 | JA | CI, verifier, browser, image, and truth artifacts are linked. |
| V4 | JA | Incident escalation and stop gates remain bound. |
| O1 | JA | The immutable rollback runbook applies to RC12 as the target. |
| O2 | JA | Incident-response and secret-rotation runbooks are present. |
| O3 | JA | Review remains pending and no-release stays explicit and fail-closed. |
| O4 | JA | The two Phase-5 owner-blocked questions remain explicitly accepted under no-release. |
| O5 | JA | Production, promotion, registry publication, and rollout remain false. |

## Candidate-Bound Observability

- Health: `/api/v1/health`, `/mcp/api/v1/health`, `/llm/api/v1/health`.
- Metrics: `/api/v1/metrics`.
- Audit: `/api/v1/audit/recent`, `/api/v1/audit/mcp`.
- Contracts: `/api/v1/errors/contract`, `/api/v1/rate-limit/contract`,
  `/api/v1/sessions/history/contract`, `/api/v1/request/contract`,
  `/api/v1/trace/contract`.
- Escalation: `docs/runbooks/incident-response.md`.

## Budget Review

- New recurring infrastructure: none.
- Paid provider/tier: none.
- Card/payment action: none.
- Existing ceiling: maximum 20 EUR/month; unchanged.
- GHCR publication: Post-Market Owner action, not executed and not credited.

## Open Questions Accepted Under No-Release

1. I1 stays `NEIN` until a non-local HTTPS surface is source-bound to RC13.
2. I5 stays `NEIN` until the Owner completes production OAuth and the hosted
   fail-closed verifier passes.

There is no unknown autonomous Phase-5 checklist work. Both known gaps remain
zero credit and block a `100%` Phase-5 claim.

## What This Candidate Changes Against RC12

RC13 freezes the completed organism visual-v2 presentation: Edges,
MeshTransmissionMaterial, Bloom, Scanline, Fibonacci-dot globe, shards,
waveform, and matrix-rain treatment are present in the production source. The
camera proof no longer waits for `networkidle` while Playwright's clock is
paused. The slice also records the measured L4/L5 substance gap without
granting credit or changing either layer percentage.

## Guardrails / Non-Claims

- DEV-ONLY; hosted proof still blocked.
- Local Docker image IDs are not registry digests.
- GHCR publication is Post-Market under E3 and remains unexecuted.
- `docker_registry_publish` remains owner-granted false and live-verified false.
- This artifact does not claim a production rollout.
- Production deployment still requires the release-candidate gate bundle and a separate rollout proof.
- No registry push, provider write, production deploy, release promotion,
  Owner approval, payment, or secret output is performed.
