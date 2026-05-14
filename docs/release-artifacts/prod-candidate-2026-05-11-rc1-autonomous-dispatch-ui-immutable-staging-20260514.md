# Autonomous Team Dispatch UI Immutable Staging Proof

release_id: `prod-candidate-2026-05-11-rc1`
proof_id: `autonomous-dispatch-ui-immutable-staging-20260514`
verified_at: `2026-05-14T02:39:58Z`
Status: `verified`
candidate_sha: `79c3c24dbb3d9907f00733e9d7d3d2238f50cb24`
image_tag: `79c3c24dbb3d9907f00733e9d7d3d2238f50cb24`
environment: `hetzner-staging`
production_rollout_claimed: `false`

## Scope

This proof binds the Autonomous Team Dispatch UI to the immutable staging runtime. It proves that the operator dashboard can submit an objective through `POST /api/v1/task/dispatch`, surface the dispatch/status evidence refs, and refresh the autonomous team/task views without making production claims.

## Local Evidence

- `py -3 -m py_compile services\agent-api\app\main.py`
- `npm run build`
- `scripts\verify-autonomous-coding-team.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`

## Image And Hosted Evidence

- `scripts\build-and-push.ps1 -Tag 79c3c24dbb3d9907f00733e9d7d3d2238f50cb24 -Platforms linux/arm64 -Builder codex-multiarch`
- `scripts\deploy-to-staging.ps1 -UseImageFilesystem -ImageTag 79c3c24dbb3d9907f00733e9d7d3d2238f50cb24 -KeyPath <local-private-key>`
- `IMAGE_TAG=79c3c24dbb3d9907f00733e9d7d3d2238f50cb24`
- `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:79c3c24dbb3d9907f00733e9d7d3d2238f50cb24`
- `scripts\verify-current-immutable-staging-parity.ps1 -RequireVerified`
- `scripts\verify-autonomous-coding-team.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-browser-contract.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-hosted-staging-smoke.ps1 -BaseUrl https://188-34-191-140.sslip.io`

## Evidence Refs

- `autonomous_team_dispatch_visible`
- `autonomous_team_dispatch_ui_visible`
- `autonomous_team_dispatch_status_visible`
- `autonomous_team_dispatch_task_provenance`
- `autonomous_team_dispatch_audit_visible`

## Non-Claims

- No production rollout is claimed.
- No live LLM provider call is claimed.
- No live MCP write is claimed.
- The UI queues scoped objectives only; it does not directly edit files or mutate cloud resources.
