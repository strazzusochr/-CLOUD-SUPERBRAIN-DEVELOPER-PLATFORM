# Task Assignment Queue Contract

Status: Implemented local runtime contract
Date: 2026-04-29
Phase: Phase 4 / L-06
Owner layer: Layer 2 to Layer 3 - Agent API / Orchestrator to Agent Pool

## Purpose

This contract closes audit gap `L-06`: the Agent API and Orchestrator must publish the exact task-assignment structure, Redis queue mechanism, status visibility, and backpressure behavior used when work is handed from Layer 2 to the Agent Pool.

## Runtime Endpoints

| Purpose | Method | Path | Evidence |
| --- | --- | --- | --- |
| Public contract | `GET` | `/api/v1/tasks/assignment-contract` | `task_assignment_queue_contract_visible` |
| Public policy validation | `POST` | `/api/v1/tasks/policy/validate` | `task_policy_blocked` / accepted assignment |
| Internal task intake | `POST` | `/internal/tasks` | `task_assignment_completed` only after completed status; otherwise `task_assignment_incomplete` |
| Internal task status | `GET` | `/internal/tasks/{task_id}` | Redis status lookup |
| Public recent task visibility | `GET` | `/api/v1/tasks/recent` | `done_validation` and `result_envelope` visible |
| Agent status visibility | `GET` | `/api/v1/agents/status` | queue depth and latest task state |
| Metrics visibility | `GET` | `/api/v1/metrics` | `superbrain_task_queue_depth` |

## Assignment Schema

Required fields:

- `project_id`: non-empty string.
- `session_id`: UUID string, fail-closed before enqueue.
- `agent_type`: `planner`, `coder`, `tester`, or `devops`.
- `task_type`: string, 1 to 120 characters.
- `task_description`: string, 1 to 10000 characters, redacted before persistence.

Policy-gated fields:

- `priority`: integer from 1 to 10, default `5`.
- `max_retries`: integer from 1 to 5, bounded by agent profile.
- `allowed_tools`: constrained by the role profile.
- `write_scope`: required for coder write-like tasks.
- `blocked_actions`: must include the required global and profile-specific blocked actions.
- `acceptance_criteria`: must include `result_envelope`, `done_validation`, and `audit_log`.
- `human_review_required`: required for deployment-like DevOps tasks.
- `policy_version`: `task-policy-v1`.

## Queue Contract

| Field | Value |
| --- | --- |
| Backend | Redis |
| Queue key | `tasks:agent:queue` for mid/default priority |
| Priority queue keys | `tasks:agent:queue:high`, `tasks:agent:queue`, `tasks:agent:queue:low` |
| Priority order | `high` -> `mid` -> `low` |
| Status key pattern | `task:status:{task_id}` |
| TTL | `86400` seconds |
| Consumer service | `agent-worker` |
| Queue-depth source | Sum of Redis `LLEN` across high/mid/low priority queues |

The Agent API writes the task status before queue publish, then pushes the JSON payload to exactly one priority queue. The worker consumes with `BLPOP` in high/mid/low order, writes `running`, `completed`, `failed`, `escalated`, or `abandoned_after_queue_drain` status, and emits audit events. The legacy/default queue key remains the mid-priority queue, so existing priority `5` tasks stay compatible without duplicate enqueue.

## Backpressure And Failure Semantics

- `fail_closed_before_enqueue`: policy validation runs before a task enters Redis.
- Profile retry limits cap `max_retries` at the role limit.
- Queue depth is visible through public status, recent task feed, and Prometheus metrics.
- Priority routing is fail-closed to one queue per task: `priority >= 8` goes high, `priority 4..7` goes mid, and `priority <= 3` goes low.
- Orchestrator manager roles use high priority: Planner `9`, DevOps `8`; worker roles remain mid priority unless a task explicitly lowers or raises them.
- Orchestrator aggregation refreshes non-terminal assignments and marks drained queued records as `partial_failure` instead of claiming false success.
- Agent Worker reconciles stale queued records after the bounded rescue window using `worker_stale_queued_finalized`.
- Malformed raw queue payloads are ignored without crashing the worker.

## Evidence

- `GET /api/v1/tasks/assignment-contract` returns `task-assignment-queue-contract-v1`.
- Frontend renders `Task Assignment Queue Contract` with `task_assignment_queue_contract_visible`.
- Runtime and hosted verifiers assert the contract, queue key, status key pattern, UUID guard, backpressure text, and evidence refs.
- Runtime and static verifiers assert priority queue keys, priority order, orchestrator assignment priority propagation, and worker high/mid/low `BLPOP` consumption.
- Existing worker-status regression harness proves stale queue rescue and real queue processing.

## Non-Claims

- This contract does not enable live provider calls.
- This contract does not enable live MCP writes.
- This contract does not enable production deploys or main-branch mutations.
