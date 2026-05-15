# Active LLM Operations Bundle Proof

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
environment: `production-candidate`
source_commit_sha: `6292a2f3c0cf0cfe02916f6fd0a6f940629adc52`
immutable_image_commit_sha: `6292a2f3c0cf0cfe02916f6fd0a6f940629adc52`
base_url: `https://188-34-191-140.sslip.io`
local_control_plane_url: `http://localhost:8081`
production_rollout_claimed: `false`
llm_gate_count: `8`
changed_horizontal: `Phase 5 80->81`
changed_vertical: `LLM Gateway 64->65`

## Bound LLM Gates

- `llm-runtime-probe`
- `llm-audit-contract`
- `phase4-llm-model-catalog`
- `phase4-llm-live-provider-guard`
- `phase3-llm-audit-feed`
- `phase3-llm-audit-export`
- `phase4-agent-llm-streaming-contract-runtime-hosted`
- `evidence-artifact-safety`

## Verification Commands

- Docker readiness: `docker info --format '{{.ServerVersion}}'`
- Build/push: `scripts\build-and-push.ps1 -Tag 6292a2f3c0cf0cfe02916f6fd0a6f940629adc52 -Builder superbrain_builder`
- Immutable staging deploy: `scripts\deploy-to-staging.ps1 -ImageTag 6292a2f3c0cf0cfe02916f6fd0a6f940629adc52 -UseImageFilesystem -KeyPath <local-private-key>`
- Local proof: `scripts\verify-phase5-active-llm-operations-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Hosted proof: `scripts\verify-phase5-active-llm-operations-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`

## Non-Claims

- This proof does not claim a production rollout.
- This proof does not claim release promotion.
- This proof does not claim live LLM provider calls.
- This proof does not claim live MCP writes.
- This proof does not claim local model downloads.
- This proof does not include secret values.
