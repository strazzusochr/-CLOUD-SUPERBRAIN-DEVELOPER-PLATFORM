# Agent Research Run Contract

Status: DEV-ONLY gateway pipeline; hosted proof still blocked.

## Runtime Surface

- Contract: `GET /api/v1/agent-run/contract`
- Runtime: `POST /api/v1/agent-run`
- Request: `{"goal":"string"}`
- Contract version: `agent-research-run-v1`
- Evidence ref: `agent_research_run_gateway_only_visible`

## Pipeline

The Agent API runs three serial, read-only steps:

1. Planner creates a bounded plan.
2. Researcher develops notes from the goal and planner output.
3. Writer produces the final answer from the supplied pipeline context.

Every step crosses the existing Layer 4 LLM Gateway Responses boundary at
`POST /llm/v1/responses`. The Agent API does not call a provider URL directly.
The request does not set `metadata.live_provider_calls_allowed`; any provider,
live-call, local-model, model-download, or audit claim in the result is derived
only from the three Gateway responses.

## Response

The response contains the frontend fields `goal`, `provider`, `steps`,
`sources`, and `answer`, plus contract, trace, safety, budget, and Gateway truth
fields. `steps` contains the exact roles `planner`, `researcher`, and `writer`.

`sources` is deliberately empty. This pipeline has no audited retrieval or
browsing boundary and therefore does not manufacture citations or URLs.

## Guards

- budget guard runs before the first Gateway request
- goal, trace, and visible model output pass through the shared redactor
- Gateway failure, incomplete status, secret-output signal, or empty output
  stops the pipeline
- `direct_provider_calls=false`
- `live_mcp_writes=false`
- `production_deploy=false`
- no new token, permission, filesystem-write, MCP-write, or deployment surface

## Verification

Focused unit coverage mocks only the LLM Gateway boundary:

```powershell
python -m unittest discover -s services/agent-api/tests -p test_agent_research_run.py
python -m py_compile services/agent-api/app/main.py
```

This is local development evidence only: `DEV-ONLY; hosted proof still blocked`.
