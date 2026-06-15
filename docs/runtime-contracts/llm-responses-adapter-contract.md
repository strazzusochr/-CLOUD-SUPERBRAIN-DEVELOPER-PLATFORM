# LLM Responses Adapter Contract

Status: DEV-ONLY verified contract, hosted proof still gated.

## Runtime Surface

- Contract: `GET /llm/api/v1/responses/contract`
- Runtime: `POST /llm/v1/responses`
- Contract version: `llm-responses-adapter-contract-v1`
- Evidence ref: `llm_responses_adapter_contract_visible`

## Boundary

Layer 3 live-agent steering calls the Layer 4 LLM Gateway only through the Responses adapter. The Agent API does not call direct provider URLs.

The adapter accepts Responses-style `input`, optional `previous_response_id`, and structured `metadata`. For audited agent paths, `metadata.trace_id` and `metadata.agent_type` must be supplied by the caller.

## Guarded Defaults

- `live_provider_calls=false`
- `model_downloads=false`
- `secret_output=false`
- `production_deploy=false`
- no OpenAI API key is required by this adapter
- live Hugging Face router calls require both token availability and explicit request metadata approval

## Negative Cases

- `stream=true` returns HTTP `501`; streaming is covered by the existing chat-completions SSE contract.
- non-object `metadata` returns HTTP `422`; trace/audit metadata must remain structured.

## Verifier

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-llm-responses-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost
```

This is a local development proof only. Hosted verification requires a real HTTPS staging URL and reachable cloud backend origins.
