# Auth Audit Timeline Immutable Staging Proof

release_id: `prod-candidate-2026-05-11-rc1`
candidate_sha: `9c38c59238043dbda2d02ee4fcd0c59d44bac812`
image_tag: `9c38c59238043dbda2d02ee4fcd0c59d44bac812`
hosted_base_url: `https://188-34-191-140.sslip.io`
recorded_at: `2026-05-14T13:17:00+02:00`
production_rollout_claimed: `false`
promotion_allowed: `false`

## Scope

This proof binds the Phase 3 Auth Audit Timeline implementation to the active immutable Hetzner staging selector. It is staging evidence only and does not approve production rollout.

## Runtime Evidence

- `GET /api/v1/audit/auth/contract` exposes `timeline_endpoint=GET /api/v1/audit/auth/timeline`, `timeline_contract_version=auth-audit-timeline-v1`, and `auth_audit_timeline_visible`.
- `GET /api/v1/audit/auth/timeline` reads `audit_log` only through the safe Auth Audit Snapshot projection for callback, refresh rotation, refresh reuse block, and logout revoke events.
- The timeline asserts `tokens_returned=false`, `cookies_returned=false`, `authorization_headers_returned=false`, `blacklist_keys_returned=false`, `oauth_codes_returned=false`, `oauth_states_returned=false`, `live_github_oauth_call_count=0`, `forbidden_pattern_hits=0`, `production_rollout_claimed=false`, and `promotion_allowed=false`.
- The adversarial verifier seeds OAuth code/state, refresh token, JWT-like, Authorization/Cookie, Redis blacklist, and unsafe trace canaries and proves they are omitted or redacted in `/api/v1/audit/auth/timeline` and `/api/v1/audit/recent`.
- The frontend renders `Auth Audit Timeline`, endpoint `GET /api/v1/audit/auth/timeline`, `auth-audit-timeline-v1`, `auth_audit_timeline_visible`, `auth_audit_redaction_enforced`, and `auth_no_live_oauth_guard`.

## Verification Commands

- `py -3 -m py_compile services\agent-api\app\main.py services\agent-api\app\security.py`
- `npm run build` in `apps/frontend`
- `docker info --format '{{.ServerVersion}}'`
- `docker compose -f docker-compose.dev.yml up -d --build agent-api frontend nginx`
- `scripts\verify-phase3-auth-audit-snapshot.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireLifecycle`
- `scripts\verify-phase3-auth-audit-risk-rollup.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireLifecycle`
- `scripts\verify-phase3-auth-audit-timeline.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireLifecycle`
- `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- `scripts\verify-security.ps1`
- `scripts\verify-evidence-artifact-safety.ps1`
- `scripts\build-and-push.ps1 -Tag 9c38c59238043dbda2d02ee4fcd0c59d44bac812 -Platforms linux/arm64 -Builder codex-multiarch`
- `scripts\deploy-to-staging.ps1 -UseImageFilesystem -ImageTag 9c38c59238043dbda2d02ee4fcd0c59d44bac812 -KeyPath <local-private-key>`
- `scripts\verify-phase3-auth-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase3-auth-audit-snapshot.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireLifecycle`
- `scripts\verify-phase3-auth-audit-risk-rollup.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireLifecycle`
- `scripts\verify-phase3-auth-audit-timeline.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireLifecycle`
- `scripts\verify-browser-contract.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-hosted-staging.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify.ps1 -Suite phase3 -BaseUrl https://188-34-191-140.sslip.io -FailFast`

## Progress

- Overall: `78%`
- Phase 3 - Product Surface & Security: `84%`
- Frontend / Next.js: `99%`
- Observability: `99%`

## Non-Claims

- No production rollout.
- No release promotion.
- No live GitHub OAuth exchange claim.
- No live LLM provider calls.
- No live MCP writes.
- No secret, token, cookie, authorization header, OAuth code/state, Redis blacklist key, unsafe trace ID, or raw audit detail exposure.
