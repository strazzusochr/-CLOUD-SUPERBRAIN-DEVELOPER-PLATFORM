# Executed Candidate Integration Plan Rebaseline

Status: `verified`
release_id: `prod-candidate-2026-05-05-rc1`
environment: `production-candidate`
base_url: `https://188-34-191-140.sslip.io`
executed_at_utc: `2026-05-07T06:00:00Z`
overall_percent: `70`
phase_4_percent: `100`
phase_5_percent: `67`
integrity_status: `verified`
rollback_selector: `IMAGE_TAG=ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`
current_selector: `IMAGE_TAG=staging`
owner_decision: `no-release`

## Goal

Rebaseline the candidate integration path on the current immutable rollback target and the current hosted truth after the completed Phase-4 closure.

## Rebased Hosted Target

- Base URL: `https://188-34-191-140.sslip.io`
- Current selector: `IMAGE_TAG=staging`
- Rollback selector: `IMAGE_TAG=ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`

## Rebased Checks

1. `GET /`
2. `GET /api/v1/health`
3. `GET /mcp/api/v1/health`
4. `GET /llm/api/v1/health`
5. `GET /api/v1/project/progress`
6. `GET /api/v1/project/progress/integrity`
7. `GET /api/v1/project/progress/completion`
8. `GET /api/v1/external-gates`
9. `GET /api/v1/clouds/deployment-preflight`
10. `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`
11. `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-executed-rollback.ps1`

## Hosted Truth Recheck

- `overall=70`
- `phase_4=100`
- `phase_5=63`
- `integrity=verified`
- `completion_can_set_all_to_100=false`

## Non-Claims

- This is not a production rollout plan.
- This does not override the current `no-release` decision.
