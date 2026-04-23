# Design Spec Register

Stand: 2026-04-23
Status: Draft fuer Phase 0
Bezug: `TEIL 10`, Design-Baseline

## 1. Zweck

Dieses Register erfasst verbindliche Design-Spezifikationen, sobald konkrete Oberflaechen oder Erlebnisbausteine in Umsetzung gehen. Es stellt sicher, dass UI- und UX-Entscheidungen nicht fragmentiert entstehen.

## 2. Register

| Spec-ID | Bereich | Zweck | Status | Verweis |
| --- | --- | --- | --- | --- |
| `DS-001` | Global UI Foundation | Dark Mode, Farbrollen, Statusfarben, Basiskomponenten | draft | `TEIL 0` Design-Baseline |
| `DS-002` | Prompt Workspace | Prompt-Eingabe, Streaming, Verlauf, Session-Kontext | placeholder | spaeterer Screen-Spec |
| `DS-003` | Squad Control Surface | Agentenstatus, Aufgaben, Gates, Evidence | placeholder | spaeterer Screen-Spec |
| `DS-004` | Memory Views | Such-, Summary- und Langzeit-Memory-Darstellung | placeholder | spaeterer Screen-Spec |
| `DS-005` | 3D Webgame Surface | Rendering-Flaeche, HUD, Fallback-Zustaende | placeholder | spaeterer Screen-Spec |

## 3. Regeln

1. Jede relevante UI-Flaeche bekommt vor Umsetzung einen Spec-Eintrag.
2. Status `placeholder` bedeutet geplant, aber noch nicht detailiert.
3. Design-Entscheidungen mit Architektur- oder Performance-Folgen brauchen ADR-Verweis oder Register-Notiz.

## 4. Verifikation

Dieses Register gilt fuer Phase 0 als ausreichend, wenn:

1. die globalen Pflichtbereiche sichtbar angelegt sind,
2. Dark Mode und Design-Baseline nicht verloren gehen,
3. neue UI-Flaechen spaeter eindeutig referenzierbar sind.
