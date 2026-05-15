# Immutable Staging Parity Proof

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
candidate_sha: `43783e702ae37ce4e88fe9f309a2488445cd83e1`
base_url: `https://188-34-191-140.sslip.io`
runtime_selector: `IMAGE_TAG=43783e702ae37ce4e88fe9f309a2488445cd83e1`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:43783e702ae37ce4e88fe9f309a2488445cd83e1`
production_rollout_claimed: `false`
release_promotion_claimed: `false`

## Evidence

- GHCR registry inspection confirmed `linux/arm64` manifests for `agent-api`, `agent-worker`, `memory-worker`, `llm-gateway`, `mcp-gateway`, and `frontend`.
- Hetzner staging was deployed with `scripts\deploy-to-staging.ps1 -ImageTag 43783e702ae37ce4e88fe9f309a2488445cd83e1 -UseImageFilesystem -KeyPath <local-private-key>`.
- Remote selector reported `IMAGE_TAG=43783e702ae37ce4e88fe9f309a2488445cd83e1`.
- Hosted project progress returned `overall=80` and `phase_5=78`.
- Current parity verifier command: `scripts\verify-current-immutable-staging-parity.ps1 -RequireVerified -ReleaseId prod-candidate-2026-05-11-rc1 -CandidateSha 43783e702ae37ce4e88fe9f309a2488445cd83e1 -BaseUrl https://188-34-191-140.sslip.io -KeyPath <local-private-key>`.

## Non-Claims

- This proof does not claim a production rollout.
- This proof does not claim release promotion.
- This proof does not claim live LLM provider calls.
- This proof does not claim live MCP writes.
- This proof does not include secret values.
