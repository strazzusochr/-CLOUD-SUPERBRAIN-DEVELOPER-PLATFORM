# Vision vs. Realität — Deep-Inventur

Stand: 2026-07-27
Audit-Stichtag: 2026-07-25 / Session 10
Aktualisiert: 2026-07-27 / Session 11 (`agent-research-run-v3`, Topologiekarte)
Scope: Produkt, 22 Seiten, 7 Layer, Funktionen, Optionen, Tools, Skills,
Agenten, Modelle und Cloud-Ziele
Fortschrittswirkung: **0 Prozentpunkte**; reine Wahrheitsinventur
Marktreife: **`MARKET_READY:false`**

## 1. Urteil

Die Plattform besitzt einen echten, lokal bewiesenen Produktkern:

- signierte Gast-Session,
- Prompt über die Frontend-Build-Grenze,
- genau einen live verifizierten Cloudflare-Workers-AI-Modellpfad,
- persistiertes HTML-Artefakt,
- sichtbares, nicht leeres WebGL/three.js-Ergebnis,
- messbare Klick-/DOM-Interaktion,
- identisches Artefakt nach Reload,
- keine direkten Provider-Aufrufe aus dem Browser und keine MCP-Schreibaktion.

Dieser Kern ist **DEV-ONLY**. Das aktuelle Hosted-Frontend besitzt keine
gleichwertig erreichbare Backend-/Persistenzstrecke. Die 22-Seiten-Abnahme
beweist die lokale UI-Aktionsmatrix, aber nicht automatisch, dass alle
dahinter beschriebenen Produkt-, Agenten-, Tool- oder Cloud-Funktionen live
existieren. Insbesondere ersetzen `named_evidence`, gemeinsam gemountete
Controls und Dry-run-Envelopes keine neue Backend-Wirkung.

Der kanonische Manifeststand bleibt unverändert:

| Wahrheit | Stand |
| --- | --- |
| Gesamt | 86 % |
| Phasen | P0 100 · P1 100 · P2 100 · P3 44 · P4 100 · P5 68 · P6 90 |
| Layer | Frontend 100 · Orchestrator 100 · Agent Pool 69 · LLM 55 · MCP 56 · Memory 90 · Observability 100 |
| Marktbereit | `false` |
| Hosted Produktparität | nicht belegt |
| Produktion/Release | nicht freigegeben |

Die Prozentwerte messen den in
`docs/project-progress.manifest.json` referenzierten Vertrags- und
Verifierstand. Sie sind kein Ersatz für die nachfolgende
Nutzbarkeitsklassifikation.

## 2. Methode und Wahrheitsrang

### 2.1 Klassifikation

| Klasse | Bedeutung |
| --- | --- |
| **ECHT NUTZBAR** | Aktueller Benutzerfluss oder Backend-Effekt ist ausgeführt, sichtbar und mit Laufzeitevidenz belegt. Der angegebene Scope, zum Beispiel `DEV-ONLY`, gehört zur Klassifikation. |
| **NUR CONTRACT** | API, UI, Typ, Safe-Envelope, Plan, Statusprojektion oder Verifiervertrag existiert; der beschriebene Live-Effekt ist nicht Ende-zu-Ende belegt. |
| **STUB/MOCK** | Statische, deterministische oder lokale Ersatzantwort simuliert den beabsichtigten Arbeitsablauf, ohne ihn wirklich auszuführen. |
| **FEHLT** | Weder eine belastbare Implementierung noch aktuelle Evidenz für die Anforderung ist vorhanden. |

### 2.2 Quellenrang

1. `PROJECT_STATE.md`
2. `docs/project-progress.manifest.json`
3. `docs/runtime-state/capability-gates.json`
4. aktive ADRs, besonders
   `docs/adr/ADR-010-cloudflare-native-free-runtime.md`
5. aktuelle Laufzeitevidenz unter `.codex/runs/CURRENT/`
6. gepatchte Ultimatum-Dokumente und `docs/system-architecture.md`
7. Endziel-, Visual- und historische Planungsdokumente

Bei Widerspruch gilt die höher priorisierte, aktuelle und
laufzeitverifizierte Quelle.

### 2.3 Geprüfte Vision-Quellen

- `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md`
- `docs/CLOUD_SUPERBRAIN_ULTIMATUM_GPT55_PATCHED_2026-04-29.md`
- `docs/END_ZIEL_GESAMTSPEC.md`
- `docs/7 layer 22 seiten Wörkbereich docs/**`
- `docs/design/page-visual-targets/01-home.md` bis `22-open-source.md`
- `LAYER_MATRIX.md`
- `docs/screen-inventory.md`
- `docs/system-architecture.md`
- alle Dateien unter `docs/adr/`
- aktuelle Runtime-, Gate-, Roster-, Produkt- und Browser-Evidenz

`CLAUDE.md` wird von der Zielvorgabe verlangt, existiert im Projekt-Root aber
nicht: **FEHLT**.

### 2.4 Beweisgrenzen

- `.codex/runs/CURRENT/product-acceptance/report.json`:
  echter lokaler Build, ein Live-Provider-Aufruf, Persistenz, WebGL,
  Klick-/DOM-Änderung und Reload-Parität. Die Keyboard-Eingaben wurden
  gesendet, erzeugten aber keine zusätzliche Pixeländerung.
- `.codex/runs/CURRENT/22-page-actions/report.json`:
  aktueller Lauf vom 2026-07-30 mit 22/22 Routen, 29/29 aktivierten Familien
  und 161/161 aktivierten Membern. 160 Aktionen wurden direkt mit ihrem
  eigenen Effekt ausgelöst; genau eine
  Aktion nutzt den aktuellen source-gebundenen P0-Produktbeweis. Zwei
  erlaubte Build-Aufrufe lieferten zwei Live-Providerantworten; es gab keine
  unerwarteten Provideraufrufe, keine toten oder unregistrierten Controls,
  keine unerwarteten Konsolenfehler und keine Seitenfehler. Zwei erwartete
  HTTP-403-Konsoleneinträge sind jeweils mit dem absichtlich gesperrten
  DELETE-Pfad von Games beziehungsweise Apps korreliert. Der reduzierte
  Member-Zähler kommt aus der dedizierten 7-Control-Topologiekarte statt der
  früher wiederverwendeten 33 Phase-6-Controls; er ist kein Coverage-Verlust.
  Das beweist die aktivierte lokale Aktionsfläche, aber nicht die
  ausgeschlossenen oder Hosted-Funktionen.
- Beide Reports sind `dev_only=true` und `hosted_proof=false`.
- Der Action-Report besitzt eine aktuelle
  `source_binding_sha256`, aber keine Bindung an ein identisches Hosted
  Deployment. Er belegt den aktuellen Workspace, nicht die öffentliche URL.
- Das Hosted-Frontend ist erreichbar, aber seine Backend-/Persistenzprojektion
  ist degradiert beziehungsweise nicht konfiguriert. Lokale Evidenz darf nicht
  als Hosted-Evidenz umetikettiert werden.

## 3. Die 22 Produktseiten

Strenges Primärurteil für die jeweils im Endziel beworbene Hauptfunktion:
**9 ECHT NUTZBAR · 11 NUR CONTRACT · 2 STUB/MOCK · 0 FEHLT/BROKEN**.
Teilfunktionen können innerhalb einer Route besser oder schlechter eingestuft
sein; das ändert das Primärurteil nicht.

| # | Route | Geforderter Kern | Realität | Klasse | Wichtigste Lücke |
| ---: | --- | --- | --- | --- | --- |
| 1 | `/home` | Hero, Einstieg, Stats, lebendes Gehirn, Build-Einstieg | Navigation, Promptwahl und read-only LiveConsole funktionieren lokal. Der Home-Build-Button besitzt keinen eigenen aktuellen Providerlauf; `HomeHeroProofPanel` ist implementiert, aber nicht gemountet. Alle 16 aktivierten Home-Member haben Registrystatus `GAP`. | **NUR CONTRACT** | Eigener Build-Proof, Hosted Build und gemounteter Hero-Check |
| 2 | `/login` | GitHub, Google, E-Mail, Gast, Refresh, Logout, Session | Signierter Gast-/Namens-Cookie und lokaler Sessionfluss sind echt. Die Identität ist nicht persistent; OAuth ist nur gegated. Ein historischer Provider-Dry-run-Panel ist nicht gemountet. | **ECHT NUTZBAR** für Gast; **FEHLT** für Produktionsidentität | O1: reale OAuth-App, Callback und Hosted-Proof |
| 3 | `/workbench` | Editor, Prompt→Orchestrator, Explorer, Preview, Terminal, Agentenhilfe, Mini-Cortex | Der lokale Prompt→Gateway→Workers-AI→HTML→Postgres→Run-Fluss ist echt und persistiert. Editor-/Previewflächen sind bedienbar. Vollwertige IDE-, Terminal- und Agentenarbeitswirkung bleibt teilweise Projektion. | **ECHT NUTZBAR — DEV-ONLY**; erweiterte IDE **NUR CONTRACT** | Hosted Backend-/Artefaktparität |
| 4 | `/organism` | Live-3D-Cortex, Hubs, Run-State, Inspector | R3F/three.js, GLB/Fallback, Kamera-, Szenen-, Gameplay-, Accessibility- und lokale Statuscontrols sind echt. Events/Replay werden gelesen; echte Cloud-Telemetrie und Tool-/Agentenpulse sind Projektionen. | **ECHT NUTZBAR — DEV-ONLY**; Live-Telemetrie **NUR CONTRACT** | OTel-/Agenten-/MCP-Ereignisse an Cortex binden |
| 5 | `/organism/replay` | Timeline, Filter, Playback | Lokale Organism-Controls funktionieren; Replay-/Event-Routen können auf redaktierte, deterministische Fallbacks zurückfallen. Ein persistierter echter Agenten-/Providerlauf wurde nicht als vollständiger Replay-Player abgenommen. | **NUR CONTRACT** | Persistierte, korrelierte Live-Runs |
| 6 | `/organism/map` | Topologie, Knotenwahl, Details | Eine eigene same-origin Kartenansicht liest den strikt validierten read-only Vertrag `organism-topology-v1`, filtert 245 Knoten, zeigt echte Auswahl und gerichtete Nachbarschaften über 494 Kanten, blockiert übergroße Antworten vor dem Parsing und kann nach einem transienten Fehler erneut laden. Frontend-/Backend-Labels, Sicherheitsflags, Kanten und Non-Claims sind exakt gespiegelt. `live=false`; echte Agenten-, Tool-, Provider- und Hosted-Telemetrie fehlt. | **NUR CONTRACT**; Interaktion lokal belegt | Live-Telemetrie und Hosted-Parität an die vertragliche Karte binden |
| 7 | `/agents` | Start/Pause/Kill/Reset, Status, Policies, echte Research-Pipeline | UI, Proxy und Python Agent API sind auf `/api/v1/agent-run` gebunden. `agent-research-run-v3` führt Planner→Coder→Tester→DevOps in vier getrennten Gateway-Aufrufen über ein bis drei echte, sanitisierte und hash-gebundene Exzerpte aus exakt drei festen Projektwahrheiten. Kanonische Profil-ID ohne Alias, Rolle, Reihenfolge, Quellen-IDs, Gateway-Vertrag/Evidence/Trace, fünf echte Boolean-Flags und 2.000-Zeichen-Ausgabelimit sind fail-closed gebunden; die UI prüft diese Wahrheitsfelder ebenfalls streng. Alle vier Schritte bleiben ausdrücklich `analysis_only`; es gibt keinen Benutzerpfad, keine externe Quelle, keinen Readback-Link, keinen separaten Source-Read-Audit-Claim und keine Tool-, Datei-, Test- oder Deploy-Ausführung. Die geforderten Steuerungen, externe Toolarbeit und autonome Softwarelieferung sind nicht live belegt. | **NUR CONTRACT** | Externe Quellen-/Toolarbeit, echte Artefakt-/Testwirkung und vollständige Agentensteuerung |
| 8 | `/files` | Knowledge Bases, Vektoren, Graph, Inspector, Suche | Seed, Speicherung und lexikalische Suche sind lokal sowie in einem begrenzten Hosted-D1-Proof echt. Embeddings/semantische Suche und Graphwirkung sind nicht belegt. | **ECHT NUTZBAR** für lexikalische Memory; Vector/Graph **FEHLT** | O5: Hosted Vectorize-Semantik |
| 9 | `/files/local` | Read-only Host-Dateibrowser, DEV-ONLY | Eine kontrollierte, redaktierte statische Auswahl-/Vertragsfläche ist vorhanden. Alle fünf Aktionen sind `spec_only`; freier Host-FS-Zugriff findet nicht statt. | **STUB/MOCK** | Echter, workspace-begrenzter Read-only-Adapter |
| 10 | `/tools` | MCP-Katalog, Scopes, read-only Execute, Status | Client, Proxy und Backend verwenden den gleichen Projekt-/Tool-/Query-Vertrag. Die allowlist-begrenzten internen Tools `memory_read` und `task_router` laufen read-only mit Ergebnis und Audit-ID; verbotene Tools bleiben fail-closed. Externe MCP-Adapter bleiben Dry-run. | **ECHT NUTZBAR — DEV-ONLY** für interne Read-only-Calls | Externe MCP-Adapter und gegatete Writes |
| 11 | `/marketplace` | Skills/Agenten/MCP/Modelle, Details, Install-Dry-run | Browse, Details und ein lokaler Installationsplan sind bedienbar. Es wird kein Providerpaket installiert oder aktiviert. | **NUR CONTRACT** | Verifizierter, reversibler Install-/Enable-Fluss |
| 12 | `/observe` | Grafana, Langfuse, OTel, Health, Runs, Traces | Lokale Health-/Audit-/Metrikprojektionen funktionieren; Hosted OTLP Log- und Metrik-Ingestion ist belegt. Traffic-Chart, Trace-Explorer, Dashboards und Alerts sind nicht live gebunden. | **NUR CONTRACT**; Basisdaten/Ingestion sind echt | Querybare Traces, Dashboards, Alerts, Langfuse |
| 13 | `/games` | Templates, Scene Preview, Workbench, persistierte Bibliothek | Templates, lokale Bibliothek/History, Preview und Öffnen-Pfade sind vorhanden. Der echte P0-Providerbeweis stammt aus der Workbench, nicht aus einer vollständigen Games-Pipeline. | **ECHT NUTZBAR — DEV-ONLY** für Katalog/Artefakte; Game-Generator **NUR CONTRACT** | Eigener Prompt→spielbares Game→Library-E2E |
| 14 | `/apps` | App-Projekte analog Games | Templates, persistierte Buildliste, Auswahl und Öffnen sind lokal bedienbar. Ein vollständiger App-Projekt-Lifecycle mit Dateien, Tests und Deploy fehlt. | **ECHT NUTZBAR — DEV-ONLY** für Katalog/History; Lifecycle **NUR CONTRACT** | Projektstruktur, Test und Deploy-Vorbereitung |
| 15 | `/media` | Bild-, Video-, Audio-Pipeline und Library | Browserlokale Audio-/Video-Erzeugung, Aufnahme, Tabs und Download sind echte, ausdrücklich nicht als KI ausgegebene Funktionen. Eine KI-Medienpipeline ist nicht implementiert. | **ECHT NUTZBAR — DEV-ONLY** für Browser-Medien; KI-Pipeline **FEHLT** | Persistierter Cloud-Store und optionale echte Provider |
| 16 | `/docs-output` | Markdown/Dokumente, Exporte | Editor, Preview, Store-Ausgabe und Download sind lokal bedienbar. PDF-Export, Zitate und vollständige Dokumentpipeline fehlen. | **ECHT NUTZBAR — DEV-ONLY**; erweiterter Export **FEHLT** | PDF/Citations und Hosted-Persistenz |
| 17 | `/evidence` | Verifier, Claim Guards, Evidence-Artefakte | Read-only Listings, sichtbare Zusammenfassungen, LiveConsole und Navigation existieren. Die UI führt absichtlich keine Verifier-Skripte aus; die sichtbare Tabelle kann „unverifiziert“ bleiben. | **NUR CONTRACT** | Sichere Job-/Verifier-Ausführung mit Audit |
| 18 | `/diagnostics` | Recovery, Archive, Rohdaten | Read-only Diagnose-, Archiv- und Evidence-Navigation funktionieren. Archivdaten sind teilweise handgepflegt; Recovery-/Restore-Wirkungen werden nicht ausgeführt. | **NUR CONTRACT** | Kontrollierter Restore-/Recovery-Workflow |
| 19 | `/design-system` | Tokens, Komponenten, Typografie, responsive Regeln | Statische Referenzfläche und Responsive-Navigation existieren. Es gibt keinen aktuellen Figma-/Pixel-Abnahmebeweis für alle 22 Targets. | **NUR CONTRACT** | Editierbare Designquelle und Visual-Regression |
| 20 | `/technology` | 7-Layer-/Provider-Matrix und Runtime-Technik | Session 11: statische Ansicht ersetzt. `TechnologyRuntimeView` liest read-only `GET /api/v1/clouds` (`cloud-provider-inventory-v1`), `GET /api/v1/clouds/layers` (`cloud-layer-readiness-v1`) und `GET /api/v1/clouds/deployment-preflight`, validiert alle drei Verträge samt Querbezügen fail-closed und führt Fly ausschließlich als `historical_only` ohne Layer-Zuordnung — ADR-010-Widerspruch behoben. Bleibt `NUR CONTRACT`, weil die Cloud-Provider selbst nicht live verifiziert sind (`cloudflare_native_zero_card_hosted_runtime` offen). | **NUR CONTRACT** | Hosted-Beweis der Provider (O2′) |
| 21 | `/settings` | Profil, Policies, Gates, Rollen, Owner-Aktivierung | Gate-/Rollenplan ist sichtbar. Apply ist gesperrt; ein vorhandener Plan-only-Button wird von der Matrix nicht auditiert. | **NUR CONTRACT** | Sichere, owner-gegatete Apply-Strecke |
| 22 | `/open-source` | OSS-First, Lizenzen, Danksagung, Komponenten | Handgepflegte statische Übersicht ohne Runtime-Probe oder SBOM-Abgleich. Die Seite erhebt Open-Source-/Fork-Claims, obwohl im Repository keine Root-`LICENSE` liegt und das Root-Paket `private:true` ist. | **STUB/MOCK / Claim-Lücke** | Lizenzentscheidung, Root-Lizenz und automatischer SBOM-Nachweis |

### 3.1 Falsch verallgemeinerte Hosted-Behauptungen

Die Abschnitte „Jetzt (HOSTED)“ in `docs/END_ZIEL_GESAMTSPEC.md` behaupten
für mehrere Seiten mehr als die aktuelle Laufzeitevidenz trägt. Besonders
betroffen sind Workbench-Persistenz, live-telemetriegebundene Map, echte
Agenten-Research-Pipeline, Files-Suche, Tools-Ausführung, Games-/Apps-/
Media-Persistenz und Hosted Evidence. P1 und die aktuellen Reports zeigen:

- aktuelles Hosted-Frontend: erreichbar,
- Hosted Backendprojektion: degradiert/nicht konfiguriert,
- lokale Working-Tree-Fixes: nicht als identischer Hosted-Stand belegt,
- Hosted Produkt-/Aktionsproof: `false`.

Diese „Jetzt (HOSTED)“-Sätze sind **Dokudrift**, keine Beweise.

## 4. Sieben technische Layer

Für diese Inventur gilt das aktive Mapping aus `AGENTS.md`,
`docs/system-architecture.md` und dem Manifest:
Frontend, Orchestrator, Agent Pool, LLM Gateway, MCP Gateway, Memory,
Observability.

| Layer | Ziel | Realität | Klasse |
| --- | --- | --- | --- |
| L1 Frontend | Next.js-Produktfläche, 22 Seiten, Hosted UI | 22 Seiten und lokale Aktionseffekte sind real; Vercel-Frontend ist erreichbar. Backendabhängige Hosted-Flows sind nicht paritätisch. | **ECHT NUTZBAR** lokal/Frontend-hosted; Backendflächen **NUR CONTRACT** |
| L2 Orchestrator | FastAPI + LangGraph, Checkpoints, Budget/Policy | Python StateGraph, PostgresSaver, Übergänge, Retry-/Budget-/Evidence-Guards laufen lokal. Standardausführung bleibt weitgehend deterministisch; Cloudflare-LangGraph.js ist lokal als zweiter Kandidat bewiesen, nicht Hosted-paritätisch. | **ECHT NUTZBAR — DEV-ONLY**; Hosted-Ziel **NUR CONTRACT** |
| L3 Agent Pool | Planner, Coder, Tester, DevOps führen echte Arbeit aus | Queue, Worker, Heartbeats, Rollen-Envelopes und Result-Aggregation laufen. Rollen erzeugen deterministische Texte/Status statt echter Plan-/Code-/Test-/Deploy-Arbeit. | Infrastruktur **ECHT NUTZBAR**; Agentenarbeit **STUB/MOCK** |
| L4 LLM Gateway | Gateway-only, Routing, Fallback, Budget, Live-Modelle | Ein begrenzter Workers-AI-Qwen-Pfad ist live bewiesen. Das kanonische Python Gateway ist standardmäßig `deterministic_dry_run`; die konfigurierte Modellflotte ist nicht live verifiziert. | Einzelpfad **ECHT NUTZBAR**; Flotte/Routing **NUR CONTRACT** |
| L5 MCP Gateway | Sichere Tools mit Scope, Timeout, Audit und Gates | Safe-Envelopes, Policies und Audit sind implementiert. Konkrete GitHub-/PG-/FS-/Playwright-/E2B-Aufrufe enden als Dry-run/No-call. Writes sind geschlossen. | **NUR CONTRACT** |
| L6 Memory | Working Memory, Long-term Memory, Vektor-/semantische Suche | PostgreSQL, Redis, Konsolidierung und lexikalische Suche laufen lokal; Hosted D1 lexical ist belegt. Schema enthält pgvector, aber produktive Suche nutzt keine Embeddings; Vectorize ist geschlossen. | Lexikalisch **ECHT NUTZBAR**; semantisch **FEHLT** |
| L7 Observability | Audit, Metriken, OTel, Grafana, Langfuse | Lokale Audit-/Prometheusdaten sind real; Hosted OTLP Logs/Metriken wurden ingestiert. Dashboards, Alerts, querybare Traces und Langfuse-End-to-End fehlen. | Basis **ECHT NUTZBAR**; vollständige Observability **NUR CONTRACT** |

### 4.1 Layer-Nummerierungsdrift

`LAYER_MATRIX.md` verwendet weiterhin ein anderes Schema:

- L1 Daten,
- L2 Modelle,
- L3 Agenten,
- L4 API,
- L5 Frontend,
- L6 Cloud,
- L7 Governance.

Das widerspricht dem aktiven Frontend-bis-Observability-Mapping. Die Datei ist
als Verschachtelungsübersicht nützlich, aber ihre Nummerierung ist
**NUR CONTRACT / veraltet** und muss atomar auf das kanonische Mapping
umgestellt werden.

### 4.2 Weitere Architektur- und Inventardrift

- `apps/frontend/lib/workspaceWiring.ts` setzt global
  `live=false`/`writes=false`, obwohl der P0-Report für die Workbench
  `live_provider_calls=true` und persistierte Wirkung belegt. Die
  Seitenwiring-Daten beschreiben die echte Workbench daher falsch.
- `docs/screen-inventory.md` ist weiterhin „Draft Phase 0“, listet nur
  sieben Screens und ist nicht mit den 22 kanonischen Routen/Visual Targets
  synchronisiert.
- `LAYER_MATRIX.md` nennt Next.js 15; tatsächlich nutzt
  `apps/frontend/package.json` Next.js 16.2.11. `/technology` nennt Version 16,
  aber es existiert keine ADR für diesen Upgrade-Schnitt.
- Die visuelle P2-Abnahme prüft Controls und Effekte, nicht die
  Pixel-/Layout-Konformität der 22 Visual Targets. Der P0-Screenshot zeigt das
  generierte WebGL-Spiel, nicht die 22 Plattformseiten.
- Die Vision nennt teilweise WebSockets; der aktive Vertrag fordert SSE.
- Die Vision wechselt zwischen Vier-, Fünf- und weiteren Spezialagenten,
  während der bindende Produktpool Planner/Coder/Tester/DevOps bleibt.
- Historische Pläne verlangen zum Teil Provider-/Secret-/Deploy-Aktionen,
  die den aktuellen Owner-Gates widersprechen.

### 4.3 ADR-Abgleich

| ADR | Befund | Klasse |
| --- | --- | --- |
| ADR-001 LangGraph | Echter `StateGraph`/Checkpointer lokal; `/agents` besitzt einen fail-closed gebundenen Planner→Coder→Tester→DevOps-Analysepfad mit begrenzten Projektquellen, aber keine externe toolgestützte Vier-Rollen-LangGraph-Softwarelieferung. | Kern **ECHT NUTZBAR**; Produktbindung **NUR CONTRACT** |
| ADR-002 LiteLLM | P0 belegt Gateway-only und keinen Browser-Direktprovider, aber den separaten Workers-AI-Pfad statt einer vollständig live verifizierten LiteLLM-Laufzeit. | **NUR CONTRACT / Entscheidungsdrift** |
| ADR-003 No AutoGen | Keine AutoGen-Nutzung gefunden; kein Verstoß. | **ECHT eingehalten**, ohne eigenen Runtime-Claim |
| ADR-004 | Datei ist durch ADR-007 superseded; ADR-Index führt sie weiter als accepted. | **Dokudrift** |
| ADR-005 WebGPU/WebGL | R3F/WebGL2 und 2D-Fallback sind real; P0 belegt WebGL, nicht WebGPU-preferred. | WebGL **ECHT NUTZBAR**; WebGPU **NUR CONTRACT** |
| ADR-006 Observability Boundary | ADR ist `proposed`; `/observe` liegt in der Main-App, während `system-architecture.md` das Mischen von Observability-UI in die Main-App verbietet. | **offener Widerspruch** |
| ADR-007 PostgreSQL/pgvector | PostgreSQL-Builds/Checkpoints echt, aber aktive Suche lexikalisch. ADR-010 macht den Stack zur Legacy-RC10-Baseline. | PostgreSQL **ECHT NUTZBAR**; Vektor/Zielbild **überholt** |
| ADR-008 Single Tenant | Keine Multi-Tenant-Wirkung; Settings-Rollen bleiben Plan. | **NUR CONTRACT** |
| ADR-009 Auth | Gast-Session echt; OAuth-State/Refresh/Produktionsidentität nicht live. | **teilweise ECHT NUTZBAR** |
| ADR-010 Cloudflare Native | Architektur A beschlossen; lokaler D1/DO/Queue/R2-Kandidat belegt, Hosted Gate geschlossen und UI/Docs nicht rebased. | **NUR CONTRACT — DEV-ONLY Kandidat** |

## 5. Agenten

### 5.1 Produkt-Runtime

| Agent/Rolle | Realität | Klasse |
| --- | --- | --- |
| Planner | Task-Envelope, Queue, Status und deterministische Plan-Zusammenfassung existieren; keine live LLM-/Toolarbeit. | Orchestrierung **ECHT NUTZBAR**; Ergebnis **STUB/MOCK** |
| Coder | Task-Envelope und Ergebnisaggregation existieren; keine echte Branch-/Codeänderung durch den Runtime-Agenten. | Orchestrierung **ECHT NUTZBAR**; Ergebnis **STUB/MOCK** |
| Tester | Task-Envelope und Status existieren; keine reale Testausführung über den Produkt-Agenten. | Orchestrierung **ECHT NUTZBAR**; Ergebnis **STUB/MOCK** |
| DevOps | Gated Workflowplan und Status existieren; kein Registry-Push oder Deploy. | **NUR CONTRACT** |
| Research-Pipeline auf `/agents` | UI, Proxy und Python-Endpoint führen Planner→Coder→Tester→DevOps mit begrenzter, read-only Projektquellenbindung und expliziter Analyse-only-Rollenbindung aus. Externe Quellen, Tools, Source-Read-Audit, Dateiänderung, Testausführung und Deployment sind nicht belegt. | **NUR CONTRACT** |
| Start/Pause/Kill/Reset | Teilweise Status-/Plancontrols; keine vollständig live bewiesene Agentensteuerung. | **NUR CONTRACT** |
| Elastische/remote Agentenflotte | Kein Hosted-Scale-/Capacity-Proof. | **FEHLT** |

### 5.2 Codex-Roster

Diese Rollen sind Entwicklungs-/Supervisor-Rollen und nicht mit dem
Produkt-Agent-Pool gleichzusetzen.

| Rosterrolle | Launch-Stand | Klasse |
| --- | --- | --- |
| `default` | launch-validiert | **ECHT NUTZBAR** |
| `explorer` | launch-validiert | **ECHT NUTZBAR** |
| `worker` | launch-validiert | **ECHT NUTZBAR** |
| `backend_platform` | blockiert | **NUR CONTRACT** |
| `cloud_infra_devops` | blockiert | **NUR CONTRACT** |
| `product_scope` | blockiert | **NUR CONTRACT** |
| `qa_validation` | blockiert | **NUR CONTRACT** |
| `security_anticheat` | blockiert | **NUR CONTRACT** |
| `sentinel_runtime` | blockiert | **NUR CONTRACT** |
| `sentinel_truth` | instabil | **NUR CONTRACT** |
| `webgl_client` | instabil | **NUR CONTRACT** |
| `game_design` | blockiert | **NUR CONTRACT** |
| `gameplay_systems` | blockiert | **NUR CONTRACT** |
| `multiplayer_netcode` | instabil | **NUR CONTRACT** |

## 6. LLM- und Modellinventur

| Route/Modell | Vorgesehene Nutzung | Laufzeitwahrheit | Klasse |
| --- | --- | --- | --- |
| `@cf/qwen/qwen2.5-coder-32b-instruct` | echter 3D-Build | Ein begrenzter Workers-AI-Aufruf mit persistiertem Resultat ist belegt. | **ECHT NUTZBAR — begrenzter DEV-ONLY Produktpfad** |
| Cloudflare Workers AI Gateway Preview | freie Edge-Inferenz | Health/Modelle und separater Live-Proof vorhanden; nicht identisch mit vollständigem kanonischem Gatewayvertrag. | **ECHT NUTZBAR** begrenzt |
| Planner: DeepSeek-V4-Pro | Primärroute | Konfigurations-/Routingvertrag, kein aktueller Live-Call-Proof. | **NUR CONTRACT** |
| Planner-Fallback: Qwen3.6 / Kimi | Fallback | Nur konfiguriert. | **NUR CONTRACT** |
| Coder: Qwen3-Coder-Next | Primärroute | Nur konfiguriert. | **NUR CONTRACT** |
| Coder-Fallback: DeepSeek Flash / Gemma4 | Fallback | Nur konfiguriert. | **NUR CONTRACT** |
| Tester: Gemma4-26B | Primärroute | Nur konfiguriert. | **NUR CONTRACT** |
| Tester-Fallback: Qwen3.5 / Llama3.1 | Fallback | Nur konfiguriert. | **NUR CONTRACT** |
| DevOps: DeepSeek Flash | Primärroute | Nur konfiguriert. | **NUR CONTRACT** |
| DevOps-Fallback: Qwen3.6 / Gemma4 | Fallback | Nur konfiguriert. | **NUR CONTRACT** |
| Research: GLM5.1 | Primärroute | Der Produktpfad läuft über das Gateway und besitzt eine begrenzte Projektquellenbindung; GLM5.1, externe Quellen und Toolarbeit sind nicht live belegt. | **NUR CONTRACT** |
| Research-Fallback: DeepSeek Pro / Ling | Fallback | Nur konfiguriert. | **NUR CONTRACT** |
| Python `llm-gateway` Default | OpenAI-kompatible Antwortgrenze | `deterministic_dry_run`; kein Live-Provider. | **STUB/MOCK** |
| lokaler Gemma-GGUF-Container | Offline-Fallback | In Compose unprofiliert konfiguriert; kollidiert mit dem Hard-Lock „kein lokaler Model-Download“ und besitzt keinen Produktbeweis. | **NUR CONTRACT / Drift** |

Keine der konfigurierten Modellnamen darf ohne providergebundene
Laufzeitevidenz als verfügbar oder erfolgreich ausgeführt gelten.

## 7. Tools und MCP

| Tool/Fähigkeit | Realität | Klasse |
| --- | --- | --- |
| MCP Safe Envelope, Scope, Timeout, Audit | Policy-, Audit- und Fehlergrenzen sind implementiert. | **ECHT NUTZBAR** als Sicherheitsgrenze |
| internes `memory_read` | `/tools` sendet den freigegebenen Projekt-/Tool-/Query-Vertrag; Ergebnis und Audit-ID werden sichtbar. | **ECHT NUTZBAR — DEV-ONLY** |
| internes `task_router` | Derselbe read-only Produktpfad liefert Queue-/Task-Readback mit Audit-ID. | **ECHT NUTZBAR — DEV-ONLY** |
| `memory_write` | Nur Memory-/Agentenverträge; kein freigegebener Tool-Write über die Produktfläche. | **NUR CONTRACT** |
| GitHub Branch/PR | Strukturierter Dry-run, kein GitHub-Aufruf. | **NUR CONTRACT** |
| PostgreSQL read-only Query | Vertrag/Allowlist, kein realer MCP-DB-Call. | **NUR CONTRACT** |
| Filesystem workspace-scope | Scope-Vertrag, kein realer Host-FS-Call. | **NUR CONTRACT** |
| Playwright Browser Proof über MCP | Vertrag, kein realer MCP-Browserlauf. | **NUR CONTRACT** |
| E2B Sandbox Lifecycle | Vertrag, kein E2B-Aufruf. | **NUR CONTRACT** |
| Live MCP Writes | Owner-Gate geschlossen. | **FEHLT** |
| Live Agent Tool Writes | Owner-Gate geschlossen. | **FEHLT** |
| GitHub MCP Zielimage | Offizieller Server ist als Ziel festgelegt; kein live Produktcall. | **NUR CONTRACT** |
| Frontend LiveConsole | Reale read-only HTTP-Abfragen, Statusanzeige und Copy. | **ECHT NUTZBAR — DEV-ONLY** |
| Evidence-Verifier-Button | Zeigt read-only Zusammenfassung; startet keinen Verifier. | **NUR CONTRACT** |

Die lokalen Codex-/Playwright-Werkzeuge, mit denen diese Plattform entwickelt
und geprüft wird, sind nicht automatisch Produkt-MCP-Fähigkeiten.

### 7.1 Weitere in der Vision benannte Werkzeuge

| Werkzeug/Integration | Realität | Klasse |
| --- | --- | --- |
| Three.js / React Three Fiber / drei | Reale Frontend-3D-Laufzeit. | **ECHT NUTZBAR — DEV-ONLY** |
| postprocessing | Code-/Paketpfad vorhanden; kein separater aktueller visueller Abnahmebeweis. | **NUR CONTRACT** |
| WebGL | Nicht leeres Canvas im P0-Proof. | **ECHT NUTZBAR — DEV-ONLY** |
| WebGPU | Erkennung/Fallback im Zielcode; P0 lief über WebGL. | **NUR CONTRACT** |
| glTF/GLB | `apps/frontend/public/organism/core.glb` wird mit Fallback geladen. | **ECHT NUTZBAR** für das eine Asset |
| `gltfjsx` | Kein reproduzierter Generatorlauf oder Quellartefakt. | **FEHLT** |
| Blender | Keine `.blend`-Quelle oder Exportpipeline. | **FEHLT** |
| glTF Validator / Khronos-Validierung | Kein aktueller Validatorreport. | **FEHLT** |
| Figma | Visual Targets/Figma-ready Beschreibungen, aber keine editierbare Figma-Quelle oder aktuelle Pixelabnahme. | **FEHLT** |
| OpenTelemetry | Hosted Log-/Metrik-Ingestion teilweise echt; vollständige Traces fehlen. | **NUR CONTRACT** |
| OPA/Rego | Keine `.rego`-Policy oder OPA-Laufzeit. | **FEHLT** |
| `read_file_chunk` | Historisch benanntes Agentenwerkzeug, kein Produkttool. | **FEHLT** im Produkt |
| `run_bash_command` | Historisch benannt; absichtlich kein ungegateter Produkt-Shellzugriff. | **FEHLT** im Produkt |
| `search_huggingface_model` | Provider-/Modellinventar vorhanden, aber kein live bewiesener Produkttoolcall. | **NUR CONTRACT** |
| Codex Review, Automations, Worktrees, Environments, Browser, Commands, Permissions, Hooks, AGENTS, Plugins, Skills, Subagents | Teilweise im Entwicklungsarbeitsplatz vorhanden; nicht als Funktionen der ausgelieferten Plattform implementiert. | Entwicklungsumgebung **ECHT**, Produkt **FEHLT/NUR CONTRACT** |

## 8. Vision-Skills

Die historischen Visual-/Organism-Pläne fordern zehn benannte Skills. Die
exakten Pakete sind nicht installiert; vorhandene Substitute werden getrennt
ausgewiesen. Die zehn Namen erscheinen außerdem als statische Skill-Metadaten
im Agent API, aber es gibt keinen nachgewiesenen Produkt-Loader/-Executor;
diese Produktdarstellung ist **STUB/MOCK**.

| Geforderter Skill | Exakt vorhanden | Reales Substitut | Klasse |
| --- | --- | --- | --- |
| `strict-project-gate` | nein | `superbrain-project-manager`, AGENTS-/Gate-Regeln | **FEHLT** exakt; Substitut **ECHT NUTZBAR** |
| `product-ux-guardian` | nein | `superbrain-frontend-agent`, `3d-web-game-swarm` | **FEHLT** exakt; Substitut **ECHT NUTZBAR** |
| `live-3d-organism-architect` | nein | `r3f-3d-webgame-engineer`, `3d-web-game-swarm` | **FEHLT** exakt; Substitut **ECHT NUTZBAR** |
| `r3f-three-engineer` | nein | `r3f-3d-webgame-engineer` | **FEHLT** exakt; Substitut **ECHT NUTZBAR** |
| `blender-gltf-pipeline` | nein | keine Blender-Pipeline; nur fertiges `core.glb` | **FEHLT** |
| `mcp-safety-auditor` | nein | `superbrain-security-auditor` | **FEHLT** exakt; Substitut **ECHT NUTZBAR** |
| `visual-verifier` | nein | `playwright` | **FEHLT** exakt; Substitut **ECHT NUTZBAR** |
| `accessibility-reduced-motion` | nein | Runtime-Implementierung im 3D-Frontend | Skill **FEHLT**; Produktfunktion **ECHT NUTZBAR** |
| `telemetry-binding-engineer` | nein | `superbrain-observability-agent` | **FEHLT** exakt; Substitut **NUR CONTRACT** für Cortex-Binding |
| `opa-gate-engineer` | nein | interne Python-/TS-Policies, keine `.rego`-Datei | **FEHLT** |

Zusätzlich real installiert und projektspezifisch nutzbar:
`codex-superbrain-agent-squad`, `superbrain-autonomy-cli`,
`superbrain-backend-agent`, `superbrain-codex-desktop-runner`,
`superbrain-database-agent`, `superbrain-frontend-agent`,
`superbrain-memory-consolidator`, `superbrain-observability-agent`,
`superbrain-project-manager`, `superbrain-security-auditor`,
`win11-toolstack`, `gh`, `playwright` und `3d-web-game-swarm`.

Eine installierte Entwicklungs-Skilldatei ist kein Beleg, dass die
entsprechende Fähigkeit im ausgelieferten Produkt existiert.

## 9. Cloud-, Provider- und Laufzeitinventur

| Ziel | Realität | Klasse |
| --- | --- | --- |
| Vercel Frontend | HTTPS-Frontend und `/api/health` erreichbar. Der gebundene Hosted-Proof gehört zu einem älteren Deployment/Commit, nicht zum dirty aktuellen Arbeitsstand. | UI **ECHT NUTZBAR**; Produktparität **NUR CONTRACT** |
| Vercel Backend | Public Health antwortet `200 degraded`; PostgreSQL, Redis, Agent Worker, Memory Worker, MCP Gateway und LLM Gateway sind `not_configured`. | Deployment **ECHT**; Produktbackend **FEHLT** |
| Cloudflare Workers AI | Begrenzter Live-Aufruf und echter Build belegt. | **ECHT NUTZBAR** |
| Cloudflare D1 | Hosted lexikalische Persistenz ist verifiziert. | **ECHT NUTZBAR** im begrenzten Scope |
| Cloudflare LangGraph.js State Runtime | Lokaler Wrangler-Kandidat mit D1-Custom-Checkpointing. Die öffentliche ältere D1-Variante liefert einen persistierten deterministischen Vier-Rollen-Lauf; `/api/v1/cloud-native/contract` antwortet dort 404. Hosted Architecture-A-Source-/State-Parität fehlt. | D1-Teilpfad **ECHT**; Architektur A **NUR CONTRACT** |
| SQLite Durable Objects | Lokal verifiziert, Hosted-Aktivierung nicht belegt. | **NUR CONTRACT** |
| Cloudflare Queues | Lokal verifiziert, Hosted-Aktivierung nicht belegt. | **NUR CONTRACT** |
| R2 | Lokaler Adapter verifiziert; Hosted Zero-card-Aktivierung nicht belegt und deshalb deaktiviert. | **NUR CONTRACT** |
| Vectorize | Scope, Architektur und semantischer Hosted-Proof fehlen. | **FEHLT** |
| Fly.io | Lokaler/älterer Runtimepfad und Inventar existieren, aber ADR-010 setzt Fly für neue Arbeit auf OUT. | **ECHT NUTZBAR** als Legacy-DEV-Runtime; **superseded** als Ziel |
| PostgreSQL + pgvector | Lokale DB, Checkpoints, Builds und Schema sind echt; semantische Embedding-Suche fehlt. | **ECHT NUTZBAR** lokal; Vectorwirkung **FEHLT** |
| Redis | Lokale Queue, Working Memory und Heartbeats sind echt. | **ECHT NUTZBAR — DEV-ONLY** |
| GitHub Actions | Historische grüne Verifier-/Buildläufe vorhanden. Der aktuelle dirty HEAD ist nicht durch CI belegt; `hotfix.yml` ist nur Approval-Marker und `autonomous-fullstack.yml` enthält falsche/Windows-Pfade für Ubuntu. | Basis-CI **ECHT**; aktuelle/autonome Pipeline **NUR CONTRACT/BROKEN** |
| GHCR | Sechs historische öffentliche Pakete existieren; der aktuelle RC/HEAD ist nicht publiziert und die neue Veröffentlichung ist nicht autorisiert. | Historisch **ECHT**; aktueller Release **NUR CONTRACT** |
| Hugging Face | Identität/Modellrouten inventarisiert; aktuelle Modellflotte nicht live verifiziert. | **NUR CONTRACT** |
| GitLab | Providerinventar meldet `action_required`; keine aktive Produktwirkung. | **NUR CONTRACT** |
| Grafana Cloud | Authentifizierte OTLP Log-/Metrik-Ingestion ist belegt. | **ECHT NUTZBAR** begrenzt |
| Langfuse | PostgreSQL-DB/URL-Vertrag existiert, aber kein laufender Langfuse-Service/SDK und kein Ende-zu-Ende-Trace-/Dashboard-Proof. | **FEHLT** als Laufzeit |
| OpenTelemetry | Ingestion-Boundary teilweise echt; vollständige Tracekorrelation und UI fehlen. | **NUR CONTRACT** |
| Produktions-OAuth | Nicht konfiguriert/freigegeben. | **FEHLT** |
| Produktion/Release Promotion | Owner-Gates geschlossen; `MARKET_READY:false`. | **FEHLT** |
| Docker Cloud Compose | Sechs App-Images plus Postgres/Redis/nginx/caddy sind beschrieben; Placeholder/Default-Credentials und kein aktueller Hosted-Stateful-Proof. | **NUR CONTRACT** |

### 9.1 Architekturdrift

ADR-010 wählt Cloudflare-native Architektur A und setzt Fly für neue Arbeit
auf `OUT`. Weiterhin führen unter anderem `docs/system-architecture.md`,
`docs/END_ZIEL_GESAMTSPEC.md`, `apps/frontend/lib/regionMap.ts`,
`apps/frontend/lib/workspaceVerticalStack.ts` und `/technology` Fly als
aktiven Kernpfad. `/api/v1/clouds/layers` beschreibt ebenfalls die
Legacy-Docker-/Fly-/Postgres-/Redis-Wahrheit.

Das ist keine funktionale Hosted-Cloud-Wahrheit. Es sind zwei gleichzeitig
sichtbare Architekturbilder:

1. laufende Legacy-DEV-Runtime,
2. neuer Cloudflare-Zielkandidat.

Sie müssen vor einer Markt-/Releasebehauptung atomar getrennt und neu
versioniert werden.

## 10. Querschnittsfunktionen und Optionen

| Anforderung | Realität | Klasse |
| --- | --- | --- |
| Gateway-only LLM-Zugriff | Der echte P0-Build läuft über die Gateway-Grenze; Browser-Direktaufrufe sind 0. | **ECHT NUTZBAR** im P0-Scope |
| Budget Guard / Free-only | Guards und No-paid-Fallback-Regeln existieren; Hosted Zero-card-Proof fehlt. | **NUR CONTRACT** für Hosted |
| Signed Guest Session | HttpOnly, signiert, SameSite, lokal verifiziert. | **ECHT NUTZBAR** |
| OAuth/JWT-Produktion | Code-/Fail-closed-Verträge vorhanden, Live-Identitätsgate geschlossen. | **NUR CONTRACT**; Aktivierung **FEHLT** |
| Persistierte Builds | PostgreSQL-Roundtrip und identischer Reload lokal belegt. | **ECHT NUTZBAR — DEV-ONLY** |
| Hosted Artifact Store | D1 lexical ist nicht vollständige Build-/R2-Parität. | **NUR CONTRACT** |
| SSE/Replay/Checkpoint | Lokale Orchestrator-/Replay-/Restart-Proofs vorhanden. | **ECHT NUTZBAR — DEV-ONLY** |
| Echte Multi-Agent-Arbeit | Rollen/Envelopes vorhanden, Arbeit deterministisch. | **STUB/MOCK** |
| MCP Read-only | Sichere Verträge, aber keine echten Providercalls. | **NUR CONTRACT** |
| MCP/Agent Writes | Owner-Gates geschlossen. | **FEHLT** |
| 3D WebGL/three.js | Sichtbares, nicht leeres Canvas und Interaktion lokal belegt. | **ECHT NUTZBAR — DEV-ONLY** |
| Tastatursteuerung im generierten P0-Spiel | Marker und Eingaben vorhanden; kein zusätzlicher Pixelwechsel gemessen. | **NUR CONTRACT / unvollständig bewiesen** |
| Reduced Motion / 2D Fallback | Lokale Controls und Fallbackfläche vorhanden. | **ECHT NUTZBAR — DEV-ONLY** |
| Remote Multiplayer/Matchmaking | Nur lokaler Zwei-Peer-/Lockstep-Simulator; keine Transport-/Serverstrecke. | **STUB/MOCK** |
| Physikengine | Explizit blockiert/nicht implementiert. | **FEHLT** |
| Blender-/GLTF-Quellpipeline | Ein `core.glb` ist vorhanden; keine `.blend`-/`.gltf`-Quellen oder Pipeline. | **FEHLT** |
| OPA/Rego Policies | Interne Policies vorhanden, aber kein OPA/Rego-Artefakt. | **FEHLT** |
| Redaction/Audit/Request IDs | Lokal umfassend implementiert und verifiziert. | **ECHT NUTZBAR — DEV-ONLY** |
| Grafana Logs/Metriken | Hosted Ingestion begrenzt belegt. | **ECHT NUTZBAR** |
| Traces/Dashboards/Alerts | Keine vollständige querybare Produktstrecke. | **NUR CONTRACT** |
| CI Secret Scan | Verifier/Workflow vorgesehen; vor Release erneut zwingend. | **ECHT NUTZBAR** als Entwicklungsprüfung |
| GHCR/Release/Rollback-Produktion | Pläne und Drills vorhanden; kein autorisierter Push/Release. | **NUR CONTRACT** |
| Figma-/Pixel-Abnahme | Visual Targets vorhanden; keine editierbare Figma-Quelle/22-Seiten-Pixelabnahme. | **FEHLT** |
| Barrierefreiheit | Reduced Motion, Fokus und 2D-Fallback lokal belegt; keine vollständige 22-Seiten-WCAG-Abnahme. | Teilweise **ECHT NUTZBAR** |

## 11. Superseded oder historische Anforderungen

Die ungepatchten Teil-1-/Teil-2-Pläne und ältere HTML-/Master-Prompts sind
Planungsprovenienz. Folgende frühere Defaults sind durch die aktiven Locks
ersetzt und deshalb **keine aktuellen Produktlücken**:

- Hetzner/CPX31/CPX51/GPU als Phase-1-Default,
- Supabase als aktive MVP-Datenbank,
- Qdrant vor Phase 6,
- LanceDB,
- Ollama,
- Railway,
- Hugging Face Spaces als Runtime,
- CrewAI als Orchestrierungsdefault,
- Helicone/Watchtower/Docker Hub als aktive Kernvorgabe,
- direkte OpenRouter-/Claude-/GPT-4o-Aufrufe,
- Secrets direkt in `.env` schreiben,
- ungated Fly-, Registry-, Main- oder Produktionsaktionen.

Wo diese Namen noch in aktueller UI oder Dokumentation als „jetzt“ erscheinen,
ist das **Dokudrift** und muss entfernt oder ausdrücklich als Historie markiert
werden.

## 12. Top-10-Lücken

1. **Hosted Cloudflare-native Produkt-Runtime (O2′):** Workers, D1,
   Durable Objects, Queues und ein wirklich zero-card-fähiger Artifact Store
   mit Source-Parität und State-Roundtrip.
2. **Hosted Workbench-Parität:** echter Prompt→Gateway→Artefakt→Run→Reload
   auf der öffentlichen URL, nicht nur lokal.
3. **Produktionsidentität (O1):** reale OAuth-App, Hosted Callback,
   persistierte Identität, Refresh/Logout und Sicherheitsproof.
4. **Echte Agentenarbeit:** externe Quellen-/Toolarbeit und
   Planner/Coder/Tester/DevOps, die über die vorhandene vierrollige
   Analyse-only-Projektquellenbindung hinaus begrenzte Artefakt-, Test- und
   Laufzeitwirkung ausführen und auditiert belegen.
5. **Externe MCP-Adapter und später Writes (O4):** zunächst mindestens ein
   realer, sicherer externer Providercall; Writes nur mit Allowlist,
   Branch Protection und Audit.
6. **Hosted semantische Memory (O5):** Embeddings, Vectorize-Index,
   Roundtrip und nachgewiesene semantische Suche.
7. **Kanonischer Live-LLM-Gatewayvertrag (O6):** dynamisches Routing,
   Fallback, Budget und Audit jenseits des einzelnen Workers-AI-P0-Pfads.
8. **Releasekette (O3):** immutable Images, GHCR-Publish, Hosted-Parität,
   Review, Promotion und realer Rollback — erst nach `MARKET_READY:true`.
9. **Observability-Endprodukt:** echte OTel-Traces, Cortex-Korrelation,
   Grafana-/Langfuse-Queries, Dashboards und Alerts.
10. **Design-/3D-/Policy-Werkzeugkette:** Figma-Quelle und Visual-Regression,
    Blender-Quellen/Pipeline, Live-Telemetrie für die verifizierte read-only
    Topology-Map sowie OPA/Rego oder eine ausdrücklich neu entschiedene
    Alternative.

## 13. Geschlossene und offene Gates

### Begrenzt live verifiziert

- `live_llm_provider_calls`: nur der benannte freie
  Cloudflare-Workers-AI-Capability-Pfad.
- `live_memory_provider`: nur Hosted D1 lexical.
- `hosted_observability_endpoint`: nur OTLP Log-/Metrik-Ingestion.

### Offen

- `production_auth_identity`
- `cloudflare_native_zero_card_hosted_runtime`
- `live_vector_memory_search`
- `live_mcp_writes`
- `live_agent_tool_writes`
- `docker_registry_publish`
- `phase6_scale_runtime`
- vollständiger kanonischer LLM-Gateway-Livevertrag

## 14. Verbindliche Non-Claims

- DEV-ONLY; hosted proof still blocked.
- Kein aktueller Hosted-Prompt→persistiertes-3D-Spiel-Proof.
- Kein produktionsreifer OAuth-/Identitätsproof.
- Keine semantische Vector-Memory.
- Keine echte Produkt-MCP-Ausführung gegen GitHub, PostgreSQL, Filesystem,
  Playwright oder E2B.
- Keine live Agenten-Toolwrites.
- Keine echte autonome Vier-Agenten-Softwarelieferung.
- Keine vollständigen Grafana-/Langfuse-Dashboards, Alerts oder Trace-UX.
- Kein GHCR-Publish, kein Produktionsdeploy, keine Release-Promotion.
- Keine vollständige Figma-/Blender-/OPA-Werkzeugkette.
- `MARKET_READY:false`.

## 15. Nächster sicherer Schritt

Den verifizierten lokalen P0-/P2-Stand in Projektwahrheit und Release-Kandidat
übernehmen. Die nächste externe Produktlücke ist O2′: Hosted
Cloudflare-native Runtime und Workbench-Parität. Sie benötigt Owner-Scopes und
Freigabe und darf nicht durch lokale oder Legacy-Fly-Evidenz ersetzt werden.
