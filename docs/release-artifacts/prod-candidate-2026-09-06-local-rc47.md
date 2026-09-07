# Release Artifact

release_id: `prod-candidate-2026-09-06-local-rc47`
scope: `RC47 no-credit requalification; source-qualified S2 archive and release-scoped evidence collection`
environment: `production-candidate`
source_branch: `codex/s2-q2-rc47-qualification`
source_commit_sha: `351b10e483258de3d52da0ef5c47b6bfb65f3548`
source_commit_semantics: `frozen S2 runtime source; qualification control Q2 binds the exact archive and later evidence records do not alter S2`
immutable_image_commit_sha: `351b10e483258de3d52da0ef5c47b6bfb65f3548`
source_attestation_control_sha: `409721d463f2190b45e07e8ce5a4baf91bfb7a64`
source_archive_sha256: `885b5f5ba66851ff3bada25ba4b39d36fb3fde41491d073e497a7c90f4145f34`
workflow_run_url: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/34053591807`
exact_head_ci_attestation: `docs/release-artifacts/prod-candidate-2026-09-06-local-rc47-evidence/ci/source-checkout-attestation.json`
pipeline_status: `success; Q2 is the workflow control head and S2 is the immutable source checkout; the following local evidence chains remain separately fail-closed`
local_validation_status: `release-scoped evidence is collected independently; this metadata grants no credit and makes no hosted claim`
security_validation: `the committed S2 archive is scanned only by the canonical npm-audit and gitleaks security writer`
smoke_result: `DEV-ONLY local evidence only; hosted stack and hosted browser parity are not claimed`
observability_check: `evidence is sanitized; secret values and secret-like match contents are never recorded`
rollback_note: `local rollback target is S2; no hosted rollback is authorized or executed`
rollback_target_commit_sha: `351b10e483258de3d52da0ef5c47b6bfb65f3548`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:351b10e483258de3d52da0ef5c47b6bfb65f3548`
immutable_tag_publish_status: `unpublished`
rollback_drill_proof: `docs/runbooks/rollback-deploy.md`
truth_mirror_rebaseline_proof: `docs/runtime-state/phase5-credit-itemization.json`
review_gate: `pending`
owner_decision: `no-release`
hosted_staging_parity: `false`
production_rollout_claimed: `false`
checklist_verified_count: `17`
checklist_blocked_count: `2`
phase5_computed_percent: `89`

## Phase-5 Readiness Checklist

This RC47 artifact binds evidence to S2 without awarding a percentage credit.
I1 `hosted_candidate_parity` and I5 `production_auth_identity` remain zero-credit
blocks until their respective hosted evidence is independently verified.

| ID | JA/NEIN | Beleg |
| --- | --- | --- |
| C1 | JA | Run 34053591807 binds Q2 as control head and S2 as exact checkout. |
| C2 | JA | Release-scoped evidence chains are independent and fail closed. |
| C3 | JA | Q2 names S2 and the exact S2 archive hash. |
| C4 | JA | Runtime-source parity remains fail closed. |
| C5 | JA | Candidate archive security evidence uses the canonical tools only. |
| I1 | NEIN | No non-local HTTPS six-service surface is bound to S2. |
| I2 | JA | Six local candidate images are source-bound but not registry-published. |
| I3 | JA | S2 is the immutable rollback target. |
| I4 | JA | No paid provider, card requirement, or recurring cost is introduced. |
| I5 | NEIN | Production OAuth lacks hosted evidence. |
| V1 | JA | Candidate health, metrics, and audit contracts remain source-bound. |
| V2 | JA | Error, rate, session, request, trace, and gateway contracts remain fail closed. |
| V3 | JA | Q2, CI checkout attestation, artifact, and source archive are linked. |
| V4 | JA | Incident escalation and stop gates remain bound. |
| O1 | JA | The rollback runbook applies to S2. |
| O2 | JA | Incident-response and secret-rotation runbooks remain present. |
| O3 | JA | Review is pending and no-release remains explicit. |
| O4 | JA | I1 and I5 remain the two explicit no-release blockers. |
| O5 | JA | Production, promotion, registry publication, and rollout remain false. |

## Guardrails / Non-Claims

- DEV-ONLY; hosted proof still blocked.
- Source prequalification proves an immutable checkout, not hosted six-service parity.
- Local Docker image IDs are not registry digests.
- `docker_registry_publish` and `production_auth_identity` remain `live_verified=false`.
- This artifact does not claim a production rollout.
- No registry push, production deploy, release promotion, payment, secret output, or provider call is performed by this metadata.
