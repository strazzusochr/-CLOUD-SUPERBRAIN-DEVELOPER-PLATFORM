## L2 — Modelle & LLM Gateway

### Implementierung (Ist-Stand)

- LLM Gateway laeuft im deterministic dry-run Modus (keine Live-Provider Calls).
- OpenAI-kompatible Endpunkte inkl. SSE Streaming.
- Routing Policy Evaluator (allow/deny) ist vertraglich abgesichert.

### Wiring (L2 ↔ L3)

- L3/Orchestrator konsumiert LLM SSE und erzwingt Policy (kein direct provider bypass).
- LLM Modelle werden als read-only Katalog fuer UI/Agenten exponiert.

### Verifikation (DEV-ONLY)

- `npm run verify:runtime` prueft u.a.:
  - `/llm/api/v1/health` mode `deterministic_dry_run`
  - Streaming Contract + `data: [DONE]`
  - Routing Policy allow/deny Proofs

Referenzen:
- `docs/runtime-contracts/llm-gateway-routing.md`
- `docs/runtime-contracts/agent-llm-streaming-contract.md`
