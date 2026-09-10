# Release Artifact

release_id: `prod-candidate-2026-08-31-local-rc25`
scope: `B1-approved rubric baseline, same-day no-credit requalification hardening, and RC25 source-bound local qualification`
environment: `production-candidate`
source_branch: `codex/organism-visual-v2`
source_commit_sha: `4947ad03cb5ff197fd536c521051631a10261497`
source_commit_semantics: `frozen post-B1 source with same-day requalification, clean-source CI prequalification, and approved-rubric verifier binding`
immutable_image_commit_sha: `4947ad03cb5ff197fd536c521051631a10261497`
source_attestation_control_sha: `9f80698f94905c53566fb35a3e4bbe2d70c8a415`
workflow_run_url: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/33405335413`
pipeline_status: `success; exact source checkout attested; 30/30 observed steps green; skipped=0; no release or production claim`
smoke_result: `five independent local source-bound chains passed; 10/10 runtime services healthy; DEV-ONLY; hosted proof still blocked`
observability_check: `candidate-bound local health, metrics, audit, trace, and O4 fail-closed paths; production observability is not claimed`
rollback_note: `local rollback target is RC24 source 1cb03979740859f0350cf18f6f08ef06c3d72b72; no hosted rollback is authorized or executed`
rollback_target_commit_sha: `1cb03979740859f0350cf18f6f08ef06c3d72b72`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:4947ad03cb5ff197fd536c521051631a10261497`
immutable_tag_publish_status: `unpublished`
rollback_drill_proof: `docs/runbooks/rollback-deploy.md`
executed_rollback_rerun_proof: `docs/release-artifacts/prod-candidate-2026-08-31-local-rc25-readiness.json`
owner_decision_proof: `e87c28a7c6cf32982caa849794042daa53ef022a`
budget_review_proof: `docs/release-artifacts/prod-candidate-2026-08-31-local-rc25-readiness.json`
open_questions_acceptance_proof: `docs/release-artifacts/prod-candidate-2026-08-31-local-rc25-readiness.json`
risk_review_recheck_proof: `docs/release-artifacts/prod-candidate-2026-08-31-local-rc25-readiness.json`
provenance_review_proof: `docs/release-artifacts/prod-candidate-2026-08-31-local-rc25-readiness.json`
smoke_recheck_proof: `docs/release-artifacts/prod-candidate-2026-08-31-local-rc25-readiness.json`
observability_recheck_proof: `docs/release-artifacts/prod-candidate-2026-08-31-local-rc25-readiness.json`
browser_evidence_reactivation_proof: `docs/release-artifacts/prod-candidate-2026-08-31-local-rc25-readiness.json`
browser_proof: `docs/release-artifacts/prod-candidate-2026-08-31-local-rc25-readiness.json`
post_rollback_browser_revalidation_proof: `not-applicable-retired-rc1-boundary`
final_browser_e2e_recheck_proof: `docs/release-artifacts/prod-candidate-2026-08-31-local-rc25-readiness.json`
full_verifier_sweep_proof: `docs/release-artifacts/prod-candidate-2026-08-31-local-rc25-readiness.json`
full_verifier_sweep_status: `all local sections passed; exact no-credit candidate-runtime parity and real selection/click verified; hosted I1 and production-auth I5 remain blocked`
truth_mirror_rebaseline_proof: `docs/runtime-state/phase5-credit-itemization.json`
release_readiness_rerun_proof: `docs/release-artifacts/prod-candidate-2026-08-31-local-rc25-readiness.json`
browser_rerun_status: `complete real-Chromium pass verified 22/22 routes, 29/29 families, and 161/161 action members`
review_gate: `pending`
owner_decision: `no-release`
hosted_staging_parity: `false`
production_rollout_claimed: `false`
checklist_verified_count: `17`
checklist_blocked_count: `2`
phase5_computed_percent: `89`

## Phase-5 Readiness Checklist

RC25 supersedes RC24 after the same five independent local qualification chains and
the exact source-attested CI run passed. The B1 rubric approval commit is an ancestor of the
frozen source. No percentage credit changes: I1 `hosted_candidate_parity` and I5
`production_auth_identity` remain zero-credit blocks.

| ID | JA/NEIN | Beleg |
| --- | --- | --- |
| C1 | JA | Exact candidate-source CI attestation is mandatory for RC25. |
| C2 | JA | Runtime, browser, security, candidate-image, and candidate-runtime chains are required and hash-bound. |
| C3 | JA | Candidate, readiness, and Phase-5 truth select the frozen RC25 source. |
| C4 | JA | Runtime-source and no-credit requalification parity remain fail-closed, including same-day selection. |
| C5 | JA | Candidate archive npm audit and canonical gitleaks scan are required. |
| I1 | NEIN | No non-local HTTPS hosted stack is bound exactly to RC25. |
| I2 | JA | Six clean-archive images are locally content-addressed; GHCR remains Post-Market. |
| I3 | JA | RC24 source is the immutable local rollback anchor. |
| I4 | JA | No new provider, paid tier, card requirement, or recurring amount is introduced. |
| I5 | NEIN | Production auth remains closed without hosted evidence. |
| V1 | JA | Health, metrics, and audit paths remain candidate-bound. |
| V2 | JA | Error, rate, session, request, and trace contracts remain candidate-bound. |
| V3 | JA | CI, verifier, browser, image, rollback, and readiness artifacts are required. |
| V4 | JA | Incident escalation and stop gates remain bound. |
| O1 | JA | The immutable rollback runbook applies to RC24 as target. |
| O2 | JA | Incident-response and secret-rotation runbooks are present. |
| O3 | JA | Review remains pending and no-release stays explicit. |
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

1. I1 stays `NEIN` until a non-local HTTPS surface is source-bound to RC25.
2. I5 stays `NEIN` until production OAuth and the hosted fail-closed evidence verifier pass.

## What This Candidate Changes Against RC24

RC25 contains the approved P3/P6/L4/L5 rubrics as immutable ancestors and hardens the
candidate machinery for a same-day, no-credit release selection and for source
prequalification when the checked-out source truth is already internally consistent.
These changes do not add percentage credit and do not open registry, promotion, or
production gates.

## Guardrails / Non-Claims

- DEV-ONLY; hosted proof still blocked.
- Local Docker image IDs are not registry digests.
- GHCR publication is Post-Market and remains unexecuted.
- `docker_registry_publish` remains owner-granted false and live-verified false.
- This artifact does not claim a production rollout.
- Production deployment still requires the release-candidate gate bundle and a separate rollout proof.
- No default-branch write, registry push, production deploy, release promotion, payment,
  secret output, or production-auth promotion is performed.
