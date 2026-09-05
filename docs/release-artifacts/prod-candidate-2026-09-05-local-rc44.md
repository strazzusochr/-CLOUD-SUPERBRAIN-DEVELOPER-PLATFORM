# Release Artifact

release_id: `prod-candidate-2026-09-05-local-rc44`
scope: `RC44 no-credit requalification for the immutable Python base CVE repair, login-route-bound auth-console diagnostics, and deterministic Three.js generated-HTML repair`
environment: `production-candidate`
source_branch: `codex/rc39-python-base-cve-fix`
source_commit_sha: `efd6826228c8e0b664a44d9a24ab38677e3b86f8`
source_commit_semantics: `frozen RC44 runtime source; direct child Q changes only source-qualification-control.json and binds the exact source archive`
immutable_image_commit_sha: `efd6826228c8e0b664a44d9a24ab38677e3b86f8`
source_attestation_control_sha: `c0f4663721ba0ac3032716b457bc5fc14658e3be`
source_archive_sha256: `506c89adab825c349eed809d8b3f7c992dd4faa29fb047cecc1925930fe45310`
workflow_run_url: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/33979907937`
exact_head_ci_attestation: `docs/release-artifacts/prod-candidate-2026-09-05-local-rc44-evidence/ci/exact-head-ci-attestation.json`
pipeline_status: `success; Q is the workflow head, S is the immutable source checkout, failed jobs=0, skipped jobs=0, skipped steps=0`
local_validation_status: `release-scoped five-chain RC44 evidence is mandatory and verifier-enforced; this metadata line grants no credit and makes no hosted claim`
security_validation: `the source repairs seven observed libuuid HIGH findings with the immutable Python 3.14.5 Alpine 3.22 base and keeps the full default gitleaks ruleset fail closed`
smoke_result: `DEV-ONLY local evidence only; the full hosted stack and hosted browser parity are not claimed`
observability_check: `remote-scan failures expose only bounded counts plus sanitized CVE and package identifiers; secret match contents and registry internals are never emitted`
rollback_note: `local rollback target is S 5668e7cb89eac03a929853f004204b56bd171cb9; no hosted rollback is authorized or executed`
rollback_target_commit_sha: `5668e7cb89eac03a929853f004204b56bd171cb9`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:efd6826228c8e0b664a44d9a24ab38677e3b86f8`
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

RC44 advances the active source without awarding percentage credit. The candidate
retains the Python image base repair and adds a shared fail-closed browser diagnostic
policy limited to correlated same-origin anonymous auth 401 probes while the current
route is `/login`. It also repairs invalid generated Three.js
`Box3.computeBoundingSphere()` calls and regression-tests the repair without changing
comments or strings. I1 `hosted_candidate_parity` and I5
`production_auth_identity` remain zero-credit blocks.

| ID | JA/NEIN | Beleg |
| --- | --- | --- |
| C1 | JA | GitHub Actions run 33979907937 completed successfully and is bound to Q as run head and S as the exact source checkout. |
| C2 | JA | Five independent release-scoped local verification chains must pass before this truth transition is committed. |
| C3 | JA | The pointer, Q control, candidate artifact, and staged truth select RC44/S exactly. |
| C4 | JA | Runtime-source and no-credit requalification parity remain fail-closed. |
| C5 | JA | The committed archive is scanned with the canonical default gitleaks rules and twelve image scans remain required. |
| I1 | NEIN | No non-local HTTPS six-service hosted stack is bound exactly to RC44. |
| I2 | JA | Six multi-architecture candidate images are locally content-addressed; RC44 GHCR tags remain unpublished. |
| I3 | JA | S2 is the immutable local rollback anchor. |
| I4 | JA | No provider, paid tier, card requirement, or recurring amount is introduced. |
| I5 | NEIN | Production auth remains closed without hosted evidence. |
| V1 | JA | Health, metrics, and audit paths remain candidate-bound contracts. |
| V2 | JA | Error, rate, session, request, trace, and gateway fail-closed contracts remain unchanged. |
| V3 | JA | Q, CI source-checkout attestation, candidate artifact, and rollback source are linked. |
| V4 | JA | Incident escalation and stop gates remain bound. |
| O1 | JA | The immutable rollback runbook applies to S2 as target. |
| O2 | JA | Incident-response and secret-rotation runbooks remain present. |
| O3 | JA | Review remains pending and no-release stays explicit. |
| O4 | JA | I1 and I5 remain the two explicitly accepted no-release blockers. |
| O5 | JA | Production, promotion, RC44 registry publication, and rollout remain false. |

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
- RC44 GHCR publication remains a separately gated Owner action and is not executed or credited.

## Open Questions Accepted Under No-Release

1. I1 stays `NEIN` until a non-local HTTPS six-service surface is source-bound to RC44.
2. I5 stays `NEIN` until production OAuth and the hosted fail-closed evidence verifier pass.

## Guardrails / Non-Claims

- DEV-ONLY; hosted proof still blocked.
- Source-prequalification proves an immutable checkout, not six-service I1 parity.
- Local Docker image IDs are not registry digests.
- RC44 GHCR publication remains unexecuted.
- The earlier S2 registry publication does not prove or publish RC44 images.
- `docker_registry_publish` and `production_auth_identity` remain `live_verified=false` for RC44.
- This artifact does not claim a production rollout.
- Production deployment still requires the release-candidate gate bundle and a separate rollout proof.
- No default-branch write, RC44 registry push, production deploy, release promotion, payment,
  secret output, or production-auth promotion is performed by this truth transition.
