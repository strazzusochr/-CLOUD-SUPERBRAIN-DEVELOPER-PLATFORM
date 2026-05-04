# LangGraph Orchestrator Contract

Status: Phase 1 dry-run, PostgreSQL checkpoint recovery, and SSE node progress implemented
Date: 2026-04-26
Phase: Phase 2 / WP-03
Owner layer: Schicht 2 - Orchestrierung

## Zweck

Dieser Vertrag legt fest, wie der Phase-2-Orchestrator als kontrollierter LangGraph-Graph modelliert werden muss. Er verhindert One-Shot-Chaos, unkontrollierte Loops, unklare Recovery-Pfade und Fake-Completeness.

Dieser Vertrag ist in Phase 1 als deterministischer LangGraph-Dry-Run aktiviert. Er beschreibt weiterhin die vollstaendige Phase-2-Zielarchitektur fuer produktive Checkpoints, Live-Routing und Tool-Nutzung.

## Bindende Quellen

1. `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE.md`, Teil 0 bis Teil 2
2. `docs/adr/ADR-001-langgraph-orchestrator.md`
3. `docs/adr/ADR-004-mvp-db-strategy.md`
4. `docs/PHASE_2_IMPLEMENTATION_PLAN.md`, WP-03
5. `docs/runtime-contracts/budget-rate-control.md`
6. `docs/runtime-contracts/llm-gateway-routing.md`
7. `docs/secrets-strategy.md`
8. `docs/interface-contract-register.md`

## Scope

Der Vertrag gilt fuer:

1. Intent-Parsing
2. Task-Routing
3. Agent-Execution-Steuerung
4. Result-Aggregation
5. Memory-Update-Anstoss
6. Error-Handling und Recovery
7. Streaming-Event-Ausgabe an das Frontend
8. Checkpoint- und Restart-Verhalten

## Nicht-Scope

Nicht Bestandteil dieses Vertrags:

1. Live-Provider-Calls
2. Live-Provider- und Tool-State ausserhalb des deterministischen Dry-Runs
3. direkte MCP-Write-Tool-Ausfuehrung
4. Deployment nach Vercel oder Hetzner
5. Secrets, Auth-Flows oder Token-Rotation

## Phase-1-Runtime-Surface

Implementiert:

1. `GET /api/v1/orchestrator/manifest`
2. `POST /api/v1/orchestrator/dry-run`
3. echte LangGraph-Engine (`langgraph==1.1.9`)
4. offizieller PostgreSQL-Checkpointer (`langgraph-checkpoint-postgres==3.0.5`)
5. Node-Pfad: `intent_parser -> budget_guard -> task_router -> agent_executor -> result_aggregator -> memory_updater`
6. Policy-/Budget-Hard-Stop-Pfad ueber `error_handler`
7. Checkpoint-Recovery ueber `GET /api/v1/orchestrator/checkpoints/{thread_id}`
8. Restart-Recovery-Beweis: Runtime-Verifier startet `agent-api` neu und liest denselben `thread_id` aus PostgreSQL zurueck.
9. SSE-Progress-Stream ueber `POST /api/v1/orchestrator/dry-run/stream`
10. Verifier-Beweis in `scripts/verify-phase1-runtime.ps1` und `scripts/verify-hosted-staging.ps1`

Nicht implementiert:

1. Live-LLM-Routing
2. Live-MCP-Toolausfuehrung

## Prinzipien

1. Jeder Node hat definierte Inputs, Outputs, Retry-Grenzen und Stop-Ausgaenge.
2. Kein Loop laeuft ohne lokalen und globalen Zaehler.
3. Der globale Run bricht nach maximal `5` Recovery-Zyklen kontrolliert ab.
4. Jeder Runtime-Schritt muss vor LLM- oder Tool-Nutzung durch Budget- und Rate-Control.
5. Jeder LLM-Aufruf muss ueber den LLM-Gateway-Routing-Vertrag laufen.
6. Jeder Tool-Aufruf muss spaeter ueber die MCP-Schicht laufen, nicht direkt aus dem Orchestrator.
7. Production-Checkpointing darf nicht in-memory sein.
8. Persistenter Checkpointer ist PostgreSQL-kompatibel und fuer den deterministischen Dry-Run aktiv.
9. Streaming-Events duerfen keine Secrets, Rohproviderdaten oder ungefilterte technische Dumps enthalten.
10. Unsicherheit wird im State markiert, nicht verschwiegen.

## Graph-Nodes

| Node | Input | Output | Retry lokal | Erlaubte Ausgaenge |
| --- | --- | --- | --- | --- |
| `intent_parser` | Prompt, Session-Kontext, Projektkontext | strukturierter Auftrag | `2` | `task_router`, `needs_clarification`, `hard_stop` |
| `task_router` | strukturierter Auftrag, Policies, Rollenverfuegbarkeit | Task-Pakete pro Rolle | `1` | `agent_executor`, `hard_stop` |
| `agent_executor` | Task-Pakete, Toolrechte, Run-State | Rollenresultate, Artefakte, Fehlerobjekte | `5` | `result_aggregator`, `error_handler` |
| `result_aggregator` | Rollenresultate, Artefakte, Diff- und Testdaten | konsolidiertes Ergebnisobjekt | `2` | `memory_updater`, `error_handler` |
| `memory_updater` | Ergebnisobjekt, Session-Metadaten, Kosten- und Fehlerdaten | Run-Eintrag, Verdichtungsauftrag, Retrieval-Schluessel | `2` | `completed`, `error_handler` |
| `error_handler` | Fehlerobjekt, letzter stabiler State, Retry-Zaehler | Retry-Entscheidung oder Abbruchobjekt | global `5` | `agent_executor`, `hard_stop` |

## Run-State-Vertrag

Jeder Graph-Run fuehrt mindestens folgende State-Felder:

| Feld | Typ | Pflicht | Zweck |
| --- | --- | --- | --- |
| `run_id` | string | ja | stabile Korrelation ueber alle Events |
| `session_id` | string | ja | Nutzersession oder Projektkontext |
| `phase` | enum | ja | aktuelle Phase des Graph-Runs |
| `node_name` | enum | ja | aktueller Node |
| `prompt_ref` | string | ja | Referenz auf Prompt, nicht zwingend Rohtext |
| `structured_intent` | object | nach Intent Parser | Ziel, Risiken, betroffene Schichten |
| `task_plan` | array | nach Task Router | geordnete Task-Pakete |
| `agent_results` | array | nach Agent Executor | strukturierte Rollenresultate |
| `evidence_refs` | array | nach Result Aggregator | Test-, Diff-, Log- und Artefaktreferenzen |
| `budget_decisions` | array | ja | Entscheidungen aus Budget-/Rate-Control |
| `llm_route_decisions` | array | bei LLM-Nutzung | Entscheidungen aus LLM-Gateway-Routing |
| `retry_counters` | object | ja | lokale und globale Zaehler |
| `last_stable_checkpoint` | string | ja | Checkpoint-Referenz |
| `uncertainties` | array | ja | markierte Annahmen oder offene Punkte |
| `hard_stop_reason` | string/null | ja | kontrollierter Abbruchgrund |

## Strukturierter Intent

`intent_parser` erzeugt kein freies Prosaobjekt, sondern ein validierbares Objekt:

```json
{
  "goal": "prepare runtime contract",
  "requested_scope": ["orchestration"],
  "affected_layers": ["layer_2_orchestration", "layer_6_memory"],
  "risk_flags": ["checkpoint_required", "no_runtime_gate"],
  "requires_owner_gate": false,
  "assumptions": [
    "Phase 2 runtime gates are not yet released"
  ],
  "forbidden_actions_detected": []
}
```

Pflichtlogik:

1. Wenn `forbidden_actions_detected` nicht leer ist, geht der Graph nach `hard_stop`.
2. Wenn `goal` oder `requested_scope` unklar bleibt, geht der Graph nach `needs_clarification`.
3. Wenn der Intent Production-Deployment, `main`-Write, Secret-/Auth-Aenderung oder Datenloeschung verlangt, geht der Graph nach `hard_stop`.

## Task-Router-Vertrag

`task_router` erstellt Task-Pakete mit klaren Grenzen:

| Feld | Typ | Pflicht | Zweck |
| --- | --- | --- | --- |
| `task_id` | string | ja | stabile Task-ID |
| `owner_role` | enum | ja | `planner`, `coder`, `tester`, `devops`, `docs`, `security` |
| `allowed_tools` | array | ja | spaeter MCP-referenzierte Tools |
| `write_scope` | array | ja | erlaubte Dateien oder Module |
| `blocked_actions` | array | ja | verbotene Aktionen |
| `verification_required` | array | ja | Mindestnachweise |
| `parallelizable` | boolean | ja | nur wahr bei disjunktem Write-Scope |

Routing-Regeln:

1. Kein Task darf direkt `main` als Schreibziel haben.
2. Kein Task darf direkte Provider-SDKs oder Secrets enthalten.
3. Parallele Tasks brauchen disjunkte Write-Scopes.
4. Runtime-Tasks bleiben blockiert, solange Gate A und Gate B aus Phase 1.5 offen sind.
5. Toolrechte sind minimiert und werden spaeter ueber MCP-Contracts gebunden.

## Agent-Executor-Vertrag

`agent_executor` steuert Rollen, fuehrt aber keine direkten Tool- oder Provider-Aufrufe am MCP- und Gateway-Vertrag vorbei aus.

Pflichtentscheidungen vor jeder Rollenaktion:

1. `budget.control.decision`
2. `llm.route.selected` oder `llm.route.rejected`, falls LLM-Nutzung noetig ist
3. spaeter `mcp.tool.allowed` oder `mcp.tool.rejected`, falls Tool-Nutzung noetig ist
4. Retry-Zaehler-Pruefung

Der Executor muss `error_handler` aufrufen, wenn:

1. Tool-Timeout eintritt
2. LLM-Routing abgelehnt wird
3. Budget- oder Rate-Control blockiert
4. ein Agent Ergebnis ohne Evidenz liefert
5. ein Agent eine Aktion ausserhalb seines Write-Scopes versucht

## Result-Aggregator-Vertrag

`result_aggregator` darf kein Ergebnis als fertig markieren, wenn eines der folgenden Felder fehlt:

1. `summary`
2. `changed_artifacts`
3. `verification_evidence`
4. `known_gaps`
5. `rollback_note`
6. `next_safe_step`

Konfliktlogik:

1. Widerspruechliche Agentenresultate gehen nach `error_handler`.
2. Fehlende Tests werden als `known_gaps` markiert, nicht verschwiegen.
3. Nicht verifizierte Runtime-Behauptungen werden entfernt oder als Annahme markiert.
4. Task-Assignment-Evidence darf `task_assignment_completed` nur fuer abgeschlossene Assignments enthalten; nicht-terminale oder drained-queued Assignments werden als Partial Failure markiert.
5. LLM-Gateway-Streaming-Evidence darf nur als complete gelten, wenn `stream_done_seen=true` und `live_provider_calls=false` explizit bewiesen ist.

## Memory-Updater-Vertrag

`memory_updater` schreibt nur verdichtete, relevante Fakten und keine ungefilterten Rohausgaben.

Erlaubte Speicherarten:

1. Session-Metadaten
2. verifizierte Entscheidungen
3. ADR-Referenzen
4. Artefaktreferenzen
5. bekannte offene Punkte
6. Kosten- und Retry-Summen

Verboten:

1. Secrets
2. Access Tokens
3. komplette unredigierte Logs
4. sensitive Prompts ohne Klassifizierung
5. personenbezogene Daten ohne Retention-Grundlage

Bis Gate B offen ist, bleibt Persistenz als Vertrag vorbereitet und wird nicht als aktive Runtime behauptet.

## Error-Handler und Recovery

Fehlerklassen:

| Klasse | Beispiele | Erlaubte Aktion |
| --- | --- | --- |
| `transient` | Timeout, Rate-Limit, temporaerer Providerfehler | Retry bis Grenze, Fallback wenn Vertrag erlaubt |
| `structural` | fehlender Checkpointer, fehlendes Schema, unklare Schnittstelle | `hard_stop` oder Vorbereitungspaket |
| `policy` | Secret im Output, Main-Write, Budgetlimit, direkte Provider-Calls | sofortiger `hard_stop` |
| `verification` | fehlende Tests, widerspruechliche Evidenz | Nacharbeit oder `hard_stop` |

Recovery-Regeln:

1. Global maximal `5` Recovery-Zyklen pro Run.
2. Ein identischer Fehler darf maximal `2` Mal wiederholt werden.
3. Nach einem Policy-Fehler gibt es keinen automatischen Retry.
4. Nach einem Structural-Fehler darf nur ein Dokumentations- oder Planungsartefakt entstehen, keine Runtime-Aktivierung.
5. Jeder `hard_stop` braucht `hard_stop_reason`, `safe_next_step` und `evidence_refs`.

## Checkpointer-Vertrag

Production-Checkpointer:

1. PostgreSQL-kompatibel
2. restart-faehig
3. korreliert mit `run_id`
4. speichert keine Secrets
5. verschluesselt oder referenziert sensitive Inhalte nach Secrets- und Datenschutzstrategie

Nicht erlaubt:

1. In-Memory-Checkpointer in Production
2. MemorySaver als Production-Ersatz
3. Checkpoint ohne Migrationspfad
4. Checkpoint-Reset ohne Owner-Bestaetigung

Gate-Bedingung:

Die aktive Phase-1-Runtime nutzt `langgraph-checkpoint-postgres==3.0.5` fuer den deterministischen Dry-Run. Fuer Live-Provider- und Tool-State bleibt dieser Abschnitt weiterhin Vertrag und Testplan.

## Streaming-Events

Der Orchestrator sendet in Phase 1 fuer deterministische Dry-Runs bereits strukturierte SSE-Events ueber `POST /api/v1/orchestrator/dry-run/stream`:

| Event | Zeitpunkt | Mindestfelder |
| --- | --- | --- |
| `graph_status` | vor Graph-Ausfuehrung | `status`, `engine`, `mode`, `checkpointing`, `thread_id`, `run_id`, `live_provider_calls` |
| `graph_node` | nach jeder LangGraph-Node-Aktualisierung | `status`, `thread_id`, `node`, `node_name`, `run_id`, `state` |
| `done` | nach finalem Snapshot | `status`, `engine`, `mode`, `checkpointing`, `thread_id`, `run_id`, `node_name`, `state` |
| `error` | bei Stream-Fehler | `code`, `message`, `recoverable` |

Der Phase-2-Zielvertrag fuer produktive Agentenlaeufe bleibt:

| Event | Zeitpunkt | Mindestfelder |
| --- | --- | --- |
| `run.started` | nach Intent-Annahme | `run_id`, `session_id`, `timestamp` |
| `node.started` | vor Node-Ausfuehrung | `run_id`, `node_name`, `retry_count` |
| `node.completed` | nach Node-Erfolg | `run_id`, `node_name`, `evidence_refs` |
| `node.failed` | nach Node-Fehler | `run_id`, `node_name`, `error_class` |
| `run.recovered` | nach Recovery-Entscheidung | `run_id`, `from_node`, `to_node`, `reason` |
| `run.hard_stop` | kontrollierter Abbruch | `run_id`, `hard_stop_reason`, `safe_next_step` |
| `run.completed` | nur nach Verifikation | `run_id`, `evidence_refs`, `known_gaps` |

Event-Regeln:

1. Keine Secrets in Events.
2. Keine Rohproviderantworten in Events.
3. Keine technischen Dumps in der Hauptoberflaeche.
4. `run.completed` ist verboten, wenn Pflichtnachweise fehlen.

## Akzeptanztests

Diese Tests sind vor Runtime-Claim nachzuweisen:

| Test-ID | Szenario | Erwartung |
| --- | --- | --- |
| `ORCH-001` | unklarer Intent nach 2 Versuchen | `needs_clarification` oder `hard_stop` |
| `ORCH-002` | Main-Write im Intent | sofort `hard_stop` |
| `ORCH-003` | Agent Executor ueberschreitet 5 Retry-Zyklen | `hard_stop` |
| `ORCH-004` | Budget-Control lehnt ab | kein Agent startet |
| `ORCH-005` | LLM-Gateway lehnt direkte Provider-Nutzung ab | `error_handler`, danach kontrollierter Abbruch oder erlaubter Fallback |
| `ORCH-006` | Resultat ohne Evidenz | kein `run.completed` |
| `ORCH-007` | Checkpointer fehlt in Production-Konfiguration | kein Runtime-Release |
| `ORCH-008` | Server-Neustart mit Checkpoint | State-Recovery ueberlebt Neustart |
| `ORCH-009` | Policy-Fehler durch Secret-Pattern | sofort `hard_stop`, kein Retry |
| `ORCH-010` | Memory-Updater bekommt ungefiltertes Log | Reject oder Redaction, kein ungefilterter Persistenz-Write |

## Stop-Gates

Sofort stoppen bei:

1. Production-Deployment
2. Merge oder Push nach `main`
3. Architekturwechsel weg von LangGraph
4. Aktivierung eines nicht freigegebenen Checkpointers
5. Datenloeschung oder Memory-Purge
6. Secret-/Auth-Aenderung
7. direktem Provider-Call ohne Gateway
8. MCP-Bypass fuer Tool-Ausfuehrung
9. Erhoehung von Retry-, Agenten- oder Kostenlimits ohne Registereintrag

## Nicht-Behauptungen

Dieses Dokument behauptet nicht:

1. dass ein Checkpointer fuer Live-Provider- oder Tool-State aktiv ist
2. dass Server-Restart-Recovery fuer Live-Provider- oder Tool-State getestet wurde
3. dass vollstaendige Phase-2-Agentencontainer existieren
4. dass MCP-Live-Write-Tools freigegeben sind
5. dass Phase-2-Gates freigegeben sind

## Naechster sicherer Schritt

Nach diesem Vertrag ist der naechste sichere Runtime-Schritt, MCP-Tool-Envelopes in den Projekt-Auditpfad oder eine dedizierte MCP-Audit-Tabelle zu persistieren.
