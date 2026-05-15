# Active Frontend-Orchestrator Evidence Bundle Proof

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
environment: `production-candidate`
source_commit_sha: `6292a2f3c0cf0cfe02916f6fd0a6f940629adc52`
immutable_image_commit_sha: `6292a2f3c0cf0cfe02916f6fd0a6f940629adc52`
base_url: `https://188-34-191-140.sslip.io`
local_control_plane_url: `http://localhost:8081`
production_rollout_claimed: `false`
frontend_layer_percent: `100`
orchestrator_layer_percent: `100`
changed_vertical: `Frontend / Next.js 99->100; Orchestrator / LangGraph 99->100`

## Evidence

- Docker readiness returned server version `29.4.1`.
- `scripts\build-and-push.ps1 -Tag 6292a2f3c0cf0cfe02916f6fd0a6f940629adc52 -Builder superbrain_builder` built and pushed all six service images for `linux/arm64`.
- `scripts\deploy-to-staging.ps1 -UseImageFilesystem -ImageTag 6292a2f3c0cf0cfe02916f6fd0a6f940629adc52 -KeyPath <local-private-key>` deployed the immutable staging selector.
- Hosted `GET /api/v1/project/progress` returns overall `82`, Frontend / Next.js `100`, and Orchestrator / LangGraph `100`.
- Hosted `GET /api/v1/project/progress/completion` returns `verified_100` for `layer_1` and `layer_2`, while overall completion remains fail-closed.
- Frontend HTML exposes `active_frontend_orchestrator_evidence_bundle_visible`, `layer_1_100_verified`, and `layer_2_100_verified`.
- Orchestrator evidence remains bound to LangGraph, deterministic dry-run mode, PostgreSQL checkpointing, Phase 2 runtime contract/runs, master plan, roster, and team status.

## Verification Commands

- `py -3 scripts\verify_project_progress_manifest.py`
- `py -3 -m py_compile services\agent-api\app\main.py`
- `npm --prefix apps\frontend run build`
- `scripts\verify-phase5-active-frontend-orchestrator-evidence-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- `scripts\verify-phase5-active-frontend-orchestrator-evidence-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-hosted-staging-smoke.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-cloud-only-staging.ps1 -BaseUrl https://188-34-191-140.sslip.io -ArtifactDir .phase1-artifacts`

## Non-Claims

- This proof does not claim a production rollout.
- This proof does not claim release promotion.
- This proof does not claim live LLM provider calls.
- This proof does not claim live MCP writes.
- This proof does not claim local model downloads.
- This proof does not include secret values.
