# Phase 1 Foundation Package - PATCHED

Stand: 2026-04-25
Status: Ready for execution scaffolding

## Purpose

Phase 1 now moves from design-only into foundation implementation, according to `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md`.

## Phase 1 Must Build

1. `docker-compose.dev.yml` for the five-service app stack: nginx, agent-api, mcp-gateway, postgres/pgvector, redis.
2. `.env.example` with placeholders only.
3. PostgreSQL init script for `superbrain_prod`, `langfuse`, `pgvector`, and `pgcrypto`.
4. Minimal FastAPI `agent-api` with health, prompt creation, and SSE stream stub.
5. Minimal FastAPI `mcp-gateway` with health and tool registry status.
6. Optional Next.js frontend scaffold only after API and compose config validate.
7. gitleaks configuration before any agent write workflow.

## Explicit Non-Goals

- No Qdrant.
- No CPX51 target.
- No production deploy.
- No real secrets.
- No live LLM provider calls before Budget-Guard and rate-limits.
- No release-ready claim.

## Verification Required

- `docker compose config` succeeds.
- No `latest` images.
- No Qdrant service.
- Data ports are internal only.
- Health checks exist for every service.
- `git diff --check` passes.
- Secret scan is clean once gitleaks is installed.
