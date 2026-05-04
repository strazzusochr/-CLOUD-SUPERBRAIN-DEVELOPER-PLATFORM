# Core Agent Profiles Contract

Status: Prepared contract, Phase-1 deterministic worker scaffold verified
Datum: 2026-04-26
Phase: Phase 2 / WP-04
Owner-Schicht: Schicht 3 - Agent-Pool

## Zweck

Dieser Vertrag definiert die vier MVP-Kern-Agenten als Runtime-Policy, bevor Container, LLM-Calls oder MCP-Toolausfuehrung aktiviert werden.
Er uebersetzt `TEIL 2` in klare Rollen, Toolrechte, Zeitgrenzen, Output-Formate, Memory-Regeln und Stop-Gates.

Dieser Vertrag ist kein Implementierungsnachweis fuer produktive Live-Agentenlaeufe. Phase 1 verfuegt jedoch ueber einen deterministic `agent-worker`-Scaffold, der Planner-Tasks aus Redis konsumiert, Ergebnisse persistiert, Retry/Eskalation prueft und per Redis-Heartbeat in Agent-API Health/Metrics sichtbar ist.

## Bindende Quellen

- `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE.md`, besonders `TEIL 0`, `TEIL 1` und `TEIL 2`
- `docs/PHASE_2_IMPLEMENTATION_PLAN.md`, Abschnitt `WP-04 Kern-Agenten-Profile`
- `docs/runtime-contracts/budget-rate-control.md`
- `docs/runtime-contracts/llm-gateway-routing.md`
- `docs/runtime-contracts/langgraph-orchestrator.md`
- `docs/cost-policy.md`
- `docs/provider-rotation-register.md`
- `docs/secrets-strategy.md`

## Scope

In Scope:

- Vier MVP-Agenten: Planner, Coder, Tester, DevOps
- Rollen, erlaubte Tools, verbotene Aktionen, Zeitlimits und Eskalationsbedingungen
- Gemeinsames Agent-Output-Envelope fuer Result-Aggregator und Memory-Updater
- Toolrechte-Matrix fuer Schicht 3 gegen Schicht 4, 5 und 6
- Akzeptanztests fuer Policy- und Gate-Verhalten

Nicht in Scope:

- Produktive Live-Agent-Container mit echten LLM-Provider-Calls bauen oder starten
- LLM-Provider aufrufen
- MCP-Server ausfuehren
- GitHub Branch-Protection oder Secrets aendern
- Production-Deployments ausloesen
- Main-Branch beschreiben

## Globale Squad-Regeln

1. Das MVP-Squad besteht aus genau vier Agenten: Planner, Coder, Tester und DevOps.
2. Agenten kommunizieren nicht direkt miteinander, sondern nur ueber Orchestrator-State, Task-Packages und Result-Objekte.
3. Jeder LLM-Call muss ueber Budget-/Rate-Control und danach ueber das LLM-Gateway laufen.
4. Direkte Provider-SDKs, direkte Provider-HTTP-Calls und Provider-Secrets in Agent-Containern sind verboten.
5. Tool-Calls laufen ausschliesslich ueber MCP mit Request-Logging, Timeout und erlaubtem Toolscope.
6. Kein Agent darf auf `main` schreiben, force-pushen, Production deployen oder Secrets/Auth-Konfigurationen aendern.
7. Kein Agent darf direkt in Production-Datenbanken schreiben.
8. Loops brauchen harte Retry-Zaehler; ein Retry ohne neue Evidenz zaehlt als fehlgeschlagener Versuch.
9. Jede Agentenantwort enthaelt Evidenz, Unsicherheiten, naechste sichere Aktion und bei Aenderungen einen Rollback-Hinweis.
10. Fehlende Evidenz fuehrt zu `blocked` oder `rejected`, nicht zu `done`.

## Agent-Output-Envelope

Jeder Agent liefert ein strukturiertes Ergebnis an den Result-Aggregator.
Freitext allein ist nicht ausreichend.

```json
{
  "agent_id": "planner",
  "role": "planner",
  "task_id": "phase-2-wp04-example",
  "status": "completed|blocked|failed|needs_review",
  "summary": "Kurze, evidenzbasierte Zusammenfassung.",
  "artifacts": [
    {
      "type": "file|diff|test-log|trace|report",
      "path": "docs/example.md",
      "description": "Was dieses Artefakt belegt."
    }
  ],
  "evidence_refs": [
    "verification-register:2026-04-23:example"
  ],
  "memory_write": {
    "allowed": true,
    "classification": "working|long_term_candidate|test_artifact",
    "content_summary": "Keine Secrets, keine Roh-Credentials."
  },
  "cost_event_ref": "budget-event-id-or-null",
  "uncertainties": [
    "Annahme oder offener Punkt, falls vorhanden."
  ],
  "blocked_by": [
    "Stop-Gate oder fehlende Evidenz, falls vorhanden."
  ],
  "next_safe_action": "Naechster Schritt ohne Gate-Verletzung.",
  "rollback_note": "Wie die Aenderung rueckgaengig gemacht werden kann oder warum nicht relevant."
}
```

## Agentenprofile

### Planner-Agent

Agent-ID: `planner`
Rolle: Intent parsen, Task-Plan erstellen, Squad zuweisen.
Modellslot: `planner`.
Erlaubte Modelle: Claude Sonnet 4.6 oder GPT-4o, nur ueber Gateway und nur nach Budgetentscheidung.
Erlaubte Tools: Memory-Read, interner Task-Router.
Verbotene Aktionen: Code schreiben, Dateien veraendern, GitHub-Schreibzugriffe, Deploy-Aktionen, direkte Tool-Calls ohne Orchestrator.
Max-Execution-Time: 60 Sekunden.
Max-Retries: 2 Intent-Klaerungsversuche.
Input: User-Intent, Run-Kontext, Memory-Suchtreffer, aktive Stop-Gates.
Output: priorisierter Task-Plan mit Agentenzuweisung, Unsicherheiten und Stop-Gate-Markierungen.
Memory-State: Run-Ziel, priorisierte Arbeitspakete, offene Blocker.
Eskalation: Intent bleibt nach 2 Versuchen unklar oder ein Stop-Gate wird erkannt.

### Coder-Agent

Agent-ID: `coder`
Rolle: Runtime- und Integrationsaenderungen in kontrollierten Arbeitskontexten umsetzen.
Modellslot: `coder`.
Erlaubte Modelle: DeepSeek-Chat oder Claude Haiku 4.5, nur ueber Gateway.
Erlaubte Tools: GitHub-MCP fuer Branch-/PR-Arbeit, Filesystem-MCP im freigegebenen Workspace, Memory-Read.
Verbotene Aktionen: Push auf `main`, Force-Push, Production-Deploy, direkte DB-Schreiboperationen ausserhalb freigegebener App-Pfade, Secret-Erzeugung im Repo.
Max-Execution-Time: 300 Sekunden.
Max-Output-Tokens: 8192.
Max-Retries: 5 Build-/Patch-Zyklen.
Input: Task-Package mit Write-Scope, betroffene Dateien, Akzeptanzkriterien und verbotene Aktionen.
Output: Diff-/Artefaktliste, Implementierungsnotiz, offene Compiler-/Lintfehler, Rollback-Hinweis.
Memory-State: geaenderte Dateien, letzter erfolgreicher Diff, offene Compiler-/Lintfehler.
Eskalation: 5 Retry-Cycles ohne stabilen Build oder Aenderung wuerde Policy verletzen.

### Tester-Agent

Agent-ID: `tester`
Rolle: Laufzeit-, Integrations- und Smoke-Validierung durchfuehren, Fehler sauber klassifizieren.
Modellslot: `tester`.
Erlaubte Modelle: GPT-4o-Mini oder Groq Llama, nur ueber Gateway.
Erlaubte Tools: E2B-Sandbox-MCP, Playwright-MCP, Memory-Read, Memory-Write fuer Testartefakte.
Verbotene Aktionen: produktive Schreibzugriffe, GitHub-Push, stilles Ueberspringen fehlgeschlagener Tests, offene E2B-Session im Fehlerfall.
Max-Execution-Time: 600 Sekunden.
Max-Retries: 5 Repro-/Validierungszyklen fuer denselben Fehler.
Input: Testauftrag, Artefaktliste, erwartete Checks, Rollback-Hinweis des Coder-Agenten.
Output: Teststatus, Logs, Repro-Schritte, Severity, fehlgeschlagene Checks und naechster Fixpfad.
Memory-State: Testartefakte, Bug-Reports, Severity und Repro-Schritte.
E2B-Regel: Jede Session muss im Erfolgs- und Fehlerfall sauber geschlossen werden.
Eskalation: derselbe Fehler tritt 5 Mal ohne verwertbaren Fixpfad auf.

### DevOps-Agent

Agent-ID: `devops`
Rolle: Laufzeitkonfigurationen, Workflow-Zustaende und Rollback-Bereitschaft bewerten.
Modellslot: `devops`.
Erlaubte Modelle: GPT-4o-Mini, nur ueber Gateway.
Erlaubte Tools: GitHub-MCP lesend, Filesystem-MCP lesend, interne Health-Checks.
Verbotene Aktionen: direkte Production-Aenderungen, Secret-Rotation ohne Approval, Deployment-Trigger ohne Human-Gate, Rechteausweitung ohne ADR/Owner-Gate.
Max-Execution-Time: 120 Sekunden.
Max-Retries: 3 Health-/Pipeline-Statuspruefungen.
Input: Workflow-Status, Infrastrukturartefakte, Rollback-Anforderungen, aktive Gates.
Output: Health-Bewertung, Pipeline-/Konfigurationsrisiken, Rollback-Bereitschaft und Blocker.
Memory-State: letzter Workflow-Status, Health-Checks, bekannte Rollback-Pfade.
Eskalation: Health-Check rot, Pipeline scheitert 3 Mal oder Rollback ist nicht nachweisbar.

## Toolrechte-Matrix

| Tool / Aktion | Planner | Coder | Tester | DevOps |
| --- | --- | --- | --- | --- |
| Memory-Read | erlaubt | erlaubt | erlaubt | erlaubt |
| Memory-Write | nur Plan-Summary via Orchestrator | nur Diff-/Fehler-Summary via Orchestrator | erlaubt fuer Testartefakte | erlaubt fuer Health-Summary via Orchestrator |
| Interner Task-Router | erlaubt | verboten | verboten | verboten |
| LLM-Gateway | erlaubt | erlaubt | erlaubt | erlaubt |
| Direkter Provider-Call | verboten | verboten | verboten | verboten |
| GitHub-MCP lesend | verboten | erlaubt im Task-Scope | verboten | erlaubt |
| GitHub-MCP schreibend | verboten | nur Feature-/PR-Scope, nie `main` | verboten | verboten |
| Filesystem-MCP lesend | verboten | erlaubt im Write-Scope | erlaubt fuer Testartefakte | erlaubt |
| Filesystem-MCP schreibend | verboten | erlaubt im Write-Scope | nur Temp-Testartefakte | verboten |
| E2B-Sandbox-MCP | verboten | verboten | erlaubt | verboten |
| Playwright-MCP | verboten | verboten | erlaubt | verboten |
| Deployment-Trigger | verboten | verboten | verboten | verboten |
| Secret-/Auth-Aenderung | verboten | verboten | verboten | verboten |
| Production-DB-Write | verboten | verboten | verboten | verboten |

## Task-Package-Mindestfelder

Der Orchestrator darf einen Agenten nur starten, wenn das Task-Package diese Felder enthaelt:

```json
{
  "task_id": "phase-2-wp04-example",
  "owner_role": "coder",
  "goal": "Konkretes Ziel ohne versteckte Gate-Entscheidung.",
  "allowed_tools": ["filesystem_mcp", "github_mcp"],
  "write_scope": ["docs/runtime-contracts/"],
  "blocked_actions": ["push_main", "prod_deploy", "secret_change"],
  "acceptance_criteria": ["Artefakt existiert", "Secret-Scan ohne Treffer"],
  "verification_required": true,
  "parallelizable": false,
  "max_iterations": 5
}
```

Fehlt `write_scope` bei einem schreibenden Task, muss der Agent-Executor den Lauf vor Start blockieren.

## Retry-, Timeout- und Eskalationsregeln

| Agent | Timeout | Retry-Limit | Harte Eskalation |
| --- | --- | --- | --- |
| Planner | 60s | 2 Intent-Versuche | Intent unklar oder Stop-Gate erkannt |
| Coder | 300s | 5 Patch-/Build-Zyklen | Build bleibt instabil oder Policy-Verletzung waere noetig |
| Tester | 600s | 5 Repro-/Validierungszyklen | Fehler bleibt ohne Fixpfad oder E2B-Cleanup scheitert |
| DevOps | 120s | 3 Health-/Pipeline-Pruefungen | Health rot, Pipeline dreimal fehlgeschlagen oder Rollback fehlt |

Jede Retry-Iteration muss den Grund, neue Evidenz und veraenderte Hypothese dokumentieren.

## Orchestrator-Integration

1. `Task-Router` erzeugt pro Agent ein Task-Package mit Rolle, Toolrechten, Write-Scope und Akzeptanzkriterien.
2. `Agent-Executor` prueft Toolrechte gegen diese Matrix, bevor ein Agent gestartet wird.
3. `Agent-Executor` blockiert jeden Tool-Call, der nicht im Task-Package und in der Matrix erlaubt ist.
4. `Result-Aggregator` akzeptiert nur Ergebnisse im Agent-Output-Envelope.
5. `Memory-Updater` schreibt nur klassifizierte, secret-freie Summaries und keine Roh-Credentials.
6. `Error-Handler` eskaliert bei Retry-Ueberschreitung, Stop-Gate oder fehlender Evidenz.

## Phase-1 Runtime-Scaffold-Beweis

- `services/agent-worker` laeuft als separater Compose-Service und konsumiert Redis-Tasks aus `tasks:agent:queue`.
- Der Worker schreibt Taskstatus in Redis, Planner-Ergebnisse in `agent_messages`, `task_completed`/`task_retry`/`task_escalated` in `audit_log` und nutzt keine LLM-Provider.
- Der Worker schreibt `agent-worker:heartbeat` nach Redis; `GET /api/v1/health` meldet diesen Puls als `agent_worker.status=healthy`, und `GET /api/v1/metrics` exportiert `superbrain_service_health{service="agent_worker"} 1`.
- `scripts/verify-phase1-runtime.ps1` und `scripts/verify-hosted-staging.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` pruefen Prompt->Task->Worker, Retry/Eskalation, Heartbeat, SSE-Ausgabe und Persistenz.

## Budget- und Modellrouting

- Jeder Modellslot nutzt zuerst `budget-rate-control.md`.
- Danach nutzt jeder Modellslot `llm-gateway-routing.md`.
- GPT-4o fuer alle Agenten ist verboten.
- Planner darf teurere Modelle nur mit dokumentierter Budgetentscheidung nutzen.
- Coder, Tester und DevOps nutzen budgetfreundliche Defaults, solange keine Gate-Freigabe etwas anderes erlaubt.
- Cost-Events muessen im Output-Envelope referenziert werden, sobald reale LLM-Calls aktiviert sind.

## Memory-Regeln

- Memory-Write enthaelt nur Summaries, Artefaktreferenzen und Klassifikationen.
- Secrets, Tokens, Private Keys, Roh-Credentials und ungepruefte personenbezogene Daten duerfen nicht gespeichert werden.
- Memory-Purge ist ein Owner-Gate.
- Working-Memory darf fuer Phase 2 nur mit TTL und Checkpoint-Regel genutzt werden.
- Long-Term-Memory-Konsolidierung bleibt bis WP-05 ein separater Vertrag.

## Akzeptanztests

| ID | Szenario | Erwartung |
| --- | --- | --- |
| AGENT-001 | Planner versucht Datei zu schreiben | Tool-Call wird vor Ausfuehrung abgelehnt |
| AGENT-002 | Coder versucht Push auf `main` | Lauf geht auf `hard_stop` |
| AGENT-003 | Tester markiert fehlgeschlagenen Test als uebersprungen | Result-Aggregator lehnt Ergebnis ab |
| AGENT-004 | DevOps versucht Deployment-Trigger | Lauf geht auf `hard_stop` und Owner-Gate wird markiert |
| AGENT-005 | Ein Agent nutzt direkten Provider-Call | Gateway-Policy lehnt ab |
| AGENT-006 | Tool liegt ausserhalb der Toolrechte-Matrix | Agent-Executor blockiert vor Ausfuehrung |
| AGENT-007 | Retry-Limit wird erreicht | Error-Handler eskaliert mit Blocker-Report |
| AGENT-008 | Output enthaelt keine Evidenz | Result-Aggregator setzt Status `rejected` |
| AGENT-009 | Memory-Write enthaelt Secret-Muster | Memory-Updater lehnt ab und markiert Redaction erforderlich |
| AGENT-010 | Coder-Task hat keinen `write_scope` | Agent-Executor startet den Agenten nicht |
| AGENT-011 | Planner laeuft in Timeout | partieller Plan mit Unsicherheitsmarkierung und Fehlerstatus |
| AGENT-012 | Tester schliesst E2B-Session nicht | Verifikation schlaegt fehl und Lauf wird blockiert |

## Stop-Gates

Diese Aktionen stoppen die autonome Ausfuehrung und brauchen Owner-Review:

- Production-Deployment oder Deployment-Trigger
- Merge, Push oder direkter Schreibzugriff auf `main`
- Force-Push oder destruktive Git-Operationen
- Secret-, Auth-, Token- oder Rechteaenderungen
- Memory-Purge, Datenloeschung oder direkter Production-DB-Write
- Toolrechte-Erweiterung fuer einen Agenten
- Wechsel vom 4-Agenten-MVP auf mehr Agenten
- Aenderung von Modell-Defaults, Budgetlimits oder Gateway-Bypass
- Aktivierung echter Agent-Container, MCP-Server oder produktiver LLM-Calls

## Nicht-Behauptungen

- Dieser Vertrag implementiert keine Agent-Runtime.
- Es wurden keine produktiven Live-Agenten mit echten LLM-Calls gestartet; der Phase-1 `agent-worker`-Scaffold ist gestartet und verifiziert.
- Es wurden keine MCP-Tool-Calls ausgefuehrt.
- Es wurden keine LLM-Provider aufgerufen.
- Es wurden keine Secrets erstellt, rotiert oder gespeichert.
- Es wurden keine UI-, Browser- oder Production-Tests ausgefuehrt.
- Phase 2 ist dadurch nicht release-ready.

## Naechster sicherer Schritt

Der naechste autonome Schritt ist die Erweiterung vom deterministic Planner-Worker zum vollstaendigen LangGraph-Agent-Executor mit denselben Heartbeat-, Retry-, Audit- und Budget-Gates.
