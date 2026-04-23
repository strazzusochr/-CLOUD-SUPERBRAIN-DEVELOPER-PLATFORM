# Architecture Map

Stand: 2026-04-23
Status: Draft fuer Phase 0
Bezug: `TEIL 0`, `PHASE 0`, `TEIL 10`

## 1. Zweck

Dieses Dokument beschreibt die Zielarchitektur auf Systemebene, bevor Implementierungsarbeit beginnt. Es dient als gemeinsame Karte fuer Schichten, Datenfluesse, Kontrollpunkte und harte Grenzen.

## 2. Systemkontext

Dieses Architekturziel beschreibt das Repository `-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`. `D:\PLATTFORM` ist dabei nur der lokale Workspace-Pfad. Das System ist eine cloud-native Entwicklerplattform, die ueber natuerliche Sprache gesteuert wird. Nutzerinteraktionen laufen ueber ein Prompt-Interface, werden im Backend orchestriert, koennen Squads aus Agenten aktivieren und nutzen Memory, MCP-Tools, GitHub-Integration und Observability als getrennte Systemfaehigkeiten.

## 3. Zielbild auf hoher Ebene

```text
User
  -> Frontend
  -> Backend API / Session Orchestrator
     -> Agent Squad Runtime
     -> MCP Tool Layer
     -> Memory Layer
     -> GitHub / CI-CD Integrations
     -> Observability Pipeline
  -> Cloud Infrastructure
```

## 4. Hauptbausteine

### Frontend

- Prompt-Interface, Streaming, Session-Uebersicht, Squad-Steuerung
- 3D-Webgame-Rendering via WebGPU mit WebGL-Fallback
- keine Secrets, keine direkte Modell- oder Tool-Authentisierung

### Backend API / Session Orchestrator

- zentrale Eintrittsstelle fuer Nutzeranfragen
- JWT-geschuetzte Sessions
- Start, Steuerung und Abschluss von Agentenlaeufen
- Aggregation von Ergebnissen, Review-Gates und Audit-Ereignissen

### Agent Squad Runtime

- MVP-Default mit `4` Agenten
- klare Rollen, Iterationslimits und Review-Gates
- kein unkontrollierter Loop, kein direkter Main-Merge

### MCP Tool Layer

- Git-, Browser-, Datei-, Deployment- und Analysewerkzeuge
- jeder Tool-Pfad mit Timeout, Fehlermodus und Logging-Grenzen
- keine Secret-Ausgabe in Logs oder Resultaten

### Memory Layer

- Kurzzeit-, Arbeits- und Langzeitgedaechtnis
- Summaries, Retrieval und Retention-Regeln
- fuer MVP budget- und cloud-kompatibel

### Observability

- getrenntes System fuer Traces, Logs, Kosten, Limits und Evidence
- Pflicht fuer Releases und produktive Claims

### Cloud Infrastructure

- Frontend-Hosting, Backend-Runtime, Memory-/DB-Runtime, CI/CD
- kein Localhost als Standardannahme
- kompatibel mit `20 EUR/Monat` Infrastruktur-Limit

## 5. Hauptdatenfluesse

1. Nutzerprompt geht vom Frontend an das Backend.
2. Das Backend authentisiert die Session, bewertet die Aufgabe und startet bei Bedarf einen Agentenlauf.
3. Agenten nutzen ueber das Backend die MCP- und Memory-Schichten.
4. Ergebnisse, Kosten- und Laufzeitdaten fliessen in die Observability-Schicht.
5. GitHub- und CI/CD-bezogene Aktionen laufen kontrolliert ueber definierte Review-Gates.

## 6. Architekturgrenzen

1. Kein direkter Providerzugriff aus dem Frontend.
2. Keine Secrets im Code oder in Laufzeit-Logs.
3. Observability bleibt ausserhalb der Main-App.
4. Kein Architekturwechsel ohne ADR.
5. Kein lokaler Standardpfad fuer Produktbetrieb.

## 7. Phase-0-Fokus

Dieses Zielbild ist noch kein finales Deploy-Design. Es legt nur die stabilen Hauptgrenzen fest, damit Phase 1 gegen eine dokumentierte Architektur arbeitet.

## 8. Verifikation

Diese Architecture Map gilt fuer Phase 0 als ausreichend, wenn:

1. alle Kernbausteine aus dem Goal Lock sichtbar sind,
2. die Hauptdatenfluesse beschrieben sind,
3. die harten Grenzen explizit genannt sind,
4. keine lokale oder budgetwidrige Architekturannahme eingefuehrt wurde.
