# LLM Provider Readiness Contract

Status: DEV-ONLY local contract. Hosted parity is not claimed by this slice.

Endpoint: `GET /llm/api/v1/providers/readiness/contract`

Contract version: `llm-provider-readiness-contract-v1`

Evidence ref: `llm_provider_readiness_contract_visible`

## Purpose

This contract makes the Layer 4 provider-readiness gate explicit without performing an upstream model-list probe or live generation call.

## Runtime Rules

- Default generation decision: `deterministic_dry_run`.
- Provider: `huggingface_inference_router`.
- Provider token env name may be reported, but token values are never returned.
- `external_probe_performed=false`.
- `live_provider_calls=false`.
- `model_downloads=false`.
- Live generation requires all env gates plus per-request `metadata.live_provider_calls_allowed=true`.
- Direct provider URLs and provider key refs remain blocked before generation.

## Guard Markers

- `llm-provider-readiness-contract-v1`
- `llm_provider_readiness_contract_visible`
- `external_probe_performed=false`
- `provider_token_returned=false`
- `llm_routing_policy_direct_provider_blocked`
- `llm_output_token_budget_guard`

## Non-Claims

- No live provider generation call is made by this contract.
- No upstream model-list probe is made by this contract.
- No provider credential, direct provider URL, local model download, production rollout, release promotion, or hosted parity is claimed by this local contract.
