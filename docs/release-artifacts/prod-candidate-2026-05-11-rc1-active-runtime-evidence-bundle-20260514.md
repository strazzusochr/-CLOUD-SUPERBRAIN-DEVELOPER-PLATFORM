# Active Runtime Evidence Bundle

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
verified_at: `2026-05-14T23:10:00+02:00`
base_url: `https://188-34-191-140.sslip.io`
local_control_plane_url: `http://localhost:8081`
source_commit_sha: `5053a8c4a2c9a0e6ff245ec3d9e6c5b2a62a5ad1`
immutable_image_commit_sha: `5053a8c4a2c9a0e6ff245ec3d9e6c5b2a62a5ad1`
production_rollout_claimed: `false`
runtime_surface_count: `8`

## Scope

This proof binds the active RC1 to read-only runtime evidence on local and hosted staging surfaces. It does not create a deployment and does not perform production mutation.

Verified surfaces:

- `GET /api/v1/project/progress`
- `GET /api/v1/project/progress/integrity`
- `GET /api/v1/phase2/runtime/contract`
- `GET /api/v1/phase2/runtime/runs?limit=5`
- `GET /api/v1/orchestrator/manifest`
- `GET /api/v1/agents/status`
- `GET /api/v1/agent-activity/recent?event_type=phase2_runtime_graph_started&limit=5`
- `GET /api/v1/team/master-plan`, `GET /api/v1/team/roster`, and `GET /api/v1/team/status`

## Evidence

- Overall progress: `82%`
- Phase 2: `89%`
- Phase 5: `87%`
- Runtime contract: `phase2-runtime-v1`
- Runtime runs: `audit_log_backed_phase2_runtime_runs`
- Orchestrator: `langgraph`, `deterministic_dry_run`, `postgres`
- Agent profile contract: `agent-profiles-v1`
- Autonomous master plan: `autonomous-master-plan-v1`
- Autonomous roster: `autonomous-agent-roster-v1`
- Evidence refs: `phase2_runtime_graph_started`, `phase2_runtime_run_status_visible`, `task_assignment_completed`, `memory_update_persisted`, `agent_result_aggregation_complete`, `autonomous_master_plan_runtime_visible`, and `autonomous_agent_roster_runtime_visible`

## Commands

- Docker readiness: `docker info --format '{{.ServerVersion}}'`
- Parser check: `[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path scripts\verify-phase5-active-runtime-evidence-bundle.ps1), [ref]$tokens, [ref]$errors)`
- Local proof: `scripts\verify-phase5-active-runtime-evidence-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Hosted proof: `scripts\verify-phase5-active-runtime-evidence-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`

## Non-Claims

- This proof does not claim a production rollout.
- This proof does not claim release promotion.
- This proof does not claim live LLM provider calls.
- This proof does not claim live MCP writes.
- This proof does not claim local model downloads.
- This proof does not include secret values.
