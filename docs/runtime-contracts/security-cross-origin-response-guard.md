# Cross-Origin Response Guard

`cross-origin-response-guard-v1` applies a same-origin browser boundary to every Agent API
response, including validation and not-found error envelopes.

## Contract

- Endpoint: `GET /api/v1/security/cross-origin/contract`
- Evidence: `cross_origin_response_guard_visible`
- `Cross-Origin-Opener-Policy: same-origin`
- `Cross-Origin-Resource-Policy: same-origin`
- `X-Permitted-Cross-Domain-Policies: none`
- Public cross-origin credentials and reflected attacker origins remain disabled.

The guard complements CSP reporting and CSRF request rejection. It does not enable COEP,
cross-origin credentials, provider calls, MCP writes, state writes, deployment, or production
claims.

## Proof

`scripts/verify-phase3-cross-origin-response-guard.ps1` checks success and 404 responses,
an untrusted `Origin` request with no reflected CORS header, a real Diagnostics click, response
headers in Chromium, a nonblank PNG, and a fixed JSON report.

Localhost evidence is `DEV-ONLY`; hosted proof remains a separate gate.
