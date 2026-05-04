# AI Handoff - Cloud Superbrain Developer Platform

## Project Root

`D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`

Open this entire folder in the next IDE or AI-agent tool. Do not copy only tracked Git files: the current project state contains many new, untracked files that are required for a 1:1 handoff.

## Binding Truth

Primary project truth:

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

Use `PROJECT_ANCHOR.md` plus `docs/project-checkpoint-2026-04-30.json` as the current resume point. It records the verified `localhost:8081` health snapshot, the restored session-history proof, the current `47%` progress state, the detailed repair protocol, the GitKraken cloud-inventory extension proof, the cloud render-offload proof, the cloud deployment preflight fail-closed proof, the external-gates alignment proof, and the next safe work item: GHCR image digest proof plus hosted non-local HTTPS staging proof.

## Current Verified Progress

Overall: `47%`

Horizontal:

- P0: `100%`
- P1: `98%`
- P2: `86%`
- P3: `33%`
- P4: `15%`
- P5: `0%`
- P6: `0%`

Vertical:

- Frontend / Next.js: `97%`
- Orchestrator / LangGraph: `99%`
- Agent Pool: `61%`
- LLM Gateway: `53%`
- MCP Gateway: `53%`
- Memory: `70%`
- Observability: `99%`

Older percentage lines below are historical proof points only. Current percentages must come from this section and `docs/project-progress.manifest.json`.

## Current Runtime

Local browser URL:

- `http://localhost:8081/`

Superbrain stream URL:

- `http://localhost:8081/api/stream`

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
powershell -ExecutionPolicy Bypass -File scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost
powershell -ExecutionPolicy Bypass -File scripts\verify-hosted-staging.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost
powershell -ExecutionPolicy Bypass -File scripts\verify-external-gates.ps1 -LocalBaseUrl http://localhost:8081
powershell -ExecutionPolicy Bypass -File scripts\verify-cloud-only-staging.ps1 -BaseUrl https://<hosted-staging-domain>
powershell -ExecutionPolicy Bypass -File scripts\verify-phase1-runtime.ps1
powershell -ExecutionPolicy Bypass -File scripts\verify-autopilot-mode.ps1 -AllowLocalhost
py -3 scripts\verify_project_progress_manifest.py
```

Recent verification status: local deterministic verifiers were extended for Priority Queue routing, Orchestrator evidence fail-closed behavior, and the ULTIMATE_SANDBOX wrapper-rule correction on 2026-05-01. The local Docker stack was rebuilt and re-proved live on `http://localhost:8081`.

Autopilot stream proof now runs through the active Agent API/Nginx stack at `http://localhost:8081/api/stream` and emits `status:init`, `status:llm`, `token`, and `done` with `autopilot-mode-stream-proof`.

## Latest Completed Proof

External Gates Alignment Contract Proof:

- API: `GET /api/v1/external-gates`
- Contract: `external-gates-state-v1`
- Evidence: `external_gates_state_visible`
- Coverage: the local external-gates endpoint now publishes the same release-gate vocabulary as the cloud deployment preflight through `preflight_gate_id` mappings for `branch_protection`, `hosted_staging`, `hetzner_cloud_stack`, `ghcr_images`, `hosted_backend_origins`, and `canonical_secret_scan`.
- UI: the `External Gates` panel now renders contract version, evidence ref, endpoint marker, blocked release gates, the preflight endpoint link, and per-gate alias rows such as `ghcr_image_digest_proof -> ghcr_images` and `vercel_backend_origins -> hosted_backend_origins`.
- Verifier hardening: `scripts/verify-browser-contract.ps1`, `scripts/verify-hosted-staging.ps1`, `scripts/verify-phase1-runtime.ps1`, and `scripts/verify-phase1.ps1` now assert the alignment markers. `scripts/verify-hosted-staging.ps1` no longer fails on a global `latest_task_id` race; it verifies stable agent-status markers instead.
- AI browser proof: Chrome DevTools MCP opened `http://localhost:8081/`, confirmed `External Gates`, `external-gates-state-v1`, `external_gates_state_visible`, `Release blockers`, the deployment preflight link, the GHCR/Vercel alias mapping, and `47%`; network proof showed HTTP `200` for the page and contract endpoints; screenshot `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM\superbrain-external-gates-alignment-proof-2026-05-04.png` was captured.
- Verified commands: Python compile for `services\agent-api\app\main.py`, project-progress manifest validation, `scripts\verify-phase1.ps1`, Docker rebuild of `agent-api`, `frontend`, and `nginx`, `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts\verify-hosted-staging.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, and direct API inspection of `GET /api/v1/external-gates`.

No progress percentage changed: Overall remains `47%`, Phase 4 remains `15%`. This was contract/verifier hardening, not a live hosted or production cloud proof.

## Previous Completed Proof

Cloud Deployment Preflight Fail-Closed Contract Proof:

- API: `GET /api/v1/clouds/deployment-preflight/contract`
- Contract: `cloud-deployment-preflight-v1`
- Evidence: `cloud_deployment_preflight_visible`
- Coverage: separates environment presence from verified cloud proof; `cloud_deploy_claim_allowed=false` and `production_deploy_claim_allowed=false` until all external gates prove real hosted/non-local cloud state.
- Required gates: `ghcr_images` with `ghcr_image_digest_proof`, `hetzner_cloud_stack`, `hosted_backend_origins`, `hosted_staging`, `branch_protection`, and `canonical_secret_scan`.
- External gate hardening: hosted URLs must be non-local HTTPS; branch protection requires `BRANCH_PROTECTION_TOKEN`; GHCR proof requires both `GITHUB_TOKEN` and `GHCR_TOKEN`; Vercel backend origins require `AGENT_API_BASE_URL`, `MCP_GATEWAY_BASE_URL`, and `LLM_GATEWAY_BASE_URL`.
- Frontend renders `Cloud Deployment Preflight`, `cloud-deployment-preflight-v1`, `cloud_deployment_preflight_visible`, `GET /api/v1/clouds/deployment-preflight/contract`, and blocked cloud/production claims.
- AI browser proof: Chrome DevTools MCP opened `http://localhost:8081/`, confirmed `Project Progress 47%`, `Verified: 2026-05-03`, the Preflight panel, the endpoint marker, all six blockers, and captured screenshot `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM\superbrain-cloud-deployment-preflight-proof-2026-05-03.png`. Network proof showed the page and `/api/v1/clouds/deployment-preflight/contract` returning HTTP `200`; console showed no JavaScript runtime errors, only an accessibility issue about unnamed form fields.
- Verified commands: Python compile for `services\agent-api\app\main.py`, project-progress manifest validation, PowerShell parser checks for the updated verifiers, `scripts\verify-phase1.ps1`, Docker rebuild, direct API checks for deployment preflight and external gate mirror, `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts\verify-hosted-staging.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts\verify-external-gates.ps1 -LocalBaseUrl http://localhost:8081`, intentional negative proof from `scripts\verify-cloud-only-staging.ps1 -BaseUrl http://localhost:8081`, and full `scripts\verify-phase1-runtime.ps1`.
- External gate artifact: `.phase1-artifacts\external-gate-audit-20260503-184218.json` reported `status=action_required`, `frontend_preview_claim_allowed=false`, `hosted_staging_claim_allowed=false`, and `production_deploy_claim_allowed=false`.

No progress percentage changed: Overall remains `47%`, Phase 4 remains `15%`. This was fail-closed cloud readiness hardening, not a live hosted staging or production deployment.

## Previous Completed Proof

Gemini Priority Queue Correction + Sandbox Rule Proof:

- Scope: reviewed the reported `tasks.py` and `orchestrator.py` changes instead of accepting the `49%` claim; current manifest truth remains `47%`.
- Queue contract: Agent API publishes each task to exactly one priority queue; Worker consumes `tasks:agent:queue:high`, `tasks:agent:queue`, then `tasks:agent:queue:low`.
- Role priority proof: Planner priority `9` and DevOps priority `8` resolve to high priority; Coder and Tester priority `5` remain mid/default.
- Orchestrator evidence proof: `task_assignment_completed` is emitted only for completed tasks; missing `[DONE]` or unproven `live_provider_calls=false` becomes partial failure instead of false completion.
- Redaction proof: `task_description` is redacted before validation/persistence.
- Sandbox rule proof: `Unexpected response type` is documented as an MCP wrapper/transport hint in `D:\PLATTFORM\AGENTS.md` and `D:\PLATTFORM\SANDBOX_INSTRUCTIONS.md`, not as an automatic ULTIMATE_SANDBOX failure.
- AI browser proof: Chrome DevTools MCP opened `http://localhost:8081/`, listed 75 network requests with HTTP `200`, and the DOM contained `Task Assignment Queue Contract`, `Priority Routing`, `high -> mid -> low`, `Total Project`, and `47%`; Puppeteer MCP confirmed the same markers and captured screenshot `superbrain-priority-routing-section-2026-05-01`.
- Verified commands: Python compile for Agent API/Worker files, `py -3 scripts\verify_project_progress_manifest.py`, `scripts\verify-phase1.ps1`, Docker rebuild, direct API priority-contract checks, `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts\verify-hosted-staging.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, and `scripts\verify-phase1-runtime.ps1`.

No progress percentage changed: Overall remains `47%`, Phase 4 remains `15%`. This was corrective hardening, not external gate closure.

## Previous Completed Proof

Cloud Render Offload Contract Proof:

- API: `GET /api/v1/clouds/render-offload/contract`
- Contract: `cloud-render-offload-v1`
- Evidence: `cloud_render_offload_contract_visible`
- Coverage: `localhost_heavy_render_allowed=false`, `home_pc_protection=true`, `webgl_3d_rendering`, `browser_gpu_smoke`, and `asset_generation` are cloud-only, while `control_plane` remains local dev-only.
- Required cloud gates: `STAGING_BASE_URL`, `AGENT_API_BASE_URL`, `MCP_GATEWAY_BASE_URL`, `LLM_GATEWAY_BASE_URL`, and `HETZNER_API_TOKEN`.
- Frontend renders `Cloud Render Offload`, `Local Render blocked`, `WebGL / 3D rendering cloud-only`, and `GET /api/v1/clouds/render-offload/contract`.
- Verified commands: `py -3 -m py_compile services\agent-api\app\main.py`, `scripts\verify-phase1.ps1`, `docker compose -f docker-compose.dev.yml up -d --build agent-api frontend nginx`, direct API curl, `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts\verify-hosted-staging.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts\verify-external-gates.ps1 -LocalBaseUrl http://localhost:8081`, and Playwright DOM proof.

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
- Verified commands: `py -3 -m py_compile services\agent-api\app\clouds.py`, `py -3 scripts\verify_project_progress_manifest.py`, `scripts\verify-phase1.ps1`, `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts\verify-hosted-staging.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts\verify-external-gates.ps1 -LocalBaseUrl http://localhost:8081`, and `scripts\verify-phase1-runtime.ps1`.
- Playwright DOM proof confirmed `Cloud Inventory`, `Cloud 7-Layer Readiness`, `GitKraken`, `cloud_provider_inventory_visible`, `cloud_layer_readiness_visible`, `Total Project 47`, and `Phase 4 15`.

No progress percentage changed: Overall remains `47%`, Phase 4 remains `15%`, MCP Gateway remains `53%`, Observability remains `99%`.

## Previous Completed Proof

Local Rebuild + Runtime Re-Proof:

- Rebuilt and restarted local Docker services with `docker compose -f docker-compose.dev.yml up -d --build agent-api agent-worker memory-worker frontend nginx`.
- `GET /api/v1/health` returned `healthy` after rebuild.
- `GET /api/v1/memory/embedding-consistency/contract` returned `status=verified`, `memory-embedding-consistency-v1`, `vector(1536)`, `embedding_model_version`, and `lexical_fallback`.
- `scripts/verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` passed.
- `scripts/verify-hosted-staging.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` passed.
- `scripts/verify-phase1-runtime.ps1` passed, including Docker recreate, worker regression, SSE replay, Memory Embedding Consistency, and post-recreate steady-state proof.
- Playwright opened `http://localhost:8081/` and confirmed `Cloud Superbrain`, `Project Progress`, and `Memory Embedding Consistency Contract`.

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
- No hosted staging success is verified without `STAGING_BASE_URL`.
- Branch protection success is not verified without `BRANCH_PROTECTION_TOKEN`.

## Next Safe Work

1. Configure real external gate secrets only when available:
   - `STAGING_BASE_URL`
   - `BRANCH_PROTECTION_TOKEN`
   - optional canonical `gitleaks`
2. Run hosted staging proof against the real hosted URL.
3. Continue evidence-based Phase 4 Integration & Hardening.

## Git State Warning

The current workspace is intentionally not clean. Many files are modified or untracked because the platform has been built in-place. For exact transfer:

1. Copy the whole project folder, or
2. Commit/stage the whole current workspace before handing it off.

Do not rely on `git clone` alone unless these local changes have been committed and pushed.
