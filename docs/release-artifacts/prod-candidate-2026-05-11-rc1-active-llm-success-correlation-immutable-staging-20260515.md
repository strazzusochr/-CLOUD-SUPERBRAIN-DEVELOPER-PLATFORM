# RC1 Active LLM Success Correlation Immutable Staging Proof - 2026-05-15

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
candidate_sha: `43783e702ae37ce4e88fe9f309a2488445cd83e1`
source_commit_sha: `43783e702ae37ce4e88fe9f309a2488445cd83e1`
immutable_image_commit_sha: `43783e702ae37ce4e88fe9f309a2488445cd83e1`
runtime_selector: `IMAGE_TAG=43783e702ae37ce4e88fe9f309a2488445cd83e1`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:43783e702ae37ce4e88fe9f309a2488445cd83e1`
production_rollout_claimed: `false`

## Evidence

- Docker readiness returned server version `29.4.1`.
- All six GHCR service images were built and pushed for `linux/arm64` under tag `43783e702ae37ce4e88fe9f309a2488445cd83e1`.
- Hetzner staging was deployed with `scripts\deploy-to-staging.ps1 -ImageTag 43783e702ae37ce4e88fe9f309a2488445cd83e1 -UseImageFilesystem -KeyPath <local-private-key>`.
- Remote selector reported `IMAGE_TAG=43783e702ae37ce4e88fe9f309a2488445cd83e1`.
- Hosted progress returned `overall=81`, `phase_5=84`, and `llm_gateway=66`.
- Current parity verifier command: `scripts\verify-current-immutable-staging-parity.ps1 -RequireVerified -ReleaseId prod-candidate-2026-05-11-rc1 -ExpectedImageTag 43783e702ae37ce4e88fe9f309a2488445cd83e1 -BaseUrl https://188-34-191-140.sslip.io -KeyPath <local-private-key>`.

## Non-Claims

- This proof is staging-candidate evidence only.
- No production rollout was performed.
- No release promotion was performed.
- No live provider call, live MCP write, local model download, or secret exposure is claimed.
