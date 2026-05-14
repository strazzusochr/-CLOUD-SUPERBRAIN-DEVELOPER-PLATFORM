# Gateway Correlation Export Immutable Staging Proof

release_id: `prod-candidate-2026-05-11-rc1`
proof_id: `gateway-correlation-export-immutable-staging-20260514`
image_tag: `819ec616b79059ab727567e5be82edba99b59045`
environment: `hetzner-staging`
base_url: `https://188-34-191-140.sslip.io`
production_rollout_claimed: `false`

## Scope

This proof adds the read-only Gateway Correlation CSV export to the Phase 3 Product Surface & Security evidence chain. It covers Agent, LLM, and MCP correlation groups only. It does not approve production, does not promote a release, does not enable live provider calls, and does not enable live MCP writes.

## Runtime Contract

- `GET /api/v1/security/gateway-correlation/export/contract`
- `GET /api/v1/security/gateway-correlation/export?format=csv&limit=80`
- Contract version: `gateway-correlation-export-v1`
- Evidence refs: `gateway_correlation_export_visible`, `gateway_correlation_export_audit_persisted`, `gateway_correlation_redaction_enforced`, `gateway_correlation_no_live_write_guard`
- Parent evidence: `gateway_correlation_snapshot_visible`, `gateway_correlation_risk_rollup_visible`, `gateway_correlation_timeline_visible`

## Local Verification

- `py -3 -m py_compile services\agent-api\app\main.py`
- `npx tsc --noEmit --pretty false`
- `npm run build --prefix apps/frontend`
- `docker info --format '{{.ServerVersion}}'`
- `py -3 scripts\verify_project_progress_manifest.py`
- `docker compose -f docker-compose.dev.yml up -d --build agent-api frontend nginx`
- `scripts\verify-phase3-gateway-correlation-export.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireFullCorrelation`
- `scripts\verify-phase3-gateway-correlation-risk-rollup.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireFullCorrelation`
- `scripts\verify-phase3-gateway-correlation-timeline.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireFullCorrelation`
- `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- `scripts\verify-security.ps1`
- `scripts\verify-evidence-artifact-safety.ps1`

The local `scripts\verify.ps1 -Suite phase3 -BaseUrl http://localhost:8081 -AllowLocalhost -FailFast` run stopped at the existing HTTPS-only hosted-auth proof, as expected for localhost. The new Gateway Correlation Export verifier and dependent Gateway gates passed locally.

## Image Build And Deploy

- Initial multi-service build/push hit a transient GHCR network/DNS failure while pushing `frontend`.
- The frontend push was repeated successfully with `docker buildx build --platform linux/arm64 -t ghcr.io/strazzusochr/cloud-superbrain-developer-platform/frontend:819ec616b79059ab727567e5be82edba99b59045 --push --builder codex-multiarch apps/frontend`.
- All six GHCR images were inspected successfully for tag `819ec616b79059ab727567e5be82edba99b59045`.
- Staging deploy used `scripts\deploy-to-staging.ps1 -UseImageFilesystem -ImageTag 819ec616b79059ab727567e5be82edba99b59045 -KeyPath <local-private-key> -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`.

## Hosted Verification

- `scripts\verify-phase3-gateway-correlation-export.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireFullCorrelation`
- `scripts\verify-phase3-gateway-correlation-risk-rollup.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireFullCorrelation`
- `scripts\verify-phase3-gateway-correlation-timeline.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireFullCorrelation`
- `scripts\verify-browser-contract.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-hosted-staging-smoke.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify.ps1 -Suite hosted-staging -BaseUrl https://188-34-191-140.sslip.io -SafeProfile -FailFast`
- `scripts\verify.ps1 -Suite phase3 -BaseUrl https://188-34-191-140.sslip.io -FailFast`

The first full hosted Phase 3 suite attempt saw a transient remote connection reset immediately after deploy. A stabilized rerun passed all 24 Phase 3 scripts, including Gateway Correlation Export.

## Result

- `overall_percent`: `79`
- `phase_3`: `92`
- `agent_pool`: `74`
- `llm_gateway`: `63`
- `mcp_gateway`: `64`

No production rollout, release promotion, live provider call, live MCP write, provider billing proof, SOC/SIEM completeness, or secret exposure is claimed.
