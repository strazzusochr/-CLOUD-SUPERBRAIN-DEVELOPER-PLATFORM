# Layer Interface Contracts

Stand: 2026-04-29
Status: Phase 4 local contract register implemented
Evidence: `layer_interface_contracts_visible`

## Zweck

Dieses Register schliesst Audit-Luecke `L-05`: alle sieben Runtime-Schichtgrenzen muessen eine sichtbare Methode, einen Pfad, ein Request-Schema, ein Response-Schema, Status und Evidence-Referenz besitzen.

Die maschinenlesbare Quelle ist:

- `GET /api/v1/layer-interfaces/contract`

## Abgedeckte Grenzen

| ID | Quelle | Ziel | Methode | Pfad | Evidence |
| --- | --- | --- | --- | --- | --- |
| `L1-L2` | Frontend / Next.js | Agent API | `POST` | `/api/v1/prompt` | `prompt_input_contract_visible` |
| `L2-L2SSE` | Frontend / Next.js | Agent API SSE | `POST` | `/api/v1/orchestrator/dry-run/stream` | `phase2_sse_event_contract_proof` |
| `L2-L3` | Agent API / Orchestrator | Agent Pool | `POST` | `/internal/tasks` | `task_session_uuid_fail_closed_proof` |
| `L2-L4` | Orchestrator / LangGraph | LLM Gateway | `POST` | `/llm/v1/chat/completions` | `llm_gateway_streaming_dry_run` |
| `L2-L5` | Orchestrator / LangGraph | MCP Gateway | `POST` | `/mcp/api/v1/tools/execute` | `mcp_tool_session_bound_audit` |
| `L2-L6` | Agent API / Memory Worker | PostgreSQL pgvector Memory | `GET/DELETE` | `/api/v1/memory/search` and `/api/v1/memory` | `memory_purge_completed` |
| `L7-OBS` | All runtime layers | Observability | `GET` | `/api/v1/audit/recent`, `/api/v1/audit/mcp`, `/api/v1/agent-activity/recent`, `/api/v1/metrics` | `agent_activity_filtered_feed_visible` |

## Nicht-Behauptungen

- Kein Hosted-Staging-Erfolg ohne `STAGING_BASE_URL`.
- Kein Branch-Protection-Erfolg ohne `BRANCH_PROTECTION_TOKEN`.
- Kein Cloudflare-native Hosted-State ohne O2', Zero-Card-Proof und
  `cloudflare_native_zero_card_hosted_runtime`-Evidence.
- Fly.io und `FLY_API_TOKEN` sind nur historische Provenienz.
- Keine Live-Provider-Calls, Live-MCP-Writes oder Production-Deploys durch diesen Contract.
