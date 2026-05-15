# RC1 Active MCP Success Correlation Immutable Staging Proof - 2026-05-15

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
candidate_sha: `c0a9d461615e4ccad2397fb6c0821659969ede4d`
source_commit_sha: `c0a9d461615e4ccad2397fb6c0821659969ede4d`
immutable_image_commit_sha: `c0a9d461615e4ccad2397fb6c0821659969ede4d`
runtime_selector: `IMAGE_TAG=c0a9d461615e4ccad2397fb6c0821659969ede4d`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:c0a9d461615e4ccad2397fb6c0821659969ede4d`
production_rollout_claimed: `false`

## Evidence

- Docker readiness returned server version `29.4.1`.
- All six GHCR service images were built and pushed for `linux/arm64` under tag `c0a9d461615e4ccad2397fb6c0821659969ede4d`.
- Hetzner staging was deployed with `scripts\deploy-to-staging.ps1 -ImageTag c0a9d461615e4ccad2397fb6c0821659969ede4d -UseImageFilesystem -KeyPath <local-private-key>`.
- Remote selector reported `IMAGE_TAG=c0a9d461615e4ccad2397fb6c0821659969ede4d`.
- Hosted progress returned `overall=81`, `phase_5=83`, and `mcp_gateway=67`.
- Current parity verifier command: `scripts\verify-current-immutable-staging-parity.ps1 -RequireVerified -ReleaseId prod-candidate-2026-05-11-rc1 -ExpectedImageTag c0a9d461615e4ccad2397fb6c0821659969ede4d -BaseUrl https://188-34-191-140.sslip.io -KeyPath <local-private-key>`.

## Non-Claims

- This proof is staging-candidate evidence only.
- No production rollout was performed.
- No release promotion was performed.
- No live provider call, live MCP write, local model download, or secret exposure is claimed.
