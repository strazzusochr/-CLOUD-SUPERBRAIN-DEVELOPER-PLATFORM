## L4 — API & Gateways (agent-api, mcp-gateway, nginx)

### Implementierung (Ist-Stand)

- agent-api (FastAPI): Health, Tasks, Memory, Progress, Limits, Security Headers, Contracts/Surfaces.
- mcp-gateway: dry-run contracts fuer Tool-Envelopes (GitHub, Filesystem, Postgres readonly, Browser proof, E2B lifecycle).
- nginx: Reverse Proxy fuer Frontend + `/api`, `/mcp`, `/llm`.

### Wiring (L4 ↔ L3/L5/L6)

- L3: Agent/Orchestrator Surfaces werden ueber agent-api exponiert.
- L5: Frontend konsumiert Contracts/Surfaces via nginx (`:8081`).
- L6: Compose + nginx upstreams definieren Service-Routing.

### Verifikation (DEV-ONLY)

- `npm run verify:browser` prueft die Contracts/Markers ueber nginx.
- `npm run verify:runtime` prueft API-Contracts + MCP health + Policy/Rate/Session Guards.

Referenzen:
- `docs/runtime-contracts/layer-interface-contracts.md`
- `docs/runtime-contracts/mcp-toolsets.md`
