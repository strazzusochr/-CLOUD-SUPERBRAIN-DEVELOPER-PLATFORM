# Cloud Superbrain Analysis Reconciliation

Stand: 2026-05-09
Source document: `C:\Users\immer\Downloads\CLOUD_SUPERBRAIN_ANALYSIS (1).html`
Repo: `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`

This document maps the external Cloud Superbrain analysis document to the
current repository truth. It is intentionally fail-closed: an item is only
marked verified when there is a file, runtime endpoint, hosted endpoint, or
verifier output backing it.

## 1. Docker Readiness Finding

Initial local Docker gate status was not acceptable.

- Normal shell `docker info --format '{{.ServerVersion}}'`: failed with pipe permission denial.
- Normal shell `wsl --status` and `wsl -l -v`: failed with `E_ACCESSDENIED`.
- Elevated `docker info --format '{{.ServerVersion}}'`: returned `29.4.1`.
- Elevated `wsl -l -v`: showed `Ubuntu` and `docker-desktop` running on WSL2.

Classification:

- Root cause: Docker/WSL access from the non-elevated process was denied.
- Correct readiness proof: elevated `docker info` returned Docker ServerVersion `29.4.1`.
- Docker gates were rerun after this proof.

## 2. Code Changes Made During This Reconciliation

### 2.1 Frontend dev container write permission

Problem:

- `frontend` used `read_only: true`.
- `next dev` needed writable `/app/.next/cache` and `/app/.next/trace`.
- Container logs showed `EACCES: permission denied`.

Fix:

- `docker-compose.dev.yml` now mounts `/app/.next` as tmpfs with app-user ownership:
  - `/app/.next:uid=10001,gid=10001,mode=1777`
- The container remains `read_only: true`.

Verification:

- `frontend` became healthy.
- `verify.ps1 -Suite phase1-runtime` passed.
- `verify.ps1 -Suite browser-contract -AllowLocalhost` passed.
- `verify.ps1 -Suite phase1` passed after the change.

### 2.2 Hosted staging smoke preflight URL

Problem:

- `verify-hosted-staging-smoke.ps1` checked `/api/v1/clouds/deployment-preflight/contract`
  for runtime fields such as `"status":"verified"`.
- The contract endpoint correctly returns contract metadata, not runtime preflight status.

Fix:

- The verifier now checks `/api/v1/clouds/deployment-preflight`.

Verification:

- `verify.ps1 -Suite hosted-staging-smoke -BaseUrl https://188-34-191-140.sslip.io` passed.

### 2.3 Single-region Frankfurt outage runbook

Problem from analysis:

- `F21`: Hetzner Frankfurt single-region dependency needed an explicit outage runbook.

Fix:

- Added `docs/runbooks/single-region-frankfurt-outage.md`.
- Added it to `docs/runbooks/README.md`.
- Added `scripts/verify-single-region-runbook.ps1`.
- Registered it under suite `phase1` in `scripts/verify.suites.json`.

Verification:

- `verify-single-region-runbook.ps1` passed.
- `verify.ps1 -Suite phase1` passed.
- `verify.ps1 -List` reports all `verify-*.ps1` files are covered by suite `all`.

### 2.4 Staging parity blocker digest refresh

Problem:

- `verify-phase5-staging-parity-blocked.ps1` failed because the mutable
  `frontend:staging` GHCR digest had changed.
- The blocker artifact still recorded the older digest.

Fix:

- Updated `docs/release-artifacts/prod-candidate-2026-05-05-rc1-staging-parity-blocked.md`
  with the current `frontend:staging` digest:
  - `sha256:b5d023c8e40765c768676b4e923897e0f9df6aa664de0a0ddbdeaa21703cd668`

Verification:

- `verify-phase5-staging-parity-blocked.ps1 -BaseUrl https://188-34-191-140.sslip.io` passed.
- Full `verify.ps1 -Suite phase5 -BaseUrl https://188-34-191-140.sslip.io` passed.

## 3. Analysis Gap Register Mapping

| ID | Analysis item | Current repo status | Evidence |
| --- | --- | --- | --- |
| L-05 | Layer 1/2 interface spec | verified | `docs/runtime-contracts/layer-interface-contracts.md`; `verify-phase4-layer-interfaces-contract-runtime-hosted.ps1`; `verify-hosted-staging.ps1` |
| L-06 | Task assignment data structure | verified | `docs/runtime-contracts/task-assignment-queue-contract.md`; `services/agent-api/app/tasks.py`; `verify-phase4-task-assignment-contract-runtime-hosted.ps1`; `verify-phase1-runtime.ps1` |
| L-13 | Branch protection artifact | verified as dry-run/config gate | `.github/workflows/branch-protection.yml`; `scripts/apply_github_branch_protection.py`; `verify-phase1.ps1` |
| L-26 | Hetzner deployment mechanism | verified as pull-based staging/runtime path | `docker-compose.cloud.yml`; `scripts/deploy-to-staging.ps1`; `.github/workflows/main-deploy.yml`; `verify-hosted-staging.ps1` |
| L-27 | LangGraph checkpoint schema init/migration | verified | `docs/runtime-contracts/langgraph-orchestrator.md`; `verify-phase1-runtime.ps1`; hosted orchestrator verifiers |
| L-29 | Rollback runbook | verified | `docs/runbooks/rollback-deploy.md`; phase5 rollback/verifier chain; `verify.ps1 -Suite phase5` |
| L-01 | ADR trigger conditions | covered by governance docs and phase1 verifier | `docs/adr/README.md`; `verify-phase1.ps1` |
| L-14 | Memory read API contract | verified | `services/agent-api/app/memory.py`; `docs/runtime-contracts/memory-consolidation-job.md`; `verify-phase1-runtime.ps1`; hosted memory verifiers |
| L-16 | E2B/tool degradation | verified as MCP degraded-path contract, not live E2B production proof | `verify-phase1-runtime.ps1`; MCP timeout/degraded path checks; `verify-hosted-staging.ps1` |
| L-18 | Langfuse/end-user observability boundary | verified as observability contract/review, not public Langfuse login proof | `docs/runbooks/incident-response.md`; `verify-phase4-observability-hosted.ps1`; `verify.ps1 -Suite phase5` |
| L-31 | Secret scanner tool | verified | `.gitleaks.toml`; `scripts/run-secret-scans.ps1`; `scripts/verify-security.ps1`; `verify.ps1 -Suite security -RefreshSecretScans` |
| L-33 | Supabase keep-alive detail | superseded | `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md` and `ADR-007` remove active Supabase runtime default for Phase 1-5 |

## 4. Improvement Register Mapping

| ID | Required improvement | Current status | Evidence |
| --- | --- | --- | --- |
| V1 | Budget contradiction / server class | verified as patched decision | `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md`; `docs/system-architecture.md`; `verify-phase1.ps1` |
| V2 | LangGraph + CrewAI relation | verified as patched decision | `docs/system-architecture.md`; `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md`; frontend roster references |
| V3 | Remove Qdrant Phase 1-5 | verified | `ADR-007`; `docs/memory/schema.md`; `verify-phase1.ps1` forbidden-term guards |
| V4 | Memory consolidation race | verified as worker/runtime behavior | `services/memory-worker/app/worker.py`; env interval `300`, TTL threshold `480`; `verify-phase1-runtime.ps1` |
| V5 | Budget guard before paid work | verified | `services/agent-api/app/budget.py`; budget endpoints; `verify-phase1-runtime.ps1`; hosted budget verifiers |
| V6 | PostgreSQL split clarity | verified as patched Hetzner/PostgreSQL position | `docker-compose.cloud.yml`; `ADR-007`; `docs/system-architecture.md` |
| V7 | Langfuse DB separation | verified in cloud compose | `docker-compose.cloud.yml` has `LANGFUSE_DB_NAME`, `LANGFUSE_DB_USER`, `LANGFUSE_DB_PASSWORD` |
| V8 | Context-window budget management | contractually covered | LLM routing policy and memory injection constraints are documented; no live provider-token proof claimed |
| V9 | SSE reconnect/replay | verified | `Last-Event-ID` replay in session/orchestrator streams; `verify-phase1-runtime.ps1`; hosted stream verifiers |
| V10 | Done validation authority | verified | result aggregation and task policy gates; `verify-phase1-runtime.ps1`; autonomy suite |
| V11 | Infra budget tracking | verified | `.github/workflows/infra-cost-check.yml`; `scripts/check_hetzner_infra_budget.py`; `GET /api/v1/infra/budget`; hosted/runtime verifiers |
| V12 | Re-embedding strategy | verified | `docs/runtime-contracts/memory-embedding-consistency-contract.md`; migration column `embedding_model_version`; hosted/runtime verifiers |
| V13 | Agent self-assessment bias | verified as orchestrator/worker gate | task policy, result aggregation, autonomy, worker regression verifiers |
| V14 | Single-region runbook | implemented and verified in this pass | `docs/runbooks/single-region-frankfurt-outage.md`; `verify-single-region-runbook.ps1` |

## 5. Risk Register Mapping

| Risk | Current status | Evidence |
| --- | --- | --- |
| R-NEW-01 Memory race condition | verified mitigation | 5-minute consolidation, TTL threshold, worker proof in `verify-phase1-runtime.ps1` |
| R-NEW-02 Context exhaustion | contractually mitigated | memory/context policy docs and LLM gateway routing constraints; no live-provider claim |
| R-NEW-03 LiteLLM SPOF | mitigated by container health/restart and provider failover drill | `llm-gateway` healthchecks; `verify-phase5-provider-failover-drill.ps1` |
| R-NEW-04 Embedding decommission | verified mitigation | `embedding_model_version`; re-embedding policy contract; `verify-phase4-memory-embedding-consistency-hosted.ps1` |
| F21 Single-region dependency | explicit runbook added | `single-region-frankfurt-outage.md`; `verify-single-region-runbook.ps1` |
| F22 LiteLLM SPOF | see R-NEW-03 | healthcheck + failover drill |
| F23 Embedding lock | see R-NEW-04 | versioned embedding contract |
| F24 Agent self-assessment bias | see V13 | orchestrator/result aggregation/worker regression gates |

## 6. Required Decisions And Owner Gates

| Decision | Current state |
| --- | --- |
| RD-01 Hetzner server type | decided in patched docs: CX21 or comparable small Hetzner start |
| RD-02 Shared PostgreSQL vs separate instances | decided: shared PostgreSQL instance, separate DBs |
| RD-03 Qdrant active or Phase-6 option | decided: Qdrant excluded Phase 1-5 |
| RD-04 LangGraph + CrewAI relation | decided: LangGraph global state machine, CrewAI only nested/local if used |
| RD-05 Supabase vs Hetzner PostgreSQL split | superseded by ADR-007 / patched architecture; active default is PostgreSQL/pgvector |
| RD-06 Staging strategy | implemented as hosted staging with documented `https://188-34-191-140.sslip.io` proof path |
| OQ-07 repo public/private | not autonomously verified; current git remote is GitHub, but repository visibility requires GitHub credential/API proof |

## 7. Verification Commands Executed

Passed:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1 -Suite phase1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1 -Suite security -RefreshSecretScans
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1 -Suite phase1-runtime
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1 -Suite browser-contract -AllowLocalhost
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1 -Suite autonomy -AllowLocalhost
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1 -Suite cloud-only-staging -BaseUrl https://188-34-191-140.sslip.io
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1 -Suite hosted-staging-smoke -BaseUrl https://188-34-191-140.sslip.io
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1 -Suite hosted-staging -BaseUrl https://188-34-191-140.sslip.io
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1 -Suite phase5 -BaseUrl https://188-34-191-140.sslip.io
```

Registry:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1 -List
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1 -Plan -Suite all
```

Observed registry result:

- suite `all` covers all `verify-*.ps1`
- suite `all` resolves to `140` verifier scripts after adding the single-region verifier

## 8. External Gate Truth

`verify.ps1 -Suite external-gates` passed as a verifier, but the gate payload is
not fully green. It reports `status=action_required`.

Current missing or failed gates from the latest run:

- `hosted_agent_api_contracts`
- `vercel_backend_origin_health`
- `hetzner_live_budget_check`

This means:

- hosted staging proof exists and passed through dedicated hosted verifiers
- production deployment remains not claimable
- some external provider checks still require live credentials or external owner action

## 9. Current Non-Claims

These claims must not be made:

1. "Production is deployed."
2. "Mutable `:staging` equals the immutable release candidate."
3. "All external provider gates are fully configured."
4. "GitHub repository visibility / OQ-07 is verified."
5. "Docker readiness is proven by process list."
6. "Localhost proof equals cloud proof."
7. "Multi-region failover exists."

## 10. Current Verified Claims

These claims are supported by verifiers from this pass:

1. Docker was ready when elevated `docker info` returned ServerVersion `29.4.1`.
2. Local dev stack can reach all service health gates and passed `phase1-runtime`.
3. Browser-visible local contracts passed.
4. Hosted staging root/API/MCP/LLM/progress/contract surfaces passed.
5. Cloud-only staging proof passed.
6. Phase 5 release-readiness and rollback/candidate proof chain passed.
7. Security scan gate passed with gitleaks finding `0`.
8. `detect-secrets` still reports a baseline of 28 findings; these remain review inventory, not green-field absence.
9. External gates remain partially action-required.

## 11. Bottom Line

The document's technical checklist has been mapped and most implementation
claims now have concrete repository or runtime evidence. Two categories remain
deliberately fail-closed:

1. external provider gates that require live credentials or owner action
2. production deployment / immutable candidate parity, which is explicitly
   blocked by the current staging-parity and repo-worktree-parity artifacts
