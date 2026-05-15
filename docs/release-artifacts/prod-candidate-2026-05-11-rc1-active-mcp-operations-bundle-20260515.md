# RC1 Active MCP Operations Bundle - 2026-05-15

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
source_commit_sha: `43783e702ae37ce4e88fe9f309a2488445cd83e1`
immutable_image_commit_sha: `43783e702ae37ce4e88fe9f309a2488445cd83e1`
base_url: `https://188-34-191-140.sslip.io`
production_rollout_claimed: `false`
mcp_gate_count: `9`
changed_horizontal: `Phase 5 81->82`
changed_vertical: `MCP Gateway 65->66`

## Verified Commands

- `docker info --format '{{.ServerVersion}}'`
- `py -3 scripts\verify_project_progress_manifest.py`
- `scripts\build-and-push.ps1 -Tag 43783e702ae37ce4e88fe9f309a2488445cd83e1 -Builder superbrain_builder`
- `docker buildx imagetools inspect ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:43783e702ae37ce4e88fe9f309a2488445cd83e1`
- `scripts\deploy-to-staging.ps1 -UseImageFilesystem -ImageTag 43783e702ae37ce4e88fe9f309a2488445cd83e1 -KeyPath <local-private-key>`
- `scripts\verify-phase5-active-mcp-operations-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- `scripts\verify-phase5-active-mcp-operations-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase4-mcp-capability-catalog.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase4-mcp-security-guard.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase4-mcp-devops-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase4-mcp-audit-feed-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase3-mcp-deny-audit-correlation.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase3-mcp-audit-export.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-evidence-artifact-safety.ps1`

## Runtime Evidence

- Hosted project progress returned `overall=81`, `phase_5=82`, `mcp_gateway=66`, and status marker `active_mcp_operations_bundle_verified`.
- MCP Gateway health returned `status=healthy`, `service=mcp-gateway`, `capability_catalog_contract_version=mcp-capability-catalog-v1`, and `live_mcp_writes=false`.
- MCP capability catalog returned `mcp-capability-catalog-v1`, six toolsets, no live mutations, no external MCP server calls, and the expected unsupported-toolset/capability, scope, timeout, redaction, and deny-correlation guards.
- MCP version pinning returned `mcp-version-pinning-v1`, exact gateway dependency pins, pinned tool contracts, and no-live-MCP-write non-claims.
- MCP audit feed/export, deny-audit correlation, and safe-envelope verifiers passed against the same hosted selector.

## Non-Claims

- This proof does not claim a production rollout.
- This proof does not claim release promotion.
- This proof does not claim live LLM provider calls.
- This proof does not claim live MCP writes.
- This proof does not claim local model downloads.
- This proof does not include secret values.
