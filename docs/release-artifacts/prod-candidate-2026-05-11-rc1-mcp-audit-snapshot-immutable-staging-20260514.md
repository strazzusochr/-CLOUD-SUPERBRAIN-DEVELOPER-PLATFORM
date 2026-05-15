# MCP Audit Snapshot Immutable Staging Proof

Release ID: `prod-candidate-2026-05-11-rc1`
Status: `verified`
Candidate SHA: `0a7ca2bed583f2e01af39a73e095e91cee642365`
Environment: `hetzner-staging`
Production rollout claimed: `false`
Promotion allowed: `false`

## Machine Contract

release_id: `prod-candidate-2026-05-11-rc1`
candidate_sha: `0a7ca2bed583f2e01af39a73e095e91cee642365`
production_rollout_claimed: `false`
hosted_selector_observed: `IMAGE_TAG=0a7ca2bed583f2e01af39a73e095e91cee642365`
image_pattern: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:0a7ca2bed583f2e01af39a73e095e91cee642365`
parity_verifier: `scripts\verify-current-immutable-staging-parity.ps1 -RequireVerified`

## Scope

This proof binds the Phase 3 / Layer 5 MCP Audit Redaction Snapshot to the active immutable staging candidate. It is a read-only audit-log projection and does not enable live MCP writes.

## Runtime Evidence

- Contract endpoint: `GET /api/v1/audit/mcp/contract`
- Feed endpoint: `GET /api/v1/audit/mcp`
- Snapshot endpoint: `GET /api/v1/audit/mcp/snapshot`
- Evidence refs: `mcp_audit_feed_contract_runtime_visible`, `mcp_tool_session_bound_audit`, `mcp_audit_snapshot_visible`, `mcp_audit_redaction_enforced`
- Snapshot fields: `input_refs_returned=false`, `provider_credentials_returned=false`, `forbidden_pattern_hits=0`, `live_mcp_writes_claimed=false`

## Verification

- Local compile: `py -3 -m py_compile services\agent-api\app\main.py`
- Frontend build: `npm run build`
- Local verifier: `scripts\verify-phase3-mcp-deny-audit-correlation.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Local browser contract: `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- GHCR build/push: `scripts\build-and-push.ps1 -Tag 0a7ca2bed583f2e01af39a73e095e91cee642365 -Platforms linux/arm64 -Builder codex-multiarch`
- Hetzner deploy: `scripts\deploy-to-staging.ps1 -UseImageFilesystem -ImageTag 0a7ca2bed583f2e01af39a73e095e91cee642365`
- Hosted verifier: `scripts\verify-phase3-mcp-deny-audit-correlation.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Hosted browser contract: `scripts\verify-browser-contract.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Hosted smoke: `scripts\verify-hosted-staging-smoke.ps1 -BaseUrl https://188-34-191-140.sslip.io`

## Non-Claims

- No production rollout.
- No live MCP write.
- No live provider call.
- No provider billing proof.
- No SOC/SIEM completeness claim.
- No secret exposure clearance beyond the verifier-scoped redaction snapshot.
