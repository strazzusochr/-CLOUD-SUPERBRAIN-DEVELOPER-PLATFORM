# Owner Runbook — Close The Two Hosted Gates

Purpose: close exactly these two external gates, without touching production promotion, live provider calls, or MCP writes:

- `hosted_agent_api_contracts`
- `vercel_backend_origin_health`

Source of truth for current state:

- `docs/runtime-state/external-gate-summary.json`
- Latest `.phase1-artifacts/external-gate-audit-*.json`

This runbook is complementary to:

- `TRAE_DEPLOY_PROMPT.md`
- `docs/runbooks/OWNER_GO_LIVE_CHECKLIST.md`

## Gate 1 — hosted_agent_api_contracts

Pass condition (minimal):

- A real, public HTTPS staging base URL exists (non-localhost, non-retired).
- The hosted staging base answers these over HTTPS with HTTP 200:
  - `GET /api/v1/health`
  - `GET /api/v1/clouds`
  - `GET /api/v1/clouds/layers`
  - `GET /api/v1/clouds/deployment-preflight/contract`
  - `GET /api/v1/project/progress/integrity`
  - `GET /api/v1/project/progress/completion`

Fastest closure path (recommended): use the single hosted compose stack (Caddy+nginx reverse proxy) described in `TRAE_DEPLOY_PROMPT.md` Path A, then set `STAGING_BASE_URL` to the real deployed HTTPS URL.

## Gate 2 — vercel_backend_origin_health

Pass condition (minimal):

- Vercel production deployment exists and is configured to rewrite to live HTTPS origins.
- All three configured origins answer a 2xx health probe:
  - `AGENT_API_BASE_URL + /api/v1/health`
  - `MCP_GATEWAY_BASE_URL + /api/v1/health`
  - `LLM_GATEWAY_BASE_URL + /api/v1/health`

Recommended wiring (single hosted compose stack):

- `AGENT_API_BASE_URL=https://<STAGING_HOST>`
- `MCP_GATEWAY_BASE_URL=https://<STAGING_HOST>/mcp`
- `LLM_GATEWAY_BASE_URL=https://<STAGING_HOST>/llm`

## Proof Commands

Run in the owner shell after staging is live (no localhost flags):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-hosted-staging.ps1 -BaseUrl $env:STAGING_BASE_URL
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-all-gates-with-tokens.ps1 -EnvFilePath "C:\Users\immer\.trae\secrets\cloud-superbrain.local.env"
```

Success means the latest `external-gate-audit-*.json` reports:

- `missing_or_failed_gates=[]`
- `hosted_staging_claim_allowed=true`
- `vercel_backend_origins_claim_allowed=true`

## Non-Claims

- No production deploy or promotion is performed by closing these gates.
- No live LLM provider calls are enabled by closing these gates.
- No live MCP write scope is enabled by closing these gates.
