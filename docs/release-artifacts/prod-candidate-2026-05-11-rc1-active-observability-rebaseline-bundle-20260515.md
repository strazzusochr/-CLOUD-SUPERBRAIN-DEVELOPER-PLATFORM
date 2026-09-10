# Active Observability Rebaseline Bundle Proof

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
environment: `production-candidate`
source_commit_sha: `5053a8c4a2c9a0e6ff245ec3d9e6c5b2a62a5ad1`
immutable_image_commit_sha: `5053a8c4a2c9a0e6ff245ec3d9e6c5b2a62a5ad1`
base_url: `https://188-34-191-140.sslip.io`
local_control_plane_url: `http://localhost:8081`
production_rollout_claimed: `false`
phase5_percent: `89`
observability_layer_percent: `99`
changed_horizontal: `Phase 5 88->89`
changed_vertical: `none; Observability remains 99 pending hosted Langfuse/Grafana owner endpoint proof`

## Evidence

- Docker readiness returned server version `29.4.1`.
- `scripts\build-and-push.ps1 -Tag 5053a8c4a2c9a0e6ff245ec3d9e6c5b2a62a5ad1 -Builder superbrain_builder` built and pushed all six service images for `linux/arm64`.
- `scripts\deploy-to-staging.ps1 -UseImageFilesystem -ImageTag 5053a8c4a2c9a0e6ff245ec3d9e6c5b2a62a5ad1 -KeyPath <local-private-key>` deployed the immutable staging selector.
- Hosted `GET /api/v1/project/progress` returns overall `82`, Phase 5 `89`, and Observability `99`.
- Hosted `GET /api/v1/project/progress/completion` keeps Observability blocked on `hosted_langfuse_or_grafana_proof_requires_owner_configured_endpoint`.
- Hosted observability surfaces cover health, progress integrity, metrics, audit feed, escalation feed, agent activity, Langfuse-style trace access, and gateway-correlation snapshot/risk/timeline.
- A deterministic LLM dry-run seeded a trace row with `live_provider_calls=false` and `audit_persisted=true`; the Langfuse-style trace endpoint read it back from `audit_log`.

## Verification Commands

- `py -3 scripts\verify_project_progress_manifest.py`
- `npm --prefix apps\frontend run build`
- `scripts\verify-phase5-active-observability-rebaseline-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- `scripts\verify-phase5-active-observability-rebaseline-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-hosted-staging-smoke.ps1 -BaseUrl https://188-34-191-140.sslip.io`

## Non-Claims

- This proof does not claim a production rollout.
- This proof does not claim Observability 100%.
- This proof does not claim hosted Langfuse or Grafana ownership.
- This proof does not claim live LLM provider calls.
- This proof does not claim live MCP writes.
- This proof does not claim local model downloads.
- This proof does not include secret values.
