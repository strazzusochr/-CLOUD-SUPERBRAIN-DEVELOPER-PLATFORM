# Cloudflare LLM Gateway Hosted Read-only Contract

Contract: `cloudflare-llm-gateway-hosted-readonly-v1`

Evidence marker: `cloudflare_workers_ai_llm_gateway_preview_readonly_source_parity_verified`

## Verified Boundary

`scripts/verify-cloudflare-llm-gateway-hosted-readonly.ps1` reads exactly two public HTTPS
GET endpoints from the fixed Cloudflare Preview Worker:

- `GET /api/v1/health`
- `GET /v1/models`

The health response must identify the Cloudflare Workers AI gateway, report a healthy AI
binding and configured gateway authentication, expose a source commit and archive hash, and
keep `live_provider_calls`, `direct_provider_calls`, and `secret_output` false. The model
response must contain exactly the two allowlisted Cloudflare model identifiers and keep
`live_provider_calls=false`.

## Source Binding

The deployed source commit must exist in the repository and be an ancestor of current HEAD.
Every tracked file under `services/cloudflare-llm-gateway` must have the same Git blob at the
deployed source and current HEAD, the complete directory tree hashes must match, and the local
source worktree must be clean.

Evidence is written to
`.codex/runs/CURRENT/llm-gateway/cloudflare-hosted-readonly/report.json`.

## Non-claims

- The proof uses no authentication token and sends no inference request.
- The proof performs no provider write, deployment, release, or promotion action.
- The Preview Worker is not claimed as a Production Worker or full-platform production release.
