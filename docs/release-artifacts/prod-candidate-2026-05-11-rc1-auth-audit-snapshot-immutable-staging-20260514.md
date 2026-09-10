# Auth Audit Snapshot Immutable Staging Proof

release_id: `prod-candidate-2026-05-11-rc1`
candidate_sha: `7a849155a7b6c3f2dd3ba93ff9fa306ad87b9296`
image_tag: `7a849155a7b6c3f2dd3ba93ff9fa306ad87b9296`
hosted_base_url: `https://188-34-191-140.sslip.io`
recorded_at: `2026-05-14T11:39:46+02:00`
production_rollout_claimed: `false`
promotion_allowed: `false`

## Scope

This proof binds the Phase 3 Auth Audit Snapshot implementation to the active immutable Hetzner staging selector. It is staging evidence only and does not approve production rollout.

## Runtime Evidence

- `GET /api/v1/audit/auth/contract` exposes `auth-audit-snapshot-v1`, parent `auth-github-jwt-refresh-v1`, `read_only=true`, `auth_audit_snapshot_visible`, `auth_audit_redaction_enforced`, and `auth_no_live_oauth_guard`.
- `GET /api/v1/audit/auth/snapshot` reads `audit_log` only and returns a safe allowlisted lifecycle projection for `auth_github_callback_contract`, `auth_refresh_rotated`, `auth_refresh_reuse_blocked`, and `auth_logout_revoked`.
- The snapshot asserts `tokens_returned=false`, `cookies_returned=false`, `authorization_headers_returned=false`, `blacklist_keys_returned=false`, `oauth_codes_returned=false`, `oauth_states_returned=false`, `live_github_oauth_call_count=0`, and `forbidden_pattern_hits=0`.
- The frontend renders `Auth Audit Snapshot`, endpoint `GET /api/v1/audit/auth/snapshot`, `auth-audit-snapshot-v1`, `auth_audit_snapshot_visible`, `auth_audit_redaction_enforced`, and `auth_no_live_oauth_guard`.

## Verification Commands

- `py -3 -m py_compile services\agent-api\app\main.py`
- `npm run build` in `apps/frontend`
- `docker info --format '{{.ServerVersion}}'`
- `docker compose -f docker-compose.dev.yml up -d --build agent-api frontend nginx`
- `scripts\verify-phase3-auth-audit-snapshot.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireLifecycle`
- `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- `scripts\verify-security.ps1`
- `scripts\verify-evidence-artifact-safety.ps1`
- `scripts\build-and-push.ps1 -Tag 7a849155a7b6c3f2dd3ba93ff9fa306ad87b9296 -Platforms linux/arm64 -Builder codex-multiarch`
- `scripts\deploy-to-staging.ps1 -UseImageFilesystem -ImageTag 7a849155a7b6c3f2dd3ba93ff9fa306ad87b9296 -KeyPath <local-private-key>`
- `scripts\verify-phase3-auth-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase3-auth-audit-snapshot.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireLifecycle`
- `scripts\verify-browser-contract.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-hosted-staging-smoke.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify.ps1 -Suite phase3 -BaseUrl https://188-34-191-140.sslip.io -FailFast`

## Non-Claims

- No production rollout.
- No release promotion.
- No live GitHub OAuth exchange claim.
- No live LLM provider calls.
- No live MCP writes.
- No secret, token, cookie, authorization header, OAuth code/state, Redis blacklist key, or raw audit detail exposure.
