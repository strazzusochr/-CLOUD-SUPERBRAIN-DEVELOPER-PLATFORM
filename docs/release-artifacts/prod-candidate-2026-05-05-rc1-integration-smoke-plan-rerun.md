# Candidate Integration Smoke Plan Rerun

Status: `verified`
release_id: `prod-candidate-2026-05-05-rc1`
environment: `production-candidate`
base_url: `https://188-34-191-140.sslip.io`
executed_at_utc: `2026-05-07T16:35:00Z`
overall_percent: `70`
phase_4_percent: `100`
phase_5_percent: `67`
integrity_status: `verified`
external_gates_status: `verified`
current_selector: `IMAGE_TAG=staging`
rollback_selector: `IMAGE_TAG=ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`
owner_decision: `no-release`

## Goal

Rerun the candidate-scoped integration smoke path on the current hosted truth after the later Phase-5 reruns, without changing the no-release gate.

This rerun is the active integration authority for the current RC1 candidate; older integration-plan artifacts remain historical reference inputs only.

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

- hosted root responded `200`
- hosted Agent API responded `200`
- hosted MCP Gateway responded `200`
- hosted LLM Gateway responded `200`
- current progress carried in integration smoke rerun: `overall=70`, `phase4=100`, `phase5=67`
- hosted integrity remained `verified`
- hosted completion remained fail-closed with `can_set_all_to_100=false`
- hosted external gates and mirror remained `verified`
- hosted deployment preflight remained `status=verified`
- candidate verifier passed
- rollback drill verifier remained passed
- candidate decision remained `no-release`

## Reference Inputs

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-plan.md`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-plan-rebaseline.md`
- `.phase1-artifacts/phase5-rollback-drill-prod-candidate-20260505-rc1.md`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-smoke-proof.md`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-smoke-recheck.md`

## Non-Claims

- This is not a production rollout proof.
- This is not an executed production release.
- This does not override the current `no-release` decision.
