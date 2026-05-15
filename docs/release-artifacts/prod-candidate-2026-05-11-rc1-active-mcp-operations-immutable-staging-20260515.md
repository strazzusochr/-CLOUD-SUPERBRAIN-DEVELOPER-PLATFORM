# RC1 Active MCP Operations Immutable Staging Proof - 2026-05-15

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
candidate_sha: `b9734ad55dc6488a56acca693b50ec9019bab01b`
source_commit_sha: `b9734ad55dc6488a56acca693b50ec9019bab01b`
immutable_image_commit_sha: `b9734ad55dc6488a56acca693b50ec9019bab01b`
base_url: `https://188-34-191-140.sslip.io`
production_rollout_claimed: `false`

## Selector Evidence

- Remote `.env` selector: `IMAGE_TAG=b9734ad55dc6488a56acca693b50ec9019bab01b`.
- Remote frontend service image: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/frontend:b9734ad55dc6488a56acca693b50ec9019bab01b`.
- Immutable tag set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:b9734ad55dc6488a56acca693b50ec9019bab01b`.
- All six GHCR images were inspected for `linux/arm64`: `agent-api`, `agent-worker`, `memory-worker`, `llm-gateway`, `mcp-gateway`, and `frontend`.
- Hosted progress returned `overall=81`, `phase_5=82`, `mcp_gateway=66`, and `active_mcp_operations_runtime_verified`.
- Immutable staging parity command: `scripts\verify-current-immutable-staging-parity.ps1 -RequireVerified -ExpectedImageTag b9734ad55dc6488a56acca693b50ec9019bab01b -BaseUrl https://188-34-191-140.sslip.io -KeyPath <local-private-key>`.

## Non-Claims

- This proof does not claim a production rollout.
- This proof does not claim release promotion.
- This proof does not claim live LLM provider calls.
- This proof does not claim live MCP writes.
- This proof does not include secret values.
