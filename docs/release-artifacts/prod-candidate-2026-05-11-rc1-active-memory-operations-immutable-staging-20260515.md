# Immutable Staging Parity Proof

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
candidate_sha: `984254f78c3f9fe0363ac2e8f3468f4b1c49ab05`
base_url: `https://188-34-191-140.sslip.io`
runtime_selector: `IMAGE_TAG=984254f78c3f9fe0363ac2e8f3468f4b1c49ab05`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:984254f78c3f9fe0363ac2e8f3468f4b1c49ab05`
production_rollout_claimed: `false`
release_promotion_claimed: `false`

## Evidence

- GHCR registry inspection confirmed `linux/arm64` manifests for `agent-api`, `agent-worker`, `memory-worker`, `llm-gateway`, `mcp-gateway`, and `frontend`.
- Hetzner staging was deployed with `scripts\deploy-to-staging.ps1 -ImageTag 984254f78c3f9fe0363ac2e8f3468f4b1c49ab05 -UseImageFilesystem -KeyPath <local-private-key>`.
- Remote selector reported `IMAGE_TAG=984254f78c3f9fe0363ac2e8f3468f4b1c49ab05`.
- Hosted project progress returned `overall=80`, `phase_5=79`, and `memory=73`.
- Current parity verifier command: `scripts\verify-current-immutable-staging-parity.ps1 -RequireVerified -ReleaseId prod-candidate-2026-05-11-rc1 -CandidateSha 984254f78c3f9fe0363ac2e8f3468f4b1c49ab05 -BaseUrl https://188-34-191-140.sslip.io -KeyPath <local-private-key>`.

## Non-Claims

- This proof does not claim a production rollout.
- This proof does not claim release promotion.
- This proof does not claim live LLM provider calls.
- This proof does not claim live MCP writes.
- This proof does not include secret values.
