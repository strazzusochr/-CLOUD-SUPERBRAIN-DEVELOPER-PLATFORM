# Security Audit Surface Contract

Phase: Phase 3 - Product Surface & Security
Layer: Layer 7 - Observability / Layer 3 - Product Security
Contract version: `security-audit-surface-v1`
Evidence: `security_audit_surface_visible`

## Scope

This contract exposes a read-only operator surface for security-relevant `audit_log` rows across CSP reports, auth lifecycle events, MCP deny events, and LLM Gateway dry-run audit events.

## Runtime Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/api/v1/security/events/contract` | Contract metadata, supported event types, evidence refs, and non-claims |
| `GET` | `/api/v1/security/events?limit=20` | Recent security audit events |
| `GET` | `/api/v1/security/events?event_type=security_csp_violation_reported` | Filtered security audit events |

## Supported Event Types

- `security_csp_violation_reported`
- `auth_refresh_rotated`
- `auth_refresh_reuse_blocked`
- `auth_logout_revoked`
- `mcp_tool_executed`
- `llm_gateway_request`

## Policy

1. The surface reads `audit_log` only.
2. It never executes MCP tools, calls LLM providers, or mutates auth/session state.
3. Events expose `request_id` and `trace_id` when the source audit writer recorded them.
4. Redacted audit details must not reveal provider tokens, API keys, prompt bodies, or browser cookies.
5. Evidence refs must include `security_audit_surface_visible` and `security_audit_event_visible`.

## Non-Claims

- No production SOC, SIEM, or incident-response workflow is claimed.
- No live provider calls or live MCP writes are enabled by this read-only feed.
- No secrets, prompt bodies, or browser cookies are intentionally returned.
