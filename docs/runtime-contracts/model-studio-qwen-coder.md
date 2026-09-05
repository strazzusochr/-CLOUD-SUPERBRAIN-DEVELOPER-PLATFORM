# Alibaba Model Studio Qwen Coder Contract

Status: Configured and fail-closed; live provider proof is not claimed
Date: 2026-08-27
Owner layers: Layer 3 Agent Pool to Layer 4 LLM Gateway

## Purpose

The `coder` profile uses `qwen3.7-plus` as its new primary model. The agent requests the
logical `coder_primary` slot and never receives a provider URL or credential. The LLM Gateway
alone resolves that model to Alibaba Model Studio's OpenAI-compatible Singapore workspace
endpoint.

## Bound Path

```text
Qwen Code / Coder Agent
  -> http://localhost:8081/llm/v1 (DEV-ONLY client boundary)
  -> LLM Gateway /v1/chat/completions
  -> ALIBABA_MODEL_STUDIO_BASE_URL/chat/completions
```

The public repository stores only environment-variable names and the approved model ID. The
workspace-specific endpoint remains user/environment configuration and may be shown as non-secret
operator metadata; the API key remains only in `DASHSCOPE_API_KEY` and is never returned.

## Configuration

| Variable | Purpose | Default |
| --- | --- | --- |
| `LLM_GATEWAY_MODE` | Explicit provider activation mode | `deterministic_dry_run` |
| `LLM_LIVE_PROVIDER_DEFAULT` | Owner-controlled external live-provider master gate | `false` |
| `ALIBABA_MODEL_STUDIO_BASE_URL` | HTTPS workspace endpoint ending in `/compatible-mode/v1` | empty |
| `ALIBABA_MODEL_STUDIO_CODER_MODEL` | Approved coder model | `qwen3.7-plus` |
| `ALIBABA_MODEL_STUDIO_TIMEOUT_SECONDS` | Bounded upstream timeout | `90` |
| `DASHSCOPE_API_KEY` | Dedicated provider credential | empty |

The live mode value is `alibaba_model_studio_live`. Endpoint validation accepts HTTPS only, no
userinfo, query, or fragment, the exact `/compatible-mode/v1` path, and a
`.maas.aliyuncs.com` hostname.

## Fail-Closed Rules

- Default mode remains `deterministic_dry_run`.
- The coder route is `configured_only=true` until a dedicated key and live proof exist.
- A live call requires the explicit Model Studio gateway mode, a valid endpoint, a dedicated key,
  the owner-controlled `LLM_LIVE_PROVIDER_DEFAULT=true` master gate, and per-request
  `metadata.live_provider_calls_allowed=true`.
- Caller metadata cannot override the owner master gate. Output is bounded to 8192 tokens and tool
  definitions are count- and byte-bounded before the provider call.
- A persisted authorization audit is required before the provider call. A second persisted audit is
  required before the live completion is returned.
- Missing key or endpoint returns HTTP `503` before any provider request.
- Models outside the single Model Studio allowlist return HTTP `400`.
- Agent policy payloads that include a direct provider URL or key reference remain
  `deny_direct_provider`.
- Provider error bodies, authorization headers, and credentials are never returned.
- Provider cost is reported as unknown (`cost_cents=null`, `provider_invoice_unverified`) until a
  measured provider invoice/cost mapping exists; it is never presented as a zero-cost live call.

## Qwen Code Client

Qwen Code `0.22.2` is the supported local client. Its user-scope provider points to the local
`/llm/v1` boundary, not to Alibaba Model Studio directly. This preserves the seven-layer gateway
boundary and keeps provider credentials out of the Qwen client configuration. OpenAI-compatible
function definitions, tool choices, assistant tool calls, and tool-result correlation IDs are
preserved across the gateway boundary.

## Current Non-Claims

- No `DASHSCOPE_API_KEY` was created, printed, stored in the repository, or used.
- No authenticated Model Studio generation was executed.
- No live provider call, provider write, production deployment, release promotion, or percentage
  increase is claimed.
- Local configuration and deterministic checks remain `DEV-ONLY; hosted proof still blocked`.
