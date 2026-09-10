# Auth Audit Export Immutable Staging Proof

release_id: `prod-candidate-2026-05-11-rc1`
candidate_sha: `efa2035e565a500b4c530fffdbab5016853a910e`
image_tag: `efa2035e565a500b4c530fffdbab5016853a910e`
hosted_base_url: `https://188-34-191-140.sslip.io`
recorded_at: `2026-05-14T14:08:39+02:00`
production_rollout_claimed: `false`
promotion_allowed: `false`

## Scope

This proof binds the Phase 3 Auth Audit Export implementation to the active immutable Hetzner staging selector. It is staging evidence only and does not approve production rollout.

## Runtime Evidence

- `GET /api/v1/audit/auth/export/contract` exposes `auth-audit-export-v1`, `auth_audit_export_visible`, `auth_audit_export_audit_persisted`, `auth_audit_redaction_enforced`, and `auth_no_live_oauth_guard`.
- `GET /api/v1/audit/auth/export?format=csv&limit=80` emits `text/csv` from the same safe Auth Audit projection as snapshot, risk rollup, and timeline.
- The CSV allowlist is limited to sequence, event id/type, timestamp, lifecycle step, status, severity, sanitized trace id, code-present boolean, cookie-flag summaries, no-live-OAuth boolean, and evidence refs.
- The export asserts no tokens, cookies, authorization headers, OAuth code/state values, Redis blacklist keys, raw details, production rollout, release promotion, or live GitHub OAuth claim.
- Export access persists only redacted metadata through `auth_audit_export_generated` and `auth_audit_export_audit_persisted`.
- The adversarial verifier seeds OAuth code/state, refresh token, JWT-like, Authorization/Cookie, Redis blacklist, and unsafe trace canaries and proves they are omitted or redacted in export, timeline, and recent audit feeds.

## Verification Commands

- `py -3 -m py_compile services\agent-api\app\main.py`
- `npm run build` in `apps/frontend`
- `docker info --format '{{.ServerVersion}}'`
- `docker compose -f docker-compose.dev.yml up -d --build agent-api frontend nginx`
- `scripts\verify-phase3-auth-audit-export.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireLifecycle`
- `scripts\verify-phase3-auth-audit-snapshot.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireLifecycle`
- `scripts\verify-phase3-auth-audit-risk-rollup.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireLifecycle`
- `scripts\verify-phase3-auth-audit-timeline.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireLifecycle`
- `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- `scripts\verify-security.ps1`
- `scripts\verify-evidence-artifact-safety.ps1`
- `scripts\build-and-push.ps1 -Tag efa2035e565a500b4c530fffdbab5016853a910e -Platforms linux/arm64 -Builder codex-multiarch`
- `scripts\deploy-to-staging.ps1 -PlanOnly -UseImageFilesystem -ImageTag efa2035e565a500b4c530fffdbab5016853a910e`
- `scripts\deploy-to-staging.ps1 -UseImageFilesystem -ImageTag efa2035e565a500b4c530fffdbab5016853a910e -KeyPath <local-private-key>`
- `scripts\verify-phase3-auth-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase3-auth-audit-export.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireLifecycle`
- `scripts\verify-phase3-auth-audit-snapshot.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireLifecycle`
- `scripts\verify-phase3-auth-audit-risk-rollup.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireLifecycle`
- `scripts\verify-phase3-auth-audit-timeline.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireLifecycle`
- `scripts\verify-browser-contract.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-hosted-staging.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify.ps1 -Suite phase3 -BaseUrl https://188-34-191-140.sslip.io -FailFast`

## Progress

- Overall: `78%`
- Phase 3 - Product Surface & Security: `86%`
- Frontend / Next.js: `99%`
- Observability: `99%`

## Non-Claims

- No production rollout.
- No release promotion.
- No live GitHub OAuth exchange claim.
- No live LLM provider calls.
- No live MCP writes.
- No secret, token, cookie, authorization header, OAuth code/state, Redis blacklist key, unsafe trace ID, or raw audit detail exposure.
