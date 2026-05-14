# prod-candidate-2026-05-11-rc1 Autonomous Roster Master Plan Proof

Date: 2026-05-14
Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
hosted_base_url: `https://188-34-191-140.sslip.io`
local_base_url: `http://localhost:8081`
production_rollout_claimed: `false`

## Scope

This proof binds the active RC1 runtime to the autonomous master-plan and persisted agent-roster surfaces. It verifies that the hosted and local runtime expose the same operator-facing planning and roster evidence without claiming production rollout, live provider calls, live MCP writes, or keeping Codex desktop child threads alive across restarts.

## Evidence

- `GET /api/v1/team/master-plan/contract` exposes `autonomous-master-plan-v1`.
- `GET /api/v1/team/master-plan` exposes `autonomous_master_plan_runtime_visible`, `PROJECT_STATE.md`, the progress manifest, Phase 2 `88`, Phase 5 `74`, Agent Pool `74`, hard constraints, dispatch endpoints, and logical roles `supervisor`, `planner`, `explorer`, `coder`, and `tester`.
- `GET /api/v1/team/roster/contract` exposes `autonomous-agent-roster-v1`.
- `GET /api/v1/team/roster` exposes `autonomous_agent_roster_runtime_visible`, `role_count>=14`, launch-validated generic roles, launcher-blocked specialized roles, LangGraph active binding, and external-adapter status visibility.
- `GET /api/v1/team/status` remains bound to `autonomous-coding-team-v1` and `autonomous-task-dispatch-v1`.
- `GET /api/v1/task/dispatches/recent?limit=10` exposes at least one completed dispatch with all five logical roles carrying `autonomous_team_dispatch_task_provenance`.
- The homepage exposes `Autonomous Master Plan` and `Persisted Agent Roster`.

## Verification

- `docker info --format '{{.ServerVersion}}'`
- `scripts\verify-autonomous-roster-master-plan-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- `scripts\verify-autonomous-roster-master-plan-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-autonomous-master-plan.ps1 -BaseUrl http://localhost:8081`
- `scripts\verify-autonomous-agent-roster.ps1 -BaseUrl http://localhost:8081`
- `scripts\verify-autonomous-master-plan.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-autonomous-agent-roster.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify.ps1 -Suite autonomy -BaseUrl https://188-34-191-140.sslip.io -ReportOnly`

## Non-Claims

This proof does not claim a production rollout.
This proof does not include secret values.
No production deploy, release promotion, live LLM provider call, live MCP write, provider billing proof, external agent uptime guarantee, or SOC/SIEM completeness proof is claimed.
