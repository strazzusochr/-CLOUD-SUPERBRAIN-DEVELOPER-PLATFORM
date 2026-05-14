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
| `GET` | `/api/v1/audit/auth/contract` | Read-only auth audit snapshot contract |
| `GET` | `/api/v1/audit/auth/snapshot?limit=80` | Safe auth lifecycle audit snapshot |
| `GET` | `/api/v1/audit/auth/risk-rollup?limit=80` | Read-only auth audit risk rollup computed from safe lifecycle events |
| `GET` | `/api/v1/security/gateway-correlation/contract` | Read-only Agent/LLM/MCP correlation contract |
| `GET` | `/api/v1/security/gateway-correlation/snapshot?limit=80` | Safe correlation snapshot across agent task, LLM audit, and MCP audit rows |
| `GET` | `/api/v1/security/gateway-correlation/risk-rollup?limit=80` | Read-only risk rollup computed from gateway correlation groups |
| `GET` | `/api/v1/security/gateway-correlation/timeline?limit=80` | Read-only ordered timeline computed from safe gateway correlation events |

## Supported Event Types

- `security_csp_violation_reported`
- `auth_refresh_rotated`
- `auth_refresh_reuse_blocked`
- `auth_logout_revoked`
- `mcp_tool_executed`
- `llm_gateway_request`

## Auth Audit Snapshot

Contract version: `auth-audit-snapshot-v1`
Evidence: `auth_audit_snapshot_visible`, `auth_audit_redaction_enforced`, `auth_no_live_oauth_guard`

The auth audit snapshot reads `audit_log` rows for dry-run GitHub callback, refresh-token rotation, refresh-token reuse block, and logout revoke events. It exposes only safe lifecycle fields: event id, event type, trace id, lifecycle step, status, severity, timestamp, evidence refs, no-live-OAuth evidence, and boolean cookie flag summaries when recorded.

It never returns access tokens, refresh tokens, cookies, authorization headers, OAuth code/state values, Redis blacklist keys, raw request details, or live GitHub OAuth claims. The verifier `scripts/verify-phase3-auth-audit-snapshot.ps1` performs GET-only checks by default and can require seeded lifecycle rows with `-RequireLifecycle`.

## Auth Audit Risk Rollup

Contract version: `auth-audit-risk-rollup-v1`
Evidence: `auth_audit_risk_rollup_visible`, `auth_audit_redaction_enforced`, `auth_no_live_oauth_guard`

The auth audit risk rollup derives from the same safe auth audit projection and stays read-only. It counts dry-run callback, refresh-token rotation, refresh-token reuse block, and logout revoke evidence; live GitHub OAuth claims; forbidden redaction-pattern hits; blocker and review totals; status/severity distributions; and operator-facing risk badges.

The rollup always returns `production_rollout_claimed=false` and `promotion_allowed=false`. Refresh-token reuse blocks are review evidence when redaction and no-live-OAuth guards remain clear; forbidden credential patterns or live GitHub OAuth claims are blockers.

The verifier `scripts/verify-phase3-auth-audit-risk-rollup.ps1` performs GET-only checks against the contract, rollup, and frontend markers. With `-RequireLifecycle`, it proves callback, refresh-rotation, refresh-reuse-block, and logout-revoke evidence is present without returning tokens, cookies, authorization headers, OAuth code/state values, Redis blacklist keys, or raw audit details.

## Gateway Correlation Snapshot

Contract version: `gateway-correlation-snapshot-v1`
Evidence: `gateway_correlation_snapshot_visible`, `gateway_correlation_redaction_enforced`, `gateway_correlation_no_live_write_guard`

The gateway correlation snapshot groups safe `audit_log` projections by trace, request, or session key across `task_completed`, `autonomous_team_dispatch`, `langgraph_dry_run_completed`, `langgraph_dry_run_stopped`, `llm_gateway_request`, and `mcp_tool_executed`.

It returns only safe fields: event id, event type, trace id, request id, session id, agent type, status, evidence refs, severity, and timestamps. It never returns raw prompt bodies, raw MCP `input_ref`, provider credentials, cookies, authorization headers, or full audit details.

The verifier `scripts/verify-phase3-gateway-correlation-snapshot.ps1` seeds one deterministic agent task, one LLM dry-run audit row, and one denied MCP audit row under a shared trace id, then proves a full `agent_llm_mcp_correlated` group with `live_provider_call_count=0`, `live_mcp_write_count=0`, `forbidden_pattern_hits=0`, and `redaction_status=clear`.

## Gateway Correlation Risk Rollup

Contract version: `gateway-correlation-risk-rollup-v1`
Evidence: `gateway_correlation_risk_rollup_visible`, `gateway_correlation_redaction_enforced`, `gateway_correlation_no_live_write_guard`

The risk rollup derives from the same safe gateway correlation projection and stays read-only. It counts full, partial, and gateway-pair correlations; missing Agent/LLM/MCP legs; live-provider or live-MCP-write violations; forbidden redaction-pattern hits; risk badges; and per-group risk states.

The rollup always returns `production_rollout_claimed=false` and `promotion_allowed=false`. A full correlation is evidence for operator visibility only, not a release promotion, live provider activation, or production claim.

The verifier `scripts/verify-phase3-gateway-correlation-risk-rollup.ps1` performs GET-only checks against the contract, snapshot, rollup, and frontend markers. When run after the snapshot verifier with `-RequireFullCorrelation`, it also proves the seeded full correlation appears in the rollup without returning prompts, MCP input refs, provider credentials, or live-call/write claims.

## Gateway Correlation Timeline

Contract version: `gateway-correlation-timeline-v1`
Evidence: `gateway_correlation_timeline_visible`, `gateway_correlation_redaction_enforced`, `gateway_correlation_no_live_write_guard`

The timeline derives from the same safe gateway correlation projection and stays read-only. It orders Agent-task, LLM-audit, and MCP-audit events by timestamp and exposes only sequence index, event id/type, timeline leg, correlation key, trace/request/session ids, agent/status/severity, evidence refs, and no-live-write markers.

The timeline always returns `production_rollout_claimed=false` and `promotion_allowed=false`. It does not claim live provider calls or live MCP writes, and it never returns raw `audit_log.details`, prompt bodies, raw MCP input refs, provider credentials, cookies, authorization headers, or full audit details.

The verifier `scripts/verify-phase3-gateway-correlation-timeline.ps1` performs GET-only checks against the contract, snapshot, risk rollup, timeline, and frontend markers. When run after the snapshot verifier with `-RequireFullCorrelation`, it proves all three timeline legs are visible for the seeded shared trace.

## Policy

1. The surface reads `audit_log` only.
2. It never executes MCP tools, calls LLM providers, or mutates auth/session state.
3. Events expose `request_id` and `trace_id` when the source audit writer recorded them.
4. Redacted audit details must not reveal provider tokens, API keys, prompt bodies, or browser cookies.
5. Evidence refs must include `security_audit_surface_visible` and `security_audit_event_visible`.
6. Auth audit evidence must include `auth_audit_snapshot_visible`, `auth_audit_risk_rollup_visible`, `auth_audit_redaction_enforced`, and `auth_no_live_oauth_guard`.
7. Gateway correlation evidence must include `gateway_correlation_snapshot_visible`, `gateway_correlation_risk_rollup_visible`, `gateway_correlation_timeline_visible`, `gateway_correlation_redaction_enforced`, and `gateway_correlation_no_live_write_guard`.

## Non-Claims

- No production SOC, SIEM, or incident-response workflow is claimed.
- No live provider calls or live MCP writes are enabled by this read-only feed.
- No secrets, prompt bodies, or browser cookies are intentionally returned.
