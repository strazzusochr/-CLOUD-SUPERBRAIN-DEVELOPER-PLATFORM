# Gateway Correlation Risk Rollup Immutable Staging Proof

Release ID: `prod-candidate-2026-05-11-rc1`
Status: `verified`
Candidate SHA: `5a67227c12bbfb1c9da956158ed2cec6d7b6d8a0`
Environment: `hetzner-staging`
Production rollout claimed: `false`
Promotion allowed: `false`

## Machine Contract

release_id: `prod-candidate-2026-05-11-rc1`
candidate_sha: `5a67227c12bbfb1c9da956158ed2cec6d7b6d8a0`
production_rollout_claimed: `false`
hosted_selector_observed: `IMAGE_TAG=5a67227c12bbfb1c9da956158ed2cec6d7b6d8a0`
image_pattern: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:5a67227c12bbfb1c9da956158ed2cec6d7b6d8a0`

## Scope

This proof binds the Phase 3 Gateway Correlation Risk Rollup to the active immutable staging candidate. It is a read-only audit-log risk view and does not enable live provider calls, live MCP writes, production rollout, release promotion, or cloud mutation.

## Runtime Evidence

- Parent contract endpoint: `GET /api/v1/security/gateway-correlation/contract`
- Snapshot endpoint: `GET /api/v1/security/gateway-correlation/snapshot`
- Risk rollup endpoint: `GET /api/v1/security/gateway-correlation/risk-rollup`
- Contract: `gateway-correlation-risk-rollup-v1`
- Evidence refs: `gateway_correlation_risk_rollup_visible`, `gateway_correlation_snapshot_visible`, `gateway_correlation_redaction_enforced`, `gateway_correlation_no_live_write_guard`
- Rollup guards: `read_only=true`, `prompt_bodies_returned=false`, `tool_input_refs_returned=false`, `provider_credentials_returned=false`, `forbidden_pattern_hits=0`, `live_provider_calls_claimed=false`, `live_mcp_writes_claimed=false`, `production_rollout_claimed=false`, `promotion_allowed=false`
- Correlation proof: the verifier requires at least one full Agent/LLM/MCP correlation group and asserts rollup event/group parity against the snapshot.

## Verification

- Local compile: `py -3 -m py_compile services\agent-api\app\main.py`
- Frontend build: `npm run build` in `apps/frontend`
- Local snapshot verifier: `scripts\verify-phase3-gateway-correlation-snapshot.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Local risk-rollup verifier: `scripts\verify-phase3-gateway-correlation-risk-rollup.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireFullCorrelation`
- Local browser contract: `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Manifest verifier: `py -3 scripts\verify_project_progress_manifest.py`
- GHCR build/push: `scripts\build-and-push.ps1 -Tag 5a67227c12bbfb1c9da956158ed2cec6d7b6d8a0 -Platforms linux/arm64 -Builder codex-multiarch`
- Hetzner deploy: `scripts\deploy-to-staging.ps1 -UseImageFilesystem -ImageTag 5a67227c12bbfb1c9da956158ed2cec6d7b6d8a0`
- Hosted snapshot verifier: `scripts\verify-phase3-gateway-correlation-snapshot.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Hosted risk-rollup verifier: `scripts\verify-phase3-gateway-correlation-risk-rollup.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireFullCorrelation`
- Hosted browser contract: `scripts\verify-browser-contract.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Hosted smoke: `scripts\verify-hosted-staging-smoke.ps1 -BaseUrl https://188-34-191-140.sslip.io`

## Progress Impact

- Overall: `77%`
- Phase 3 - Product Surface & Security: `76%`
- Frontend: unchanged at `99%`
- Agent Pool: unchanged at `73%`
- LLM Gateway: unchanged at `61%`
- MCP Gateway: unchanged at `61%`
- Memory: unchanged at `72%`
- Observability: unchanged at `99%`

## Non-Claims

- No production rollout.
- No production promotion.
- No live provider call.
- No live MCP write.
- No provider billing proof.
- No external SOC/SIEM completeness claim.
- No secret exposure clearance beyond the verifier-scoped redaction assertions.
