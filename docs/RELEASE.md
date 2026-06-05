# Cloud Superbrain — Release v1.0.0

Workbench-first AI developer organism platform. Release build wired to the local
**7-layer runtime** at `http://localhost:8081`, with every page projecting live,
layer-verified data and an honest spec/mock fallback when the runtime is unreachable.

## Run the release (against the 7-layer runtime)

```bash
# 1. The 7-layer runtime (postgres/pgvector · redis · agent-api · agent-worker ·
#    memory-worker · mcp-gateway · llm-gateway, behind nginx :8081), dry-run, no secrets:
docker compose -f docker-compose.dev.yml up -d

# 2. Build + start the release frontend, wired to http://localhost:8081:
cd apps/frontend
npm run release:build
npm run release            # → http://localhost:3000  (override PORT / AGENT_API_INTERNAL_URL)
```

The launcher (`apps/frontend/release.mjs`) defaults `AGENT_API_INTERNAL_URL=http://localhost:8081`.
No secret/token value is ever read or printed; production deploy, provider writes and
registry pushes stay gate-closed.

## Verified across all 7 layers (localhost:8081)

`GET /api/v1/clouds/layers` → **layer_1 … layer_7 all `live_verified`**.
`GET /api/v1/project/progress` → **overall 100 %, evidence-based**, all 7 phases verified.
`GET /api/v1/health` → **all six runtime services healthy**.

| Layer | Name | Status | Surfaced on |
|-------|------|--------|-------------|
| **L1** | Frontend / Next.js | `live_verified` | every page · `/technology` |
| **L2** | Orchestrator / LangGraph | `live_verified` | `/organism` live-state · `/diagnostics` |
| **L3** | Agent Pool | `live_verified` | `/agents` live roster (12) |
| **L4** | LLM Gateway (dry-run) | `live_verified` | `/observe` · `/marketplace` |
| **L5** | MCP Gateway / Tools | `live_verified` | `/tools` cloud readiness (8/8) |
| **L6** | Memory / pgvector | `live_verified` | `/files` (live entry count) |
| **L7** | Observability / Evidence | `live_verified` | `/observe` · `/evidence` · `/diagnostics` |

The project plan itself (**7 phases × 7 layers**, binding document
`docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md`, truth policy *evidence-based only*)
is embedded live on `/diagnostics`, and the `SevenLayerBar` shows `N/7 live_verified` on
`/technology`, `/evidence`, `/organism`, `/diagnostics` and `/home`.

## Release verification (this branch)

- `next build` green (33 routes) · `eslint .` 0 findings · `tsc` strict 0 errors.
- Playwright **7/7** green incl. WebGL + GLB render proof and the dead-route 404 guard.
- Full-page sweep **25/25** routes HTTP 200 with a document-outline `<h1>` and **0 console errors**
  (with the live runtime connected).
- `gitleaks` — **no leaks** (no token value in the repo or UI).
- CI green: Vercel `frontend` + `cloud-superbrain-developer-platform` + GitHub `verify`.

## Honest scope

- Live data is proven on the **local docker-compose runtime** (LLM in
  `deterministic_dry_run`, `live_provider_calls: false`). On Vercel (no reachable
  agent-api) the pages render their labelled spec/mock fallback — never fake-live.
- `/games`, `/media`, `/docs-output` remain honest preview/spec/demo surfaces (their
  generators are not provider-wired).
- Production deploy / provider writes / pushes remain OPA-gate-closed by policy.
