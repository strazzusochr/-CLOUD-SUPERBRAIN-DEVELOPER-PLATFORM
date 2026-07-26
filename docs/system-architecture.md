# System Architecture - PATCHED

Stand: 2026-07-26
Status: Cloudflare-native target; RC10 runtime retained as historical local proof

## Active Target Override

`docs/adr/ADR-010-cloudflare-native-free-runtime.md` selects Architecture A as the
zero-cost target: LangGraph.js on Workers with custom D1 persistence, SQLite Durable Objects,
Queues and a private R2 adapter. Fly.io is OUT for new Session-9 work. The Fly/PostgreSQL/Redis
tables below remain the last verified RC10 baseline and migration checklist, not an
authorization to spend, deploy, or reactivate Fly.

The Cloudflare adapter is `DEV-ONLY; hosted proof still blocked`. R2's published
free quota is not treated as a zero-card proof because current setup documentation requires a
subscription checkout. No legacy lock is removed from verification until O2' proves hosted
Cloudflare parity without a card or paid plan.

The active external gate is `cloudflare_native_zero_card_hosted_runtime`.
`external-gate-summary-v2` and `external-gate-audit-v2` are authoritative for
hosted readiness. Fly.io and `FLY_API_TOKEN` are `historical_only` and cannot
close an active gate.

## 1. Binding Source

`docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md` is the highest local architecture truth. Older references to CPX51, Supabase as active MVP database, Qdrant in Phase 1-5, or 30-minute memory consolidation are superseded.

## 2. Current Target Locks

- Vercel remains the frontend target; the stateful hosted target is Cloudflare
  Workers, D1, SQLite Durable Objects, Queues, and a zero-card artifact adapter.
- Infrastructure budget remains capped at 20 EUR/month.
- D1 custom persistence is not claimed as an official LangGraph checkpointer.
- PostgreSQL, Redis, and pgvector remain verified RC10 local-runtime provenance
  until O2' hosted parity is proven; they are not the new hosted target.
- Hosted semantic vector search remains separately Owner-gated through
  `live_vector_memory_search`.
- Qdrant is explicitly excluded until Phase 6 evaluation.
- LangGraph is the core state machine for orchestration.
- CrewAI may only run locally inside a LangGraph Agent-Executor node.
- Memory consolidation interval is 5 minutes.
- Budget-Guard node must run before paid API calls.
- Frontend/backend streaming uses contractual SSE.
- Branch protection and gitleaks are mandatory before agent write workflows.

## 3. Seven Technical Layers

| Layer | Current target / verified fallback | Inputs | Outputs | Responsibilities | Forbidden |
| --- | --- | --- | --- | --- | --- |
| 1 Frontend | Vercel/Next.js | User prompt, session state from API | REST/SSE calls to agent-api | Prompt UI, streaming output, agent status, budget banner | Direct DB calls, direct provider calls, secrets |
| 2 Orchestration | Cloudflare Workers/LangGraph.js target; FastAPI/LangGraph RC10 local fallback | REST/SSE requests | Task assignments, SSE events | Intent parsing, routing, graph state, budget guard, recovery | Provider bypass, schema changes without ADR |
| 3 Agent Pool | Workers/Queues target; Docker containers RC10 local fallback | Task assignments | Result envelopes | Planner, Coder, Tester, DevOps execution | Main writes, production deploys, uncontrolled loops |
| 4 LLM Gateway | LiteLLM | Generic LLM requests | Model responses, cost/provider events | Routing, rate limits, fallback, caching policy | Direct provider calls, sensitive prompt caching |
| 5 Tool MCP | MCP gateway | Tool requests | Tool results with audit data | GitHub, E2B, Playwright, Filesystem, Postgres readonly | Untimed tool calls, unlogged tool calls |
| 6 Memory | D1/SQLite Durable Objects target; Redis + PostgreSQL/pgvector RC10 local fallback | Run events, memory search | Working context, long-term memory | Coordination, retrieval, purge support | Unverified Vectorize claims, Qdrant Phase 1-5, MemorySaver in production |
| 7 Observability | Langfuse/Prometheus/Grafana | Traces, metrics, costs | Dashboards, alerts, audit | Evidence, cost tracking, alerting | Mixing observability UI into main app, secrets in traces |

## 4. Deployment Targets

| Target | Role | Gate |
| --- | --- | --- |
| Vercel | Frontend only | No direct DB/provider access |
| Cloudflare-native runtime | Workers, LangGraph.js, D1, SQLite Durable Objects, Queues; artifact adapter only after zero-card proof | O2' plus hosted source-parity/stateful-roundtrip verifier |
| Fly.io | Historical RC10 provenance only | Cannot satisfy any active gate |

## 5. Data Flow

```text
User -> Next.js Frontend -> REST/SSE -> FastAPI Agent API
  -> LangGraph Intent Parser
  -> Budget Guard
  -> Task Router
  -> Agent Executor
     -> LiteLLM Gateway -> model provider
     -> MCP Gateway -> GitHub/E2B/Playwright/Filesystem/Postgres-readonly
     -> Memory -> Redis + PostgreSQL/pgvector
  -> Result Aggregator
  -> Memory Updater
  -> SSE response stream -> Frontend
```

## 6. Active Gates

- No Qdrant before Phase 6.
- No CPX51 before measured resource need and budget proof.
- No Supabase-as-active-MVP-DB claim after PATCHED; ADR-007 supersedes ADR-004.
- No retired legacy provider as an active default after the 2026-06-08 cloud rewiring; historical references do not satisfy active gates.
- No release-ready claim without CI, tests, observability evidence, rollback note, and release checklist.
