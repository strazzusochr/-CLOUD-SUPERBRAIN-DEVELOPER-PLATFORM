# Executed Candidate Provider Failover Drill

Status: `verified`
release_id: `prod-candidate-2026-05-05-rc1`
environment: `production-candidate`
base_url: `https://188-34-191-140.sslip.io`
provider_scope: `llm_gateway_routing`
executed_at_utc: `2026-05-07T09:45:00Z`

## Goal

Record the executed candidate-scoped provider-failover decision path for the current production-candidate without claiming any live external provider switch.

## Simulated Failover

- Trigger: `provider degradation / timeout drill`
- Affected provider class: `external llm provider`
- Runtime scope: `llm-gateway routing policy and orchestrator preflight`
- Current release decision: `no-release`

## Evidence Capture

1. `docs/runbooks/provider-failover.md`
2. `GET /llm/api/v1/health`
3. `GET /api/v1/health`
4. `GET /api/v1/project/progress`
5. `GET /api/v1/project/progress/integrity`
6. `GET /api/v1/external-gates`
7. `GET /api/v1/clouds/deployment-preflight`
8. `GET /api/v1/audit/recent?limit=5`

## Decision Path

- Failover classification: `candidate_provider_failover`
- External live provider switch executed: `no`
- Reason: `no-release candidate and no live provider claim`
- Fallback route: `keep dry-run/fail-closed routing policy`
- Escalation gate: `owner review required before external provider switch`
- Runbooks used:
  - `docs/runbooks/provider-failover.md`
  - `docs/runbooks/incident-response.md`
  - `docs/runbooks/rollback-deploy.md`

## Results

- Hosted LLM health endpoint available: `200`
- Hosted Agent API health endpoint available: `200`
- Progress endpoint remained manifest-backed: `overall=70`, `phase5=67`
- Progress integrity remained: `verified`
- External gates remained: `verified`
- Deployment preflight remained: `verified`
- Audit feed remained available: `200`
- Candidate stayed: `no-release`

## Non-Claims

- This is not a live external provider failover.
- This does not claim live provider traffic.
- This does not override the current `no-release` decision.
