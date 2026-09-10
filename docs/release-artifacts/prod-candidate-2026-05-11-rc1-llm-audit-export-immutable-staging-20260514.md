# LLM Audit Export Immutable Staging Proof

release_id: `prod-candidate-2026-05-11-rc1`
candidate_sha: `13d02661c5cfbc2e4a881f1a16f303002affca06`
image_tag: `13d02661c5cfbc2e4a881f1a16f303002affca06`
hosted_base_url: `https://188-34-191-140.sslip.io`
recorded_at: `2026-05-14T14:59:54+02:00`
production_rollout_claimed: `false`
promotion_allowed: `false`

## Scope

This proof binds the Phase 3 LLM Audit Export implementation to the active immutable Hetzner staging selector. It is staging evidence only and does not approve production rollout.

## Runtime Evidence

- `GET /api/v1/audit/llm/export/contract` exposes `llm-audit-export-v1`, `llm_audit_export_visible`, `llm_audit_export_audit_persisted`, `llm_audit_redaction_enforced`, and `llm_audit_no_live_provider_guard`.
- `GET /api/v1/audit/llm/export?format=csv&limit=80` emits `text/csv` from the same safe LLM Audit projection as feed and snapshot.
- The CSV allowlist is limited to sequence, event id/type, timestamp, severity, trace id, model/provider names, agent type, status, token/cost counters, live-provider boolean, prompt-body stored boolean, and evidence refs.
- The export asserts no prompt bodies, provider credentials, tokens, cookies, authorization headers, raw details, production rollout, release promotion, or live provider claim.
- Export access persists only redacted metadata through `llm_audit_export_generated` and `llm_audit_export_audit_persisted`.
- The adversarial verifier seeds token/provider/header/cookie/JWT canaries and proves they are omitted or redacted in export, feed, snapshot, and recent audit feeds.

## Verification Commands

- `py -3 -m py_compile services\agent-api\app\main.py`
- `npm run build` in `apps/frontend`
- `docker info --format '{{.ServerVersion}}'`
- `docker compose -f docker-compose.dev.yml up -d --build agent-api frontend nginx`
- `scripts\verify-phase3-llm-audit-export.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireSeed`
- `scripts\verify-phase3-llm-audit-feed.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- `scripts\verify-security.ps1`
- `scripts\verify-evidence-artifact-safety.ps1`
- `scripts\build-and-push.ps1 -Tag 13d02661c5cfbc2e4a881f1a16f303002affca06 -Platforms linux/arm64 -Builder codex-multiarch`
- `scripts\deploy-to-staging.ps1 -PlanOnly -UseImageFilesystem -ImageTag 13d02661c5cfbc2e4a881f1a16f303002affca06`
- `scripts\deploy-to-staging.ps1 -UseImageFilesystem -ImageTag 13d02661c5cfbc2e4a881f1a16f303002affca06 -KeyPath <local-private-key>`
- `scripts\verify-phase3-llm-audit-export.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase3-llm-audit-feed.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-browser-contract.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-hosted-staging.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify.ps1 -Suite phase3 -BaseUrl https://188-34-191-140.sslip.io -FailFast`

## Progress

- Overall: `79%`
- Phase 3 - Product Surface & Security: `88%`
- LLM Gateway: `62%`
- Frontend / Next.js: `99%`
- Observability: `99%`

## Non-Claims

- No production rollout.
- No release promotion.
- No live LLM provider calls.
- No live MCP writes.
- No secret, token, cookie, authorization header, provider credential, prompt body, unsafe trace ID, or raw audit detail exposure.
