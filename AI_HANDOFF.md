# AI Handoff - Cloud Superbrain Developer Platform

## Project Root

`<repo-root>`

Open this entire folder in the next IDE or AI-agent tool. Do not copy only tracked Git files: the current project state contains many new, untracked files that are required for a 1:1 handoff.

Current honesty guardrail: the active staging candidate is `13d02661c5cfbc2e4a881f1a16f303002affca06`, verified through GHCR multi-service images and Hetzner `-UseImageFilesystem` parity. This is a staging-candidate claim only; production rollout remains unclaimed.

## Binding Truth

Primary project truth hierarchy:

- `docs/project-progress.manifest.json` is the canonical source for current progress percentages and current gate-closure status.
- `docs/verification-register.md` is the evidence register and may contain historical milestone notes, but it is not a separate progress authority.
- `PROJECT_STATE.md` and this handoff file are derived mirrors and must follow the manifest plus evidence register.
- `PROJECT_STATE.md`
- `PROJECT_ANCHOR.md`
- `docs/project-checkpoint-2026-04-30.json`
- `AGENTS.md`
- `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md`
- `docs/project-progress.manifest.json`
- `docs/verification-register.md`

Follow `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md` over older planning files when there is any conflict.

## Active Project Anchor

Anchor ID: `project-anchor-2026-04-30T00-49-26+02-00`

Use `PROJECT_ANCHOR.md` plus `docs/project-checkpoint-2026-04-30.json` as the current resume point. It records the verified `<local-control-plane-host>` health snapshot, the restored session-history proof, the current `79%` progress state, the detailed repair protocol, and the current hosted evidence chain up through the progress-bound live-agent-steering/history Phase-3 evidence, the Phase-5 immutable staging parity proof, the Phase-3 Security Audit Surface proof, the Autonomous Team Dispatch UI proof, Security Review Gate Summary proof, LLM Audit Feed Redaction Snapshot proof, LLM Audit Export proof, MCP Audit Redaction Snapshot proof, Gateway Correlation Snapshot proof, Gateway Correlation Risk Rollup proof, Gateway Correlation Timeline proof, Auth Audit Snapshot proof, Auth Audit Risk Rollup proof, Auth Audit Timeline proof, and Auth Audit Export proof. Continue Phase-3 security/product-surface evidence before rollout.

## Current Verified Progress

Overall: `79%`

Horizontal:

- P0: `100%`
- P1: `100%`
- P2: `88%`
- P3: `88%`
- P4: `100%`
- P5: `74%`
- P6: `0%`

Vertical:

- Frontend / Next.js: `99%`
- Orchestrator / LangGraph: `99%`
- Agent Pool: `73%`
- LLM Gateway: `62%`
- MCP Gateway: `61%`
- Memory: `72%`
- Observability: `99%`

Older percentage lines below are historical proof points only. Current percentages must come from this section and `docs/project-progress.manifest.json`.

## Latest Verified Step

LLM Audit Export Proof:

- `GET /api/v1/audit/llm/export/contract` exposes `llm-audit-export-v1`, `llm_audit_export_visible`, `llm_audit_export_audit_persisted`, `llm_audit_redaction_enforced`, and `llm_audit_no_live_provider_guard`.
- `GET /api/v1/audit/llm/export?format=csv&limit=80` reads only the same safe LLM Audit projection as feed and snapshot and emits allowlisted CSV columns only.
- Export and export audit metadata do not return prompt bodies, tokens, cookies, authorization headers, provider credentials, raw details, live provider claims, production rollout claims, or promotion claims.
- Local proof passed: `scripts\verify-phase3-llm-audit-export.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireSeed`, `scripts\verify-phase3-llm-audit-feed.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, browser-contract, py_compile, Next.js build, Docker readiness, security, and evidence-artifact-safety.
- Hosted proof passed after GHCR build/push plus Hetzner immutable deploy for `IMAGE_TAG=13d02661c5cfbc2e4a881f1a16f303002affca06`: LLM-audit export, LLM-audit feed, browser-contract, hosted-staging, and full Phase-3 suite.
- Progress change: Overall rises to `79%`; Phase 3 rises to `88%`; LLM Gateway rises to `62%`; no production rollout, live provider call, live MCP write, release promotion, or secret exposure is claimed.

Previous verified step - Auth Audit Export Proof:

- `GET /api/v1/audit/auth/export/contract` exposes `auth-audit-export-v1`, `auth_audit_export_visible`, `auth_audit_export_audit_persisted`, `auth_audit_redaction_enforced`, and `auth_no_live_oauth_guard`.
- `GET /api/v1/audit/auth/export?format=csv&limit=80` reads only the same safe Auth Audit projection as snapshot, risk rollup, and timeline and emits allowlisted CSV columns only.
- Export and export audit metadata do not return tokens, cookies, authorization headers, OAuth code/state values, Redis blacklist keys, raw details, live GitHub OAuth claims, production rollout claims, or promotion claims.
- Local proof passed: `scripts\verify-phase3-auth-audit-export.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireLifecycle`, Auth Audit Snapshot/Risk Rollup/Timeline local verifiers, browser-contract, py_compile, Next.js build, Docker readiness, security, evidence-artifact-safety, and manifest validation.
- Hosted proof passed after GHCR build/push plus Hetzner immutable deploy for `IMAGE_TAG=efa2035e565a500b4c530fffdbab5016853a910e`: auth lifecycle, auth-audit export, auth-audit snapshot, auth-audit risk-rollup, auth-audit timeline, browser-contract, hosted-staging, and full Phase-3 suite.
- Progress change: Overall remains `78%`; Phase 3 rises to `86%`; no production rollout, live GitHub OAuth claim, live provider call, live MCP write, release promotion, or secret exposure is claimed.

Previous verified step - Auth Audit Snapshot Proof:

- `GET /api/v1/audit/auth/contract` exposes `auth-audit-snapshot-v1`, `parent_contract_version=auth-github-jwt-refresh-v1`, `read_only=true`, `auth_audit_snapshot_visible`, `auth_audit_redaction_enforced`, and `auth_no_live_oauth_guard`.
- `GET /api/v1/audit/auth/snapshot` reads only `audit_log`, returns safe Auth lifecycle fields, counts callback/refresh/logout events, and does not return tokens, cookies, authorization headers, OAuth code/state values, Redis blacklist keys, or raw details.
- Local proof passed: `scripts\verify-phase3-auth-audit-snapshot.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireLifecycle`, `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `py -3 -m py_compile services\agent-api\app\main.py`, `npm run build`, `scripts\verify-security.ps1`, and `scripts\verify-evidence-artifact-safety.ps1`.
- Hosted proof passed after GHCR build/push plus Hetzner immutable deploy for `IMAGE_TAG=7a849155a7b6c3f2dd3ba93ff9fa306ad87b9296`: auth lifecycle, auth-audit snapshot, browser-contract, smoke, and full Phase-3 suite.
- Progress change: Overall remains `77%`; Phase 3 rises to `80%`; no production rollout, live GitHub OAuth claim, live provider call, live MCP write, release promotion, or secret exposure is claimed.

Previous verified step - Gateway Correlation Timeline Proof:

- `GET /api/v1/security/gateway-correlation/timeline` exposes `gateway-correlation-timeline-v1`, `gateway_correlation_timeline_visible`, `read_only=true`, `promotion_allowed=false`, `production_rollout_claimed=false`, `live_provider_calls_claimed=false`, and `live_mcp_writes_claimed=false`.
- The timeline derives from safe `audit_log` correlation events and returns ordered sequence/event/leg/correlation/evidence fields without prompt bodies, raw MCP input refs, provider credentials, cookies, authorization headers, or full details.
- Hosted proof passed after GHCR build/push plus Hetzner immutable deploy for `IMAGE_TAG=d2c8b9c52785955b698da151edb666c884ac888f`: hosted snapshot, risk rollup, timeline, browser-contract, smoke, and full Phase-3 suite.
- Progress change: Overall remains `77%`; Phase 3 rises to `78%`; no production rollout, live provider call, live MCP write, release promotion, or secret exposure is claimed.

Previous verified step - Gateway Correlation Risk Rollup Proof:

- `GET /api/v1/security/gateway-correlation/risk-rollup` exposes `gateway-correlation-risk-rollup-v1`, `gateway_correlation_risk_rollup_visible`, `read_only=true`, `promotion_allowed=false`, `production_rollout_claimed=false`, `live_provider_calls_claimed=false`, and `live_mcp_writes_claimed=false`.
- The rollup derives from safe `audit_log` correlation groups and counts full/partial/gateway-pair correlations, missing Agent/LLM/MCP legs, blocker_count, review_count, risk_badges, and per-group risk states without returning prompt bodies, raw MCP input refs, provider credentials, cookies, or full details.
- Local proof passed: `scripts\verify-phase3-gateway-correlation-snapshot.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts\verify-phase3-gateway-correlation-risk-rollup.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireFullCorrelation`, `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `py -3 scripts\verify_project_progress_manifest.py`, `py -3 -m py_compile services\agent-api\app\main.py`, and `npm run build`.
- Hosted proof passed after GHCR build/push plus Hetzner immutable deploy for `IMAGE_TAG=5a67227c12bbfb1c9da956158ed2cec6d7b6d8a0`: `scripts\verify-phase3-gateway-correlation-snapshot.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `scripts\verify-phase3-gateway-correlation-risk-rollup.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireFullCorrelation`, `scripts\verify-browser-contract.ps1 -BaseUrl https://188-34-191-140.sslip.io`, and `scripts\verify-hosted-staging-smoke.ps1 -BaseUrl https://188-34-191-140.sslip.io`.
- Progress change: Overall remains `77%`; Phase 3 rises to `76%`; no production rollout, live provider call, live MCP write, release promotion, or secret exposure is claimed.

Previous verified step - Gateway Correlation Snapshot Proof:

- `GET /api/v1/security/gateway-correlation/contract` exposes `gateway-correlation-snapshot-v1`, `read_only=true`, `live_provider_calls_claimed=false`, `live_mcp_writes_claimed=false`, and evidence refs `gateway_correlation_snapshot_visible`, `gateway_correlation_redaction_enforced`, `gateway_correlation_no_live_write_guard`.
- `GET /api/v1/security/gateway-correlation/snapshot` groups safe `audit_log` projections across agent task, LLM audit, and MCP audit events while keeping prompt bodies, raw tool input refs, provider credentials, cookies, authorization headers, and full details out of the response.
- Frontend renders `Gateway Correlation Snapshot`, evidence refs, live-call/write non-claims, redaction status, full-correlation counts, and grouped trace/session/request cards.
- Local proof passed: `scripts\verify-phase3-gateway-correlation-snapshot.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, and `py -3 scripts\verify_project_progress_manifest.py`.
- Hosted proof passed after immutable deploy `IMAGE_TAG=10df3ea48627e6f11787587e3c984b72107e78f5`: gateway-correlation verifier, Browser-Contract, and Hosted-Smoke all green on `https://188-34-191-140.sslip.io`.
- Progress change: Overall rises to `77%`; Phase 3 rises to `74%`; Agent Pool rises to `73%`; LLM Gateway rises to `61%`; MCP Gateway rises to `61%`; no production rollout, live provider call, live MCP write, provider billing proof, SOC/SIEM completeness, or secret exposure is claimed.

Previous verified step - MCP Audit Redaction Snapshot Proof:

- `GET /api/v1/audit/mcp/contract` exposes `mcp-audit-feed-v1` with `snapshot_endpoint=GET /api/v1/audit/mcp/snapshot`, `mcp_audit_snapshot_visible`, `mcp_audit_redaction_enforced`, and `live_mcp_writes_claimed=false`.
- `GET /api/v1/audit/mcp` returns MCP audit rows with `input_ref_stored=false` and redaction evidence; `GET /api/v1/audit/mcp/snapshot` returns aggregate status/toolset/capability/error/agent-role counts with `input_refs_returned=false`, `provider_credentials_returned=false`, `forbidden_pattern_hits=0`, and `live_mcp_writes_claimed=false`.
- Frontend renders `MCP Audit Snapshot`, snapshot endpoint markers, redaction evidence, forbidden-hit status, blocked/denied/session-bound counts, and input-ref non-claim.
- Local proof passed: `scripts\verify-phase3-mcp-deny-audit-correlation.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` and `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`.
- Hosted proof passed after immutable deploy `IMAGE_TAG=0a7ca2bed583f2e01af39a73e095e91cee642365`: MCP-audit snapshot verifier, Browser-Contract, and Hosted-Smoke all green on `https://188-34-191-140.sslip.io`.
- Progress change: Overall remains `76%`; Phase 3 rises to `72%`; MCP Gateway rises to `60%`; no production rollout, live provider call, live MCP write, or secret exposure is claimed.

Previous verified step - LLM Audit Feed Redaction Snapshot Proof:

- `GET /api/v1/audit/llm/contract` exposes `llm-audit-feed-v1` with `snapshot_endpoint=GET /api/v1/audit/llm/snapshot`, `llm_audit_snapshot_visible`, and `llm_audit_redaction_enforced`.
- `GET /api/v1/audit/llm` returns LLM audit rows with `prompt_body_stored=false` and redaction evidence; `GET /api/v1/audit/llm/snapshot` returns aggregate status/provider/agent/model counts with `prompt_bodies_returned=false`, `provider_credentials_returned=false`, `forbidden_pattern_hits=0`, and `live_provider_calls_claimed=false`.
- Frontend renders `LLM Audit Snapshot`, snapshot endpoint markers, redaction evidence, forbidden-hit status, dry-run count, and prompt-body non-claim.
- Local proof passed: `scripts\verify-phase3-llm-audit-feed.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` and `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`.
- Hosted proof passed after immutable deploy `IMAGE_TAG=f5fb7d221d403b966b38d240bd5b936755ecc245`: LLM-Audit-Feed verifier, Browser-Contract, and Hosted-Smoke all green on `https://188-34-191-140.sslip.io`.
- Progress change: Overall remains `76%`; Phase 3 rises to `70%`; LLM Gateway rises to `60%`; no production rollout, live provider call, live MCP write, or secret exposure is claimed.

Previous verified step - Security Review Gate Summary Proof:

- `GET /api/v1/security/review-queue/contract` exposes `security-review-queue-v1`, read-only policy, and evidence refs `security_review_queue_visible`, `security_review_item_visible`, `security_review_filter_state_visible`, `security_review_decision_history_visible`, `security_review_evidence_snapshot_visible`, `security_review_redaction_enforced`, and `security_review_mutation_blocked`.
- `GET /api/v1/security/review-queue` returns redacted review items; `GET /api/v1/security/review-queue/snapshot` returns filter state, risk badges, decision history, and evidence snapshots; `GET /api/v1/security/review-queue/gate` returns blocker_count, production_rollout_claimed=false, and promotion_allowed=false; `POST/PUT/PATCH/DELETE /api/v1/security/review-queue` return HTTP `403`.
- Frontend renders `Security Review Queue`, Security Review Gate Summary, endpoint markers, snapshot evidence, filter state, risk badges, decision history, status/severity counts, redaction markers, and item evidence refs.
- Local proof passed: `scripts\verify-phase3-security-review-gate.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` and `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`.
- Hosted proof passed after immutable deploy `IMAGE_TAG=9f1e52266b3d9f9ddbdfc226d68bd2379ead9fad`: Security-Review-Gate verifier, Browser-Contract, and Hosted-Smoke all green on `https://188-34-191-140.sslip.io`.
- Progress change: Overall rises to `76%`; Phase 3 rises to `67%`; no production rollout, live provider call, live MCP write, or secret exposure is claimed.

Previous verified step - Phase 3 Security Audit Surface:

- `GET /api/v1/security/events/contract` exposes `security-audit-surface-v1`, `security_audit_surface_visible`, `security_audit_event_visible`, and `read_only=true`.
- `GET /api/v1/security/events` reads `audit_log` only for CSP/Auth/MCP/LLM security-relevant events.
- Frontend renders `Security Audit Surface`; browser contract now fails closed if the panel/API markers disappear.
- Local proof passed: `scripts\verify-phase3-security-audit-surface-hosted.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` and `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`.
- Hosted proof passed after immutable deploy `IMAGE_TAG=54bb064c8a5650f9a5c811179d3b4d0e1f38cfbf`: Security-Audit verifier, Browser-Contract, and Hosted-Smoke all green on `https://188-34-191-140.sslip.io`.
- Progress change: Overall rises to `73%`; Phase 3 rises to `50%`; LLM Gateway and MCP Gateway rise to `57%`; no production rollout, live provider call, live MCP write, or secret exposure is claimed.

## Current Runtime

Local browser URL:

- `<local-control-plane-url>/`

Superbrain stream URL:

- `<local-control-plane-stream-url>`

Docker stack:

```powershell
docker compose -f docker-compose.dev.yml ps
```

Expected healthy services:

- `nginx`
- `agent-api`
- `frontend`
- `llm-gateway`
- `mcp-gateway`
- `agent-worker`
- `memory-worker`
- `postgres`
- `redis`

## Important Verified Commands

Run from the project root.

```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1
powershell -ExecutionPolicy Bypass -File scripts\verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost
powershell -ExecutionPolicy Bypass -File scripts\verify-hosted-staging.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost
powershell -ExecutionPolicy Bypass -File scripts\verify-external-gates.ps1 -LocalBaseUrl <local-control-plane-url>
powershell -ExecutionPolicy Bypass -File scripts\verify-cloud-only-staging.ps1 -BaseUrl https://<hosted-staging-domain>
powershell -ExecutionPolicy Bypass -File scripts\verify-phase1-runtime.ps1
powershell -ExecutionPolicy Bypass -File scripts\verify-autopilot-mode.ps1 -AllowLocalhost
py -3 scripts\verify_project_progress_manifest.py
```

Recent verification status: local deterministic verifiers were extended for Priority Queue routing, Orchestrator evidence fail-closed behavior, and the ULTIMATE_SANDBOX wrapper-rule correction on 2026-05-01. The local Docker stack was rebuilt and re-proved live on `<local-control-plane-url>`.

Autopilot stream proof now runs through the active Agent API/Nginx stack at `<local-control-plane-stream-url>` and emits `status:init`, `status:llm`, `token`, and `done` with `autopilot-mode-stream-proof`.

## Latest Completed Proof

Phase 5 Active Runtime Selector Truth:

- `docs/release-artifacts/prod-candidate-2026-05-11-rc1-runtime-selector-truth.md` records the active hosted selector truth: `IMAGE_TAG=staging` plus `cloud-superbrain-frontend:source-staging`.
- `docs/release-artifacts/prod-candidate-2026-05-11-rc1.md` now marks current immutable staging parity as `blocked_after_frontend_source_build`.
- `scripts/verify-current-runtime-selector-truth.ps1` binds the active RC, proof artifact, hosted root, hosted progress, and optional SSH selector/image proof.
- `scripts/verify-current-immutable-staging-parity.ps1` now passes this current state only as `blocked`; real immutable parity still requires `-RequireVerified`.
- Progress change: Overall remains `71%`; Phase 5 rises to `69%`. No production rollout, GHCR push, Vercel promotion, live provider call, live MCP write, or immutable candidate parity is claimed.

Previous latest completed proof:

Phase 5 Frontend Source Build Path:

- `docs/release-artifacts/prod-candidate-2026-05-11-rc1-frontend-source-build-path.md` records the staging-only Hetzner frontend source-build proof.
- `scripts/deploy-to-staging.ps1 -FrontendSourceBuild -ImageTag staging` builds `cloud-superbrain-frontend:source-staging` on the host with `pull_policy: never` while backend services stay on `IMAGE_TAG=staging`.
- The failed `staging-src-dba8cb012e8a` selector attempt restored cleanly; the correct staging-only run then passed.
- Verified by local frontend build, remote Docker readiness, hosted deploy, remote compose proof, hosted browser contract, and `scripts\verify-phase5-frontend-source-build-path.ps1 -BaseUrl https://188-34-191-140.sslip.io -KeyPath C:\Users\immer\.ssh\oracle_key`.
- Progress change: Overall remains `71%`; Phase 5 rises to `68%`; Frontend rises to `99%`. No production rollout, GHCR push, Vercel promotion, live provider call, live MCP write, or immutable candidate parity is claimed.

Previous latest completed proof:

Phase 5 Active Candidate Gate Rerun:

- `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-candidate-gate-rerun.md` records one active-RC gate rerun against `https://188-34-191-140.sslip.io`, binding current-release-candidate config, active candidate artifact, active release-candidate bundle, Vercel Git link readiness, and project Git readiness.
- `scripts/verify-phase5-active-candidate-gate-rerun.ps1` re-checks the proof, parses `scripts\verify-active-release-candidate-bundle.ps1 -ReportOnly -JsonOnly`, and then reruns `scripts\verify-current-release-candidate.ps1`.
- The rerun asserts `bundle_status=passed`, `bundle_gate_count=3`, `active_release_id=prod-candidate-2026-05-11-rc1`, `production_rollout_claimed=false`, and policy flags for production mutation, deploy, rollout claim, and secret inclusion all remain false.
- This is an active release-candidate verification proof only; it does not claim production rollout, production deploy, live provider use, or secret disclosure.
- Progress change: Overall remains `70%`; Phase 5 remains `67%`.

Previous latest completed proof:

Phase 5 Integration Smoke Plan Rerun:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-smoke-plan-rerun.md` records one fresh candidate-scoped hosted smoke-plan rerun on the active truth `overall=70`, `phase_5=67`, with hosted root/API/MCP/LLM `200`, hosted progress/integrity, fail-closed completion, external gates `verified`, external-gates mirror visibility, and deployment-preflight `verified`.
- `scripts/verify-phase5-integration-smoke-plan-rerun.ps1` re-checks that artifact, the active candidate link, the hosted HTML title `Cloud Superbrain`, the hosted API surface set, and the current manifest-backed hosted truth.
- The rerun preserves `IMAGE_TAG=staging` as the current selector and `IMAGE_TAG=ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5` as the immutable rollback selector.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-staging-parity-blocked.md` and `scripts/verify-phase5-staging-parity-blocked.ps1` now keep the resulting digest-parity blocker explicit: the mutable `:staging` tag set currently does not equal the immutable candidate SHA tag set, so hosted parity is not claimed.
- Verified by `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-integration-smoke-plan-rerun.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`, and Hetzner re-sync.
- Progress change: Overall remains `70%`; Phase 5 rises to `67%`. This is not a rollout or production deployment claim.

Previous latest completed proof:

Phase 5 Executed Rollback + Post-Rollback Requalification + Release Readiness Rerun:

- `.phase1-artifacts/phase5-executed-rollback-rerun-20260507.md` records one fresh rerun of the existing executed rollback lane on the active hosted truth `overall=70`, `phase_5=66`, confirms the immutable selector `ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`, and re-checks the restored hosted selector `IMAGE_TAG=staging`.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-requalification-rerun.md` records one fresh rerun of the post-rollback requalification lane on the same hosted truth and reconfirms hosted root/API/MCP/LLM `200`, fail-closed completion, and external gates `verified`.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-release-readiness-rerun.md` records one fresh candidate-scoped release-readiness rerun against the same hosted truth, active runbooks, active candidate links, and the active browser-evidence chain.
- `.phase1-artifacts/phase5-owner-decision-no-release-20260505.md`, `.phase1-artifacts/phase5-rollback-readiness-20260505.md`, and `.phase1-artifacts/phase5-release-baseline-refresh-20260507.md` were corrected in the same batch so the active candidate no longer depends on stale `50/8` and `67/40` truth fragments.
- Verified by `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-executed-rollback-rerun.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-post-rollback-requalification-rerun.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-release-readiness-rerun.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-release-baseline-refresh.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`, and Hetzner re-sync.
- Progress change: Overall remains `70%`; Phase 5 rises to `66%`. This is not a rollout or production deployment claim.

Previous latest completed proof:

Phase 5 Final Browser E2E + Full Verifier Sweep + Truth Mirror Rebaseline:

- `.phase1-artifacts/phase5-final-browser-e2e-recheck-20260507.md` records one fresh local-plus-hosted AI-browser rerun on the active candidate truth `overall=70`, `phase_5=63`, with visible markers `Cloud Superbrain`, `Project Progress`, `External Gates`, `Phase 5 - Release Readiness`, `Progress Integrity`, `Error Response Contract`, and `System Unavailable Fallback`.
- `.phase1-artifacts/phase5-full-verifier-sweep-20260507.md` records one complete green end-to-end verifier chain: `py -3 scripts\verify_project_progress_manifest.py`, the full `verify-phase5*.ps1` sweep, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`, and `gitleaks`.
- `.phase1-artifacts/phase5-truth-mirror-rebaseline-20260507.md` records the current mirror rebaseline across `docs/project-progress.manifest.json`, `docs/verification-register.md`, `PROJECT_STATE.md`, `AI_HANDOFF.md`, and `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md`.
- Verified by `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-final-browser-e2e-recheck.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-full-verifier-sweep.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-truth-mirror-rebaseline.ps1 -BaseUrl https://188-34-191-140.sslip.io`, the full `verify-phase5*.ps1` sweep, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`, and Hetzner re-sync.
- Progress rises repo-honestly: Overall is now `70%` and Phase 5 is now `63%`. This is a verification/mirror-closure batch, not a rollout or production deployment claim.

Previous latest completed proof:

Phase 5 Browser Claims Fail-Closed Repair:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md` and `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-browser-revalidation.md` are now explicitly historical `superseded` artifacts, not current candidate evidence.
- `scripts/verify-phase5-browser-proof.ps1` and `scripts/verify-phase5-post-rollback-browser-revalidation.ps1` now verify the fail-closed blocked state instead of carrying non-reproducible current browser claims.
- `scripts/verify-phase5-candidate.ps1` and `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` no longer link the two browser artifacts as active candidate evidence; the current blocker is documented directly in the candidate artifact.
- Hard blocker evidence is explicit: `node_repl` + `iab` fails with `failed to start codex app-server ... (os error 3)`, `chrome_devtools` fails with `Target.setDiscoverTargets): Target closed`, and Playwright closes with launcher `exit code 13`.
- Progress change: Overall remains `69%`; Phase 5 is corrected fail-closed to `57%`. This removes two stale current claims and still does not create a rollout or production deployment claim.

Previous latest completed proof:

Phase 5 Post-Rollback Provenance + Incident + Rollback Drill Rerun:

- `scripts/verify-phase5-post-rollback-provenance-revalidation.ps1` now rebinds the legacy post-rollback provenance artifact to current hosted `overall=69`, hosted `phase_5=57`, workflow run `25392582005`, immutable GHCR SHA `ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`, and hosted root/API/MCP/LLM health.
- `scripts/verify-phase5-incident-drill.ps1` now validates deployment preflight through the runtime endpoint `GET /api/v1/clouds/deployment-preflight`, binds the drill to current hosted `overall=69`, hosted `phase_5=57`, and replaces the obsolete rollback selector `5464c922...` with the current immutable SHA `ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`.
- `scripts/verify-phase5-rollback-drill.ps1` now validates the rollback drill against GitHub Actions run `25392582005` and the immutable rollback SHA `ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5` through the GitHub API instead of the stale old run/SHA pair.
- `scripts/verify-phase5-candidate.ps1` now derives the expected rollback-drill SHA and workflow run directly from the candidate artifact, so the candidate verifier no longer conserves the obsolete rollback pin.
- `scripts/verify-phase5-integration-plan.ps1` and `docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-plan.md` were updated in the same batch so the legacy integration plan also uses runtime deployment preflight and the current immutable rollback selector.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-post-rollback-provenance-revalidation.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-incident-drill.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-rollback-drill.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-integration-plan.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall remains `69%`; Phase 5 had previously risen to `59%`, but current manifest-backed truth is now `57%` after the browser claims were removed fail-closed. This is still not a rollout or production deployment.

Phase 5 Risk + Observability + Smoke Rerun:

- `scripts/verify-phase5-risk-review.ps1` now reads expected hosted progress from the canonical manifest instead of the stale `53/18` pin and re-checks `owner_decision=no-release`, hosted progress/integrity, fail-closed completion truth, external gates, and hosted audit/escalation visibility.
- `scripts/verify-phase5-observability-review.ps1` now reads expected hosted progress from the canonical manifest instead of the stale `52/11` pin and re-checks hosted health, progress, integrity, metrics, audit feed, escalation feed, and external gates.
- `scripts/verify-phase5-executed-smoke.ps1` now binds the smoke proof to current hosted `overall=69`, hosted `phase_4=100`, hosted `phase_5=56` and fixes the real contract-vs-runtime check by validating deployment preflight through `GET /api/v1/clouds/deployment-preflight` instead of the contract endpoint.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-risk-review.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-observability-review.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-executed-smoke.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall rises to `69%`; Phase 5 rises to `56%`. This is still not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Project Progress + Layer Progress Contract Runtime Parity:

- `scripts/verify-phase4-project-progress-contract-runtime-hosted.ps1` now binds `GET /api/v1/project/progress/contract` directly to the visible hosted runtime at `GET /api/v1/project/progress` plus `GET /api/v1/project/progress/integrity` and proves the canonical manifest-backed top-level fields, phase count, layer count, binding document, and non-empty runtime status strings on the live Hetzner stack.
- `scripts/verify-phase4-project-progress-layers-contract-runtime-hosted.ps1` now binds `GET /api/v1/project/progress/layers/contract` directly to the new hosted layer-only projection at `GET /api/v1/project/progress/layers` and proves the seven layer ids, label parity, count parity, overall-percent parity, and runtime alignment with the canonical progress feed.
- `.phase1-artifacts/phase4-project-progress-contract-runtime-hosted-proof-20260507.md` and `.phase1-artifacts/phase4-project-progress-layers-contract-runtime-hosted-proof-20260507.md` record the successful hosted proofs.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-project-progress-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-project-progress-layers-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall remains `63%`; Phase 4 rises to `86%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Task Assignment + Agent LLM Streaming Contract Runtime Parity:

- `scripts/verify-phase4-task-assignment-contract-runtime-hosted.ps1` now binds `GET /api/v1/tasks/assignment-contract` to a fresh hosted internal task over `POST /api/v1/internal/tasks` and proves the same task through `GET /api/v1/internal/tasks/{task_id}`, `GET /api/v1/tasks/recent`, `GET /api/v1/agents/status`, and `GET /api/v1/metrics`.
- `scripts/verify-phase4-agent-llm-streaming-contract-runtime-hosted.ps1` now binds `GET /api/v1/agents/llm-streaming-contract` to the live hosted LLM SSE contract at `GET /llm/api/v1/streaming/contract` and to a real hosted orchestrator dry-run with visible `llm_gateway_calls[]`, `stream_done_seen=true`, `stream_chunk_count>=1`, `routing_policy_decision=allow_primary`, `live_provider_calls=false`, and matching trace visibility in hosted agent activity and audit feeds.
- `.phase1-artifacts/phase4-task-assignment-contract-runtime-hosted-proof-20260507.md` and `.phase1-artifacts/phase4-agent-llm-streaming-contract-runtime-hosted-proof-20260507.md` record the successful hosted proofs.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-task-assignment-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-agent-llm-streaming-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall remains `62%`; Phase 4 rises to `82%`; Agent Pool rises to `68%`; LLM Gateway rises to `54%`. This is a hosted integration proof, not a rollout or production deployment.

Phase 4 Hosted Health Contract Runtime Parity:

- `services/agent-api/app/main.py` now exposes `GET /api/v1/health/contract` via `health_contract_payload()`, so the public health runtime surface now has its own visible contract instead of being covered only indirectly through fallback, budget, and external-gate proofs.
- the new visible health contract declares `contract_version=health-surface-v1`, the required top-level runtime fields, the required service keys, the embedded budget and infra-budget field sets, the embedded external-gates field set, and the currently supported health and gate statuses.
- `scripts/verify-phase4-health-contract-runtime-hosted.ps1` proves the hosted contract against `GET /api/v1/health` on the live Hetzner runtime and binds the visible contract to the real hosted values.
- `.phase1-artifacts/phase4-health-contract-runtime-hosted-proof-20260507.md` records the successful hosted proof.
- Verified commands: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-health-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall remains `61%`; Phase 4 rises to `72%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Costs Contract Runtime Parity:

- `services/agent-api/app/main.py` now exposes `GET /api/v1/costs/contract` via `costs_contract_payload()`, so the public costs runtime surface now has its own visible contract instead of being covered only indirectly through budget, metrics, and export proofs.
- the new visible costs contract declares `contract_version=costs-surface-v1`, the required top-level runtime fields, the required `breakdown[]` fields, the supported budget levels, and the runtime budget limit binding.
- `scripts/verify-phase4-costs-contract-runtime-hosted.ps1` proves the hosted contract against `GET /api/v1/costs` on the live Hetzner runtime and binds the visible contract to the real hosted runtime values.
- `.phase1-artifacts/phase4-costs-contract-runtime-hosted-proof-20260507.md` records the successful hosted proof.
- Verified commands: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-costs-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall remains `61%`; Phase 4 rises to `71%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Budget Contracts Runtime Parity:

- `services/agent-api/app/main.py` now exposes `GET /api/v1/budget/contract` via `budget_contract_payload()` and `GET /api/v1/infra/budget/contract` via `infra_budget_contract_payload()`, so both public budget surfaces now have their own visible runtime contracts instead of being covered only indirectly through metrics and older budget guard proofs.
- the new visible budget contracts declare `contract_version=budget-surface-v1` and `contract_version=infra-budget-surface-v1`, their required top-level runtime fields, supported levels, supported infra sources, and the required hosted `items[]` fields for the infra budget surface.
- `scripts/verify-phase4-budget-contracts-runtime-hosted.ps1` proves both hosted contracts against `GET /api/v1/budget`, `GET /api/v1/infra/budget`, `GET /api/v1/budget/contract`, and `GET /api/v1/infra/budget/contract` on the live Hetzner runtime and binds the visible contracts to the live hosted values including `source=hetzner_api_readonly`.
- `.phase1-artifacts/phase4-budget-contracts-runtime-hosted-proof-20260506.md` records the successful hosted proof.
- Verified commands: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-budget-contracts-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall rises to `61%`; Phase 4 rises to `70%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted MCP Audit Feed Contract Runtime Parity:

- `services/agent-api/app/main.py` now exposes `GET /api/v1/audit/mcp/contract` via `mcp_audit_feed_contract_payload()`, so the public MCP audit feed has its own visible contract instead of being covered only indirectly through the generic audit feed and MCP safe-envelope proofs.
- the new visible MCP-audit contract declares `contract_version=mcp-audit-feed-v1`, the top-level event fields, the required `mcp_tool_executed` detail fields, and the supported statuses `success|blocked|timeout|degraded`.
- `scripts/verify-phase4-mcp-audit-feed-contract-runtime-hosted.ps1` proves the hosted contract against `GET /api/v1/audit/mcp`, creates a real hosted `mcp_tool_executed` event through `POST /internal/audit/mcp-tool-events`, and binds the dedicated contract to the live MCP audit feed on the Hetzner runtime.
- `scripts/deploy-to-staging.ps1` was hardened in the same slice: remote hot-mount source directories are now reset before recursive copy so stale nested `app/app` trees cannot shadow newer runtime code on the host.
- `.phase1-artifacts/phase4-mcp-audit-feed-contract-runtime-hosted-proof-20260506.md` records the successful hosted proof.
- Verified commands: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-mcp-audit-feed-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall remains `60%`; Phase 4 rises to `68%`; MCP Gateway rises to `55%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Session History Contract Runtime Parity:

- `services/agent-api/app/main.py` now exposes `GET /api/v1/sessions/history/contract` via `session_history_contract_payload()`, so the public session-history runtime surface has its own visible contract instead of being covered only indirectly through stream/history proofs.
- `scripts/verify-phase4-session-history-contract-runtime-hosted.ps1` proves the hosted session-history contract against the real runtime by creating one real hosted prompt session through `POST /api/v1/prompt`, waiting for completion, then reading `GET /api/v1/sessions/history/contract`, `GET /api/v1/sessions/{session_id}/history`, `GET /api/v1/sessions/recent`, `GET /api/v1/tasks/recent`, `GET /api/v1/agent-activity/recent`, and `GET /api/v1/audit/recent`.
- the proof confirms that the dedicated session-history contract and the real hosted session-history feed stay aligned on top-level sections, session fields, task fields, audit-event fields, and request/trace/correlation/audit-feed visibility.
- `.phase1-artifacts/phase4-session-history-contract-runtime-hosted-proof-20260506.md` records the successful hosted proof for session-history-contract runtime parity.
- Verified commands: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-session-history-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall remains `59%`; Phase 4 rises to `57%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Recent Sessions Contract Runtime Parity:

- `services/agent-api/app/main.py` now exposes `GET /api/v1/sessions/recent/contract` via `recent_sessions_contract_payload()`, so the public recent-sessions runtime surface has its own visible contract instead of being covered only indirectly through session-stream, failure-history, and cross-surface runtime proofs.
- `scripts/verify-phase4-recent-sessions-contract-runtime-hosted.ps1` proves the hosted recent-sessions contract against the real runtime by creating one real hosted prompt session through `POST /api/v1/prompt`, waiting for completion, then reading `GET /api/v1/sessions/recent/contract`, `GET /api/v1/sessions/recent`, `GET /api/v1/sessions/{session_id}/history`, `GET /api/v1/tasks/recent`, `GET /api/v1/agent-activity/recent`, and `GET /api/v1/audit/recent`.
- the proof confirms that the dedicated recent-sessions contract and the real hosted recent-sessions feed stay aligned on top-level session fields, supported status coverage, latest-task failure metadata, and request/trace/correlation/audit-feed visibility.
- `.phase1-artifacts/phase4-recent-sessions-contract-runtime-hosted-proof-20260506.md` records the successful hosted proof for recent-sessions-contract runtime parity.
- Verified commands: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-recent-sessions-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall rises to `59%`; Phase 4 rises to `56%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Recent Tasks Contract Runtime Parity:

- `services/agent-api/app/main.py` now exposes `GET /api/v1/tasks/recent/contract` via `recent_tasks_contract_payload()`, so the public recent-tasks runtime surface has its own visible contract instead of being covered only indirectly through worker-priority and cross-surface runtime proofs.
- the same runtime patch also closes a real correlation gap: `POST /api/v1/internal/tasks` now writes trace/request/correlation metadata into `agent_sessions`, and `GET /api/v1/tasks/recent` now falls back to session projection when fresh audit correlation for the task itself is not available yet.
- `scripts/verify-phase4-recent-tasks-contract-runtime-hosted.ps1` proves the hosted recent-tasks contract against the real runtime by creating one real hosted `planner` task through `POST /api/v1/internal/tasks`, waiting for completion, then reading `GET /api/v1/tasks/recent/contract`, `GET /api/v1/tasks/recent`, `GET /api/v1/internal/tasks/{task_id}`, and `GET /api/v1/audit/recent`.
- the proof confirms that the dedicated recent-tasks contract and the real hosted recent-tasks feed stay aligned on top-level task fields, queue fields, status coverage, trace visibility, and task policy metadata.
- `.phase1-artifacts/phase4-recent-tasks-contract-runtime-hosted-proof-20260506.md` records the successful hosted proof for recent-tasks-contract runtime parity.
- Verified commands: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-recent-tasks-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall remains `58%`; Phase 4 rises to `55%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Escalation Contract Runtime Parity:

- `services/agent-api/app/main.py` now exposes `GET /api/v1/escalations/contract` via `escalation_contract_payload()`, so the public escalation runtime surface has its own visible contract instead of being covered only indirectly through request and audit parity.
- `scripts/verify-phase4-escalation-contract-runtime-hosted.ps1` proves the hosted escalation contract against the real runtime by seeding one escalated `coder` path with shared `request_id`, `trace_id`, `correlation_evidence_ref=request_id_audit_correlation`, and `audit_feed_evidence_ref=request_id_audit_feed_visible`, then reading `GET /api/v1/escalations/contract`, `GET /api/v1/escalations/recent`, and `GET /api/v1/audit/recent`.
- the proof confirms that the dedicated escalation contract and the real hosted escalation feed stay aligned on top-level fields plus request/trace/correlation/audit-feed evidence.
- `.phase1-artifacts/phase4-escalation-contract-runtime-hosted-proof-20260506.md` records the successful hosted proof for escalation-contract runtime parity.
- Verified commands: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-escalation-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall remains `58%`; Phase 4 rises to `54%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Request Contract Negative-State Parity:

- `services/agent-api/app/main.py` now extends the request contract registry with explicit `supported_statuses`, so each public runtime surface declares whether it carries `escalated`, `abandoned_after_queue_drain`, or both negative worker end states.
- `scripts/verify-phase4-request-contract-negative-state-parity-hosted.ps1` proves the hosted request contract against the real runtime by seeding one escalated `coder` path and one `abandoned_after_queue_drain` `tester` path with shared `request_id`, `trace_id`, `correlation_evidence_ref=request_id_audit_correlation`, and `audit_feed_evidence_ref=request_id_audit_feed_visible`, then reading `GET /api/v1/request/contract`.
- the proof re-checks `/api/v1/agents/status`, `/api/v1/agent-activity/recent`, `/api/v1/tasks/recent`, `/api/v1/sessions/recent`, `/api/v1/sessions/{session_id}/history`, `/api/v1/audit/recent`, and `/api/v1/escalations/recent` on the live Hetzner staging stack and confirms the declared `supported_statuses` plus the registered request/trace/correlation/audit-feed fields stay aligned on the real runtime surfaces.
- `.phase1-artifacts/phase4-request-contract-negative-state-parity-hosted-proof-20260506.md` records the successful hosted proof for request-contract negative-state parity.
- Verified commands: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-request-contract-negative-state-parity-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall remains `58%`; Phase 4 rises to `53%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Request Contract Runtime Parity:

- `scripts/verify-phase4-request-contract-runtime-parity-hosted.ps1` proves the hosted request contract against the real runtime by seeding one escalated `coder` path with shared `request_id`, `trace_id`, `correlation_evidence_ref=request_id_audit_correlation`, and `audit_feed_evidence_ref=request_id_audit_feed_visible`, then reading `GET /api/v1/request/contract` and using its `public_surface_registry` as the binding source of field names.
- the proof re-checks `/api/v1/agents/status`, `/api/v1/agent-activity/recent`, `/api/v1/tasks/recent`, `/api/v1/sessions/recent`, `/api/v1/sessions/{session_id}/history`, `/api/v1/audit/recent`, and `/api/v1/escalations/recent` on the live Hetzner staging stack and confirms the registered request/trace/correlation/audit-feed fields are present and value-aligned on the real runtime surfaces.
- `.phase1-artifacts/phase4-request-contract-runtime-parity-hosted-proof-20260506.md` records the successful hosted proof for request-contract-to-runtime parity.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-request-contract-runtime-parity-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`
- Progress change: Overall remains `58%`; Phase 4 rises to `52%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Request Contract Surface Registry Parity:

- `services/agent-api/app/main.py` now extends `request_id_contract_payload()` with a visible `public_surface_registry` that enumerates the public runtime surfaces carrying top-level request, trace, correlation, and audit-feed evidence fields.
- `scripts/verify-phase4-request-contract-surface-registry-hosted.ps1` proves the hosted request contract surface end to end by checking `GET /api/v1/request/contract` on the live Hetzner staging stack and confirming that all seven public runtime surfaces are explicitly registered with their request/trace/correlation/audit-feed fields.
- `.phase1-artifacts/phase4-request-contract-surface-registry-hosted-proof-20260506.md` records the successful hosted proof for request-contract surface-registry parity.
- Verified commands: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-request-contract-surface-registry-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`
- Progress change: Overall remains `58%`; Phase 4 rises to `51%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Dual-Path Audit Feed Parity:

- `scripts/verify-phase4-dual-path-audit-feed-parity-hosted.ps1` proves the hosted public audit-feed parity surface end to end by seeding one escalated `coder` path and one `abandoned_after_queue_drain` `tester` path with a shared `trace_id`, shared `request_id`, `correlation_evidence_ref=request_id_audit_correlation`, and `audit_feed_evidence_ref=request_id_audit_feed_visible`, then re-checking `GET /api/v1/agents/status`, `GET /api/v1/agent-activity/recent`, `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent`, `GET /api/v1/sessions/{session_id}/history`, and `GET /api/v1/audit/recent` for both paths plus `GET /api/v1/escalations/recent` for the escalated path.
- the proof confirms that both negative worker paths now keep top-level request-/trace-correlation and `audit_feed_evidence_ref` aligned across all relevant hosted public surfaces.
- `.phase1-artifacts/phase4-dual-path-audit-feed-parity-hosted-proof-20260506.md` records the successful hosted proof for dual-path audit-feed parity.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-dual-path-audit-feed-parity-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`
- Progress change: Overall remains `58%`; Phase 4 rises to `50%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Audit Feed Evidence Cross-Surface Parity:

- `scripts/verify-phase4-audit-feed-evidence-cross-surface-hosted.ps1` proves the hosted public audit-feed evidence surface end to end by seeding one escalated `coder` path with a shared `trace_id`, shared `request_id`, `correlation_evidence_ref=request_id_audit_correlation`, and `audit_feed_evidence_ref=request_id_audit_feed_visible`, then re-checking `GET /api/v1/escalations/recent`, `GET /api/v1/agents/status`, `GET /api/v1/agent-activity/recent`, `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent`, `GET /api/v1/sessions/{session_id}/history`, and `GET /api/v1/audit/recent`.
- the proof confirms that top-level request-/trace-correlation and `audit_feed_evidence_ref` now stay aligned across all seven hosted public surfaces for the escalated worker path.
- `.phase1-artifacts/phase4-audit-feed-evidence-cross-surface-hosted-proof-20260506.md` records the successful hosted proof for audit-feed-evidence cross-surface parity.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-audit-feed-evidence-cross-surface-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`
- Progress change: Overall rises to `58%`; Phase 4 rises to `49%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Escalation Request Correlation Parity:

- `services/agent-api/app/main.py` now projects top-level request-/trace-correlation onto `GET /api/v1/escalations/recent` via `request_id`, `trace_id`, `correlation_evidence_ref`, and `audit_feed_evidence_ref`.
- `scripts/verify-phase4-escalation-request-correlation-hosted.ps1` proves the hosted public escalation surface end to end by seeding one escalated `coder` path with a shared `trace_id`, shared `request_id`, and explicit `correlation_evidence_ref=request_id_audit_correlation`, then re-checking `GET /api/v1/escalations/recent`, `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent`, `GET /api/v1/sessions/{session_id}/history`, and `GET /api/v1/audit/recent`.
- the proof confirms that top-level request-/trace-correlation now stays aligned on the hosted escalation surface with the already correlated task/session/audit surfaces for the escalated worker path.
- `.phase1-artifacts/phase4-escalation-request-correlation-hosted-proof-20260506.md` records the successful hosted proof for escalation request correlation parity.
- Verified commands: `py -3 -m py_compile services/agent-api/app/main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-escalation-request-correlation-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall remains `57%`; Phase 4 rises to `48%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Agent Status Request Correlation Parity:

- `services/agent-api/app/main.py` now projects top-level request-/trace-correlation onto `GET /api/v1/agents/status` via `latest_trace_id`, `latest_request_id`, `latest_correlation_evidence_ref`, and `latest_audit_feed_evidence_ref`.
- `scripts/verify-phase4-agent-status-request-correlation-hosted.ps1` proves the hosted public agent-status surface end to end by seeding one escalated `coder` path and one `abandoned_after_queue_drain` `tester` path with a shared `trace_id`, shared `request_id`, and explicit `correlation_evidence_ref=request_id_audit_correlation`, then re-checking `GET /api/v1/agents/status`, `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent`, `GET /api/v1/sessions/{session_id}/history`, and `GET /api/v1/audit/recent`.
- the proof confirms that top-level request-/trace-correlation now stays aligned on the hosted agent-status surface with the already correlated task/session/audit surfaces for both negative worker paths.
- `.phase1-artifacts/phase4-agent-status-request-correlation-hosted-proof-20260506.md` records the successful hosted proof for agent-status request correlation parity.
- Verified commands: `py -3 -m py_compile services/agent-api/app/main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-agent-status-request-correlation-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall remains `57%`; Phase 4 rises to `47%`; Agent Pool rises to `66%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Request Correlation Cross-Surface Parity:

- `services/agent-api/app/main.py` now projects top-level `trace_id`, `request_id`, and `correlation_evidence_ref` from the hosted audit trail onto `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent`, `GET /api/v1/sessions/{session_id}/history`, and `GET /api/v1/agent-activity/recent`.
- `scripts/verify-phase4-request-correlation-cross-surface-hosted.ps1` proves the hosted public correlation surfaces end to end by seeding one escalated `coder` path and one `abandoned_after_queue_drain` `tester` path with a shared `trace_id`, shared `request_id`, and explicit `correlation_evidence_ref=request_id_audit_correlation`, then re-checking `GET /api/v1/agent-activity/recent?trace_id=...`, `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent`, `GET /api/v1/sessions/{session_id}/history`, and `GET /api/v1/audit/recent`.
- the proof confirms that top-level `trace_id`, `request_id`, and `correlation_evidence_ref` stay aligned across all five hosted public surfaces for both negative worker paths.
- `.phase1-artifacts/phase4-request-correlation-cross-surface-hosted-proof-20260506.md` records the successful hosted proof for cross-surface request correlation parity.
- Verified commands: `py -3 -m py_compile services/agent-api/app/main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-request-correlation-cross-surface-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall remains `57%`; Phase 4 rises to `46%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Agent Activity Filter Parity:

- `scripts/verify-phase4-agent-activity-filter-parity-hosted.ps1` now proves the hosted public filter surface end to end by seeding one escalated `coder` path and one `abandoned_after_queue_drain` `tester` path with a shared `trace_id`, then re-checking `GET /api/v1/agent-activity/recent?trace_id=...` plus the narrower `agent_type`, `event_type`, and `severity` combinations for each path, and finally mirroring the results against `GET /api/v1/audit/recent`.
- the proof confirms that the filtered agent-activity feed isolates exactly the intended failure event and keeps `task_id`, `trace_id`, and retry metadata aligned with the public audit feed.
- `.phase1-artifacts/phase4-agent-activity-filter-parity-hosted-proof-20260506.md` records the successful hosted proof for filter parity on the public agent-activity surface.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-agent-activity-filter-parity-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `57%`; Phase 4 rises to `45%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Trace + Request Correlation Parity:

- `scripts/verify-phase4-trace-request-correlation-hosted.ps1` now proves the hosted public correlation surfaces end to end by seeding one escalated `coder` path and one `abandoned_after_queue_drain` `tester` path with a shared `trace_id`, a shared `request_id`, and explicit `correlation_evidence_ref=request_id_audit_correlation`, then re-checking `GET /api/v1/agent-activity/recent?trace_id=...`, `GET /api/v1/audit/recent`, `GET /api/v1/sessions/{session_id}/history`, and `GET /api/v1/request/contract` for the same ids and evidence refs.
- the proof confirms that `trace_id`, `request_id`, `request_id_audit_correlation`, and `request_id_audit_feed_visible` stay aligned between the hosted agent-activity feed, hosted audit feed, and hosted session-history audit events for both negative worker paths.
- `.phase1-artifacts/phase4-trace-request-correlation-hosted-proof-20260506.md` records the successful hosted proof for trace/request correlation parity.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-trace-request-correlation-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `57%`; Phase 4 rises to `44%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Failure Audit + Escalation Parity:

- `scripts/verify-phase4-failure-audit-escalation-parity-hosted.ps1` now proves the hosted public audit and escalation surfaces end to end by seeding one escalated `coder` path and one `abandoned_after_queue_drain` `tester` path on the real Hetzner staging stack, then re-checking `GET /api/v1/audit/recent`, `GET /api/v1/escalations/recent`, and `GET /api/v1/sessions/{session_id}/history` for the same ids and failure fields.
- the verifier was corrected to the real feed contracts: both feeds expose `events`, `trace_id` on the escalation feed lives inside `details`, and `escalations/recent` intentionally includes the escalated path rather than the queue-drain abandonment path.
- `.phase1-artifacts/phase4-failure-audit-escalation-hosted-proof-20260506.md` records the successful hosted proof for audit/escalation/history parity of the negative worker end states.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-failure-audit-escalation-parity-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `57%`; Phase 4 rises to `43%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Agent Status Cross-Surface Parity:

- `scripts/verify-phase4-agent-status-cross-surface-hosted.ps1` now proves the hosted public agent-status surface end to end by seeding one escalated `coder` path and one `abandoned_after_queue_drain` `tester` path on the real Hetzner staging stack, then re-checking `GET /api/v1/agents/status`, `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent`, and `GET /api/v1/sessions/{session_id}/history` for the same ids and failure fields.
- no runtime code change was required for this slice; the proof closes the hosted parity gap between the already-existing public surfaces.
- `.phase1-artifacts/phase4-agent-status-cross-surface-hosted-proof-20260506.md` records the successful hosted proof for cross-surface parity of `escalated` and `abandoned_after_queue_drain` from the `agents/status` perspective.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-agent-status-cross-surface-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall rises to `57%`; Phase 4 rises to `42%`; Agent Pool rises to `65%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Failure Cross-Surface Parity:

- `scripts/verify-phase4-failure-cross-surface-hosted.ps1` now proves the hosted public failure surface end to end by seeding one escalated `coder` path and one `abandoned_after_queue_drain` `tester` path on the real Hetzner staging stack, then re-checking `GET /api/v1/agent-activity/recent`, `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent`, and `GET /api/v1/sessions/{session_id}/history` for the same ids and failure fields.
- the verifier itself had a real seed-parser defect and now parses only the final remote JSON line before building the hosted `trace_id` filter URL; no runtime surface change was required for this slice.
- `.phase1-artifacts/phase4-failure-cross-surface-hosted-proof-20260505.md` records the successful hosted proof for cross-surface parity of `escalated` and `abandoned_after_queue_drain`.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-failure-cross-surface-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `56%`; Phase 4 rises to `41%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Agent Activity Contract Parity:

- `services/agent-api/app/main.py` now declares `task_id`, `task_status`, `retry_count`, `max_retries`, and `error` in `agent_activity_contract_payload()`, and adds explicit contract markers `failure_surface_visible` plus `agent_activity_failure_surface_visible`.
- `scripts/verify-phase4-agent-activity-contract-hosted.ps1` proves the hosted public contract/runtime surface end to end by checking `GET /api/v1/agent-activity/contract`, seeding one escalated `coder` audit path and one `abandoned_after_queue_drain` `tester` audit path on the real Hetzner staging stack, then re-checking `GET /api/v1/agent-activity/recent?trace_id=...`.
- `.phase1-artifacts/phase4-agent-activity-contract-hosted-proof-20260505.md` records the successful hosted proof for public contract/runtime parity of the surfaced failure fields on the same task ids.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-agent-activity-contract-hosted.ps1`, `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `56%`; Phase 4 rises to `40%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Worker Failure / Stale Queue Parity:

- `scripts/verify-phase4-worker-failure-parity-hosted.ps1` now proves the hosted worker failure path end to end by seeding real Hetzner Redis/Postgres state for one escalating task with a missing session, one stale queued rehydrate path with a completed audit, and one stale queued abandon path without queue membership; it then re-checks `GET /api/v1/internal/tasks/{task_id}`, `GET /api/v1/tasks/recent`, `GET /api/v1/audit/recent`, `GET /api/v1/escalations/recent`, `GET /api/v1/metrics`, and `GET /api/v1/health`.
- `.phase1-artifacts/phase4-worker-failure-parity-hosted-proof-20260505.md` records the successful hosted proof for `task_retry`, `task_failed`, `task_escalated`, `task_status_rehydrated_from_audit`, and `task_abandoned_after_queue_drain` parity on the real staging stack.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-worker-failure-parity-hosted.ps1`, `py -3 -m py_compile services\agent-api\app\main.py`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall rises to `56%`; Phase 4 rises to `35%`; Agent Pool rises to `63%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Orchestrator Stream / Checkpoint Replay Parity:

## Previous Latest Completed Proof

Phase 4 Hosted Session History / SSE Replay Parity:

- `scripts/verify-phase4-session-stream-history-hosted.ps1` now proves the hosted session history and stream path end to end through `POST /api/v1/prompt`, `GET /api/v1/sessions/{session_id}/history`, `GET /api/v1/session/{session_id}/stream`, replay against the same stream with `Last-Event-ID: 0`, `GET /api/v1/sessions/recent`, and `GET /api/v1/audit/recent`.
- `.phase1-artifacts/phase4-session-stream-history-hosted-proof-20260505.md` records the successful hosted proof for session visibility, session history, live SSE, replay SSE, and audit parity.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-session-stream-history-hosted.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `55%`; Phase 4 rises to `33%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Session / Memory Worker Runtime Parity:

- `scripts/verify-phase4-session-memory-parity-hosted.ps1` now proves the hosted session and memory-worker runtime path end to end through `POST /api/v1/prompt`, `GET /api/v1/sessions/{session_id}/history`, `GET /api/v1/sessions/recent`, a real SSH-seeded hosted `memory:working:*` key plus `memory-worker --once`, `GET /api/v1/memory/search`, `GET /api/v1/memory/consolidation/recent`, and `GET /api/v1/metrics`.
- `.phase1-artifacts/phase4-session-memory-parity-hosted-proof-20260505.md` records the successful hosted proof for session visibility, session history, deterministic worker completion, Redis-to-Postgres memory consolidation, public memory search, consolidation audit, and metrics parity.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-session-memory-parity-hosted.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `55%`; Phase 4 rises to `32%`; Memory rises to `71%`. This is a hosted integration proof, not a rollout or production deployment.
## Previous Latest Completed Proof

Phase 4 Hosted Worker / Priority Queue Runtime Parity:

- `scripts/verify-phase4-worker-priority-runtime-hosted.ps1` now proves the hosted worker runtime path end to end through `GET /api/v1/tasks/assignment-contract`, `POST /api/v1/internal/tasks`, `GET /api/v1/internal/tasks/{task_id}`, `GET /api/v1/tasks/recent`, `GET /api/v1/agents/status`, `GET /api/v1/sessions/recent`, `GET /api/v1/metrics`, and `GET /api/v1/audit/recent`.
- `services/agent-api/app/main.py` now initializes `agent_sessions` before internal task enqueue and writes `latest_task_id/latest_task_type` metadata for the hosted internal-task path; this fixes the real `ForeignKeyViolation`/`status=escalated` bug previously triggered by hosted worker proof tasks.
- `.phase1-artifacts/phase4-worker-priority-queue-hosted-proof-20260505.md` records the successful hosted proof for high/mid/low task priorities, worker completion, session visibility, audit visibility, and metrics parity.
- Verified commands: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-worker-priority-runtime-hosted.ps1`
- Progress change: Overall remains `55%`; Phase 4 rises to `31%`; Agent Pool rises to `62%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 5 Post-Rollback Provenance + Completion Gate Freeze:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-provenance-revalidation.md` now binds the current production-candidate to a fresh post-rollback provenance revalidation across GitHub Actions run `25392582005`, immutable GHCR SHA tags for all six services, multi-arch `amd64/arm64` availability, and hosted root/API/MCP/LLM health at `overall=55`, `phase5=28`.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-completion-gate-freeze.md` now binds the same candidate to the still fail-closed completion boundary after rollback/restore: external gates remain `verified`, `blocked_release_gates=[]`, but `can_set_all_to_100=false` and `owner_decision=no-release` remain hard true.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now links both new post-rollback provenance and completion-gate-freeze artifacts directly beside the existing rollback/requalification evidence.
- `scripts/verify-phase5-post-rollback-provenance-revalidation.ps1` and `scripts/verify-phase5-post-rollback-completion-gate-freeze.ps1` verify the new artifacts fail-closed against live GitHub workflow truth, live GHCR manifests, and current hosted truth.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-post-rollback-provenance-revalidation.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-post-rollback-completion-gate-freeze.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `55%`; Phase 5 rises to `28%`. These are post-rollback release-readiness proofs, not a rollout or production deployment.

## Previous Latest Completed Proof

Historical, now superseded browser section - Phase 5 Post-Rollback Observability + Browser Revalidation:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-observability-revalidation.md` now binds the current production-candidate to a fresh hosted observability revalidation after rollback/restore, checking health, progress, integrity, metrics, audit, escalations, and external gates at `overall=55`, `phase5=26`.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-browser-revalidation.md` is now a historical `superseded` artifact only; fresh browser reruns are currently blocked and are not counted in current candidate evidence.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now links only the post-rollback observability artifact as active current evidence; the browser revalidation artifact is excluded from the current candidate truth.
- `scripts/verify-phase5-post-rollback-observability-revalidation.ps1` remains on current hosted truth, while `scripts/verify-phase5-post-rollback-browser-revalidation.ps1` now verifies the fail-closed blocked historical state.
- Blocker evidence is explicit: `failed to start codex app-server ... (os error 3)`, `Target.setDiscoverTargets): Target closed`, and Playwright launcher `exit code 13`.
- The progress line in this historical section is retained only as provenance and is not the current manifest-backed truth.

## Previous Completed Proof

Phase 5 Executed Candidate Risk Review:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-risk-review.md` now binds the current production-candidate to an executed risk and open-questions review.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now links the risk review directly as candidate evidence.
- `scripts/verify-phase5-risk-review.ps1` verifies the risk-review artifact fail-closed against the required decision state, hosted progress/integrity truth, completion guard, external-gate truth, and hosted audit/escalation visibility.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-risk-review.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `53%`; Phase 5 rises to `18%`. This is a release-readiness risk-review evidence step, not a rollout or production deployment.

## Previous Completed Proof

Phase 5 Executed Candidate Handoff Packet:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-handoff-packet.md` now binds the current production-candidate to an executed release-communication and operator-handoff packet.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now links the handoff packet directly as candidate evidence.
- `scripts/verify-phase5-handoff-packet.ps1` verifies the packet artifact fail-closed against the required packet files, current handoff/state/register mirrors, and hosted progress/integrity truth.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-handoff-packet.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `53%`; Phase 5 rises to `17%`. This is a release-readiness communication evidence step, not a rollout or production deployment.

## Previous Completed Proof

Phase 5 Executed Candidate Memory Recovery Drill:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-memory-recovery-drill.md` now binds the current production-candidate to an executed memory-recovery decision drill without any live restore claim.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now links the memory-recovery drill directly as candidate evidence.
- `scripts/verify-phase5-memory-recovery-drill.ps1` verifies the drill artifact fail-closed against the runbook links, explicit no-restore decision, hosted progress/integrity, memory embedding consistency, purge contract, purge-job status, consolidation feed, and audit feed.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-memory-recovery-drill.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `53%`; Phase 5 rises to `16%`. This is a release-readiness operations evidence step, not a rollout or production deployment.

## Previous Completed Proof

Phase 5 Executed Candidate Provider Failover Drill:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-provider-failover-drill.md` now binds the current production-candidate to an executed provider-failover decision drill without any live external provider switch.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now links the provider-failover drill directly as candidate evidence.
- `scripts/verify-phase5-provider-failover-drill.ps1` verifies the drill artifact fail-closed against the runbook links, explicit no-switch decision, hosted LLM/API health, hosted progress/integrity, external gates, deployment preflight, and audit feed.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-provider-failover-drill.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `53%`; Phase 5 rises to `15%`. This is a release-readiness operations evidence step, not a rollout or production deployment.

## Previous Completed Proof

Phase 5 Executed Candidate Secret Rotation Drill:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-secret-rotation-drill.md` now binds the current production-candidate to an executed candidate-scoped secret-rotation drill without storing any secret values in Git.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now links the secret-rotation drill directly as candidate evidence.
- `scripts/verify-phase5-secret-rotation-drill.ps1` verifies the drill artifact fail-closed against the runbook links, repo-storage prohibition, hosted health/progress/integrity surfaces, external gates, and deployment preflight.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-secret-rotation-drill.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `53%`; Phase 5 rises to `14%`. This is a release-readiness operations evidence step, not a rollout or production deployment.

## Previous Completed Proof

Historical, now superseded browser section - Phase 5 Executed Hosted Candidate Browser Proof:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md` is now a historical `superseded` artifact only; fresh browser reruns are currently blocked and are not counted in current candidate evidence.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` no longer links the browser proof as active candidate evidence.
- `scripts/verify-phase5-browser-proof.ps1` now verifies the fail-closed blocked historical state instead of a current browser-proof claim.
- Blocker evidence is explicit: `failed to start codex app-server ... (os error 3)`, `Target.setDiscoverTargets): Target closed`, and Playwright launcher `exit code 13`.
- Progress change: Overall remains `53%`; Phase 5 rises to `13%`. This is a release-readiness browser evidence step, not a rollout or production deployment.

## Previous Completed Proof

Phase 5 Candidate Observability Review Proof:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-observability-review.md` now binds the current production-candidate to an executed hosted observability review.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now links the observability review directly as candidate evidence.
- `scripts/verify-phase5-observability-review.ps1` verifies the observability-review artifact fail-closed against the hosted health, progress, integrity, metrics, audit, escalation, and external-gate surfaces.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-observability-review.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall rises to `53%`; Phase 5 rises to `12%`. This is a release-readiness observability evidence step, not a rollout or production deployment.

## Previous Completed Proof

Phase 5 Executed Candidate Incident Drill:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-incident-drill.md` now binds the current production-candidate to an executed incident/escalation drill for a simulated unhealthy candidate scenario.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now links the incident drill directly as candidate evidence.
- `scripts/verify-phase5-incident-drill.ps1` verifies the incident-drill artifact fail-closed against incident classification, evidence capture, rollback decision path, hosted health/integrity/metrics/audit/escalation surfaces, and the external gate / deployment preflight state.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-incident-drill.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-rollback-drill.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `52%`; Phase 5 rises to `11%`. This is a release-readiness operations evidence step, not a rollout or production deployment.

## Previous Completed Proof

Phase 5 Executed Hosted Candidate Smoke Proof:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-smoke-proof.md` now binds the current production-candidate to an executed hosted smoke run against the live Hetzner staging target.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now links the executed smoke proof directly as candidate evidence.
- `scripts/verify-phase5-executed-smoke.ps1` verifies the executed smoke artifact fail-closed against the hosted root title marker, the four hosted health paths, hosted progress/integrity/completion truth, and the external gate / deployment preflight contracts.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-executed-smoke.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-rollback-drill.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `52%`; Phase 5 rises to `10%`. This is a release-readiness evidence step, not a rollout or production deployment.

## Previous Completed Proof

Phase 5 Candidate Integration Plan Proof:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-plan.md` now binds the current production-candidate to an explicit hosted smoke sequence, expected outcomes, failure handling, evidence links, and non-claims.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now closes `Integration plan documented` and links the integration-plan artifact as candidate evidence.
- `scripts/verify-phase5-integration-plan.ps1` verifies the integration-plan artifact fail-closed against the required structure, hosted target, exact verifier links, and the candidate-artifact evidence line.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-integration-plan.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `52%`; Phase 5 rises to `9%`. This is a release-readiness evidence step, not a rollout or production deployment.

## Previous Completed Proof

Phase 5 Owner Decision + P3 Browser Proof Hardening:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now carries `owner_decision_proof`, `review_gate=reviewed`, and `owner_decision=no-release`.
- `.phase1-artifacts/phase5-owner-decision-no-release-20260505.md` documents the explicit no-release decision against the current `50%` overall state and preserves the production non-claim.
- `scripts/verify-phase5-candidate.ps1` now verifies the owner-decision artifact fail-closed instead of allowing a generic pending review state.
- `scripts/verify-browser-contract.ps1` now also asserts the already-shipped Product Surface & Security markers for `Auth Contract` and `System Unavailable Fallback`, so these contracts have a repeatable local browser proof in addition to the hosted verifier coverage.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `50%`; Phase 5 rises to `8%`. This is an owner decision plus verifier hardening step, not a production deployment.

## Previous Completed Proof

Phase 5 Candidate Pipeline + Rollback Drill Proof:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now binds the first concrete production-candidate artifact to the hosted staging runtime, external-gate closure, GHCR candidate tags, successful GitHub Actions run `25318349068`, source commit `5464c922f8871e4ff36e620ff53026fb1a2a05b3`, immutable rollback tag set, rollback runbook path, and the owner/review decision path.
- `.phase1-artifacts/phase5-rollback-readiness-20260505.md` remains the candidate-specific rollback-readiness proof, and `.phase1-artifacts/phase5-rollback-drill-prod-candidate-20260505-rc1.md` now captures the documented good-tag rollback drill with the hosted root, Agent API, MCP Gateway, and LLM Gateway as post-revert verification targets.
- `scripts/verify-phase5-candidate.ps1` and `scripts/verify-phase5-rollback-drill.ps1` verify the candidate fail-closed against the release artifact, rollback-readiness proof artifact, rollback-drill artifact, hosted endpoints, GHCR `staging` tags, GHCR commit tags, GitHub workflow run truth, and the hosted runtime truth endpoints.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-release-readiness.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-rollback-drill.ps1`, `gh run view 25318349068 --json conclusion,status,headSha,url,name`, `docker manifest inspect ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:staging` for all six services, `docker manifest inspect ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:5464c922f8871e4ff36e620ff53026fb1a2a05b3` for all six services, and hosted `GET /`, `GET /api/v1/health`, `GET /mcp/api/v1/health`, `GET /llm/api/v1/health`
- Progress change: Overall stays at `50%`; Phase 5 rises to `7%`. This is a verified production-candidate pipeline and immutable rollback-drill step, not a production deployment.

## Previous Completed Proof

Phase 5 Release Readiness Baseline Proof:

- `docs/release-checklist.md` now defines the active Phase-5 release-readiness baseline with four mandatory sections: `Code Readiness`, `Infrastructure Readiness`, `Observability Readiness`, and `Operations Readiness`; all checklist items are `JA/NEIN`, the Git artifact path is `docs/release-artifacts/<release_id>.md`, and explicit stop-gates plus non-claims are included.
- `docs/release-artifacts/README.md` and `docs/release-artifacts/TEMPLATE.md` now define the per-release Git artifact location and required candidate fields such as `release_id`, `pipeline_status`, `review_gate`, and `owner_decision`.
- `docs/runbooks/rollback-deploy.md`, `docs/runbooks/incident-response.md`, `docs/runbooks/secret-rotation.md`, `docs/runbooks/provider-failover.md`, and `docs/runbooks/memory-recovery.md` now provide the Phase-5 baseline runbooks with trigger, verification, escalation, and non-claims; `docs/runbooks/README.md` was promoted from Phase-0 draft to an active baseline index.
- `scripts/verify-phase5-release-readiness.ps1` verifies the release-checklist baseline fail-closed against the checklist, release-artifact template, runbooks, hosted browser proof artifact, and deploy workflow guard.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-release-readiness.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change at that milestone: none yet. The baseline alone did not raise progress until the concrete production-candidate artifact and candidate verifier were added.

## Previous Completed Proof

Hosted Runtime Truth Alignment Proof:

- Hosted URL: `<hosted-staging-url>`
- Runtime endpoints now aligned: `GET /api/v1/external-gates`, `GET /api/v1/external-gates/mirror`, `GET /api/v1/clouds/deployment-preflight/contract`, and `GET /api/v1/project/progress/completion`
- Result: Hosted `external-gates status=verified`, `verified_count=6`, `blocked_release_gates=[]`; hosted deployment preflight `status=verified`, `missing_or_blocked_gates=[]`, `cloud_deploy_claim_allowed=true`, `production_deploy_claim_allowed=true`; hosted mirror `status=verified`, `hosted_staging_claim_allowed=true`, `branch_protection_claim_allowed=true`
- Runtime correction: `services/agent-api/app/main.py` now derives cloud-gate verification from the binding progress manifest markers, so the hosted panels stop advertising stale blockers after the external gate audit is already closed.
- Verified commands: Python compile for `services\agent-api\app\main.py`, `scripts\deploy-to-staging.ps1`, `scripts\verify-cloud-only-staging.ps1 -BaseUrl <hosted-staging-url>`, `scripts\verify-external-gates.ps1 -HostedBaseUrl <hosted-staging-url> -LocalBaseUrl <local-control-plane-url>`, direct hosted API inspection of the three gate endpoints and the completion endpoint, and remote `docker compose --env-file .env -f docker-compose.cloud.yml up -d --force-recreate agent-api`.
- Progress change: Overall remains `49%`; Phase 4 rises to `24%`. This is runtime-truth alignment after real gate closure, not a production deployment.

## Previous Completed Proof

External Gate Audit Closure Proof:

- Hosted URL: `<hosted-staging-url>`
- Audit artifact: `.phase1-artifacts\external-gate-audit-20260504-212633.json`
- Result: `status=verified`, `frontend_preview_claim_allowed=True`, `hosted_staging_claim_allowed=True`, `production_deploy_claim_allowed=True`
- Closed gates: GHCR digest resolution, Hetzner live budget proof, hosted backend-origin health, hosted HTTPS staging, branch protection verify-only, and canonical gitleaks.
- Branch protection proof: remote verifier upload to `/tmp/apply_github_branch_protection.py` plus remote `python3 /tmp/apply_github_branch_protection.py --verify-only --repo strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM --branch chore/repo-bootstrap` executed successfully against the GitHub API using the existing remote `.env` secret context.
- Verifier hardening: `scripts/verify-external-gates.ps1` now resolves the remote default branch first, accepts hosted Hetzner budget proof by contract marker instead of brittle JSON spacing, and falls back to remote branch-protection verification when local `BRANCH_PROTECTION_TOKEN` is absent.
- Progress change: Overall rises to `49%`; Phase 4 rises to `23%`. This is gate closure and release-readiness hardening only. It is not a production deployment.

## Previous Completed Proof

Hosted HTTPS Staging Proof:

- Hosted URL: `<hosted-staging-url>`
- Deploy path: `scripts/deploy-to-staging.ps1` now requires an existing remote `.env`, copies only non-secret files, sets non-local `STAGING_BASE_URL`, `AGENT_API_BASE_URL`, `MCP_GATEWAY_BASE_URL`, and `LLM_GATEWAY_BASE_URL`, and deploys the pull-based cloud stack under `/app`.
- TLS layer: `docker-compose.cloud.yml` now runs `caddy` in front of `nginx`; `infrastructure/caddy/Caddyfile` terminates HTTPS for `<hosted-staging-hostname>`; `infrastructure/nginx/cloud.conf` preserves forwarded proto/host markers from the TLS proxy.
- Live proof: Python/OpenSSL probes returned HTTP `200` for `<hosted-staging-url>/` and `<hosted-staging-url>/api/v1/health`; the hosted progress endpoint returned `overall_percent=48`; remote `docker compose ... ps` showed `caddy`, `nginx`, `frontend`, `agent-api`, `mcp-gateway`, `llm-gateway`, `postgres`, `redis`, `agent-worker`, and `memory-worker` healthy.
- Gate proof: `scripts/verify-cloud-only-staging.ps1 -BaseUrl <hosted-staging-url>` now passes with `hosted_staging_claim_allowed=True`. The later external-gate audit closure proof supersedes the older note about still-open branch, GHCR, backend-origin, and Hetzner gates.
- Browser proof: Puppeteer navigated to `<hosted-staging-url>/` and confirmed title `Cloud Superbrain`, visible `Project Progress`, visible `External Gates`, visible `48%`, and the hosted URL. Playwright/Chrome DevTools screenshot proof remained locally blocked because Chrome is not installed on this machine.
- Progress change at that milestone: Overall remained `48%`; Phase 4 rose to `16%`. The newer external-gate audit closure proof supersedes the older open-gate state.

## Previous Completed Proof

External Gates Alignment Contract Proof:

- API: `GET /api/v1/external-gates`
- Contract: `external-gates-state-v1`
- Evidence: `external_gates_state_visible`
- Coverage: the local external-gates endpoint now publishes the same release-gate vocabulary as the cloud deployment preflight through `preflight_gate_id` mappings for `branch_protection`, `hosted_staging`, `hetzner_cloud_stack`, `ghcr_images`, `hosted_backend_origins`, and `canonical_secret_scan`.
- UI: the `External Gates` panel now renders contract version, evidence ref, endpoint marker, blocked release gates, the preflight endpoint link, and per-gate alias rows such as `ghcr_image_digest_proof -> ghcr_images` and `vercel_backend_origins -> hosted_backend_origins`.
- Verifier hardening: `scripts/verify-browser-contract.ps1`, `scripts/verify-hosted-staging.ps1`, `scripts/verify-phase1-runtime.ps1`, and `scripts/verify-phase1.ps1` now assert the alignment markers. `scripts/verify-hosted-staging.ps1` no longer fails on a global `latest_task_id` race; it verifies stable agent-status markers instead.
- AI browser proof: Chrome DevTools MCP opened `<local-control-plane-url>/`, confirmed `External Gates`, `external-gates-state-v1`, `external_gates_state_visible`, `Release blockers`, the deployment preflight link, the GHCR/Vercel alias mapping, and `47%`; network proof showed HTTP `200` for the page and contract endpoints; screenshot `<repo-root>\superbrain-external-gates-alignment-proof-2026-05-04.png` was captured.
- Verified commands: Python compile for `services\agent-api\app\main.py`, project-progress manifest validation, `scripts\verify-phase1.ps1`, Docker rebuild of `agent-api`, `frontend`, and `nginx`, `scripts\verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts\verify-hosted-staging.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, and direct API inspection of `GET /api/v1/external-gates`.

No progress percentage changed at that point: Overall remained `48%`, Phase 4 remained `15%`. This was contract/verifier hardening, not a live hosted or production cloud proof.

## Previous Completed Proof

Cloud Deployment Preflight Fail-Closed Contract Proof:

- API: `GET /api/v1/clouds/deployment-preflight/contract`
- Contract: `cloud-deployment-preflight-v1`
- Evidence: `cloud_deployment_preflight_visible`
- Coverage: separates environment presence from verified cloud proof; `cloud_deploy_claim_allowed=false` and `production_deploy_claim_allowed=false` until all external gates prove real hosted/non-local cloud state.
- Required gates: `ghcr_images` with `ghcr_image_digest_proof`, `hetzner_cloud_stack`, `hosted_backend_origins`, `hosted_staging`, `branch_protection`, and `canonical_secret_scan`.
- External gate hardening: hosted URLs must be non-local HTTPS; branch protection requires `BRANCH_PROTECTION_TOKEN`; GHCR proof requires both `GITHUB_TOKEN` and `GHCR_TOKEN`; Vercel backend origins require `AGENT_API_BASE_URL`, `MCP_GATEWAY_BASE_URL`, and `LLM_GATEWAY_BASE_URL`.
- Frontend renders `Cloud Deployment Preflight`, `cloud-deployment-preflight-v1`, `cloud_deployment_preflight_visible`, `GET /api/v1/clouds/deployment-preflight/contract`, and blocked cloud/production claims.
- AI browser proof: Chrome DevTools MCP opened `<local-control-plane-url>/`, confirmed `Project Progress 47%`, `Verified: 2026-05-03`, the Preflight panel, the endpoint marker, all six blockers, and captured screenshot `<repo-root>\superbrain-cloud-deployment-preflight-proof-2026-05-03.png`. Network proof showed the page and `/api/v1/clouds/deployment-preflight/contract` returning HTTP `200`; console showed no JavaScript runtime errors, only an accessibility issue about unnamed form fields.
- Verified commands: Python compile for `services\agent-api\app\main.py`, project-progress manifest validation, PowerShell parser checks for the updated verifiers, `scripts\verify-phase1.ps1`, Docker rebuild, direct API checks for deployment preflight and external gate mirror, `scripts\verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts\verify-hosted-staging.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts\verify-external-gates.ps1 -LocalBaseUrl <local-control-plane-url>`, intentional negative proof from `scripts\verify-cloud-only-staging.ps1 -BaseUrl <local-control-plane-url>`, and full `scripts\verify-phase1-runtime.ps1`.
- External gate artifact: `.phase1-artifacts\external-gate-audit-20260503-184218.json` reported `status=action_required`, `frontend_preview_claim_allowed=false`, `hosted_staging_claim_allowed=false`, and `production_deploy_claim_allowed=false`.

No progress percentage changed: Overall remains `47%`, Phase 4 remains `15%`. This was fail-closed cloud readiness hardening, not a live hosted staging or production deployment.

## Previous Completed Proof

Gemini Priority Queue Correction + Sandbox Rule Proof:

- Scope: reviewed the reported `tasks.py` and `orchestrator.py` changes instead of accepting the `49%` claim; current manifest truth remains `47%`.
- Queue contract: Agent API publishes each task to exactly one priority queue; Worker consumes `tasks:agent:queue:high`, `tasks:agent:queue`, then `tasks:agent:queue:low`.
- Role priority proof: Planner priority `9` and DevOps priority `8` resolve to high priority; Coder and Tester priority `5` remain mid/default.
- Orchestrator evidence proof: `task_assignment_completed` is emitted only for completed tasks; missing `[DONE]` or unproven `live_provider_calls=false` becomes partial failure instead of false completion.
- Redaction proof: `task_description` is redacted before validation/persistence.
- Sandbox rule proof: `Unexpected response type` is documented as an MCP wrapper/transport hint in `<workspace-root>\AGENTS.md` and `<workspace-root>\SANDBOX_INSTRUCTIONS.md`, not as an automatic ULTIMATE_SANDBOX failure.
- AI browser proof: Chrome DevTools MCP opened `<local-control-plane-url>/`, listed 75 network requests with HTTP `200`, and the DOM contained `Task Assignment Queue Contract`, `Priority Routing`, `high -> mid -> low`, `Total Project`, and `47%`; Puppeteer MCP confirmed the same markers and captured screenshot `superbrain-priority-routing-section-2026-05-01`.
- Verified commands: Python compile for Agent API/Worker files, `py -3 scripts\verify_project_progress_manifest.py`, `scripts\verify-phase1.ps1`, Docker rebuild, direct API priority-contract checks, `scripts\verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts\verify-hosted-staging.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, and `scripts\verify-phase1-runtime.ps1`.

No progress percentage changed: Overall remains `47%`, Phase 4 remains `15%`. This was corrective hardening, not external gate closure.

## Previous Completed Proof

Cloud Render Offload Contract Proof:

- API: `GET /api/v1/clouds/render-offload/contract`
- Contract: `cloud-render-offload-v1`
- Evidence: `cloud_render_offload_contract_visible`
- Coverage: `localhost_heavy_render_allowed=false`, `home_pc_protection=true`, `webgl_3d_rendering`, `browser_gpu_smoke`, and `asset_generation` are cloud-only, while `control_plane` remains local dev-only.
- Required cloud gates: `STAGING_BASE_URL`, `AGENT_API_BASE_URL`, `MCP_GATEWAY_BASE_URL`, `LLM_GATEWAY_BASE_URL`, and `HETZNER_API_TOKEN`.
- Frontend renders `Cloud Render Offload`, `Local Render blocked`, `WebGL / 3D rendering cloud-only`, and `GET /api/v1/clouds/render-offload/contract`.
- Verified commands: `py -3 -m py_compile services\agent-api\app\main.py`, `scripts\verify-phase1.ps1`, `docker compose -f docker-compose.dev.yml up -d --build agent-api frontend nginx`, direct API curl, `scripts\verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts\verify-hosted-staging.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts\verify-external-gates.ps1 -LocalBaseUrl <local-control-plane-url>`, and Playwright DOM proof.

No progress percentage changed: Overall remains `47%`, Phase 4 remains `15%`. The contract is local/fail-closed and does not claim live cloud servers.

## Previous Completed Proof

GitKraken Cloud Inventory Contract Proof:

- API: `GET /api/v1/clouds`
- Contract: `cloud-provider-inventory-v1`
- Evidence: `cloud_provider_inventory_visible`
- Coverage: the inventory now exposes eight providers and includes `gitkraken_identity` with `GITKRAKEN_API_TOKEN`, `GITKRAKEN_ORG_ID`, `GITKRAKEN_ORG_NAME`, `GITKRAKEN_DASHBOARD_URL`, and `GITKRAKEN_API_URL` as key names/status only.
- Layer readiness: `GET /api/v1/clouds/layers` includes `gitkraken_identity` in Layer 5 and Layer 7 with fail-closed blocker `gitkraken_identity_requires_GITKRAKEN_API_TOKEN`.
- External gate audit: `scripts/verify-external-gates.ps1` now emits `gitkraken_identity_claim_allowed=false` until a rotated real `GITKRAKEN_API_TOKEN` is injected.
- Docs/runtime: `.env.example`, `docker-compose.cloud.yml`, `docs/runbooks/cloud-secret-runtime-injection.md`, `docs/runtime-contracts/cloud-provider-inventory-contract.md`, and `docs/runtime-contracts/external-gate-audit-contract.md` now include GitKraken without storing secrets.
- Verified commands: `py -3 -m py_compile services\agent-api\app\clouds.py`, `py -3 scripts\verify_project_progress_manifest.py`, `scripts\verify-phase1.ps1`, `scripts\verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts\verify-hosted-staging.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts\verify-external-gates.ps1 -LocalBaseUrl <local-control-plane-url>`, and `scripts\verify-phase1-runtime.ps1`.
- Playwright DOM proof confirmed `Cloud Inventory`, `Cloud 7-Layer Readiness`, `GitKraken`, `cloud_provider_inventory_visible`, `cloud_layer_readiness_visible`, `Total Project 47`, and `Phase 4 15`.

No progress percentage changed: Overall remains `47%`, Phase 4 remains `15%`, MCP Gateway remains `53%`, Observability remains `99%`.

## Previous Completed Proof

Local Rebuild + Runtime Re-Proof:

- Rebuilt and restarted local Docker services with `docker compose -f docker-compose.dev.yml up -d --build agent-api agent-worker memory-worker frontend nginx`.
- `GET /api/v1/health` returned `healthy` after rebuild.
- `GET /api/v1/memory/embedding-consistency/contract` returned `status=verified`, `memory-embedding-consistency-v1`, `vector(1536)`, `embedding_model_version`, and `lexical_fallback`.
- `scripts/verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost` passed.
- `scripts/verify-hosted-staging.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost` passed.
- `scripts/verify-phase1-runtime.ps1` passed, including Docker recreate, worker regression, SSE replay, Memory Embedding Consistency, and post-recreate steady-state proof.
- Playwright opened `<local-control-plane-url>/` and confirmed `Cloud Superbrain`, `Project Progress`, and `Memory Embedding Consistency Contract`.

No progress percentage changed: Overall remains `47%`, Phase 4 remains `15%`, Memory remains `70%`.

Audit L-09 Memory Embedding Consistency Contract Proof:

- API: `GET /api/v1/memory/embedding-consistency/contract`
- Contract: `memory-embedding-consistency-v1`
- Evidence: `memory_embedding_consistency_contract_visible`
- Coverage: runtime verifies `memory_entries.content_embedding vector(1536)`, `memory_entries.embedding_model_version`, deterministic `text-embedding-3-small`, `lexical_fallback`, and a fail-closed re-embedding policy before future vector search can mix versions.
- Frontend renders `Memory Embedding Consistency Contract`; docs live in `docs/runtime-contracts/memory-embedding-consistency-contract.md`.

This raised Memory from `69%` to `70%`. Overall remains `47%`, Phase 4 remains `15%`.

## Previous Completed Proof

Runtime Post-Recreate Steady-State Proof:

- Verifier: `scripts/verify-phase1-runtime.ps1`
- Coverage: transient `curl` noise is suppressed while waiting through Docker/Nginx recreate windows; failed probes still fail after bounded retry exhaustion. Session-SSE stream and replay probes now use bounded `Wait-SseContains` retries in both runtime and hosted-local verifiers.
- Post-recreate proof: `GET /api/v1/health`, `GET /api/v1/project/progress/integrity`, `GET /mcp/api/v1/version-pinning/contract`, and `/favicon.ico`.
- Purpose: a green runtime run cannot leave an unverified 502, stale Nginx upstream, or browser asset regression behind.

No percentage change. Overall remains `47%`, Phase 4 remains `15%`.

## Previous Completed Proof

L-09 Project Progress Integrity Runtime Proof:

- API: `GET /api/v1/project/progress/integrity`
- Contract: `project-progress-integrity-v1`
- Evidence: `project_progress_integrity_runtime_proof`
- Coverage: runtime recomputes `computed_overall_percent` from the seven horizontal phases, compares it to `manifest_overall_percent`, reports mismatches fail-closed, and keeps the binding manifest/document visible.
- Frontend renders `Progress Integrity`; docs live in `docs/runtime-contracts/project-progress-integrity-contract.md`.

This raised Phase 4 from `14%` to `15%`. Overall remains `47%`.

## Previous Completed Proof

L-08 MCP Version Pinning Contract Proof:

- API: `GET /mcp/api/v1/version-pinning/contract`
- Contract: `mcp-version-pinning-v1`
- Evidence: `mcp_version_pinning_contract_visible`
- Coverage: MCP Gateway version `0.1.0`, exact Python dependency pins, pinned tool contract versions for GitHub, PostgreSQL, Filesystem, Playwright, and E2B, ToolRequest shape, drift policy, and no-live-MCP-write non-claims.
- Frontend renders `MCP Version Pinning Contract`; docs live in `docs/runtime-contracts/mcp-version-pinning-contract.md`.

This raised Phase 4 from `13%` to `14%` and MCP Gateway from `52%` to `53%`. Overall remains `47%`.

## Previous Completed Proof

L-07 Agent LLM Streaming Contract Proof:

- API: `GET /api/v1/agents/llm-streaming-contract`
- Contract: `agent-llm-streaming-contract-v1`
- Evidence: `agent_llm_streaming_contract_visible`
- Coverage: Layer 3 to Layer 4 streaming boundary from Agent Pool to LLM Gateway, `call_llm_gateway_for_task`, `parse_llm_gateway_sse_line`, routing policy preflight, OpenAI-compatible SSE frames, `data: [DONE]`, `stream_done_seen`, and no-live-provider non-claims.
- Frontend renders `Agent LLM Streaming Contract`; docs live in `docs/runtime-contracts/agent-llm-streaming-contract.md`.

This raised Phase 4 from `12%` to `13%` and LLM Gateway from `52%` to `53%`. Overall remains `47%`.

## Previous Completed Proof

Hetzner Live Budget Warning Proof:

- Script: `scripts/check_hetzner_infra_budget.py`
- Proof doc: `docs/runbooks/hetzner-live-budget-proof-2026-04-29.md`
- Result: projected Hetzner monthly server cost `EUR 19.03`
- Thresholds: warning `EUR 16.00`, hard budget `EUR 20.00`
- Interpretation: under hard budget, above warning threshold.
- Token handling: `HETZNER_API_TOKEN` was used only as transient process environment and was not written to repo files.

This raised Phase 4 from `11%` to `12%`. Overall remains `47%`.

## Previous Completed Proof

L-06 Task Assignment Queue Contract Proof:

- API: `GET /api/v1/tasks/assignment-contract`
- Contract: `task-assignment-queue-contract-v1`
- Evidence: `task_assignment_queue_contract_visible`
- Coverage: Layer 2 to Layer 3 task assignment, Redis queue key, status key pattern, TTL, worker consumer, public visibility endpoints, backpressure, stale-queue rescue, and policy fail-closed semantics.
- Frontend renders `Task Assignment Queue Contract`; docs live in `docs/runtime-contracts/task-assignment-queue-contract.md`.

This raised Phase 4 from `10%` to `11%` and Agent Pool from `60%` to `61%`. Overall remains `47%`.

## Previous Completed Proof

L-05 Layer Interface Contracts Proof:

- API: `GET /api/v1/layer-interfaces/contract`
- Contract: `layer-interface-contracts-v1`
- Evidence: `layer_interface_contracts_visible`
- Coverage: seven runtime layer boundaries with method, path, request schema, response schema, status, and evidence ref.
- Frontend renders `Layer Interface Contracts`; docs live in `docs/runtime-contracts/layer-interface-contracts.md`.

Historical proof point: this raised Phase 4 from `9%` to `10%` and Frontend from `96%` to `97%`; current verified progress remains defined by the `Current Verified Progress` section above.

## Previous Completed Proof

Audit Runtime Closure Proof:

- Task intake rejects invalid `session_id` values fail-closed with HTTP 422.
- Agent Worker rejects malformed raw queue payloads without crashing.
- Orchestrator MCP calls carry `session_id` and `trace_id` into MCP Gateway and Agent API audit persistence.
- `GET /api/v1/audit/mcp` exposes `session_bound=true`, top-level `trace_id`, and `mcp_tool_session_bound_audit` for orchestrator tool calls.
- ADR-008 and ADR-009 close the single-tenant and auth-design audit documentation gaps.

Historical proof point: this raised Phase 4 from `8%` to `9%`, Agent Pool from `59%` to `60%`, MCP Gateway from `51%` to `52%`, and Overall from `46%` to `47%`; current verified progress remains defined by the `Current Verified Progress` section above.

## Previous Completed Proof

External Gate Mirror Proof:

- API: `GET /api/v1/external-gates/mirror`
- Contract: `external-gate-mirror-v1`
- Evidence: `external_gate_mirror_proof`
- Hosted workflow mirror: `.github/workflows/hosted-staging-proof.yml`
- Hosted verifier mirror: `scripts/verify-hosted-staging.ps1`
- Progress mirror evidence: `project_progress_manifest_proof`

Historical proof point: this raised Phase 4 from `7%` to `8%` while Overall was still `46%`; current verified progress remains defined by the `Current Verified Progress` section above.

## Non-Claims / Closed Gates

Do not claim these until external evidence exists:

- No live LLM provider calls are verified.
- No live MCP writes are verified.
- No production deployment is verified.
- `production_deploy_claim_allowed=true` is only a gate-closure statement, not a deploy statement.

## Next Safe Work

1. Keep localhost as a dev control plane only; the authoritative hosted gate truth is on the Hetzner staging URL.
2. Keep extending candidate-scoped Phase-5 evidence after the integration-plan proof instead of switching to rollout.
3. If rollout is approved later, treat `.phase1-artifacts/phase5-rollback-drill-prod-candidate-20260505-rc1.md` as the rollback starting point, not the floating `:staging` alias.
4. Treat `.phase1-artifacts/hosted-browser-proof-20260504-235540.md` as historical provenance only; do not reuse it as current candidate evidence until the external Codex browser bridge is repaired and a fresh rerun exists.

## Git State Warning

The current workspace is intentionally not clean. Many files are modified or untracked because the platform has been built in-place. For exact transfer:

1. Copy the whole project folder, or
2. Commit/stage the whole current workspace before handing it off.

Do not rely on `git clone` alone unless these local changes have been committed and pushed.

## Historical Hosted Proof Snapshot

- Historical Overall: `63%`
- Historical Horizontal `P0 100 | P1 100 | P2 86 | P3 40 | P4 84 | P5 28 | P6 0`
- Historical Vertical `Frontend 97 | Orchestrator 99 | Agent Pool 68 | LLM 54 | MCP 55 | Memory 72 | Observability 99`
- Current truth remains the `Current Verified Progress` section above and `docs/project-progress.manifest.json`.

## Latest Completed Hosted Proofs

**Project Progress Completion Contract Runtime Parity**

- API:
  - `GET /api/v1/project/progress/completion/contract`
  - `GET /api/v1/project/progress/completion`
- Contract: `project-progress-completion-surface-v1`
- Runtime stayed fail-closed with `can_set_all_to_100=false`
- Proof: `.phase1-artifacts/phase4-progress-completion-contract-runtime-hosted-proof-20260507.md`

**Orchestrator Manifest Contract Runtime Parity**

- API:
  - `GET /api/v1/orchestrator/manifest/contract`
  - `GET /api/v1/orchestrator/manifest`
- Contract: `orchestrator-manifest-surface-v1`
- Hosted dry-run stayed aligned with `engine=langgraph`, `checkpointing=postgres`, `live_provider_calls=false`
- Proof: `.phase1-artifacts/phase4-orchestrator-manifest-contract-runtime-hosted-proof-20260507.md`
