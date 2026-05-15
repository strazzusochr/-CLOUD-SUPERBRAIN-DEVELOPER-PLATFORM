# RC1 Active LLM Success Correlation Bundle - 2026-05-15

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
source_commit_sha: `4a894c16d5f340b89ad1134da781d1c855d6ced5`
immutable_image_commit_sha: `4a894c16d5f340b89ad1134da781d1c855d6ced5`
base_url: `https://188-34-191-140.sslip.io`
production_rollout_claimed: `false`
llm_success_gate_count: `7`
changed_horizontal: `Phase 5 83->84`
changed_vertical: `LLM Gateway 65->66`

## Verified Commands

- `docker info --format '{{.ServerVersion}}'`
- `py -3 -m compileall services\agent-api\app services\llm-gateway\app`
- `py -3 scripts\verify_project_progress_manifest.py`
- `scripts\build-and-push.ps1 -Tag 4a894c16d5f340b89ad1134da781d1c855d6ced5 -Builder superbrain_builder`
- `docker buildx imagetools inspect ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:4a894c16d5f340b89ad1134da781d1c855d6ced5`
- `scripts\deploy-to-staging.ps1 -ImageTag 4a894c16d5f340b89ad1134da781d1c855d6ced5 -UseImageFilesystem -KeyPath <local-private-key>`
- `scripts\verify-phase5-active-llm-success-correlation-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- `scripts\verify-phase5-active-llm-success-correlation-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase5-active-verifier-sweep-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-current-runtime-selector-truth.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireRemoteProof -KeyPath <local-private-key>`
- `scripts\verify-evidence-artifact-safety.ps1`

## Runtime Evidence

- Hosted project progress returned `overall=81`, `phase_5=84`, `llm_gateway=66`, and status marker `active_llm_success_correlation_bundle_verified`.
- The verifier executed a deterministic `/llm/v1/responses` success path with explicit `session_id`, `trace_id`, and `request_id`.
- The LLM Gateway returned `status=completed`, `provider_name=deterministic-dry-run`, `audit_persisted=true`, `live_provider_calls=false`, and `model_downloads=false`.
- The LLM audit feed, global audit feed, and agent-activity feed exposed the same request, trace, and session correlation evidence while keeping `prompt_body_stored=false`.
- The gateway correlation timeline exposed the success event as a safe LLM audit leg with `live_provider_calls=false` and `live_mcp_writes=false`.

## Non-Claims

- This proof does not claim a production rollout.
- This proof does not claim release promotion.
- This proof does not claim live LLM provider calls.
- This proof does not claim live MCP writes.
- This proof does not claim local model downloads.
- This proof does not include secret values.
