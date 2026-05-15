# Phase 2 Runtime Dual Surface Proof

release_id: `prod-candidate-2026-05-11-rc1`
status: `verified`
verified_at: `2026-05-14T22:45:00+02:00`
hosted_staging_url: `https://188-34-191-140.sslip.io/`
local_control_plane_url: `http://localhost:8081/`
runtime_image_tag: `4364d31d7f1e6d0dec1f4d9f686715fec41d3b35`
production_rollout_claimed: `false`

## Scope

This proof binds the active RC1 Phase 2 runtime contract to both local and hosted runtime surfaces without changing production.

Verified surfaces:

- `GET /api/v1/phase2/runtime/contract`
- `GET /api/v1/phase2/runtime/start/contract`
- `POST /api/v1/phase2/runtime/start`
- `GET /api/v1/phase2/runtime/runs/contract`
- `GET /api/v1/phase2/runtime/runs?limit=10`
- `GET /`

## Evidence

- Runtime contract: `phase2-runtime-v1`
- Start surface contract: `phase2-runtime-start-surface-v1`
- Runs surface contract: `phase2-runtime-runs-surface-v1`
- Runtime mode: `deterministic_local_runtime`
- Runs mode: `audit_log_backed_phase2_runtime_runs`
- Engine: `langgraph`
- Checkpointing: `postgres`
- Evidence refs: `phase2_runtime_graph_started`, `phase2_sse_event_contract_proof`, `langgraph_mcp_timeout_controlled`, `task_assignment_completed`, `memory_update_persisted`, and `agent_result_aggregation_complete`
- Verified roles: `planner`, `coder`, `tester`, and `devops`
- Guarded claims: `live_provider_calls=false`, `live_mcp_writes=false`, and `production_deploy=false`

## Commands

- Docker readiness: `docker info --format '{{.ServerVersion}}'`
- Parser check: `[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path scripts\verify-phase2-runtime-dual-surface.ps1), [ref]$tokens, [ref]$errors)`
- Local proof: `scripts\verify-phase2-runtime-dual-surface.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Hosted proof: `scripts\verify-phase2-runtime-dual-surface.ps1 -BaseUrl https://188-34-191-140.sslip.io`

## Non-Claims

- No production rollout is claimed.
- No release promotion is claimed.
- No live LLM provider call is claimed.
- No live MCP write is claimed.
- No local model download is claimed.
- No secret value is included in this proof.
