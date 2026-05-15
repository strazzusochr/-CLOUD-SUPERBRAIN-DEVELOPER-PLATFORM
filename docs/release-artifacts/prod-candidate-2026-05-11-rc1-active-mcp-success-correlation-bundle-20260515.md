# RC1 Active MCP Success Correlation Bundle - 2026-05-15

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
source_commit_sha: `6292a2f3c0cf0cfe02916f6fd0a6f940629adc52`
immutable_image_commit_sha: `6292a2f3c0cf0cfe02916f6fd0a6f940629adc52`
base_url: `https://188-34-191-140.sslip.io`
production_rollout_claimed: `false`
mcp_success_gate_count: `7`
changed_horizontal: `Phase 5 82->83`
changed_vertical: `MCP Gateway 66->67`

## Verified Commands

- `docker info --format '{{.ServerVersion}}'`
- `py -3 scripts\verify_project_progress_manifest.py`
- `scripts\build-and-push.ps1 -Tag 6292a2f3c0cf0cfe02916f6fd0a6f940629adc52 -Builder superbrain_builder`
- `docker buildx imagetools inspect ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:6292a2f3c0cf0cfe02916f6fd0a6f940629adc52`
- `scripts\deploy-to-staging.ps1 -ImageTag 6292a2f3c0cf0cfe02916f6fd0a6f940629adc52 -UseImageFilesystem -KeyPath <local-private-key>`
- `scripts\verify-phase5-active-mcp-success-correlation-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- `scripts\verify-phase5-active-mcp-success-correlation-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase5-active-verifier-sweep-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-current-runtime-selector-truth.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireRemoteProof -KeyPath <local-private-key>`
- `scripts\verify-evidence-artifact-safety.ps1`

## Runtime Evidence

- Hosted project progress returned `overall=81`, `phase_5=83`, `mcp_gateway=67`, and status marker `active_mcp_success_correlation_bundle_verified`.
- The verifier executed a successful MCP `github/plan_branch_pr` dry-run with explicit `session_id`, `trace_id`, `request_id`, and `tool_request_id`.
- The MCP Gateway returned `status=success`, `evidence_ref=github_branch_pr_plan`, `audit_persisted=true`, `live_github_call=false`, and a draft PR plan without creating a branch or pull request.
- The MCP audit feed, global audit feed, and agent-activity feed exposed the same request and trace correlation evidence while keeping `input_ref_stored=false`.
- The gateway correlation timeline exposed the success event as a safe MCP audit leg with `live_mcp_writes=false`.

## Non-Claims

- This proof does not claim a production rollout.
- This proof does not claim release promotion.
- This proof does not claim live LLM provider calls.
- This proof does not claim live MCP writes.
- This proof does not claim local model downloads.
- This proof does not include secret values.
