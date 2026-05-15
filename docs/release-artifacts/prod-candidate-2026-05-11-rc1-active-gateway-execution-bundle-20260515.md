# Active Gateway Execution Bundle Proof

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
environment: `production-candidate`
source_commit_sha: `9d8469801b1dcdf8f8e4cd326be258389c0f8183`
immutable_image_commit_sha: `9d8469801b1dcdf8f8e4cd326be258389c0f8183`
base_url: `https://188-34-191-140.sslip.io`
local_control_plane_url: `http://localhost:8081`
production_rollout_claimed: `false`
execution_gate_count: `8`
changed_horizontal: `Phase 5 77->78`
changed_vertical: `none`

## Bound Execution Gates

- `phase2-runtime-dual-surface`
- `phase4-agent-llm-streaming-contract-runtime`
- `phase4-mcp-devops-hosted`
- `phase3-gateway-correlation-snapshot`
- `phase3-gateway-correlation-risk-rollup`
- `phase3-gateway-correlation-timeline`
- `hosted-staging-smoke`
- `evidence-artifact-safety`

## Verification Commands

- Docker readiness: `docker info --format '{{.ServerVersion}}'`
- Build/push: `scripts\build-and-push.ps1 -Tag 9d8469801b1dcdf8f8e4cd326be258389c0f8183 -Builder superbrain_builder`
- Immutable staging deploy: `scripts\deploy-to-staging.ps1 -ImageTag 9d8469801b1dcdf8f8e4cd326be258389c0f8183 -UseImageFilesystem -KeyPath <local-private-key>`
- Local proof: `scripts\verify-phase5-active-gateway-execution-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Hosted proof: `scripts\verify-phase5-active-gateway-execution-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`

## Non-Claims

- This proof does not claim a production rollout.
- This proof does not claim release promotion.
- This proof does not claim live LLM provider calls.
- This proof does not claim live MCP writes.
- This proof does not claim local model downloads.
- This proof does not include secret values.
