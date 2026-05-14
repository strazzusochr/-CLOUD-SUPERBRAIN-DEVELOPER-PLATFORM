# Release Artifact

release_id: `prod-candidate-2026-05-11-rc1`
scope: `release-boundary cleanup, HF router truth, frontend build, agent-api/runtime compile checks, hosted staging smoke checks, immutable staging image candidate, Phase 3 Security Audit Surface, Autonomous Team Dispatch UI, Security Review Queue, Security Review Queue Snapshot`
environment: `production-candidate`
source_branch: `chore/repo-bootstrap`
image_build_branch: `codex/live-agent-steering-ui-20260513`
source_commit_sha: `8fc8654f4a77a7b6705f351e060244bfc42d664e`
source_commit_semantics: `Vercel production branch remains chore/repo-bootstrap; immutable GHCR images were built from codex/live-agent-steering-ui-20260513 at the current validated runtime head including live-agent UI/runtime state, Phase 5 runtime-selector truth, immutable image-filesystem staging proof, the Phase 3 Security Audit Surface, the Autonomous Team Dispatch UI, the Security Review Queue, and the Security Review Queue Snapshot`
immutable_image_commit_sha: `8fc8654f4a77a7b6705f351e060244bfc42d664e`
workflow_run_url: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25833000061`
pipeline_status: `local Docker Buildx with arm64 binfmt built and pushed all six GHCR images for 8fc8654f4a77a7b6705f351e060244bfc42d664e after py_compile, Next.js build, local Security Review Queue snapshot verifier, and local browser-contract passed; hosted immutable deploy plus hosted security-review snapshot/browser/smoke verifiers passed after push`
smoke_result: `passed`
observability_check: `present`
rollback_note: `no production rollout performed; rollback remains the existing hosted staging rollback path`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:8fc8654f4a77a7b6705f351e060244bfc42d664e`
owner_decision: `approved`
hosted_selector_observed: `IMAGE_TAG=8fc8654f4a77a7b6705f351e060244bfc42d664e`
hosted_selector_observed_at: `2026-05-14T04:03:23Z`
frontend_runtime_image_observed: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/frontend:8fc8654f4a77a7b6705f351e060244bfc42d664e`
immutable_staging_parity_status: `verified`
active_candidate_gate_rerun_proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-candidate-gate-rerun.md`
runtime_selector_truth_proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-runtime-selector-truth.md`
immutable_staging_parity_proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-security-review-snapshot-immutable-staging-20260514.md`

## Verification Evidence

- Python compile check: `py -3 -m compileall services\agent-api\app services\agent-worker\app services\llm-gateway\app`
- Frontend production build: `npm run build --prefix apps/frontend`
- Phase 3 Security Audit Surface local proof: `scripts\verify-phase3-security-audit-surface-hosted.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Autonomous Team Dispatch UI local proof: `scripts\verify-autonomous-coding-team.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Security Review Queue local proof: `scripts\verify-phase3-security-review-queue.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` including snapshot endpoint, filter state, risk badges, decision history, evidence snapshot, redaction, and mutation block checks
- Browser contract local proof: `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- GHCR arm64 image build/push: `docker run --privileged --rm tonistiigi/binfmt --install arm64`, then `scripts\build-and-push.ps1 -Tag 8fc8654f4a77a7b6705f351e060244bfc42d664e -Platforms linux/arm64 -Builder codex-multiarch`
- Immutable staging deploy: `scripts\deploy-to-staging.ps1 -UseImageFilesystem -ImageTag 8fc8654f4a77a7b6705f351e060244bfc42d664e -KeyPath <local-private-key>`
- Phase 3 Security Audit Surface hosted proof: `scripts\verify-phase3-security-audit-surface-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Autonomous Team Dispatch UI hosted proof: `scripts\verify-autonomous-coding-team.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Security Review Queue hosted proof: `scripts\verify-phase3-security-review-queue.ps1 -BaseUrl https://188-34-191-140.sslip.io` including snapshot endpoint, filter state, risk badges, decision history, evidence snapshot, redaction, and mutation block checks
- Browser contract hosted proof: `scripts\verify-browser-contract.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Hosted staging smoke: `scripts\verify-hosted-staging-smoke.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Security suite: `scripts\verify.ps1 -Suite security`
- Hosted staging smoke: `scripts\verify.ps1 -Suite hosted-staging-smoke -BaseUrl https://188-34-191-140.sslip.io`
- Hosted staging safe profile: `scripts\verify.ps1 -Suite hosted-staging -BaseUrl https://188-34-191-140.sslip.io -SafeProfile`
- Release boundary suite: `scripts\verify.ps1 -Suite release-boundary -ReportOnly`
- Main deploy workflow for immutable staging image commit: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25833000061` (verify plus five service builds succeeded; frontend job was force-cancelled after OCI manifest retag proof)
- Frontend immutable manifest retag proof: `docker buildx imagetools create -t ghcr.io/strazzusochr/cloud-superbrain-developer-platform/frontend:031c95c3e5af1101caf282eee463256285803495 ghcr.io/strazzusochr/cloud-superbrain-developer-platform/frontend:97c7ea04b5180862ea9862cc18b9c5bac994f794`
- Main deploy workflow for release-boundary source head: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25765691998`
- Main deploy workflow for metadata/verifier wrapper head: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25782828285`
- Hosted staging proof workflow: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25738288780`
- Production tag gate ordering: `production-gate` depends on `verify`, uses environment `production`, and `build-and-push` waits for `production-gate` before publishing production tags.
- Immutable staging plan: `scripts\deploy-to-staging.ps1 -PlanOnly -UseImageFilesystem -ImageTag 8fc8654f4a77a7b6705f351e060244bfc42d664e`
- Immutable staging parity ready check: `scripts\manual\verify-phase5-staging-immutable-parity.ps1 -ReleaseId prod-candidate-2026-05-11-rc1 -CandidateSha 8fc8654f4a77a7b6705f351e060244bfc42d664e`
- Immutable staging parity remote proof: `scripts\manual\verify-phase5-staging-immutable-parity.ps1 -RequireVerified -ReleaseId prod-candidate-2026-05-11-rc1 -CandidateSha 8fc8654f4a77a7b6705f351e060244bfc42d664e -BaseUrl https://188-34-191-140.sslip.io -KeyPath <local-private-key>`
- Active candidate gate rerun proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-candidate-gate-rerun.md`
- Runtime selector truth proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-runtime-selector-truth.md`

## Cloud Surfaces

- Vercel frontend: `https://frontend-seven-psi-78.vercel.app/`
- Hetzner hosted platform: `https://188-34-191-140.sslip.io/`
- Agent API health: `https://188-34-191-140.sslip.io/api/v1/health`
- LLM gateway health: `https://188-34-191-140.sslip.io/llm/api/v1/health`

## Security Review Queue Snapshot Evidence

- Contract: `security-review-queue-v1`
- Endpoint: `GET /api/v1/security/review-queue`
- Snapshot endpoint: `GET /api/v1/security/review-queue/snapshot`
- Evidence refs: `security_review_queue_visible`, `security_review_item_visible`, `security_review_filter_state_visible`, `security_review_decision_history_visible`, `security_review_evidence_snapshot_visible`, `security_review_redaction_enforced`, `security_review_mutation_blocked`
- Risk badges: `release_blocker_review`, `review_required`, `runtime_monitor`, and `monitor` are derived from queue status/severity/category without leaking raw payload details.
- Decision history: queue entries expose deterministic review history references and evidence snapshots while keeping the surface read-only.
- Mutation policy: `POST/PUT/PATCH/DELETE /api/v1/security/review-queue` return HTTP `403`; queue is read-only and redacted.
- Non-claims: no production rollout, no secret disclosure, no SOC/SIEM completeness claim, no live provider or live MCP writes.

## Guardrails

- This artifact approves the current clean repository boundary as a production candidate.
- The release boundary source commit is `8fc8654f4a77a7b6705f351e060244bfc42d664e`; the immutable image commit deployed to staging is `8fc8654f4a77a7b6705f351e060244bfc42d664e`.
- This artifact does not claim a production rollout.
- Remote immutable Hetzner parity for `8fc8654f4a77a7b6705f351e060244bfc42d664e` is current staging evidence only; production is still not rolled out.
- This artifact does not replace the historical `prod-candidate-2026-05-05-rc1` no-release evidence.
- The hosted selector line records the current Hetzner staging selector observed after later deployment work; it does not rewrite the historical 2026-05-05 rollback selector.
- Production deployment still requires the release-candidate gate bundle and a separate rollout proof.
