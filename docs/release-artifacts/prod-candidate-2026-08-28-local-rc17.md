# Release Artifact

release_id: `prod-candidate-2026-08-28-local-rc17`
scope: `generated-document runnability enforcement and deterministic missing-three-core repair across frontend generation, Agent API persistence, and Cloudflare D1 persistence`
environment: `production-candidate`
source_branch: `codex/organism-visual-v2`
source_commit_sha: `bbc2ad481352e8d9ee1e8e9fc010a5d3407d7b85`
source_commit_semantics: `frozen development source with fail-closed rejection of dead script references and missing THREE dependencies at both persistence boundaries, plus deterministic pinned-core repair at the trusted generation boundary`
immutable_image_commit_sha: `bbc2ad481352e8d9ee1e8e9fc010a5d3407d7b85`
workflow_run_url: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/33171020720`
pipeline_status: `GitHub Actions pr-check run 33171020720 passed with binding_mode source_checkout_attestation_v1; checked_out_sha equals the candidate and the control delta is the single allowed path`
smoke_result: `passed DEV-ONLY; six committed-archive service images, candidate runtime, full runtime, full browser with real Cloudflare Workers AI generation, 22 routes, 161 page-local actions, O4 write proof, and candidate-scoped security checks are green; hosted proof still blocked`
observability_check: `present in candidate-bound DEV-ONLY runtime and browser evidence`
rollback_note: `local rollback target is RC16 source 0a706beae17e25525a312843c236720a1efdf99b; no hosted rollback is authorized or executed`
rollback_target_commit_sha: `0a706beae17e25525a312843c236720a1efdf99b`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:bbc2ad481352e8d9ee1e8e9fc010a5d3407d7b85`
immutable_tag_publish_status: `unpublished`
rollback_drill_proof: `docs/runbooks/rollback-deploy.md`
executed_rollback_rerun_proof: `docs/release-artifacts/prod-candidate-2026-08-28-local-rc17-readiness.json`
owner_decision_proof: `docs/runtime-state/owner-input-manifest.json`
budget_review_proof: `docs/release-artifacts/prod-candidate-2026-08-28-local-rc17-readiness.json`
open_questions_acceptance_proof: `docs/release-artifacts/prod-candidate-2026-08-28-local-rc17-readiness.json`
risk_review_recheck_proof: `docs/release-artifacts/prod-candidate-2026-08-28-local-rc17-readiness.json`
provenance_review_proof: `docs/release-artifacts/prod-candidate-2026-08-28-local-rc17-readiness.json`
smoke_recheck_proof: `docs/release-artifacts/prod-candidate-2026-08-28-local-rc17-readiness.json`
observability_recheck_proof: `docs/release-artifacts/prod-candidate-2026-08-28-local-rc17-readiness.json`
browser_evidence_reactivation_proof: `docs/release-artifacts/prod-candidate-2026-08-28-local-rc17-readiness.json`
browser_proof: `docs/release-artifacts/prod-candidate-2026-08-28-local-rc17-readiness.json`
post_rollback_browser_revalidation_proof: `not-applicable-retired-rc1-boundary`
final_browser_e2e_recheck_proof: `docs/release-artifacts/prod-candidate-2026-08-28-local-rc17-readiness.json`
full_verifier_sweep_proof: `docs/release-artifacts/prod-candidate-2026-08-28-local-rc17-readiness.json`
truth_mirror_rebaseline_proof: `docs/runtime-state/phase5-credit-itemization.json`
release_readiness_rerun_proof: `docs/release-artifacts/prod-candidate-2026-08-28-local-rc17-readiness.json`
browser_rerun_status: `passed DEV-ONLY on 2026-08-28; browser contract, product acceptance with a real Cloudflare Workers AI generation, 22-page actions, responsive 22-route proof, and O4 write proof are green against source bbc2ad481352e8d9ee1e8e9fc010a5d3407d7b85`
review_gate: `pending`
owner_decision: `no-release`
hosted_staging_parity: `false`
production_rollout_claimed: `false`
checklist_verified_count: `17`
checklist_blocked_count: `2`
phase5_computed_percent: `89`

## Phase-5 Readiness Checklist

The five local qualification chains and source-attested CI are green and
preserved as the immutable 27-file RC17 evidence set. The score stays 17/19
because I1 `hosted_candidate_parity` and I5 `production_auth_identity` remain
zero-credit Owner blocks.

| ID | JA/NEIN | Beleg |
| --- | --- | --- |
| C1 | JA | Source-bound GitHub Actions run 33171020720 is recorded through the source-checkout attestation. |
| C2 | JA | Runtime, browser, security, candidate-image, and candidate-runtime chains are bound as hashed evidence. |
| C3 | JA | Candidate, readiness, and Phase-5 itemization truth are synchronized. |
| C4 | JA | Candidate runtime and both generated-document persistence boundaries fail closed on unrunnable source. |
| C5 | JA | Candidate-scoped npm audit and the canonical secret scan are green. |
| I1 | NEIN | No non-local HTTPS hosted stack is bound exactly to RC17. |
| I2 | JA | Six clean-archive images are locally content-addressed; GHCR remains Post-Market. |
| I3 | JA | RC16 source is named as the immutable local rollback anchor. |
| I4 | JA | No new provider, paid tier, card requirement, or recurring amount is introduced. |
| I5 | NEIN | `production_auth_identity` remains closed without Owner OAuth consent. |
| V1 | JA | Health, metrics, and audit paths remain candidate-bound. |
| V2 | JA | Error, rate, session, request, and trace contracts remain candidate-bound. |
| V3 | JA | CI, verifier, browser, image, rollback, and readiness artifacts are linked. |
| V4 | JA | Incident escalation and stop gates remain bound. |
| O1 | JA | The immutable rollback runbook applies to RC16 as the target. |
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

1. I1 stays `NEIN` until a non-local HTTPS surface is source-bound to RC17.
2. I5 stays `NEIN` until the Owner completes production OAuth and the hosted
   fail-closed verifier passes.

## What This Candidate Changes Against RC16

RC17 makes generated HTML executable-by-contract before it can become a saved
build. Red-first tests define rejection of dead `examples/js` references,
unsupported classic `examples/jsm` references, and `THREE` use without a prior
core dependency. The trusted frontend generation boundary repairs only the
missing-core case by inserting the pinned
`https://unpkg.com/three@0.160.0/build/three.min.js` script before first use,
idempotently. Agent API and Cloudflare D1 persistence independently reject the
same unrunnable documents instead of trusting the frontend boundary.

The first full real-browser attempt caught `THREE is not defined` in a generated
3D build. That run is not credited. The repaired frozen source then passed the
frontend, Agent API, and Cloudflare red-first suites, source-attested CI, six
candidate images, candidate runtime, full runtime, candidate security, a real
Cloudflare Workers AI product build, and the complete `22/22`, `29/29`,
`161/161` browser action matrix without the page error. No model route,
provider permission, infrastructure target, or budget ceiling changes.

## Guardrails / Non-Claims

- DEV-ONLY; hosted proof still blocked.
- Local Docker image IDs are not registry digests.
- GHCR publication is Post-Market and remains unexecuted.
- `docker_registry_publish` remains owner-granted false and live-verified false.
- This artifact does not claim a production rollout.
- Production deployment still requires the release-candidate gate bundle and a separate rollout proof.
- No default-branch write, registry push, production deploy, release promotion,
  authenticated Alibaba provider call, Owner approval, payment, or secret output
  is performed.
