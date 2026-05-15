# RC1 Active MCP Operations Immutable Staging Proof - 2026-05-15

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
candidate_sha: `c0a9d461615e4ccad2397fb6c0821659969ede4d`
source_commit_sha: `c0a9d461615e4ccad2397fb6c0821659969ede4d`
immutable_image_commit_sha: `c0a9d461615e4ccad2397fb6c0821659969ede4d`
base_url: `https://188-34-191-140.sslip.io`
production_rollout_claimed: `false`

## Selector Evidence

- Remote `.env` selector: `IMAGE_TAG=c0a9d461615e4ccad2397fb6c0821659969ede4d`.
- Remote frontend service image: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/frontend:c0a9d461615e4ccad2397fb6c0821659969ede4d`.
- Immutable tag set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:c0a9d461615e4ccad2397fb6c0821659969ede4d`.
- All six GHCR images were inspected for `linux/arm64`: `agent-api`, `agent-worker`, `memory-worker`, `llm-gateway`, `mcp-gateway`, and `frontend`.
- Hosted progress returned `overall=81`, `phase_5=82`, `mcp_gateway=66`, and `active_mcp_operations_runtime_verified`.
- Immutable staging parity command: `scripts\verify-current-immutable-staging-parity.ps1 -RequireVerified -ExpectedImageTag c0a9d461615e4ccad2397fb6c0821659969ede4d -BaseUrl https://188-34-191-140.sslip.io -KeyPath <local-private-key>`.

## Non-Claims

- This proof does not claim a production rollout.
- This proof does not claim release promotion.
- This proof does not claim live LLM provider calls.
- This proof does not claim live MCP writes.
- This proof does not include secret values.
