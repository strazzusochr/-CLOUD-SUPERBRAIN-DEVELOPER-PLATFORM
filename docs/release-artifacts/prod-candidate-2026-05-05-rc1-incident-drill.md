# Executed Candidate Incident Drill

Status: `verified`
release_id: `prod-candidate-2026-05-05-rc1`
environment: `production-candidate`
base_url: `https://188-34-191-140.sslip.io`
incident_type: `runtime_candidate`
executed_at_utc: `2026-05-07T08:13:20Z`

## Goal

Record the executed candidate-scoped incident and escalation path for the current production-candidate without claiming rollout.

## Simulated Incident

- Trigger: `production-candidate treated as unhealthy for drill purposes`
- Scope: `frontend, agent-api, mcp-gateway, llm-gateway, hosted staging truth`
- Current release decision: `no-release`
- Current progress carried in drill: `overall=70`, `phase5=67`

## Evidence Capture

1. `GET /api/v1/health`
2. `GET /api/v1/project/progress`
3. `GET /api/v1/project/progress/integrity`
4. `GET /api/v1/metrics`
5. `GET /api/v1/audit/recent?limit=5`
6. `GET /api/v1/escalations/recent?limit=5`
7. `GET /api/v1/external-gates`
8. `GET /api/v1/clouds/deployment-preflight`

## Decision Path

- Incident classification: `runtime`
- Release action: `keep candidate stopped / no-release`
- Rollback decision path: `use immutable GHCR tag set :ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5 if hosted health regresses`
- Rollback proof dependency: `.phase1-artifacts/phase5-rollback-drill-prod-candidate-20260505-rc1.md`
- Runbooks used:
  - `docs/runbooks/incident-response.md`
  - `docs/runbooks/rollback-deploy.md`

## Results

- Hosted health endpoint available: `200`
- Progress integrity remained: `verified`
- Metrics endpoint available: `200`
- Audit feed available: `200`
- Escalation feed available: `200`
- External gates remained: `verified`
- Deployment preflight remained: `verified`
- Hosted progress remained manifest-backed: `overall=70`, `phase5=67`
- Next action remained: `no-release`

## Non-Claims

- This is not an executed rollback.
- This is not a production rollout proof.
- This does not override the current `no-release` decision.
