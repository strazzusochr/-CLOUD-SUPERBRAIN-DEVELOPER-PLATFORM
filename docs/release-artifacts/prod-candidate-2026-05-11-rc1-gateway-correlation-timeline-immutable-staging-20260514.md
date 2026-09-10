# Gateway Correlation Timeline Immutable Staging Proof

Release ID: `prod-candidate-2026-05-11-rc1`
Status: `verified`
Candidate SHA: `d2c8b9c52785955b698da151edb666c884ac888f`
Environment: `hetzner-staging`
Production rollout claimed: `false`
Promotion allowed: `false`

## Machine Contract

release_id: `prod-candidate-2026-05-11-rc1`
candidate_sha: `d2c8b9c52785955b698da151edb666c884ac888f`
production_rollout_claimed: `false`
hosted_selector_observed: `IMAGE_TAG=d2c8b9c52785955b698da151edb666c884ac888f`
image_pattern: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:d2c8b9c52785955b698da151edb666c884ac888f`

## Scope

This proof binds the Phase 3 Gateway Correlation Timeline to the active immutable staging candidate. It is a read-only audit-log event ordering view and does not enable live provider calls, live MCP writes, production rollout, release promotion, or cloud mutation.

## Runtime Evidence

- Parent contract endpoint: `GET /api/v1/security/gateway-correlation/contract`
- Snapshot endpoint: `GET /api/v1/security/gateway-correlation/snapshot`
- Risk rollup endpoint: `GET /api/v1/security/gateway-correlation/risk-rollup`
- Timeline endpoint: `GET /api/v1/security/gateway-correlation/timeline`
- Contract: `gateway-correlation-timeline-v1`
- Evidence refs: `gateway_correlation_timeline_visible`, `gateway_correlation_snapshot_visible`, `gateway_correlation_redaction_enforced`, `gateway_correlation_no_live_write_guard`
- Timeline guards: `read_only=true`, `prompt_bodies_returned=false`, `tool_input_refs_returned=false`, `provider_credentials_returned=false`, `forbidden_pattern_hits=0`, `live_provider_calls_claimed=false`, `live_mcp_writes_claimed=false`, `production_rollout_claimed=false`, `promotion_allowed=false`
- Timeline proof: the verifier requires ordered timeline sequence rows, safe Agent/LLM/MCP timeline legs when `-RequireFullCorrelation` is set, and event parity against snapshot/risk rollup counts.

## Verification

- Python compile: `py -3 -m py_compile services\agent-api\app\main.py`
- Frontend build: `npm run build` in `apps/frontend`
- Local Docker deploy: `docker compose -f docker-compose.dev.yml up -d --build agent-api frontend nginx`
- Local snapshot verifier: `scripts\verify-phase3-gateway-correlation-snapshot.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Local risk-rollup verifier: `scripts\verify-phase3-gateway-correlation-risk-rollup.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireFullCorrelation`
- Local timeline verifier: `scripts\verify-phase3-gateway-correlation-timeline.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireFullCorrelation`
- Local browser contract: `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Security verifier: `scripts\verify-security.ps1`
- Evidence artifact safety verifier: `scripts\verify-evidence-artifact-safety.ps1`
- GHCR build/push: `scripts\build-and-push.ps1 -Tag d2c8b9c52785955b698da151edb666c884ac888f -Platforms linux/arm64 -Builder codex-multiarch`
- Hetzner deploy: `scripts\deploy-to-staging.ps1 -UseImageFilesystem -ImageTag d2c8b9c52785955b698da151edb666c884ac888f`
- Hosted snapshot verifier: `scripts\verify-phase3-gateway-correlation-snapshot.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Hosted risk-rollup verifier: `scripts\verify-phase3-gateway-correlation-risk-rollup.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireFullCorrelation`
- Hosted timeline verifier: `scripts\verify-phase3-gateway-correlation-timeline.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireFullCorrelation`
- Full hosted Phase-3 suite: `scripts\verify.ps1 -Suite phase3 -BaseUrl https://188-34-191-140.sslip.io -FailFast`
- Hosted browser contract: `scripts\verify-browser-contract.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Hosted smoke: `scripts\verify-hosted-staging-smoke.ps1 -BaseUrl https://188-34-191-140.sslip.io`

## Progress Impact

- Overall: `77%`
- Phase 3 - Product Surface & Security: `78%`
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
