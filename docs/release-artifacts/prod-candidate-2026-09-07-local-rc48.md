# Release Artifact

release_id: `prod-candidate-2026-09-07-local-rc48`
scope: `RC48 no-credit requalification for the immutable S3 source after the RC48 Codespaces and hosted-verifier control corrections`
environment: `production-candidate`
source_branch: `chore/repo-bootstrap`
source_commit_sha: `e949cc1a50f21a3c565c2c2f2380a663f2cc4be7`
source_commit_semantics: `frozen RC48 runtime source; direct child Q3 changes only source-qualification-control.json and binds the exact source archive`
immutable_image_commit_sha: `e949cc1a50f21a3c565c2c2f2380a663f2cc4be7`
source_attestation_control_sha: `79a186af68e9c54653894de818422976a2f2fb04`
source_archive_sha256: `56b2ec11da962f359e64f6a8f1ef41ab202a38d2474b2826b929c30e6740254a`
workflow_run_url: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/34154969045`
exact_head_ci_attestation: `docs/release-artifacts/prod-candidate-2026-09-07-local-rc48-evidence/ci/exact-head-ci-attestation.json`
pipeline_status: `success; Q3 is the workflow head, S3 is the immutable source checkout, failed jobs=0, skipped jobs=0, skipped steps=0`
local_validation_status: `release-scoped five-chain RC48 evidence is mandatory and verifier-enforced; this metadata line grants no credit and makes no hosted claim`
security_validation: `the committed S3 archive must pass npm audit and the canonical default gitleaks rules before qualification`
smoke_result: `DEV-ONLY local evidence only; the full hosted stack and hosted browser parity are not claimed`
observability_check: `all generated evidence is release-scoped, source-bound, sanitized, and hash-verified`
rollback_note: `local rollback target is RC44 source efd6826228c8e0b664a44d9a24ab38677e3b86f8; no hosted rollback is authorized or executed`
rollback_target_commit_sha: `efd6826228c8e0b664a44d9a24ab38677e3b86f8`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:e949cc1a50f21a3c565c2c2f2380a663f2cc4be7`
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

RC48 advances the active source to S3 without awarding percentage credit. Q3 binds
the exact release and archive, and GitHub Actions run 34154969045 verifies Q3 while
checking out S3 as the immutable source with no failed or skipped jobs or steps.
I1 `hosted_candidate_parity` and I5 `production_auth_identity` remain zero-credit
blocks until their independent hosted evidence chains pass.

| ID | JA/NEIN | Beleg |
| --- | --- | --- |
| C1 | JA | GitHub Actions run 34154969045 completed successfully and binds Q3 as run head and S3 as exact source checkout. |
| C2 | JA | Five independent release-scoped local verification chains must pass before this truth transition is committed. |
| C3 | JA | Pointer, Q3 control, candidate artifact, and staged truth select RC48/S3 exactly. |
| C4 | JA | Runtime-source and no-credit requalification parity remain fail-closed. |
| C5 | JA | The committed archive is checked by npm audit and the canonical default gitleaks rules. |
| I1 | NEIN | No non-local HTTPS six-service hosted stack is bound exactly to RC48/S3. |
| I2 | JA | Six candidate images are locally content-addressed; RC48/S3 GHCR tags remain unpublished. |
| I3 | JA | RC44 is the immutable local rollback anchor. |
| I4 | JA | No provider, paid tier, card requirement, or recurring amount is introduced. |
| I5 | NEIN | Production auth remains closed without hosted OAuth evidence. |
| V1 | JA | Health, metrics, and audit paths remain candidate-bound contracts. |
| V2 | JA | Error, rate, session, request, trace, and gateway fail-closed contracts remain unchanged. |
| V3 | JA | Q3, exact-head CI attestation, candidate artifact, and rollback source are linked. |
| V4 | JA | Incident escalation and stop gates remain bound. |
| O1 | JA | The immutable rollback runbook applies to RC44 as target. |
| O2 | JA | Incident-response and secret-rotation runbooks remain present. |
| O3 | JA | Review remains pending and no-release stays explicit. |
| O4 | JA | I1 and I5 remain the two explicitly accepted no-release blockers. |
| O5 | JA | Production, promotion, RC48 registry publication, and rollout remain false. |

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
- RC48 GHCR publication remains separately gated and is not executed or credited.

## Open Questions Accepted Under No-Release

1. I1 stays `NEIN` until a non-local HTTPS six-service surface is source-bound to RC48/S3.
2. I5 stays `NEIN` until production OAuth and its hosted fail-closed verifier pass.

## Guardrails / Non-Claims

- DEV-ONLY; hosted proof still blocked.
- Source-prequalification proves an immutable checkout, not six-service I1 parity.
- Local Docker image IDs are not registry digests.
- RC48 GHCR publication remains unexecuted.
- Earlier candidate publications do not prove or publish RC48/S3 images.
- `docker_registry_publish` and `production_auth_identity` remain `live_verified=false` for RC48.
- This artifact does not claim a production rollout.
- Production deployment still requires the release-candidate gate bundle and a separate rollout proof.
- No default-branch write, RC48 registry push, production deploy, release promotion, payment,
  secret output, or production-auth promotion is performed by this truth transition.
