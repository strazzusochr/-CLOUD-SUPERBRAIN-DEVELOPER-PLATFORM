# Integration Plan

Status: `verified`
release_id: `prod-candidate-2026-05-05-rc1`
environment: `production-candidate`
base_url: `https://188-34-191-140.sslip.io`
scope: `frontend, agent-api, mcp-gateway, llm-gateway, nginx/caddy, hosted staging truth`

## Goal

Define the exact repeatable integration and smoke path for this production-candidate without claiming rollout.

## Hosted Target

- Base URL: `https://188-34-191-140.sslip.io`
- Environment: `production-candidate`
- Current selector: `IMAGE_TAG=staging`
- Rollback selector: `IMAGE_TAG=ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`

## Ordered Smoke Sequence

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

## Expected Outcomes

- hosted root responds `200`
- hosted Agent API responds `200`
- hosted MCP Gateway responds `200`
- hosted LLM Gateway responds `200`
- project progress remains manifest-backed
- integrity remains `verified`
- completion remains `can_set_all_to_100=false`
- external gates remain `status=verified`
- external gate mirror remains `status=verified`
- deployment preflight remains `status=verified`
- candidate verifier passes
- rollback drill verifier passes

## Failure Handling

- stop Phase-5 advancement on any hosted health failure
- stop Phase-5 advancement on manifest/runtime drift
- stop Phase-5 advancement if external gates regress
- keep candidate `no-release` if rollback drill verification fails

## Evidence Links

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-browser-revalidation.md`
- `.phase1-artifacts/phase5-rollback-drill-prod-candidate-20260505-rc1.md`
- `.phase1-artifacts/phase5-owner-decision-no-release-20260505.md`

## Non-Claims

- This is not a production rollout plan.
- This is not an executed production smoke run.
- This is not owner approval to release.
