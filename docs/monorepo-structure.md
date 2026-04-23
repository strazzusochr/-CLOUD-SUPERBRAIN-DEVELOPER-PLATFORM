# Monorepo Structure

Stand: 2026-04-23
Status: Draft fuer Phase 0
Bezug: `TEIL 0`, `PHASE 0`, `TEIL 10`

## 1. Ziel

Dieses Dokument definiert die geplante Monorepo-Struktur fuer das Repository `-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`. `D:\PLATTFORM` ist nur der lokale Workspace-Pfad. Es beschreibt Verantwortungen, Grenzziehungen und Schnittstellen, bevor Produktcode entsteht.

## 2. Leitprinzipien

1. Kein `localhost` als Betriebsannahme.
2. Keine lokalen Modell-Downloads, nur API-Inferenz.
3. Multi-Agent-Ausfuehrung wird als cloud-native Systemfaehigkeit geplant.
4. Observability ist eine eigene Schicht und nicht Teil der Main-App.
5. Die Struktur muss von `4` auf `4 -> inf` Agenten erweiterbar bleiben.
6. Das MVP darf das Infrastruktur-Budget von `20 EUR/Monat` nicht brechen.

## 3. Geplante Top-Level-Struktur

```text
/
|- frontend/
|- backend/
|- agents/
|- mcp/
|- infrastructure/
|- memory/
|- observability/
|- docs/
```

## 4. Schichtbeschreibung

### `frontend/`

Verantwortung:
Prompt-Interface, Streaming-UI, Squad-Steuerung, Verlauf, Memory-Ansicht, 3D-Webgame-Client, Session-Steuerung.

Regeln:
- Dark Mode Standard.
- `shadcn/ui` als UI-Basis.
- WebGPU bevorzugt, WebGL-Fallback verpflichtend.
- Keine Logik fuer Secrets, keine direkte Provider-Bindung.

### `backend/`

Verantwortung:
API-Gateway, Session-Orchestrierung, Prompt-Routing, Agent-Lifecycle, GitHub-Integration, CI/CD-Hooks, Auth, Audit-Events.

Regeln:
- JWT-basierte Auth.
- Provider-Zugriffe nur ueber Gateway-Schicht.
- Keine UI-spezifische Logik.

### `agents/`

Verantwortung:
Agentenrollen, Squad-Koordination, Task-Policies, Iterationslimits, Supervisor-Gates, Reporting-Templates.

Regeln:
- Default-Squad fuer MVP: `4` Agenten.
- Kein Agent ohne klares Task-Ownership.
- Keine Endlosschleifen; jede Strategie braucht Iterationslimit und Abbruchbedingung.

### `mcp/`

Verantwortung:
Tool-Adapter, MCP-Server-Definitionen, Tool-Discovery, Sicherheitsgrenzen fuer Datei-, Browser-, Git- und Cloud-Zugriffe.

Regeln:
- Tool-Aufrufe sind nachvollziehbar zu loggen.
- Secrets duerfen nie ueber MCP-Antworten in Logs landen.
- Jeder produktive Tool-Pfad braucht Timeouts und Fehlermodi.

### `infrastructure/`

Verantwortung:
Deploy-Definitionen, Cloud-Runtime, GitHub Actions, Runtime-Konfiguration, Budget-Gates, Rollback-Strategien.

Regeln:
- Kein direkter Schreibpfad nach `main`.
- Kein Deployment ohne Pipeline-Nachweis.
- Infrastruktur muss mit dem `20 EUR/Monat`-Limit kompatibel bleiben.

### `memory/`

Verantwortung:
Kurzzeit-, Arbeits- und Langzeitgedaechtnis, Vektorindex, Zusammenfassungen, Retrieval-Policies, Retention-Regeln.

Regeln:
- Dreischichtige Memory-Strategie.
- Speicherung nur mit klarer TTL- oder Retention-Regel.
- Kein unbeschraenktes Kontextwachstum.

### `observability/`

Verantwortung:
Tracing, Metriken, Logs, Run-Evidence, Kosten- und Limit-Tracking, Alerting.

Regeln:
- Eigene Schicht, nicht in Main-App versteckt.
- Jedes Release braucht Observability-Anbindung.
- Produktionsrelevante Claims brauchen Evidence.

## 5. Ownership Map auf hoher Ebene

| Schicht | Primaere Verantwortung | Sekundaere Verantwortung |
| --- | --- | --- |
| `frontend/` | UX, Streaming, 3D-Client | Auth-Integration, Session-Darstellung |
| `backend/` | API, Auth, Orchestrierung | Audit, GitHub, Webhooks |
| `agents/` | Rollen, Policies, Squad-Flow | Reporting, Retry-Gates |
| `mcp/` | Tool-Schicht | Laufzeitgrenzen, Tool-Sicherheit |
| `infrastructure/` | Deploy, Runtime, CI/CD | Rollback, Kosten-Gates |
| `memory/` | Retrieval, Vektorlogik, Retention | Summaries, Session-Wissen |
| `observability/` | Telemetrie, Evidence, Alerts | Kostenhistorie, SLA-Signale |

## 6. Erwartete Hauptschnittstellen

1. `frontend -> backend`
Prompt-, Session- und Streaming-API fuer Nutzerinteraktionen.

2. `backend -> agents`
Aufgaben, Rollensteuerung, Review-Gates, Ergebnisaggregation.

3. `backend -> mcp`
Werkzeugnutzung fuer GitHub, Browser, Dateisystem, Deployment, Analyse.

4. `backend -> memory`
Lesen, Schreiben, Verdichten, Abrufen von Projekterinnerungen.

5. `backend -> observability`
Traces, Kosten, Fehler, Agentenlauf-Evidence.

6. `infrastructure -> backend/frontend/observability`
Build-, Deploy-, Secret- und Runtime-Konfiguration.

## 7. Nicht Teil der Monorepo-Startphase

1. Lokale Desktop-App
2. Eigenes Modelltraining
3. Vollstaendiges Kubernetes vor Phase 6
4. GPU-Server vor Phase 6
5. Direkte Providerlogik im Frontend

## 8. Verifikation

Diese Struktur gilt fuer `PHASE 0` als ausreichend verifiziert, wenn:

1. alle 7 Pflichtschichten dokumentiert sind,
2. Ownership und Schnittstellen benannt sind,
3. die Struktur mit `TEIL 0` kompatibel ist,
4. keine lokale Standardannahme eingefuehrt wurde.
