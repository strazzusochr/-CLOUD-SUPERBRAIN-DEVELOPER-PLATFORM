# Frontend Audit — 22 pages (25 routes)

Status legend: **PASS** = renders + verified, **WARN** = renders with spec_only/mock data
(honestly labelled), **BLOCKED** = honest gap. Verified via `next build` (32 routes), `eslint .`
(0 findings), route smoke (HTTP 200), and Playwright `e2e/organism.spec.ts` (6 tests).

"Live (when reachable)" pages project from the local agent-api runtime
(`AGENT_API_INTERNAL_URL`) and fall back to a clearly-labelled spec/mock on Vercel — never fake-live.

| # | Route | Purpose | Data source | Proof / Status |
|---|-------|---------|-------------|----------------|
| 1 | `/` | Marketing landing + hero organism | static + `regionMap` | 200, screenshot · **PASS** |
| 2 | `/home` | Product dashboard (not audit-first) | static + `platform.ts` | 200 · **PASS** |
| 3 | `/login` | Auth / onboarding | static | 200 · **PASS** |
| 4 | `/workbench` | Real workspace (explorer/editor/preview/dock) | static + mini-cortex | 200 · **PASS** |
| 5 | `/files` | Knowledge bases + live pgvector count | `platform.ts` + `/api/v1/metrics` | 200, "978 entries" live · **PASS** |
| 6 | `/files/local` | Read-only local files | `platform.ts` PROJECT_TREE | 200 · **PASS** (read_only_redacted) |
| 7 | `/organism` | 3D collective organism (PBR/basic dual-path) | `regionMap` + `/api/v1/organism/*` | 200, WebGL canvas, screenshot · **PASS** |
| 8 | `/organism/live` | Organism live mode | OrganismView | 200 · **PASS** |
| 9 | `/organism/replay` | Organism replay mode | `/api/v1/organism/replay` (live agent-activity / mock) | 200 · **PASS** |
| 10 | `/organism/map` | Organism map mode | OrganismView | 200 · **PASS** |
| 11 | `/agents` | 4 real agent profiles | `platform.ts` AGENTS (models.py) | 200 · **PASS** |
| 12 | `/tools` | MCP tools + 8 providers | `platform.ts` + `regionMap` | 200 · **PASS** |
| 13 | `/marketplace` | Skills/agents/MCP/models | `platform.ts` (26 blocks) | 200 · **PASS** |
| 14 | `/observe` | Health/metrics/traces | live `/api/v1/metrics` (+ spec-only chart) | 200, live numbers · **PASS** |
| 15 | `/evidence` | Verifier proofs + claim guard | branch proofs + VERIFIERS | 200 · **PASS** |
| 16 | `/settings` | Governance + gate matrix | CLOSED_GATES | 200 · **PASS** |
| 17 | `/diagnostics` | Project progress + archive | live `/api/v1/project/progress` (manifest fallback) | 200 · **PASS** |
| 18 | `/design-system` | Tokens/components | static | 200 · **PASS** |
| 19 | `/responsive` | Breakpoint matrix + a11y/reduced-motion | static (real page, not alias) | 200, e2e content asserted · **PASS** |
| 20 | `/technology` | 7×8 architecture + full toolstack | `regionMap` 7×8 + static | 200, e2e content asserted · **PASS** |
| 21 | `/open-source` | OSS principles + 14-component license table | static (real page, not alias) | 200, e2e content asserted · **PASS** |
| 22 | `/games` | Game projects workflow | static/local preview | 200 · **WARN** (demo, labelled) |
| 23 | `/media` | Media workflow | static | 200 · **WARN** (spec_only, labelled) |
| 24 | `/docs-output` | Documents workflow | local markdown | 200 · **WARN** (local_files, labelled) |
| 25 | `/apps` | Generated apps | static cards | 200 · **PASS** (honest per-card labels) |

**Removed (de-duplicated):** `/about/stack`, `/about/open-source`, `/design-system/responsive`
were re-export shortcut targets; consolidated into the real top-level pages above and now
return **404** (asserted by e2e). All internal links repointed.

API surfaces: `/api/v1/organism/contract` (**PASS**, organism-surface-v1) ·
`/api/v1/organism/{live-state,events,replay}` (**PASS** — live from cloud-layer-readiness /
agent-activity-trace when reachable, `source:mock,live:false` fallback) · `/api/health`, `/health` (**PASS**).

The three remaining **WARN** pages (games/media/docs-output) are honest preview/spec_only/demo
surfaces — their generators are not provider-wired, so any "live" claim would violate the
no-fake-live rule. No page makes a false claim; spec_only/mock/demo/local_files are labelled.
Home and Workbench carry no project-status/gate matrix as hero (that lives on /diagnostics + /evidence).
