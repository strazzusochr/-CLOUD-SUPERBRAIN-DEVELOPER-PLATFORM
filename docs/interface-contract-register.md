# Interface Contract Register

Stand: 2026-04-23
Status: Draft fuer Phase 0
Bezug: `docs/monorepo-structure.md`, `docs/architecture-map.md`

## 1. Zweck

Dieses Register macht die erwarteten Schnittstellen zwischen den Hauptschichten sichtbar, bevor Implementierung beginnt. Es ist kein API-Schemaersatz, sondern ein Governance-Register fuer Verantwortungen und Grenzen.

## 2. Register

| Vertrag | Von | Nach | Zweck | Mindestgarantien | Offene Punkte |
| --- | --- | --- | --- | --- | --- |
| `IF-001` | `frontend` | `backend` | Prompt-, Session- und Streaming-Kommunikation | Auth-pruefbar, streamingfaehig, keine Secrets im Client | Transportformat und Fehlerstandard |
| `IF-002` | `backend` | `agents` | Aufgabenstart, Rollensteuerung, Ergebnisaggregation | Iterationslimit, Abbruchgrund, strukturierte Resultate | Squad-Task-Schema |
| `IF-003` | `backend` | `mcp` | Werkzeugzugriff fuer Git, Browser, Datei, Analyse | Timeout, Fehlermodus, auditierbarer Aufruf | feinere Tool-Scopes |
| `IF-004` | `backend` | `memory` | Speichern, Abrufen, Verdichten von Kontext | Retention-Regel, Zugriffspfad, keine unendliche Akkumulation | konkretes Vector-Backend |
| `IF-005` | `backend` | `observability` | Laufzeit-, Fehler-, Kosten- und Evidence-Signale | korrelierbare Runs, Kostenfelder, Gate-relevante Events | Toolchain-Auswahl |
| `IF-006` | `infrastructure` | `frontend/backend/observability` | Deployment- und Runtime-Konfiguration | kein Localhost-Pfad, Secret-Injektion nur zur Laufzeit | konkrete Hosting-Verteilung |
| `IF-007` | `backend` | `GitHub / CI-CD` | PR-, Pipeline- und Release-Integration | Human-Review vor Main, kein Release ohne Pipeline | GitHub-App-Detaildesign |

## 3. Pflege-Regeln

1. Neue systemrelevante Schnittstelle bedeutet neuer Registereintrag.
2. Architektur- oder Sicherheitsrelevante Vertragsaenderung verlangt ADR oder Verweis auf bestaetigte Entscheidung.
3. Offene Punkte duerfen nicht still aus dem Register verschwinden.

## 4. Verifikation

Dieses Register gilt fuer Phase 0 als ausreichend, wenn:

1. alle Kernfluesse zwischen den Hauptschichten erfasst sind,
2. jeder Vertrag einen klaren Zweck und Mindestgarantien hat,
3. offene Punkte explizit markiert sind,
4. keine Schnittstelle lokale Betriebsannahmen oder Secret-Leaks voraussetzt.
