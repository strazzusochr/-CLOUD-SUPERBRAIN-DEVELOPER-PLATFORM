# PLATFORM INVENTORY — everything built, accounted for
# Project: -CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM
# Date: 2026-06-15 · Branch: fly-cloud-redirect (HEAD e0752476)
# Counts measured live from the repo. This is the complete accounting, including artifacts that
# are correctly NOT page-wired (internal endpoints, worker functions, infrastructure verifiers).

> The 4.19 GB on disk is dominated by `node_modules` (613M), `.codex` runs (381M) and `.git` (372M)
> — not product code. The actual implemented surface is inventoried below.

---

## 1. BACKEND SERVICES (5) — 17,206 lines of Python

| Service | Endpoints | Py files | Lines | Role |
|---------|-----------|----------|-------|------|
| agent-api | **152** | 9 | 14,128 | Orchestration, contracts, tasks, memory, gates, organism, workspace, clouds |
| llm-gateway | **11** | 2 | 1,221 | LiteLLM-style routing, dry-run + local llama opt-in, responses adapter |
| mcp-gateway | **8** | 1 | 868 | MCP tool contracts (GitHub/Postgres/Filesystem/Playwright/E2B), version pinning |
| agent-worker | 0 (worker) | 2 | 690 | Redis task consumer — **30 functions** (heartbeat, result envelopes, status, escalation) |
| memory-worker | 0 (worker) | 2 | 299 | 5-min consolidation — **17 functions** (purge, redaction, secret-scan, embedding) |

### agent-api endpoint surfacing
- **152 endpoints total**; **130 surfaced on the 22 pages** (page dataSources, parity-wired).
- 22 not page-surfaced (by design): 6 internal-only (`/api/v1/internal/*`), 8 templated `{param}`
  detail routes (their base is surfaced), 5 compat aliases (`/api/agents`, `/team/status`, …, whose
  `/api/v1/` original is surfaced), 3 put-only.

---

## 2. FRONTEND — Next.js 16 App Router

| Artifact | Count | Notes |
|----------|-------|-------|
| Pages (`page.tsx`) | 25 | 22 canonical + `/`, `/organism/live`, `/responsive` supplemental |
| Components (`.tsx`) | 12 | AppShell, batch1-workbench-studio, goal-b/batch4/batch5-actions, organism (CortexCanvas/3D/Live), ui |
| Lib modules (`.ts`) | 7 | nav, workspaceWiring, workspaceVerticalStack, referenceDesign, platform, paidCapabilities, agentApi |
| API routes (`route.ts`) | 12 | organism contract/topology/regions/safety/events/replay/live-state, workspace wiring/vertical-stack, design, platform/verify, health |
| E2E specs | 4 | organism, goal-b-action-to-result, f2-real-agents, + |

---

## 3. CAPABILITY REGISTRIES (all directly page-wired)

| Class | Count | Surfaced on (hub/region) |
|-------|-------|--------------------------|
| LLM models | 12 catalog / 4 routed | marketplace, media |
| Agent profiles | 4 | agents |
| Live-agent profiles | 12 | agents |
| Skills | 10 | tools, settings |
| MCP tools | 8 | tools, settings |
| Cloud providers | 8 | organism-map, technology, open-source |
| Safety gates | 8 | login, settings, diagnostics |
| Brain regions | 10 | all pages (page→region) |
| Capability hubs | 8 | all pages (page→hub) |
| Architecture layers | 7 | all pages (page→layer) |

Organism topology: **231 nodes / 484 edges**, 0 isolated, 0 unable to reach a page — every built
capability is directly wired to the 22 pages.

---

## 4. VERIFICATION & GOVERNANCE (infrastructure — not page content)

| Artifact | Count |
|----------|-------|
| `verify-*.ps1` verifiers | **191** |
| Python verifiers (`scripts/*.py`) | 6 |
| Browser proof scripts (`.cjs`) | 2 |
| Total files under `scripts/` | 231 |

These prove the platform (gates, contracts, browser, topology, security, manifest) — they are
correctly NOT surfaced as page data sources.

---

## 5. INFRASTRUCTURE

| Artifact | Count | Detail |
|----------|-------|--------|
| Compose files | 2 | `docker-compose.dev.yml` (11 services), `docker-compose.cloud.yml` (10 services) |
| Fly configs | 6 | agent-api, llm-gateway, mcp-gateway, agent-worker, memory-worker, fly.toml |
| Dockerfiles | 6 | one per service + frontend |
| nginx confs | 2 | dev.conf, cloud.conf (edge routing /api·/mcp·/llm·/) |
| Caddy | 1 | TLS edge (`:80` default, ACME on real host) |

---

## 6. WHAT "EVERYTHING" MEANS HERE

- **Product surface (page-wired):** 22 pages × {UI, API, Data, Verification, Deploy, Safety} +
  130/152 endpoints + all 6 capability classes — all directly connected to the 22 pages and
  browser-proven.
- **Engine surface (functional, not page content):** 47 worker functions, 191 verifier scripts,
  the build/CI/Fly/compose infrastructure — built, exercised by the verifier battery, and correctly
  not page data sources.
- **Non-code mass:** node_modules / .codex runs / .git history make up most of the 4.19 GB.

Every category above is either directly wired to the 22 pages (product surface) or proven by the
verifier battery (engine + infra). Nothing built is orphaned.

— END OF PLATFORM INVENTORY —
