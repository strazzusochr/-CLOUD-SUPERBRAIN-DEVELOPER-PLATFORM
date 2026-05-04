# Agent LLM Streaming Contract

Status: Implemented local runtime contract
Date: 2026-04-29
Phase: Phase 4 / L-07
Owner layer: Layer 3 to Layer 4 - Agent Pool to LLM Gateway

## Purpose

This contract closes audit gap `L-07`: Agent Pool execution must publish the exact streaming boundary it uses when it asks the LLM Gateway for model output. The proof is contract visibility only; the deterministic local path keeps `live_provider_calls=false`.

## Runtime Endpoints

| Purpose | Method | Path | Evidence |
| --- | --- | --- | --- |
| Public agent-to-LLM streaming contract | `GET` | `/api/v1/agents/llm-streaming-contract` | `agent_llm_streaming_contract_visible` |
| LLM Gateway streaming contract | `GET` | `/llm/api/v1/streaming/contract` | `llm_gateway_streaming_dry_run` |
| LLM route resolution | `POST` | `/llm/api/v1/routing/resolve` | selected model/provider |
| LLM routing policy evaluation | `POST` | `/llm/api/v1/routing/policy/evaluate` | `llm_routing_policy_primary_allowed` |
| OpenAI-compatible stream | `POST` | `/llm/v1/chat/completions` | SSE frames and `[DONE]` |

## Agent Consumer

The Agent API consumes this boundary from `services/agent-api/app/orchestrator.py`:

- Function: `call_llm_gateway_for_task`
- Parser: `parse_llm_gateway_sse_line`
- Required state fields:
  - `llm_gateway_calls[].streaming_used`
  - `llm_gateway_calls[].streaming_protocol`
  - `llm_gateway_calls[].stream_chunk_count`
  - `llm_gateway_calls[].stream_done_seen`
  - `llm_gateway_calls[].live_provider_calls`
  - `llm_gateway_calls[].live_provider_calls_proven_false`
  - `llm_gateway_calls[].audit_persisted`

## Gateway Protocol

| Field | Value |
| --- | --- |
| Protocol | `openai_compatible_sse` |
| Content type | `text/event-stream` |
| Required request flag | `stream=true` |
| Chat completion endpoint | `POST /llm/v1/chat/completions` |
| Terminal frame | `data: [DONE]` |

Required frames:

- `data: {chat.completion.chunk}`
- `data: {chat.completion.chunk finish_reason=stop}`
- `data: [DONE]`

## Request Schema

- `model`: selected model from routing resolver.
- `messages`: system and user messages, including bounded memory context.
- `stream`: `true`.
- `metadata.trace_id`: `langgraph-{run_id}-{task_id}`.
- `metadata.agent_type`: `planner`, `coder`, `tester`, or `devops`.
- `metadata.session_id`: UUID.
- `metadata.run_id`: UUID.

## Response Schema

- `chunk.object`: `chat.completion.chunk`.
- `choices[].delta.content`: string chunk content.
- `choices[].finish_reason`: `null` or `stop`.
- `terminal_frame`: `data: [DONE]`.
- `live_provider_calls`: `false` in deterministic local mode.
- `audit_persisted`: boolean from the LLM audit sink.

## Policy Checks

- Agents request streaming through the LLM Gateway and never through direct provider URLs.
- Routing policy is evaluated before the streaming chat completion request.
- The Agent executor records `stream_done_seen=true` before claiming streaming completion.
- If `[DONE]` is missing, `llm_gateway_streaming_dry_run` must not be emitted and the run is marked partial failure.
- `live_provider_calls=false` is accepted only when it is explicitly present and proven by the deterministic gateway response; missing values fail closed.
- A policy-blocked route records `streaming_used=false` and does not enqueue follow-up live provider work.
- Deterministic local proof keeps `live_provider_calls=false` and `cost_cents=0`.

## Evidence

- `GET /api/v1/agents/llm-streaming-contract` returns `agent-llm-streaming-contract-v1`.
- Frontend renders `Agent LLM Streaming Contract` with `agent_llm_streaming_contract_visible`.
- Runtime, hosted, browser-contract, and static verifiers assert the contract endpoint, protocol, parser, terminal frame, state fields, evidence refs, and non-claims.
- Existing LLM Gateway stream proofs assert `openai_compatible_sse`, `text/event-stream`, `data: [DONE]`, and `live_provider_calls=false`.
- Orchestrator proof asserts missing terminal stream frames or unproven live-provider non-claims become `llm_gateway_streaming_incomplete`, not completion evidence.

## Non-Claims

- This contract does not open live provider streams.
- This contract does not expose provider credentials.
- This contract does not enable production deployment.
