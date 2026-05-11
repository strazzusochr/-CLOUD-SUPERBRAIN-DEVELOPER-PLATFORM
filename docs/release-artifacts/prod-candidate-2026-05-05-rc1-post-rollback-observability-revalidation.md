# Executed Candidate Post-Rollback Observability Revalidation

Status: `verified`
release_id: `prod-candidate-2026-05-05-rc1`
environment: `production-candidate`
base_url: `https://188-34-191-140.sslip.io`
executed_at_utc: `2026-05-07T08:22:00Z`
revalidation_scope: `post_rollback_observability_runtime_truth`

## Goal

Record the executed post-rollback observability revalidation for the current production-candidate after immutable rollback, restore, requalification, and stability watch, without claiming rollout.

## Reviewed Endpoints

1. `GET /api/v1/health`
2. `GET /api/v1/project/progress`
3. `GET /api/v1/project/progress/integrity`
4. `GET /api/v1/metrics`
5. `GET /api/v1/audit/recent?limit=5`
6. `GET /api/v1/escalations/recent?limit=5`
7. `GET /api/v1/external-gates`

## Results

- Agent API health: `200`
- Progress remained: `overall=70`, `phase5=67`
- Progress integrity remained: `verified`
- Metrics endpoint available: `200`
- Metrics exposed project progress gauge: `superbrain_project_progress_percent`
- Audit feed available: `200`
- Escalation feed available: `200`
- External gates remained: `verified`
- Candidate decision remained: `no-release`

## Evidence Links

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-requalification.md`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-stability-watch.md`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-promotion-gate-refusal.md`

## Non-Claims

- This is not a production rollout proof.
- This is not a live provider claim.
- This does not override the current `no-release` decision.
