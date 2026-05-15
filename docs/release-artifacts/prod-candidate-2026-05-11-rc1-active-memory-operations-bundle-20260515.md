# Active Memory Operations Bundle Proof

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
environment: `production-candidate`
source_commit_sha: `0065a5e0254dd530b1c3a49f8ce602b8952eafa4`
immutable_image_commit_sha: `0065a5e0254dd530b1c3a49f8ce602b8952eafa4`
base_url: `https://188-34-191-140.sslip.io`
local_control_plane_url: `http://localhost:8081`
production_rollout_claimed: `false`
memory_gate_count: `8`
changed_horizontal: `Phase 5 78->79`
changed_vertical: `Memory 72->73`

## Bound Memory Gates

- `memory-runtime-probe`
- `memory-purge-job-status`
- `memory-search-runtime`
- `memory-contract-surface`
- `phase4-session-memory-parity-hosted`
- `phase4-memory-embedding-consistency-hosted`
- `hosted-staging-smoke`
- `evidence-artifact-safety`

## Verification Commands

- Docker readiness: `docker info --format '{{.ServerVersion}}'`
- Build/push: `scripts\build-and-push.ps1 -Tag 0065a5e0254dd530b1c3a49f8ce602b8952eafa4 -Builder superbrain_builder`
- Immutable staging deploy: `scripts\deploy-to-staging.ps1 -ImageTag 0065a5e0254dd530b1c3a49f8ce602b8952eafa4 -UseImageFilesystem -KeyPath <local-private-key>`
- Local proof: `scripts\verify-phase5-active-memory-operations-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Hosted proof: `scripts\verify-phase5-active-memory-operations-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io -KeyPath <local-private-key>`

## Non-Claims

- This proof does not claim a production rollout.
- This proof does not claim release promotion.
- This proof does not claim live embedding provider calls.
- This proof does not claim live LLM provider calls.
- This proof does not claim live MCP writes.
- This proof does not claim local model downloads.
- This proof does not include secret values.
