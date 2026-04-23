# MCP Toolsets Runtime Contract

Stand: 2026-04-23
Status: Prepared, not implemented
Phase: Phase 2 / WP-06
Owner-Schicht: Schicht 5 - Tool-MCP-Schicht

## Zweck

Dieser Vertrag definiert die erlaubten MCP-Toolsets fuer den ersten Runtime-Ausbau.
Er legt Request-Envelope, Rechte, Timeouts, Audit-Pflichten, Fehlerklassen und Stop-Gates fest.

Dieser Vertrag startet keine MCP-Server, keine Browser-Automation, keine E2B-Sandbox, keine Docker-Publishes, keine GitHub-Schreibaktion und keinen Datenbankzugriff.

## Verbindliche Quellen

- `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE.md`, Teil 0 bis Teil 2
- `docs/PHASE_2_IMPLEMENTATION_PLAN.md`, Abschnitt `WP-06 MCP-Toolsets`
- `docs/runtime-contracts/core-agent-profiles.md`
- `docs/runtime-contracts/langgraph-orchestrator.md`
- `docs/runtime-contracts/memory-consolidation-job.md`
- `docs/cost-policy.md`
- `docs/provider-rotation-register.md`
- `docs/verification-register.md`

## Scope

In Scope:

- GitHub-MCP fuer Branch-, PR- und Workflow-Status-Operationen
- E2B-Sandbox-MCP fuer isolierte Build- und Testausfuehrung
- Playwright-MCP fuer Browser-Smoke- und Runtime-Evidence-Flows
- Filesystem-MCP fuer streng begrenzte Workspace-Operationen
- PostgreSQL-MCP als spaeteres read-only Projektkontext-Tool nach Gate-Freigabe
- Puppeteer-MCP als zusaetzlicher Evidence-Pfad fuer UI- und Gameplay-Aufgaben
- Request-Envelope, Timeout, Audit-Event, Retry-Grenze und Fehlermodus je Toolcall

Out of Scope:

- produktiver MCP-Server-Deploy
- GitHub-Push, PR-Merge oder direkter Schreibzugriff auf `main`
- Produktionsdatenbank-Schreibzugriff oder Schema-Migration
- Secret-Provisioning, Auth-Konfiguration oder Token-Rotation
- Live-Browser-Validierung mit echten Credentials
- Docker-Image-Publish oder Registry-Push
- lokale Sonderpfade als Ersatz fuer Cloud-/Sandbox-Ausfuehrung

## Tool-Request-Envelope

Jeder Toolcall muss vor Ausfuehrung einen validierten Request-Envelope besitzen.

Pflichtfelder:

- `tool_request_id`: eindeutige ID fuer Audit und Retry-Zuordnung
- `run_id`: Orchestrator-Run oder Task-Run
- `agent_role`: aufrufender Agent aus dem erlaubten Rollenprofil
- `toolset`: erlaubtes Toolset, zum Beispiel `github`, `e2b`, `playwright`, `filesystem`
- `capability`: konkrete erlaubte Aktion innerhalb des Toolsets
- `intent_summary`: kurze Zweckbeschreibung ohne Secrets
- `input_ref`: Referenz auf Eingaben statt ungefilterter Rohdaten
- `allowed_scope`: Branch, Workspace, URL, Sandbox oder read-only Datenbereich
- `timeout_ms`: harte obere Laufzeitgrenze
- `retry_budget`: verbleibende Retry-Anzahl fuer diesen Toolcall
- `idempotency_key`: Pflicht bei Schreiboperationen
- `audit_tags`: Kosten-, Sicherheits- und Evidenz-Tags
- `redaction_required`: ob Eingaben vor Logging zwingend redigiert werden muessen
- `expected_output_type`: erwarteter Ergebnistyp

## Tool-Result-Envelope

Jeder Toolcall muss nach Ausfuehrung ein Ergebnis im folgenden Format liefern.

Pflichtfelder:

- `status`: `success`, `degraded`, `blocked`, `timeout` oder `failed`
- `result_ref`: Referenz auf Ergebnis oder Artefakt
- `audit_event_id`: zugehoeriges Audit-Event
- `duration_ms`: gemessene Laufzeit
- `cost_event_ref`: Kostenreferenz oder `none`
- `sanitized_summary`: kurze geheimefreie Zusammenfassung
- `error_class`: Fehlerklasse oder `none`
- `retry_after_ms`: empfohlene Wartezeit oder `0`
- `rollback_note`: Rueckrollhinweis fuer Schreiboperationen
- `evidence_ref`: Verifikationsartefakt oder `none`

## Toolsets

| Toolset | Primaerer Besitzer | Erlaubt | Verboten | Timeout | Fehlermodus |
| --- | --- | --- | --- | --- | --- |
| GitHub-MCP | Coder, DevOps | Branch- und PR-Arbeit auf `feature/agent-*`, Draft-PRs, Workflow-Status lesen | `main` schreiben, mergen, ungeschuetzter Push, Secrets hochladen, Branch destruktiv loeschen ohne Gate | `30000 ms` read, `90000 ms` write | `blocked` bei Auth, Branch-Schutz oder Scope-Verletzung |
| E2B-Sandbox-MCP | Tester | isolierte Build-/Testausfuehrung, Logs und Artefakte lesen, Sandbox beenden | lokale Ausfuehrung als Ersatz, Secret-Exfiltration, Produktionscredentials, persistente Sandbox ohne TTL | `30000 ms` setup, `120000 ms` execution | `degraded` oder `test-blocked` bei Timeout |
| Playwright-MCP | Tester | Smoke-Flows, Screenshots, Text- und Statuspruefung gegen freigegebene Cloud-/Preview-URLs | Localhost-only Evidence, Credential Capture, persistente Browserprofile | `60000 ms` scenario | `evidence-blocked` bei fehlender Runtime-Evidence |
| Filesystem-MCP | Coder, DevOps | Temp-Workspace, repo-begrenzte geplante Patch-Staging-Pfade | Secret-Pfade, User-Home, Main-Bypass, unprotokollierte Bulk-Copy | `20000 ms` read, `60000 ms` write | `blocked` bei Scope-Verletzung |
| PostgreSQL-MCP | Planner, Tester | read-only Projektkontext nach Schema- und Auth-Gate | Production-Write, Schema-Migration, direkter DB-Zugriff ausserhalb MCP | `30000 ms` query | `blocked` bis Gate erfuellt |
| Puppeteer-MCP | Tester, Sentinel Runtime | zweiter Browser-Evidence-Pfad fuer UI-/Gameplay-Aufgaben | Ersatz fuer Playwright-Evidence, Secret Capture, Profilpersistenz | `60000 ms` scenario | `evidence-blocked` bei Sentinel-Ablehnung |

## Globale Garantien

- Kein Toolcall ohne Request-Envelope.
- Kein Toolcall ohne `timeout_ms`.
- Kein Toolcall ohne Audit-Event vor und nach der Ausfuehrung.
- Kein Toolcall darf Secrets in Argumente, Logs, Screenshots oder Artefakte schreiben.
- Kein Toolcall darf eine lokale Sonderroute als Ersatz fuer die definierte Cloud-/Sandbox-Schicht nutzen.
- Jeder Fehler muss als `blocked`, `timeout`, `failed` oder `degraded` sichtbar werden.
- `degraded` ist kein Fertig-Status und darf nicht als Completion-Claim verwendet werden.
- Tool-Retries muessen durch `retry_budget` begrenzt sein.
- Tool-Zyklen duerfen das globale Maximum von `5` kontrollierten Cycles nicht ueberschreiten.
- Scope-Verletzungen stoppen den Task und erzeugen einen Review-Gate-Eintrag.

## Agentenrechte

| Agent | GitHub | E2B | Playwright | Filesystem | PostgreSQL | Puppeteer |
| --- | --- | --- | --- | --- | --- | --- |
| Planner | nein | nein | nein | nein | read-only nach Gate | nein |
| Coder | `feature/agent-*`, Draft-PR | nein | nein | repo/temp scoped | nein | nein |
| Tester | status read nur delegiert | ja | ja | test-artifact scoped | read-only nach Gate | conditional fuer UI/Game |
| DevOps | workflow/status read, config PR | nein | health-check delegiert | config read scoped | nein | nein |

Rechteausweitungen sind Architektur- und Sicherheitsentscheidungen.
Sie brauchen ADR oder explizite Owner-Freigabe.

## Retry-, Timeout- und Fehlermodus

- Maximal `2` Retries pro Toolcall.
- Maximal `5` Tool-Cycles pro Run-Segment.
- Auth-, Secret-, Permission- und Branch-Protection-Fehler duerfen nicht automatisch retried werden.
- Timeouts muessen kontrolliert abbrechen und ein `timeout` Ergebnis liefern.
- Schreiboperationen brauchen `idempotency_key` und `rollback_note`.
- Fehlende Evidence erzeugt `evidence-blocked`, nicht `success`.
- Unbekannte Tool-Antworten werden als `failed` klassifiziert.

## Audit-Event

Jedes Audit-Event muss mindestens enthalten:

- Zeitstempel
- `run_id`
- `tool_request_id`
- aufrufender Agent
- Toolset und Capability
- geheimefreie Eingabereferenz
- Scope-Hash oder Scope-Beschreibung
- Entscheidung: erlaubt, blockiert, timeout, failed oder degraded
- Dauer
- Fehlerklasse
- Evidence-Referenz
- Kostenreferenz oder `none`

## Security

- Secrets duerfen nie direkt im Request-Envelope, Result-Envelope, Audit-Event oder Evidence-Artefakt stehen.
- Credentials duerfen nur als Vault-/Secret-Referenz in einer freigegebenen Runtime erscheinen.
- Token, die ausserhalb eines Secret-Gates offengelegt wurden, duerfen nicht verwendet werden.
- Falls GitHub-Authentifizierung benoetigt wird, muss sie ueber einen sicheren Secret-Gate neu provisioniert werden.
- Browser-Tools duerfen keine Session-Cookies, Tokens oder Passwoerter persistieren.
- Filesystem-Tools muessen Pfade gegen den erlaubten Workspace aufloesen und Scope-Verletzungen blockieren.

## Akzeptanztests

| ID | Nachweis | Erwartung |
| --- | --- | --- |
| MCP-001 | Toolcall ohne Envelope | wird vor Ausfuehrung blockiert |
| MCP-002 | Envelope ohne Timeout | wird vor Ausfuehrung blockiert |
| MCP-003 | GitHub-Write auf `main` | wird blockiert und eskaliert |
| MCP-004 | GitHub-Write auf `feature/agent-*` | nur mit Audit und Idempotency erlaubt |
| MCP-005 | E2B-Ausfuehrung ueber Timeout | bricht kontrolliert mit `timeout` ab |
| MCP-006 | Playwright gegen `localhost` als alleinige Evidence | wird unter Projektconstraints blockiert |
| MCP-007 | Filesystem ausserhalb erlaubtem Scope | wird blockiert |
| MCP-008 | PostgreSQL-Write oder Schema-Migration | wird blockiert |
| MCP-009 | Secret-aehnliche Eingabe | wird redigiert oder blockiert vor Logging |
| MCP-010 | Mehr als `2` Retries pro Toolcall | wird blockiert |
| MCP-011 | Tool-Ergebnis `degraded` | darf nicht als fertig gelten |
| MCP-012 | UI-/Gameplay-Task ohne Browser-Evidence | bleibt `evidence-blocked` |

## Stop-Gates

Sofortiger Halt mit Review-Gate ist Pflicht bei:

- GitHub-Push oder Merge nach `main`
- Production-Deployment
- Docker-Image-Publish oder Registry-Push
- Secret-, Auth- oder Rechteaenderung
- Toolrechte-Erweiterung
- destruktiver Datei-, Branch- oder Datenbankoperation
- Datenbank-Write, Schema-Migration oder Memory-Purge
- Browser-Validierung mit echten Credentials
- fehlendem Audit-Event oder fehlendem Timeout
- lokaler Fallback-Ausfuehrung statt Cloud-/Sandbox-Pfad

## Nicht-Behauptungen

- Es ist kein MCP-Server live verdrahtet.
- Es wurde keine E2B-Sandbox gestartet.
- Es wurde keine Browser-Automation ausgefuehrt.
- Es wurde keine GitHub-Schreiboperation ausgefuehrt.
- Es wurde kein Docker-Image gepusht.
- Es wurde kein Filesystem-MCP verbunden.
- Es wurde keine Datenbank verbunden.

## Naechster sicherer Schritt

Nach diesem Vertrag folgt eine Phase-2-Readiness-Matrix, die alle Runtime-Vertraege gegen Tests, Evidence-Artefakte und offene Stop-Gates abgleicht.
