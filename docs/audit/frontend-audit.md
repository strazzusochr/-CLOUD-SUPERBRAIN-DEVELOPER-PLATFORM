# Frontend Audit — 22 routes

Status legend: **PASS** = renders + verified, **WARN** = renders with spec_only/mock data,
**BLOCKED** = honest gap. Verified via `next build` (31 routes), `eslint .` (0 findings),
route smoke (HTTP 200), and Playwright `e2e/organism.spec.ts`.

| # | Route | Purpose | Data source | Proof / Status |
|---|-------|---------|-------------|----------------|
| 1 | `/` | Marketing landing + hero organism | static + `regionMap` | 200, screenshot · **PASS** |
| 2 | `/home` | Product dashboard (not audit-first) | static + `platform.ts` | 200 · **PASS** |
| 3 | `/login` | Auth / onboarding | static | 200 · **PASS** |
| 4 | `/workbench` | Real workspace (explorer/editor/preview/dock) | static + mini-cortex | 200 · **PASS** |
| 5 | `/files` | Knowledge bases (memory surfaces) | `platform.ts` memory surfaces | 200 · **WARN** (spec_only) |
| 6 | `/files/local` | Read-only local files | `platform.ts` PROJECT_TREE | 200 · **PASS** (read_only_redacted) |
| 7 | `/organism` | 3D collective organism | `regionMap` HUBS + `/api/v1/organism/*` | 200, WebGL canvas, screenshot · **PASS** |
| 8 | `/organism/live` | Organism live mode | OrganismView | 200 · **PASS** |
| 9 | `/organism/replay` | Organism replay mode | `/api/v1/organism/replay` (mock) | 200 · **WARN** (mock) |
| 10 | `/organism/map` | Organism map mode | OrganismView | 200 · **PASS** |
| 11 | `/agents` | 4 real agent profiles | `platform.ts` AGENTS (models.py) | 200 · **PASS** |
| 12 | `/tools` | MCP tools + 8 providers | `platform.ts` + `regionMap` | 200 · **PASS** |
| 13 | `/marketplace` | Skills/agents/MCP/models | `platform.ts` (26 blocks) | 200 · **PASS** |
| 14 | `/observe` | Health/metrics/traces | real services + spec_only charts | 200 · **WARN** (spec_only charts) |
| 15 | `/evidence` | Verifier proofs + claim guard | branch proofs + VERIFIERS | 200 · **PASS** |
| 16 | `/settings` | Governance + gate matrix | CLOSED_GATES | 200 · **PASS** |
| 17 | `/diagnostics` | Project progress + archive | MANIFEST snapshot 2026-05-07 | 200 · **WARN** (dated manifest) |
| 18 | `/design-system` | Tokens/components | static | 200 · **PASS** |
| 19 | `/responsive` | Responsive preview (alias → /design-system/responsive) | static | 200 · **PASS** |
| 20 | `/technology` | Tech stack (alias → /about/stack) | `regionMap` 7×8 | 200 · **PASS** |
| 21 | `/open-source` | Open-by-design (alias → /about/open-source) | static | 200 · **PASS** |
| 22 | `/games` | Game projects | static/local preview | 200 · **WARN** (demo) |
| 23 | `/media` | Media workflow | static | 200 · **WARN** (spec_only) |
| 24 | `/docs-output` | Documents workflow | local markdown | 200 · **WARN** (local_files) |
| 25 | `/apps` | Generated apps | static cards | 200 · **WARN** (mixed labels) |

API surfaces: `/api/v1/organism/contract` (**PASS**, organism-surface-v1) ·
`/api/v1/organism/{live-state,events,replay}` (**WARN**, `source:mock,live:false`) ·
`/api/health`, `/health` (**PASS**).

No page makes a false claim; spec_only/mock/demo/blocked are labelled. Home and Workbench
carry no project-status/gate matrix as hero (that lives on /diagnostics + /evidence).
