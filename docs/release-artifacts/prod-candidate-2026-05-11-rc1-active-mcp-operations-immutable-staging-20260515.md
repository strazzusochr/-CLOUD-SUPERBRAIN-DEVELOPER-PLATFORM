# RC1 Active MCP Operations Immutable Staging Proof - 2026-05-15

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
candidate_sha: `4ce557f7e195846afa39d89861f296202561f34a`
source_commit_sha: `4ce557f7e195846afa39d89861f296202561f34a`
immutable_image_commit_sha: `4ce557f7e195846afa39d89861f296202561f34a`
base_url: `https://188-34-191-140.sslip.io`
production_rollout_claimed: `false`

## Selector Evidence

- Remote `.env` selector: `IMAGE_TAG=4ce557f7e195846afa39d89861f296202561f34a`.
- Remote frontend service image: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/frontend:4ce557f7e195846afa39d89861f296202561f34a`.
- Immutable tag set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:4ce557f7e195846afa39d89861f296202561f34a`.
- All six GHCR images were inspected for `linux/arm64`: `agent-api`, `agent-worker`, `memory-worker`, `llm-gateway`, `mcp-gateway`, and `frontend`.
- Hosted progress returned `overall=81`, `phase_5=82`, `mcp_gateway=66`, and `active_mcp_operations_runtime_verified`.
- Immutable staging parity command: `scripts\verify-current-immutable-staging-parity.ps1 -RequireVerified -ExpectedImageTag 4ce557f7e195846afa39d89861f296202561f34a -BaseUrl https://188-34-191-140.sslip.io -KeyPath <local-private-key>`.

## Non-Claims

- This proof does not claim a production rollout.
- This proof does not claim release promotion.
- This proof does not claim live LLM provider calls.
- This proof does not claim live MCP writes.
- This proof does not include secret values.
