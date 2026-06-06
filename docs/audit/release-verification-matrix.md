# Release Verification Matrix — every route vs the live 7-layer runtime (localhost:8081)

Produced by a 6-agent `release-verification-audit` workflow (each agent read the page
source **and** probed `http://localhost:8081`), then synthesized. Honest, evidence-based —
no route over-claims live status in a way that survives source inspection.

7 layers: **L1** Frontend · **L2** Orchestrator/LangGraph · **L3** Agent Pool ·
**L4** LLM Gateway · **L5** MCP Gateway · **L6** Memory/pgvector · **L7** Observability.
Runtime probe at audit time: `/api/v1/clouds/layers` → **L1…L7 all `live_verified`**,
`/api/v1/health` → **6/6 services healthy**. ⚠️ **Progress caveat:** the committed ledger
`docs/project-progress.manifest.json` is **overall 70 %** (P6 Scale & 3D = 0 %, P3 = 40 %,
P5 = 67 %, P2 = 86 %; L4 = 54 %, L5 = 55 %, L3 = 68 %, L6 = 72 %). The local runtime serves a
divergent 100 % from a stale manifest mount — the **70 % committed value is the evidence-based
truth**; cloud-layer-readiness (`live_verified`) is a separate, genuinely-passing signal.

Every workspace page also shows the global **`N/7 layers verified`** pill (AppShell topbar,
`/api/v1/platform/verify`). "live+fallback" = live when the runtime is reachable, honest
spec/mock label otherwise (Vercel) — never fake-live.

## Matrix (25 routes)

| Route | Mode | Layers | Verified | Backing |
|-------|------|--------|----------|---------|
| `/` | static | — | — | marketing landing (demo cortex visual) |
| `/home` | live+fallback | L1–L7 | ✅ | fetchLiveAgents + SevenLayerBar |
| `/login` | static | — | — | auth form (pre-workspace) |
| `/workbench` | static | — | — | IDE workspace canvas (sr-only h1) |
| `/files` | live+fallback | L6,L7 | ✅ | fetchMetrics → memory_entries (pgvector) |
| `/files/local` | static | L1 | — | read-only redacted file tree |
| `/organism` | live+fallback | L1–L7 | ✅ | live-state + SevenLayerBar + GLB |
| `/organism/live` | live+fallback | L1–L7 | ✅ | /api/v1/organism/live-state |
| `/organism/replay` | live+fallback | L1–L7 | ✅ | /api/v1/organism/replay (activity trace) |
| `/organism/map` | live+fallback | L1–L7 | ✅ | /api/v1/organism/live-state |
| `/agents` | live | L1,L3 | ✅ | fetchLiveAgents → /api/v1/live-agents/status (12) |
| `/tools` | live+fallback | L1,L2,L4,L5,L6 | ✅ | fetchProviders → /api/v1/clouds (8/8) |
| `/marketplace` | live+fallback | L4,L5 | ✅ | fetchProviders provider readiness *(gap closed)* |
| `/observe` | live+fallback | L2,L4,L5,L6,L7 | ✅ | fetchMetrics + /api/v1/health (chart honestly spec) |
| `/evidence` | live | L1–L7 | ✅ | fetchMetrics (gates+services) + SevenLayerBar |
| `/settings` | static | — | — | governance + gate matrix (spec) |
| `/diagnostics` | live | L1–L7 | ✅ | fetchProgress (7 phases × 7 layers) + SevenLayerBar |
| `/design-system` | static | — | — | NeuroGlass tokens/components |
| `/responsive` | static | — | — | breakpoint matrix + a11y |
| `/technology` | live+fallback | L1–L7 | ✅ | SevenLayerBar (cloud-layer-readiness) + toolstack |
| `/open-source` | static | — | — | OSS licence catalog |
| `/games` | demo | L6/L7* | ⚠️ | static templates · generators *blocked by plan* |
| `/media` | spec_only | L4/L5/L6* | ⚠️ | empty stage · providers *blocked by plan* |
| `/docs-output` | local_files | L6* | ⚠️ | static markdown preview · artifact store *not wired* |
| `/apps` | demo | L6* | ⚠️ | generated-app cards · artifact store *not wired (badge added)* |

`*` = the layer this surface *would* project once its generator/artifact store exists.

## Verdict

- **13 routes live-verified** against the runtime; **9 legitimately static** by design
  (`/`, `/login`, `/workbench`, `/files/local`, `/settings`, `/design-system`,
  `/responsive`, `/open-source`); **the 22 workspace pages all carry the global 7-layer
  verified pill**.
- **Gaps closed this pass:** `/marketplace` now projects live provider readiness (L4/L5);
  `/apps` now carries an honest `demo` SpecModeBadge.
- **Honest remaining limits:** `/games`, `/media`, `/docs-output` are preview/spec/demo
  surfaces. Their generators and the binary artifact store are **intentionally blocked by
  the project plan** (Phase 6: `binary_asset_upload_blocked`, `external_asset_fetch_blocked`,
  `cloud_save_sync_blocked`, `multiplayer_netcode_blocked`). They are honestly labelled and
  will project live L4/L5/L6 data only when those gates are opened — wiring them now would
  violate the no-fake-live rule.

No secret/token value is read or surfaced; production deploy / provider writes / pushes stay
OPA-gate-closed. Live proof is on the local docker-compose runtime (LLM `deterministic_dry_run`).
