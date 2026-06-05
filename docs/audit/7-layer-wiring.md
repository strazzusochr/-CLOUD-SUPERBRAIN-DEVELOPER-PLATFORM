# 7-Layer Wiring Report

Each architecture layer, its real source, runtime/API (or honest BLOCKED reason),
tests, evidence, and status. Source of truth for the cloud mapping:
`services/agent-api/app/clouds.py` (`cloud_provider_state().seven_layer_mapping`).

Local runtime evidence (`docker-compose.dev.yml`, no secrets, LLM `deterministic_dry_run`):
`/api/v1/health` → agent-api **healthy**; postgres **healthy** (`superbrain_prod`, 6 tables,
4 checkpoint tables, extensions `pgcrypto` + `vector`); redis healthy; agent-worker healthy;
mcp-gateway + llm-gateway healthy (`live_provider_calls: false`). `/api/v1/clouds/layers`
(`cloud-layer-readiness-v1`) reports **layer_1…layer_7 all `live_verified`**. Raw capture:
`docs/audit/backend-runtime-evidence.md`. (memory-worker consolidation loop = down → MEM partial.)

| Layer | Source files | Runtime / API | Tests | Evidence | Status |
|-------|--------------|---------------|-------|----------|--------|
| **FE** Frontend / Application | `apps/frontend/app/**`, `components/**` | `next build` (37 routes), Vercel `frontend` deploy | `e2e/organism.spec.ts` (routes + WebGL) | build green, route smoke 200, screenshot | **PASS** |
| **ORC** Orchestration | `services/agent-api/app/main.py` (phase2 runtime, orchestrator), `clouds.py` layer_2 → Hetzner | **local docker-compose**: agent-api up, postgres checkpointer ensured (dry-run); hosted = prod | `/api/v1/health`, `/api/v1/clouds/layers` | layer_2 `live_verified` (local), `docs/audit/backend-runtime-evidence.md` | **PASS** (local dry-run; prod hosted) |
| **AP** Agent Pool | `services/agent-api/app/models.py` (`AGENT_PROFILES`), `tasks.py`, `orchestrator.py` | **local**: `/api/v1/live-agents/status` serves 12 agents; agent-worker heartbeat healthy | `e2e`, live status probe | layer_3 `live_verified`, `/agents` UI mirrors agent-profiles-v1 | **PASS** (local + UI) |
| **LLM** LLM Gateway | `services/llm-gateway/**`, `models.py` MODEL_ROUTES, `clouds.py` layer_4 → Cloudflare + HF | **local**: llm-gateway healthy, `mode: deterministic_dry_run`, `live_provider_calls: false` | `/llm/api/v1/health` | layer_4 `live_verified` (dry-run), no live call | **PASS** (local dry-run; live calls gated) |
| **MCP** MCP Gateway / Tools | `services/mcp-gateway/**`, `clouds.py` layer_5 → GitHub/GHCR/GitLab/GitKraken | **local**: mcp-gateway healthy; `/tools` UI lists allowed_tools | `/mcp/api/v1/health`, audit feed | layer_5 `live_verified`, `/tools` UI | **PASS** (local; writes gated) |
| **MEM** Memory / Data | `services/agent-api/app/main.py` memory routes, `clouds.py` layer_6 → Hetzner pgvector | **local**: postgres + pgvector (`vector` ext) healthy, memory routes live; consolidation worker down | `/api/v1/health` (postgres), memory probes | layer_6 `live_verified`, pgvector extension present | **WARN** (store live; consolidation worker down) |
| **OBS** Observability / Evidence | `services/agent-api` metrics/costs/audit, `apps/frontend/app/{observe,evidence,diagnostics}` | **local**: `/api/v1/metrics`, health surface live; `/observe`,`/evidence`,`/diagnostics` UI | `verify_project_progress_manifest.py`, `e2e` | layer_7 `live_verified`, `/evidence` proofs | **PASS** (local + UI) |

**Cloud providers (8) backing the layers** (clouds.py): Vercel(L1,7) · Hetzner(L2,3,6,7) ·
Cloudflare(L4,7) · GitHub(L5,7) · GHCR(L5) · Hugging Face(L4,7) · GitLab(L5,7) · GitKraken(L5,7).

**Honest summary:** all seven layers now have a **local runtime proof** via
`docker-compose.dev.yml` — the Python `agent-api` + `postgres`/`pgvector` + `redis` +
`mcp-gateway` + `llm-gateway` + `agent-worker` run locally (no secrets), and
`/api/v1/clouds/layers` reports every layer `live_verified`. This is a **dry-run** runtime:
the LLM gateway is `deterministic_dry_run` with `live_provider_calls: false`, so no real
provider call is made. MEM is **WARN** only because the memory-consolidation worker
heartbeat is down (the pgvector store itself is healthy). Hosted production is a separate,
gated environment. No layer claims a *live provider* call; production deploy / provider
writes / pushes stay gate-closed. The organism `/api/v1/organism/live-state` route now binds
to this runtime (`source: agent-api, live: true`) when reachable and falls back to a
deterministic, clearly-labelled mock (`source: mock, live: false`) otherwise (e.g. on Vercel).
