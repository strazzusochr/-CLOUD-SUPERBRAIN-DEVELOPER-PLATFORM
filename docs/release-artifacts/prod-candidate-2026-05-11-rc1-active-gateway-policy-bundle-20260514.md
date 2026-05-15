# Active Gateway Policy Bundle Proof

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
environment: `production-candidate`
source_commit_sha: `4ce557f7e195846afa39d89861f296202561f34a`
immutable_image_commit_sha: `4ce557f7e195846afa39d89861f296202561f34a`
base_url: `https://188-34-191-140.sslip.io`
local_control_plane_url: `http://localhost:8081`
production_rollout_claimed: `false`
gateway_policy_surface_count: `14`
changed_horizontal: `Phase 3 94->95, overall 79->80`
changed_vertical: `LLM Gateway 63->64, MCP Gateway 64->65`

## Verified Surfaces

- `GET /llm/api/v1/health`
- `GET /llm/api/v1/models/catalog`
- `GET /api/v1/audit/llm/contract`
- `GET /api/v1/audit/llm?limit=20`
- `GET /api/v1/audit/llm/snapshot?limit=50`
- `GET /mcp/api/v1/health`
- `GET /mcp/api/v1/capabilities/catalog`
- `GET /api/v1/audit/mcp/contract`
- `GET /api/v1/audit/mcp?limit=20`
- `GET /api/v1/audit/mcp/snapshot?limit=50`
- `GET /api/v1/security/gateway-correlation/contract`
- `GET /api/v1/security/gateway-correlation/snapshot?limit=80`
- `GET /api/v1/security/gateway-correlation/risk-rollup?limit=80`
- `GET /api/v1/security/gateway-correlation/timeline?limit=80`

## Evidence Bound

- LLM Gateway: `llm-model-catalog-v1`, `llm_model_catalog_visible`, `llm-audit-feed-v1`, `read_only_llm_audit_redaction_snapshot`, `llm_audit_snapshot_visible`, `llm_audit_redaction_enforced`, `llm_routing_policy_direct_provider_blocked`, `llm_routing_policy_unknown_model_blocked`
- MCP Gateway: `mcp-capability-catalog-v1`, `mcp_capability_catalog_visible`, `mcp-audit-feed-v1`, `read_only_mcp_audit_redaction_snapshot`, `mcp_audit_snapshot_visible`, `mcp_audit_redaction_enforced`, `mcp_unsupported_toolset_guard`, `mcp_unsupported_capability_guard`
- Gateway Correlation: `gateway-correlation-snapshot-v1`, `gateway-correlation-risk-rollup-v1`, `gateway-correlation-timeline-v1`, `gateway_correlation_redaction_enforced`, `gateway_correlation_no_live_write_guard`
- Runtime policy: `open_source_first=true`, `api_inference_only=true`, `model_downloads=false`, `local_model_downloads_allowed=false`, `live_provider_calls=false`, `live_mcp_writes=false`

## Verification Commands

- `scripts\verify-phase3-active-gateway-policy-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- `scripts\verify-phase3-active-gateway-policy-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase4-llm-model-catalog.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase4-mcp-capability-catalog.ps1 -BaseUrl https://188-34-191-140.sslip.io`

## Non-Claims

- This proof does not claim a production rollout.
- This proof does not claim release promotion.
- This proof does not claim live LLM provider calls.
- This proof does not claim live MCP writes.
- This proof does not claim local model downloads.
- This proof does not claim provider billing proof.
- This proof does not include secret values.
