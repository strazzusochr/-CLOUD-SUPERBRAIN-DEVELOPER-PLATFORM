## L3 — Agent Pool & Worker (LangGraph, agent-worker, memory-worker)

### Implementierung (Ist-Stand)

- LangGraph Orchestrator mit dry-run Execution + SSE Event Stream.
- agent-worker konsumiert Redis Queue, persistiert Status/Events.
- memory-worker konsolidiert Memory und liefert Feed/Job Status Surfaces.

### Wiring (L3 ↔ L1/L2/L4)

- L1: Redis Queue + Postgres Checkpoints.
- L2: LLM Gateway SSE wird konsumiert und fail-closed behandelt.
- L4: agent-api exponiert Task- und Orchestrator-Surfaces, enforced policies.

### Verifikation (DEV-ONLY)

- `npm run verify:runtime` prueft u.a.:
  - Phase2 runtime graph start + replay/checkpoint recovery
  - worker status regression harness
  - task assignment queue contract

Referenzen:
- `docs/runtime-contracts/langgraph-orchestrator.md`
- `docs/runtime-contracts/task-assignment-queue-contract.md`
