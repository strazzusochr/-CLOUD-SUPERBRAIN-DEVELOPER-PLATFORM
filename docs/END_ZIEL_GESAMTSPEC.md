# END_ZIEL_GESAMTSPEC — Cloud Superbrain Developer Platform
Stand: 2026-06-11
Status: Konsolidierte End-Ziel-Spezifikation + Index (ohne Cloud-/Owner-Mutation)

## 0) Binding Truth (Priorität)
Diese Datei ist eine konsolidierte Spezifikation und ein Index. Bindende Quellen bleiben:

- `PROJECT_STATE.md`
- `docs/project-progress.manifest.json`
- `docs/verification-register.md`
- `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md`
- `docs/system-architecture.md`
- `AI_HANDOFF.md`

Wenn diese Spec und eine der obigen Quellen widersprechen, gilt die obige Liste.

## 1) Gesamtvision + organisatorischer Zweck

### North Star
Cloud-native, prompt-gesteuerte Multi-Agent-Developer-Platform, die Projekte (inkl. 3D-Webgame-Pfad) erstellt, testet, verdrahtet und für Cloud-Deploy vorbereitet — evidenzbasiert, budget-guarded, ohne Fake-Done und ohne Secrets.

Kernformel (operative Leitplanken):
- Evidence-based only (Verifikation schlägt Behauptung).
- 7-Layer-Architektur (L1–L7) ist Pflicht.
- Localhost ist nur DEV-ONLY (Smoke/Verifier); Hosted/Prod Claims bleiben gated.
- Keine Secrets in Code/Logs/Antworten; Tokens nur via ENV.
- Gefahr-Gates bleiben Owner-only: `production_deploy`, `release_promotion`, `provider_write`, `main_push`, `registry_push`, `live_mcp_write`, `live_llm_call`, `secret_output`.

Siehe:
- `docs/CLOUD_SUPERBRAIN_ULTIMATUM_GPT55_PATCHED_2026-04-29.md` (North Star, harte Regeln)
- `docs/system-architecture.md` (7 Layer, Data Flow, Verbote)
- `PROJECT_STATE.md` (aktueller Stand + Non-Claims)

## 2) 7 Layer Architektur (aktuelle Provider, Hetzner/GitKraken retired)

Layer-Mapping (operative Zielarchitektur):
- L1 Frontend/Next.js → Vercel
- L2 Orchestrator/LangGraph → Fly.io
- L3 Agent Pool → Fly.io
- L4 LLM Gateway → Cloudflare Edge + Hugging Face Identity (dry-run bis Live-Gate)
- L5 MCP Gateway/Tools → GitHub Actions + GHCR + GitLab Identity (read-only/timeout/audit)
- L6 Memory → Fly.io (PostgreSQL + pgvector) + Redis Working Memory
- L7 Observability → Grafana Cloud + Langfuse + OpenTelemetry (gated)

Laufender DEV-ONLY Proof (lokal):
- `GET http://localhost:8081/api/v1/clouds/layers` liefert `cloud-layer-readiness-v1` und zeigt aktuelle Provider-IDs; Hetzner/GitKraken tauchen nicht mehr als required/default auf.

Siehe:
- `docs/system-architecture.md`
- `docs/runtime-contracts/cloud-provider-inventory-contract.md`
- `services/agent-api/app/main.py` (Cloud readiness / inventory endpoints)

## 3) 3D-Cortex / Organismus (End-Ziel)

Zweck:
- Live-Visualisierung der gesamten Plattform als „Organismus“: Knoten = Agents/Tools/DB/Gateways/Provider/Memory, Kanten = Datenfluss/Abhängigkeiten, Events = Puls/Glow.

End-Ziel-Bausteine (funktional oder klar gated):
- 3D View (R3F/three.js): Force-Directed / spring-like Layout, Event-Pulsing, Reduced-Motion, 2D-Fallback.
- Run-State Machine: `idle / planning / executing / verifying / blocked`.
- Brain-Mapping:
  - Prefrontal = Planning
  - Motor = CLI/Git/Cloud-Actions
  - Sensory = Files/Logs/Provider/MCP
  - Hippocampus = Memory
- Inspector: Region/Node Details, Replay Timeline, Status Legend.
- Datenquellen: `GET /api/v1/organism/events`, `GET /api/v1/organism/replay`, `GET /api/v1/organism/topology`, alle redaction-aware.

Aktueller Stand (DEV-ONLY, ohne Live-Provider / ohne Live-MCP-Write):
- Organism Contracts + Topology + Replay-Projektion existieren, inklusive `run_id` Binding.

Siehe:
- Frontend: `apps/frontend/components/organism/*`
- Contracts: `apps/frontend/app/api/v1/organism/*`
- Verifier: `scripts/verify-organism-topology.ps1`, `scripts/verify-organism-runtime-events.ps1`
- Hintergrund-Prompt/Design: `docs/7 layer 22 seiten Wörkbereich docs/CLOUD_SUPERBRAIN_LIVE_3D_ORGANISM_ULTIMATE_CODEX_PROMPT_2026-05-27 (2) (1).md`

## 4) Die 22 Seiten (End-Ziel-UX vs. Jetzt)

Regel für jedes UI-Element:
- ECHT verdrahtet (Klick → Request/State → sichtbares Result), oder
- sichtbar disabled mit Text („coming soon“ / „requires gate“ / „plan only“), oder
- reine Deko (nicht klickbar wirkend; kein Button/Role/Pointer).

Kanonische Registry: `apps/frontend/lib/nav.tsx` (`WORKSPACE_PAGES`, exakt 22).

### Seite 1 — /home (Landing)
End-Ziel: Hero + Einstieg Workbench + Live-Stats + „lebendes Gehirn“ (gated/DEV-ONLY).
Jetzt: read-only Surface; Navigation + Shell + Links.

### Seite 2 — /login (Onboarding)
End-Ziel: GitHub/Google/Email/Guest, Refresh/Logout, Session.
Jetzt: Contract-/Dry-run Lifecycle (kein live OAuth ohne Gate); UI bleibt kontrolliert.

### Seite 3 — /workbench (Kommandozentrale)
End-Ziel: Editor (Monaco-artig), Prompt-Composer → Orchestrator, Explorer, Preview-Tabs, Terminal, Agent-Assistance, Mini-Cortex.
Jetzt (DEV-ONLY): Action-to-Result „Run“ ist verdrahtet über `POST /api/v1/phase2/runtime/start` und erzeugt Artefakt; restliche Controls bleiben gated/spec-only aber nicht als tote Attrappen.

### Seite 4 — /organism (Live)
End-Ziel: Live 3D Cortex, Hubs, Run-State, Inspector.
Jetzt (DEV-ONLY): 3D Ansicht + redaktierte Events/Replays; kein Live-Provider Call.

### Seite 5 — /organism/replay
End-Ziel: Timeline + Filter + Playback.
Jetzt: Replay Surface (redaction-aware); keine Secrets.

### Seite 6 — /organism/map
End-Ziel: Topologie-/Kartenansicht.
Jetzt: Map Surface (read-only, topology-bound).

### Seite 7 — /agents
End-Ziel: Start/Pause/Kill/Reset, Live-Status, Policies.
Jetzt (DEV-ONLY): Start/Reset/Status sind als dry-run Steering verdrahtet (Live-Agent-Steering-Contract, ohne Live-Provider Calls).

### Seite 8 — /files
End-Ziel: Knowledge Bases, Vectors, Graph, Inspector, Search.
Jetzt (DEV-ONLY): Memory Search Panel verdrahtet (`GET /api/v1/memory/search`), plus Live-Metrics wenn erreichbar.

### Seite 9 — /files/local
End-Ziel: Lokaler read-only File Browser (DEV-ONLY).
Jetzt: read-only Surface + Contract; keine Host-FS Reads ohne expliziten Contract.

### Seite 10 — /tools
End-Ziel: MCP Tools, Scopes, read-only Execute, Provider Status.
Jetzt (DEV-ONLY): read-only Tool Execute ist verdrahtet (`POST /api/v1/tools/read-only/execute`), inklusive Audit-ID; Provider-Readiness ist sichtbar (read-only).

### Seite 11 — /marketplace
End-Ziel: Browse, Details, Install (dry-run) für Skills/Agents/MCP/Models.
Jetzt (DEV-ONLY): Install/Details sind als dry-run plan/artefakt verdrahtet (kein provider_write).

### Seite 12 — /observe
End-Ziel: Monitoring (Grafana/Langfuse/OTel), Health, Runs, Traces.
Jetzt: lokale Observability-Projektionen + Verifier/Artifacts surfaces; hosted bleibt gated.

### Seite 13 — /games
End-Ziel: Templates, Scene Preview, „In Workbench öffnen“.
Jetzt: Templates + Action Panel (dry-run Artifact Pipeline) + Live Task projection wenn Runtime erreichbar.

### Seite 14 — /apps
End-Ziel: App-Projekte analog Games.
Jetzt: analog Games (dry-run Artifact Pipeline + Live projection).

### Seite 15 — /media
End-Ziel: Media Pipeline (Bild/Video/Audio) + Library.
Jetzt: dry-run Artifact Pipeline + read-only surfaces; keine Fake Media-Generierung.

### Seite 16 — /docs-output
End-Ziel: Markdown/Dokument Output + Exporte.
Jetzt: Anzeige echter Session Outputs; Export ist plan-only (gated), aber nicht tot.

### Seite 17 — /evidence
End-Ziel: Verifier-Ergebnisse, Claim Guards, Evidence Artefacts.
Jetzt: Evidence-/Verifier-Surface (read-only).

### Seite 18 — /diagnostics
End-Ziel: Recovery, Archive, Rohdaten.
Jetzt: Archive/Verifier Listing; „Öffnen“ führt zur Evidence Surface.

### Seite 19 — /design-system
End-Ziel: Tokens/Komponenten/Typografie, responsive rules.
Jetzt: Showcase (non-interactive samples; keine toten Buttons).

### Seite 20 — /technology
End-Ziel: 7 Layer x Provider Matrix, Runtime-Tech.
Jetzt: Architektur-/Stack Surface (read-only, keine Cloud Mutation).

### Seite 21 — /settings
End-Ziel: Profil, Policies, Gates, Rollen; Owner Activation.
Jetzt: PlanOnly Gate-Plan + keine Apply-Aktion.

### Seite 22 — /open-source
End-Ziel: OSS-first, Lizenzen, Danksagung, Komponentenliste.
Jetzt: read-only Surface.

## 5) „Jetzt“ vs. „Nächste Erweiterung“

Jetzt (Phase 1–2, DEV-ONLY belegt):
- 22 Seiten existieren, sind verdrahtet oder klar gated.
- Action-to-Result Proofs (WorkBench Run, Agent Steering, Tools Read-only, Files Search, Marketplace Install) sind testbar.
- External Gates bleiben blocked (Hosted URL / Tokens).

Nächste Erweiterung (gated / Owner erforderlich):
- Hosted Staging Proof über echte `STAGING_BASE_URL` (Vercel) + erreichbare Fly Origins.
- Branch Protection live verifizieren (GitHub Token).
- Fly live budget read (Fly token) + Provider inventory read (Cloudflare/HF/GitLab/Grafana tokens).
- Live LLM Calls erst nach Budget-Guard + Owner Gate.

Siehe:
- `PROJECT_STATE.md` (Next concrete step)
- `docs/runbooks/cloud-gate-owner-activation-2026-06-09.md`
- `docs/external-gates-setup.md`

## 6) Doku-/Prompt-/Plan-Inventar (Index)

Prompts:
- `docs/codex-integration/CODEX_LOADER_PROMPT.txt`
- `docs/7 layer 22 seiten Wörkbereich docs/CLOUD_SUPERBRAIN_LIVE_3D_ORGANISM_ULTIMATE_CODEX_PROMPT_2026-05-27 (2) (1).md`

Kern-/Wahrheitsdokumente:
- `PROJECT_STATE.md`, `PROJECT_STATUS.md`, `PROJECT_ANCHOR.md`, `AI_HANDOFF.md`, `AGENTS.md`
- `docs/project-progress.manifest.json`, `docs/verification-register.md`
- `docs/system-architecture.md`, `docs/repository-identity.md`, `docs/architecture-map.md`

Planung/Phasen:
- `docs/PHASE_0_EXECUTION_PLAN.md`, `docs/PHASE_1_FOUNDATION_PACKAGE.md`, `docs/PHASE_2_IMPLEMENTATION_PLAN.md`
- `docs/phase-2-readiness-matrix.md`, `docs/phase-transition-gate.json`

Contracts:
- `docs/runtime-contracts/*`
- `docs/interface-contract-register.md`
- `docs/layer-l1-data-storage.md` ... `docs/layer-l7-verification.md`

Audit/Analyse/Runbooks:
- `docs/audit/*`
- `docs/analysis/*`
- `docs/runbooks/*`
- `.codex/runs/CURRENT/*` (Audits, Feature-Matrix, Screenshots, Traces)

Release-Artefakte (historische Candidate-Proofs; hosted Grenzen beachten):
- `docs/release-artifacts/*`

## 7) 11.06.2025 Planungsstand
Im Repository existieren keine Treffer auf `2025-06-11` / `11.06.2025`. Falls ein externer „Planungsstand 11.06.2025“ existiert, muss er separat ins Repo eingebracht werden; bis dahin ist eine 1:1-Ausrichtung darauf blockiert.

