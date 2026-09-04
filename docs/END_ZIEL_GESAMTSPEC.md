# END_ZIEL_GESAMTSPEC — Cloud Superbrain Developer Platform
Stand: 2026-07-11
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
Jetzt (HOSTED): produktiver Einstieg mit ehrlicher Client-/Live-Kennzeichnung, Navigation zu den Arbeitsflächen und sichtbarer Runtime-Projektion; der Hosted-Klickbeweis ist grün.

### Seite 2 — /login (Onboarding)
End-Ziel: GitHub/Google/Email/Guest, Refresh/Logout, Session.
Jetzt (HOSTED): kontrollierter Session-Lifecycle mit Gastzugang und Frontend-Session-Contract; Live-OAuth bleibt sichtbar gegated und wurde nicht aktiviert.

### Seite 3 — /workbench (Kommandozentrale)
End-Ziel: Editor (Monaco-artig), Prompt-Composer → Orchestrator, Explorer, Preview-Tabs, Terminal, Agent-Assistance, Mini-Cortex.
Jetzt (HOSTED): Workbench-Studio, Dateiansicht, Lauf-/Ergebnisflächen und Persistenz sind verdrahtet; der Beweis umfasst einen echten Workers-AI-Mini-Build mit gespeichertem Artefakt. Nicht freigegebene Provider-Schreibaktionen bleiben gegated.

### Seite 4 — /organism (Live)
End-Ziel: Live 3D Cortex, Hubs, Run-State, Inspector.
Jetzt (HOSTED): interaktive 3D-Ansicht mit redaktiertem Event-Feed, Inspector und dynamischem `source_kind`-Chip (`platform_audit`/`frontend_projection`); keine ungegatede Provider-Schreibaktion.

### Seite 5 — /organism/replay
End-Ziel: Timeline + Filter + Playback.
Jetzt (HOSTED): redaction-aware Replay-Timeline mit Run-Auswahl und Wiedergabesteuerung; der Klickpfad ist im Endproof belegt.

### Seite 6 — /organism/map
End-Ziel: Topologie-/Kartenansicht.
Jetzt (HOSTED): topology-gebundene Kartenansicht mit auswählbaren Knoten und Detailprojektion; Plattform-Mutationen bleiben ausgeschlossen.

### Seite 7 — /agents
End-Ziel: Start/Pause/Kill/Reset, Live-Status, Policies.
Jetzt (HOSTED): echte dreistufige Multi-Agent-Research-Pipeline über Workers AI sowie Status-/Ergebnisdarstellung; riskante Steuer- und Provider-Aktionen bleiben policy-gated.

### Seite 8 — /files
End-Ziel: Knowledge Bases, Vectors, Graph, Inspector, Search.
Jetzt (HOSTED): Memory-Seed/Search-Roundtrip, Trefferansicht und Metrikprojektion sind verdrahtet und im Hosted-Proof belegt.

### Seite 9 — /files/local
End-Ziel: Lokaler read-only File Browser (DEV-ONLY).
Jetzt (DEV-ONLY): kontrollierter read-only Dateibrowser mit explizitem Contract und Auswahlpfad; keine freien Host-FS-Zugriffe.

### Seite 10 — /tools
End-Ziel: MCP Tools, Scopes, read-only Execute, Provider Status.
Jetzt (HOSTED): read-only Tool-Ausführung mit strukturiertem Resultat, Audit-ID und sichtbarer Provider-Readiness ist verdrahtet; Schreib-Scope bleibt gesperrt.

### Seite 11 — /marketplace
End-Ziel: Browse, Details, Install (dry-run) für Skills/Agents/MCP/Models.
Jetzt (HOSTED): typisierte Karten mit Icons/Badges, Detailansicht und strukturiertem Installationsplan sind verdrahtet; `provider_writes=false` ist im Klickbeweis bestätigt.

### Seite 12 — /observe
End-Ziel: Monitoring (Grafana/Langfuse/OTel), Health, Runs, Traces.
Jetzt (HOSTED + DEV-RUNTIME): ehrliche Health-/Run-/Trace-Projektionen und Verifier-Artefakte; fehlende Live-Messungen werden nicht als gesund erfunden. Grafana Cloud bleibt extern gegated.

### Seite 13 — /games
End-Ziel: Templates, Scene Preview, „In Workbench öffnen“.
Jetzt (HOSTED): Templates, Build-Aktion und persistierte Spielebibliothek sind verbunden; 13 kuratierte Karten aus dem Store sowie der Öffnen-Pfad sind live belegt.

### Seite 14 — /apps
End-Ziel: App-Projekte analog Games.
Jetzt (HOSTED): kuratierte App-Templates, Artifact-Pipeline, deduplizierte Ergebnisdarstellung und Öffnen-Pfad sind verdrahtet.

### Seite 15 — /media
End-Ziel: Media Pipeline (Bild/Video/Audio) + Library.
Jetzt (HOSTED): Musik-/Video-Studio und store-backed Medienbibliothek sind getrennt von Dokumenten; ein erzeugtes Artefakt erscheint nach dem Persistenz-Roundtrip in der Galerie. Keine Fake-Mediengenerierung.

### Seite 16 — /docs-output
End-Ziel: Markdown/Dokument Output + Exporte.
Jetzt (HOSTED): Dokumenteditor, echte Session-/Dokument-Outputs aus dem Store und Download-Pfad sind verbunden; der Store-Roundtrip ist belegt.

### Seite 17 — /evidence
End-Ziel: Verifier-Ergebnisse, Claim Guards, Evidence Artefacts.
Jetzt (HOSTED): navigierbare Evidence-/Verifier-Surface mit Claim- und Artefaktprojektion; der Endproof öffnet die sichtbaren Nachweise.

### Seite 18 — /diagnostics
End-Ziel: Recovery, Archive, Rohdaten.
Jetzt (HOSTED): Recovery-/Archiv- und Verifier-Listing mit funktionalem Öffnen-Pfad zur Evidence-Surface.

### Seite 19 — /design-system
End-Ziel: Tokens/Komponenten/Typografie, responsive rules.
Jetzt (HOSTED): responsive Token-, Typografie- und Komponentenreferenz; Beispiele sind bewusst nicht als tote Aktionen gestaltet.

### Seite 20 — /technology
End-Ziel: 7 Layer x Provider Matrix, Runtime-Tech.
Jetzt (HOSTED): 7-Layer-/Provider-Matrix und Runtime-Technologie sind als ehrliche read-only Architekturansicht verfügbar; keine Cloud-Mutation.

### Seite 21 — /settings
End-Ziel: Profil, Policies, Gates, Rollen; Owner Activation.
Jetzt (HOSTED): Sicherheits-Gate-Matrix, Rollen- und Policy-Plan sind sichtbar; Owner-Aktivierung bleibt bewusst ohne Apply-Aktion.

### Seite 22 — /open-source
End-Ziel: OSS-first, Lizenzen, Danksagung, Komponentenliste.
Jetzt (HOSTED): navigierbare OSS-/Lizenz-/Komponentenübersicht als read-only Produktfläche.

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
