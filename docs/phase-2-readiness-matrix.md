# Phase 2 Readiness Matrix

Status: deterministic-local-runtime-verified
Date: 2026-07-21
Scope: Phase 2 contract readiness for orchestration, agents, LLM gateway, MCP tools, memory, budget control, and verification.

This matrix is the control artifact for moving from prepared contracts to runtime implementation without fake completeness. It maps every Phase 2 work package to the seven-layer architecture, required proof, active blockers, and stop-gates.

## Binding Baseline

- Highest project anchor: `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md`.
- Architecture map: `docs/system-architecture.md`.
- Runtime contracts: `docs/runtime-contracts/`.
- Verification register: `docs/verification-register.md`.
- Phase 1 runtime activation is proven on the local Compose stack. Phase 2 live provider/tool activation remains gated by secure secrets and human review for release actions.

## Active Gates

| Gate | Area | Status | Required resolution |
| --- | --- | --- | --- |
| Gate A | Observability boundary | phase1-resolved | `GET /api/v1/metrics`, audit log, cost endpoint, rotation events, and escalation feed provide the Phase 1 runtime observability envelope. External Prometheus/Grafana remains a deployment gate, not a local runtime blocker. |
| Gate B | Database/checkpointer runtime | resolved | PostgreSQL/pgvector runtime is healthy; migrations apply; six required app tables, pgvector/pgcrypto, and LangGraph checkpoint tables are verified. Runtime verifier restarts `agent-api` and recovers a dry-run by `thread_id`. |
| Gate C | Memory schema | resolved | Canonical schema path is `memory/schema.md`; `memory_entries` exists in PostgreSQL and prompt/internal memory writes are runtime-verified. |
| Gate D | Secrets/auth | blocked for live integrations | Do not use pasted tokens. Provision GitHub, provider, DB, and MCP credentials only through a secure secret gate. |
| Gate E | Release/Docker/Main | blocked for release actions | No production deployment, Docker image push, registry publish, merge, or direct write to `main` without human review gate. |

## Work Package Matrix

| Work package | Artifact | Architecture layer | Required proof before runtime claim | Current evidence | Status | Blocking gate |
| --- | --- | --- | --- | --- | --- | --- |
| WP-01 Budget and rate control | `docs/runtime-contracts/budget-rate-control.md` | Layer 4 LLM Gateway, Layer 7 Observability | Budget alert at 80 percent, rate-limit rejection, cache policy, per-agent cost event, audit-safe logs. | Runtime budget guard, prompt rate limiter, session-call limiter, costs endpoint, hard-stop proof, and metrics are verified. | phase1-runtime-verified | Gate D for live providers |
| WP-02 LLM gateway routing | `docs/runtime-contracts/llm-gateway-routing.md` | Layer 4 LLM Gateway | Gateway-only calls, no direct provider path, fallback reason logging, provider rotation log, cost event. | Configured-only model matrix, rotation policy, and rotation event persistence are verified; no live provider availability is claimed. | phase1-runtime-verified, provider-blocked | Gate D |
| WP-03 LangGraph orchestrator | `docs/runtime-contracts/langgraph-orchestrator.md` | Layer 2 Orchestration | Node retry counters, global max 5 retry cycles, restart recovery, SSE event envelope, error-state transition. | Deterministic LangGraph dry-run is implemented in Agent API and verified through runtime/hosted checks; PostgreSQL checkpointer, restart recovery, dry-run SSE node progress stream, Phase 2 runtime start contract `phase2-runtime-v1`, `phase2_runtime_graph_started` checkpoint/audit evidence, global retry limit hard-stop evidence `langgraph_global_retry_limit_enforced`, bounded node-failure probes for `intent_parser`, `budget_guard`, `task_router`, `agent_executor`, `result_aggregator`, and `memory_updater`, dashboard Progress panel, in-app Browser-triggered `Start Phase 2 Runtime` proof, and Agent Activity per-role feed visibility are verified; worker queue, bounded retries, escalation, SSE, and PostgreSQL persistence are verified. | phase2-runtime-graph-started, global-retry-limit-verified, node-failure-bounded-verified, browser-triggered-runtime-verified, agent-activity-per-role-feed-verified | None for local deterministic runtime; Gate D/E remain closed for live providers/writes |
| WP-04 Core agent profiles | `docs/runtime-contracts/core-agent-profiles.md` | Layer 3 Agent Pool | Role rights matrix, task/result envelopes, escalation behavior, no forbidden tool access, no main-branch write. | Planner, Coder, Tester, and DevOps now execute through the deterministic LangGraph Agent-Executor path with role-specific `TaskAssignment` records, worker-completed result envelopes, G2 done-validation, role-specific MCP proof, and `result.per_role_results[]` aggregation. The aggregator reports `partial_failure=false` only when all four role summaries complete, persists those summaries into the Agent Activity feed, and would expose role-scoped failure reasons if any role is incomplete. Agent-worker heartbeat in health/metrics, max-retry escalation, and branch-protection fail-closed tooling remain verified. | phase1-worker-observable-runtime-verified, four-role-agent-pool-verified, per-role-aggregation-verified, per-role-activity-visible | Gate D, Gate E for live writes |
| WP-05 Memory consolidation | `docs/runtime-contracts/memory-consolidation-job.md` | Layer 6 Memory | Source references, secret redaction, retention policy, atomic writes, rollback path, consolidation schedule. | Prompt-to-memory, internal memory write, lexical search fallback, pgvector schema, memory metrics, Redis-to-PostgreSQL `memory-worker` consolidation, worker heartbeat, filtered consolidation API, frontend panel, in-app Browser panel refresh proof, and Prometheus consolidation counters are verified. The worker runs with a 5-minute interval, 8-minute TTL threshold, idempotency key, secret blocker, and audit events. | phase1-runtime-verified, consolidation-observable, browser-memory-panel-verified | Gate D for embedding provider |
| WP-06 MCP toolsets | `docs/runtime-contracts/mcp-toolsets.md` | Layer 5 Tool-MCP | Request/result envelope, timeout abort, audit entry, scope rejection, no local fallback, no GitHub write without branch guard. | MCP health, request/result envelope, timeout abort, GitHub-main scope block, E2B missing-credentials degraded path, Agent-API audit-log persistence, filtered MCP audit feed, and Prometheus MCP tool counters are verified through runtime and hosted checks. Live write tools remain blocked by secrets and branch protection gate. | phase1-safe-toolpaths-audit-metrics-verified, write-tools-blocked | Gate D, Gate E for live writes |
| WP-07 Phase 2 verification harness | `scripts/verify-phase1-runtime.ps1`, `scripts/verify-hosted-staging.ps1`, `scripts/verify-browser-contract.ps1` | Cross-layer | End-to-end proof for budget, retry, recovery, fallback, tool timeouts, browser-visible runtime controls, memory-consolidation refresh, per-role result aggregation, and audit-safe evidence artifacts. | Phase 1 harness is implemented and green; LangGraph restart recovery, global retry limit hard-stop, protected-node bounded failure probes, LangGraph SSE node progress, repeatable browser-contract harness, Phase-1 MCP safe tool paths, complete four-role aggregation with `partial_failure=false`, and Agent Activity top-level per-role feed visibility are verified. | phase1-harness-verified, global-retry-limit-verified, node-failure-bounded-verified, browser-contract-harness-verified, per-role-aggregation-verified, agent-activity-per-role-feed-verified | Gate D for live providers/tools |

## Acceptance Test Map

| Test ID | Requirement | Evidence target | Current status |
| --- | --- | --- | --- |
| P2-RT-001 | Budget alert triggers at 80 percent of configured limit. | Test log plus cost event sample with secrets redacted. | verified for Phase 1: runtime verifier inserts a temporary 16000-cent cost row, verifies `level=warning`, permits calls, verifies metrics, deletes the row, and confirms `level=ok`; hard-stop at 100 percent is also proven. |
| P2-RT-002 | Every orchestration node has retry counter and bounded failure state. | Unit or integration test output plus graph manifest. | verified for deterministic local runtime: `force_langgraph_node_failure:<node>` probes cover `intent_parser`, `budget_guard`, `task_router`, `agent_executor`, `result_aggregator`, and `memory_updater`; each probe reaches `node_name=hard_stop`, records `<node>_retry_limit_reached`, sets `retry_counters.<node>=5` and `retry_counters.global=5`, persists PostgreSQL checkpoint evidence, and writes audit evidence `langgraph_node_failure_bounded`. |
| P2-RT-003 | Global retry loop stops after max 5 cycles. | Failure-path test output with max-iteration proof. | verified for deterministic local runtime: `force_langgraph_global_retry_limit` stops in `error_handler` with `hard_stop_reason=global_retry_limit_reached`, `retry_counters.global=5`, checkpoint evidence, and audit evidence `langgraph_global_retry_limit_enforced`; worker-level bounded retry escalation is also verified. |
| P2-RT-004 | Checkpointer survives restart and recovers state. | Restart simulation log and recovered task state. | verified: Runtime verifier restarts `agent-api` and recovers `checkpointing=postgres`, `node_name=completed`, and the original `thread_id`; evidence `phase2-postgres-checkpoint-restart-recovery-v1`. |
| P2-RT-005 | Fallback routing logs provider, reason, and cost event. | Gateway test log plus observability event sample. | partially verified: structured rotation event audit is proven; live provider fallback remains blocked by Gate D. |
| P2-RT-006 | Tool timeout aborts safely with audit entry. | MCP timeout test log plus audit event sample. | verified for Phase 1 safe envelope: runtime and hosted verifiers call `POST /mcp/api/v1/tools/execute` with `simulate_timeout` and receive `status=timeout`; GitHub-main scope returns `blocked`; missing E2B credentials return `degraded`; all three responses carry `audit_persisted=true` and are visible as `mcp_tool_executed` records in `/api/v1/audit/recent`. |

## Evidence Ledger

Current evidence:

- Runtime contract index references WP-01 through WP-06 in `docs/runtime-contracts/README.md`.
- Phase 2 plan defines allowed preparation-only work in `docs/PHASE_2_IMPLEMENTATION_PLAN.md`.
- Verification register records Phase 1 runtime proof in `docs/verification-register.md`.
- `scripts/verify-phase1.ps1`, `scripts/verify-phase1-runtime.ps1`, and `scripts/verify-hosted-staging.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` are green.
- `scripts/verify-phase1-runtime.ps1` now waits cleanly through Docker/Nginx recreate windows, retries Session-SSE stream/replay reads through `Wait-SseContains`, and ends with a post-recreate steady-state proof for health, project progress integrity, MCP version pinning, and `/favicon.ico`, so a green local run cannot leave an unverified proxy, empty SSE read, or browser asset regression behind. `scripts/verify-hosted-staging.ps1` uses the same retry-safe Session-SSE probe for the local hosted mirror.
- `phase2-postgres-checkpoint-restart-recovery-v1` under `.codex/runs/CURRENT/master-goal/phase2/checkpoint-restart-recovery-20260721.md` records the final mandatory local proof and its hashed full-runtime logs. Phase 2 is therefore `100%` for deterministic local scope.
- `GET /api/v1/metrics` exposes live budget, queue, service health, memory, and audit counters.
- `GET /api/v1/orchestrator/manifest`, `POST /api/v1/orchestrator/dry-run`, `POST /api/v1/orchestrator/dry-run/stream`, and `GET /api/v1/orchestrator/checkpoints/{thread_id}` prove the Phase 1 LangGraph skeleton, SSE node progress, and PostgreSQL checkpoint recovery without live provider calls; the frontend exposes this as `LangGraph Progress`.
- `GET /api/v1/phase2/runtime/contract` and `POST /api/v1/phase2/runtime/start` prove the deterministic local Phase 2 runtime graph start with `phase2-runtime-v1`, `phase2_runtime_graph_started`, PostgreSQL checkpoint recovery, audit visibility, Agent Activity per-role feed visibility, and frontend `Start Phase 2 Runtime` controls while keeping live-provider, live-MCP-write, and production-deploy gates closed. The runtime now executes all four core agent roles: `planner`, `coder`, `tester`, and `devops`, then aggregates `result.per_role_results[]` with `partial_failure=false` and evidence `agent_result_aggregation_complete`.
- In-app Browser proof opened `http://localhost:8081/`, found one unique `Start Phase 2 Runtime` button, clicked it, and verified visible markers `phase2-runtime-v1`, `phase2_runtime_graph_started`, `live_provider_calls=false`, `LangGraph Progress`, plus screenshot status `phase2-runtime-started`.
- In-app Browser proof found one unique visible `Memory Consolidation` region, clicked its unique `Refresh` button, and verified visible markers `consolidated`, `Idempotency:`, `Reason: consolidated`, and `memory:working:` plus a screenshot with live consolidated entries.
- `scripts/verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -SeedMemoryConsolidation` converts the manual browser proofs into a repeatable harness: it asserts frontend markers, starts the Phase 2 runtime graph through the public API, verifies checkpoint/audit evidence, asserts all four core agent roles complete with role evidence, asserts `result.per_role_results[]`, `partial_failure=false`, `agent_result_aggregation_complete`, and `/api/v1/agent-activity/recent` top-level per-role feed fields, seeds a fresh Redis `memory:working:*` key, runs `memory-worker --once`, and verifies the idempotency key through the public Memory Consolidation feed.
- `POST /api/v1/orchestrator/dry-run` with `force_langgraph_global_retry_limit` proves the deterministic LangGraph max-5 global retry hard-stop through `global_retry_limit_reached`, `retry_counters.global=5`, PostgreSQL checkpoint evidence, and audit evidence `langgraph_global_retry_limit_enforced`.
- `POST /api/v1/orchestrator/dry-run` with `force_langgraph_node_failure:<node>` proves bounded failure for `intent_parser`, `budget_guard`, `task_router`, `agent_executor`, `result_aggregator`, and `memory_updater`; runtime and hosted verifiers assert `node_name=hard_stop`, `<node>_retry_limit_reached`, `retry_counters.<node>=5`, `retry_counters.global=5`, checkpoint evidence, and audit evidence `langgraph_node_failure_bounded`.
- MCP tool audit proof is persisted through Agent API, exposed through `GET /api/v1/audit/mcp`, rendered in the frontend as `MCP Audit`, and exported as `superbrain_mcp_tool_events_total` grouped by `toolset`, `status`, and `error_class`.
- WP-01 through WP-06 have Phase 1 runtime proof where possible without live secrets; WP-04 now includes `agent-worker` heartbeat proof through `/api/v1/health` and `superbrain_service_health{service="agent_worker"}`; WP-05 includes `memory-worker` consolidation proof, filtered API evidence, dashboard evidence, and Prometheus counters; WP-06 safe tool envelopes persist audit evidence through Agent API.

Missing evidence:

- No live LLM provider, E2B, GitHub write, Docker registry push, external browser MCP production integration, or production deployment integration is active.
- No production CI/CD, deployment, or release checklist has been executed for Phase 2.
- No live-provider fallback, live MCP write, external observability sink, or production release evidence has been proven.

## Stop-Gates

The following actions require an explicit review gate before execution:

- Direct write, merge, or push to `main`.
- Production deployment or release promotion.
- Docker image push or registry publish.
- Secret creation, token usage, auth changes, or permission expansion.
- Database migration, production DB write, memory purge, or destructive file operation.
- Live LLM provider activation or direct provider bypass.
- MCP tool activation with write access.
- Architecture deviation from the seven-layer model or OSS-first budget baseline.
- Any local fallback that would violate the no-localhost or no-local-model constraint.

## Next Transition Package

1. Keep `scripts/verify-browser-contract.ps1` wired into CI/manual proof flows for Phase 2 browser-visible runtime controls.
2. Keep Gate D and Gate E closed until secrets, branch protection, and review gates are configured.
3. Next non-secret local hardening target: continue Phase 4 integration contracts that make runtime truth visible without live-provider, live-MCP-write, hosted-staging, or production claims. The deterministic per-role partial-failure probe and Project Progress Integrity proof are already verified.

## Non-Claims

- This document claims the deterministic local Phase 2 runtime is implemented and verified.
- This document does not claim hosted stateful parity or live provider/tool integration.
- This document does not claim release readiness.
- This document does not authorize secret usage, Docker push, production deployment, or main-branch writes.
