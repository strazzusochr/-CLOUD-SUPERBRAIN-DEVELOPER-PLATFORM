# Auth Audit Risk Rollup Immutable Staging Proof

release_id: `prod-candidate-2026-05-11-rc1`
candidate_sha: `4a59571c77d46728b8c11320e6dc65433b7eeff0`
image_tag: `4a59571c77d46728b8c11320e6dc65433b7eeff0`
hosted_base_url: `https://188-34-191-140.sslip.io`
recorded_at: `2026-05-14T12:34:00+02:00`
production_rollout_claimed: `false`
promotion_allowed: `false`

## Scope

This proof binds the Phase 3 Auth Audit Risk Rollup implementation to the active immutable Hetzner staging selector. It is staging evidence only and does not approve production rollout.

## Runtime Evidence

- `GET /api/v1/audit/auth/contract` exposes `risk_rollup_endpoint=GET /api/v1/audit/auth/risk-rollup`, `risk_rollup_contract_version=auth-audit-risk-rollup-v1`, and `auth_audit_risk_rollup_visible`.
- `GET /api/v1/audit/auth/risk-rollup` reads `audit_log` only through the safe Auth Audit Snapshot projection for callback, refresh rotation, refresh reuse block, and logout revoke events.
- The rollup asserts `tokens_returned=false`, `cookies_returned=false`, `authorization_headers_returned=false`, `blacklist_keys_returned=false`, `oauth_codes_returned=false`, `oauth_states_returned=false`, `live_github_oauth_call_count=0`, `forbidden_pattern_hits=0`, `blocker_count=0`, `production_rollout_claimed=false`, and `promotion_allowed=false`.
- The frontend renders `Auth Audit Risk Rollup`, endpoint `GET /api/v1/audit/auth/risk-rollup`, `auth-audit-risk-rollup-v1`, `auth_audit_risk_rollup_visible`, `auth_audit_redaction_enforced`, and `auth_no_live_oauth_guard`.

## Verification Commands

- `py -3 -m py_compile services\agent-api\app\main.py`
- `npm run build` in `apps/frontend`
- `docker info --format '{{.ServerVersion}}'`
- `docker compose -f docker-compose.dev.yml up -d --build agent-api frontend nginx`
- `scripts\verify-phase3-auth-audit-snapshot.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireLifecycle`
- `scripts\verify-phase3-auth-audit-risk-rollup.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireLifecycle`
- `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- `scripts\verify-security.ps1`
- `scripts\verify-evidence-artifact-safety.ps1`
- `scripts\build-and-push.ps1 -Tag 4a59571c77d46728b8c11320e6dc65433b7eeff0 -Platforms linux/arm64 -Builder codex-multiarch`
- `scripts\deploy-to-staging.ps1 -UseImageFilesystem -ImageTag 4a59571c77d46728b8c11320e6dc65433b7eeff0 -KeyPath <local-private-key>`
- `scripts\verify-phase3-auth-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase3-auth-audit-snapshot.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireLifecycle`
- `scripts\verify-phase3-auth-audit-risk-rollup.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireLifecycle`
- `scripts\verify-browser-contract.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-hosted-staging-smoke.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify.ps1 -Suite phase3 -BaseUrl https://188-34-191-140.sslip.io -FailFast`

## Progress

- Overall: `78%`
- Phase 3 - Product Surface & Security: `82%`
- Frontend / Next.js: `99%`
- Observability: `99%`

## Non-Claims

- No production rollout.
- No release promotion.
- No live GitHub OAuth exchange claim.
- No live LLM provider calls.
- No live MCP writes.
- No secret, token, cookie, authorization header, OAuth code/state, Redis blacklist key, or raw audit detail exposure.
