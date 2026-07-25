# System Architecture - PATCHED

Stand: 2026-07-25
Status: RC10 baseline plus Session-9 target transition

## Session-9 Target Override

`docs/adr/ADR-010-cloudflare-native-free-runtime.md` selects Architecture A as the
zero-cost target: LangGraph.js on Workers with custom D1 persistence, SQLite Durable Objects,
Queues and a private R2 adapter. Fly.io is OUT for new Session-9 work. The Fly/PostgreSQL/Redis
tables below remain the last verified RC10 baseline and migration checklist, not an
authorization to spend, deploy, or reactivate Fly.

The Cloudflare adapter is initially `DEV-ONLY; hosted proof still blocked`. R2's published
free quota is not treated as a zero-card proof because current setup documentation requires a
subscription checkout. No legacy lock is removed from verification until O2' proves hosted
Cloudflare parity without a card or paid plan.

## 1. Binding Source

`docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md` is the highest local architecture truth. Older references to CPX51, Supabase as active MVP database, Qdrant in Phase 1-5, or 30-minute memory consolidation are superseded.

## 2. Phase 1 Architecture Locks

- Infrastructure starts small on Vercel Frontend plus Fly.io shared-cpu runtime services. No CPX51 in Phase 1.
- Infrastructure budget remains capped at 20 EUR/month.
- One PostgreSQL instance is the primary source of truth.
- Separate databases inside the same instance: `superbrain_prod` for app state and `langfuse` for observability state.
- `pgvector` is the only vector solution in Phase 1-5.
- Qdrant is explicitly excluded until Phase 6 evaluation.
- LangGraph is the core state machine for orchestration.
- CrewAI may only run locally inside a LangGraph Agent-Executor node.
- Memory consolidation interval is 5 minutes.
- Budget-Guard node must run before paid API calls.
- Frontend/backend streaming uses contractual SSE.
- Branch protection and gitleaks are mandatory before agent write workflows.

## 3. Seven Technical Layers

| Layer | Owner | Inputs | Outputs | Responsibilities | Forbidden |
| --- | --- | --- | --- | --- | --- |
| 1 Frontend | Vercel/Next.js | User prompt, session state from API | REST/SSE calls to agent-api | Prompt UI, streaming output, agent status, budget banner | Direct DB calls, direct provider calls, secrets |
| 2 Orchestration | Fly.io/FastAPI/LangGraph | REST/SSE requests | Task assignments, SSE events | Intent parsing, routing, graph state, budget guard, recovery | Provider bypass, schema changes without ADR |
| 3 Agent Pool | Docker containers | Task assignments | Result envelopes | Planner, Coder, Tester, DevOps execution | Main writes, production deploys, uncontrolled loops |
| 4 LLM Gateway | LiteLLM | Generic LLM requests | Model responses, cost/provider events | Routing, rate limits, fallback, caching policy | Direct provider calls, sensitive prompt caching |
| 5 Tool MCP | MCP gateway | Tool requests | Tool results with audit data | GitHub, E2B, Playwright, Filesystem, Postgres readonly | Untimed tool calls, unlogged tool calls |
| 6 Memory | Redis + PostgreSQL/pgvector | Run events, memory search | Working context, long-term memory | 5-minute consolidation, retrieval, purge support | Qdrant Phase 1-5, MemorySaver in production |
| 7 Observability | Langfuse/Prometheus/Grafana | Traces, metrics, costs | Dashboards, alerts, audit | Evidence, cost tracking, alerting | Mixing observability UI into main app, secrets in traces |

## 4. Deployment Targets

| Target | Role | Phase 1 Limit |
| --- | --- | --- |
| Vercel | Frontend only | No DB connections, no agent runtime |
| Fly.io shared-cpu runtime | API, agents, MCP, Redis/PostgreSQL clients, gateway services | Must stay within 20 EUR/month total infra |
| Cloudflare Free Tier | DNS, CDN, optional AI Gateway caching | No DB responsibility |

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
