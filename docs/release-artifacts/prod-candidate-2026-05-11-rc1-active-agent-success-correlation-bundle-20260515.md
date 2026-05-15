# RC1 Active Agent Success Correlation Bundle - 2026-05-15

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
source_commit_sha: `c0a9d461615e4ccad2397fb6c0821659969ede4d`
immutable_image_commit_sha: `c0a9d461615e4ccad2397fb6c0821659969ede4d`
base_url: `https://188-34-191-140.sslip.io`
production_rollout_claimed: `false`
agent_success_gate_count: `8`
changed_horizontal: `Phase 2 88->89; Phase 5 84->85`
changed_vertical: `Agent Pool 75->76`

## Verified Commands

- `docker info --format '{{.ServerVersion}}'`
- `py -3 -m compileall services\agent-api\app services\agent-worker\app`
- `py -3 scripts\verify_project_progress_manifest.py`
- `scripts\build-and-push.ps1 -Tag c0a9d461615e4ccad2397fb6c0821659969ede4d -Builder superbrain_builder`
- `docker buildx imagetools inspect ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:c0a9d461615e4ccad2397fb6c0821659969ede4d`
- `scripts\deploy-to-staging.ps1 -ImageTag c0a9d461615e4ccad2397fb6c0821659969ede4d -UseImageFilesystem -KeyPath <local-private-key>`
- `scripts\verify-phase5-active-agent-success-correlation-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- `scripts\verify-phase5-active-agent-success-correlation-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase5-active-verifier-sweep-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-current-runtime-selector-truth.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireRemoteProof -KeyPath <local-private-key>`
- `scripts\verify-evidence-artifact-safety.ps1`

## Runtime Evidence

- Hosted project progress returned `overall=81`, `phase_2=89`, `phase_5=85`, `agent_pool=76`, and status marker `active_agent_success_correlation_bundle_verified`.
- The verifier executed a deterministic internal task success path with explicit `session_id`, `trace_id`, and `request_id`.
- The task status, recent-task feed, global audit feed, agent-activity feed, and gateway correlation timeline exposed the same request, trace, and session correlation evidence.
- The verifier executed an autonomous team dispatch success path and confirmed the dispatch record, assignment rows, team status, and dispatch audit all carried the same request/trace/session evidence.
- Agent success audit rows kept `live_provider_calls=false` and `live_mcp_writes=false`.

## Non-Claims

- This proof does not claim a production rollout.
- This proof does not claim release promotion.
- This proof does not claim live LLM provider calls.
- This proof does not claim live MCP writes.
- This proof does not claim local model downloads.
- This proof does not include secret values.
