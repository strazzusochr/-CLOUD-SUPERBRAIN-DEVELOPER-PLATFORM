# RC1 Active MCP Guard Correlation Bundle - 2026-05-15

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
source_commit_sha: `5053a8c4a2c9a0e6ff245ec3d9e6c5b2a62a5ad1`
immutable_image_commit_sha: `5053a8c4a2c9a0e6ff245ec3d9e6c5b2a62a5ad1`
base_url: `https://188-34-191-140.sslip.io`
local_control_plane_url: `http://localhost:8081`
production_rollout_claimed: `false`
mcp_guard_gate_count: `8`
changed_horizontal: `Phase 5 87->88`
changed_vertical: `MCP Gateway 67->68`

## Verified Commands

- `docker info --format '{{.ServerVersion}}'`
- `py -3 -m compileall services\agent-api\app services\mcp-gateway\app`
- `py -3 scripts\verify_project_progress_manifest.py`
- `scripts\build-and-push.ps1 -Tag 5053a8c4a2c9a0e6ff245ec3d9e6c5b2a62a5ad1 -Builder superbrain_builder`
- `scripts\deploy-to-staging.ps1 -ImageTag 5053a8c4a2c9a0e6ff245ec3d9e6c5b2a62a5ad1 -UseImageFilesystem -KeyPath <local-private-key>`
- `scripts\verify-phase5-active-mcp-guard-correlation-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- `scripts\verify-phase5-active-mcp-guard-correlation-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase5-active-verifier-sweep-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-evidence-artifact-safety.ps1`

## Runtime Evidence

- Hosted project progress returned `overall=82`, `phase_5=88`, `mcp_gateway=68`, and status marker `active_mcp_guard_correlation_bundle_verified`.
- The verifier exercises three deterministic fail-closed `/mcp/api/v1/tools/execute` guard paths: unsupported toolset, PostgreSQL write scope, and unsupported capability.
- Each blocked request is persisted as an MCP audit event with the same `session_id`, `trace_id`, `request_id`, and `tool_request_id` used by the request.
- The MCP audit feed, global audit feed, agent-activity feed, and gateway-correlation timeline expose the blocked guard evidence while keeping `live_mcp_writes=false` and `input_ref_stored=false`.
- Guard evidence refs verified: `mcp_unsupported_toolset_guard`, `mcp_scope_guard`, `mcp_unsupported_capability_guard`, `mcp_denied_tool_audit_correlation`, and `mcp_guard_correlation_audit_visible`.

## Non-Claims

- This proof does not claim a production rollout.
- This proof does not claim release promotion.
- This proof does not claim live LLM provider calls.
- This proof does not claim live MCP writes.
- This proof does not claim local model downloads.
- This proof does not include secret values.
