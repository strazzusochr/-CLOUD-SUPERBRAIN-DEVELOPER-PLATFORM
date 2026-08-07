# LLM Responses Adapter Contract

Status: DEV-ONLY verified contract, hosted proof still gated.

## Runtime Surface

- Contract: `GET /llm/api/v1/responses/contract`
- Runtime: `POST /llm/v1/responses`
- Contract version: `llm-responses-adapter-contract-v2`
- Streaming protocol: `openai-responses-sse-v1`
- Evidence ref: `llm_responses_adapter_contract_visible`

## Boundary

Layer 3 live-agent steering calls the Layer 4 LLM Gateway only through the Responses adapter. The Agent API does not call direct provider URLs.

The adapter accepts Responses-style `input`, optional `previous_response_id`, optional `instructions`, structured `metadata`, and a boolean `stream` flag. On the internal audited path, Layer 3 supplies server-owned `metadata.trace_id` and `metadata.agent_type`; public Live-Agent request metadata cannot override those values or authorize provider use.

`max_output_tokens` is optional and must be an integer from `1` through `8192`. Instructions are limited to `8192` characters and are prepended to the provider request as system context. Input, model id, metadata, audit correlation fields, serialized request payload, requested output tokens, and generated output text are bounded on both streaming and non-streaming paths.

When `store=true`, the adapter keeps at most `64` process-local response contexts for `1800` seconds, with `65536` stored context characters per response. `previous_response_id` must be an adapter-issued id and is resolved before any model call. An unknown or expired id returns HTTP `404`. Layer 3 clears the stale Redis pointer and retries exactly once without continuity, reporting `continuity_reset=true`; this does not claim cross-replica persistence.

With `stream=true`, the gateway emits deterministic, Responses-native SSE frames in monotonic `sequence_number` order. The stream ends with `response.completed` and connection close; it does not append the Chat Completions `[DONE]` sentinel. The current implementation buffers the bounded deterministic result before emitting frames and therefore does not claim upstream provider token passthrough.

The audit write completes before SSE headers or frames are emitted. If persistence is unavailable or rejected, the endpoint returns HTTP `503` JSON and never emits `response.completed`.

## Guarded Defaults

- `live_provider_calls=false`
- `model_downloads=false`
- `secret_output=false`
- `production_deploy=false`
- no OpenAI API key is required by this adapter
- live Hugging Face router calls require both token availability and explicit request metadata approval
- streaming is deterministic-only and never calls local or live providers
- `metadata.live_provider_calls_allowed=true` is rejected on the streaming path
- SSE responses use `Cache-Control: no-store` and disable reverse-proxy buffering
- Live-Agent body metadata cannot set `trace_id`, role/project correlation, gateway routing, or `live_provider_calls_allowed`

## Negative Cases

- non-boolean `stream` returns HTTP `422`; the wire mode must be explicit.
- non-object `metadata` returns HTTP `422`; trace/audit metadata must remain structured.
- empty or oversized input returns HTTP `422`; the DEV-ONLY stream stays bounded.
- invalid or oversized `max_output_tokens` returns HTTP `422`; booleans are not accepted as integers.
- invalid/oversized instructions and malformed `previous_response_id` return HTTP `422`.
- unknown/expired bounded context returns HTTP `404`; Layer 3 performs one explicit continuity reset/retry.
- failed stream audit persistence returns HTTP `503` before any SSE event.

## Verifier

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-llm-responses-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost
```

This is a local development proof only. Hosted verification requires a real HTTPS staging URL and reachable cloud backend origins.
