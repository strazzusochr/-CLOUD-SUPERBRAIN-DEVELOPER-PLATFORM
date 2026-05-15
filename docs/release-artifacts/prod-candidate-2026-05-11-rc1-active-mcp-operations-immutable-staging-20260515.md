# RC1 Active MCP Operations Immutable Staging Proof - 2026-05-15

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
candidate_sha: `4a894c16d5f340b89ad1134da781d1c855d6ced5`
source_commit_sha: `4a894c16d5f340b89ad1134da781d1c855d6ced5`
immutable_image_commit_sha: `4a894c16d5f340b89ad1134da781d1c855d6ced5`
base_url: `https://188-34-191-140.sslip.io`
production_rollout_claimed: `false`

## Selector Evidence

- Remote `.env` selector: `IMAGE_TAG=4a894c16d5f340b89ad1134da781d1c855d6ced5`.
- Remote frontend service image: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/frontend:4a894c16d5f340b89ad1134da781d1c855d6ced5`.
- Immutable tag set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:4a894c16d5f340b89ad1134da781d1c855d6ced5`.
- All six GHCR images were inspected for `linux/arm64`: `agent-api`, `agent-worker`, `memory-worker`, `llm-gateway`, `mcp-gateway`, and `frontend`.
- Hosted progress returned `overall=81`, `phase_5=82`, `mcp_gateway=66`, and `active_mcp_operations_runtime_verified`.
- Immutable staging parity command: `scripts\verify-current-immutable-staging-parity.ps1 -RequireVerified -ExpectedImageTag 4a894c16d5f340b89ad1134da781d1c855d6ced5 -BaseUrl https://188-34-191-140.sslip.io -KeyPath <local-private-key>`.

## Non-Claims

- This proof does not claim a production rollout.
- This proof does not claim release promotion.
- This proof does not claim live LLM provider calls.
- This proof does not claim live MCP writes.
- This proof does not include secret values.
