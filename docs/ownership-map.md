# Ownership Map

Stand: 2026-04-23
Status: Draft fuer Phase 0
Bezug: `docs/monorepo-structure.md`, `TEIL 10`

## 1. Zweck

Diese Karte ordnet jeder der sieben Schichten primaere Verantwortung, typische Entscheidungen und Review-Beteiligung zu. Sie verhindert unklare Zustandswechsel und stille Grenzueberschreitungen.

## 2. 7-Layer Ownership

| Schicht | Primaere Verantwortung | Typische Entscheidungen | Pflicht-Review bei Risiko |
| --- | --- | --- | --- |
| `frontend/` | UX, Prompt-Flow, Streaming, 3D-Client | UI-Flows, Render-Fallback, Session-Darstellung | Architektur, Runtime, Security |
| `backend/` | API, Auth, Orchestrierung, GitHub-Integration | Endpunkte, Session-Flow, Review-Gates | Security, Architektur, Deployment |
| `agents/` | Rollen, Task-Policies, Retry- und Review-Logik | Squad-Groesse, Task-Verteilung, Stop-Regeln | Kosten, Security, Architektur |
| `mcp/` | Tool-Adapter und Zugriffsgrenzen | Timeouts, Tool-Vertraege, Fehlermodi | Security, Runtime |
| `infrastructure/` | Deploy, Runtime, CI/CD, Rollback | Hosting-Pfade, Pipeline-Gates, Rollback | Owner, Security, Kosten |
| `memory/` | Speicherlogik, Retrieval, Retention | Datenmodell, TTL, Zusammenfassungen | Security, Architektur |
| `observability/` | Evidence, Traces, Kosten, Alerts | Signalquellen, Metriken, Alarme | Runtime, Kosten |

## 3. Querschnittsrollen

| Rolle | Verantwortung ueber Schichten hinweg |
| --- | --- |
| Owner | Freigaben, Budget, kritische Gates, Main-Merge |
| Planner | Reihenfolge, Scope, Zielabgleich gegen Goal Lock |
| Reviewer | Risiko-, Regressions- und Gate-Pruefung |
| Security | Secrets, Auth, Least-Privilege, Logging-Grenzen |
| Runtime / QA | Verifikation, Smoke-Flows, Evidence, Rollback-Hinweise |

## 4. Eskalationspflichten

1. `frontend` darf keine direkte Provider- oder Secret-Logik einfuehren.
2. `backend` darf Auth- oder Datenfluesse nicht ohne Review-Gate aendern.
3. `agents` duerfen keine neuen ungebremsten Schleifen oder autonomen Main-Pfade einfuehren.
4. `mcp`-Aenderungen mit Datei-, Browser-, Cloud- oder Git-Schreibzugriff brauchen explizite Verifikation.
5. `infrastructure` bleibt an Human-Review vor Production und Main gebunden.

## 5. Verifikation

Diese Ownership Map gilt fuer Phase 0 als ausreichend, wenn:

1. alle sieben Pflichtschichten abgedeckt sind,
2. primaere Verantwortung klar getrennt ist,
3. Risikofelder mit Review-Pflichten benannt sind,
4. keine Schicht still Main-, Secret- oder Deploy-Rechte erhaelt.
