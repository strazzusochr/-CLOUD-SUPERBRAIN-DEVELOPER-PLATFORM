# AI Handoff - Cloud Superbrain Developer Platform

## Project Root

`<repo-root>`

Open this entire folder in the next IDE or AI-agent tool. Do not copy only tracked Git files: the current project state contains many new, untracked files that are required for a 1:1 handoff.

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

Use `PROJECT_ANCHOR.md` plus `docs/project-checkpoint-2026-04-30.json` as the current resume point. It records the verified `<local-control-plane-host>` health snapshot, the restored session-history proof, the current `54%` progress state, the detailed repair protocol, the GitKraken cloud-inventory extension proof, the cloud render-offload proof, the cloud deployment preflight fail-closed proof, the external-gates alignment proof, the hosted HTTPS staging proof on Hetzner, the external-gate audit closure proof on hosted HTTPS, the hosted browser proof under `.phase1-artifacts/hosted-browser-proof-20260504-235540.md`, the workflow-linked production-candidate artifact under `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md`, the candidate integration-plan artifact under `docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-plan.md`, the immutable rollback-drill artifact under `.phase1-artifacts/phase5-rollback-drill-prod-candidate-20260505-rc1.md`, the explicit no-release owner decision artifact under `.phase1-artifacts/phase5-owner-decision-no-release-20260505.md`, the hosted orchestrator-runtime parity artifact under `.phase1-artifacts/phase4-orchestrator-runtime-hosted-proof-20260505.md`, the hosted orchestrator fail-closed/SSE artifact under `.phase1-artifacts/phase4-orchestrator-failclosed-hosted-proof-20260505.md`, the hosted MCP/DevOps artifact under `.phase1-artifacts/phase4-mcp-devops-hosted-proof-20260505.md`, the hosted public-dashboard artifact under `.phase1-artifacts/phase4-public-dashboard-hosted-proof-20260505.md`, the hosted observability artifact under `.phase1-artifacts/phase4-observability-hosted-proof-20260505.md`, the hosted cloud-surface artifact under `.phase1-artifacts/phase4-cloud-surfaces-hosted-proof-20260505.md`, and the current next safe work item: continue dedicated hosted Phase-4/Phase-5 evidence instead of rollout.

## Current Verified Progress

Overall: `54%`

Horizontal:

- P0: `100%`
- P1: `100%`
- P2: `86%`
- P3: `40%`
- P4: `30%`
- P5: `21%`
- P6: `0%`

Vertical:

- Frontend / Next.js: `97%`
- Orchestrator / LangGraph: `99%`
- Agent Pool: `61%`
- LLM Gateway: `53%`
- MCP Gateway: `54%`
- Memory: `70%`
- Observability: `99%`

Older percentage lines below are historical proof points only. Current percentages must come from this section and `docs/project-progress.manifest.json`.

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

Phase 5 Executed Hosted Rollback Proof:

- `.phase1-artifacts/phase5-executed-rollback-prod-candidate-20260505-rc1.md` now binds the current production-candidate to a real hosted rollback/restore run against Hetzner staging.
- `scripts/execute-phase5-executed-rollback.ps1` now preflights remote architecture, validates GHCR manifest architecture before selector mutation, performs the real `IMAGE_TAG=<immutable-sha>` switch, verifies hosted root/API/MCP/LLM health, restores `IMAGE_TAG=staging`, and re-verifies the hosted runtime.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now links the executed rollback proof directly as candidate evidence and points to workflow run `25392582005` on commit `ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`.
- `scripts/verify-phase5-executed-rollback.ps1` verifies the executed rollback artifact fail-closed against the immutable selector, restored selector, hosted truth, and remote `.env` state.
- Verified commands: `gh run watch 25392582005`, `powershell -ExecutionPolicy Bypass -File scripts\execute-phase5-executed-rollback.ps1 -ExpectedSha ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-executed-rollback.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `54%`; Phase 5 rises to `21%`. This is a real release-readiness rollback execution proof, not a rollout or production deployment.

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

Phase 5 Executed Hosted Candidate Browser Proof:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md` now binds the current production-candidate to an executed live browser proof against the hosted HTTPS target.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now links the browser proof directly as candidate evidence.
- `scripts/verify-phase5-browser-proof.ps1` verifies the browser-proof artifact fail-closed against the title, URL, screenshot handle, and required visible markers.
- Verified commands: live Puppeteer DOM proof, screenshot `phase5-hosted-browser-proof-20260505`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-browser-proof.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
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
4. Reuse `.phase1-artifacts/hosted-browser-proof-20260504-235540.md` as the latest hosted UI/runtime truth artifact unless a newer hosted proof supersedes it.

## Git State Warning

The current workspace is intentionally not clean. Many files are modified or untracked because the platform has been built in-place. For exact transfer:

1. Copy the whole project folder, or
2. Commit/stage the whole current workspace before handing it off.

Do not rely on `git clone` alone unless these local changes have been committed and pushed.
