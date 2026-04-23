# Phase 2 Readiness Matrix

Status: prepared, runtime-blocked
Date: 2026-04-23
Scope: Phase 2 contract readiness for orchestration, agents, LLM gateway, MCP tools, memory, budget control, and verification.

This matrix is the control artifact for moving from prepared contracts to runtime implementation without fake completeness. It maps every Phase 2 work package to the seven-layer architecture, required proof, active blockers, and stop-gates.

## Binding Baseline

- Highest project anchor: `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE.md`, especially Teil 0, Teil 1, and Teil 2.
- Architecture map: `docs/system-architecture.md`.
- Runtime contracts: `docs/runtime-contracts/`.
- Verification register: `docs/verification-register.md`.
- Runtime activation is not allowed until the open gates below are resolved.

## Active Gates

| Gate | Area | Status | Required resolution |
| --- | --- | --- | --- |
| Gate A | Observability boundary | blocked | Confirm separate observability service envelope or write ADR for any deviation. |
| Gate B | Database/checkpointer runtime | blocked | Confirm PostgreSQL-compatible runtime for LangGraph checkpoints and state recovery. |
| Gate C | Memory schema | blocked | Restore `docs/memory/schema.md` or replace it with an ADR-backed canonical schema path. |
| Gate D | Secrets/auth | blocked for live integrations | Do not use pasted tokens. Provision GitHub, provider, DB, and MCP credentials only through a secure secret gate. |
| Gate E | Release/Docker/Main | blocked for release actions | No production deployment, Docker image push, registry publish, merge, or direct write to `main` without human review gate. |

## Work Package Matrix

| Work package | Artifact | Architecture layer | Required proof before runtime claim | Current evidence | Status | Blocking gate |
| --- | --- | --- | --- | --- | --- | --- |
| WP-01 Budget and rate control | `docs/runtime-contracts/budget-rate-control.md` | Layer 4 LLM Gateway, Layer 7 Observability | Budget alert at 80 percent, rate-limit rejection, cache policy, per-agent cost event, audit-safe logs. | Contract prepared and registered; no runtime execution claimed. | contract-ready, runtime-blocked | Gate A, Gate D |
| WP-02 LLM gateway routing | `docs/runtime-contracts/llm-gateway-routing.md` | Layer 4 LLM Gateway | Gateway-only calls, no direct provider path, fallback reason logging, provider rotation log, cost event. | Contract prepared and registered; no provider calls claimed. | contract-ready, runtime-blocked | Gate A, Gate D |
| WP-03 LangGraph orchestrator | `docs/runtime-contracts/langgraph-orchestrator.md` | Layer 2 Orchestration | Node retry counters, global max 5 retry cycles, restart recovery, SSE event envelope, error-state transition. | Contract prepared and registered; no orchestrator runtime claimed. | contract-ready, runtime-blocked | Gate B |
| WP-04 Core agent profiles | `docs/runtime-contracts/core-agent-profiles.md` | Layer 3 Agent Pool | Role rights matrix, task/result envelopes, escalation behavior, no forbidden tool access, no main-branch write. | Contract prepared and registered; no agent containers claimed. | contract-ready, runtime-blocked | Gate D, Gate E |
| WP-05 Memory consolidation | `docs/runtime-contracts/memory-consolidation-job.md` | Layer 6 Memory | Source references, secret redaction, retention policy, atomic writes, rollback path, consolidation schedule. | Contract prepared and registered; missing canonical memory schema is recorded. | contract-ready, runtime-blocked | Gate B, Gate C, Gate D |
| WP-06 MCP toolsets | `docs/runtime-contracts/mcp-toolsets.md` | Layer 5 Tool-MCP | Request/result envelope, timeout abort, audit entry, scope rejection, no local fallback, no GitHub write without branch guard. | Contract prepared and registered; no live MCP, browser, E2B, DB, Docker, or GitHub write claimed. | contract-ready, runtime-blocked | Gate D, Gate E |
| WP-07 Phase 2 verification harness | planned | Cross-layer | End-to-end proof for budget, retry, recovery, fallback, tool timeouts, and audit-safe evidence artifacts. | Not yet implemented; this matrix defines the proof map. | planned, blocked | Gates A, B, C, D |

## Acceptance Test Map

| Test ID | Requirement | Evidence target | Current status |
| --- | --- | --- | --- |
| P2-RT-001 | Budget alert triggers at 80 percent of configured limit. | Test log plus cost event sample with secrets redacted. | planned, blocked |
| P2-RT-002 | Every orchestration node has retry counter and bounded failure state. | Unit or integration test output plus graph manifest. | planned, blocked |
| P2-RT-003 | Global retry loop stops after max 5 cycles. | Failure-path test output with max-iteration proof. | planned, blocked |
| P2-RT-004 | Checkpointer survives restart and recovers state. | Restart simulation log and recovered task state. | planned, blocked by Gate B |
| P2-RT-005 | Fallback routing logs provider, reason, and cost event. | Gateway test log plus observability event sample. | planned, blocked by Gate A and Gate D |
| P2-RT-006 | Tool timeout aborts safely with audit entry. | MCP timeout test log plus audit event sample. | planned, blocked by Gate D |

## Evidence Ledger

Current evidence:

- Runtime contract index references WP-01 through WP-06 in `docs/runtime-contracts/README.md`.
- Phase 2 plan defines allowed preparation-only work in `docs/PHASE_2_IMPLEMENTATION_PLAN.md`.
- Verification register records the prepared contracts and open blockers in `docs/verification-register.md`.
- Recent contract commits exist for budget/rate, LLM gateway, LangGraph, core agents, memory consolidation, and MCP toolsets.
- WP-05 and WP-06 were verified with staged diff checks, secret scans, and required-section scans before commit.

Missing evidence:

- No Phase 2 runtime implementation has been started.
- No live LLM, MCP, browser, E2B, Docker, DB, or GitHub write integration is active.
- No production CI/CD, deployment, or release checklist has been executed for Phase 2.
- No runtime observability event has been emitted for Phase 2.
- No DB/checkpointer restart recovery has been proven.

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

1. Resolve Gate C by restoring `docs/memory/schema.md` or replacing it through ADR.
2. Resolve Gate A with the smallest separate observability service envelope.
3. Resolve Gate B with a DB/checkpointer decision package.
4. Add WP-07 as a verification-harness contract before any runtime implementation.
5. Only after those gates are resolved, start runtime scaffolding on a feature branch with bounded tests and evidence artifacts.

## Non-Claims

- This document does not claim that Phase 2 is implemented.
- This document does not claim that runtime integration works.
- This document does not claim release readiness.
- This document does not authorize secret usage, Docker push, production deployment, or main-branch writes.
