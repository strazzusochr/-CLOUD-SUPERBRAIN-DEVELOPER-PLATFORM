# Phase 2 Implementation Plan

Stand: 2026-04-23
Status: Prepared, runtime start blocked by Phase-1.5 gates

## Zweck

Dieses Paket uebersetzt den `PHASE 2`-Abschnitt aus dem Masterplan in eine kontrollierte Umsetzungsreihenfolge.
Es ist ein Implementierungsplan, kein Build-, Test- oder Release-Claim.

## Voraussetzungen

`PHASE 2` darf erst in echte Runtime-Arbeit uebergehen, wenn diese Punkte explizit geklaert sind:

1. Gate A: Observability-Grenze gemaess [docs/PHASE_1_5_GATE_DECISION_PACKAGE.md](docs/PHASE_1_5_GATE_DECISION_PACKAGE.md)
2. Gate B: aktive PostgreSQL-kompatible Runtime fuer Checkpointer und relationale State-Persistenz
3. keine Abweichung von `ADR-001`, `ADR-004` und `ADR-006` ohne neuen ADR

Bis dahin ist nur nicht-invasive Vorarbeit erlaubt. Der erlaubte Arbeitsmodus ist in
[docs/PHASE_1_5_AUTONOMOUS_HANDOFF.md](docs/PHASE_1_5_AUTONOMOUS_HANDOFF.md) festgelegt.

## Zielbild fuer Phase 2

Am Ende dieser Phase soll ein Nutzer einen Prompt eingeben koennen und einen kontrollierten `4`-Agenten-Lauf sehen:

1. Planner analysiert den Auftrag
2. Coder erzeugt Aenderungen im isolierten Arbeitskontext
3. Tester validiert Ergebnisse mit klaren Abbruchregeln
4. DevOps bewertet Runtime- und Deploy-Folgen, ohne selbst ungefragt `production` zu beruehren

Pflicht vor jedem produktiven LLM-Call:

1. Budget-Alert bei `80 Prozent`
2. Rate-Limiting pro Modellslot
3. Kostenweitergabe in die relationale Laufzeit
4. Retry-Grenzen ohne Endlosschleifen

## Umsetzungsreihenfolge

1. Budget- und Rate-Control zuerst
2. LLM-Gateway mit Modellrouting und Fallbacks
3. LangGraph-Orchestrator mit Checkpointer und Recovery-Pfaden
4. Vier Kern-Agenten-Profile als Laufzeitkontrakte
5. Memory-Konsolidierungs-Job als Hintergrundprozess
6. MCP-Toolsets fuer GitHub, E2B, Playwright und Filesystem
7. Verifikation fuer Recovery, Budget-Alarm und Retry-Abbruch

## Arbeitspakete

### Vorlaufpakete ohne Runtime-Claim

Diese Pakete duerfen vor Gate-Freigabe vorbereitet werden, solange sie keine produktive Runtime aktivieren:

1. Vertragsdokumente fuer Budget-, Retry-, Timeout- und Audit-Events
2. Testplaene fuer Budget-Alarm, Retry-Abbruch und Recovery
3. Agentenrollen als Policy- und Toolrecht-Kontrakte
4. DB-portable Schema- und Zugriffskonventionen gemaess `ADR-004`
5. Observability-Interface-Beschreibung gemaess vorgeschlagenem `ADR-006`, ohne Stack-Aktivierung

Nicht erlaubt vor Gate-Freigabe:

1. Langfuse in den Main-App-Compose aufnehmen
2. Self-hosted PostgreSQL als aktive MVP-Runtime setzen
3. echte LLM-Provider-Calls ohne Budget- und Rate-Control
4. Deployment, Secret-Aenderung oder Branch-Schutz-Aenderung
5. Phase 2 als implementiert, getestet oder release-ready markieren

### WP-01 Budget- und Rate-Control

Ziel:
Kein produktiver LLM-Aufruf ohne Kosten- und Lastschutz.

Umfang:

- Request-Kosten je Modellslot berechnen und speichern
- Budget-Alert bei `80 Prozent` des Monatslimits ausloesen
- Rate-Limit pro Modell und pro Run setzen
- identische Prompt-Anfragen mit `10 Minuten` TTL cachen

Lieferobjekte:

- Runtime-Kontrakt fuer Budgetevents: [docs/runtime-contracts/budget-rate-control.md](runtime-contracts/budget-rate-control.md)
- Alert-Regeln und Eskalationspfade
- Tests fuer Limit-Ueberschreitung und Cache-Hit

Stop-Gate:
Kein Live-LLM-Test ohne nachweisbaren Alarm- und Limitpfad.

### WP-02 LLM-Gateway und Modellrouting

Ziel:
Jeder Agentenslot hat eine definierte Primaer- und Fallback-Reihenfolge.

Routing-Matrix:

| Slot | Primaer | Fallback 1 | Fallback 2 | Pflichtschutz |
| --- | --- | --- | --- | --- |
| Planner | Claude Sonnet 4.6 oder GPT-4o | GPT-4o | Gemini Flash | hohes Reasoning, striktes Timeout |
| Coder | DeepSeek-Chat oder Claude Haiku 4.5 | Claude Haiku 4.5 | GPT-4o-Mini | Kostenlimit, laengere Tokenobergrenze |
| Tester | GPT-4o-Mini oder Groq Llama | Groq Llama | Gemini Flash | Analyse vor Tool-Wiederholung |
| DevOps | GPT-4o-Mini | Claude Haiku 4.5 | Gemini Flash | keine ungeprueften Schreibaktionen |

Pflichten:

- modellbezogene Rate-Limits
- Fallback nur bei explizitem Fehlergrund
- Kosten- und Providerwechsel als Event loggen

Lieferobjekte:

- Runtime-Kontrakt fuer Gateway-Only-Routing: [docs/runtime-contracts/llm-gateway-routing.md](runtime-contracts/llm-gateway-routing.md)
- Slot- und Kostenklassen-Mapping ohne Provider-Secrets
- Fallback-Events und Reject-Entscheidungen als testbare Schnittstelle

### WP-03 LangGraph-Orchestrator

Ziel:
Der Multi-Agent-Run ist als kontrollierter Graph mit Abbruchzaehlern modelliert.

Lieferobjekte:

- Runtime-Kontrakt fuer Graph-Nodes, State, Retry-Grenzen und Recovery: [docs/runtime-contracts/langgraph-orchestrator.md](runtime-contracts/langgraph-orchestrator.md)
- Checkpointer-Anforderungen ohne aktive Runtime-Freischaltung
- Streaming-Event-Vertrag fuer `run.*` und `node.*` Events ohne Secret- oder Rohproviderdaten

#### Node 1: Intent Parser

- Eingabe: Nutzerprompt, Session-Kontext, Projektkontext
- Ausgabe: strukturierter Auftrag mit Ziel, Risiken, betroffenen Schichten und Prioritaet
- Entscheidungslogik: prueft Vollstaendigkeit, erkennt unklare oder verbotene Absichten
- Ausgaenge: `task_routing`, `needs_clarification`, `hard_stop`
- Max Retry: `2`
- Eskalation: Intent nach `2` Versuchen weiter unklar oder sicherheitskritisch

#### Node 2: Task Router

- Eingabe: strukturierter Auftrag, aktive Policies, Rollenverfuegbarkeit
- Ausgabe: Aufgabenpakete pro Rolle, Reihenfolge, Parallelisierungsflag
- Entscheidungslogik: trennt Pflichtpfade, vermeidet unnoetige Rollenaktivierung
- Ausgaenge: `agent_execution`, `hard_stop`
- Max Retry: `1`
- Eskalation: Auftrag verletzt Rollen- oder Gate-Regeln

#### Node 3: Agent Executor

- Eingabe: Aufgabenpakete, Toolrechte, aktueller Run-State
- Ausgabe: Rollenresultate, Artefakte, Fehlerobjekte
- Entscheidungslogik: fuehrt Rollen kontrolliert aus und sammelt strukturierte Resultate
- Ausgaenge: `result_aggregation`, `error_handler`
- Max Retry: `5`
- Eskalation: keine lauffaehige Teilantwort nach `5` Zyklen oder Toolfehler ohne sicheren Fallback

#### Node 4: Result Aggregator

- Eingabe: Rollenresultate, Artefakte, Diff- und Testdaten
- Ausgabe: konsolidiertes Ergebnisobjekt mit Evidenzliste
- Entscheidungslogik: prueft Vollstaendigkeit, Konflikte und fehlende Nachweise
- Ausgaenge: `memory_updater`, `error_handler`
- Max Retry: `2`
- Eskalation: Resultate widersprechen sich oder haben keinen verifizierbaren Nachweis

#### Node 5: Memory Updater

- Eingabe: konsolidiertes Ergebnisobjekt, Session-Metadaten, Kosten- und Fehlerdaten
- Ausgabe: persistierter Run-Eintrag, Verdichtungsauftrag, Retrieval-Schluessel
- Entscheidungslogik: schreibt nur relevante Fakten, keine ungefilterten Rohausgaben
- Ausgaenge: `completed`, `error_handler`
- Max Retry: `2`
- Eskalation: Persistenzfehler oder Datenschutz-/Retention-Konflikt

#### Node 6: Error Handler

- Eingabe: Fehlerobjekt, letzter stabiler State, Retry-Zaehler
- Ausgabe: Retry-Entscheidung, Eskalationsobjekt oder sauberer Abbruch
- Entscheidungslogik: unterscheidet transient, strukturell und policy-bedingt
- Ausgaenge: `agent_execution`, `hard_stop`
- Max Retry: global `5`
- Eskalation: Wiederholungsgrenze erreicht, Sicherheitskonflikt oder Recovery unmoeglich

### WP-04 Kern-Agenten-Profile

#### PLANNER-AGENT

Rolle: Intent parsen, Task-Plan erstellen, Squad zuweisen
Modell: Claude Sonnet 4.6 oder GPT-4o
Erlaubte Tools: Memory-Read, interner Task-Router
Verbotene Aktionen: Code schreiben, Dateien veraendern, GitHub-Schreibzugriffe, Deploy-Aktionen
Max-Execution-Time: `60 Sekunden`
Bei Timeout: partiellen Plan mit Unsicherheitsmarkierung liefern, Fehlerstatus loggen, Eskalation
State im Memory: Run-Ziel, priorisierte Arbeitspakete, offene Blocker
Eskalations-Bedingung: Intent unklar nach `2` Versuchen oder Stop-Gate erkannt

#### CODER-AGENT

Rolle: Runtime- und Integrationsaenderungen in kontrollierten Arbeitskontexten umsetzen
Modell: DeepSeek-Chat oder Claude Haiku 4.5
Erlaubte Tools: GitHub-MCP fuer Branch-/PR-Arbeit, Filesystem-MCP, Memory-Read
Verbotene Aktionen: Push auf `main`, Force-Push, Prod-Deploy, direkte DB-Schreiboperationen ausserhalb freigegebener App-Pfade
Max-Execution-Time: `300 Sekunden`
Max-Output-Tokens: `8192`
State im Memory: geaenderte Dateien, letzter erfolgreicher Diff, offene Compiler- oder Lintfehler
Eskalations-Bedingung: `5` Retry-Cycles ohne stabilen Build oder policy-widrige Aenderung benoetigt

#### TESTER-AGENT

Rolle: Laufzeit-, Integrations- und Smoke-Validierung durchfuehren, Fehler sauber klassifizieren
Modell: GPT-4o-Mini oder Groq Llama
Erlaubte Tools: E2B-Sandbox-MCP, Playwright-MCP, Memory-Read und Write
Verbotene Aktionen: produktive Schreibzugriffe, GitHub-Push, stilles Ueberspringen fehlgeschlagener Tests
Max-Execution-Time: `600 Sekunden`
E2B-Session-Pflicht: immer sauber schliessen, auch im Fehlerfall
State im Memory: Testartefakte, Bug-Reports, Severity und Repro-Schritte
Eskalations-Bedingung: derselbe Fehler `5` Mal ohne verwertbaren Fixpfad

#### DEVOPS-AGENT

Rolle: Laufzeitkonfigurationen, Workflow-Zustaende und Rollback-Bereitschaft bewerten
Modell: GPT-4o-Mini
Erlaubte Tools: GitHub-MCP lesend, Filesystem-MCP lesend, interne Health-Checks
Verbotene Aktionen: direkte Production-Aenderungen, Secret-Rotation ohne Approval, Deployment-Trigger ohne Human-Gate
Max-Execution-Time: `120 Sekunden`
State im Memory: letzter Workflow-Status, Health-Checks, bekannte Rollback-Pfade
Eskalations-Bedingung: Health-Check rot, Pipeline scheitert `3` Mal oder Rollback nicht nachweisbar

### WP-05 Memory-Konsolidierungs-Job

Ziel:
Langzeitgedaechtnis bleibt brauchbar, klein genug und nachvollziehbar.

Prozess:

1. neue Run-Ereignisse einsammeln
2. irrelevante oder redundante Details markieren
3. facts, decisions, blockers, evidence und follow-ups getrennt verdichten
4. relationale Metadaten aktualisieren
5. Vector-Embeddings nur fuer retrieval-relevante Inhalte aktualisieren
6. Retention- und Datenschutzregeln anwenden

Input:

- abgeschlossene Run-Zusammenfassung
- Test- und Fehlerartefakte
- Kosten- und Tool-Nutzung
- Owner-Entscheidungen und ADR-Verweise

Output:

- session summary
- project facts update
- blocker register update
- retrieval keys fuer spaetere Prompts

Fehlerpfad:

- keine stillen Teilwrites
- bei Persistenzfehlern nur sauberer Retry oder Eskalation
- keine Memory-Konsolidierung ohne Quellreferenz

### WP-06 MCP-Toolsets

Pflicht-Sets fuer den ersten Runtime-Ausbau:

1. GitHub
2. E2B
3. Playwright
4. Filesystem

Pflichtgarantien:

- timeoutfaehig
- auditierbar
- klarer Fehlermodus
- keine geheimen lokalen Sonderpfade

## Verifikation

Phase-2-Readiness ist erst gegeben, wenn mindestens diese Nachweise geplant und spaeter auch ausgefuehrt werden:

1. Budget-Alert feuert bei `80 Prozent`
2. kein Node laeuft ohne Retry-Zaehler
3. globales Maximum von `5` Retry-Cycles ist dokumentiert und testbar
4. Checkpointer ueberlebt Server-Neustart mit nachweisbarer State-Recovery
5. Fallback-Routing schreibt Provider- und Kostenereignisse mit
6. Tool-Timeouts fuehren zu kontrolliertem Abbruch statt Hängenbleiben

## Bewusste Nicht-Behauptungen

- kein Claim, dass der Orchestrator schon implementiert ist
- kein Claim, dass MCP-Server bereits live verdrahtet sind
- kein Claim, dass Phase-2-Gates schon owner-seitig freigegeben wurden
- kein Claim, dass UI, Auth oder GDPR bereits Bestandteil dieser Phase sind

## Naechster kontrollierter Schritt

Nach Owner-Klaerung der `PHASE 1.5`-Gates kann dieser Plan in konkrete Implementierungsarbeitspakete ueberfuehrt werden:

1. Runtime-Kontrakte und Schemas
2. Budget-/Rate-Control zuerst
3. Graph-Skelett mit Checkpointer
4. Agentenprofile und Toolrechte
5. Recovery- und Budget-Verifikation
