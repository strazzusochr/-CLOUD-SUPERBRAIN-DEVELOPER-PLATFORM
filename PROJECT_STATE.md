# CLOUD SUPERBRAIN — AKTUELLER PROJEKTSTAND (Auto-Loaded by Codex)

Letzte Aktualisierung: 2026-07-13
══════════════════════════════════════════════════════════════════

## AKTUELLER PROJEKTANKER

- **Anchor ID:** `project-anchor-2026-04-30T00-49-26+02-00`
- **Anchor-Datei:** `PROJECT_ANCHOR.md`
- **Checkpoint:** `docs/project-checkpoint-2026-04-30.json`
- **Live-Snapshot:** `2026-04-30 00:49:26 +02:00`
- **Kernstand:** Localhost `8081` bleibt ausschliesslich `DEV-ONLY` Control-Plane; Gesamtfortschritt laut bindendem Manifest `84%`; Phase 1 Foundation Runtime ist manifestseitig `100%`; Project Progress Integrity `verified`. Die 22 kanonischen Seiten und sieben Schichten sind verdrahtet. Frontend steht bei `99%`, Orchestrator / LangGraph bei `100%`, Phase 3 bei `43%`, Phase 5 nach dem lokalen archivbasierten Production-Candidate-Beweis bei `68%` und Phase 6 bei `90%`. External Gates bleiben laut `.phase1-artifacts/external-gate-audit-20260713-083839.json` auf `hosted_agent_api_contracts` und `vercel_backend_origin_health` `blocked`; Production ist nicht ausgerollt.
- Hetzner, GitKraken und Oracle sind aus dem aktiven Pfad entfernt oder als historische Altlast markiert.
- **Master Goal External-Gate-Spiegel (CURRENT READ-ONLY RUN BLOCKED):** `.phase1-artifacts/external-gate-audit-20260713-083839.json` meldet `status=blocked` auf `hosted_agent_api_contracts` und `vercel_backend_origin_health`; aktuelle verify-only Branch-Protection- und Fly-Budget-Checks sind gruen, `production_deploy_claim_allowed=false`. Kein Audit enthaelt Tokenwerte; Production wurde nicht ausgerollt und der Manifest-Fortschritt steht bei `84%`.
- **Aktueller gehosteter Phase-6-Basisbeweis:** `scripts/verify-phase6-frontend.mjs` bestand lokal und gegen `https://frontend-seven-psi-78.vercel.app` mit 7/7 Slice-Markern, sichtbarem nichtleerem WebGL-Canvas, Kamera-/Tastatursteuerung, Frame-Budget-HUD, Reduced-Motion-zu-2D-Umschaltung, zwei PNG-Beweisen und null Console-Fehlern. Evidence liegt unter `.codex/runs/CURRENT/phase6/frontend-local` und `.codex/runs/CURRENT/phase6/frontend-hosted`; diese Basis kreditiert die ersten vier Rubrikbloecke bis `32%`.
- **Aktueller lokaler Phase-6-Kamera-/Licht-Beweis:** `phase6-3d-camera-lighting-runtime-v1` bindet drei angewendete Kamera-Presets, FOV 38/45/58, Studio/Nacht/Morgen-Lichtprofile, Exposure 0.72..1.18, Reset und Runtime-State-Overlay. Der Chromium-Beweis klickt alle Zustandsklassen, prueft echte Three.js-Datenattribute, beide Exposure-Grenzen, ein nichtleeres PNG, keine XHR/fetch-Aufrufe waehrend der Steuerung und null Console-Fehler. Evidence: `.codex/runs/CURRENT/phase6/camera-lighting-local`. Dies erhoeht Phase 6 von `32%` auf `40%` und Overall auf `76%`. DEV-ONLY; kein Shader-Hotload, Asset-Fetch, Provider-Write, Deploy oder Production-Claim.
- **Aktueller lokaler Phase-6-Gameplay-State-Beweis:** `phase6-3d-gameplay-state-runtime-v1` bindet `collect -> checkpoint -> survive -> collect`, Score-Schritte, Checkpoint-Zaehler, Completion-/Input-Zaehler, einen pausensicheren Sekundentakt, Button-/`G`-Paritaet, Reset und angewendete Three.js-Datenattribute. Der Chromium-Beweis klickt und tippt den ganzen Zyklus, friert den Tick waehrend Pause ein, prueft Resume und stabilen Reset, ein nichtleeres PNG, keine XHR/fetch-Aufrufe und null Console-Fehler. Evidence: `.codex/runs/CURRENT/phase6/gameplay-state-local`. Dies erhoeht Phase 6 von `40%` auf `48%` und Overall auf `77%`. DEV-ONLY; kein Multiplayer, Server-Sync, Physics-Engine, Provider-Write, Deploy oder Production-Claim.
- **Aktueller lokaler Phase-6-Asset-Policy-Beweis:** `phase6-3d-asset-policy-runtime-v1` bindet drei allowlist-basierte prozedurale Three.js-Primitive (`cube`, `beacon`, `ring`), drei lokale Materialvarianten, Reset, sichtbares Manifest und angewendete Runtime-Datenattribute. Der Chromium-Beweis schaltet alle Profile und Materialien, prueft den Reset, ein nichtleeres PNG, null XHR/fetch und null Console-Fehler. Evidence: `.codex/runs/CURRENT/phase6/asset-policy-local`. Dies erhoeht Phase 6 von `48%` auf `56%` und Overall auf `78%`. DEV-ONLY; kein externer Asset-Fetch, Upload, CDN, Asset-Pipeline-Service, Provider-Write, Deploy oder Production-Claim.
- **Aktueller lokaler Phase-6-Save/Load-Beweis:** `phase6-3d-save-load-runtime-v1` erfasst exakt 15 allowlist-basierte Kamera-, Licht-, Gameplay- und Asset-Felder in einem fluechtigen React-State-Slot. Der Chromium-Beweis prueft Load-disabled, Save, Zustandsmutation, vollstaendigen Restore in UI und Three.js, Clear, Reload-Verlust, ein nichtleeres PNG, null XHR/fetch und null Console-Fehler. Evidence: `.codex/runs/CURRENT/phase6/save-load-local`. Dies erhoeht Phase 6 von `56%` auf `64%` und Overall auf `80%`. DEV-ONLY; kein LocalStorage, IndexedDB, Cookie, Cache, Cloud-Sync, Upload, Server-Write, Deploy oder Production-Claim.
- **Aktueller lokaler Phase-6-Netcode-Loopback-Beweis:** `phase6-3d-netcode-loopback-runtime-v1` bindet eine fluechtige Zwei-Peer-Session, Host-/Guest-Ready-Barriere, manuelle deterministische Lockstep-Ticks, monotone Paketfolge, sofortiges Disconnect-Fail-Closed und einen prozeduralen Three.js-Guest-Marker. Der Chromium-Beweis prueft Create, Join, Ready, Start, zwei Ticks (`ticks=2`, `packets=5`, `sequence=5`), Disconnect, Close, ein nichtleeres PNG, null Fetch/XHR/WebSocket und null Console-Fehler. Evidence: `.codex/runs/CURRENT/phase6/netcode-local`. Dies erhoeht Phase 6 von `72%` auf `80%` und Overall auf `82%`. DEV-ONLY; kein Remote-Transport, WebSocket, WebRTC, Matchmaking, Public Lobby, Server-Sync, Deploy oder Production-Claim.
- **Aktueller lokaler Phase-6-Scoreboard-/Performance-Beweis:** `phase6-local-scoreboard-performance-runtime-v1` bindet ein fluechtiges Top-3 aus echten Gameplay-Snapshots und eine gebundene 12-Sample-Klassifikation der vorhandenen Renderer-Statistik. Chromium belegte `L003,L004,L002`, Reset und Reload-Verlust, zwoelf positive Samples, neu berechnete Mittelwerte, 1024 sichtbare Pixelproben, 118 Farbbuckets sowie null Netzwerk-, Storage-, IndexedDB-, Cache-, Service-Worker-, Beacon-, WebSocket-, WebRTC-, Cookie- und Console-Zugriffe. Der beobachtete DEV-Container-Wert klassifizierte ehrlich `fail` (`3.4 FPS`, `298.6 ms` abgeleitetes Frame-Intervall); dies ist kein GPU-Benchmark oder Performance-Erfolgsclaim. Evidence: `.codex/runs/CURRENT/phase6/scoreboard-performance-local`. Dies erhoeht Phase 6 von `80%` auf `90%` und Overall von `82%` auf `84%`; Frontend bleibt `99%`. DEV-ONLY; kein Sync, persistenter Speicher, Telemetry-, Scale-, Capacity-, Deploy- oder Production-Claim.
- **Aktueller lokaler Orchestrator-Completion-Beweis:** `orchestrator-completion-evidence-v1` bindet drei frische LangGraph-Runs: einen vollstaendigen Planner/Coder/Tester/DevOps-Erfolg mit Aggregation und dry-run LLM-Streaming, einen Policy-Hard-Stop fuer `production deploy` plus `merge main` ohne Task-/MCP-Ausfuehrung und einen kontrollierten Tester-MCP-Timeout als terminale Partial-Failure. PostgreSQL-Checkpoints und korrelierte Audit-Events wurden fuer die Runs gelesen; Chromium lud den Read-only-Contract durch einen echten Klick in `/diagnostics`. Evidence: `.codex/runs/CURRENT/orchestrator/completion-local`, Screenshot 164195 Bytes. Dies erhoeht Orchestrator / LangGraph von `99%` auf `100%`; Overall und horizontale Phasen bleiben unveraendert. DEV-ONLY; keine Live-Provider-Calls, Live-MCP-Writes, Provider-Writes, Secrets oder Production-Aktion.
- **Aktueller lokaler Phase-5-Production-Candidate-Beweis:** `phase5-production-candidate-local-v1` baut Frontend, Agent API, Agent Worker, Memory Worker, MCP Gateway und LLM Gateway ausschliesslich aus dem Git-Archiv von `c451fa8ff2b631685ad07ebcfcf4dc4a5b418e81`. Der Beweis validiert sechs lokale Image-IDs, OCI-Revisionen, eingebettete Source-Hashes, den Next.js `BUILD_ID`, read-only API-Methoden und einen echten Diagnostics-Chromium-Klick. Evidence: `.codex/runs/CURRENT/master-goal/phase5/production-candidate-local`; Screenshot 158598 Bytes. Dies erhoeht Phase 5 von `67%` auf `68%`; Overall bleibt `84%`. DEV-ONLY; GHCR-Tags sind geplant und unveroeffentlicht, Hosted-Paritaet, Owner-Freigabe, Deploy und Promotion bleiben false.
- **Aktueller lokaler Phase-3-CSP-Beweis:** `csp-report-contract-v1` exponiert den same-origin Sink `POST /api/v1/security/csp/report` mit 16-KB-Grenze, Content-Type-Guard, allowlist-basierter Redaktion, Query-/Fragment-Entfernung und fail-closed Audit-Persistenz. `scripts/verify-phase3-csp-report-contract.ps1` bestand inklusive 413/415/422-Negativpfaden; `apps/frontend/e2e/phase3-csp-report.spec.ts` klickte auf `/diagnostics` den CSP-Vertrag und belegte sichtbar HTTP `200`. Screenshot: `.codex/runs/CURRENT/phase3/csp-report-contract/diagnostics-csp-report-contract.png`. Dies erhoeht Phase 3 auf `41%`. DEV-ONLY; kein Hosted-, Provider-, MCP-, Deploy- oder Production-Claim.
- **Aktueller lokaler Phase-3-CSRF-Beweis:** `csrf-origin-guard-v1` schützt unsichere `/api/`-Methoden mit Fetch Metadata und exaktem Origin-Abgleich. Ein echter Chromium-POST gleicher Herkunft liefert `200`; Cross-Site, Origin-Mismatch und `Origin: null` liefern jeweils `403`, werden redigiert auditiert und persistieren weder Raw-Origin noch Credentials. Evidence: `.codex/runs/CURRENT/phase3/csrf-origin-guard`. Dies erhoeht Phase 3 von `41%` auf `42%`; Overall bleibt gerundet `82%`. DEV-ONLY; kein Hosted-OAuth-, Provider-, Deploy- oder Production-Claim.
- **Aktueller lokaler 22x2-Responsive-Beweis:** `npm run verify:responsive` navigiert per echter Command-Palette durch alle 22 kanonischen Routen bei Desktop `1440x960` und Mobile `390x844`. Der Nachweis umfasst 44 Routenklicks, vier PNGs, `overflow_failures=0`, `console_errors=0`, eine mobile Command-Palette, einspaltige Organismus-/Datei-Grids, begrenzte Tabellen und aspect-ratio-sensitives 3D-Framing. Evidence: `.codex/runs/CURRENT/frontend/responsive-22/report.json`. Dies erhoeht Frontend von `97%` auf `99%`; Overall bleibt `82%`. DEV-ONLY; kein Hosted-, Deploy-, Release- oder Production-Claim.
- **Aktueller lokaler Cross-Origin-Response-Beweis:** `cross-origin-response-guard-v1` erzwingt `Cross-Origin-Opener-Policy: same-origin`, `Cross-Origin-Resource-Policy: same-origin` und `X-Permitted-Cross-Domain-Policies: none` auch auf Fehlerantworten. Ein untrusted `Origin` wird nicht als CORS-Freigabe reflektiert; Diagnostics lädt den Vertrag per echtem Chromium-Klick. Evidence: `.codex/runs/CURRENT/phase3/cross-origin-response-guard`. Dies erhoeht Phase 3 von `42%` auf `43%`; Overall bleibt `82%`. DEV-ONLY; kein Provider-, MCP-, State-, Deploy- oder Production-Write.
- **Aktueller lokaler Zusatzbeweis:** `workspace-data-sources-v1` ist jetzt als Guard in `scripts/verify-workspace-data-sources.ps1`, `scripts/verify-browser-contract.ps1` und `scripts/verify-phase1.ps1` eingebunden. Die falschen Singular-Refs `/api/v1/model-capabilities` wurden in Frontend-Wiring und Agent-API-Mirror auf `/api/v1/models/capabilities` korrigiert. `GET /api/v1/files/local/contract` existiert jetzt als read-only Agent-API-Contract ohne Host-Filesystem-Mount, ohne Live-Filesystem-Reads, ohne Writes und ohne Secret Output. DEV-ONLY Runtime-Proof: `api_refs=32`, Browser-Contract gruen.
- **Aktueller lokaler Boundary-Beweis:** `scripts/verify-platform-ui-status-boundary.ps1` trennt Produkt-/Workbench-Flächen von Projektstatus-/Gate-/Manifest-Oberflächen. Home, Workbench, Games, Apps, Media, Docs-Output und AppShell duerfen keine `fetchProgress`, `fetchMasterPlan`, `fetchCompletionGate`, `MANIFEST`, `/api/v1/project/progress`, `overall_percent`, `Project Progress`, `Projektstand`, `Completion-Gate`, `Workspace-Surfaces`, `Gate-Matrix`, `Recovery-Historie` oder Go-Live-/External-Gate-Audit-Marker rendern/importieren. Runtime-Proof: `product_surfaces=7`, `routes=6`, Browser-Contract gruen.
- **Aktueller lokaler LLM-Beweis:** `GET /llm/api/v1/responses/contract` liefert jetzt `llm-responses-adapter-contract-v1` mit `llm_responses_adapter_contract_visible`. `POST /llm/v1/responses` gibt Responses-kompatibel `output`, `output_text`, `trace_id`, `live_provider_calls=false`, `model_downloads=false` und `audit_persisted=true` zurueck; `stream=true` fail-closed mit HTTP `501`, nicht-strukturierte `metadata` mit HTTP `422`. `scripts/verify-llm-responses-contract.ps1` ist in `npm run verify:browser` und `scripts/verify-phase1.ps1` eingebunden. DEV-ONLY; kein Live-Provider-Call, kein lokaler Model-Download, kein Hosted-Proof, keine Prozentsteigerung.
- **Aktueller lokaler Live-Agent-Beweis:** `GET /api/v1/live-agents/contract`, `POST /api/v1/live-agents/steer`, `POST /api/steer-agent`, `GET /api/v1/live-agents/status` und `POST /api/v1/live-agents/{agent_id}/reset` sind jetzt ueber `live-agent-steering-v1` abgesichert. Steering-Antworten spiegeln `trace_id`, `llm_gateway_contract_version=llm-responses-adapter-contract-v1`, `live_provider_calls=false`, `model_downloads=false`, `audit_persisted=true` und `secret_output=false`. `scripts/verify-live-agent-steering-contract.ps1` prueft Runtime, Session-State, Kompatibilitaetsroute, Audit-Trace, `unknown agent -> 404` und `empty message -> 422`; der Guard ist in Browser-Contract und Phase1 eingebunden. DEV-ONLY; kein Live-Provider-Call, kein Hosted-Proof, keine Prozentsteigerung.

## PROJEKT-IDENTITÄT

- **Name:** -CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM
- **Ziel:** Cloud-native, multi-agent AI-Entwicklerplattform, 3D-Webgame-fähig, prompt-gesteuert
- **Repo-Pfade:**
  - Hauptprojekt: `<repo-root>`
  - Fresh Build: `<workspace-root>\cloud-superbrain-fresh`
- **Architektur-Wahrheit:** `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md`

## HARTE CONSTRAINTS (NIEMALS BRECHEN)

1. **Budget:** Max €20/Monat Infrastruktur (Vercel/Fly.io/GHCR/Grafana Cloud; keine retired-legacy-provider Active Defaults)
2. **Kein Localhost in Produktion:** Alles muss Cloud-fähig sein
3. **Orchestrierung:** LangGraph als Haupt-Orchestrator mit PostgreSQL-Checkpointer
4. **Open-Source-First:** LangGraph, LiteLLM, Langfuse, pgvector
5. **Kein Qdrant:** Nur pgvector in Phase 1-5
6. **Kein E2B-Sandbox:** Docker Desktop für lokale Tests
7. **7-Schichten-Architektur** laut Ultimatum Finale

## AKTUELLER FORTSCHRITT: 84%

### Horizontal (nach Priorität)

| Prio | Status |
|------|--------|
| P0   | 100%   |
| P1   | 100%   |
| P2   | 86%    |
| P3   | 43%    |
| P4   | 99%    |
| P5   | 68%    |
| P6   | 90%    |

### Vertikal (nach Modul)

| Modul         | Status |
|---------------|--------|
| Frontend      | 99%    |
| Orchestrator  | 100%   |
| Agent Pool    | 68%    |
| LLM Gateway   | 54%    |
| MCP Gateway   | 55%    |
| Memory        | 72%    |
| Observability | 99%    |

## LAUFENDE DOCKER-CONTAINER (cloud-superbrain-phase1-dev)

- nginx (healthy)
- agent-api (healthy)
- redis (healthy)
- frontend (healthy)
- mcp-gateway (healthy)
- llm-gateway (healthy)
- local-llm (healthy)
- agent-worker (healthy)
- memory-worker (healthy)
- postgres (healthy)

## NÄCHSTER KONKRETER ARBEITSSCHRITT

- **Naechsten evidence-basierten Nicht-Rollout-Slice fortsetzen** — Orchestrator / LangGraph ist lokal bei `100%`, Frontend bei `99%`, Phase 3 bei `43%`, Phase 5 bei `68%` und Phase 6 bei `90%`; der aktuelle Read-only-Audit `083839` bleibt auf Hosted Agent API und Vercel Backend Origins blockiert.
- Den naechsten candidate-spezifischen P5-Slice aus Hosted-Paritaet und Rollback-Proof erst nach erreichbaren HTTPS-Origins bearbeiten; `production_deploy_claim_allowed=true` waere weiterhin kein Deployment-Nachweis.
- Localhost bleibt nur `DEV-ONLY`; ein spaeterer Rollout braucht zusaetzlich Owner-Freigabe, aktuellen Commit-Scope, Hosted-Proof und Rollback-Evidence.

## ZULETZT ABGESCHLOSSEN

**Phase 5 Local Production Candidate Preparation** - `npm run build:phase5-candidate-local` baute sechs Produktionsziele ausschliesslich aus dem Git-Archiv von Commit `c451fa8ff2b631685ad07ebcfcf4dc4a5b418e81`. `npm run verify:phase5-candidate-local` revalidierte lokale Image-IDs, OCI-Labels, eingebettete Source-Hashes, Frontend-`BUILD_ID`, den read-only API-Vertrag und einen echten Diagnostics-Chromium-Klick (`1 passed`, PNG 158598 Bytes). Evidence: `.codex/runs/CURRENT/master-goal/phase5/production-candidate-local`. Fortschritt: Phase 5 `67% -> 68%`; Overall bleibt `84%`. DEV-ONLY; kein Registry-Push, keine Hosted-Paritaet, keine Owner-Freigabe, kein Deploy und keine Release-Promotion.

**Orchestrator / LangGraph Completion Evidence** - `npm run verify:orchestrator-completion` bestand gegen die neu gebauten DEV-Container. Der Gate fuehrte einen vierrolligen Erfolgsgraphen, einen Policy-Hard-Stop und einen kontrollierten MCP-Timeout frisch aus, korrelierte PostgreSQL-Checkpoints und Audits und bestand den echten Diagnostics-Chromium-Klick (`1 passed`, PNG 164195 Bytes). Der integrierte Abschluss bestand zusaetzlich `npm run verify`, `npm run verify:runtime`, `npm run verify:browser`, Frontend-Lint und einen isolierten Production-Build mit TypeScript plus 21/21 statischen Seiten. Der Browserlauf umfasste 22 Routen, zwei Viewports und 44 Klicks; ein timing-abhaengiger Scoreboard-Test wurde auf die erlaubten manuellen und terminalen Timeout-Pfade gehaertet. Evidence: `.codex/runs/CURRENT/orchestrator/completion-local/report.json`. Fortschritt: Orchestrator `99% -> 100%`; Overall bleibt `84%`, horizontale Phasen bleiben unveraendert. `verify:market-ready:static` endet weiterhin ehrlich mit `MARKET_READY: false`. DEV-ONLY; kein Hosted-, Live-Provider-, Live-MCP-Write-, Deploy-, Release- oder Production-Claim.

**Phase 6 Local Scoreboard And Performance Classification** - vier reale Gameplay-Snapshots wurden deterministisch auf Top 3 begrenzt; Reset und Reload-Verlust beweisen fluechtigen Zustand. Eine echte 12-Sample-Stichprobe klassifizierte den headless DEV-Container ehrlich als `fail` bei `3.4 FPS` und `298.6 ms` abgeleitetem Frame-Intervall. Der Beweis enthaelt rekalkulierte Mittelwerte, 1024 sichtbare Pixelproben, 118 Farbbuckets und ausschliesslich Nullwerte fuer Netzwerk-/Persistenz-Guards. Evidence: `.codex/runs/CURRENT/phase6/scoreboard-performance-local`. Fortschritt: Phase 6 `80% -> 90%`, Overall `82% -> 84%`; Frontend bleibt `99%`. DEV-ONLY; kein GPU-Benchmark-, Capacity-, Scale-, Sync-, Deploy- oder Production-Claim.

**Phase 3 Cross-Origin Response Guard** — COOP/CORP und die Cross-Domain-Policy werden auf Erfolg und Fehlerantworten erzwungen; ein fremder Origin wird nicht als CORS-Freigabe reflektiert. Der Diagnostics-Vertrag wird per echtem Chromium-Klick mit PNG/JSON belegt. Fortschritt: Phase 3 `42% -> 43%`, Overall bleibt `82%`. DEV-ONLY; kein Provider-, MCP-, State-, Deploy- oder Production-Write.

**Frontend 22x2 Responsive Click Proof** — alle 22 kanonischen Routen wurden bei `1440x960` und `390x844` durch echte Command-Palette-Klicks geoeffnet. Mobile Navigation, Organismus-Framing, Datei-Grids und Tabellen-Scrollgrenzen wurden dabei real repariert. Report: `.codex/runs/CURRENT/frontend/responsive-22/report.json`; 44 Klicks, Overflow 0, Console Errors 0, vier PNGs. Fortschritt: Frontend `97% -> 99%`, Overall bleibt `82%`. DEV-ONLY; Hosted-Proof bleibt separat blockiert.

**Phase 3 CSRF Origin Guard** — Fetch-Metadata- und Origin-basierte Browsergrenze, redigierter Reject-Audit, schreibfreier Probe-Endpunkt und echter Diagnostics-Klick sind verifiziert. `npm run verify`, `npm run verify:runtime`, `npm run verify:browser`, Frontend-Lint und der Produktionsbuild mit 21/21 statischen Seiten sind gruen; gitleaks meldet keinen Fund. Evidence: `.codex/runs/CURRENT/phase3/csrf-origin-guard`. Fortschritt: Phase 3 `41% -> 42%`, Overall bleibt `82%`. DEV-ONLY; kein Hosted-OAuth-, Provider-, Deploy- oder Production-Claim.

**Phase 6 3D Netcode Loopback Runtime** — eine deterministische Zwei-Peer-Browser-Session mit Ready-Barriere, manuellen Lockstep-Ticks, monotoner Paketfolge, Disconnect-Fail-Closed und Three.js-Guest-Marker ist verifiziert. Evidence: `.codex/runs/CURRENT/phase6/netcode-local`. `npm run verify`, `npm run verify:runtime`, `npm run verify:browser`, Frontend-Lint, Produktionsbuild mit 21/21 statischen Seiten, Manifest-Integritaet und gitleaks sind gruen; Lint meldet nur vier bereits bestehende Warnungen. Fortschritt: Phase 6 `72% -> 80%`, Overall `81% -> 82%`. DEV-ONLY; kein WebSocket, WebRTC, Matchmaking, Public Lobby, Server-Sync, Provider-, Deploy- oder Production-Claim.

**Phase 6 3D Accessibility Runtime** — manueller und systemseitiger Reduced-Motion-Modus, semantischer 2D-Fallback, zehn Fokusziele, Pfeil-/Home-/End-/Enter-Navigation, Szenenfokus und Live-Status sind browserlokal verifiziert. Evidence: `.codex/runs/CURRENT/phase6/accessibility-local`. Fortschritt: Phase 6 `64% -> 72%`, Overall `80% -> 81%`. DEV-ONLY; kein Speech-, Telemetry-, Persistenz-, Provider-, Deploy- oder Production-Claim.

**Phase 6 3D Save And Load Runtime** — der achte Phase-6-Rubrikblock ist als fluechtiger, browserlokaler Snapshot geschlossen:

- `services/agent-api/app/main.py` exponiert `GET /api/v1/phase6/3d-save-load/contract` als `phase6-3d-save-load-runtime-v1` mit acht fail-closed Szenarien und 15 allowlist-basierten Feldern.
- `OrganismView` setzt Save, Load, Clear, Disabled-State, Revision, sichtbaren Speicherstatus und vollstaendigen Restore der Kamera-, Licht-, Gameplay- und Asset-Zustaende um.
- `apps/frontend/e2e/organism.spec.ts` prueft leeren Load-Pfad, Save, Mutation, Restore in UI/Three.js, Clear, Reload-Verlust, ein nichtleeres Canvas sowie null control-triggered XHR/fetch und null Console-Fehler.
- `scripts/verify-phase6-3d-save-load-runtime.ps1` bindet Contract, Source, Manifest, Chromium und PNG zusammen; Static-, Runtime- und Browser-Verifier enthalten den Guard.
- Fortschritt: Phase 6 `56% -> 64%`, Overall `78% -> 80%`; vertikale Werte bleiben unveraendert. DEV-ONLY; kein persistenter Browser-Speicher, Cloud-Sync, Upload, Server-, Provider-, MCP-, Deploy-, Release- oder Production-Claim.

**Phase 6 3D Asset Policy Runtime** — der siebte Phase-6-Rubrikblock ist als prozedurale, browserlokale Allowlist geschlossen:

- `services/agent-api/app/main.py` exponiert `GET /api/v1/phase6/3d-asset-policy/contract` als `phase6-3d-asset-policy-runtime-v1` mit acht fail-closed Szenarien und allen Non-Claims.
- `OrganismView`, `CortexLive` und `CortexCanvas3D` setzen drei lokale Primitive, drei Materialvarianten, Reset, sichtbares Manifest und angewendete Runtime-Datenattribute um.
- `apps/frontend/e2e/organism.spec.ts` schaltet alle Profile und Materialien, prueft Reset, ein nichtleeres Canvas sowie null control-triggered XHR/fetch und null Console-Fehler.
- `scripts/verify-phase6-3d-asset-policy-runtime.ps1` bindet Contract, Source, Manifest, Chromium und PNG zusammen; Static-, Runtime- und Browser-Verifier enthalten den Guard.
- Fortschritt: Phase 6 `48% -> 56%`, Overall `77% -> 78%`; vertikale Werte bleiben unveraendert. DEV-ONLY; kein externer Asset-Fetch, Upload, CDN, Pipeline-Service, Provider-, MCP-, Deploy-, Release- oder Production-Claim.

**Phase 6 3D Gameplay State Runtime** — der sechste Phase-6-Rubrikblock ist als deterministische, browserlokale Zustandsmaschine geschlossen:

- `services/agent-api/app/main.py` exponiert `GET /api/v1/phase6/3d-gameplay-state/contract` als `phase6-3d-gameplay-state-runtime-v1` mit acht fail-closed Szenarien und allen Non-Claims.
- `OrganismView`, `CortexLive` und `CortexCanvas3D` setzen Objective-, Score-, Checkpoint-, Completion-, Input- und Tick-State, Pause/Resume/Reset, Button-/Tastatur-Paritaet, Runtime-Datenattribute und einen prozeduralen Ziel-Beacon um.
- `apps/frontend/e2e/organism.spec.ts` klickt und tippt alle drei Uebergaenge, prueft den eingefrorenen Tick waehrend Pause, Resume, stabilen Reset, ein nichtleeres Canvas sowie null control-triggered XHR/fetch und null Console-Fehler.
- `scripts/verify-phase6-3d-gameplay-state-runtime.ps1` bindet Contract, Source, Manifest, Chromium und PNG zusammen; Static-, Runtime- und Browser-Verifier enthalten den Guard.
- Fortschritt: Phase 6 `40% -> 48%`, Overall `76% -> 77%`; vertikale Werte bleiben unveraendert. DEV-ONLY; kein Multiplayer, Server-Sync, Physics-Engine, Asset-Fetch, Provider-, MCP-, Deploy-, Release- oder Production-Claim.

**Phase 6 3D Camera And Lighting Runtime** — die zuvor nur partielle Kamera-/A11y-Markierung wurde in einen echten, voll kreditierten Kamera-/Licht-Rubrikblock getrennt:

- `services/agent-api/app/main.py` exponiert `GET /api/v1/phase6/3d-camera-lighting/contract` als `phase6-3d-camera-lighting-runtime-v1` mit acht fail-closed Szenarien und allen Non-Claims.
- `OrganismView`, `CortexLive` und `CortexCanvas3D` setzen drei Kamera-Presets, sichere FOV-Schritte, drei gebundene Lichtprofile, Exposure 0.72..1.18, ACES-Tone-Mapping, Reset und angewendete Runtime-Datenattribute um.
- `apps/frontend/e2e/organism.spec.ts` klickt die Presets und Lichtprofile, waehlt FOV, erreicht beide Exposure-Grenzen, prueft den Reset sowie angewendete Kamera-/Rendererwerte und verifiziert null control-triggered XHR/fetch sowie null Console-Fehler.
- `scripts/verify-phase6-3d-camera-lighting-runtime.ps1` bindet Contract, Source, Manifest, Chromium und PNG zusammen; `scripts/verify-browser-contract.ps1`, `scripts/verify-phase1-runtime.ps1` und `scripts/verify-phase1.ps1` enthalten den Guard.
- Fortschritt: Phase 6 `32% -> 40%`, Overall `75% -> 76%`; vertikale Werte bleiben unveraendert. DEV-ONLY; kein Hosted-Staging-, Shader-Hotload-, Asset-Fetch-, Provider-, MCP-, Deploy-, Release- oder Production-Claim.

**Phase 3 CSP Report Audit Contract** — CSP-Verletzungsberichte sind jetzt same-origin, groessenbegrenzt, redigiert und erst nach Audit-Persistenz akzeptiert:

- `services/agent-api/app/main.py` exponiert `GET /api/v1/security/csp/contract` und `POST /api/v1/security/csp/report`, setzt `report-uri /api/v1/security/csp/report` und speichert ausschliesslich allowlist-basierte Felder.
- URI-Querystrings und Fragmente, User-Agent, Cookies/Credentials, unbekannte Felder und der Raw-Body werden nicht persistiert; Body > 16384 Byte, ungueltige Shapes und nicht erlaubte Content Types scheitern mit 413/422/415.
- `scripts/verify-phase3-csp-report-contract.ps1` prueft Contract, Header, echten lokalen Audit-Write, Redaktion, Fail-closed-Grenzen und Non-Claims; `scripts/verify-browser-contract.ps1` bindet den Guard ein.
- `apps/frontend/app/diagnostics/page.tsx` bietet den sichtbaren CSP-Vertrag im LiveConsole-Select; `apps/frontend/e2e/phase3-csp-report.spec.ts` belegt Auswahl, Klick, GET 200 und sichtbare Evidence-Felder in Chromium.
- Fortschritt: Phase 3 `40% -> 41%`; gerundetes Overall bleibt `75%`. Localhost bleibt `DEV-ONLY`; kein Hosted-Proof, keine Cloud-Mutation, kein Deploy, kein Production-Claim, kein Live-Provider-Call, kein Live-MCP-Write und keine Secret-Nutzung.

**Live Agent Steering Contract Guard** — der L3/L4 Live-Agent-Steering-Pfad ist jetzt explizit gegen den Responses-Adapter und Runtime-Session-State abgesichert:

- `services/agent-api/app/main.py` importiert den bestehenden `llm_gateway_url`-Helper, nutzt `httpx` explizit und gibt Steering-Antworten mit `trace_id`, `evidence_ref`, `llm_gateway_contract_version`, `llm_gateway_evidence_ref`, `live_provider_calls`, `model_downloads`, `audit_persisted` und `secret_output` aus.
- `scripts/verify-live-agent-steering-contract.ps1` prueft Source-Guards, Contract, LLM-Gateway-Contract, Reset, Steering, Redis-Session-State, Audit-Trace, ZIP-Kompatibilitaetsroute, `unknown agent -> 404` und `empty message -> 422`.
- `scripts/verify-browser-contract.ps1` ruft den Guard im Browserlauf auf; `scripts/verify-phase1.ps1` prueft Parser und Pflichtmarker statisch.
- `docs/runtime-contracts/live-agent-steering-contract.md` dokumentiert die Boundary und Non-Claims.
- Verifiziert mit `py -3 -m py_compile services\agent-api\app\main.py`, Docker DEV rebuild/restart, `scripts\verify-live-agent-steering-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `npm run verify:browser` und `scripts\verify-phase1.ps1` inklusive gitleaks ohne Leaks.
- Localhost bleibt `DEV-ONLY`; kein Hosted-Proof, keine Cloud-Mutation, kein Deploy, kein Production-Claim, kein Live-Provider-Call, kein Live-MCP-Write, keine Secret-Nutzung und keine Prozentsteigerung.

**LLM Responses Adapter Contract Guard** — der L3/L4 Responses-Pfad ist jetzt explizit vertraglich und per Runtime-Negativtest abgesichert:

- `services/llm-gateway/app/main.py` exponiert `GET /api/v1/responses/contract` als `llm-responses-adapter-contract-v1` und markiert `POST /v1/responses` mit `llm_responses_adapter_contract_visible`.
- `services/agent-api/app/main.py` verlinkt den Contract im Live-Agent-Steering-Vertrag ueber `GET /llm/api/v1/responses/contract` und verlangt die Responses-Felder `output_text`, `trace_id`, `live_provider_calls`, `model_downloads` und `audit_persisted`.
- `scripts/verify-llm-responses-contract.ps1` prueft Source-Guards, Contract, Live-Agent-Vertrag, dry-run Runtime-Call, Audit-Trace, `stream=true -> 501` und `metadata`-Shape `422`.
- `scripts/verify-browser-contract.ps1` ruft den Guard im Browserlauf auf; `scripts/verify-phase1.ps1` prueft Parser und Pflichtmarker statisch.
- Verifiziert mit `py -3 -m py_compile services\llm-gateway\app\main.py services\agent-api\app\main.py`, Docker DEV rebuild/restart, `scripts\verify-llm-responses-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `npm run verify:browser` und `scripts\verify-phase1.ps1`.
- Localhost bleibt `DEV-ONLY`; kein Hosted-Proof, keine Cloud-Mutation, kein Deploy, kein Production-Claim, kein Live-Provider-Call, kein Live-MCP-Write, keine Secret-Nutzung und keine Prozentsteigerung.

**Platform UI Status Boundary Guard** — Entwicklerplattform und Projektstatus bleiben getrennte, aber verdrahtete Flächen:

- `scripts/verify-platform-ui-status-boundary.ps1` prueft Home, Workbench, Games, Apps, Media, Docs-Output und `AppShell.tsx` statisch gegen direkte Projektstatus-/Gate-/Manifest-Fetches und sichtbare Statuswand-Marker.
- Der Guard erlaubt Projektstatus nur in den dafuer vorgesehenen Evidence-/Diagnostics-/Organism-/non-rendering Wiring-Kontexten; Produktflächen bleiben sauber und verweisen nur auf getrennte Nachweisflächen.
- `scripts/verify-browser-contract.ps1` ruft den Guard im Browserlauf auf; `scripts/verify-phase1.ps1` prueft Parser und verbotene Marker statisch.
- Verifiziert mit `scripts\verify-platform-ui-status-boundary.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` und `npm run verify:browser`.
- Localhost bleibt `DEV-ONLY`; kein Hosted-Proof, keine Cloud-Mutation, kein Deploy, kein Production-Claim, kein Live-Provider-Call, kein Live-MCP-Write, keine Secret-Nutzung und keine Prozentsteigerung.

**Workspace Data Source Integrity Guard** — die 22-Seiten-Datenquellen sind jetzt gegen reale Runtime-Contracts und Source-Routen abgesichert:

- `apps/frontend/lib/workspaceWiring.ts` und `services/agent-api/app/main.py` nutzen fuer Marketplace/Media jetzt die echte Route `GET /api/v1/models/capabilities`; der stale Ref `/api/v1/model-capabilities` ist verboten.
- `services/agent-api/app/main.py` stellt `GET /api/v1/files/local/contract` als `local-files-readonly-contract-v1` bereit: keine Host-Filesystem-Mounts, keine Live-Filesystem-Reads, keine Writes, keine Secret-Ausgabe.
- `scripts/verify-workspace-data-sources.ps1` prueft `workspace-surface-wiring-v1`, `workspace-vertical-stack-v1`, `organism-topology-v1`, Model-Capabilities, Local-Files-Contract, Source-Routen und 32 API-like Data-Source-Refs.
- `scripts/verify-browser-contract.ps1` ruft den Guard nach dem Vertical-Stack-Guard auf; `scripts/verify-phase1.ps1` prueft Parser, Pflichtmarker und verbietet die stale Singular-Route statisch.
- Verifiziert mit `py -3 -m py_compile services\agent-api\app\main.py`, `npm run lint --prefix apps/frontend`, `npm run build --prefix apps/frontend`, `docker compose -f docker-compose.dev.yml up -d --build frontend agent-api nginx`, `scripts\verify-workspace-data-sources.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` und `npm run verify:browser`.
- Localhost bleibt `DEV-ONLY`; kein Hosted-Proof, keine Cloud-Mutation, kein Deploy, kein Production-Claim, kein Live-Provider-Call, kein Live-MCP-Write, keine Secret-Nutzung und keine Prozentsteigerung.

**Organism Topology Integrity Guard** — die 3D-Organismus-Verdrahtung ist jetzt als harter Runtime- und Source-Guard abgesichert:

- `scripts/verify-organism-topology.ps1` prueft `GET /api/v1/organism/topology`, `GET /api/v1/organism/contract`, `GET /api/v1/workspace/wiring` und `GET /api/v1/workspace/vertical-stack` gegen konsistente Versionen, Node-Arten, Edge-Arten, 22 Workbench-Seiten und geschlossene Non-Claims.
- Der Guard beweist aktuell `151` Nodes und `308` Edges mit referenziell gueltigen Kanten fuer Brain-Regions, Architektur-Layer, Agenten, MCP-Tools, LLM-Modelle, Skills, Cloud-Provider, Safety-Gates, Workspace-Pages, Data-Sources und Verifier.
- `scripts/verify-browser-contract.ps1` ruft den Topology-Guard im Browser-Contract auf; `scripts/verify-phase1.ps1` prueft Parser, Frontend-Route, Organism-Contract-Route, Agent-API-Mirror und den `P4=99`-Manifest-Spiegel in `apps/frontend/lib/platform.ts`.
- `apps/frontend/lib/platform.ts` spiegelt Phase `P4` wieder mit `99%` und vermeidet damit einen falschen `100%`-Snapshot im Frontend-Diagnosevertrag.
- Verifiziert mit `scripts\verify-organism-topology.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `npm run verify:browser`, `py -3 scripts\verify_project_progress_manifest.py` und `git diff --check`.
- Localhost bleibt `DEV-ONLY`; kein Hosted-Proof, keine Cloud-Mutation, kein Deploy, kein Production-Claim, kein Live-Provider-Call, kein Live-MCP-Write, keine Secret-Nutzung und keine Prozentsteigerung.

**Workspace Vertical Stack Contract** — alle 22 Workbench-Seiten haben jetzt eine maschinenlesbare Vertikal-Verdrahtung ueber UI, API, Data, Verification, Deploy und Safety:

- `apps/frontend/lib/workspaceVerticalStack.ts` erzeugt `workspace-vertical-stack-v1` aus der kanonischen `workspace-surface-wiring-v1` Registry, mit `page_count=22`, `layers_required=7`, `workspace_vertical_stack_visible` und fail-closed Non-Claims.
- `GET /api/v1/workspace/vertical-stack` existiert im Frontend und ist im Agent API gespiegelt; der Organism Contract referenziert den neuen Stack-Endpoint.
- `scripts/verify-workspace-vertical-stack.ps1` prueft pro Seite Route/Component, API-Gateway-Bindung, Datenquelle, Verifier-Refs, Vercel/Fly/GHCR Deploy-Zuordnung, `hostedProofStatus=blocked_external_gates`, keine direkten Provider-Calls, keine Default-Writes, keine Secret-Ausgabe und keine Production-Claims.
- `scripts/verify-browser-contract.ps1` ruft den Runtime-Guard auf; `scripts/verify-phase1.ps1` enthaelt einen statischen Guard fuer Source, Route, Agent-API-Mirror und Verifier.
- `/files/local` nutzt fuer die read-only Suche jetzt ein statisches `role=searchbox` statt eines disabled Inputs, damit der 22-Seiten-Browserproof keine Hydration-Drift erzeugt.
- Verifiziert mit `npm run lint --prefix apps/frontend`, `npm run build --prefix apps/frontend`, `py -3 -m py_compile services\agent-api\app\main.py`, `docker compose -f docker-compose.dev.yml up -d --build frontend nginx`, `scripts\verify-workspace-vertical-stack.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts\verify-workspace-pages-browser.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` und `npm run verify:browser`.
- Localhost bleibt `DEV-ONLY`; kein Hosted-Proof, keine Cloud-Mutation, kein Deploy, kein Production-Claim, kein Live-Provider-Call, kein Live-MCP-Write, keine Secret-Nutzung und keine Prozentsteigerung.

**Workspace Pages Browser Proof** — alle 22 kanonischen Workbench-Seiten sind jetzt mit echtem DEV-ONLY Browser-/Screenshot-Nachweis an die 7-Layer-/Organismus-Verdrahtung gebunden:

- `scripts/verify-workspace-pages-browser.ps1` und `scripts/verify-workspace-pages-browser.cjs` lesen `GET /api/v1/workspace/wiring` und `GET /api/v1/design/reference-contract`, pruefen exakt 22 Seiten, eindeutige Routen/Nummern, Layer, Brain-Regions, Hubs, Datenquellen, Verifier-Refs, Eventarten und die Non-Claims `live=false`, `writes=false`, `secretOutput=false`.
- Der Proof oeffnet jede kanonische Route im Browser, prueft `.app-shell`, `.main`, `.topbar`, aktive Rail-Navigation, sichtbaren Text, Design-Tokens, maximalen Panel-Radius, ausgeblendete Retired Provider `Hetzner|GitKraken|Oracle`, ausgeblendete Projektstatus-/Gate-Matrix-Marker und ausgeblendetes `Metered Budget` auf dem unbezahlten Defaultpfad.
- Der Proof erzeugt `.phase1-artifacts/workspace-pages-browser-proof-latest.json` und 22 Screenshots unter `apps/frontend/e2e/__artifacts__/workspace-pages/`.
- `apps/frontend/components/shell/AppShell.tsx` markiert Parent-/Bottom-Rail-Routen stabil aktiv; `/files/local` aktiviert jetzt korrekt den Files-Bereich.
- `apps/frontend/app/files/local/page.tsx` und `apps/frontend/app/styles.css` vermeiden eine Hydration-Drift durch stabile Klassen fuer die lokale Read-only-Suche.
- `scripts/verify-browser-contract.ps1` ruft erst den Reference-Design-Proof und danach den langen 22-Seiten-Proof auf; temporare Windows-Verifier-Dateien werden retry-faehig entfernt.
- `scripts/verify-reference-design-browser.cjs` prueft jetzt echte HTTP-Statuscodes mit transientem 502/503/504-Retry und sichtbare Browsertexte inklusive CSS-transformiertem `RUN BINDING`.
- Verifiziert mit `npm run lint --prefix apps/frontend`, `npm run build --prefix apps/frontend`, Node-Syntaxchecks, PowerShell-Parsercheck, `scripts\verify-reference-design-browser.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts\verify-workspace-pages-browser.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` und `npm run verify:browser`.
- Localhost bleibt `DEV-ONLY`; kein Hosted-Proof, keine Pixel-Perfect-Completion-Behauptung, kein Cloud-Deploy, keine Cloud-Mutation, kein Production-Claim und keine Prozentsteigerung.

**Reference Design Browser Proof** — die 1:1-Blueprint-Richtung ist jetzt mit echtem DEV-ONLY Browser-/Screenshot-Nachweis an die Workbench und den 3D-Organismus gebunden:

- `scripts/verify-reference-design-browser.ps1` und `scripts/verify-reference-design-browser.cjs` pruefen `/workbench`, `/organism` und `GET /api/v1/design/reference-contract` mit Playwright.
- Der Proof erzeugt `apps/frontend/e2e/__artifacts__/reference-design-workbench.png`, `apps/frontend/e2e/__artifacts__/reference-design-organism.png` und `.phase1-artifacts/reference-design-browser-proof-latest.json`.
- Der Workbench-Proof prueft `Main Workbench`, Preview-Tabs fuer Game/App/Video/Docs, `Run Binding`, maximalen Panel-Radius, Design-Tokens und das Fehlen von Projektstatuswand-/Gate-Matrix-/Budget-Markern.
- Der Organismus-Proof prueft Canvas-Groesse, WebGL-Kontext, Runtime-Feed `agent_api_redacted`, Screenshot-Groesse und PNG-Pixelvarianz (`uniqueColorBuckets`, `visiblePixels`, `accentPixels`).
- `GET /api/v1/platform/verify` wurde im Agent API gespiegelt, weil nginx `/api/*` an den Agent API routet und die Shell-Pill sonst einen Frontend-only-404 erzeugte.
- `infrastructure/nginx/dev.conf` und `infrastructure/nginx/cloud.conf` leiten Frontend-WebSocket-Upgrades weiter, damit Browser-Hydration und Client-Fetches stabil bleiben.
- Verifiziert mit `py -3 -m py_compile services\agent-api\app\main.py`, `node --check scripts\verify-reference-design-browser.cjs`, PowerShell-Parserchecks, `docker compose -f docker-compose.dev.yml up -d --build agent-api nginx`, direktem `GET /api/v1/platform/verify`, `scripts\verify-reference-design-browser.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `npm run verify:browser` und `scripts\verify-phase1.ps1`.
- Localhost bleibt `DEV-ONLY`; kein Hosted-Proof, keine Pixel-Perfect-Completion-Behauptung, kein Cloud-Deploy, keine Cloud-Mutation, kein Production-Claim und keine Prozentsteigerung.

**Reference Design Contract** — die 22-Seiten-/Organismus-Referenz ist jetzt maschinenlesbar an echte Assets, Frontend und Agent API gebunden:

- `apps/frontend/lib/referenceDesign.ts` definiert `reference-design-conformance-v1` mit Designregeln, Reference-Asset-Inventar, 22 Seiten, Organism-Eventarten und Non-Claims.
- `GET /api/v1/design/reference-contract` existiert im Frontend und als Agent-API-Mirror in `services/agent-api/app/main.py`.
- `scripts/verify-reference-design-contract.ps1` prueft die vorhandenen `docs/reference` Assets, mindestens 4 Root-Bilder, 15 aktuelle Design-Screenshots, 1 Motion-Referenzvideo, Frontend-Route, Agent-API-Mirror und Browser-Contract-Anbindung.
- `scripts/verify-browser-contract.ps1` prueft den Runtime-Endpoint; `scripts/verify-phase1.ps1` ruft den statischen Guard auf.
- Verifiziert mit `py -3 -m py_compile services\agent-api\app\main.py`, `npm run lint --prefix apps/frontend`, `npm run build --prefix apps/frontend`, `docker compose -f docker-compose.dev.yml up -d --build frontend agent-api nginx`, `scripts\verify-reference-design-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` und `npm run verify:browser`.
- Localhost bleibt `DEV-ONLY`; kein Hosted-Proof, keine Pixel-Perfect-Completion-Behauptung, kein Cloud-Deploy, keine Cloud-Mutation, kein Production-Claim und keine Prozentsteigerung.

**Go-Live Runbook Guard** — `docs/SUPERBRAIN_GO_LIVE.md` ist jetzt owner-gated und read-only abgesichert:

- Das Runbook ueberschreibt die Projekt-AGENTS.md nicht und erlaubt daraus keine Cloud-Mutation, keinen Deploy, keinen Registry-Push, keine Live-Provider-Aktivierung, keinen MCP-Write und keinen Production-Claim.
- Es spiegelt die aktuelle External-Gate-Wahrheit: `.phase1-artifacts/external-gate-audit-20260611-011938.json`, `external-gate-summary-v1`, `GET /api/v1/clouds/go-live-readiness` und die vier offenen Gates.
- Es spiegelt die aktuelle Frontend-Version-Baseline aus `apps/frontend/package.json`, ohne Latest-Claim und ohne Upgrade-Behauptung.
- Neuer Guard: `scripts/verify-superbrain-go-live-runbook.ps1`; in `scripts/verify-phase1.ps1` eingebunden.
- Verifiziert mit `scripts\verify-superbrain-go-live-runbook.ps1`; Localhost bleibt `DEV-ONLY`; kein Cloud-Deploy, keine Cloud-Mutation, kein Hosted-Proof, kein Production-Claim und keine Prozentsteigerung.

**Go-Live Readiness Contract** — der aktuelle 100%-Go-Live-Pfad ist jetzt als read-only Runtime-Vertrag und Verifier abgesichert:

- `GET /api/v1/clouds/go-live-readiness` aggregiert Project Completion, External Gates, Cloud Layer Readiness, Deployment Preflight, 22-Seiten-Wiring und Owner-Activation-Plan zu einem einzigen Statusvertrag.
- `GET /api/v1/clouds/go-live-readiness/contract` beschreibt die Pflichtfelder, guarded endpoints und Verifier, ohne eine Workbench-Projektstatuswand zu rendern.
- `scripts/verify-go-live-readiness.ps1` prueft Runtime-Vertrag, Contract-Endpoint, Pflicht-Owner-Inputs, 22 Seiten, 7 Layer, PlanOnly-Owner-Aktivierung und das neueste External-Gate-Audit auf die vier real offenen Gates.
- `scripts/verify-browser-contract.ps1` ruft den neuen Verifier im laufenden DEV-/Hosted-Kontext auf; `scripts/verify-phase1.ps1` prueft ihn statisch auf Pflichtmarker und PowerShell-Parser.
- Verifiziert mit `py -3 -m py_compile services\agent-api\app\main.py`, PowerShell Parser-Checks, `docker compose -f docker-compose.dev.yml up -d --build agent-api nginx`, `scripts\verify-go-live-readiness.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `npm run verify:browser` und `scripts\verify-phase1.ps1`.
- Status bleibt `blocked_external_gates`; Localhost-Proofs bleiben `DEV-ONLY`; kein Cloud-Deploy, keine Cloud-Mutation, kein Hosted-Proof, kein Production-Claim und keine Prozentsteigerung.

**Workbench Budget Visibility Guard** — der Workbereich blendet Budget vollstaendig aus, solange keine paid/metered Option aktiv oder explizit verfuegbar ist:

- `apps/frontend/lib/paidCapabilities.ts` wertet rohe Provider-Key-Umgebungsvariablen wie OpenAI/Anthropic/Azure/E2B nicht mehr als Workbench-UI-Freigabe fuer Budget-Anzeigen.
- Budget wird weiterhin sichtbar, wenn eine paid/metered Auswahl gesetzt ist, z. B. `/workbench?billing=paid`, oder wenn explizite paid Capability Flags bzw. ein nicht lokaler LLM-Gateway-Modus konfiguriert sind.
- `apps/frontend/e2e/organism.spec.ts` beweist den UI-Vertrag: `/workbench` enthaelt weder `Metered Budget` noch `paid/metered Capability`, `/workbench?billing=paid` zeigt beides.
- Docker DEV Frontend/Nginx wurden neu gebaut; gezielter HTTP-Proof bestaetigte `defaultContainsMeteredBudget=false`, `defaultContainsPaidCapability=false`, `paidContainsMeteredBudget=true`, `paidContainsPaidCapability=true`.
- Verifiziert mit `npm run lint --prefix apps/frontend`, `npm run build --prefix apps/frontend`, kompletter Organism-E2E-Datei (`13 passed`), `docker compose -f docker-compose.dev.yml up -d --build frontend nginx`, `npm run verify:browser`, `py -3 scripts\verify_project_progress_manifest.py`, `git diff --check`, `scripts\verify-phase1.ps1` und `npm run verify:external-gates` (`.phase1-artifacts/external-gate-audit-20260611-011938.json`, blocked-ehrlich).
- Localhost-Proofs bleiben `DEV-ONLY`; kein Cloud-Deploy, keine Cloud-Mutation, kein Hosted-Proof, kein Production-Claim und keine Prozentsteigerung.

**Organism UI Runtime Run Binding** — die Organism-UI reicht `run_id` jetzt bis in beide Runtime-Projektionen durch:

- `apps/frontend/components/organism/OrganismView.tsx` liest einen validierten `run_id` aus der Browser-URL und ruft `GET /api/v1/organism/events?run_id=...` sowie `GET /api/v1/organism/replay?run_id=...` mit demselben Wert auf.
- Das Runtime-Panel zeigt den gebundenen `run_id` als `data-run-id` und sichtbaren `run_id=...` Marker, ohne raw `details`, `user_id`, `session_id`, Prompts oder Secret-Werte zu rendern.
- `apps/frontend/e2e/organism.spec.ts` beweist per Playwright-Request-Intercept, dass `/organism/replay?run_id=...` beide Runtime-API-Requests mit identischem `run_id` ausloest und weiterhin `agent_api_redacted`, `data-live=true`, Replay-Frames und Redaktionsmarker rendert.
- Verifiziert mit `npm run lint --prefix apps/frontend`, `npm run build --prefix apps/frontend`, fokussiertem `npx playwright test e2e/organism.spec.ts --project=chromium --grep "forwards run_id"`, kompletter Organism-E2E-Datei (`12 passed`), `scripts\verify-organism-runtime-events.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `npm run verify:browser`, `npm run verify:runtime`, `py -3 scripts\verify_project_progress_manifest.py` und `git diff --check`.
- `npm run verify` fand initial eine Handoff-Truth-String-Drift beim no-token External-Baseline-Satz; der Spiegel wurde repariert. Danach wurde ein gitleaks-Blocker in lokalen `.claude`-Secret-/Session-Kopien redigiert, `scripts/verify-external-gates.ps1` fuer den realen 4.19-GB-Scan auf `1200s` Default-Timeout gehoben und `scripts\verify-phase1.ps1` sowie `npm run verify:external-gates` erneut gruen/blockiert-ehrlich ausgefuehrt. Keine Cloud-Mutation, kein Hosted-Proof, kein Production-Claim und keine Prozentsteigerung.

**Organism Runtime Event Projection** — `/organism` ist fuer lokale Runtime-Runs nicht mehr nur Spec-Contract, sondern kann echte redaktierte Audit-Aktivitaet projizieren:

- `services/agent-api/app/main.py` mappt `audit_log.event_type` aus `phase2_runtime_graph_started`, Tool-, LLM-, Memory-, Verifier- und Blocker-Events auf Organism-Eventarten, Capability-Hubs, Brain-Regions und Replay-Frames.
- Die Runtime-Projektion liest nur `event_type`, `severity` und `created_at`; raw `details`, `user_id`, `session_id`, Prompts und Secret-Werte werden nicht serialisiert.
- `run_id`/`thread_id`-Filter sind exakt gegen `details->>'trace_id'`, `details->>'thread_id'`, `details->>'run_id'` und `session_id`, damit der Verifier nicht alte Audit-Zeilen als Beweis nutzt.
- Neuer Verifier `scripts/verify-organism-runtime-events.ps1` startet bei Bedarf einen lokalen deterministischen Phase-2-Run oder nutzt einen uebergebenen Run, prueft `source=agent-api`, `source_kind=agent_api_redacted`, `live=true`, `replay_available=true`, Events/Frames, `writes=false`, `secret_output=false` und keine raw `details`/`user_id`/`session_id`/`prompt`-Felder.
- `scripts/verify-browser-contract.ps1` und `scripts/verify-phase1-runtime.ps1` rufen den neuen Verifier nach dem bestehenden Phase-2-Runtime-Status auf.
- Verifiziert mit `py -3 -m py_compile services\agent-api\app\main.py`, PowerShell Parser-Checks fuer die geaenderten Verifier, `docker compose -f docker-compose.dev.yml up -d --build agent-api nginx`, `scripts\verify-organism-runtime-events.ps1`, `npm run verify:browser`, `npm run verify:runtime`, `npm run verify`, `py -3 scripts\verify_project_progress_manifest.py`, `git diff --check` und `npm run verify:external-gates`.
- Ergebnis: lokale DEV-ONLY Organism-Events/Replays sind belegt; External Gates bleiben mit `.phase1-artifacts/external-gate-audit-20260610-143257.json` blocked. Kein Deploy, keine Cloud-Mutation, kein Production-Claim und keine Prozentsteigerung.

**22-Seiten Organism Wiring Contract** — alle kanonischen Workbench-Seiten sind jetzt typed mit Gehirnregionen, Capability-Hubs, Datenquellen und Verifiern verdrahtet:

- `apps/frontend/lib/workspaceWiring.ts` definiert `workspace-surface-wiring-v1` fuer exakt 22 Seiten mit `brainRegion`, `hub`, `dataSources`, `verifierRefs`, `eventKinds` und den Non-Claims `live=false`, `writes=false`, `secretOutput=false`.
- `GET /api/v1/workspace/wiring` existiert im Frontend und als Agent-API-Mirror in `services/agent-api/app/main.py`; beide liefern `workspace_surface_wiring_visible` und `page_count=22`.
- `GET /api/v1/organism/contract` und `GET /api/v1/organism/topology` enthalten jetzt `workspace_page_count=22`, Page-Nodes und Kanten `page_to_brain_region`, `page_to_capability_hub`, `page_to_data_source` und `page_to_verifier`.
- `scripts/verify-workspace-pages-layer-map.ps1`, `scripts/verify-browser-contract.ps1` und `apps/frontend/e2e/organism.spec.ts` pruefen das Wiring, die Backend-Spiegelung und die 22 Seiten gegen das Organism-Modell.
- Verifiziert mit `py -3 -m py_compile services\agent-api\app\main.py`, `npm run lint --prefix apps/frontend`, `npm run build --prefix apps/frontend`, `npm run test:e2e --prefix apps/frontend` (`10 passed`), `scripts/verify-workspace-pages-layer-map.ps1`, `npm run verify:runtime`, `npm run verify:browser`, `scripts\verify-phase1.ps1`, `py -3 scripts\verify_project_progress_manifest.py`, `git diff --check` und `npm run verify:external-gates`.
- kein Deploy, keine Cloud-Mutation, kein Production-Claim und keine Prozentsteigerung.

**Frontend Local E2E Rewrite/Hydration Recovery** — lokale Workbench-/Organismus-Tests sind wieder von Cloud-Origin-Proxies entkoppelt:

- `apps/frontend/next.config.mjs` nutzt Default-Fly-Rewrites nur noch bei explizitem `STAGING_REWRITES_ENABLED` oder expliziten `FLY_APP_*`-Origins; ohne Cloud-Gate bleiben lokale `/api/v1/*`-Routes lokal.
- `scripts/verify-frontend-cloud-rewrites.ps1` prueft jetzt zusaetzlich, dass Plain-Local keine Cloud-Rewrites erzeugt, unsichere Origins ohne Cloud-Modus fail-closed bleiben und Cloud-Modus weiterhin auf Fly-Defaults fallen kann.
- `apps/frontend/components/organism/CortexLive.tsx` und `apps/frontend/components/organism/OrganismView.tsx` vermeiden SSR/Client-Hydration-Drift, indem 3D-/GPU-Erkennung erst nach Client-Mount erfolgt.
- `scripts/verify-browser-contract.ps1`, `scripts/verify-phase1-runtime.ps1` und `scripts/verify-phase1.ps1` pruefen die aktuelle Completion-/Preflight-Truth listenbasiert: `fly_api_token` plus `vercel_backend_origins`, `fly_cloud_stack` plus `hosted_backend_origins`.
- Verifiziert mit `scripts/verify-frontend-cloud-rewrites.ps1`, `scripts/verify-workspace-pages-layer-map.ps1`, `npm run lint --prefix apps/frontend`, `npm run build --prefix apps/frontend`, `npm run test:e2e --prefix apps/frontend` (`9 passed`), `npm run verify:browser`, `npm run verify:runtime`, `scripts/verify-phase1.ps1` und `npm run verify:external-gates`.
- kein Deploy, keine Cloud-Mutation, kein Production-Claim und keine Prozentsteigerung.

**22-Seiten-/7-Layer-Registry Guard** — die Workbench-Seitenstruktur ist lokal gegen die bindende Layer-Taxonomie abgesichert:

- neuer Verifier `scripts/verify-workspace-pages-layer-map.ps1`
- prueft exakt 22 `WORKSPACE_PAGES`, reale `page.tsx`-Routen, keine Rueckkehr der alten Aliase `/about/stack`, `/about/open-source`, `/design-system/responsive`
- supplemental Routes `/`, `/organism/live` und `/responsive` bleiben erlaubt, aber nicht Teil der kanonischen 22
- Layer-Codes werden gegen `docs/system-architecture.md` gemappt: Frontend, Orchestration, Agent Pool, LLM Gateway, Tool MCP, Memory, Observability
- in `scripts/verify-phase1.ps1` eingebunden; kein UI-Projektstatus, kein Deploy, kein Production-Claim

**Phase-5 Browser Manifest Retire Guard** — der Manifest-Status traegt keine aktive Browser-Evidence mehr fuer retired `sslip.io`/Hetzner-Proofs:

- `docs/project-progress.manifest.json` markiert die alten Browser-Bridge-, Browser-Proof-, Post-Rollback-Browser-, Final-Browser-, Full-Sweep- und Truth-Mirror-Browser-Tokens als retired/current-hosted-blocked
- `scripts/verify-retired-hosted-boundary.ps1` prueft diese Manifest-Tokens jetzt zusaetzlich zu Candidate- und Proof-Artefakten
- Verifiziert mit `py -3 scripts\verify_project_progress_manifest.py` und `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-retired-hosted-boundary.ps1`
- keine Prozentsteigerung, kein Deploy, keine Cloud-Mutation, kein Production-Claim

**Cloud-Gate-Realignment 2026-06-08** — aktive Gates und Verifier sind auf Vercel/Fly.io/GHCR/Grafana ausgerichtet:

- `scripts/verify-external-gates.ps1` nutzt fuer das Fly-Live-Budget den kanonischen `scripts/check_fly_infra_budget.py`-Pfad und bleibt ohne `FLY_API_TOKEN` fail-closed.
- Direkte MCP-/LLM-Fly-Origin-URLs werden jetzt korrekt an `/api/v1/health` geprueft; path-prefixed Reverse-Proxy-URLs wie `/mcp` und `/llm` bleiben unter diesem Prefix gueltig.
- `fly.agent-api.toml`, `fly.mcp-gateway.toml` und `fly.llm-gateway.toml` bereiten die drei origin health gates getrennt vor; `scripts/verify-phase1.ps1` prueft diese Configs offline.
- `apps/frontend/next.config.mjs` nutzt dieselbe Origin-Prioritaet fuer Vercel-Rewrites: explizite HTTPS-Origin, Fly-App-Name/Fly-Default, dann Hosted-Rewrite-Fallback; `scripts/verify-frontend-cloud-rewrites.ps1` prueft diese Matrix ohne Secrets und ohne Deploy.
- `scripts/verify-external-gates.ps1` begrenzt HTTP- und native Prozess-Probes fail-closed; Timeout-Proof erzeugte ein nicht-geheimes blocked Artifact statt haengender Ausfuehrung.
- Hosted-Verifier ohne echte HTTPS-`STAGING_BASE_URL` brechen fail-closed ab; localhost kann keine Cloud-Gates schliessen.
- Frontend-Stack ist auf Next.js `16.2.7`, React `19.2.7`, Three `0.184.0` und `@types/node` `25.9.2`; ESLint bleibt bewusst auf kompatiblem `9.39.4`, weil `eslint@10` Peer-Konflikte im aktuellen Next-Plugin-Stack erzeugt.
- Verifiziert: `npm run build`, `npm run lint --prefix apps/frontend`, `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`, `npm run verify:browser`, `npm run verify:runtime`, `npm run verify:external-gates`.
- Ergebnis: lokale Checks gruen; External Gates bleiben mit `.phase1-artifacts/external-gate-audit-20260609-202428.json` blocked auf `hosted_agent_api_contracts`, `github_branch_protection_current_verify`, `vercel_backend_origin_health` und `fly_live_budget_check`. `canonical_gitleaks_scan` und `ghcr_image_digest_verify` sind verified; GitLab-, Hugging-Face- und Grafana-Identity bleiben im Basislauf ohne Token fail-closed. Hosted-Proof ist ohne echte HTTPS-`STAGING_BASE_URL` blockiert; Vercel-Origin-Probes bleiben ohne `AGENT_API_BASE_URL`, `MCP_GATEWAY_BASE_URL` und `LLM_GATEWAY_BASE_URL` blockiert.

**Historischer Phase 5 Integration Smoke Plan Rerun** — dieser `RC1`-Truth bleibt als historische Candidate-Evidence erhalten, ist aber kein aktueller Hosted-Gate-Proof mehr:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-smoke-plan-rerun.md` dokumentiert einen frischen candidate-scoped Hosted-Smoke-Lauf gegen Root, API-, MCP- und LLM-Health, Project Progress, Integrity, Completion, External Gates, External-Gates-Mirror und Deployment-Preflight
- `scripts/verify-phase5-integration-smoke-plan-rerun.ps1` band denselben Proof damals an die inzwischen retired `sslip.io`/Hetzner-Surface; aktuelle Hosted-Gates muessen ueber eine Vercel-HTTPS-`STAGING_BASE_URL` neu bewiesen werden
- der Rerun fuehrt weiter `IMAGE_TAG=staging` als aktuellen Selector und `IMAGE_TAG=ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5` als immutable Rollback-Selector
- Der damalige Hetzner-Sync ist historische Provenance; aktuelle External Gates bleiben laut `.phase1-artifacts/external-gate-audit-20260609-202428.json` blocked.
- dies ist ein weiterer Release-Readiness-/Smoke-Rerun-Batch, kein Rollout-Claim und kein Production-Deploy

**Vorheriger Abschluss — Phase 5 Executed Rollback + Post-Rollback Requalification + Release Readiness Rerun** — der aktuelle `RC1`-Truth ist jetzt nochmals gegen den Rollback-Lane- und Release-Readiness-Pfad auf `overall=70`, `phase_5=66` nachgezogen:

- `.phase1-artifacts/phase5-executed-rollback-rerun-20260507.md` bindet den bereits ausgefuehrten immutable Rollback-Pfad erneut an den heutigen Truth `overall=70`, `phase_5=66`, bestaetigt `IMAGE_TAG=staging` als wiederhergestellten Hosted-Selector und prueft die vier hosted Health-Endpunkte erneut
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-requalification-rerun.md` bestaetigt denselben Hosted-Selector, dieselbe aktuelle Progress-/Integrity-Truth, fail-closed `completion=false` und weiter `external_gates=verified`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-release-readiness-rerun.md` zieht den aktiven Candidate, die Runbooks, die Hosted-Truth und die aktive Browser-Evidence nochmals in einen frischen Candidate-scoped Release-Readiness-Rerun zusammen
- `.phase1-artifacts/phase5-owner-decision-no-release-20260505.md`, `.phase1-artifacts/phase5-rollback-readiness-20260505.md` und `.phase1-artifacts/phase5-release-baseline-refresh-20260507.md` sind im selben Batch vom alten Truth auf den aktuellen Stand repariert
- Der damalige Hetzner-Sync ist historische Provenance; aktuelle Hosted-Gate-Wahrheit kommt aus dem Vercel/Fly External-Gate-Audit und bleibt blocked.
- dies ist ein weiterer Release-Readiness-/Truth-Repair-Batch, kein Rollout-Claim und kein Production-Deploy

**Vorheriger Abschluss — Phase 5 Final Browser E2E + Full Verifier Sweep + Truth Mirror Rebaseline** — der aktuelle `RC1`-Truth ist jetzt auf `overall=70`, `phase_5=63` sauber geschlossen:

- `.phase1-artifacts/phase5-final-browser-e2e-recheck-20260507.md` belegt einen frischen lokalen und gehosteten AI-Browser-Lauf mit sichtbaren Markern `Cloud Superbrain`, `Project Progress`, `External Gates`, `Phase 5 - Release Readiness`, `Progress Integrity`, `Error Response Contract` und `System Unavailable Fallback`
- `.phase1-artifacts/phase5-full-verifier-sweep-20260507.md` belegt den kompletten grünen Sweep aus `py -3 scripts\verify_project_progress_manifest.py`, dem vollen `verify-phase5*.ps1`-Lauf, `verify-phase1.ps1` und `gitleaks`
- `.phase1-artifacts/phase5-truth-mirror-rebaseline-20260507.md` belegt den synchronen Truth-Mirror-Zustand fuer `docs/project-progress.manifest.json`, `docs/verification-register.md`, `PROJECT_STATE.md`, `AI_HANDOFF.md` und den aktiven Candidate
- Der damalige Hetzner-Sync ist historische Provenance; er darf nicht als aktueller Hosted-Gate-Proof wiederverwendet werden.
- dies ist ein Verifier-/Mirror-Abschlussbatch, kein Rollout-Claim und kein Production-Deploy

**Vorheriger Abschluss — Phase 5 Browser Evidence Retire Repair** — die alte `sslip.io`/Hetzner-Browser-Evidence-Kette fuer `RC1` ist wieder fail-closed und nur historische Provenance:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md` ist `superseded` und `current_candidate_evidence=false`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-browser-revalidation.md` ist `superseded` und `current_candidate_evidence=false`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt historische Browser-Felder; aktuelle Browser-Evidence erfordert Vercel HTTPS `STAGING_BASE_URL` plus erreichbare Fly Origins
- `scripts/verify-phase5-browser-proof.ps1` und `scripts/verify-phase5-post-rollback-browser-revalidation.ps1` pruefen fail-closed den historischen Zustand statt einen aktuellen Live-Browser-Claim weiterzutragen
- `scripts/verify-retired-hosted-boundary.ps1` schuetzt diese Grenze im Phase-1-Verifier

**Vorheriger Abschluss — Phase 5 Full Verifier Rebaseline Sweep** — die komplette `verify-phase5*.ps1`-Kette ist gegen den damaligen fail-closed Candidate-Truth `overall=69`, `phase_5=57` neu ausgerichtet und einmal voll gruen durchgelaufen:

- `verify-phase5-auth-gate-recheck.ps1`, `verify-phase5-budget-review.ps1`, `verify-phase5-checklist-conformance.ps1`, `verify-phase5-integration-plan-rebaseline.ps1`, `verify-phase5-open-questions-acceptance.ps1`, `verify-phase5-observability-recheck.ps1`, `verify-phase5-risk-review-recheck.ps1`, `verify-phase5-runbook-applicability.ps1` und `verify-phase5-smoke-recheck.ps1` lesen den erwarteten Hosted-Truth jetzt manifest-dynamisch statt aus alten Pins `65/66/67`
- `verify-phase5-executed-smoke.ps1`, `verify-phase5-handoff-packet.ps1`, `verify-phase5-memory-recovery-drill.ps1`, `verify-phase5-post-handoff-stability-watch.ps1`, `verify-phase5-post-phase4-rebaseline.ps1`, `verify-phase5-post-rollback-stability-watch.ps1`, `verify-phase5-promotion-gate-refusal.ps1`, `verify-phase5-provider-failover-drill.ps1` und `verify-phase5-secret-rotation-drill.ps1` sind ebenfalls auf denselben damaligen Truth gezogen
- die zugehoerigen RC1-Artefakte in `docs/release-artifacts/` und `.phase1-artifacts/` tragen seitdem konsistent dieselbe Hosted-Wahrheit statt historischer Zwischenstaende
- Vollsweep belegt: **alle** `verify-phase5*.ps1` liefen gruen, `verify-phase1.ps1` blieb gruen, `verify_project_progress_manifest.py` blieb gruen, `gitleaks` fand keine Leaks
- dieser Batch schloss Drift und Verifier-Repair, ohne einen Rollout-Claim oder Production-Deploy einzufuehren

**Vorheriger Abschluss — Phase 5 Browser Claims Fail-Closed Repair** — die aktiven Candidate-Browser-Claims sind aus dem aktuellen Truth entfernt, weil frische Live-Evidence im In-App-Browser derzeit extern blockiert ist:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md` und `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-browser-revalidation.md` sind jetzt explizit als historische, superseded Artefakte markiert
- `scripts/verify-phase5-browser-proof.ps1` und `scripts/verify-phase5-post-rollback-browser-revalidation.ps1` pruefen jetzt fail-closed den aktuellen Blockerzustand statt einen nicht reproduzierbaren Live-Browser-Claim weiter als aktuell zu behandeln
- `scripts/verify-phase5-candidate.ps1` und `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehren die beiden Browser-Proofs nicht mehr als aktuelle Candidate-Evidence; stattdessen ist der Browser-Rerun-Blocker explizit dokumentiert
- die harte Blocker-Evidence lautet:
  - `node_repl` + `iab`: `failed to start codex app-server ... (os error 3)`
  - `chrome_devtools`: `Target.setDiscoverTargets): Target closed`
  - Playwright: Launcher `exit code 13`
- Fortschritt bleibt repo-ehrlich: Gesamt bleibt `69%`, Phase 5 sinkt auf `57%`; das beseitigt zwei unbelegte aktuelle Claims und fuehrt keinen Rollout- oder Production-Deploy-Claim ein

**Vorheriger Abschluss — Phase 5 Post-Rollback Provenance + Incident + Rollback Drill Rerun** — drei weitere zentrale Release-Readiness-Beweise sind jetzt auf die aktuelle Hosted-Truth und den aktuellen immutable Candidate-SHA gezogen:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-provenance-revalidation.md` bindet den Candidate jetzt an `overall=69`, `phase_5=59`, den aktuellen Workflow-Run `25392582005`, den immutable GHCR-SHA `ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5` und weiter `owner_decision=no-release`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-incident-drill.md` prueft Deployment-Preflight jetzt korrekt ueber die Runtime-Surface `GET /api/v1/clouds/deployment-preflight` und nennt denselben aktuellen immutable Rollback-SHA statt des alten `5464...`-Pfads
- `.phase1-artifacts/phase5-rollback-drill-prod-candidate-20260505-rc1.md` und `scripts/verify-phase5-rollback-drill.ps1` sind jetzt auf Workflow `25392582005` und SHA `ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5` rebasiert; `scripts/verify-phase5-candidate.ps1` leitet den erwarteten Rollback-Drill-SHA jetzt direkt aus dem Candidate-Artefakt ab statt aus einem alten Pin
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-plan.md` und `scripts/verify-phase5-integration-plan.ps1` sind im selben Zug vom alten Contract-/Rollback-Drift befreit
- Verifiziert mit `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-post-rollback-provenance-revalidation.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-incident-drill.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-rollback-drill.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-integration-plan.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py` und `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `69%`, Phase 5 steigt auf `59%`; dies schliesst drei weitere Release-Readiness-Proofs, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 5 Risk + Observability + Smoke Rerun** — drei weitere Legacy-Beweise sind jetzt auf die aktuelle Hosted-Truth gehoben und erneut verifiziert:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-risk-review.md` bindet den Candidate jetzt an `overall=69`, `phase_5=56`, `integrity=verified`, fail-closed `completion`, `external_gates=verified` und weiter `owner_decision=no-release`
- `scripts/verify-phase5-risk-review.ps1` liest den erwarteten Hosted-Truth jetzt manifest-dynamisch statt aus hart verdrahtetem Altstand `53/18`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-observability-review.md` bindet Health, Progress, Integrity, Metrics, Audit, Escalations und External Gates jetzt an denselben aktuellen Candidate-Truth
- `scripts/verify-phase5-observability-review.ps1` liest den erwarteten Hosted-Truth jetzt manifest-dynamisch statt aus hart verdrahtetem Altstand `52/11`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-smoke-proof.md` bindet den Legacy-Smoke-Proof jetzt an `overall=69`, `phase_4=100`, `phase_5=56`; der Verifier prueft Deployment-Preflight dabei korrekt ueber die Runtime-Surface statt ueber den Contract-Endpunkt
- Verifiziert mit `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-risk-review.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-observability-review.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-executed-smoke.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py` und `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt steigt auf `69%`, Phase 5 steigt auf `56%`; dies sind drei weitere Release-Readiness-Proofs, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 5 Candidate Checklist Conformance Review** — der aktuelle Production-Candidate ist jetzt nochmals direkt an die aktive Release-Checklist und die aktuelle Hosted-Truth gebunden:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-checklist-conformance.md` dokumentiert die aktuelle Candidate-Konformitaet gegen die vier Pflichtsektionen `Code Readiness`, `Infrastructure Readiness`, `Observability Readiness` und `Operations Readiness`
- `scripts/verify-phase5-checklist-conformance.ps1` prueft Artefaktstruktur, Candidate-Linking, die verpflichtenden `[x]`-Checklist-Items, Candidate-Pflichtfelder, Hosted `GET /api/v1/health`, Hosted `GET /api/v1/project/progress`, Hosted `GET /api/v1/project/progress/integrity`, Hosted `GET /api/v1/project/progress/completion` und Hosted `GET /api/v1/external-gates`
- Verifiziert mit `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-checklist-conformance.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py` und `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `65%`, Phase 5 steigt auf `31%`; dies ist ein neuer Release-Readiness-/Checklist-Proof, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 5 Candidate Runbook Applicability Review** — der aktuelle Production-Candidate ist jetzt nochmals direkt an die aktiven Operations-Runbooks und die aktuelle Hosted-Truth gebunden:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-runbook-applicability.md` dokumentiert die aktuelle Anwendbarkeit von `rollback-deploy`, `incident-response`, `secret-rotation`, `provider-failover` und `memory-recovery` gegen den laufenden Candidate-Stand
- `scripts/verify-phase5-runbook-applicability.ps1` prueft Artefaktstruktur, Candidate-Linking, verpflichtende Runbook-Sektionen, Hosted `GET /api/v1/health`, Hosted `GET /api/v1/project/progress`, Hosted `GET /api/v1/project/progress/integrity`, Hosted `GET /api/v1/project/progress/completion` und Hosted `GET /api/v1/external-gates`
- Verifiziert mit `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-runbook-applicability.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py` und `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `65%`, Phase 5 steigt auf `30%`; dies ist ein neuer Release-Readiness-/Operations-Proof, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 5 Post-Phase4 Candidate Rebaseline** — der aktuelle Production-Candidate ist jetzt nochmals direkt gegen den kompletten gehosteten `P4=100`-Truth revalidiert:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-phase4-rebaseline.md` bindet den Candidate an die aktuelle hosted Runtime-Truth mit `overall=65`, `phase_4=100`, `phase_5=29`, `integrity=verified`, `external_gates=verified`, weiter fail-closed `completion_can_set_all_to_100=false` und unveraendertem `owner_decision=no-release`
- `scripts/verify-phase5-post-phase4-rebaseline.ps1` prueft Artefaktstruktur, Candidate-Linking, Hosted `GET /api/v1/health`, Hosted `GET /api/v1/project/progress`, Hosted `GET /api/v1/project/progress/integrity`, Hosted `GET /api/v1/project/progress/completion` und Hosted `GET /api/v1/external-gates`
- Verifiziert mit `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-post-phase4-rebaseline.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py` und `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `65%`, Phase 5 steigt auf `29%`; dies ist ein neuer Release-Readiness-Proof, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 4 Hosted System Fallback Contract Runtime Parity** — der letzte offene Public-Runtime-Slice ist jetzt gehostet direkt an echte Health- und Frontend-Projektion gebunden:

- `scripts/verify-phase4-system-fallback-contract-runtime-hosted.ps1` bindet den sichtbaren Fallback-Contract an die echte hosted Frontend-Surface `GET /` und die echte hosted Health-Surface `GET /api/v1/health`
- der Proof bestaetigt `contract_version=system-unavailable-fallback-v1`, `ui_state=System Unavailable`, `health_endpoint=GET /api/v1/health`, sichtbare `no_fake_healthy_claim`-/`failed_service_visible`-Policies, sichtbare Retry-Action und zugleich eine gesunde aktuelle hosted Runtime mit allen erforderlichen Services auf `healthy`
- `.phase1-artifacts/phase4-system-fallback-contract-runtime-hosted-proof-20260507.md` dokumentiert den erfolgreichen Hosted-Proof
- Verifiziert mit `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-system-fallback-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py` und `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `65%`, Phase 4 steigt auf `100%`; dies schliesst Phase 4 fachlich und bleibt weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 4 Hosted Memory Embedding Consistency Parity** — die bestehende Embedding-Consistency-Surface ist jetzt nicht mehr nur lokal/statisch sichtbar, sondern gehostet gegen echte Runtime- und Search-Projektion gebunden:

- `scripts/verify-phase4-memory-embedding-consistency-hosted.ps1` prueft `GET /api/v1/memory/embedding-consistency/contract` gegen die echte Hosted-Runtime auf Hetzner
- der Proof bestaetigt `contract_version=memory-embedding-consistency-v1`, `status=verified`, Schema-Paritaet fuer `memory_entries.content_embedding vector(1536)`, `embedding_model_version`, `metadata` und `status`, null Schema-Drift, `search_mode=lexical_fallback`, `generation_mode=disabled_until_live_embedding_gate` und `live_embedding_provider_calls=false`
- derselbe Proof bindet den Contract an eine echte Hosted-Search-Projektion: `GET /api/v1/memory/search/contract`, frischer `POST /api/v1/prompt` und anschliessendes `GET /api/v1/memory/search` unter derselben fail-closed lexical-fallback-Policy
- `.phase1-artifacts/phase4-memory-embedding-consistency-hosted-proof-20260507.md` dokumentiert den erfolgreichen Hosted-Proof
- Verifiziert mit `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-memory-embedding-consistency-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py` und `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `62%`, Phase 4 steigt auf `80%`, Memory auf `72%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Phase 4 Hosted Layer Interfaces + Phase 2 Runtime Contract Parity** — zwei weitere oeffentliche Runtime-Surfaces sind jetzt gehostet direkt an echte Hetzner-Runtime-Projektion gebunden:

- `scripts/verify-phase4-layer-interfaces-contract-runtime-hosted.ps1` bindet `GET /api/v1/layer-interfaces/contract` gehostet an die reale Verfuegbarkeit der referenzierten Runtime-Surfaces `prompt`, `phase2/runtime`, `tasks/policy`, `mcp health`, `memory/search` und `metrics`
- `scripts/verify-phase4-phase2-runtime-contract-hosted.ps1` bindet `GET /api/v1/phase2/runtime/contract` gehostet an `GET /api/v1/phase2/runtime/runs` und prueft echte Hosted-Run-Status-Projektion inklusive `engine=langgraph`, `checkpointing=postgres`, `live_provider_calls=false`, `live_mcp_writes=false`, `production_deploy=false`, `role_summary_count>=4` und `agent_result_aggregation_complete`
- `.phase1-artifacts/phase4-layer-interfaces-contract-runtime-hosted-proof-20260507.md` und `.phase1-artifacts/phase4-phase2-runtime-contract-hosted-proof-20260507.md` dokumentieren die erfolgreichen Hosted-Proofs
- beim Layer-Interfaces-Slice waren die einzigen Fehler reine Verifier-Drifts auf exakte Contract-Namen:
  - `task-policy-contract-v1`
  - `memory-search-runtime-v1`
- Verifiziert mit `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-layer-interfaces-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-phase2-runtime-contract-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py` und `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `62%`, Phase 4 steigt auf `79%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 4 Hosted Cloud Render Offload + Cloud Deployment Preflight Runtime Surfaces** — die bisherigen Cloud-Contracts sind jetzt auch als eigene gehostete Runtime-Surfaces fail-closed an die echte Hetzner-Runtime gebunden:

- `services/agent-api/app/main.py` exponiert jetzt `GET /api/v1/clouds/render-offload` plus `GET /api/v1/clouds/render-offload/contract` sowie `GET /api/v1/clouds/deployment-preflight` plus `GET /api/v1/clouds/deployment-preflight/contract`
- der sichtbare Render-Offload-Contract deklariert `contract_version=cloud-render-offload-surface-v1`, den Runtime-Endpunkt `GET /api/v1/clouds/render-offload`, die erforderlichen Gate-/Workload-Felder und die unterstuetzten Statuswerte `cloud_runtime_ready|action_required`
- der sichtbare Deployment-Preflight-Contract deklariert `contract_version=cloud-deployment-preflight-surface-v1`, den Runtime-Endpunkt `GET /api/v1/clouds/deployment-preflight`, die erforderlichen Gate-Felder und die unterstuetzten Statuswerte `verified|ready_for_external_execution|action_required`
- `scripts/verify-phase4-cloud-render-offload-runtime-hosted.ps1` und `scripts/verify-phase4-cloud-deployment-preflight-runtime-hosted.ps1` binden die sichtbaren Contracts gehostet an die echte Runtime auf Hetzner
- `.phase1-artifacts/phase4-cloud-render-offload-runtime-hosted-proof-20260507.md` und `.phase1-artifacts/phase4-cloud-deployment-preflight-runtime-hosted-proof-20260507.md` dokumentieren die erfolgreichen Hosted-Proofs
- beim Render-Offload-Slice war der einzige echte Fehler ein zu strenger Feldcheck im Verifier: `control_plane.blocker` ist absichtlich `null`, deshalb prueft der Verifier jetzt Feld-Praesenz statt Nicht-Null
- Verifiziert mit `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-cloud-render-offload-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-cloud-deployment-preflight-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py` und `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt geht auf `62%`, Phase 4 steigt auf `77%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 4 Hosted Cloud Inventory + Cloud Layers Contract Runtime Parity** — die oeffentlichen `clouds`- und `clouds/layers`-Surfaces haben jetzt je einen eigenen sichtbaren Contract, der gehostet gegen die echte Runtime verifiziert ist:

- `services/agent-api/app/main.py` exponiert jetzt `GET /api/v1/clouds/contract` ueber `cloud_inventory_contract_payload()` und `GET /api/v1/clouds/layers/contract` ueber `cloud_layers_contract_payload()`
- der sichtbare Inventory-Contract deklariert `contract_version=cloud-provider-surface-v1`, die erforderlichen Top-Level-Felder, die erforderlichen Provider-Felder, die Provider-ID-Menge und die Layer-Mapping-ID-Menge
- der sichtbare Layers-Contract deklariert `contract_version=cloud-layer-surface-v1`, die erforderlichen Top-Level-Felder, die erforderlichen Layer-Felder, die Layer-ID-Menge und die unterstuetzten Layer-Statuswerte
- `scripts/verify-phase4-cloud-inventory-contract-runtime-hosted.ps1` und `scripts/verify-phase4-cloud-layers-contract-runtime-hosted.ps1` binden die sichtbaren Contracts gehostet an `GET /api/v1/clouds` und `GET /api/v1/clouds/layers` auf dem echten Hetzner-Stack
- `.phase1-artifacts/phase4-cloud-inventory-contract-runtime-hosted-proof-20260507.md` und `.phase1-artifacts/phase4-cloud-layers-contract-runtime-hosted-proof-20260507.md` dokumentieren die erfolgreichen Hosted-Proofs
- Verifiziert mit `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-cloud-inventory-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-cloud-layers-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py` und `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `61%`, Phase 4 steigt auf `75%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 4 Hosted External Gates Contract Runtime Parity** — die oeffentliche External-Gates-Surface ist jetzt nicht mehr nur implizit ueber Gate-State-, Mirror- und Preflight-Beweise abgesichert, sondern hat einen eigenen sichtbaren Contract, der gehostet gegen die echte Runtime verifiziert ist:

- `services/agent-api/app/main.py` exponiert jetzt `GET /api/v1/external-gates/contract` ueber `external_gates_surface_contract_payload()`
- der sichtbare Contract deklariert `contract_version=external-gates-surface-v1`, die erforderlichen Top-Level-Felder, die Pflicht-Gate-Felder sowie die erforderlichen Gate-ID- und Preflight-Gate-ID-Mengen
- `scripts/verify-phase4-external-gates-contract-runtime-hosted.ps1` bindet den sichtbaren Contract gehostet an `GET /api/v1/external-gates` auf dem echten Hetzner-Stack
- `.phase1-artifacts/phase4-external-gates-contract-runtime-hosted-proof-20260507.md` dokumentiert den erfolgreichen Hosted-Proof
- Verifiziert mit `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-external-gates-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py` und `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `61%`, Phase 4 steigt auf `73%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 4 Hosted Health Contract Runtime Parity** — die oeffentliche Health-Surface ist jetzt nicht mehr nur implizit ueber Fallback-, Budget- und External-Gate-Beweise abgesichert, sondern hat einen eigenen sichtbaren Contract, der gehostet gegen die echte Runtime verifiziert ist:

- `services/agent-api/app/main.py` exponiert jetzt `GET /api/v1/health/contract` ueber `health_contract_payload()`
- der sichtbare Contract deklariert `contract_version=health-surface-v1`, die erforderlichen Top-Level-Felder, die Pflicht-Service-Keys, die eingebetteten Budget-/Infra-Budget-/External-Gate-Feldmengen und die unterstuetzten Statuswerte
- `scripts/verify-phase4-health-contract-runtime-hosted.ps1` bindet den sichtbaren Contract gehostet an `GET /api/v1/health` auf dem echten Hetzner-Stack
- `.phase1-artifacts/phase4-health-contract-runtime-hosted-proof-20260507.md` dokumentiert den erfolgreichen Hosted-Proof
- Verifiziert mit `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-health-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py` und `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `61%`, Phase 4 steigt auf `72%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 4 Hosted Costs Contract Runtime Parity** — die oeffentliche Costs-Surface ist jetzt nicht mehr nur implizit ueber Budget-, Metrics- und Export-Beweise abgesichert, sondern hat einen eigenen sichtbaren Contract, der gehostet gegen die echte Runtime verifiziert ist:

- `services/agent-api/app/main.py` fuehrt jetzt `costs_contract_payload()` plus `GET /api/v1/costs/contract` ein
- der neue sichtbare Costs-Contract deklariert:
  - `contract_version=costs-surface-v1`
  - die bindenden Runtime-Felder der Costs-Surface
  - die bindenden `breakdown[]`-Felder
  - die unterstuetzten Budget-Level `ok|warning|critical`
- `scripts/verify-phase4-costs-contract-runtime-hosted.ps1` prueft gehostet `GET /api/v1/costs/contract` und `GET /api/v1/costs` und bindet den sichtbaren Contract an die echte Hosted-Runtime
- der erste Verifier-Fehler lag nur im direkten Post-Recreate-Startfenster; nach Abschluss des Stack-Recreate lieferte die neue Hosted-Contract-Route `200` und der robuste Verifier lief gruen
- `.phase1-artifacts/phase4-costs-contract-runtime-hosted-proof-20260507.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof
- Verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-costs-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `61%`, Phase 4 steigt auf `71%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Budget Contracts Runtime Parity** — die oeffentlichen Budget-Surfaces sind jetzt nicht mehr nur implizit ueber Metrics-, Budget-Guard- und Infra-Budget-Beweise abgesichert, sondern haben eigene sichtbare Contracts, die gehostet gegen die echte Runtime verifiziert sind:

- `services/agent-api/app/main.py` fuehrt jetzt `budget_contract_payload()` plus `GET /api/v1/budget/contract` und `infra_budget_contract_payload()` plus `GET /api/v1/infra/budget/contract` ein
- die neuen sichtbaren Budget-Contracts deklarieren:
  - `contract_version=budget-surface-v1`
  - `contract_version=infra-budget-surface-v1`
  - die bindenden Runtime-Felder fuer beide Budget-Surfaces
  - die unterstuetzten Budget-Level `ok|warning|critical`
  - fuer Infra zusaetzlich die erlaubten Sources `projection|hetzner_api_readonly` und die bindenden `items[]`-Felder
- `scripts/verify-phase4-budget-contracts-runtime-hosted.ps1` prueft gehostet `GET /api/v1/budget/contract`, `GET /api/v1/budget`, `GET /api/v1/infra/budget/contract` und `GET /api/v1/infra/budget` und bindet beide sichtbaren Contracts an die echte Hosted-Runtime
- der erste 404 auf `/api/v1/budget/contract` lag nur im direkten Post-Recreate-Startfenster; nach Abschluss des Stack-Recreate liefen beide neuen Hosted-Contract-Routen ohne Codeaenderung gruen
- `.phase1-artifacts/phase4-budget-contracts-runtime-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof
- Verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-budget-contracts-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt geht auf `61%`, Phase 4 steigt auf `70%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Phase 4 Hosted MCP Audit Feed Contract Runtime Parity** — der oeffentliche MCP-Audit-Feed ist jetzt nicht mehr nur implizit ueber allgemeine Audit- oder MCP-Safe-Envelope-Proofs abgesichert, sondern hat einen eigenen sichtbaren Contract, der gehostet gegen die echte Runtime verifiziert ist:

- `services/agent-api/app/main.py` fuehrt jetzt `mcp_audit_feed_contract_payload()` plus `GET /api/v1/audit/mcp/contract` ein
- der neue sichtbare MCP-Audit-Feed-Contract deklariert:
  - `contract_version=mcp-audit-feed-v1`
  - die bindenden Event-Top-Level-Felder
  - die bindenden Detail-Felder eines `mcp_tool_executed`-Runtime-Events
  - die unterstuetzten Status `success|blocked|timeout|degraded`
- `scripts/verify-phase4-mcp-audit-feed-contract-runtime-hosted.ps1` prueft gehostet `GET /api/v1/audit/mcp/contract`, erzeugt ein echtes Hosted-`mcp_tool_executed`-Event via `POST /internal/audit/mcp-tool-events` und bindet den Contract an `GET /api/v1/audit/mcp`
- derselbe Schritt haertet den Deploy-Pfad in `scripts/deploy-to-staging.ps1`, indem die Remote-Hot-Mount-Verzeichnisse vor dem rekursiven Copy gezielt zurueckgesetzt werden; damit wird der echte Host-Drift `app/app` beseitigt, der neue Runtime-Routen vorher shadowen konnte
- `.phase1-artifacts/phase4-mcp-audit-feed-contract-runtime-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof
- Verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-mcp-audit-feed-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `60%`, Phase 4 steigt auf `68%`, MCP Gateway steigt auf `55%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Phase 4 Hosted Session History Contract Runtime Parity** — `sessions/{session_id}/history` ist jetzt nicht mehr nur implizit ueber Session-Stream- und Failure-History-Proofs abgesichert, sondern hat einen eigenen sichtbaren Contract, der gehostet gegen die echte Runtime verifiziert ist:

- `services/agent-api/app/main.py` fuehrt jetzt `session_history_contract_payload()` plus `GET /api/v1/sessions/history/contract` ein
- der neue sichtbare Session-History-Contract deklariert:
  - `contract_version=session-history-v1`
  - die top-level Sektionen des History-Response
  - die bindenden Session-/Task-/Audit-Event-Felder
  - die unterstuetzten Status sowie Request-/Trace-/Correlation-/Audit-Feed-Sichtbarkeit
- `scripts/verify-phase4-session-history-contract-runtime-hosted.ps1` erstellt auf dem echten Hetzner-Staging eine echte Prompt-Session via `POST /api/v1/prompt`, wartet auf Abschluss und prueft danach `GET /api/v1/sessions/history/contract`, `GET /api/v1/sessions/{session_id}/history`, `GET /api/v1/sessions/recent`, `GET /api/v1/tasks/recent`, `GET /api/v1/agent-activity/recent` und `GET /api/v1/audit/recent`
- `.phase1-artifacts/phase4-session-history-contract-runtime-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Session-History-Contract-zu-Runtime-Paritaet
- Verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-session-history-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `59%`, Phase 4 steigt auf `57%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Recent Sessions Contract Runtime Parity** — `sessions/recent` ist jetzt nicht mehr nur ueber Session-Stream-/Failure-/Cross-Surface-Beweise indirekt abgesichert, sondern hat einen eigenen sichtbaren Contract, der gehostet gegen die echte Runtime verifiziert ist:

- `services/agent-api/app/main.py` fuehrt jetzt `recent_sessions_contract_payload()` plus `GET /api/v1/sessions/recent/contract` ein
- der neue sichtbare Recent-Sessions-Contract deklariert:
  - `contract_version=recent-sessions-feed-v1`
  - die top-level Runtime-Felder von `GET /api/v1/sessions/recent`
  - die unterstuetzten Session-/Failure-Zustaende
  - die bindenden Request-/Trace-/Correlation-/Audit-Feed-Felder
- `scripts/verify-phase4-recent-sessions-contract-runtime-hosted.ps1` erstellt auf dem echten Hetzner-Staging eine echte Prompt-Session via `POST /api/v1/prompt`, wartet auf Abschluss und prueft danach `GET /api/v1/sessions/recent/contract`, `GET /api/v1/sessions/recent`, `GET /api/v1/sessions/{session_id}/history`, `GET /api/v1/tasks/recent`, `GET /api/v1/agent-activity/recent` und `GET /api/v1/audit/recent`
- `.phase1-artifacts/phase4-recent-sessions-contract-runtime-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Recent-Sessions-Contract-zu-Runtime-Paritaet
- Verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-recent-sessions-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt steigt auf `59%`, Phase 4 steigt auf `56%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Recent Tasks Contract Runtime Parity** — `tasks/recent` ist jetzt nicht mehr nur ueber Worker-/Cross-Surface-Beweise indirekt abgesichert, sondern hat einen eigenen sichtbaren Contract, der gehostet gegen die echte Runtime verifiziert ist:

- `services/agent-api/app/main.py` fuehrt jetzt `recent_tasks_contract_payload()` plus `GET /api/v1/tasks/recent/contract` ein
- der neue sichtbare Recent-Tasks-Contract deklariert:
  - `contract_version=recent-tasks-feed-v1`
  - die top-level Runtime-Felder von `GET /api/v1/tasks/recent`
  - Queue-Felder und unterstuetzte Status
  - die bindenden Request-/Trace-/Correlation-/Audit-Feed-Felder
- zusaetzlich wurde eine echte Runtime-Luecke korrigiert:
  - `POST /api/v1/internal/tasks` schreibt jetzt Trace-/Request-/Correlation-Metadaten in `agent_sessions`
  - `GET /api/v1/tasks/recent` faellt jetzt auch auf Session-Projektion zurueck, wenn frische Audit-Korrelation fuer den Task selbst noch nicht vorliegt
- `scripts/verify-phase4-recent-tasks-contract-runtime-hosted.ps1` erstellt auf dem echten Hetzner-Staging einen echten `planner`-Task via `POST /api/v1/internal/tasks`, wartet auf Abschluss und prueft danach `GET /api/v1/tasks/recent/contract`, `GET /api/v1/tasks/recent`, `GET /api/v1/internal/tasks/{task_id}` und `GET /api/v1/audit/recent`
- `.phase1-artifacts/phase4-recent-tasks-contract-runtime-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Recent-Tasks-Contract-zu-Runtime-Paritaet
- Verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-recent-tasks-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `58%`, Phase 4 steigt auf `55%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Escalation Contract Runtime Parity** — die Escalation-Surface ist jetzt nicht mehr nur ueber Request-/Audit-Paritaet indirekt abgesichert, sondern hat einen eigenen sichtbaren Contract, der gehostet gegen die echte Runtime verifiziert ist:

- `services/agent-api/app/main.py` fuehrt jetzt `escalation_contract_payload()` plus `GET /api/v1/escalations/contract` ein
- der neue sichtbare Escalation-Contract deklariert die top-level Runtime-Felder von `GET /api/v1/escalations/recent`, `supported_statuses=["escalated"]` und die bindenden Request-/Trace-/Correlation-/Audit-Feed-Felder
- `scripts/verify-phase4-escalation-contract-runtime-hosted.ps1` seedet auf dem echten Hetzner-Staging einen eskalierten `coder`-Pfad mit gemeinsamer `request_id`, `trace_id`, `correlation_evidence_ref=request_id_audit_correlation` und `audit_feed_evidence_ref=request_id_audit_feed_visible`
- derselbe Hosted-Proof prueft danach `GET /api/v1/escalations/contract`, `GET /api/v1/escalations/recent` und `GET /api/v1/audit/recent` und bestaetigt, dass Contract und Runtime fuer dieselbe Escalation-Surface auf denselben top-level Feldern und denselben Request-/Trace-Beweisen bleiben
- `.phase1-artifacts/phase4-escalation-contract-runtime-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Escalation-Contract-zu-Runtime-Paritaet
- Verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-escalation-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `58%`, Phase 4 steigt auf `54%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Audit Feed Evidence Cross-Surface Parity** — derselbe eskalierte Worker-Pfad bleibt jetzt gehostet nicht nur auf Task-, Session-, Activity-, Audit-, Agent-Status- und Escalation-Surfaces sichtbar, sondern traegt ueber alle diese Public-Surfaces auch dieselbe top-level `audit_feed_evidence_ref`:

- `scripts/verify-phase4-audit-feed-evidence-cross-surface-hosted.ps1` seedet auf dem echten Hetzner-Staging einen eskalierten `coder`-Pfad mit gemeinsamer `trace_id`, gemeinsamer `request_id`, `correlation_evidence_ref=request_id_audit_correlation` und `audit_feed_evidence_ref=request_id_audit_feed_visible`, prueft danach `GET /api/v1/escalations/recent`, `GET /api/v1/agents/status`, `GET /api/v1/agent-activity/recent`, `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent`, `GET /api/v1/sessions/{session_id}/history` und `GET /api/v1/audit/recent`
- derselbe Hosted-Proof bestaetigt fuer den eskalierten Pfad identische top-level `request_id`-, `trace_id`-, `correlation_evidence_ref`- und `audit_feed_evidence_ref`-Werte ueber alle sieben Public Surfaces
- `.phase1-artifacts/phase4-audit-feed-evidence-cross-surface-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Audit-Feed-Evidence-Cross-Surface-Paritaet
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-audit-feed-evidence-cross-surface-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`
- Fortschritt steigt evidenzbasiert: Gesamt steigt auf `58%`, Phase 4 steigt auf `49%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Escalation Request Correlation Parity** — dieselben negativen Worker-Endzustaende sind jetzt gehostet nicht nur auf Task-, Session-, Activity-, Audit- und Agent-Status-Surfaces, sondern auch auf `GET /api/v1/escalations/recent` mit identischer top-level Request-/Trace-Korrelation sichtbar:

- `services/agent-api/app/main.py` projiziert Korrelation jetzt auch auf die Escalation-Surface und liefert `request_id`, `trace_id`, `correlation_evidence_ref` und `audit_feed_evidence_ref` direkt auf `GET /api/v1/escalations/recent`
- `scripts/verify-phase4-escalation-request-correlation-hosted.ps1` seedet auf dem echten Hetzner-Staging einen eskalierten `coder`-Pfad mit gemeinsamer `trace_id`, gemeinsamer `request_id` und `correlation_evidence_ref=request_id_audit_correlation`, prueft danach `GET /api/v1/escalations/recent`, `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent`, `GET /api/v1/sessions/{session_id}/history` und `GET /api/v1/audit/recent`
- derselbe Hosted-Proof bestaetigt fuer den eskalierten Pfad identische top-level `trace_id`-, `request_id`- und `correlation_evidence_ref`-Werte jetzt auch auf der Escalation-Surface
- `.phase1-artifacts/phase4-escalation-request-correlation-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Escalation-Request-Correlation-Paritaet
- Verifiziert: `py -3 -m py_compile services/agent-api/app/main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-escalation-request-correlation-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `57%`, Phase 4 steigt auf `48%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Agent Status Request Correlation Parity** — dieselben negativen Worker-Endzustaende sind jetzt gehostet nicht nur auf Task-, Session-, Activity- und Audit-Surfaces, sondern auch auf `GET /api/v1/agents/status` mit identischer top-level Request-/Trace-Korrelation sichtbar:

- `services/agent-api/app/main.py` projiziert Korrelation jetzt auch auf die Agent-Status-Surface und liefert `latest_trace_id`, `latest_request_id`, `latest_correlation_evidence_ref` und `latest_audit_feed_evidence_ref` direkt auf `GET /api/v1/agents/status`
- `scripts/verify-phase4-agent-status-request-correlation-hosted.ps1` seedet auf dem echten Hetzner-Staging einen eskalierten `coder`-Pfad und einen `abandoned_after_queue_drain`-`tester`-Pfad mit gemeinsamer `trace_id`, gemeinsamer `request_id` und `correlation_evidence_ref=request_id_audit_correlation`, prueft danach `GET /api/v1/agents/status`, `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent`, `GET /api/v1/sessions/{session_id}/history` und `GET /api/v1/audit/recent`
- derselbe Hosted-Proof bestaetigt fuer beide negativen Pfade identische top-level `trace_id`-, `request_id`- und `correlation_evidence_ref`-Werte jetzt auch auf der Agent-Status-Surface
- `.phase1-artifacts/phase4-agent-status-request-correlation-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Agent-Status-Request-Correlation-Paritaet
- Verifiziert: `py -3 -m py_compile services/agent-api/app/main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-agent-status-request-correlation-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `57%`, Phase 4 steigt auf `47%`, Agent Pool steigt auf `66%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Request Correlation Cross-Surface Parity** — dieselben negativen Worker-Endzustaende sind jetzt gehostet nicht nur in Agent Activity und Audit sichtbar, sondern mit identischer `trace_id`-, `request_id`- und `correlation_evidence_ref`-Korrelation top-level quer ueber die oeffentlichen Task-, Session- und History-Surfaces bestaetigt:

- `services/agent-api/app/main.py` projiziert Korrelation jetzt direkt aus dem Audit Feed auf `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent`, `GET /api/v1/sessions/{session_id}/history` und zusaetzlich top-level auf `GET /api/v1/agent-activity/recent`, statt `request_id`/`trace_id` nur indirekt in nested audit details sichtbar zu lassen
- `scripts/verify-phase4-request-correlation-cross-surface-hosted.ps1` seedet auf dem echten Hetzner-Staging einen eskalierten `coder`-Pfad und einen `abandoned_after_queue_drain`-`tester`-Pfad mit gemeinsamer `trace_id`, gemeinsamer `request_id` und `correlation_evidence_ref=request_id_audit_correlation`, prueft danach `GET /api/v1/agent-activity/recent?trace_id=...`, `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent`, `GET /api/v1/sessions/{session_id}/history` und `GET /api/v1/audit/recent`
- derselbe Hosted-Proof bestaetigt fuer beide negativen Pfade identische top-level `trace_id`-, `request_id`- und `correlation_evidence_ref`-Werte ueber alle fuenf Public Surfaces
- `.phase1-artifacts/phase4-request-correlation-cross-surface-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Cross-Surface-Request-Correlation-Paritaet
- Verifiziert: `py -3 -m py_compile services/agent-api/app/main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-request-correlation-cross-surface-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `57%`, Phase 4 steigt auf `46%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Agent Activity Filter Parity** — dieselben negativen Worker-Endzustaende sind jetzt gehostet nicht nur sichtbar, sondern ueber die oeffentliche Agent-Activity-Surface auch reproduzierbar per `trace_id`, `agent_type`, `event_type` und `severity` isolierbar:

- `scripts/verify-phase4-agent-activity-filter-parity-hosted.ps1` seedet auf dem echten Hetzner-Staging einen eskalierten `coder`-Pfad und einen `abandoned_after_queue_drain`-`tester`-Pfad mit gemeinsamer `trace_id`, prueft danach `GET /api/v1/agent-activity/recent?trace_id=...`, dann die beiden engeren Multi-Filter-Kombinationen fuer `coder/task_escalated/warning` und `tester/task_abandoned_after_queue_drain/warning`, und spiegelt die Ergebnisse gegen `GET /api/v1/audit/recent`
- derselbe Hosted-Proof bestaetigt, dass jede Multi-Filter-Kombination genau das erwartete Failure-Ereignis isoliert und dabei `task_id`, `trace_id` und Retry-Metadaten mit dem Audit Feed synchron bleiben
- `.phase1-artifacts/phase4-agent-activity-filter-parity-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer die Filter-Paritaet der oeffentlichen Agent-Activity-Surface
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-agent-activity-filter-parity-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `57%`, Phase 4 steigt auf `45%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Trace + Request Correlation Parity** — dieselben negativen Worker-Endzustaende sind jetzt gehostet nicht nur als Failure-Surfaces sichtbar, sondern auch mit identischer `trace_id`- und `request_id`-Korrelation quer ueber Agent Activity, Audit Feed und Session-History-Audit belegt:

- `scripts/verify-phase4-trace-request-correlation-hosted.ps1` seedet auf dem echten Hetzner-Staging einen eskalierten `coder`-Pfad und einen `abandoned_after_queue_drain`-`tester`-Pfad mit gemeinsamer `trace_id`, gemeinsamer `request_id` und expliziter `correlation_evidence_ref=request_id_audit_correlation`, prueft danach `GET /api/v1/agent-activity/recent?trace_id=...`, `GET /api/v1/audit/recent`, `GET /api/v1/sessions/{session_id}/history` und `GET /api/v1/request/contract`
- derselbe Hosted-Proof bestaetigt fuer beide negativen Pfade identische `trace_id`- und `request_id`-Werte zwischen Agent Activity, Audit Feed und Session-History sowie die sichtbaren Evidence-Refs `request_id_audit_correlation` und `request_id_audit_feed_visible`
- `.phase1-artifacts/phase4-trace-request-correlation-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Trace-/Request-Correlation-Paritaet
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-trace-request-correlation-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `57%`, Phase 4 steigt auf `44%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Failure Audit + Escalation Parity** — dieselben negativen Worker-Endzustaende sind jetzt gehostet nicht nur ueber Runtime-Surfaces, sondern auch quer ueber Audit Feed, Escalation Feed und Session-History-Audit feldgenau synchron bestaetigt:

- `scripts/verify-phase4-failure-audit-escalation-parity-hosted.ps1` seedet auf dem echten Hetzner-Staging einen eskalierten `coder`-Pfad und einen `abandoned_after_queue_drain`-`tester`-Pfad und prueft danach `GET /api/v1/audit/recent`, `GET /api/v1/escalations/recent` und `GET /api/v1/sessions/{session_id}/history`
- dabei wurden zwei echte Verifier-Contractfehler bereinigt: die Feeds liefern `events` statt `entries`, und `escalations/recent` fuehrt `trace_id` nur in `details`; ausserdem wurde der Proof auf das echte Feed-Verhalten korrigiert, dass `escalations/recent` den eskalierten Pfad fuehrt, nicht den Queue-Drain-Abandon-Pfad
- `.phase1-artifacts/phase4-failure-audit-escalation-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Audit-/Escalation-Paritaet von `escalated` und Audit-/History-Paritaet von `abandoned_after_queue_drain`
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-failure-audit-escalation-parity-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `57%`, Phase 4 steigt auf `43%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Agent Status Cross-Surface Parity** — dieselben negativen Worker-Endzustaende sind jetzt gehostet nicht nur ueber `agents/status` einzeln sichtbar, sondern auch quer ueber Agent Status, Recent Tasks, Recent Sessions und Session-History feldgenau synchron bestaetigt:

- `scripts/verify-phase4-agent-status-cross-surface-hosted.ps1` seedet auf dem echten Hetzner-Staging einen eskalierten `coder`-Pfad und einen `abandoned_after_queue_drain`-`tester`-Pfad und prueft danach `GET /api/v1/agents/status`, `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent` und `GET /api/v1/sessions/{session_id}/history`
- derselbe Hosted-Proof bestaetigt ueber alle vier Public Surfaces dieselben `latest_task_id`-, `latest_status`-, Retry-, Fehler- und `current_session_id`-Fakten fuer die beiden negativen Worker-Endzustaende
- `.phase1-artifacts/phase4-agent-status-cross-surface-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Cross-Surface-Paritaet von `escalated` und `abandoned_after_queue_drain` aus Sicht der Agent-Status-Surface
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-agent-status-cross-surface-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt steigt auf `57%`, Phase 4 steigt auf `42%`, Agent Pool steigt auf `65%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Failure Cross-Surface Parity** — dieselben negativen Worker-Endzustaende sind jetzt gehostet nicht nur je Surface einzeln, sondern auch quer ueber Agent Activity, Recent Tasks, Recent Sessions und Session-History feldgenau synchron bestaetigt:

- `scripts/verify-phase4-failure-cross-surface-hosted.ps1` seedet auf dem echten Hetzner-Staging einen eskalierten `coder`-Pfad und einen `abandoned_after_queue_drain`-`tester`-Pfad mit gemeinsamem `trace_id`, prueft danach `GET /api/v1/agent-activity/recent`, `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent` und `GET /api/v1/sessions/{session_id}/history`, und bestaetigt dieselben `task_id`-, `task_status`-, Retry- und Fehlerfelder ueber alle vier oeffentlichen Surfaces
- der neue Verifier hatte zuerst einen echten Seed-Parser-Bug: der Remote-Seed lieferte zwei JSON-Zeilen und damit ein doppelt zusammengeklebtes `trace_id`; `scripts/verify-phase4-failure-cross-surface-hosted.ps1` parst jetzt nur noch die letzte JSON-Zeile und prueft danach sauber gegen die echte Hosted-Runtime
- `.phase1-artifacts/phase4-failure-cross-surface-hosted-proof-20260505.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Cross-Surface-Paritaet von `escalated` und `abandoned_after_queue_drain`
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-failure-cross-surface-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `56%`, Phase 4 steigt auf `41%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Agent Activity Contract Parity** — die oeffentliche Agent-Activity-Surface benennt dieselben Failure-Felder jetzt auch im sichtbaren Contract und bleibt zur gehosteten Runtime feldgenau synchron:

- `services/agent-api/app/main.py` erklaert in `agent_activity_contract_payload()` jetzt explizit `task_id`, `task_status`, `retry_count`, `max_retries` und `error` als oeffentliche Trace-Felder und fuehrt dazu `failure_surface_visible` plus `agent_activity_failure_surface_visible` im Contract
- `scripts/verify-phase4-agent-activity-contract-hosted.ps1` prueft auf dem echten Hetzner-Staging zuerst `GET /api/v1/agent-activity/contract`, dann seedet es denselben `coder`/`tester`-Fehlerpfad in die Hosted-Audit-Quelle und bestaetigt anschliessend ueber `GET /api/v1/agent-activity/recent?trace_id=...`, dass Contract und Runtime dieselben top-level Failure-Felder liefern
- `.phase1-artifacts/phase4-agent-activity-contract-hosted-proof-20260505.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Contract-/Runtime-Paritaet auf der oeffentlichen Agent-Activity-Surface

## Previous Latest Completed Proof

**Phase 4 Hosted Agent Activity Failure Surface Parity** — dieselben negativen Worker-Endzustaende sind jetzt auch ueber die oeffentliche Agent-Activity-Surface konsistent und feldgenau sichtbar:

- `services/agent-api/app/main.py` surfacet in `agent_activity_row_to_event()` jetzt top-level `task_id`, `task_status`, `retry_count`, `max_retries` und `error` statt dieselben Failure-Fakten nur in verschachtelten `details` zu belassen
- `scripts/verify-phase4-agent-activity-failure-hosted.ps1` seedet auf dem echten Hetzner-Staging einen `coder`-`task_escalated`-Auditpfad und einen `tester`-`task_abandoned_after_queue_drain`-Auditpfad mit gemeinsamem `trace_id`, liest danach `GET /api/v1/agent-activity/recent?trace_id=...` und bestaetigt dieselben `task_id`-Werte plus top-level `task_status`, Retry-Metadaten und Fehlertexte
- `.phase1-artifacts/phase4-agent-activity-failure-hosted-proof-20260505.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer oeffentliche Failure-Surfacing-Paritaet auf der Agent-Activity-Surface

## Previous Latest Completed Proof

**Phase 4 Hosted Agent Status Failure Surface Parity** — dieselben negativen Worker-Endzustaende sind jetzt auch ueber die oeffentlichen Agent-/Task-Surfaces konsistent und feldgenau sichtbar:

- `services/agent-api/app/main.py` behandelt `escalated` und `abandoned_after_queue_drain` in `GET /api/v1/agents/status` jetzt als sichtbare `error`-Zustaende und surfacet zusaetzlich `retries`, `latest_retry_count` und `latest_max_retries` aus dem echten letzten Task statt eines konstanten Nullwerts
- `scripts/verify-phase4-agent-status-failure-hosted.ps1` seedet auf dem echten Hetzner-Staging einen eskalierten `coder`-Task und einen `abandoned_after_queue_drain`-`tester`-Task direkt im echten Runtime-Store, prueft danach `GET /api/v1/agents/status`, `GET /api/v1/tasks/recent`, `GET /api/v1/audit/recent` und `GET /api/v1/health`, und bestaetigt `status=error`, `latest_status=escalated`, `latest_status=abandoned_after_queue_drain`, Retry-Zaehler sowie sichtbare Fehlertexte auf den oeffentlichen Surfaces
- `.phase1-artifacts/phase4-agent-status-failure-hosted-proof-20260505.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer oeffentliche Failure-Surfacing-Paritaet zwischen Agent-Status, Task-Recent und Audit
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-agent-status-failure-hosted.ps1`, `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `56%`, Phase 4 steigt auf `38%`, Agent Pool steigt auf `64%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 4 Hosted Session Failure History Parity** — dieselben negativen Worker-Zustaende sind jetzt auch ueber die oeffentlichen Session-Surfaces konsistent und feldgenau sichtbar:

- `services/agent-api/app/main.py` erweitert `GET /api/v1/sessions/recent` um `latest_task_status`, `latest_error`, `latest_retry_count` und `latest_max_retries`, sodass negative Worker-Endzustaende nicht nur ueber Task-/Audit-Interna, sondern auch ueber die oeffentliche Recent-Session-Surface sichtbar werden
- `scripts/verify-phase4-session-failure-history-hosted.ps1` seedet auf dem echten Hetzner-Staging gezielt zwei Session-basierte stale queued Pfade: einen Rehydrate-Pfad mit passendem `task_completed`-Audit und einen Abandon-Pfad ohne Queue-Match; danach prueft der Verifier `GET /api/v1/sessions/{session_id}/history`, `GET /api/v1/sessions/recent` und `GET /api/v1/audit/recent` inklusive `latest_task_status=completed`, `latest_task_status=abandoned_after_queue_drain`, sichtbarem `latest_error` und `latest_retry_count=0`
- `scripts/deploy-to-staging.ps1` erzwingt jetzt bei geaenderten bind mounts ein `--force-recreate` der gehosteten App-Services, damit kopierter Python-Code nicht mehr mit alten laufenden Prozessen verifiziert wird
- `.phase1-artifacts/phase4-session-failure-history-hosted-proof-20260505.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer `status=completed` via `task_status_rehydrated_from_audit`, `status=abandoned_after_queue_drain`, `worker_status_rehydrated_from_completed_audit`, `worker_stale_queued_finalized` und die neuen Recent-Session-Felder
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-session-failure-history-hosted.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `56%`, Phase 4 steigt auf `37%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 4 Hosted Worker Failure / Stale Queue Parity** — der gehostete Worker-Runtime-Pfad belegt jetzt auch echte Retry-/Escalation-/Stale-Queue-Transitionen statt nur den Happy Path:

- `scripts/verify-phase4-worker-failure-parity-hosted.ps1` seedet auf dem echten Hetzner-Staging gezielt Redis-/Postgres-Status fuer einen eskalierenden Worker-Task mit fehlender Session, einen stale queued Rehydrate-Pfad mit passendem Completed-Audit und einen stale queued Abandon-Pfad ohne Queue-Match; danach prueft der Verifier `GET /api/v1/internal/tasks/{task_id}`, `GET /api/v1/tasks/recent`, `GET /api/v1/audit/recent`, `GET /api/v1/escalations/recent`, `GET /api/v1/metrics` und `GET /api/v1/health`
- `.phase1-artifacts/phase4-worker-failure-parity-hosted-proof-20260505.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer `task_retry`, `task_failed`, `task_escalated`, `task_status_rehydrated_from_audit`, `task_abandoned_after_queue_drain`, `worker_status_rehydrated_from_completed_audit` und `worker_stale_queued_finalized`
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-worker-failure-parity-hosted.ps1`, `py -3 -m py_compile services\agent-api\app\main.py`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt steigt auf `56%`, Phase 4 steigt auf `35%`, Agent Pool steigt auf `63%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 4 Hosted Orchestrator Stream / Checkpoint Replay Parity** — der gehostete LangGraph-Runtime-Pfad belegt jetzt auch die echte Orchestrator-Stream-/Replay-/Checkpoint-Integration statt nur Dry-Run-JSON:

**Vorheriger Abschluss — Phase 4 Hosted Session History / SSE Replay Parity** — der gehostete Runtime-Pfad belegt jetzt auch die echte Session-History-/Stream-/Replay-Integration statt nur Contracts:

- `scripts/verify-phase4-session-stream-history-hosted.ps1` erzeugt eine echte gehostete Prompt-Session ueber `POST /api/v1/prompt`, wartet auf die abgeschlossene deterministische Worker-Antwort ueber `GET /api/v1/sessions/{session_id}/history`, prueft dann den Live-Stream `GET /api/v1/session/{session_id}/stream` auf `heartbeat`, `agent_status`, `token` und `done` und prueft denselben Pfad erneut mit `Last-Event-ID: 0` auf sichtbares Replay mit `replay=true`
- `.phase1-artifacts/phase4-session-stream-history-hosted-proof-20260505.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Session-History, Recent-Sessions, Live-SSE, Replay-SSE und die dazu passenden Audit-Eintraege
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-session-stream-history-hosted.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `55%`, Phase 4 steigt auf `33%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 4 Hosted Session / Memory Worker Runtime Parity** — der gehostete Runtime-Pfad belegt jetzt auch die echte Session-/History-/Memory-Integration statt nur Contracts:

- `scripts/verify-phase4-session-memory-parity-hosted.ps1` erzeugt eine echte gehostete Prompt-Session ueber `POST /api/v1/prompt`, wartet auf die abgeschlossene deterministische Worker-Antwort ueber `GET /api/v1/sessions/{session_id}/history`, prueft `GET /api/v1/sessions/recent`, seedet danach per SSH einen echten `memory:working:*`-Eintrag auf dem Hetzner-Host, laesst `memory-worker --once` laufen und prueft schliesslich `GET /api/v1/memory/search`, `GET /api/v1/memory/consolidation/recent` und `GET /api/v1/metrics`
- `.phase1-artifacts/phase4-session-memory-parity-hosted-proof-20260505.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Session-History, Recent-Sessions, echte Redis-zu-Postgres-Consolidation, oeffentliche Memory-Suche, Consolidation-Audit und Memory-Metriken
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-session-memory-parity-hosted.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `55%`, Phase 4 steigt auf `32%`, Memory steigt auf `71%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 4 Hosted Worker / Priority Queue Runtime Parity** — der gehostete Runtime-Pfad belegt jetzt auch die echte Worker-/Queue-Integration statt nur Contracts:

- `scripts/verify-phase4-worker-priority-runtime-hosted.ps1` legt vier echte gehostete interne Aufgaben fuer `planner`, `coder`, `tester` und `devops` mit Prioritaeten `9`, `5`, `2` und `8` an, prueft `GET /api/v1/tasks/assignment-contract`, `POST /api/v1/internal/tasks`, `GET /api/v1/internal/tasks/{task_id}`, `GET /api/v1/tasks/recent`, `GET /api/v1/agents/status`, `GET /api/v1/sessions/recent`, `GET /api/v1/metrics` und `GET /api/v1/audit/recent`
- dabei wurde ein echter Runtime-Bug behoben: `POST /api/v1/internal/tasks` erzeugte vorher keine `agent_sessions`-Zeile, wodurch der Worker in `ForeignKeyViolation` und `status=escalated` lief; `services/agent-api/app/main.py` initialisiert jetzt die Session vor dem Queue-Intake und schreibt `latest_task_id/latest_task_type` in die Session-Metadaten
- `.phase1-artifacts/phase4-worker-priority-queue-hosted-proof-20260505.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Queue-Prioritaet, Worker-Lifecycle, Session-Sichtbarkeit, Audit und Metrics
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-worker-priority-runtime-hosted.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 -m py_compile services\agent-api\app\main.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `55%`, Phase 4 steigt auf `31%`, Agent Pool steigt auf `62%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Phase 5 Post-Rollback Provenance + Completion Gate Freeze** — der aktuelle Production-Candidate ist jetzt nach rollback/restore nicht nur requalifiziert und browser-/observability-seitig frisch bestätigt, sondern auch nochmals explizit an Workflow/GHCR-Herkunft und an die weiterhin fail-closed Completion-Grenze gebunden:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-provenance-revalidation.md` bindet den Candidate an die weiterhin erfolgreiche GitHub-Workflow-Herkunft `25392582005`, an denselben Commit `ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`, an die weiter verfuegbaren immutable GHCR-Tag-Saetze fuer alle sechs Services und an die bestätigte Multi-Arch-Verwendbarkeit fuer Hetzner `arm64`; der Proof bestaetigt dazu Hosted Root/API/MCP/LLM weiter gruen sowie `overall=55`, `phase5=28`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-completion-gate-freeze.md` bindet denselben Candidate an den nach Rollback/Restore weiter fail-closed bleibenden Completion-Contract: External Gates bleiben `verified`, `blocked_release_gates=[]`, aber `can_set_all_to_100=false` und `owner_decision=no-release` bleiben hart aktiv
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt jetzt `post_rollback_provenance_revalidation_proof` und `post_rollback_completion_gate_freeze_proof` explizit als weitere Candidate-Evidence
- `scripts/verify-phase5-post-rollback-provenance-revalidation.ps1` und `scripts/verify-phase5-post-rollback-completion-gate-freeze.ps1` pruefen Artefaktstruktur, Candidate-Links, GitHub-Workflow-Herkunft, GHCR-Manifest-Architekturen, Hosted-Endpunkte, External Gates und Completion fail-closed
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-post-rollback-provenance-revalidation.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-post-rollback-completion-gate-freeze.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `55%`, Phase 5 steigt auf `28%`; dies sind zwei weitere Release-Readiness-/Operations-Proofs, aber weiterhin kein Rollout und kein Production-Deploy

**Historischer, jetzt superseded Browser-Abschnitt — Phase 5 Post-Rollback Observability + Browser Revalidation** — der Browser-Teil dieses alten Claims ist nicht mehr Teil des aktuellen Candidate-Truth:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-observability-revalidation.md` bindet den Candidate an eine neue gehostete Nachpruefung von `health`, `project/progress`, `project/progress/integrity`, `metrics`, `audit/recent`, `escalations/recent` und `external-gates`; der Proof bestaetigt `overall=55`, `phase5=26`, `status=verified` und weiter `no-release`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-browser-revalidation.md` ist jetzt als historisches, superseded Artefakt markiert; ein frischer Browser-Rerun ist aktuell extern blockiert und wird nicht mehr als aktuelle Candidate-Evidence gefuehrt
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt nur noch `post_rollback_observability_revalidation_proof` als aktive Candidate-Evidence; der Browser-Teil ist explizit aus dem aktuellen Truth entfernt
- `scripts/verify-phase5-post-rollback-observability-revalidation.ps1` bleibt auf aktueller Hosted-Truth, `scripts/verify-phase5-post-rollback-browser-revalidation.ps1` prueft jetzt fail-closed den historischen Blockerzustand
- der Browser-Blocker ist durch `failed to start codex app-server`, `Target.setDiscoverTargets): Target closed` und Playwright `exit code 13` konkret belegt
- die historische Fortschrittslinie dieses alten Abschnitts bleibt nur Dokumentationskontext und ist nicht der aktuelle Manifest-Truth

**Phase 5 Post-Rollback Stability + Refusal Proofs** — der aktuelle Production-Candidate ist jetzt nach rollback/restore nicht nur unmittelbar requalifiziert, sondern auch im Nachlauf stabil gehalten und erneut hart auf `no-release` fixiert:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-stability-watch.md` bindet den Candidate an einen kurzen gehosteten Nachlauf nach dem echten immutable rollback/restore Lauf; zwei aufeinanderfolgende Progress-/Integrity-Reads bleiben bei `overall=54`, `phase5=24` und `status=verified`, Completion bleibt fail-closed und External Gates bleiben `verified`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-promotion-gate-refusal.md` fixiert denselben neuesten Zustand nochmals explizit als nicht promotable: `owner_decision=no-release`, kein `prod-release-*` Artefakt, Completion weiter `can_set_all_to_100=false`, Hosted Progress `overall=54`, `phase5=24`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt jetzt `post_rollback_stability_watch_proof` und `post_rollback_promotion_gate_refusal_proof` explizit als Candidate-Evidence
- `scripts/verify-phase5-post-rollback-stability-watch.ps1` und `scripts/verify-phase5-post-rollback-promotion-gate-refusal.ps1` pruefen Artefaktstruktur, Candidate-Links, Hosted-Endpunkte, Hosted-Progress/Integrity/Completion sowie die weiter harte `no-release`-/No-Production-Truth
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-post-rollback-stability-watch.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-post-rollback-promotion-gate-refusal.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `54%`, Phase 5 steigt auf `24%`; dies sind zwei weitere Release-Readiness-/Operations-Proofs, aber weiterhin kein Rollout und kein Production-Deploy

**Phase 5 Post-Rollback Requalification Proof** — der aktuelle Production-Candidate ist jetzt nach dem echten immutable rollback/restore Lauf nochmals hosted requalifiziert:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-requalification.md` bindet den Candidate an den gehosteten Requalifikationslauf nach dem executed rollback proof
- der Proof bestaetigt `IMAGE_TAG=staging` nach Restore, Hosted Root/API/MCP/LLM `200`, hosted Progress weiterhin manifest-backed, Integrity `verified`, External Gates `verified` und Completion weiter fail-closed
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt den neuen `post_rollback_requalification_proof`-Eintrag jetzt explizit als Candidate-Evidence
- `scripts/verify-phase5-post-rollback-requalification.ps1` prueft Artefaktstruktur, Candidate-Link, remote `.env`, Hosted-Endpunkte, Hosted-Progress `overall=54`, `phase5=22`, Integrity `verified` und External Gates fail-closed
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-post-rollback-requalification.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`
- Historischer Fortschrittspunkt: dieser Proof hob Phase 5 zuvor auf `22%`; current verified progress remains defined by the manifest-backed totals above

**Phase 5 Executed Candidate Risk Review** — der aktuelle Production-Candidate hat jetzt auch den expliziten Risk-/Open-Questions-Review als eigenen Proof:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-risk-review.md` bindet den Candidate an einen ausgefuehrten Risk-Review fuer offene Fragen, erklaerte Blocker, Completion-Guard, External-Gate-Wahrheit sowie Audit-/Escalation-Sichtbarkeit bei weiter bindendem `no-release`
- `scripts/verify-phase5-risk-review.ps1` prueft Artefaktstruktur, Candidate-Link, Hosted-Progress `overall=53`, `phase5=18`, Hosted-Integrity `verified`, Completion `can_set_all_to_100=false`, External Gates `verified` sowie Audit-/Escalation-Feeds fail-closed
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt den neuen `risk_review_proof` jetzt explizit als Candidate-Evidence
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-risk-review.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `53%`, Phase 5 steigt auf `18%`; dies ist ein weiterer Release-Readiness-/Operations-Proof, aber weiterhin kein Rollout und kein Production-Deploy

**Phase 5 Executed Candidate Handoff Packet** — der aktuelle Production-Candidate hat jetzt auch den Release-Communication-/Operator-Handoff-Satz als eigenen Proof:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-handoff-packet.md` bindet den Candidate an einen ausgefuehrten Packet-Satz aus `AI_HANDOFF.md`, `PROJECT_STATE.md`, `docs/verification-register.md`, `docs/project-progress.manifest.json`, Candidate-Artefakt, Rollback-Drill und `no-release`-Owner-Decision
- `scripts/verify-phase5-handoff-packet.ps1` prueft Artefaktstruktur, Candidate-Link, die Spiegel `AI_HANDOFF.md` und `PROJECT_STATE.md`, den Verification Register, gehostete Runtime-Truth `overall=53`, `phase5=17` und Integrity `verified` fail-closed
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt den neuen `handoff_packet_proof` jetzt explizit als Candidate-Evidence
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-handoff-packet.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `53%`, Phase 5 steigt auf `17%`; dies ist ein weiterer Release-Readiness-/Operations-Proof, aber weiterhin kein Rollout und kein Production-Deploy

**Phase 5 Executed Candidate Memory Recovery Drill** — der aktuelle Production-Candidate hat jetzt auch den Memory-Recovery-Entscheidungspfad als eigenen Operations-Proof:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-memory-recovery-drill.md` bindet den Candidate an einen ausgefuehrten candidate-spezifischen Memory-Recovery-Drill fuer Search-, Purge-, Job-Status- und Consolidation-Surfaces bei weiter gueltigem `no-release`
- `scripts/verify-phase5-memory-recovery-drill.ps1` prueft Artefaktstruktur, Candidate-Link, `api/v1/health`, gehostete Runtime-Truth `overall=53`, `phase5=16`, Integrity `verified`, `memory/embedding-consistency/contract`, `memory/purge/contract`, `memory/purge/jobs/{job_id}`, `memory/consolidation/recent` und Audit-Feed fail-closed
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt den neuen `memory_recovery_drill_proof` jetzt explizit als Candidate-Evidence
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-memory-recovery-drill.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `53%`, Phase 5 steigt auf `16%`; dies ist ein weiterer Release-Readiness-/Operations-Proof, aber weiterhin kein Rollout und kein Production-Deploy

**Phase 5 Executed Candidate Provider Failover Drill** — der aktuelle Production-Candidate hat jetzt auch den Provider-Failover-Entscheidungspfad als eigenen Operations-Proof:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-provider-failover-drill.md` bindet den Candidate an einen ausgefuehrten candidate-spezifischen Failover-Drill fuer den LLM-Gateway-Routing-Scope, ohne Live-Provider-Umschaltung und bei weiter gueltigem `no-release`
- `scripts/verify-phase5-provider-failover-drill.ps1` prueft Artefaktstruktur, Candidate-Link, `llm/api/v1/health`, `api/v1/health`, gehostete Runtime-Truth `overall=53`, `phase5=15`, Integrity `verified`, External Gates `verified`, Deployment Preflight `verified` und Audit-Feed `200` fail-closed
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt den neuen `provider_failover_drill_proof` jetzt explizit als Candidate-Evidence
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-provider-failover-drill.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `53%`, Phase 5 steigt auf `15%`; dies ist ein weiterer Release-Readiness-/Operations-Proof, aber weiterhin kein Rollout und kein Production-Deploy

**Phase 5 Executed Candidate Secret Rotation Drill** — der aktuelle Production-Candidate hat jetzt auch den Secret-Rotation-Pfad als eigenen Operations-Proof:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-secret-rotation-drill.md` bindet den Candidate an einen ausgefuehrten candidate-spezifischen Secret-Rotation-Drill mit klarer Trennung zwischen Secret-Store und Git, weiter gueltigem `no-release` und hosted Re-Checks fuer Health, Progress, Integrity, External Gates und Deployment Preflight
- `scripts/verify-phase5-secret-rotation-drill.ps1` prueft Artefaktstruktur, Candidate-Link, gehostete Runtime-Truth `overall=53`, `phase5=14`, Integrity `verified`, External Gates `verified` und Deployment Preflight `verified` fail-closed
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt den neuen `secret_rotation_drill_proof` jetzt explizit als Candidate-Evidence
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-secret-rotation-drill.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `53%`, Phase 5 steigt auf `14%`; dies ist ein weiterer Release-Readiness-/Operations-Proof, aber weiterhin kein Rollout und kein Production-Deploy

**Historischer, jetzt superseded Browser-Abschnitt — Phase 5 Executed Hosted Candidate Browser Proof** — dieser Browser-Claim ist nicht mehr Teil des aktuellen Candidate-Truth:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md` ist jetzt als historisches, superseded Artefakt markiert; frische In-App-Browser-Evidence ist aktuell extern blockiert
- `scripts/verify-phase5-browser-proof.ps1` prueft jetzt fail-closed den historischen Blockerzustand statt einen nicht reproduzierbaren aktuellen Browser-Claim
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt keinen aktiven `browser_proof`-Eintrag mehr als Candidate-Evidence
- die aktuelle harte Blocker-Evidence lautet `failed to start codex app-server`, `Target.setDiscoverTargets): Target closed` und Playwright `exit code 13`
- die historische Fortschrittslinie dieses alten Abschnitts bleibt nur Dokumentationskontext und ist nicht der aktuelle Manifest-Truth

**Phase 5 Candidate Observability Review Proof** — der aktuelle Production-Candidate hat jetzt auch die gehostete Observability-Sichtung als eigenen Release-Readiness-Proof:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-observability-review.md` bindet den Candidate an die wirklich ausgefuehrte Sichtung von Hosted-Health, Progress, Progress-Integrity, Metrics, Audit-Feed, Escalation-Feed und External Gates
- `scripts/verify-phase5-observability-review.ps1` prueft Artefaktstruktur, Candidate-Link und die live gehosteten Observability-Endpunkte fail-closed
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt den neuen `observability_review_proof` jetzt explizit als Candidate-Evidence
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-observability-review.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt steigt auf `53%`, Phase 5 steigt auf `12%`; dies ist ein weiterer Release-Readiness-Proof, aber weiterhin kein Rollout und kein Production-Deploy

**Phase 5 Executed Candidate Incident Drill** — der aktuelle Production-Candidate hat jetzt auch den dokumentierten Stoerungs- und Eskalationspfad als eigenen Operations-Proof:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-incident-drill.md` bindet den Candidate an einen ausgefuehrten Incident-/Escalation-Drill fuer den Fall eines unhealthy production-candidate, inklusive Incident-Klassifikation `runtime`, Evidence-Capture, Rollback-Entscheidungspfad und weiter gueltigem `no-release`
- `scripts/verify-phase5-incident-drill.ps1` prueft Artefaktstruktur, Candidate-Link, Hosted-Health, Progress-Integrity, Metrics, Audit-Feed, Escalation-Feed, External Gates und Deployment Preflight fail-closed
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt den neuen `incident_drill_proof` jetzt explizit als Candidate-Evidence
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-incident-drill.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-rollback-drill.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `52%`, Phase 5 steigt auf `11%`; dies ist ein neuer Release-Readiness-/Operations-Proof, aber weiterhin kein Rollout und kein Production-Deploy

**Phase 5 Executed Hosted Candidate Smoke Proof** — der aktuelle Production-Candidate hat jetzt nicht nur Plan und Rollback-Drill, sondern auch einen ausgefuehrten, dokumentierten Hosted-Smoke-Run:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-smoke-proof.md` bindet den aktuellen Candidate an den wirklich ausgefuehrten Hosted-Smoke-Pfad fuer `/`, `/api/v1/health`, `/mcp/api/v1/health`, `/llm/api/v1/health`, `/api/v1/project/progress`, `/api/v1/project/progress/integrity`, `/api/v1/project/progress/completion`, `/api/v1/external-gates`, `/api/v1/external-gates/mirror` und `/api/v1/clouds/deployment-preflight/contract`
- `scripts/verify-phase5-executed-smoke.ps1` prueft Artefaktstruktur, Candidate-Link, Hosted-Root-Titel `Cloud Superbrain`, alle vier Hosted-Health-Pfade, Progress `overall=52`, `phase4=30`, `phase5=10`, Integrity `verified`, External Gates `verified`, External Gate Mirror `verified`, Deployment Preflight `verified` und Completion `can_set_all_to_100=false`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt den neuen `executed_smoke_proof` jetzt explizit als Candidate-Evidence
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-executed-smoke.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-rollback-drill.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `52%`, Phase 5 steigt auf `10%`; dies ist ein neuer Release-Readiness-Proof, aber weiterhin kein Rollout und kein Production-Deploy

**Phase 4 Hosted Cloud Surface + Gate Mirror Parity Proof** — die gehosteten Cloud-/Gate-Oberflaechen sind jetzt ebenfalls als eigener HTTPS-Hardening-Slice wiederholbar belegt:

- `scripts/verify-phase4-cloud-surfaces-hosted.ps1` prueft auf echtem Hosted HTTPS Staging die sichtbaren Root-Panels `Cloud Inventory`, `Cloud 7-Layer Readiness`, `Cloud Render Offload`, `Cloud Deployment Preflight` und `External Gate Mirror` sowie `GET /api/v1/clouds`, `GET /api/v1/clouds/layers`, `GET /api/v1/clouds/render-offload/contract`, `GET /api/v1/clouds/deployment-preflight/contract`, `GET /api/v1/external-gates`, `GET /api/v1/external-gates/mirror` und `GET /api/v1/project/progress/completion`
- der Proof deckt `cloud-provider-inventory-v1`, `cloud_layer_readiness_visible`, `cloud_render_offload_contract_visible`, `cloud_deployment_preflight_visible`, `external_gate_mirror_proof`, die freigeschalteten claim flags sowie die weiterhin lokale Blockade von `can_set_all_to_100=false` trotz geschlossener externer Gates ab
- Artefakt `.phase1-artifacts/phase4-cloud-surfaces-hosted-proof-20260505.md` bindet den wiederholbaren HTTPS-Proof an den exakten Verifier-Befehl
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-cloud-surfaces-hosted.ps1 -BaseUrl <hosted-staging-url>`, `py -3 scripts\verify_project_progress_manifest.py`, direkte Hosted-Progress-/Integrity-Pruefung nach dem Sync
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `52%`, Phase 4 steigt auf `30%`; dies ist ein neuer dedizierter Hosted-Integration-&-Hardening-Proof, aber weiterhin kein Production-Deploy

**Phase 5 Candidate Integration Plan Proof** — der aktuelle Production-Candidate hat jetzt auch den zuvor offenen candidate-spezifischen Integrations-/Smoke-Plan als eigenes Release-Artefakt:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-plan.md` beschreibt die geordnete Hosted-Smoke-Sequenz, die erwarteten Outcomes, Failure-Handling und Non-Claims fuer den aktuellen Candidate
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt `Integration plan documented` jetzt explizit als geschlossen und verlinkt den Integrationsplan
- `scripts/verify-phase5-integration-plan.ps1` prueft den neuen Candidate-Plan fail-closed gegen Artefaktstruktur und Link im Candidate-Artefakt
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-integration-plan.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `52%`, Phase 5 steigt auf `9%`; dies ist ein weiterer Release-Readiness-Proof, aber weiterhin kein Rollout und kein Production-Deploy

**Phase 4 Hosted Public Dashboard + Observability Truth Proofs** — die gehosteten oeffentlichen Dashboard-/Session-Stream-Surfaces und die gehostete Runtime-/Telemetrie-Wahrheit sind jetzt ebenfalls als eigene HTTPS-Hardening-Slices wiederholbar belegt:

- `scripts/verify-phase4-public-dashboard-hosted.ps1` prueft auf echtem Hosted HTTPS Staging die sichtbare Root-Oberflaeche, `GET /api/v1/project/progress`, `GET /api/v1/project/progress/integrity`, `GET /api/v1/project/progress/completion`, `GET /api/v1/layer-interfaces/contract`, `GET /api/v1/tasks/assignment-contract`, `GET /api/v1/agents/llm-streaming-contract`, den echten `POST /api/v1/prompt`-Pfad, `GET /api/v1/tasks/recent`, `GET|POST /api/v1/tasks/policy*`, `GET /api/v1/agents/status`, `GET /api/v1/agents/profiles`, `GET /api/v1/sessions/recent`, `GET /api/v1/audit/recent`, `GET /api/v1/escalations/recent` sowie Session-SSE und Replay
- `scripts/verify-phase4-observability-hosted.ps1` prueft auf echtem Hosted HTTPS Staging `GET /api/v1/project/progress/integrity`, `GET /api/v1/agent-activity/contract`, `GET /api/v1/agent-activity/recent`, `GET /api/v1/audit/recent` und `GET /api/v1/metrics` als eigenen Observability-/Runtime-Truth-Block
- die Proofs decken manifestgebundene Progress-Wahrheit, fail-closed Completion-Guards, oeffentliche Task-/Policy-/Profile-/Session-Paritaet, deterministische Session-SSE-Replays, Agent-Activity-Filtered-Feed, Audit-/Request-Korrelation und die hosted Prometheus-Metriken fuer Budget, Progress, Queue, Services, MCP-Ereignisse, Memory-Consolidation und Checkpoint-Tabellen ab
- Artefakte `.phase1-artifacts/phase4-public-dashboard-hosted-proof-20260505.md` und `.phase1-artifacts/phase4-observability-hosted-proof-20260505.md` binden die wiederholbaren HTTPS-Proofs an die exakten Verifier-Befehle
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-public-dashboard-hosted.ps1 -BaseUrl <hosted-staging-url>`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-observability-hosted.ps1 -BaseUrl <hosted-staging-url>`, `py -3 scripts\verify_project_progress_manifest.py`, direkte Hosted-Progress-/Integrity-Pruefung nach dem Sync
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `52%`, Phase 4 steigt auf `29%`; dies sind zwei neue dedizierte Hosted-Integration-&-Hardening-Proofs, aber weiterhin kein Production-Deploy

**Phase 4 Hosted MCP Safe Envelope + DevOps Dispatch Proof** — die gehosteten MCP-Werkzeuggrenzen und das fail-closed DevOps-Dispatch-Gate sind jetzt ebenfalls als eigener HTTPS-Hardening-Slice wiederholbar belegt:

- `scripts/verify-phase4-mcp-devops-hosted.ps1` extrahiert den MCP-Safe-Envelope- und DevOps-Dispatch-Abschnitt aus dem Monolith-Verifier und prueft auf echtem Hosted HTTPS Staging `GET /mcp/api/v1/health`, die sichtbaren MCP-Contracts fuer GitHub/PostgreSQL/Filesystem/Playwright/E2B/Version-Pinning, die dry-run/blocked/degraded Pfade von `POST /mcp/api/v1/tools/execute`, `GET /api/v1/audit/mcp`, `GET /api/v1/devops/workflow-dispatch/plan`, `POST /api/v1/devops/workflow-dispatch/validate` und die korrespondierenden Audit-Ereignisse in `GET /api/v1/audit/recent`
- der Proof deckt `status=timeout`, `status=blocked`, `status=degraded`, GitHub-Branch/PR-Dry-Run, PostgreSQL-Readonly-Plan, Filesystem-Workspace-Plan, Playwright-Browser-Proof-Plan, E2B-Lifecycle-Plan, deren jeweilige Policy-Blocks, persistierte Audit-Spuren sowie das fail-closed Dispatch-Gate fuer `production workflow dispatch requires human_review_approved=true` ab
- Artefakt `.phase1-artifacts/phase4-mcp-devops-hosted-proof-20260505.md` bindet den wiederholbaren HTTPS-Proof an den exakten Verifier-Befehl
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-mcp-devops-hosted.ps1 -BaseUrl <hosted-staging-url>`, `py -3 scripts\verify_project_progress_manifest.py`, direkte Hosted-Progress-/Integrity-Pruefung nach dem Sync
- Fortschritt steigt evidenzbasiert: Gesamt geht auf `52%`, Phase 4 steigt auf `27%`, MCP Gateway auf `54%`; dies ist ein neuer dedizierter Hosted-Integration-&-Hardening-Proof, aber weiterhin kein Production-Deploy

**Phase 4 Hosted Orchestrator Fail-Closed + SSE Replay Proof** — die negativen LangGraph-/SSE-Pfade sind jetzt ebenfalls als eigener gehosteter HTTPS-Hardening-Slice wiederholbar belegt:

- `scripts/verify-phase4-orchestrator-failclosed-hosted.ps1` extrahiert den Hard-Stop-/Retry-/Replay-Abschnitt aus dem Monolith-Verifier und prueft auf echtem Hosted HTTPS Staging Policy/Budget-Hard-Stops, den globalen Retry-Cap, node-bounded failures fuer `intent_parser`, `budget_guard`, `task_router`, `agent_executor`, `result_aggregator` und `memory_updater`, den LLM-Routing-Policy-Deny-Pfad sowie den SSE-/Replay-/Error-Contract
- der Proof deckt `hard_stop_reason=policy_or_budget_guard_rejected`, `global_retry_limit_reached`, `${node}_retry_limit_reached`, `llm_routing_policy_rejected`, `phase2-sse-event-contract-v1`, `phase2_sse_event_contract_proof`, `replay=true`, den terminalen Error-Probe `force_phase2_sse_error_event` und `live_provider_calls=false` auf Hosted HTTPS ab
- Artefakt `.phase1-artifacts/phase4-orchestrator-failclosed-hosted-proof-20260505.md` bindet den wiederholbaren HTTPS-Proof an den exakten Verifier-Befehl
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-orchestrator-failclosed-hosted.ps1 -BaseUrl <hosted-staging-url>`, `py -3 scripts\verify_project_progress_manifest.py`, direkte Hosted-Progress-/Integrity-Pruefung nach dem Sync
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `51%`, Phase 4 steigt auf `26%`; dies ist ein neuer dedizierter Hosted-Integration-&-Hardening-Proof, aber weiterhin kein Production-Deploy

**Phase 4 Hosted Orchestrator Runtime Parity Proof** — der LangGraph-/Phase-2-Runtime-Pfad ist jetzt auch als eigener gehosteter HTTPS-Hardening-Slice wiederholbar belegt:

- `scripts/verify-phase4-orchestrator-runtime-hosted.ps1` extrahiert den orchestrierten Runtime-Parity-Pfad aus dem Monolith-Verifier und prueft auf echtem Hosted HTTPS Staging `GET /api/v1/orchestrator/manifest`, `POST /api/v1/orchestrator/dry-run`, `GET /api/v1/orchestrator/checkpoints/{thread_id}`, `GET /api/v1/audit/recent`, `GET /api/v1/audit/mcp`, `GET /api/v1/memory/search`, `GET /api/v1/tasks/recent`, `GET /api/v1/phase2/runtime/contract`, `POST /api/v1/phase2/runtime/start`, `GET /api/v1/phase2/runtime/runs` und `GET /api/v1/agent-activity/recent?event_type=phase2_runtime_graph_started`
- der Proof deckt LangGraph `engine=langgraph`, `checkpointing=postgres`, `live_provider_calls=false`, den vier-Rollen-Agentenlauf mit high-priority Planner/DevOps, MCP-Readonly-Plan fuer PostgreSQL, `stream_done_seen=true`, `allow_primary`-Routing, Audit-/MCP-Audit-Korrelation, Memory-Update-Persistenz sowie die gehostete Phase-2-Runtime-Paritaet mit `live_mcp_writes=false`, `production_deploy=false`, per-role Aggregation und Run-Status-Sichtbarkeit ab
- Artefakt `.phase1-artifacts/phase4-orchestrator-runtime-hosted-proof-20260505.md` bindet den wiederholbaren HTTPS-Proof an den exakten Verifier-Befehl
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-orchestrator-runtime-hosted.ps1 -BaseUrl <hosted-staging-url>`, `py -3 scripts\verify_project_progress_manifest.py`, direkte Hosted-Progress-/Integrity-Pruefung nach dem Sync
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `51%`, Phase 4 steigt auf `25%`; dies ist ein neuer dedizierter Hosted-Integration-&-Hardening-Proof, aber weiterhin kein Production-Deploy

**Phase 3 Repeatable Browser Surface Proof** — der vorhandene Product-Surface-&-Security-Satz ist jetzt nicht nur runtime-/hosted-seitig, sondern auch lokal als wiederholbarer Browser-/API-Harness sichtbar:

- `scripts/verify-browser-contract.ps1` deckt jetzt lokal die bereits ausgelieferten P3-Panels und Contract-Endpunkte fuer `Memory Purge Contract`, `Cost Monitor CSV Export`, `Rate Limit Guard`, `Session Limit Guard`, `Error Response Contract`, `Security Headers Contract`, `Trace ID Contract`, `Cache Control Contract`, `Request ID Contract` und `Agent Activity` mit ab
- `.phase1-artifacts/phase3-browser-surface-proof-20260505.md` bindet den wiederholbaren lokalen Browser-Proof an den exakten Verifier-Befehl
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt minimal evidenzbasiert: Gesamt bleibt `50%`, Phase 3 steigt auf `34%`; dies ist lokaler Browser-/API-Repeatability-Proof fuer vorhandene P3-Surfaces, aber kein neuer Hosted-/Production-Claim

**Phase 5 Owner Decision + P3 Browser Proof Hardening** — der erste Candidate ist jetzt explizit auf `no-release` gestellt, und die bereits sichtbaren P3-Vertraege werden nun auch vom lokalen Browser-Harness fail-closed mitbelegt:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt `owner_decision_proof`, `review_gate=reviewed` und `owner_decision=no-release`; `.phase1-artifacts/phase5-owner-decision-no-release-20260505.md` dokumentiert die Begruendung bei unveraendertem `overall=50%` und weiter offenem `can_set_all_to_100=false`
- `scripts/verify-phase5-candidate.ps1` prueft den Candidate jetzt fail-closed inklusive `no-release`-Artefakt statt nur gegen einen `pending`-Reviewzustand
- `scripts/verify-browser-contract.ps1` deckt jetzt die bereits vorhandenen Frontend-/API-Marker fuer `Auth Contract` und `System Unavailable Fallback` mit ab; damit werden zwei P3-Vertraege nicht nur hosted, sondern auch lokal wiederholbar browserseitig bewiesen
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt minimal evidenzbasiert: Gesamt bleibt `50%`, Phase 5 steigt auf `8%`; dies ist eine dokumentierte `no-release`-Entscheidung plus lokales P3-Verifier-Hardening, aber weiterhin kein Production-Deploy

**Phase 5 Candidate Pipeline + Rollback Drill Proof** — Phase 5 ist nicht mehr nur beim ersten RC-Artefaktschritt, sondern hat jetzt einen workflow-gebundenen Candidate und einen dokumentierten Good-Tag-Ruecksprung:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` bindet den ersten Production-Candidate jetzt an den erfolgreichen GitHub-Run `25318349068`, Commit `5464c922f8871e4ff36e620ff53026fb1a2a05b3`, GHCR-Candidate-Tags, einen immutable Good-Tag-Satz, Rollback-Runbook, Review-Gate und Owner-Decision im Zustand `pending`
- `.phase1-artifacts/phase5-rollback-readiness-20260505.md` bleibt der Readiness-Beleg fuer Hosted-Root, Agent API, MCP Gateway und LLM Gateway; `.phase1-artifacts/phase5-rollback-drill-prod-candidate-20260505-rc1.md` dokumentiert jetzt zusaetzlich den candidate-spezifischen Good-Tag-Rollback-Drill gegen den immutable Tag-Satz `:5464c922f8871e4ff36e620ff53026fb1a2a05b3`
- `scripts/verify-phase5-candidate.ps1` und `scripts/verify-phase5-rollback-drill.ps1` pruefen den Candidate fail-closed gegen Release-Artefakt, Workflow-Run, Rollback-Readiness, Rollback-Drill, Hosted-Endpoints, GHCR-`staging`-Tags, GHCR-Commit-Tags und die gehostete Runtime-Wahrheit
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-release-readiness.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-rollback-drill.ps1`, `gh run view 25318349068 --json conclusion,status,headSha,url,name`, `docker manifest inspect ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:staging`, `docker manifest inspect ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:5464c922f8871e4ff36e620ff53026fb1a2a05b3`, `GET <hosted-staging-url>/`, `GET /api/v1/health`, `GET /mcp/api/v1/health`, `GET /llm/api/v1/health`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `50%`, Phase 5 steigt auf `7%`; dies ist ein verifizierter Candidate-Pipeline-/Good-Tag-Rollback-Drill-Schritt, aber weiterhin kein Production-Deploy

**Phase 5 Release Readiness Baseline Proof** — der Release-Pfad hat jetzt einen belastbaren Basissatz aus Checkliste, Artefakt-Template, Runbooks und eigenem Verifier:

- `docs/release-checklist.md` ist nicht mehr nur Phase-0-Draft, sondern definiert jetzt den aktiven Phase-5-Standard mit vier Sektionen `Code Readiness`, `Infrastructure Readiness`, `Observability Readiness` und `Operations Readiness`, ausschliesslich `JA/NEIN`-Items, Git-Artefakt-Pfad `docs/release-artifacts/<release_id>.md`, Stop-Gates und Non-Claims
- `docs/release-artifacts/README.md` und `docs/release-artifacts/TEMPLATE.md` definieren jetzt den Git-Artefakt-Pfad und das auszufuellende Release-Candidate-Format mit `release_id`, `pipeline_status`, `review_gate`, `owner_decision` und den vier Pflichtsektionen
- `docs/runbooks/rollback-deploy.md`, `docs/runbooks/incident-response.md`, `docs/runbooks/secret-rotation.md`, `docs/runbooks/provider-failover.md` und `docs/runbooks/memory-recovery.md` bilden jetzt die produktionsnahen Pflicht-Runbooks mit Trigger, Verifikation, Eskalation und Non-Claims; `docs/runbooks/README.md` wurde auf Phase-5-Baseline hochgezogen
- `scripts/verify-phase5-release-readiness.ps1` prueft den neuen Release-Basissatz fail-closed gegen Checkliste, Artefakt-Template, Runbooks, Hosted-Proof-Artefakt und Deploy-Workflow-Guard
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-release-readiness.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Der Basissatz allein erhoehte den Fortschritt noch nicht; die Prozent-Erhoehung erfolgte erst mit dem konkreten Production-Candidate-Artefakt und dem nachgezogenen Candidate-Verifier

**Retired Hosted Runtime Truth Alignment Proof** — historische Hetzner-Gate-Panels; fuer aktuelle Gates superseded:

- `services/agent-api/app/main.py` liest die evidenzbasierten Gate-Schliessungen jetzt aus dem bindenden Progress-Manifest statt nur aus der aktuellen Env-Praesenz; `GET /api/v1/external-gates`, `GET /api/v1/external-gates/mirror`, `GET /api/v1/clouds/deployment-preflight/contract` und `GET /api/v1/project/progress/completion` laufen damit fail-closed, aber ohne alte Runtime-Drift
- die damaligen Hetzner-Werte `external-gates status=verified` und `production_deploy_claim_allowed=true` sind retired historical evidence und duerfen aktuell nicht als Hosted-/Production-Claim genutzt werden
- aktueller Mirror-Massstab ist ein realer Vercel-HTTPS-Hosted-Proof plus erreichbare Fly-Origin-Probes; bis dahin bleibt `hosted_staging_claim_allowed=false`
- Verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `scripts/deploy-to-staging.ps1`, `scripts/verify-cloud-only-staging.ps1 -BaseUrl <hosted-staging-url>`, `scripts/verify-external-gates.ps1 -HostedBaseUrl <hosted-staging-url> -LocalBaseUrl <local-control-plane-url>`, direkte Hosted-API-Pruefung von `/api/v1/external-gates`, `/api/v1/external-gates/mirror`, `/api/v1/clouds/deployment-preflight/contract` und `/api/v1/project/progress/completion`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `49%`, Phase 4 steigt auf `24%`; dies ist die abgeschlossene Runtime-Truth-Angleichung nach der Gate-Schliessung, aber weiterhin kein ausgerollter Production-Stack

**Retired External Gate Audit Closure Proof** — historische Hetzner-Gate-Schliessung; fuer aktuelle Gates superseded:

- `scripts/verify-external-gates.ps1 -HostedBaseUrl <hosted-staging-url> -LocalBaseUrl <local-control-plane-url>` erzeugte damals `.phase1-artifacts\external-gate-audit-20260504-212633.json`; dieses Artefakt ist retired und wird durch `.phase1-artifacts\external-gate-audit-20260609-202428.json` ersetzt
- der Verifier prueft jetzt GHCR-Digests ohne unnoetigen lokalen Token-Zwang, hosted Backend Origins ueber echte non-local HTTPS-Probes, Hetzner Live Budget ueber den gehosteten Health-Contract und Branch Protection ueber einen Remote-Fallback, der `scripts/apply_github_branch_protection.py --verify-only` mit dem vorhandenen Remote-`.env` auf dem Hetzner-Host ausfuehrt
- Live-Beweise: `docker manifest inspect` fuer alle sechs GHCR-Images, Hosted-Health-Probes gegen `/api/v1/health`, `/mcp/api/v1/health`, `/llm/api/v1/health`, gehosteter `infra_budget.live_verified=true`, und Remote-GitHub-Verify-Only-Output fuer Branch Protection auf `chore/repo-bootstrap`
- Verifiziert: `scripts/verify-phase1.ps1`, `scripts/verify-cloud-only-staging.ps1 -BaseUrl <hosted-staging-url>`, `scripts/verify-external-gates.ps1 -HostedBaseUrl <hosted-staging-url> -LocalBaseUrl <local-control-plane-url>`, Remote `python3 /tmp/apply_github_branch_protection.py --verify-only --repo strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM --branch chore/repo-bootstrap`, GHCR manifest probes und canonical `gitleaks`
- Fortschritt steigt evidenzbasiert: Gesamt geht auf `49%`, Phase 4 auf `23%`; dies ist Gate-Schliessung und Release-Readiness-Hardening, aber weiterhin kein ausgerollter Production-Stack

**Retired Hosted HTTPS Staging Proof** — altes non-local HTTPS Staging auf Hetzner; nicht mehr aktiver Proof:

- Deploy-Skript `scripts/deploy-to-staging.ps1` bleibt nur als historische Referenz/Plan-Kompatibilitaet erhalten; aktive Cloud-Aktivierung laeuft ueber `scripts/owner-cloud-gate-activation.ps1` und Vercel/Fly
- `docker-compose.cloud.yml` enthaelt jetzt den TLS-Proxy `caddy`, `infrastructure/caddy/Caddyfile` terminiert HTTPS vor `nginx`, und `infrastructure/nginx/cloud.conf` bewahrt `X-Forwarded-Proto`/`X-Forwarded-Host` aus der aeusseren TLS-Schicht
- Live-Host-Beweis: `<hosted-staging-url>/` liefert `200`, `<hosted-staging-url>/api/v1/health` liefert `status=healthy`, `<hosted-staging-url>/api/v1/project/progress` liefert `overall_percent=48`, und der Remote-Compose-Status meldet `caddy`, `nginx`, `agent-api`, `mcp-gateway`, `llm-gateway`, `frontend`, `postgres`, `redis`, `agent-worker` und `memory-worker` als gesund
- Verifiziert: `scripts/verify-phase1.ps1`, `scripts/verify-cloud-only-staging.ps1 -BaseUrl <hosted-staging-url>`, `scripts/verify-external-gates.ps1 -HostedBaseUrl <hosted-staging-url> -LocalBaseUrl <local-control-plane-url>`, Python/OpenSSL-GET-Probes gegen Hosted Root/API und Remote-`curl -k` via SSH gegen Root, Agent API, MCP Gateway und LLM Gateway
- Browser-Live-Beweis: Puppeteer navigierte zu `<hosted-staging-url>/` und bestaetigte `Cloud Superbrain`, `Project Progress`, `External Gates`, sichtbares `48%` und die echte Hosted-URL. Playwright/Chrome-DevTools Screenshot-Proof blieb lokal durch fehlende Chrome-Installation blockiert.
- Diese historische Evidence schliesst heute kein Gate mehr; aktueller Status bleibt `hosted_staging_claim_allowed=false`, bis Vercel/Fly-Proofs bestehen.

**External Gates Alignment Contract Proof** — die lokale External-Gates-Sicht und der Cloud-Deployment-Preflight sprechen jetzt dieselbe Gate-Sprache:

- `GET /api/v1/external-gates` liefert jetzt `external-gates-state-v1`, `external_gates_state_visible`, den Endpoint-Marker, `blocked_release_gates` und die sichtbare Zuordnung `preflight_gate_id` zu `branch_protection`, `hosted_staging`, `hetzner_cloud_stack`, `ghcr_images`, `hosted_backend_origins` und `canonical_secret_scan`
- das Frontend rendert diese Zuordnung sichtbar im Panel `External Gates`, inklusive Contract-Version, Evidence, Endpoint, Release-Blockern und Link auf `GET /api/v1/clouds/deployment-preflight/contract`
- `verify-browser-contract.ps1`, `verify-hosted-staging.ps1`, `verify-phase1-runtime.ps1` und `verify-phase1.ps1` pruefen jetzt die gemeinsame Contract-Version und die fail-closed Zuordnung statt zweier auseinanderlaufender Gate-Begriffe
- der Hosted-Staging-Local-Mirror-Verifier prueft nicht mehr flakey gegen globale `latest_task_id`, sondern gegen stabile Agent-Status-Marker; dadurch verschwindet die Race-Condition mit parallel laufenden Dry-Runs
- Verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `py -3 scripts\verify_project_progress_manifest.py`, `scripts\verify-phase1.ps1`, Docker-Rebuild von `agent-api`, `frontend`, `nginx`, `scripts\verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts\verify-hosted-staging.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, direkte API-Pruefung von `/api/v1/external-gates` und AI-Browser-Proof auf `<local-control-plane-url>/` inklusive Screenshot `superbrain-external-gates-alignment-proof-2026-05-04.png`
- Keine Prozent-Erhoehung durch diesen Proof: manifestseitiger Gesamtstand bleibt `48%`, Phase 4 bleibt `15%`; dies ist Contract- und Verifier-Hardening, kein externer Cloud-Gate-Abschluss

**Cloud Deployment Preflight Fail-Closed Contract** — die externe Cloud-Ausfuehrung ist jetzt als sichtbarer Vorflugvertrag gefasst, ohne Deployment-Claim:

- `GET /api/v1/clouds/deployment-preflight/contract` liefert `cloud-deployment-preflight-v1` und `cloud_deployment_preflight_visible`
- GHCR, Hetzner, Vercel Backend Origins, Hosted Staging, Branch Protection, canonical Gitleaks und Owner Review bleiben einzelne Gates; Env-Praesenz zaehlt nur als Voraussetzung, nicht als Verifikation
- `verify-external-gates.ps1` blockiert localhost/non-HTTPS fuer Hosted-Ziele und verlangt Cloud Deployment Preflight, GHCR Image Digest, Vercel Origin Health, Hosted API, Branch Protection, Gitleaks und Hetzner Budget, bevor `production_deploy_claim_allowed` wahr werden kann
- `verify-cloud-only-staging.ps1`, Browser-, Hosted-Local- und Runtime-Verifier pruefen den neuen Preflight-Endpunkt fail-closed
- Keine Prozent-Erhoehung durch diesen Proof: manifestseitiger Gesamtstand bleibt `48%`, Phase 4 bleibt `15%`; dies ist lokales Gate-Hardening, keine echte Cloud-Ausfuehrung

**Gemini Priority Queue Correction + Sandbox Rule Proof** — der gemeldete Manager-Agenten-Prioritaetsstand wurde geprueft und korrigiert:

- `tasks.py`, `worker.py`, `orchestrator.py`, `main.py`, Frontend and Verifier nutzen jetzt konsistent `high -> mid -> low`; Planner `9` und DevOps `8` landen in `tasks:agent:queue:high`, Coder/Tester `5` bleiben in `tasks:agent:queue`
- Task-Beschreibungen werden vor Validierung/Persistenz redigiert; Status wird vor Queue-Publish geschrieben; der Worker konsumiert in Priority-Reihenfolge und requeued in die passende Priority-Queue
- Orchestrator behauptet `task_assignment_completed` nur bei wirklich completed Tasks; fehlende LLM-Stream-`[DONE]` Frames oder unbewiesene `live_provider_calls=false` Non-Claims werden zu Partial-Failure statt Completion
- `<workspace-root>\AGENTS.md` und `<workspace-root>\SANDBOX_INSTRUCTIONS.md` behandeln `Unexpected response type` als MCP-Wrapper-Hinweis; Backend-Smoke/Status bleibt der eigentliche Ausfuehrungsnachweis
- AI-Browser-Live-Beweis: Chrome DevTools MCP oeffnete `<local-control-plane-url>/`, alle 75 gelisteten Requests waren HTTP `200`, DOM enthielt `Task Assignment Queue Contract`, `Priority Routing`, `high -> mid -> low`, `Total Project` und `47%`; Puppeteer MCP bestaetigte dieselben Marker und erzeugte Screenshot `superbrain-priority-routing-section-2026-05-01`
- Verifiziert: `py -3 -m py_compile services\agent-api\app\tasks.py services\agent-api\app\orchestrator.py services\agent-api\app\main.py services\agent-worker\app\worker.py`, `py -3 scripts\verify_project_progress_manifest.py`, `scripts/verify-phase1.ps1`, Docker-Rebuild, direkte API-Checks, `scripts\verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts\verify-hosted-staging.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost` und `scripts\verify-phase1-runtime.ps1`
- Keine Prozent-Erhoehung: Gesamt bleibt `47%`, Phase 4 bleibt `15%`; das war Korrektur/Hardening, kein neuer externer Gate-Abschluss

**Cloud Render Offload Contract Proof** — lokale Grafik-/3D-Renderlast ist jetzt sichtbar aus dem localhost-Pfad herausgenommen:

- `GET /api/v1/clouds/render-offload/contract` liefert `cloud-render-offload-v1`, `cloud_render_offload_contract_visible`, `localhost_heavy_render_allowed=false` und `home_pc_protection=true`
- Workloads `webgl_3d_rendering`, `browser_gpu_smoke` and `asset_generation` sind `cloud-only`; nur `control_plane` bleibt lokal erlaubt
- fehlende Cloud-Server-Gates bleiben explizit: `STAGING_BASE_URL`, `AGENT_API_BASE_URL`, `MCP_GATEWAY_BASE_URL`, `LLM_GATEWAY_BASE_URL`, `FLY_API_TOKEN`
- Frontend rendert `Cloud Render Offload` mit `Local Render blocked`, `WebGL / 3D rendering cloud-only` und dem Endpoint `GET /api/v1/clouds/render-offload/contract`
- Verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `scripts/verify-phase1.ps1`, `docker compose -f docker-compose.dev.yml up -d --build agent-api frontend nginx`, `GET /api/v1/clouds/render-offload/contract`, `scripts/verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts/verify-hosted-staging.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts/verify-external-gates.ps1 -LocalBaseUrl <local-control-plane-url>` und Playwright-DOM-Proof
- Keine Prozent-Erhoehung: Gesamt bleibt `47%`, Phase 4 bleibt `15%`; ohne echte gehostete Server und rotierte Secrets bleibt Cloud-Runtime `action_required`

**Grafana Cloud Inventory Contract Proof** — die aktive Observability-Cloud ist lokal und sichtbar verdrahtet:

- `GET /api/v1/clouds` liefert die aktive Provider-Linie mit `grafana_cloud` und `GRAFANA_CLOUD_API_KEY` als Namen/Status, niemals als Wert.
- `GET /api/v1/clouds/layers` fuehrt `grafana_cloud` in Layer 7 mit fail-closed Optional-Identity-Probe.
- `docker-compose.cloud.yml`, `.env.example`, `docs/runbooks/cloud-secret-runtime-injection.md`, `docs/runtime-contracts/cloud-provider-inventory-contract.md` und `docs/runtime-contracts/external-gate-audit-contract.md` kennen die aktiven Vercel/Fly.io/GHCR/Grafana Gates und Non-Claims.
- `scripts/verify-phase1.ps1`, `scripts/verify-browser-contract.ps1`, `scripts/verify-hosted-staging.ps1`, `scripts/verify-phase1-runtime.ps1` und `scripts/verify-external-gates.ps1` pruefen diese Gates fail-closed.
- Verifiziert: Python compile, `scripts/verify_project_progress_manifest.py`, `scripts/verify-phase1.ps1`, `scripts/verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts/verify-hosted-staging.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts/verify-external-gates.ps1 -LocalBaseUrl <local-control-plane-url>`, `scripts/verify-phase1-runtime.ps1` und Playwright-DOM-Proof auf `<local-control-plane-url>/`
- Keine Prozent-Erhoehung: Gesamt bleibt manifestgefuehrt; ohne echte Cloud-Tokens bleiben Live-Identity- und Budget-Claims geschlossen.

**Local Rebuild + Runtime Re-Proof** — der zuvor alte laufende Containerstand wurde neu gebaut und nach Recreate live verifiziert:

- `docker compose -f docker-compose.dev.yml up -d --build agent-api agent-worker memory-worker frontend nginx` baute `agent-api`, `agent-worker`, `memory-worker`, `frontend`, `mcp-gateway`, `llm-gateway` und startete den lokalen Stack neu
- `GET /api/v1/health` meldet `healthy` fuer Agent API, PostgreSQL, Redis, Agent Worker, Memory Worker, MCP Gateway and LLM Gateway
- `GET /api/v1/memory/embedding-consistency/contract` liefert `status=verified`, `memory-embedding-consistency-v1`, `vector(1536)`, `embedding_model_version`, `lexical_fallback` und `No live embedding provider call`
- `scripts/verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost` und `scripts/verify-hosted-staging.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost` laufen gruen
- `scripts/verify-phase1-runtime.ps1` laeuft gruen inklusive Docker-Recreate, Worker-Regression, SSE-Replay, Memory-Embedding-Consistency-Contract und post-recreate steady-state proof
- Playwright-Live-Proof oeffnete `<local-control-plane-url>/`, sah `Cloud Superbrain`, `Project Progress` und `Memory Embedding Consistency Contract`
- Keine Prozent-Erhoehung: Gesamt bleibt `47%`, Phase 4 bleibt `15%`, Memory bleibt `70%`

**Audit L-09 Memory Embedding Consistency Contract Proof** — die Memory-Schicht hat jetzt einen sichtbaren Fail-Closed-Vertrag gegen inkompatible Embedding-Versionen:

- `GET /api/v1/memory/embedding-consistency/contract` liefert `memory-embedding-consistency-v1`
- der Endpoint prueft die DB-Schema-Spalten `content_embedding vector(1536)` und `embedding_model_version`
- neue Memory-Writes persistieren `embedding_model_version` in `memory_entries` und spiegeln den Wert in `metadata`
- Frontend rendert `Memory Embedding Consistency Contract` inklusive `memory_embedding_consistency_contract_visible`
- Verifier pruefen Endpoint, UI, Schema-Guard, `lexical_fallback`, Re-Embedding-Policy und No-Live-Embedding-Provider-Non-Claims
- Fortschritt bleibt Gesamt `47%`; horizontal bleibt P4 `15%`; vertikal steigt Memory auf `70%`

**Runtime Post-Recreate Steady-State Proof** — der große lokale Runtime-Harness ist nach Docker/Nginx-Recreates leiser und strenger:

- `scripts/verify-phase1-runtime.ps1` unterdrueckt transienten `curl`-Noise waehrend bounded Retry-Fenstern, ohne echte Fehler zu verstecken
- nach `agent-api`/`nginx` Recreate wartet der Harness explizit auf `GET /api/v1/health` mit `status=healthy`
- Session-SSE Stream- und Replay-Probes nutzen jetzt `Wait-SseContains` mit bounded Retry in Runtime- und Hosted-Local-Verifier
- am Ende prueft er erneut Health, `GET /api/v1/project/progress/integrity`, `GET /mcp/api/v1/version-pinning/contract` und `/favicon.ico`
- damit kann ein gruener Runtime-Lauf keinen unbemerkten 502-Upstream- oder Browser-Asset-Fehler hinterlassen
- Fortschritt bleibt Gesamt `47%`, Phase 4 bleibt `15%`

**L-09 Project Progress Integrity Runtime Proof** — die Fortschrittsanzeige hat jetzt einen eigenen Runtime-Guard gegen erfundene Prozentzahlen:

- `GET /api/v1/project/progress/integrity` liefert `project-progress-integrity-v1`
- der Endpoint berechnet `computed_overall_percent` aus den sieben horizontalen Phasen neu und vergleicht ihn mit `manifest_overall_percent`
- Frontend rendert `Progress Integrity` inklusive `project_progress_integrity_runtime_proof`
- Verifier pruefen Endpoint, Evidence, Manifest-/Durchschnitts-Paritaet und UI-Markierungen
- Fortschritt bleibt Gesamt `47%`, Phase 4 steigt evidenzbasiert auf `15%`

**L-08 MCP Version Pinning Contract Proof** — die Schicht-5 MCP-Gateway-Versionierung ist jetzt als sichtbarer, versionierter Contract geschlossen:

- `GET /mcp/api/v1/version-pinning/contract` liefert `mcp-version-pinning-v1`
- Frontend rendert `MCP Version Pinning Contract` inklusive `mcp_version_pinning_contract_visible`
- Der Contract pinnt `fastapi==0.115.8`, `uvicorn[standard]==0.34.0`, `pydantic==2.10.6` und die Tool-Contract-Versionen fuer GitHub, PostgreSQL, Filesystem, Playwright und E2B
- Dokumentiert in `docs/runtime-contracts/mcp-version-pinning-contract.md`
- Fortschritt bleibt Gesamt `47%`, Phase 4 steigt evidenzbasiert auf `14%`, MCP Gateway auf `53%`

**L-07 Agent LLM Streaming Contract Proof** — die Schicht 3→4 Agent-Pool-zu-LLM-Gateway-Streaminggrenze ist jetzt als sichtbarer, versionierter Contract geschlossen:

- `GET /api/v1/agents/llm-streaming-contract` liefert `agent-llm-streaming-contract-v1`
- Frontend rendert `Agent LLM Streaming Contract` inklusive `agent_llm_streaming_contract_visible`
- Der Contract bindet `call_llm_gateway_for_task`, `parse_llm_gateway_sse_line`, `openai_compatible_sse`, `text/event-stream`, `data: [DONE]` und `stream_done_seen`
- Dokumentiert in `docs/runtime-contracts/agent-llm-streaming-contract.md`
- Fortschritt bleibt Gesamt `47%`, Phase 4 steigt evidenzbasiert auf `13%`, LLM Gateway auf `53%`

**Fly.io Budget Gate Projection** — aktiver Budgetpfad ist Fly.io/Vercel/GHCR/Grafana, live weiter token-gated:

- `scripts/check_fly_infra_budget.py` ist der aktive Budget-Verifier.
- `docs/runbooks/fly-live-budget-proof-2026-06-08.md` dokumentiert nur eine Projektion; der Live-Gate bleibt ohne `FLY_API_TOKEN` blockiert.
- Budget: Warnschwelle `EUR 16.00`, hartes Limit `EUR 20.00`
- Fortschritt bleibt unveraendert; kein Live-Budget-Claim ohne externen Token-Beweis.

**L-06 Task Assignment Queue Contract Proof** — die Schicht 2→3 Task-Uebergabe ist jetzt als sichtbarer, versionierter Contract geschlossen:

- `GET /api/v1/tasks/assignment-contract` liefert `task-assignment-queue-contract-v1` mit TaskAssignment-Schema, Redis-Queue, Status-Key, Backpressure und Evidence
- Frontend rendert `Task Assignment Queue Contract` inklusive `task_assignment_queue_contract_visible`
- Dokumentiert in `docs/runtime-contracts/task-assignment-queue-contract.md`
- Autopilot-Stream laeuft im aktiven Stack ueber `<local-control-plane-stream-url>` mit `autopilot-mode-stream-proof`
- Fortschritt bleibt Gesamt `47%`, Phase 4 steigt evidenzbasiert auf `11%`, Agent Pool auf `61%`

**L-05 Layer Interface Contracts Proof** — alle sieben Runtime-Schichtgrenzen haben jetzt ein sichtbares Interface-Register:

- `GET /api/v1/layer-interfaces/contract` liefert `layer-interface-contracts-v1` mit Methode, Pfad, Request-Schema, Response-Schema, Status und Evidence pro Grenze
- Frontend rendert `Layer Interface Contracts` inklusive `layer_interface_contracts_visible`
- Dokumentiert in `docs/runtime-contracts/layer-interface-contracts.md`
- Fortschritt bleibt Gesamt `47%`, Phase 4 steigt evidenzbasiert auf `10%`, Frontend auf `97%`

**Audit Runtime Closure Proof** — die Audit-Report-Fails, die ohne externe Owner-Gates lokal fixbar sind, sind jetzt Code-, Doc- und Verifier-gebunden:

- Task Intake validiert `session_id` als UUID und weist ungueltige Sessions mit HTTP 422 ab
- Agent Worker verwirft malformed Raw-Queue-Payloads ohne Worker-Crash
- Orchestrator MCP-Calls senden `session_id` und `trace_id`; MCP Gateway und Agent API persistieren session-gebundene Audit-Zeilen mit `mcp_tool_session_bound_audit`
- ADR-008 und ADR-009 dokumentieren Single-Tenant-Annahme und Owner-gated Auth-Design
- Fortschritt steigt evidenzbasiert auf Gesamt `47%`, Phase 4 `9%`, Agent Pool `60%`, MCP Gateway `52%`

**External Gate Mirror Proof** — Hosted/External-Gate-Readiness ist jetzt lokal sichtbar und fail-closed gespiegelt:

- `GET /api/v1/external-gates/mirror` liefert `external-gate-mirror-v1`, `external_gate_mirror_proof`, Workflow `.github/workflows/hosted-staging-proof.yml` und Verifier `scripts/verify-hosted-staging.ps1`
- fehlende externe Gates bleiben explizit sichtbar: `hosted_staging_claim_allowed=false`, `production_deploy_claim_allowed=false`, `local_mirror_ready_hosted_blocked`
- Frontend rendert `External Gate Mirror` inklusive Contract, Evidence, Workflow, Verifier und Phase-2-Contract-Spiegelung
- Huygens pruefte die offenen Mirror-Gates; dabei wurde der Project-Progress-Mirror-Ref auf `project_progress_manifest_proof` korrigiert
- `scripts/verify-browser-contract.ps1`, `scripts/verify-hosted-staging.ps1`, `scripts/verify-phase1-runtime.ps1` und `scripts/verify-phase1.ps1` laufen gruen
- Historischer Proof-Zeitpunkt: Gesamt `46%`, Phase 4 stieg evidenzbasiert auf `8%`; aktueller Manifeststand steht im Kopf dieses Dokuments bei Gesamt `47%`

**Phase 2 LangGraph MCP Timeout Controlled Proof** — MCP-Timeouts haengen jetzt nicht nur im Gateway-Vertrag, sondern laufen kontrolliert durch den LangGraph-Agentenpfad:

- Probe `force_mcp_tool_timeout:tester` schaltet die Tester-Rolle auf `simulate_timeout`
- MCP Gateway liefert `status=timeout`, `error_class=timeout`, `mcp_timeout_guard` und `audit_persisted=true`
- LangGraph aggregiert den Lauf bis `completed`, markiert `partial_failure=true`, `tester:mcp_timeout`, `mcp_tool_controlled_error` und `langgraph_mcp_timeout_controlled`
- SSE-Stream endet weiterhin terminal mit `done`; Runtime-Harness prueft Direct Run, Stream, Audit und Contract
- Historischer Proof-Zeitpunkt: Gesamt `46%`, Phase 2 stieg evidenzbasiert auf `86%`; aktueller Manifeststand steht im Kopf dieses Dokuments bei Gesamt `47%`

**Phase 2 SSE Event Contract Proof** — der LangGraph-Orchestrator-Stream hat jetzt einen versionierten SSE-Vertrag fuer die Pflicht-Events:

- `POST /api/v1/orchestrator/dry-run/stream` emittiert `heartbeat`, `agent_status`, `error` und `done` mit `phase2-sse-event-contract-v1`, `phase2_sse_event_contract_proof`, `required_event_types` und `live_provider_calls=false`
- der deterministische Probe-Prompt `force_phase2_sse_error_event` beweist den Fehlerpfad ohne Live-Provider und beendet den Stream mit terminalem `done` plus `status=error`
- `GET /api/v1/phase2/runtime/contract` veroeffentlicht Stream-Endpunkt, Required Events, Error-Probe und Evidence Ref; das Frontend zeigt `SSE Event Contract`
- `scripts/verify-phase1-runtime.ps1`, `scripts/verify-phase1.ps1`, `scripts/verify-hosted-staging.ps1` und `scripts/verify-browser-contract.ps1` blockieren Contract-Drift
- Historischer Proof-Zeitpunkt: Gesamt `46%`, Phase 2 stieg evidenzbasiert auf `85%`; aktueller Manifeststand steht im Kopf dieses Dokuments bei Gesamt `47%`

**Phase 2 Provider Fallback Structured Event Proof** — Provider-Rotation schreibt jetzt ein versioniertes, kosten- und providerbewusstes Audit-Event:

- `POST /internal/rotation/events` persistiert `provider-fallback-event-v1` mit `provider_chain`, `from_model`, `to_model`, `fallback_index`, `routing_policy_decision`, `cost_metadata`, `live_provider_calls=false` und `provider_fallback_structured_event`
- `GET /api/v1/rotation/events` liefert denselben Contract top-level aus, und die Rotation-Policy dokumentiert das neue Event-Format
- Frontend zeigt im Panel `Rotation Events` Fallback-Index, Routing-Policy, Modellwechsel, Kostenmetadaten und Live-Provider-Status an
- `scripts/verify-phase1-runtime.ps1` prueft Policy, Event-Erzeugung und API-Rueckgabe im vollen Runtime-Harness; `scripts/verify-phase1.ps1` und `scripts/verify-hosted-staging.ps1` blockieren Contract-Drift statisch
- Historischer Proof-Zeitpunkt: Gesamt `46%`, Phase 2 stieg evidenzbasiert auf `84%`; aktueller Manifeststand steht im Kopf dieses Dokuments bei Gesamt `47%`

**Phase 2 Budget Hard-Stop Proof** — Budget Guard ist jetzt fuer Warnung und 100%-Block fail-closed im Runtime-Harness abgesichert:

- `scripts/verify-phase1-runtime.ps1` setzt temporaer `cost_tracking=16000` Cent und beweist `level=warning`, `budget_spent_percentage=80.0`, `allow_new_calls=true` sowie erfolgreiche Prompt-Metadaten im Warnzustand
- derselbe Harness setzt temporaer `cost_tracking=20000` Cent und beweist `level=critical`, `allow_new_calls=false`, Prometheus `superbrain_budget_allow_new_calls{level="critical"} 0` und HTTP `402` fuer `POST /api/v1/prompt`
- LangGraph `budget_guard` wird bei 100% Budget ohne Live-Provider auf `hard_stop` mit `hard_stop_reason=budget_guard_rejected` gefuehrt, inklusive PostgreSQL-Checkpoint und `langgraph_dry_run_stopped` Audit
- die Proof-Zeilen werden im `finally` geloescht; nach dem Proof ist `/api/v1/budget` wieder `level=ok`
- Historischer Proof-Zeitpunkt: Gesamt `46%`, Phase 2 stieg evidenzbasiert auf `83%`; aktueller Manifeststand steht im Kopf dieses Dokuments bei Gesamt `47%`

**Governance Drift Cleanup** — die Projektsteuerung ist wieder auf das Ultimatum-Finale und ADR-007 ausgerichtet:

- `AGENTS.md` ist auf `PROJECT_STATE.md`, `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md`, `docs/system-architecture.md` und `docs/project-progress.manifest.json` ausgerichtet
- alte aktive Runtime-Pfade fuer Supabase/LanceDB/Railway/HuggingFace Spaces/Ollama/Qdrant-vor-Phase-6 wurden aus Governance-, Memory-, Secret-, Infrastruktur- und Observability-Dokumenten entfernt oder klar als superseded markiert
- `.github/workflows/supabase-keepalive.yml` ist entfernt; `scripts/verify-phase1.ps1` blockiert eine Rueckkehr dieses Workflows und der alten Drift-Phrasen
- Historischer Proof-Zeitpunkt: Gesamt `46%`, Phase 4 stieg evidenzbasiert auf `7%`; aktueller Manifeststand steht im Kopf dieses Dokuments bei Gesamt `47%`

**Phase 2 Runtime Run Status** — Phase-2-Laufstatus ist jetzt API-, UI- und Browser-Contract-sichtbar:

- `GET /api/v1/phase2/runtime/runs` liest audit-log-backed Runtime-Laeufe und liefert `phase2_runtime_run_status_visible`
- Frontend zeigt `Runtime Runs`, `Latest Runtime Status`, `Role Summaries` und den Runs-Endpunkt im LangGraph-Panel
- Browser-Contract-Proof bestaetigte `status=completed`, `role_summary_count=4`, `agent_result_aggregation_complete`, `live_provider_calls=false`, `live_mcp_writes=false`, `production_deploy=false`
- Historischer Proof-Zeitpunkt: Gesamt `46%`, Phase 2 `82%`; aktueller Manifeststand steht im Kopf dieses Dokuments bei Gesamt `47%`

**Autopilot Runtime Hardening** — der Volltest ist nach dem Automatisierungsmodus wieder gruen:

- `scripts/verify-phase1-runtime.ps1` laeuft inklusive Autopilot-Harness, Worker-Regression, Redis/Nginx-Recreate, LangGraph-Hard-Stops, Checkpoint-Recovery und SSE-Replay durch
- Agent API schreibt Task-Status vor Queue-Publish, damit schnelle Worker-Eskalationen nicht von einem alten `queued`-Status ueberschrieben werden
- Agent Worker ignoriert ungueltige Session-IDs beim stale-queued Completion-Audit-Lookup und faellt sauber in den bestehenden Abandoned/Escalation-Pfad
- Hard-Stop-Checkpoint-Proofs nutzen gueltige UUID-Thread-IDs; gezielter Proof bestaetigte `checkpointing=postgres` und `node_name=hard_stop`
- Keine Live-Provider, keine Live-MCP-Writes, kein Production Deploy

**Autopilot Mode Harness** — der Automatisierungsmodus hat jetzt einen fail-closed lokalen Nachweis:

- Codex-App-Heartbeat `Superbrain Project Autopilot` laeuft alle 30 Minuten auf diesem Thread weiter
- Neuer Verifier `scripts/verify-autopilot-mode.ps1` prueft `<local-control-plane-stream-url>`
- Der Harness beweist Health, Projektfortschritt `47%`, Phase 2 `86%`, Phase 4 `15%`, Frontend `97%`, Agent Pool `61%` und LangGraph/Postgres-Manifest
- Stream-Proof enthaelt `status:init`, `status:llm`, `token`, `done`, `LLM gateway deterministic dry-run response` und `live_provider_calls=false`

**Compact Project Progress UI** — die Fortschrittsanzeige bleibt jetzt horizontal und vertikal lesbar:

- Aktueller Gesamtstand `47%`, horizontale Phasen und vertikale Layer werden im Dashboard gemeinsam angezeigt
- Lange Statusketten werden gekuerzt, behalten aber den vollstaendigen `title`-Nachweis
- Vertikale Layer nutzen kompakte 12px-Balken statt grosser 150px-Flaechen
- Browser-/AI-Proof bestaetigt `Total Project 47%`, `Phase 2 86%`, `Phase 4 15%`, `Agent Pool 61%`, sieben Vertikal-Layer, kompakte Kartenhoehen und keine Status-Ueberlaeufe

**Worker Status Regression Harness** — Worker-Stale-Queued-Finalisierung ist jetzt als fail-closed Runtime-Harness abgesichert:

- Neuer Verifier `scripts/verify-worker-status-regression.ps1` erzeugt isolierte Redis/PostgreSQL-Proof-Records
- Stale `queued` ohne Queue-Eintrag wird zu `abandoned_after_queue_drain` plus Audit `worker_stale_queued_finalized`
- Stale `queued` mit passendem `task_completed` Audit wird zu `completed` rehydriert plus Audit `worker_status_rehydrated_from_completed_audit`
- Frische `queued` Records bleiben unangetastet, echte Queue-Items werden normal verarbeitet, kaputte Completion-Audits rehydrieren nicht
- Direct- und Stream-Dry-run beweisen vier Rollen `completed`, `partial_failure=false`, `agent_result_aggregation_complete`

**Worker Stale-Queued Finalization** — Agent Worker/Task-Status haelt Queue-Drain und Redis-Status jetzt konsistent:

- Worker finalisiert stale `queued` Status-Records ohne Queue-Eintrag als `abandoned_after_queue_drain`
- Vor Abandon wird ein vorhandener `task_completed` Audit-Eintrag genutzt, um Redis-Status auf `completed` zu rehydrieren
- Worker-Restart finalisierte 14 alte stale Records mit Audit `worker_stale_queued_finalized`
- Direct Session `cccccccc-cccc-4333-8ccc-cccccccccccc` lief mit vier Rollen `completed` und `partial_failure=false`
- Stream Session `eeeeeeee-eeee-4333-8eee-eeeeeeeeeeee` lief mit vier Rollen `completed` und `partial_failure=false`

**Dry-run Stream Completion Parity / Bounded Contract** — Stream-Dry-runs sind jetzt auditierbar und luegen nicht ueber Parity:

- Aggregator refreshes nicht-terminale Task-Assignments vor der Rollenbewertung
- Nach 20 Sekunden und leerer Queue wird `stale_queued_after_queue_drain` als explizite Partial-Failure-Reason gesetzt
- Stream Session `bbbbbbbb-bbbb-4333-8bbb-bbbbbbbbbbbb` lief bis `completed`, meldete aber korrekt `partial_failure=true`
- PostgreSQL Audit enthaelt `langgraph_dry_run_completed` mit `agent_result_aggregation_partial_failure_detected`
- Direct Session `99999999-9999-4333-8999-999999999999` lief mit vier Rollen `completed` und `partial_failure=false`

**Dry-run Session Guard** — direkter und gestreamter Orchestrator-Dry-run sichern jetzt vor Graphstart die Agent-Session:

- `prepare_orchestrator_session()` erzeugt/validiert die UUID und upsertet `agent_sessions`
- Direkter Dry-run Session `33333333-3333-4333-8333-333333333333` lief bis `completed` mit `memory_update_persisted`
- Stream Session `44444444-4444-4333-8444-444444444444` wurde vorab als `orchestrator-dry-run-stream` in `agent_sessions` nachgewiesen
- Der vorherige `memory_entries.session_id` Foreign-Key-Fehler ist fuer neue Dry-run-Sessions behoben

**force_agent_partial_failure:tester** — Partial-Failure-Hook in `services/agent-api/app/orchestrator.py` ist verifiziert:

- `force_agent_partial_failure:<role>` setzt in `build_per_role_results()` eine Rollen-Failure-Reason
- Phase-2-Runtime bleibt am Knoten `completed`, setzt aber `partial_failure = true`
- Activity Feed und PostgreSQL Audit enthalten `agent_result_aggregation_partial_failure_detected`
- Verifizierte Session: `22222222-2222-4333-8444-555555555555`

## API-ENDPOINTS

- Local Health: `GET <local-control-plane-url>/api/v1/health` -> healthy
- Local Progress: `GET <local-control-plane-url>/api/v1/project/progress` -> 49%
- Hosted Health: `GET <hosted-staging-url>/api/v1/health` -> healthy
- SSH: `root@<staging-host>` via `STAGING_SSH_KEY_PATH` außerhalb des Repos

## ZULETZT ABGESCHLOSSEN (STAGING)

**Retired Hetzner Staging Server Provisioning** — historische Laufzeitbasis, nicht mehr aktiver Cloud-Pfad:

- CX21-Server `superbrain-staging-fsn1` in Frankfurt war historisch bereitgestellt (IP: <retired-staging-host>)
- SSH-Zugriff mit extern injiziertem `STAGING_SSH_KEY_PATH` verifiziert
- Docker Engine & Compose Plugin installiert
- Firewall (UFW) auf 22, 80, 443 beschraenkt
- Phase 1 Foundation bleibt lokal/manifestevident `100%`; aktueller Hosted-Proof ist auf Vercel/Fly neu zu erbringen.

## BEHOBENE BLOCKER (zum Nachschlagen)

1. **CreateProcessAsUserW failed: 5** — Windows 11 Home hat kein Hyper-V. `[windows] sandbox = "elevated"` entfernt. Globaler `sandbox = "danger-full-access"` aktiv.
2. **write_roots leer** — `setup_marker.json` manuell mit `<workspace-root>` als write_root gepatcht.
3. **CodexSandboxOffline ACLs** — Full Control auf `<workspace-root>` via icacls gesetzt.
4. **Python fehlte** — Python 3.12.10 installiert.
5. **GitHub/Linear MCP Placeholder** — Server disabled bis echte Tokens vorhanden.

## CODEX VERHALTENSREGELN

- TOKEN-SAVING-MODE: Nur 1-2 kurze Sätze als Antwort
- VOLL AUTONOM: Keine Rückfragen, keine Bestätigungen
- IMMER `docs/codex-integration/CODEX_AGENT_SKILL_MASTER.md` beachten
- Bei "go" oder "weiter": Sofort CHAT-START-PROTOKOLL ausführen
- Jede Architektur-Änderung braucht ein ADR in `/docs/adr/`

## ZULETZT ABGESCHLOSSEN (HOSTED PHASE 4)

**Project Progress Completion Contract Runtime Parity**

- Neuer Contract-Endpunkt `GET /api/v1/project/progress/completion/contract` ist live.
- Hosted-Verifier `scripts/verify-phase4-progress-completion-contract-runtime-hosted.ps1` ist gruen.
- Hosted Completion bleibt korrekt fail-closed mit `can_set_all_to_100=false` und sichtbarem `local_progress_gaps_require_verified_evidence_for_each_phase_and_layer`.
- Proof: `.phase1-artifacts/phase4-progress-completion-contract-runtime-hosted-proof-20260507.md`

**Orchestrator Manifest Contract Runtime Parity**

- Neuer Contract-Endpunkt `GET /api/v1/orchestrator/manifest/contract` ist live.
- Hosted-Verifier `scripts/verify-phase4-orchestrator-manifest-contract-runtime-hosted.ps1` ist gruen.
- Hosted Dry-run bleibt an Manifest-Werte `engine=langgraph`, `checkpointing=postgres`, `live_provider_calls=false` gebunden.
- Proof: `.phase1-artifacts/phase4-orchestrator-manifest-contract-runtime-hosted-proof-20260507.md`

**Historischer verifizierter Stand (2026-05-07; aktuelle Werte stehen am Dokumentanfang)**

- Gesamt `63%`
- Horizontal `P0 100 | P1 100 | P2 86 | P3 40 | P4 84 | P5 28 | P6 0`
- Vertikal `Frontend 99 | Orchestrator 99 | Agent Pool 68 | LLM 54 | MCP 55 | Memory 72 | Observability 99`
