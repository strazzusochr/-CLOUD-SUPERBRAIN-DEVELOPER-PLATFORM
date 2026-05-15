# Active Agent Operations Bundle Proof

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
environment: `production-candidate`
source_commit_sha: `c0a9d461615e4ccad2397fb6c0821659969ede4d`
immutable_image_commit_sha: `c0a9d461615e4ccad2397fb6c0821659969ede4d`
base_url: `https://188-34-191-140.sslip.io`
local_control_plane_url: `http://localhost:8081`
production_rollout_claimed: `false`
agent_gate_count: `8`
changed_horizontal: `Phase 5 79->80`
changed_vertical: `Agent Pool 74->75`

## Bound Agent Gates

- `agent-status-runtime-probe`
- `recent-tasks-contract`
- `autonomous-coding-team`
- `autonomous-roster-master-plan-bundle`
- `phase2-runtime-dual-surface`
- `phase3-live-agent-steering`
- `phase3-live-agent-history`
- `evidence-artifact-safety`

## Verification Commands

- Docker readiness: `docker info --format '{{.ServerVersion}}'`
- Build/push: `scripts\build-and-push.ps1 -Tag c0a9d461615e4ccad2397fb6c0821659969ede4d -Builder superbrain_builder`
- Immutable staging deploy: `scripts\deploy-to-staging.ps1 -ImageTag c0a9d461615e4ccad2397fb6c0821659969ede4d -UseImageFilesystem -KeyPath <local-private-key>`
- Local proof: `scripts\verify-phase5-active-agent-operations-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Hosted proof: `scripts\verify-phase5-active-agent-operations-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`

## Non-Claims

- This proof does not claim a production rollout.
- This proof does not claim release promotion.
- This proof does not claim live LLM provider calls.
- This proof does not claim live MCP writes.
- This proof does not claim local model downloads.
- This proof does not include secret values.
