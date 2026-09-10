# RC1 Active Observability Immutable Staging Proof - 2026-05-15

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
candidate_sha: `5053a8c4a2c9a0e6ff245ec3d9e6c5b2a62a5ad1`
source_commit_sha: `5053a8c4a2c9a0e6ff245ec3d9e6c5b2a62a5ad1`
immutable_image_commit_sha: `5053a8c4a2c9a0e6ff245ec3d9e6c5b2a62a5ad1`
runtime_selector: `IMAGE_TAG=5053a8c4a2c9a0e6ff245ec3d9e6c5b2a62a5ad1`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:5053a8c4a2c9a0e6ff245ec3d9e6c5b2a62a5ad1`
production_rollout_claimed: `false`

## Evidence

- Docker readiness returned server version `29.4.1`.
- All six GHCR service images were built and pushed for `linux/arm64` under tag `5053a8c4a2c9a0e6ff245ec3d9e6c5b2a62a5ad1`.
- Hetzner staging was deployed with `scripts\deploy-to-staging.ps1 -ImageTag 5053a8c4a2c9a0e6ff245ec3d9e6c5b2a62a5ad1 -UseImageFilesystem -KeyPath <local-private-key>`.
- Remote selector reported `IMAGE_TAG=5053a8c4a2c9a0e6ff245ec3d9e6c5b2a62a5ad1`.
- Hosted progress returned `overall=82`, `phase5=89`, and `observability=99`.
- Current parity verifier command: `scripts\verify-current-immutable-staging-parity.ps1 -RequireVerified -ReleaseId prod-candidate-2026-05-11-rc1 -CandidateSha 5053a8c4a2c9a0e6ff245ec3d9e6c5b2a62a5ad1 -BaseUrl https://188-34-191-140.sslip.io -KeyPath <local-private-key>`.

## Non-Claims

- This proof is staging-candidate evidence only.
- No production rollout was performed.
- No release promotion was performed.
- No Observability 100% claim is made.
- No live provider call, live MCP write, local model download, or secret exposure is claimed.
