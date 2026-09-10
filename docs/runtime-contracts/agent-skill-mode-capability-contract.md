# Agent Skill Mode Capability Contract

Status: DEV-ONLY verified local contract. Hosted parity is not claimed by this slice.

Endpoint: `GET /api/v1/agents/skill-mode/contract`

Contract version: `agent-skill-mode-capability-contract-v1`

Evidence ref: `agent_skill_mode_capability_visible`

Registry mirror: `docs/codex-integration/agent-skill-mode-capability-registry.json`

## Purpose

This contract exposes the Codex capability surface requested by the operator as a guarded, read-only capability registry for the Superbrain Workbench. It records the current declared Codex surface counts: `plugins=11`, `apps=4`, `mcp_servers=1`, and `skills=140`.

## Guard Model

All capability activation stays behind the seven-layer platform model:

- Frontend: visible Workbench module registry and browser contract markers.
- Orchestrator: LangGraph task envelopes and budget guard before execution.
- Agent Pool: Supervisor, Planner, Coder, Tester, and DevOps role scopes.
- LLM Gateway: API-only routing with no direct provider bypass.
- MCP Gateway: safe envelopes, capability catalogs, and `live_mcp_writes=false`.
- Memory: redacted summaries only.
- Observability: evidence refs and audit trails required.

## Non-Claims

- No plugin, app, MCP, or skill is executed by reading this contract.
- No live provider call is made.
- No live MCP write or external MCP server mutation is made.
- No local model download is made.
- No production rollout or release promotion is claimed.
- No secret is exposed.

## Guard Markers

- `agent_skill_mode_no_live_external_calls`
- `agent_skill_mode_no_secret_material`
- `agent_skill_mode_no_local_model_downloads`
