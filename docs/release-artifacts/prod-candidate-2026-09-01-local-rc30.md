# Release Artifact

release_id: `prod-candidate-2026-09-01-local-rc30`
scope: `RC30 browserslist security remediation and same-day source-bound no-credit requalification`
environment: `production-candidate`
source_branch: `codex/organism-visual-v2`
source_commit_sha: `9e88f84ac6c4afd78e152b5dc3b5bb08cf636c68`
source_commit_semantics: `frozen RC30 source with browserslist 4.28.8 pinned above the two newly disclosed high-severity advisory ranges`
immutable_image_commit_sha: `9e88f84ac6c4afd78e152b5dc3b5bb08cf636c68`
source_attestation_control_sha: `f5a31e52e8bbf6d166c7a1c11932f15219c587c1`
workflow_run_url: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/33540678387`
pipeline_status: `success; exact source checkout attested; 31/31 observed steps green; skipped=0; frontend audit found 0 vulnerabilities; no release or production claim`
smoke_result: `source prequalification and six clean-archive images passed; remaining RC30 local evidence chains are being rebound serially; DEV-ONLY; hosted proof still blocked`
observability_check: `candidate-bound local health, metrics, audit, trace, O4 fail-closed, and browser readback paths remain mandatory; production observability is not claimed`
rollback_note: `local rollback target remains RC27 source 0ca71d1c6168d64360a7764b725b2b673af00afe because RC29 final-head CI failed; no hosted rollback is authorized or executed`
rollback_target_commit_sha: `0ca71d1c6168d64360a7764b725b2b673af00afe`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:9e88f84ac6c4afd78e152b5dc3b5bb08cf636c68`
immutable_tag_publish_status: `unpublished`
rollback_drill_proof: `docs/runbooks/rollback-deploy.md`
executed_rollback_rerun_proof: `docs/release-artifacts/prod-candidate-2026-09-01-local-rc30-readiness.json`
owner_decision_proof: `e87c28a7c6cf32982caa849794042daa53ef022a`
budget_review_proof: `docs/release-artifacts/prod-candidate-2026-09-01-local-rc30-readiness.json`
open_questions_acceptance_proof: `docs/release-artifacts/prod-candidate-2026-09-01-local-rc30-readiness.json`
risk_review_recheck_proof: `docs/release-artifacts/prod-candidate-2026-09-01-local-rc30-readiness.json`
provenance_review_proof: `docs/release-artifacts/prod-candidate-2026-09-01-local-rc30-readiness.json`
smoke_recheck_proof: `docs/release-artifacts/prod-candidate-2026-09-01-local-rc30-readiness.json`
observability_recheck_proof: `docs/release-artifacts/prod-candidate-2026-09-01-local-rc30-readiness.json`
browser_evidence_reactivation_proof: `docs/release-artifacts/prod-candidate-2026-09-01-local-rc30-readiness.json`
browser_proof: `docs/release-artifacts/prod-candidate-2026-09-01-local-rc30-readiness.json`
post_rollback_browser_revalidation_proof: `not-applicable-retired-rc1-boundary`
final_browser_e2e_recheck_proof: `docs/release-artifacts/prod-candidate-2026-09-01-local-rc30-readiness.json`
full_verifier_sweep_proof: `docs/release-artifacts/prod-candidate-2026-09-01-local-rc30-readiness.json`
full_verifier_sweep_status: `RC30 source CI and candidate images passed; remaining local evidence chains pending; hosted I1 and production-auth I5 remain blocked`
truth_mirror_rebaseline_proof: `docs/runtime-state/phase5-credit-itemization.json`
release_readiness_rerun_proof: `docs/release-artifacts/prod-candidate-2026-09-01-local-rc30-readiness.json`
browser_rerun_status: `RC30 immutable candidate-browser evidence rebinding remains pending`
review_gate: `pending`
owner_decision: `no-release`
hosted_staging_parity: `false`
production_rollout_claimed: `false`
checklist_verified_count: `17`
checklist_blocked_count: `2`
phase5_computed_percent: `89`

## Phase-5 Readiness Checklist

RC30 supersedes RC29 only after the same five independent local qualification chains are
rebound to the exact source. RC30 changes only the frontend dependency resolution needed
to close the newly disclosed Browserslist audit findings; it does not award percentage
credit. I1 `hosted_candidate_parity` and I5 `production_auth_identity` remain zero-credit
blocks.

| ID | JA/NEIN | Beleg |
| --- | --- | --- |
| C1 | JA | Exact candidate-source CI attestation is bound to RC30. |
| C2 | JA | Runtime, browser, security, candidate-image, and candidate-runtime chains must be hash-bound before final selection. |
| C3 | JA | Candidate, readiness, and Phase-5 truth select the frozen RC30 source. |
| C4 | JA | Runtime-source and no-credit requalification parity remain fail-closed, including same-day selection. |
| C5 | JA | Candidate archive npm audit and canonical gitleaks scan are required. |
| I1 | NEIN | No non-local HTTPS six-service hosted stack is bound exactly to RC30. |
| I2 | JA | Six clean-archive images are locally content-addressed; GHCR remains Post-Market. |
| I3 | JA | RC27 source is the immutable local rollback anchor. |
| I4 | JA | No new provider, paid tier, card requirement, or recurring amount is introduced. |
| I5 | NEIN | Production auth remains closed without hosted evidence. |
| V1 | JA | Health, metrics, and audit paths remain candidate-bound. |
| V2 | JA | Error, rate, session, request, and trace contracts remain candidate-bound. |
| V3 | JA | CI, verifier, browser, image, rollback, and readiness artifacts are required. |
| V4 | JA | Incident escalation and stop gates remain bound. |
| O1 | JA | The immutable rollback runbook applies to RC27 as target. |
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

1. I1 stays `NEIN` until a non-local HTTPS six-service surface is source-bound to RC30.
2. I5 stays `NEIN` until production OAuth and the hosted fail-closed evidence verifier pass.

## What This Candidate Changes Against RC29

RC29 final-head CI exposed two newly published high-severity Browserslist advisories after
its source prequalification had passed. RC30 pins `browserslist` `4.28.8` through npm
overrides and refreshes only the lockfile dependency closure. Clean `npm ci` plus
`npm audit --audit-level=moderate` report zero vulnerabilities. Product runtime logic and
the RC29 Three.js repair are unchanged. The control commit differs from the frozen source
only by the allowlisted source-prequalification binding comment.

## Guardrails / Non-Claims

- DEV-ONLY; hosted proof still blocked.
- Local Docker image IDs are not registry digests.
- GHCR publication is Post-Market and remains unexecuted.
- `docker_registry_publish` remains owner-granted false and live-verified false.
- This artifact does not claim a production rollout.
- Production deployment still requires the release-candidate gate bundle and a separate rollout proof.
- No default-branch write, registry push, production deploy, release promotion, payment,
  secret output, or production-auth promotion is performed.
