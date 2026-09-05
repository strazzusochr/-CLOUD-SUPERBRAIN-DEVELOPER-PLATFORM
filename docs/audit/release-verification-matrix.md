# Release Verification Matrix

Updated: 2026-07-12

This is the current 22-page browser matrix. Local proof uses
`http://localhost:8081` and is strictly `DEV-ONLY`.

## Runtime Baseline

- Docker Compose: 10/10 services running healthy.
- Project progress: Overall 76 percent; P3 41 percent; P6 40 percent.
- Progress integrity: `verified` with computed and manifest overall both 75.
- Workspace contract: exactly 22 canonical pages and seven architecture layers.
- External audit: `blocked` on hosted Agent API, GitHub branch-protection current
  verification, Vercel backend-origin health, and Fly live-budget proof.
- Production deployment and release promotion: not allowed and not performed.

## Canonical Pages

| Route | Layer | Browser proof | Runtime boundary |
| --- | --- | --- | --- |
| `/home` | FE | HTTP 200, shell and product markers | Read-only navigation/data wiring |
| `/login` | FE | HTTP 200, shell and page markers | Auth contract; no live OAuth claim |
| `/workbench` | FE | HTTP 200, IDE controls and preview | Deterministic runtime paths |
| `/organism` | FE | HTTP 200, nonblank WebGL/2D proof | Redacted runtime projection |
| `/organism/replay` | OBS | HTTP 200, replay surface | Read-only redacted events |
| `/organism/map` | FE | HTTP 200, topology surface | Read-only topology contract |
| `/agents` | AP | HTTP 200, agent surface | Dry-run/policy-gated agent runtime |
| `/files` | MEM | HTTP 200, memory surface | PostgreSQL/pgvector plus lexical fallback |
| `/files/local` | MEM | HTTP 200, read-only search surface | No host filesystem read/write |
| `/tools` | MCP | HTTP 200, safe tool surface | Read-only/dry-run envelopes |
| `/marketplace` | LLM | HTTP 200, model/skill surface | Capability inventory, no install write |
| `/observe` | OBS | HTTP 200, metrics surface | Local metrics and audit contracts |
| `/games` | AP | HTTP 200, product surface | Client preview only; gated generation |
| `/apps` | AP | HTTP 200, product surface | Client preview only; gated generation |
| `/media` | LLM | HTTP 200, product surface | No live provider generation claim |
| `/docs-output` | MEM | HTTP 200, document surface | Local browser artifact behavior |
| `/evidence` | OBS | HTTP 200, evidence surface | Read-only gate/progress truth |
| `/diagnostics` | OBS | HTTP 200, live contract console | Read-only contracts; local CSP test audited |
| `/design-system` | FE | HTTP 200, design tokens | Static design contract |
| `/technology` | ORC | HTTP 200, seven-layer inventory | Read-only architecture/cloud inventory |
| `/settings` | MCP | HTTP 200, governance surface | All dangerous actions remain gated |
| `/open-source` | FE | HTTP 200, OSS surface | Static license/package inventory |

The workspace browser verifier checks every route for the application shell, active
navigation state, visible page markers, bounded panel styling, hidden retired providers,
hidden product-surface progress walls, and non-claims `live=false`, `writes=false`, and
`secretOutput=false` in the workspace contract. It writes one artifact per canonical
page plus `.phase1-artifacts/workspace-pages-browser-proof-latest.json`.

## Additional Browser Proof

- Phase 3 CSP: `/diagnostics` selection and Refresh click return HTTP 200 and render
  `csp-report-contract-v1`, `csp_report_contract_visible`, and
  `csp_report_audit_persisted`.
- Phase 6 local and hosted frontend proof: visible nonblank WebGL canvas, keyboard and
  camera-reset interaction, frame-budget HUD, and Reduced Motion to 2D with zero console
  errors. The additional local camera/lighting proof covers all presets, FOV steps,
  light profiles, exposure bounds, applied Three.js state, browser-local behavior, and
  zero console errors. Together these credit the first five Phase-6 rubric blocks
  (40 percent).

## Release Verdict

The 22 local pages are browser-functional, but this is not a release proof. Hosted
backend origins, current branch protection, Fly budget, immutable candidate parity,
Owner review, and promotion approval remain open. No secret use, provider write,
registry push, deployment, release promotion, live LLM call, or live MCP write is claimed.
