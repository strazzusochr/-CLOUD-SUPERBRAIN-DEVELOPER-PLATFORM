# Immutable Staging Parity Proof

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
candidate_sha: `5abca83a7680ea680a65a8e3e8f70a368ed79db7`
base_url: `https://188-34-191-140.sslip.io`
runtime_selector: `IMAGE_TAG=5abca83a7680ea680a65a8e3e8f70a368ed79db7`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:5abca83a7680ea680a65a8e3e8f70a368ed79db7`
production_rollout_claimed: `false`
release_promotion_claimed: `false`

## Evidence

- GHCR registry inspection confirmed `linux/arm64` manifests for `agent-api`, `agent-worker`, `memory-worker`, `llm-gateway`, `mcp-gateway`, and `frontend`.
- Hetzner staging was deployed with `scripts\deploy-to-staging.ps1 -ImageTag 5abca83a7680ea680a65a8e3e8f70a368ed79db7 -UseImageFilesystem -KeyPath <local-private-key>`.
- Remote selector reported `IMAGE_TAG=5abca83a7680ea680a65a8e3e8f70a368ed79db7`.
- Hosted project progress returned `overall=80`, `phase_5=80`, `agent_pool=75`, and `memory=73`.
- Current parity verifier command: `scripts\verify-current-immutable-staging-parity.ps1 -RequireVerified -ReleaseId prod-candidate-2026-05-11-rc1 -CandidateSha 5abca83a7680ea680a65a8e3e8f70a368ed79db7 -BaseUrl https://188-34-191-140.sslip.io -KeyPath <local-private-key>`.

## Non-Claims

- This proof does not claim a production rollout.
- This proof does not claim release promotion.
- This proof does not claim live LLM provider calls.
- This proof does not claim live MCP writes.
- This proof does not include secret values.
