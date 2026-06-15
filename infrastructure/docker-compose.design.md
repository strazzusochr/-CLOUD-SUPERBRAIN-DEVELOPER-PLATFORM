# Docker Compose Design - PATCHED Phase 1

Stand: 2026-04-25
Status: Implementation-ready design, synchronized with PATCHED

## Goal

Define the Phase 1 app stack for the local Docker control plane and the Fly.io/Vercel cloud target while staying below 20 EUR/month. This is the target for the executable `docker-compose.dev.yml`.

## Services

| Service | Image/Source | External Port | Internal Port | Role |
| --- | --- | --- | --- | --- |
| `nginx` | `nginx:1.27.4-alpine` | `80`/dev mapped port | `80` | reverse proxy |
| `frontend` | local build `apps/frontend` | none | `3000` | Next.js developer dashboard |
| `agent-api` | local build `services/agent-api` | none | `8000` | FastAPI control plane, SSE, LangGraph host |
| `agent-worker` | local build `services/agent-worker` | none | n/a | Redis task consumer and deterministic Phase-1 planner execution |
| `memory-worker` | local build `services/memory-worker` | none | n/a | Redis Working-Memory to PostgreSQL consolidation |
| `mcp-gateway` | local build `services/mcp-gateway` | none | `9000` | normalized tool access |
| `postgres` | `pgvector/pgvector:0.8.2-pg16` | none | `5432` | single source of truth, pgvector |
| `redis` | `redis:7.4.2-alpine` | none | `6379` | working memory, queue, rate-limit state |

## Explicit Exclusions

- No Qdrant in Phase 1-5.
- No CPX51 target in Phase 1.
- No Langfuse containers inside the main app stack unless separately budgeted and gated.
- No LiteLLM container in Phase 1 runtime until live-provider secrets are gated.
- No `latest` tags.
- No public database ports.

## PostgreSQL Layout

One PostgreSQL instance, two logical databases:

- `superbrain_prod`
- `langfuse`

`pgvector` is enabled for semantic memory in the app database.

## Health Checks

- `nginx`: `GET /health`
- `frontend`: proxied dashboard HTTP 200 through nginx
- `agent-api`: `GET /api/v1/health`
- `agent-worker`: container health check against Redis and Agent API
- `memory-worker`: container health check against Redis and PostgreSQL
- `mcp-gateway`: `GET /api/v1/health`
- `postgres`: `pg_isready`
- `redis`: `redis-cli ping`

## Resource Direction

Phase 1 defaults must fit a CX21-class start. Increase only after measured CPU/RAM pressure and budget proof.

## Definition of Done

A real `docker-compose.dev.yml` is valid only if it contains the eight services above, no Qdrant, pinned base images, health checks, internal data ports, and no secrets.
