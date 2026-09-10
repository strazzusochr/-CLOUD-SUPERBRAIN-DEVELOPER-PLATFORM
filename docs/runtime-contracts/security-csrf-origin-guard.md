# Security CSRF Origin Guard

Contract version: `csrf-origin-guard-v1`

Evidence reference: `csrf_origin_guard_visible`

Audit evidence: `csrf_origin_rejection_audited`

Contract endpoint: `GET /api/v1/security/csrf/contract`

Write-free probe: `POST /api/v1/security/csrf/probe`

## Scope

The Agent API applies a defense-in-depth CSRF boundary to unsafe methods under `/api/`. Browser requests with `Sec-Fetch-Site: cross-site`, `Origin: null`, a malformed Origin, or an Origin that differs from the public request origin fail closed with HTTP `403` before route execution.

Same-origin browser requests are accepted. CLI and internal service requests that do not carry browser Fetch Metadata or Origin headers remain compatible with the existing service-to-service runtime. Safe methods remain unaffected.

## Rejection Contract

Rejected requests return `csrf_origin_rejected`, a bounded reason code, `csrf-origin-guard-v1`, and `X-Superbrain-CSRF-Contract`. The `security_csrf_request_rejected` audit stores only method, path, bounded Fetch Metadata, Origin presence, reason, request ID, and trace ID. Raw Origin values, cookies, authorization values, request bodies, and secret material are never persisted.

## Verification

The dedicated verifier proves:

- contract and Diagnostics visibility;
- a real same-origin browser POST succeeds through the guard;
- non-browser requests without browser metadata remain compatible;
- cross-site Fetch Metadata fails with `403`;
- mismatched and null Origins fail with `403`;
- rejection audit evidence is visible and contains no attacker-origin value;
- no provider write, live MCP write, deployment, OAuth scope change, or secret output occurs.

Localhost evidence is `DEV-ONLY`; it does not prove hosted OAuth or production authentication.
