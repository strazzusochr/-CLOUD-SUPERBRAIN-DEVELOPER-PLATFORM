# 7-Layer Wiring Report

Each architecture layer, its real source, runtime/API (or honest BLOCKED reason),
tests, evidence, and status. Source of truth for the cloud mapping:
`services/agent-api/app/clouds.py` (`cloud_provider_state().seven_layer_mapping`).

| Layer | Source files | Runtime / API | Tests | Evidence | Status |
|-------|--------------|---------------|-------|----------|--------|
| **FE** Frontend / Application | `apps/frontend/app/**`, `components/**` | `next build` (31 routes), Vercel `frontend` deploy | `e2e/organism.spec.ts` (routes + WebGL) | build green, route smoke 200, screenshot | **PASS** |
| **ORC** Orchestration | `services/agent-api/app/main.py` (phase2 runtime, orchestrator), `clouds.py` layer_2 → Hetzner | hosted only; not run locally | `scripts/verify-phase4-phase2-runtime-*.ps1` | docs/release-artifacts | **BLOCKED** (no local runtime) |
| **AP** Agent Pool | `services/agent-api/app/models.py` (`AGENT_PROFILES`), `tasks.py`, `orchestrator.py` | `/api/v1/agents/status` (hosted) | `scripts/verify-phase4-*agents*.ps1` | `/agents` UI mirrors agent-profiles-v1 | **WARN** (UI PASS, live hosted-only) |
| **LLM** LLM Gateway | `services/llm-gateway/**`, `models.py` MODEL_ROUTES, `clouds.py` layer_4 → Cloudflare + HF | hosted only | `scripts/verify-phase4-*llm*.ps1` | rotation policy, model matrix | **BLOCKED** (no local runtime) |
| **MCP** MCP Gateway / Tools | `services/mcp-gateway/**`, `clouds.py` layer_5 → GitHub/GHCR/GitLab/GitKraken | hosted only; `/tools` UI lists allowed_tools | `scripts/verify-phase4-mcp-audit-feed-*.ps1` | `/tools` UI, audit feed contract | **WARN** (UI PASS, live hosted-only) |
| **MEM** Memory / Data | `services/agent-api/app/main.py` memory routes, `clouds.py` layer_6 → Hetzner pgvector | hosted only; `/files` UI shows surfaces | `scripts/verify-phase4-memory-*.ps1` | embedding-consistency contract (vector 1536) | **BLOCKED** (no local runtime) |
| **OBS** Observability / Evidence | `services/agent-api` metrics/costs/audit, `apps/frontend/app/{observe,evidence,diagnostics}` | `/observe`, `/evidence`, `/diagnostics` UI; hosted metrics | `verify_project_progress_manifest.py`, `e2e` | `/evidence` proofs, gate matrix | **WARN** (UI PASS, live hosted-only) |

**Cloud providers (8) backing the layers** (clouds.py): Vercel(L1,7) · Hetzner(L2,3,6,7) ·
Cloudflare(L4,7) · GitHub(L5,7) · GHCR(L5) · Hugging Face(L4,7) · GitLab(L5,7) · GitKraken(L5,7).

**Honest summary:** the Frontend layer is fully runnable + tested here (PASS). The backend
layers (ORC/LLM/MEM) are real source with hosted-only runtime — they are **BLOCKED** for
local proof because the Python `agent-api` is not run in this environment. AP/MCP/OBS are
PASS on the UI mirror and hosted-only for live data. No layer claims live status without a
verifier; production deploy / provider writes / pushes stay gate-closed.
