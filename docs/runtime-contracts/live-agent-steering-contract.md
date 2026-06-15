# Live Agent Steering Contract

Status: DEV-ONLY verified contract, hosted proof still gated.

## Runtime Surface

- Contract: `GET /api/v1/live-agents/contract`
- Status: `GET /api/v1/live-agents/status`
- Steering: `POST /api/v1/live-agents/steer`
- Compatibility: `POST /api/steer-agent`
- Reset: `POST /api/v1/live-agents/{agent_id}/reset`
- Contract version: `live-agent-steering-v1`
- Evidence ref: `live_agent_steering_contract_visible`

## Boundary

Layer 3 live agents call Layer 4 only through the LLM Gateway Responses adapter:
`POST /llm/v1/responses`. The Agent API does not call direct provider URLs and
does not store provider credentials.

Each steering response mirrors the LLM Gateway contract posture:

- `llm_gateway_contract_version`
- `llm_gateway_evidence_ref`
- `trace_id`
- `live_provider_calls`
- `model_downloads`
- `audit_persisted`
- `secret_output`

## Session State

Agent history is stored in Redis under `live-agent:responses:<agent_id>` with
the task TTL. The status surface exposes only the previous response id, model,
execution role, and update timestamp.

## Guarded Defaults

- `live_provider_calls=false`
- `model_downloads=false`
- `secret_output=false`
- no production deploy claim
- no live provider claim unless the LLM Gateway policy and owner gate allow it

## Negative Cases

- unknown `agent_id` returns HTTP `404`
- empty `message` returns HTTP `422`
- localhost proof requires `-AllowLocalhost`
- hosted proof requires HTTPS

## Verifier

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-live-agent-steering-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost
```

This is a local development proof only. Hosted verification requires a real
HTTPS staging URL and reachable cloud backend origins.
