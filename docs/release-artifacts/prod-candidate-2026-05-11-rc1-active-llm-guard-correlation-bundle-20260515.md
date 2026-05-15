# RC1 Active LLM Guard Correlation Bundle - 2026-05-15

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
source_commit_sha: `6292a2f3c0cf0cfe02916f6fd0a6f940629adc52`
immutable_image_commit_sha: `6292a2f3c0cf0cfe02916f6fd0a6f940629adc52`
base_url: `https://188-34-191-140.sslip.io`
local_control_plane_url: `http://localhost:8081`
production_rollout_claimed: `false`
llm_guard_gate_count: `8`
changed_horizontal: `Phase 5 86->87`
changed_vertical: `LLM Gateway 66->67`

## Verified Commands

- `docker info --format '{{.ServerVersion}}'`
- `py -3 -m compileall services\agent-api\app services\llm-gateway\app`
- `py -3 scripts\verify_project_progress_manifest.py`
- `scripts\build-and-push.ps1 -Tag 6292a2f3c0cf0cfe02916f6fd0a6f940629adc52 -Builder superbrain_builder`
- `scripts\deploy-to-staging.ps1 -ImageTag 6292a2f3c0cf0cfe02916f6fd0a6f940629adc52 -UseImageFilesystem -KeyPath <local-private-key>`
- `scripts\verify-phase5-active-llm-guard-correlation-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- `scripts\verify-phase5-active-llm-guard-correlation-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase5-active-verifier-sweep-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-evidence-artifact-safety.ps1`

## Runtime Evidence

- Hosted project progress returned `overall=82`, `phase_5=87`, `llm_gateway=67`, and status marker `active_llm_guard_correlation_bundle_verified`.
- The verifier exercises three deterministic fail-closed `/llm/v1/responses` guard paths: direct-provider bypass, unknown model id, and output-token budget overflow.
- Each blocked request is persisted as an LLM audit event with the same `session_id`, `trace_id`, and `request_id` used by the request.
- The LLM audit feed, global audit feed, agent-activity feed, and gateway-correlation timeline expose the blocked guard evidence while keeping `live_provider_calls=false`, `model_downloads=false`, and `prompt_body_stored=false`.
- Guard evidence refs verified: `llm_routing_policy_direct_provider_blocked`, `llm_routing_policy_unknown_model_blocked`, and `llm_output_token_budget_guard`.

## Non-Claims

- This proof does not claim a production rollout.
- This proof does not claim release promotion.
- This proof does not claim live LLM provider calls.
- This proof does not claim live MCP writes.
- This proof does not claim local model downloads.
- This proof does not include secret values.
