# Observability Strategy

Stand: 2026-04-23
Status: Phase-1 design only

## Ziel

Observability ist ab Tag `1` Pflicht und kein spaeteres Nice-to-have.
Diese Strategie priorisiert Open Source, Budgettreue und klare Tracing-Pfade.

## Toolchain fuer Phase 1

| Ebene | Werkzeug | Rolle | Budget-/Policy-Begruendung |
| --- | --- | --- | --- |
| Traces | `Langfuse OSS` | LLM-Traces, Prompt- und Session-Observability | Open Source, produktnah fuer AI-Workflows |
| Metriken | `Prometheus` | Scraping, Metrikspeicherung, Alerts | OSS-Standard, leichtgewichtig |
| Dashboards | `Grafana OSS` | Dashboards und Alarmvisualisierung | OSS-Standard |
| Logs | strukturierte JSON-Logs plus Host-Rotation | Debug- und Audit-Logs | vermeidet fruehen Zusatzstack wie Loki |

## Bewusste Nicht-Entscheidung in Phase 1

`Loki` oder ein anderer dedizierter Log-Stack wird in `PHASE 1` bewusst nicht als Pflichtkomponente gesetzt.
Grund:

- Budgetschutz
- geringere operative Komplexitaet
- Debug- und Audit-Logs lassen sich zunaechst ueber strukturierte Logdateien mit Rotation kontrolliert halten

## Pflichtmetriken pro Schicht

Mindestens diese Werte muessen pro Schicht erhoben werden:

- Request Count
- Latenz
- Error Rate
- Memory Usage

Zielschichten:

- `nginx`
- `agent-api`
- `mcp-gateway`
- `redis`
- `postgres`
- `qdrant`
- `langfuse`
- Host-System

## Trace-Konzept

- jede eingehende Anfrage bekommt eine `x-trace-id`
- dieselbe ID wird durch `nginx`, `agent-api`, `mcp-gateway`, Queue-Events und Persistenzpfade propagiert
- `agent_sessions.trace_id` ist die relationale Bruecke zur Observability-Schicht
- Logs, Metriken und Traces muessen ueber diese ID korrelierbar bleiben

## Alarmregeln

Pflichtalarme:

- Server Down
- Error Rate groesser als `5 %`
- Budgetverbrauch groesser als `80 %`
- Memory Usage groesser als `85 %`

Alarmziele werden spaeter im echten Betrieb an Email, Chat oder Incident-Hook gebunden.
Die Routing-Ziele sind in `PHASE 1` noch kein Implementierungsgegenstand.

## Retention

- Debug-Logs: `30` Tage
- Audit-Logs: `90` Tage
- Metriken: Startwert `30` Tage in Prometheus, spaeter an Lastprofil anpassen
- Langfuse-Traces: Retention erst nach geklaerter Storage-Topologie finalisieren

## Sichtbarkeit und Sicherheit

- Grafana nicht oeffentlich ohne VPN oder gleichwertige Auth-Absicherung
- keine Secrets in Dashboards, Alert-Definitionen oder Logs
- personenbezogene Daten in Traces nur nach expliziter Freigabe und Maskierungsregel

## Phase-1-Risiko

Die offizielle Langfuse-v3-Architektur verlangt zusaetzliche Storage-Komponenten. Solange die `8`-Service-Grenze des Master-Dokuments nicht mit dieser Architektur in Einklang gebracht ist, bleibt Langfuse in `PHASE 1` ein kontrollierter Design-Baustein und kein bestaetigt lauffaehiger Runtime-Claim.

## Definition of Done fuer dieses Artefakt

Dieses Dokument ist fertig, wenn:

- Toolchain, Mindestmetriken und Alertregeln festgelegt sind
- `x-trace-id` als Pflichtsignal definiert ist
- die Budgetgrenze durch einen schlanken Log-Ansatz respektiert wird
- offene Risiken nicht kaschiert werden
