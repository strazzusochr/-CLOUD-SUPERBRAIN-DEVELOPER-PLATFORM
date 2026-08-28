# Release Artifact

release_id: `prod-candidate-2026-08-28-local-rc21`
scope: `five-axis substance audit wired into the static gate chain, PROJECT_STATE truth refreshed before the freeze, marketplace no longer paints a retired provider as verified`
environment: `production-candidate`
source_branch: `codex/organism-visual-v2`
source_commit_sha: `c1b022a884eb16939fe0542b2eb9056b60706b20`
source_commit_semantics: `frozen development source whose product-acceptance harness holds ArrowRight and KeyD across animation frames so requestAnimationFrame-polled controls produce measurable visible state changes`
immutable_image_commit_sha: `c1b022a884eb16939fe0542b2eb9056b60706b20`
workflow_run_url: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/33217980790`
pipeline_status: `GitHub Actions pr-check run 33217980790 passed with binding_mode source_checkout_attestation_v1; checked_out_sha equals the candidate and the control delta is the single allowed path`
smoke_result: `passed DEV-ONLY; six committed-archive service images, candidate runtime, full runtime, candidate-scoped security, real Cloudflare Workers AI generation with held-key interaction, 22 routes, 161 page-local actions, and O4 write proof are green; hosted proof still blocked`
observability_check: `present in candidate-bound DEV-ONLY runtime and browser evidence`
rollback_note: `local rollback target is RC20 source c29c738b82e4e35cc1288bc603319cba60d167d2; no hosted rollback is authorized or executed`
rollback_target_commit_sha: `c29c738b82e4e35cc1288bc603319cba60d167d2`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:c1b022a884eb16939fe0542b2eb9056b60706b20`
immutable_tag_publish_status: `unpublished`
rollback_drill_proof: `docs/runbooks/rollback-deploy.md`
executed_rollback_rerun_proof: `docs/release-artifacts/prod-candidate-2026-08-28-local-rc21-readiness.json`
owner_decision_proof: `docs/runtime-state/owner-input-manifest.json`
budget_review_proof: `docs/release-artifacts/prod-candidate-2026-08-28-local-rc21-readiness.json`
open_questions_acceptance_proof: `docs/release-artifacts/prod-candidate-2026-08-28-local-rc21-readiness.json`
risk_review_recheck_proof: `docs/release-artifacts/prod-candidate-2026-08-28-local-rc21-readiness.json`
provenance_review_proof: `docs/release-artifacts/prod-candidate-2026-08-28-local-rc21-readiness.json`
smoke_recheck_proof: `docs/release-artifacts/prod-candidate-2026-08-28-local-rc21-readiness.json`
observability_recheck_proof: `docs/release-artifacts/prod-candidate-2026-08-28-local-rc21-readiness.json`
browser_evidence_reactivation_proof: `docs/release-artifacts/prod-candidate-2026-08-28-local-rc21-readiness.json`
browser_proof: `docs/release-artifacts/prod-candidate-2026-08-28-local-rc21-readiness.json`
post_rollback_browser_revalidation_proof: `not-applicable-retired-rc1-boundary`
final_browser_e2e_recheck_proof: `docs/release-artifacts/prod-candidate-2026-08-28-local-rc21-readiness.json`
full_verifier_sweep_proof: `docs/release-artifacts/prod-candidate-2026-08-28-local-rc21-readiness.json`
truth_mirror_rebaseline_proof: `docs/runtime-state/phase5-credit-itemization.json`
release_readiness_rerun_proof: `docs/release-artifacts/prod-candidate-2026-08-28-local-rc21-readiness.json`
browser_rerun_status: `passed DEV-ONLY on 2026-08-28; browser contract, product acceptance with a real Cloudflare Workers AI generation and held-key input, 22-page actions, responsive 22-route proof, and O4 write proof are green against source c1b022a884eb16939fe0542b2eb9056b60706b20`
review_gate: `pending`
owner_decision: `no-release`
hosted_staging_parity: `false`
production_rollout_claimed: `false`
checklist_verified_count: `17`
checklist_blocked_count: `2`
phase5_computed_percent: `89`

## Phase-5 Readiness Checklist

The five local qualification chains and source-attested CI are green and
preserved as the immutable 27-file RC20 evidence set. The score stays 17/19
because I1 `hosted_candidate_parity` and I5 `production_auth_identity` remain
zero-credit Owner blocks.

| ID | JA/NEIN | Beleg |
| --- | --- | --- |
| C1 | JA | Source-bound GitHub Actions run 33217980790 is recorded through the source-checkout attestation. |
| C2 | JA | Runtime, browser, security, candidate-image, and candidate-runtime chains are bound as hashed evidence. |
| C3 | JA | Candidate, readiness, and Phase-5 itemization truth are synchronized. |
| C4 | JA | Candidate source parity, generated-document runnability, held-key interaction, and outward timeout budgets fail closed. |
| C5 | JA | Candidate-scoped npm audit and the canonical secret scan are green. |
| I1 | NEIN | No non-local HTTPS hosted stack is bound exactly to RC20. |
| I2 | JA | Six clean-archive images are locally content-addressed; GHCR remains Post-Market. |
| I3 | JA | RC19 source is named as the immutable local rollback anchor. |
| I4 | JA | No new provider, paid tier, card requirement, or recurring amount is introduced. |
| I5 | NEIN | `production_auth_identity` remains closed without Owner OAuth consent. |
| V1 | JA | Health, metrics, and audit paths remain candidate-bound. |
| V2 | JA | Error, rate, session, request, and trace contracts remain candidate-bound. |
| V3 | JA | CI, verifier, browser, image, rollback, and readiness artifacts are linked. |
| V4 | JA | Incident escalation and stop gates remain bound. |
| O1 | JA | The immutable rollback runbook applies to RC19 as the target. |
| O2 | JA | Incident-response and secret-rotation runbooks are present. |
| O3 | JA | Review remains pending and no-release stays explicit and fail-closed. |
| O4 | JA | The two remaining questions remain accepted under no-release. |
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

1. I1 stays `NEIN` until a non-local HTTPS surface is source-bound to RC20.
2. I5 stays `NEIN` until the Owner completes production OAuth and the hosted
   fail-closed verifier passes.

## What This Candidate Changes Against RC19

RC20 corrects the real-interaction acceptance harness for generated games that
poll held keys inside `requestAnimationFrame`. The proof now performs genuine
`keyboard.down` and `keyboard.up` input across animation frames and verifies the
resulting measurable visible state or pixel change. This removes the false
negative caused by a same-frame press/release while keeping the product
requirement strict.

The frozen source passed six clean-archive image builds, candidate runtime,
full runtime, candidate security, source-attested CI, a real Cloudflare Workers
AI product build, and the complete `22/22`, `29/29`, `161/161` browser action
matrix. RC19 remains the rollback anchor. No product visual implementation,
model permission, provider bypass, infrastructure target, or budget ceiling
changes.

## Guardrails / Non-Claims

- DEV-ONLY; hosted proof still blocked.
- Local Docker image IDs are not registry digests.
- GHCR publication is Post-Market and remains unexecuted.
- `docker_registry_publish` remains owner-granted false and live-verified false.
- This artifact does not claim a production rollout.
- Production deployment still requires the release-candidate gate bundle and a separate rollout proof.
- No default-branch write, registry push, production deploy, release promotion,
  authenticated Alibaba provider call, Owner approval, payment, secret output,
  or final visual approval is performed.
