# LLM Audit Feed Contract

Phase: Phase 3 - Product Surface & Security
Layer: Layer 4 - LLM Gateway
Contract version: `llm-audit-feed-v1`
Evidence: `llm_audit_feed_visible`

## Scope

This contract exposes a read-only operator feed for LLM Gateway audit rows. It is backed only by `audit_log` rows where `event_type = llm_gateway_request`.

## Runtime Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/api/v1/audit/llm/contract` | Contract metadata and non-claims |
| `GET` | `/api/v1/audit/llm?limit=20` | Recent LLM Gateway audit events |
| `GET` | `/api/v1/audit/llm/snapshot?limit=50` | Read-only redaction and aggregate snapshot |
| `POST` | `/internal/audit/llm-events` | Internal audit writer used by gateway/verifiers |

## Required Fields

- `trace_id`
- `model_name`
- `provider_name`
- `agent_type`
- `status`
- `input_tokens`
- `output_tokens`
- `cost_cents`
- `live_provider_calls`
- `summary`
- `prompt_body_stored`
- `redaction_evidence_ref`

## Policy

1. The public feed is read-only.
2. The public feed never calls a model provider.
3. Dry-run proof rows must expose `live_provider_calls=false`.
4. Provider credentials, API keys, and prompt bodies must not be returned.
5. Evidence refs must include `llm_audit_feed_visible` and `llm_audit_feed_event_visible`.
6. Snapshot evidence must include `llm_audit_snapshot_visible` and `llm_audit_redaction_enforced`.
7. Snapshot responses must expose `prompt_bodies_returned=false`, `provider_credentials_returned=false`, and `forbidden_pattern_hits=0` before any release claim.

## Non-Claims

- No live provider call is enabled by this feed.
- No production deployment or provider billing proof is claimed.
- This is not a long-term telemetry warehouse or Langfuse replacement.
