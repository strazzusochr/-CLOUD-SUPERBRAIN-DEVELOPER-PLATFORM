# RC1 Active Memory Success Correlation Bundle - 2026-05-15

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
source_commit_sha: `c0a9d461615e4ccad2397fb6c0821659969ede4d`
immutable_image_commit_sha: `c0a9d461615e4ccad2397fb6c0821659969ede4d`
base_url: `https://188-34-191-140.sslip.io`
production_rollout_claimed: `false`
memory_success_gate_count: `6`
changed_horizontal: `Phase 5 85->86`
changed_vertical: `Memory 73->74`

## Verified Commands

- `docker info --format '{{.ServerVersion}}'`
- `py -3 -m compileall services\agent-api\app`
- `py -3 scripts\verify_project_progress_manifest.py`
- `scripts\build-and-push.ps1 -Tag c0a9d461615e4ccad2397fb6c0821659969ede4d -Builder superbrain_builder`
- `scripts\deploy-to-staging.ps1 -ImageTag c0a9d461615e4ccad2397fb6c0821659969ede4d -UseImageFilesystem -KeyPath <local-private-key>`
- `scripts\verify-phase5-active-memory-success-correlation-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- `scripts\verify-phase5-active-memory-success-correlation-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase5-active-verifier-sweep-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-evidence-artifact-safety.ps1`

## Runtime Evidence

- Hosted project progress returned `overall=81`, `phase_5=86`, `memory=74`, and status marker `active_memory_success_correlation_bundle_verified`.
- The verifier posted a deterministic prompt with explicit `session_id`, `trace_id`, and `request_id`.
- The prompt response, memory search result, global audit feed, agent-activity feed, and session-history surface exposed the same request, trace, session, and memory id.
- Memory success audit rows kept `live_provider_calls=false`, `live_mcp_writes=false`, and `live_embedding_provider_calls=false`.

## Non-Claims

- This proof does not claim a production rollout.
- This proof does not claim release promotion.
- This proof does not claim live embedding provider calls.
- This proof does not claim live MCP writes.
- This proof does not claim local model downloads.
- This proof does not include secret values.
