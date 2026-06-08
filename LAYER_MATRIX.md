## L1–L7 Layer Matrix (Implementation + Wiring)

Diese Matrix beschreibt die real implementierten Verbindungen im aktuellen Stack. Lokal gilt: DEV-ONLY; Hosted Proof ist blocked bis External Gates offen sind.

### L1 — Daten & Speicher

- PostgreSQL (pgvector): Persistenz fuer Sessions/Tasks/Memory + Checkpointer
- Redis: Queue + working memory + rate/session guards
- Artifacts: `.phase1-artifacts/` fuer Proof-Outputs (ohne Secrets)

### L2 — Modelle & LLM Gateway

- LLM Gateway (dry-run): OpenAI-kompatible Endpunkte + SSE Streaming
- Routing Policy: allow/deny Entscheidungen ohne Live-Provider-Calls

### L3 — Agent Pool & Worker

- LangGraph Orchestrator: dry-run Graph + SSE Event Stream
- agent-worker: Task consumption aus Redis + Status persistence
- memory-worker: Konsolidierung + Purge/Redaction Proofs

### L4 — API & Gateways

- agent-api: Contracts/Surfaces fuer Tasks, Memory, Progress, Limits, Security Headers
- mcp-gateway: dry-run contracts fuer GitHub/Postgres/Filesystem/Playwright/E2B
- nginx: Routing `/api`, `/mcp`, `/llm` und Frontend ueber `:8081`

### L5 — Frontend & UI

- Next.js 15 App Router: Workbench, Organism, Diagnostics, Tools, Evidence, usw.
- Browser Contracts: Marker/Contracts werden via `verify-browser-contract.ps1` geprueft

### L6 — Cloud & Infrastruktur

- Compose dev: lokale Runtime Proofs
- Compose cloud: pull-based substrate Guards, aber hosted deploy bleibt gated (Owner approval + Secrets)

### L7 — Verification & Governance

- `scripts/verify-phase1.ps1`: Repo/Governance/Security/Manifest Guards
- `scripts/verify-phase1-runtime.ps1`: Runtime Contracts + Stability Proofs
- `scripts/verify-browser-contract.ps1`: Browser/UI/Contracts (DEV-ONLY optional)
- `scripts/verify-external-gates.ps1`: Hosted/Production Claims (BLOCKED ohne echte HTTPS URLs/Tokens)

## Wichtigste Verschachtelungen (Wiring)

- L1 → L3: Redis Queue + Postgres Checkpoints/State (LangGraph) + Memory persistence
- L2 → L3: LLM SSE (dry-run) → Orchestrator/Agent Streaming → Memory/Task updates
- L3 → L4: Agent Tasks/Policies → agent-api endpoints + audit events
- L4 → L5: HTTP/SSE → UI Panels (Workbench/Organism/Diagnostics)
- L5 → L6: nginx Reverse Proxy / Compose Networking
- L6 → L7: CI/Verifier-Execution (lokal), hosted verification nach External Gate Freischaltung
