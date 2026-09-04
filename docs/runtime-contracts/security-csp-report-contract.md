# Phase 3 CSP Report Audit Contract

## Scope

This contract adds a same-origin Content Security Policy report sink to the Agent API. It is a Phase 3 security and observability slice with deterministic local runtime proof.

- Contract: `GET /api/v1/security/csp/contract`
- Report sink: `POST /api/v1/security/csp/report`
- CSP directive: `report-uri /api/v1/security/csp/report`
- Contract version: `csp-report-contract-v1`
- Contract evidence: `csp_report_contract_visible`
- Audit evidence: `csp_report_audit_persisted`
- Audit event: `security_csp_violation_reported`

## Acceptance And Privacy Rules

- Accepted media types are `application/csp-report` and `application/json`.
- The raw request body is limited to `16384` bytes and oversized requests fail closed with HTTP `413`.
- Invalid JSON, missing wrappers, empty supported fields, and unsupported media types are rejected.
- Only explicitly allowlisted CSP fields are persisted.
- Query strings and fragments are removed from URI fields before audit persistence.
- User-Agent, cookies, credentials, unknown fields, and the raw report are not persisted.
- The API returns success only after the redacted audit row has been written.
- Audit persistence failure rejects the report with HTTP `503`.
- Reports are not forwarded to an external collector.

## Verification

`scripts/verify-phase3-csp-report-contract.ps1` proves the contract, response headers, a real local audit write, query and unknown-field redaction, the `16384` byte limit, invalid-shape handling, and unsupported-content-type handling.

`apps/frontend/e2e/phase3-csp-report.spec.ts` selects `CSP Report Contract` on `/diagnostics`, clicks the live refresh control, and verifies the runtime response rendered in the browser.

After source, runtime, browser, audit, negative-path, and documentation evidence pass, the bounded progress rule is Phase 3 `40% -> 41%`; rounded overall progress remains unchanged.

## Non-Claims

- Localhost proof is `DEV-ONLY`; hosted proof is still blocked until the hosted staging and backend-origin gates are genuinely available.
- No production incident-response workflow is claimed.
- No third-party CSP collector is configured.
- No live provider call, provider write, live MCP write, secret use, production deployment, or release promotion is performed.
