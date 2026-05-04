# ══════════════════════════════════════════════════════════════════
# CLOUD SUPERBRAIN — AKTUELLER PROJEKTSTAND (Auto-Loaded by Codex)
# Letzte Aktualisierung: 2026-05-04 00:00 Uhr
# ══════════════════════════════════════════════════════════════════

## AKTUELLER PROJEKTANKER
- **Anchor ID:** `project-anchor-2026-04-30T00-49-26+02-00`
- **Anchor-Datei:** `PROJECT_ANCHOR.md`
- **Checkpoint:** `docs/project-checkpoint-2026-04-30.json`
- **Live-Snapshot:** `2026-04-30 00:49:26 +02:00`
- **Kernstand:** Localhost `8081` bleibt Dev-Control-Plane; Gesamtfortschritt laut bindendem Manifest `47%`; Project Progress Integrity `verified`; Task-Assignment nutzt echte high/mid/low-Priority-Queues; Cloud Inventory umfasst Vercel, Hetzner, Cloudflare, GitHub, GHCR, Hugging Face, GitLab und GitKraken als nicht-geheime Provider-Oberflaechen; Cloud Render Offload und Cloud Deployment Preflight sind sichtbar, aber echte Hosted-/Production-Claims bleiben fail-closed.

## PROJEKT-IDENTITÄT
- **Name:** -CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM
- **Ziel:** Cloud-native, multi-agent AI-Entwicklerplattform, 3D-Webgame-fähig, prompt-gesteuert
- **Repo-Pfade:**
  - Hauptprojekt: `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`
  - Fresh Build: `D:\PLATTFORM\cloud-superbrain-fresh`
- **Architektur-Wahrheit:** `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md`

## HARTE CONSTRAINTS (NIEMALS BRECHEN)
1. **Budget:** Max €20/Monat Infrastruktur (Hetzner CX21 + Cloudflare)
2. **Kein Localhost in Produktion:** Alles muss Cloud-fähig sein
3. **Orchestrierung:** LangGraph als Haupt-Orchestrator mit PostgreSQL-Checkpointer
4. **Open-Source-First:** LangGraph, LiteLLM, Langfuse, pgvector
5. **Kein Qdrant:** Nur pgvector in Phase 1-5
6. **Kein E2B-Sandbox:** Docker Desktop für lokale Tests
7. **7-Schichten-Architektur** laut Ultimatum Finale

## AKTUELLER FORTSCHRITT: 47%

### Horizontal (nach Priorität)
| Prio | Status |
|------|--------|
| P0   | 100%   |
| P1   | 98%    |
| P2   | 86%    |
| P3   | 33%    |
| P4   | 15%    |
| P5   | 0%     |
| P6   | 0%     |

### Vertikal (nach Modul)
| Modul         | Status |
|---------------|--------|
| Frontend      | 97%    |
| Orchestrator  | 99%    |
| Agent Pool    | 61%    |
| LLM Gateway   | 53%    |
| MCP Gateway   | 53%    |
| Memory        | 70%    |
| Observability | 99%    |

## LAUFENDE DOCKER-CONTAINER (cloud-superbrain-phase1-dev)
- nginx (healthy)
- agent-api (healthy)
- redis (healthy)
- frontend (healthy)
- mcp-gateway (healthy)
- llm-gateway (healthy)
- agent-worker (healthy)
- memory-worker (healthy)
- postgres (healthy)

## NÄCHSTER KONKRETER ARBEITSSCHRITT
- **Externe Gate-Konfiguration / Hosted Staging Proof** — L-05 Layer-Interface-Contracts, L-06 Task-Assignment-Queue-Contract, L-07 Agent-LLM-Streaming-Contract, L-08 MCP-Version-Pinning-Contract, L-09 Project-Progress-Integrity und der einmalige Hetzner-Live-Budgetcheck sind verifiziert; als naechstes bleibt der Plan auf echte externe Secrets und gehostete Spiegelpruefung ausgerichtet:
- `STAGING_BASE_URL` und `BRANCH_PROTECTION_TOKEN` bleiben externe Gate-Abhaengigkeiten; `HETZNER_API_TOKEN` wurde nur transient verwendet und nicht persistiert
- lokal weiter nur deterministische Proofs ohne Live-Provider, ohne Live-MCP-Writes und ohne Production Deploy

## ZULETZT ABGESCHLOSSEN
**External Gates Alignment Contract Proof** — die lokale External-Gates-Sicht und der Cloud-Deployment-Preflight sprechen jetzt dieselbe Gate-Sprache:
- `GET /api/v1/external-gates` liefert jetzt `external-gates-state-v1`, `external_gates_state_visible`, den Endpoint-Marker, `blocked_release_gates` und die sichtbare Zuordnung `preflight_gate_id` zu `branch_protection`, `hosted_staging`, `hetzner_cloud_stack`, `ghcr_images`, `hosted_backend_origins` und `canonical_secret_scan`
- das Frontend rendert diese Zuordnung sichtbar im Panel `External Gates`, inklusive Contract-Version, Evidence, Endpoint, Release-Blockern und Link auf `GET /api/v1/clouds/deployment-preflight/contract`
- `verify-browser-contract.ps1`, `verify-hosted-staging.ps1`, `verify-phase1-runtime.ps1` und `verify-phase1.ps1` pruefen jetzt die gemeinsame Contract-Version und die fail-closed Zuordnung statt zweier auseinanderlaufender Gate-Begriffe
- der Hosted-Staging-Local-Mirror-Verifier prueft nicht mehr flakey gegen globale `latest_task_id`, sondern gegen stabile Agent-Status-Marker; dadurch verschwindet die Race-Condition mit parallel laufenden Dry-Runs
- Verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `py -3 scripts\verify_project_progress_manifest.py`, `scripts\verify-phase1.ps1`, Docker-Rebuild von `agent-api`, `frontend`, `nginx`, `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts\verify-hosted-staging.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, direkte API-Pruefung von `/api/v1/external-gates` und AI-Browser-Proof auf `http://localhost:8081/` inklusive Screenshot `superbrain-external-gates-alignment-proof-2026-05-04.png`
- Keine Prozent-Erhoehung: Gesamt bleibt `47%`, Phase 4 bleibt `15%`; dies ist Contract- und Verifier-Hardening, kein externer Cloud-Gate-Abschluss

**Cloud Deployment Preflight Fail-Closed Contract** — die externe Cloud-Ausfuehrung ist jetzt als sichtbarer Vorflugvertrag gefasst, ohne Deployment-Claim:
- `GET /api/v1/clouds/deployment-preflight/contract` liefert `cloud-deployment-preflight-v1` und `cloud_deployment_preflight_visible`
- GHCR, Hetzner, Vercel Backend Origins, Hosted Staging, Branch Protection, canonical Gitleaks und Owner Review bleiben einzelne Gates; Env-Praesenz zaehlt nur als Voraussetzung, nicht als Verifikation
- `verify-external-gates.ps1` blockiert localhost/non-HTTPS fuer Hosted-Ziele und verlangt Cloud Deployment Preflight, GHCR Image Digest, Vercel Origin Health, Hosted API, Branch Protection, Gitleaks und Hetzner Budget, bevor `production_deploy_claim_allowed` wahr werden kann
- `verify-cloud-only-staging.ps1`, Browser-, Hosted-Local- und Runtime-Verifier pruefen den neuen Preflight-Endpunkt fail-closed
- Keine Prozent-Erhoehung: Gesamt bleibt `47%`, Phase 4 bleibt `15%`; dies ist lokales Gate-Hardening, keine echte Cloud-Ausfuehrung

**Gemini Priority Queue Correction + Sandbox Rule Proof** — der gemeldete Manager-Agenten-Prioritaetsstand wurde geprueft und korrigiert:
- `tasks.py`, `worker.py`, `orchestrator.py`, `main.py`, Frontend und Verifier nutzen jetzt konsistent `high -> mid -> low`; Planner `9` und DevOps `8` landen in `tasks:agent:queue:high`, Coder/Tester `5` bleiben in `tasks:agent:queue`
- Task-Beschreibungen werden vor Validierung/Persistenz redigiert; Status wird vor Queue-Publish geschrieben; der Worker konsumiert in Priority-Reihenfolge und requeued in die passende Priority-Queue
- Orchestrator behauptet `task_assignment_completed` nur bei wirklich completed Tasks; fehlende LLM-Stream-`[DONE]` Frames oder unbewiesene `live_provider_calls=false` Non-Claims werden zu Partial-Failure statt Completion
- `D:\PLATTFORM\AGENTS.md` und `D:\PLATTFORM\SANDBOX_INSTRUCTIONS.md` behandeln `Unexpected response type` als MCP-Wrapper-Hinweis; Backend-Smoke/Status bleibt der eigentliche Ausfuehrungsnachweis
- AI-Browser-Live-Beweis: Chrome DevTools MCP oeffnete `http://localhost:8081/`, alle 75 gelisteten Requests waren HTTP `200`, DOM enthielt `Task Assignment Queue Contract`, `Priority Routing`, `high -> mid -> low`, `Total Project` und `47%`; Puppeteer MCP bestaetigte dieselben Marker und erzeugte Screenshot `superbrain-priority-routing-section-2026-05-01`
- Verifiziert: `py -3 -m py_compile services\agent-api\app\tasks.py services\agent-api\app\orchestrator.py services\agent-api\app\main.py services\agent-worker\app\worker.py`, `py -3 scripts\verify_project_progress_manifest.py`, `scripts/verify-phase1.ps1`, Docker-Rebuild, direkte API-Checks, `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts\verify-hosted-staging.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` und `scripts\verify-phase1-runtime.ps1`
- Keine Prozent-Erhoehung: Gesamt bleibt `47%`, Phase 4 bleibt `15%`; das war Korrektur/Hardening, kein neuer externer Gate-Abschluss

**Cloud Render Offload Contract Proof** — lokale Grafik-/3D-Renderlast ist jetzt sichtbar aus dem localhost-Pfad herausgenommen:
- `GET /api/v1/clouds/render-offload/contract` liefert `cloud-render-offload-v1`, `cloud_render_offload_contract_visible`, `localhost_heavy_render_allowed=false` und `home_pc_protection=true`
- Workloads `webgl_3d_rendering`, `browser_gpu_smoke` und `asset_generation` sind `cloud-only`; nur `control_plane` bleibt lokal erlaubt
- fehlende Cloud-Server-Gates bleiben explizit: `STAGING_BASE_URL`, `AGENT_API_BASE_URL`, `MCP_GATEWAY_BASE_URL`, `LLM_GATEWAY_BASE_URL`, `HETZNER_API_TOKEN`
- Frontend rendert `Cloud Render Offload` mit `Local Render blocked`, `WebGL / 3D rendering cloud-only` und dem Endpoint `GET /api/v1/clouds/render-offload/contract`
- Verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `scripts/verify-phase1.ps1`, `docker compose -f docker-compose.dev.yml up -d --build agent-api frontend nginx`, `GET /api/v1/clouds/render-offload/contract`, `scripts/verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts/verify-hosted-staging.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts/verify-external-gates.ps1 -LocalBaseUrl http://localhost:8081` und Playwright-DOM-Proof
- Keine Prozent-Erhoehung: Gesamt bleibt `47%`, Phase 4 bleibt `15%`; ohne echte gehostete Server und rotierte Secrets bleibt Cloud-Runtime `action_required`

**GitKraken Cloud Inventory Contract Proof** — der in der Cloud/API-Analyse gefundene GitKraken-Gap ist jetzt lokal und sichtbar geschlossen:
- `GET /api/v1/clouds` liefert `total_count=8` und den neuen Provider `gitkraken_identity` mit `GITKRAKEN_API_TOKEN`, `GITKRAKEN_ORG_ID`, `GITKRAKEN_ORG_NAME`, `GITKRAKEN_DASHBOARD_URL` und `GITKRAKEN_API_URL` als Namen/Status, niemals als Werte
- `GET /api/v1/clouds/layers` fuehrt `gitkraken_identity` in Layer 5 und Layer 7 mit expliziten Blockern `gitkraken_identity_requires_GITKRAKEN_API_TOKEN`
- `docker-compose.cloud.yml`, `.env.example`, `docs/runbooks/cloud-secret-runtime-injection.md`, `docs/runtime-contracts/cloud-provider-inventory-contract.md` und `docs/runtime-contracts/external-gate-audit-contract.md` kennen die GitKraken-Keys und Non-Claims
- `scripts/verify-phase1.ps1`, `scripts/verify-browser-contract.ps1`, `scripts/verify-hosted-staging.ps1`, `scripts/verify-phase1-runtime.ps1` und `scripts/verify-external-gates.ps1` pruefen GitKraken jetzt fail-closed
- Verifiziert: Python compile, `scripts/verify_project_progress_manifest.py`, `scripts/verify-phase1.ps1`, `scripts/verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts/verify-hosted-staging.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts/verify-external-gates.ps1 -LocalBaseUrl http://localhost:8081`, `scripts/verify-phase1-runtime.ps1` und Playwright-DOM-Proof auf `http://localhost:8081/`
- Keine Prozent-Erhoehung: Gesamt bleibt `47%`, Phase 4 bleibt `15%`, MCP Gateway bleibt `53%`, Observability bleibt `99%`; ohne rotierten echten GitKraken-Token bleibt der Live-Identity-Claim geschlossen

**Local Rebuild + Runtime Re-Proof** — der zuvor alte laufende Containerstand wurde neu gebaut und nach Recreate live verifiziert:
- `docker compose -f docker-compose.dev.yml up -d --build agent-api agent-worker memory-worker frontend nginx` baute `agent-api`, `agent-worker`, `memory-worker`, `frontend`, `mcp-gateway`, `llm-gateway` und startete den lokalen Stack neu
- `GET /api/v1/health` meldet `healthy` fuer Agent API, PostgreSQL, Redis, Agent Worker, Memory Worker, MCP Gateway und LLM Gateway
- `GET /api/v1/memory/embedding-consistency/contract` liefert `status=verified`, `memory-embedding-consistency-v1`, `vector(1536)`, `embedding_model_version`, `lexical_fallback` und `No live embedding provider call`
- `scripts/verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` und `scripts/verify-hosted-staging.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` laufen gruen
- `scripts/verify-phase1-runtime.ps1` laeuft gruen inklusive Docker-Recreate, Worker-Regression, SSE-Replay, Memory-Embedding-Consistency-Contract und post-recreate steady-state proof
- Playwright-Live-Proof oeffnete `http://localhost:8081/`, sah `Cloud Superbrain`, `Project Progress` und `Memory Embedding Consistency Contract`
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

**Hetzner Live Budget Warning Proof** — der bereitgestellte Hetzner-Token wurde einmalig als Prozess-Environment genutzt, nicht gespeichert:
- `scripts/check_hetzner_infra_budget.py` meldete `EUR 19.03` projizierte monatliche Serverkosten
- Budget: Warnschwelle `EUR 16.00`, hartes Limit `EUR 20.00`
- Ergebnis: unter hartem Limit, aber Warning aktiv; keine weitere Hetzner-Erweiterung ohne neuen Live-Budgetbeweis
- Dokumentiert in `docs/runbooks/hetzner-live-budget-proof-2026-04-29.md`
- Fortschritt bleibt Gesamt `47%`, Phase 4 steigt evidenzbasiert auf `12%`

**L-06 Task Assignment Queue Contract Proof** — die Schicht 2→3 Task-Uebergabe ist jetzt als sichtbarer, versionierter Contract geschlossen:
- `GET /api/v1/tasks/assignment-contract` liefert `task-assignment-queue-contract-v1` mit TaskAssignment-Schema, Redis-Queue, Status-Key, Backpressure und Evidence
- Frontend rendert `Task Assignment Queue Contract` inklusive `task_assignment_queue_contract_visible`
- Dokumentiert in `docs/runtime-contracts/task-assignment-queue-contract.md`
- Autopilot-Stream laeuft im aktiven Stack ueber `http://localhost:8081/api/stream` mit `autopilot-mode-stream-proof`
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
- Neuer Verifier `scripts/verify-autopilot-mode.ps1` prueft `http://localhost:8081/api/stream`
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

## API-ENDPOINTS (lokal laufend)
- Health: `GET http://localhost:8081/api/v1/health` → healthy
- Progress: `GET http://localhost:8081/api/v1/project/progress` → 47%
- Agent Activity: enthält `per_role_results_visible`
- Rollen sichtbar: planner, coder, tester, devops (alle completed)

## BEHOBENE BLOCKER (zum Nachschlagen)
1. **CreateProcessAsUserW failed: 5** — Windows 11 Home hat kein Hyper-V. `[windows] sandbox = "elevated"` entfernt. Globaler `sandbox = "danger-full-access"` aktiv.
2. **write_roots leer** — `setup_marker.json` manuell mit `D:\PLATTFORM` als write_root gepatcht.
3. **CodexSandboxOffline ACLs** — Full Control auf `D:\PLATTFORM` via icacls gesetzt.
4. **Python fehlte** — Python 3.12.10 installiert.
5. **GitHub/Linear MCP Placeholder** — Server disabled bis echte Tokens vorhanden.

## CODEX VERHALTENSREGELN
- TOKEN-SAVING-MODE: Nur 1-2 kurze Sätze als Antwort
- VOLL AUTONOM: Keine Rückfragen, keine Bestätigungen
- IMMER `docs/codex-integration/CODEX_AGENT_SKILL_MASTER.md` beachten
- Bei "go" oder "weiter": Sofort CHAT-START-PROTOKOLL ausführen
- Jede Architektur-Änderung braucht ein ADR in `/docs/adr/`
