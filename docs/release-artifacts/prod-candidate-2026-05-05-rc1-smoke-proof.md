# Executed Hosted Candidate Smoke Proof

Status: `verified`
release_id: `prod-candidate-2026-05-05-rc1`
environment: `production-candidate`
base_url: `https://188-34-191-140.sslip.io`
executed_at_utc: `2026-05-07T10:12:00Z`

## Goal

Record the executed hosted smoke sequence for the current production-candidate without claiming rollout.

## Executed Sequence

1. `GET /`
2. `GET /api/v1/health`
3. `GET /mcp/api/v1/health`
4. `GET /llm/api/v1/health`
5. `GET /api/v1/project/progress`
6. `GET /api/v1/project/progress/integrity`
7. `GET /api/v1/project/progress/completion`
8. `GET /api/v1/external-gates`
9. `GET /api/v1/external-gates/mirror`
10. `GET /api/v1/clouds/deployment-preflight`
11. `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`
12. `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-rollback-drill.ps1`

## Results

- Root HTML: `200`
- Root title marker: `Cloud Superbrain`
- Root markers visible in HTML: `Cloud Superbrain`, `Project Progress`, `External Gates`
- Agent API health: `200`
- MCP Gateway health: `200`
- LLM Gateway health: `200`
- Project Progress: `overall=70`, `phase4=100`, `phase5=67`
- Progress Integrity: `status=verified`
- Completion Contract: `can_set_all_to_100=false`
- External Gates: `status=verified`
- External Gate Mirror: `status=verified`
- Deployment Preflight: `status=verified`
- Candidate Verifier: `passed`
- Rollback Drill Verifier: `passed`

## Evidence Links

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-plan.md`
- `.phase1-artifacts/phase5-rollback-drill-prod-candidate-20260505-rc1.md`
- `.phase1-artifacts/phase5-owner-decision-no-release-20260505.md`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-browser-revalidation.md`

## Non-Claims

- This is not a production rollout proof.
- This is not owner approval to release.
- This does not override the current `no-release` decision.
