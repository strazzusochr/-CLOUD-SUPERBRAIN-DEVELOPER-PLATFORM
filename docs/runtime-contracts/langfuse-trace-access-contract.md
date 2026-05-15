# Langfuse Trace Access Contract

Phase: Phase 3 - Product Surface & Security
Layer: Layer 7 - Observability
Contract version: `langfuse-trace-access-v1`
Evidence: `langfuse_trace_access_visible`

## Scope

This contract exposes an operator trace lookup that is backed only by `audit_log`. It gives the UI a stable Langfuse-style trace access surface while the live Langfuse deployment/auth proxy is still gated.

## Runtime Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/api/v1/observability/langfuse/contract` | Contract metadata, evidence refs, deep-link template, and non-claims |
| `GET` | `/api/v1/observability/langfuse/trace/{trace_id}?limit=20` | Read-only audit-log trace event lookup |
| `GET` | `/api/v1/agent-activity/recent?trace_id={trace_id}` | Source-compatible filtered activity feed |

## Required Fields

- `trace_id`
- `event_type`
- `severity`
- `created_at`
- `details`
- `evidence_ref`

## Policy

1. Trace lookup reads `audit_log` only.
2. Returned details are redacted before leaving the API.
3. The endpoint never exports traces to a provider.
4. The UI must expose `langfuse_trace_access_visible` and `langfuse_trace_event_visible`.
5. Public unauthenticated Langfuse access is never claimed.

## Non-Claims

- No live Langfuse deployment is claimed unless `LANGFUSE_PUBLIC_URL` is configured.
- No provider-side trace export or purge is claimed.
- No production observability auth proxy is claimed.
