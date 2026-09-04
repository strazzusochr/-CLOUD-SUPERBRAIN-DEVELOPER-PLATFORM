# Release Artifact

release_id: `prod-candidate-2026-09-04-local-rc38`
scope: `RC38 dual-bound source prequalification and local no-credit requalification`
environment: `production-candidate`
source_branch: `codex/organism-visual-v2`
source_commit_sha: `5668e7cb89eac03a929853f004204b56bd171cb9`
source_commit_semantics: `frozen RC38 source with fail-closed exact-head CI dual binding; Q is a distinct direct child that carries only the source-qualification control`
immutable_image_commit_sha: `5668e7cb89eac03a929853f004204b56bd171cb9`
source_attestation_control_sha: `bbdf952eb369f2ae00310d797333e3e08960a668`
workflow_run_url: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/33817644414`
pipeline_status: `success; source checkout attested; 29/29 observed steps green; skipped=0; exact-head dual-binding evidence is retained; no release or production claim`
smoke_result: `RC38 local qualification evidence is prepared as DEV-ONLY; hosted proof remains blocked`
observability_check: `candidate-bound local health, metrics, audit, trace, O4 fail-closed, MCP health, browser readback, and sanitized gateway failure paths remain mandatory; production observability is not claimed`
rollback_note: `local rollback target is RC33 source a632372863a39faa0e53d780c1942938a2b3241c; no hosted rollback is authorized or executed`
rollback_target_commit_sha: `a632372863a39faa0e53d780c1942938a2b3241c`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:5668e7cb89eac03a929853f004204b56bd171cb9`
immutable_tag_publish_status: `unpublished`
rollback_drill_proof: `docs/runbooks/rollback-deploy.md`
executed_rollback_rerun_proof: `docs/release-artifacts/prod-candidate-2026-09-04-local-rc38-readiness.json`
owner_decision_proof: `e87c28a7c6cf32982caa849794042daa53ef022a`
budget_review_proof: `docs/release-artifacts/prod-candidate-2026-09-04-local-rc38-readiness.json`
open_questions_acceptance_proof: `docs/release-artifacts/prod-candidate-2026-09-04-local-rc38-readiness.json`
risk_review_recheck_proof: `docs/release-artifacts/prod-candidate-2026-09-04-local-rc38-readiness.json`
provenance_review_proof: `docs/release-artifacts/prod-candidate-2026-09-04-local-rc38-readiness.json`
smoke_recheck_proof: `docs/release-artifacts/prod-candidate-2026-09-04-local-rc38-readiness.json`
observability_recheck_proof: `docs/release-artifacts/prod-candidate-2026-09-04-local-rc38-readiness.json`
browser_evidence_reactivation_proof: `docs/release-artifacts/prod-candidate-2026-09-04-local-rc38-readiness.json`
browser_proof: `docs/release-artifacts/prod-candidate-2026-09-04-local-rc38-readiness.json`
post_rollback_browser_revalidation_proof: `not-applicable-retired-rc1-boundary`
final_browser_e2e_recheck_proof: `docs/release-artifacts/prod-candidate-2026-09-04-local-rc38-readiness.json`
full_verifier_sweep_proof: `docs/release-artifacts/prod-candidate-2026-09-04-local-rc38-readiness.json`
full_verifier_sweep_status: `RC38 remains source-bound, DEV-ONLY, and no-release; I1 and I5 remain blocked until immutable hosted evidence exists`
truth_mirror_rebaseline_proof: `docs/runtime-state/phase5-credit-itemization.json`
release_readiness_rerun_proof: `docs/release-artifacts/prod-candidate-2026-09-04-local-rc38-readiness.json`
browser_rerun_status: `RC38 browser evidence is independently hash-bound and passed DEV-ONLY: browser-contract, Product Acceptance, 22 routes/161 actions, and O4 live writes; it cannot satisfy hosted I1 or I5.`
review_gate: `pending`
owner_decision: `no-release`
hosted_staging_parity: `false`
production_rollout_claimed: `false`
checklist_verified_count: `17`
checklist_blocked_count: `2`
phase5_computed_percent: `89`

## Phase-5 Readiness Checklist

RC38 supersedes RC33 only when all five independent source-bound local qualification chains
are hash-bound in its release-scoped evidence directory. It does not award percentage credit.
I1 `hosted_candidate_parity` and I5 `production_auth_identity` remain zero-credit blocks.

| ID | JA/NEIN | Beleg |
| --- | --- | --- |
| C1 | JA | Exact candidate-source CI checkout and exact-head dual-binding attestations are bound to RC38. |
| C2 | JA | Runtime, browser, security, candidate-image, and candidate-runtime chains are recorded independently in RC38 evidence. |
| C3 | JA | Candidate, readiness, and Phase-5 truth select the frozen RC38 source. |
| C4 | JA | Runtime-source and no-credit requalification parity remain fail-closed. |
| C5 | JA | Candidate archive npm audit and canonical gitleaks scan are recorded in the security evidence chain. |
| I1 | NEIN | No non-local HTTPS six-service hosted stack is bound exactly to RC38. |
| I2 | JA | Six clean-archive images are locally content-addressed; GHCR remains unpublished. |
| I3 | JA | RC33 source is the immutable local rollback anchor. |
| I4 | JA | No new provider, paid tier, card requirement, or recurring amount is introduced. |
| I5 | NEIN | Production auth remains closed without hosted evidence. |
| V1 | JA | Health, metrics, and audit paths remain candidate-bound. |
| V2 | JA | Error, rate, session, request, trace, and gateway fail-closed contracts remain candidate-bound. |
| V3 | JA | CI, verifier, browser, image, rollback, and readiness artifacts are source-bound. |
| V4 | JA | Incident escalation and stop gates remain bound. |
| O1 | JA | The immutable rollback runbook applies to RC33 as target. |
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
- GHCR publication remains a separately gated Owner action and is not executed or credited.

## Open Questions Accepted Under No-Release

1. I1 stays `NEIN` until a non-local HTTPS six-service surface is source-bound to RC38.
2. I5 stays `NEIN` until production OAuth and the hosted fail-closed evidence verifier pass.

## Guardrails / Non-Claims

- DEV-ONLY; hosted proof still blocked.
- The exact-head CI result proves a source checkout, not six-service I1 parity.
- Local Docker image IDs are not registry digests.
- GHCR publication remains unexecuted.
- `docker_registry_publish` and `production_auth_identity` remain `live_verified=false`.
- This artifact does not claim a production rollout.
- Production deployment still requires the release-candidate gate bundle and a separate rollout proof.
- No default-branch write, registry push, production deploy, release promotion, payment,
  secret output, or production-auth promotion is performed.
