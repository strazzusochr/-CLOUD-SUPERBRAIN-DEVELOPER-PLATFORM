# RC1 Active MCP Success Correlation Immutable Staging Proof - 2026-05-15

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
candidate_sha: `4a894c16d5f340b89ad1134da781d1c855d6ced5`
source_commit_sha: `4a894c16d5f340b89ad1134da781d1c855d6ced5`
immutable_image_commit_sha: `4a894c16d5f340b89ad1134da781d1c855d6ced5`
runtime_selector: `IMAGE_TAG=4a894c16d5f340b89ad1134da781d1c855d6ced5`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:4a894c16d5f340b89ad1134da781d1c855d6ced5`
production_rollout_claimed: `false`

## Evidence

- Docker readiness returned server version `29.4.1`.
- All six GHCR service images were built and pushed for `linux/arm64` under tag `4a894c16d5f340b89ad1134da781d1c855d6ced5`.
- Hetzner staging was deployed with `scripts\deploy-to-staging.ps1 -ImageTag 4a894c16d5f340b89ad1134da781d1c855d6ced5 -UseImageFilesystem -KeyPath <local-private-key>`.
- Remote selector reported `IMAGE_TAG=4a894c16d5f340b89ad1134da781d1c855d6ced5`.
- Hosted progress returned `overall=81`, `phase_5=83`, and `mcp_gateway=67`.
- Current parity verifier command: `scripts\verify-current-immutable-staging-parity.ps1 -RequireVerified -ReleaseId prod-candidate-2026-05-11-rc1 -ExpectedImageTag 4a894c16d5f340b89ad1134da781d1c855d6ced5 -BaseUrl https://188-34-191-140.sslip.io -KeyPath <local-private-key>`.

## Non-Claims

- This proof is staging-candidate evidence only.
- No production rollout was performed.
- No release promotion was performed.
- No live provider call, live MCP write, local model download, or secret exposure is claimed.
