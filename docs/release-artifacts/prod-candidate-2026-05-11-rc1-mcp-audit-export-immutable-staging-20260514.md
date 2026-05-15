# MCP Audit Export Immutable Staging Proof

release_id: `prod-candidate-2026-05-11-rc1`
proof_id: `prod-candidate-2026-05-11-rc1-mcp-audit-export-immutable-staging-20260514`
Status: `verified`
recorded_at: `2026-05-14T18:10:00+02:00`
environment: `hetzner-staging`
hosted_base_url: `https://188-34-191-140.sslip.io`
image_tag: `21145b89634b330231b6fd66c8aa2654c55a047e`
candidate_sha: `21145b89634b330231b6fd66c8aa2654c55a047e`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:21145b89634b330231b6fd66c8aa2654c55a047e`
hosted_selector_observed: `IMAGE_TAG=21145b89634b330231b6fd66c8aa2654c55a047e`
production_rollout_claimed: `false`
release_promotion_claimed: `false`
live_provider_calls_claimed: `false`
live_mcp_writes_claimed: `false`

## Scope

This proof binds the Phase 3 MCP Audit Export slice to the immutable staging selector.
It does not approve production promotion and does not claim live MCP writes.

## Runtime Surface

- Contract endpoint: `GET /api/v1/audit/mcp/export/contract`
- Export endpoint: `GET /api/v1/audit/mcp/export?format=csv&limit=80`
- Contract version: `mcp-audit-export-v1`
- Export evidence ref: `mcp_audit_export_visible`
- Export audit evidence ref: `mcp_audit_export_audit_persisted`
- Redaction evidence ref: `mcp_audit_redaction_enforced`
- No-live-write evidence ref: `mcp_audit_no_live_write_guard`

## Safety Guarantees

- CSV columns are allowlisted.
- Export reads the safe MCP audit projection only.
- Export access writes redacted `mcp_audit_export_generated` audit metadata.
- Export does not return tool input refs, prompt bodies, cookies, authorization headers, provider credentials, raw details, live MCP write claims, production rollout claims, or promotion claims.

## Local Verification

- `py -3 -m py_compile services\agent-api\app\main.py`
- `npm run build` in `apps/frontend`
- `docker info --format '{{.ServerVersion}}'`
- `docker compose -f docker-compose.dev.yml up -d --build agent-api frontend nginx`
- `scripts\verify-phase3-mcp-audit-export.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireSeed`
- `scripts\verify-phase3-mcp-deny-audit-correlation.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- `scripts\verify-security.ps1`
- `scripts\verify-evidence-artifact-safety.ps1`

## Build And Deploy Verification

- `scripts\build-and-push.ps1 -Tag 21145b89634b330231b6fd66c8aa2654c55a047e -Platforms linux/arm64 -Builder codex-multiarch`
- `scripts\deploy-to-staging.ps1 -UseImageFilesystem -ImageTag 21145b89634b330231b6fd66c8aa2654c55a047e -KeyPath <local-private-key>`
- Remote Compose proof showed all application images using tag `21145b89634b330231b6fd66c8aa2654c55a047e` under `/app`.
- Remote service health was green for caddy, nginx, frontend, agent-api, agent-worker, memory-worker, llm-gateway, mcp-gateway, redis, and postgres.

## Hosted Verification

- `scripts\verify-phase3-mcp-audit-export.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase3-mcp-deny-audit-correlation.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-browser-contract.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-hosted-staging.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify.ps1 -Suite phase3 -BaseUrl https://188-34-191-140.sslip.io -FailFast`
- `scripts\verify-current-immutable-staging-parity.ps1 -RequireVerified`

## Progress Impact

- Overall remains `79%`.
- Phase 3 rises to `90%`.
- MCP Gateway rises to `63%`.

## Non-Claims

- No production rollout was performed.
- No production promotion was performed.
- No live MCP write was performed or enabled.
- No live provider call is claimed.
- No provider billing proof is claimed.
- No SOC/SIEM completeness is claimed.
- No secret, token, raw tool input, cookie, authorization header, or provider credential is exposed.
