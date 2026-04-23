# UI State Matrix

Stand: 2026-04-23
Status: Draft fuer Phase 0
Bezug: `docs/screen-inventory.md`, Design-Baseline

## 1. Zweck

Diese Matrix definiert die minimalen UI-Zustaende, die fuer kritische Produktflaechen beruecksichtigt werden muessen. Sie verhindert, dass nur der Happy Path spezifiziert wird.

## 2. Matrix

| Bereich | idle | loading | success | empty | degraded | error | blocked |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Workspace | Prompt bereit | Antwort streamt | Resultat sichtbar | kein Verlauf | Teilantwort / langsamer Provider | Anfrage fehlgeschlagen | Gate verhindert Ausfuehrung |
| Session Detail | Session offen | Evidence wird geladen | Artefakte verifiziert | noch keine Events | Teilverifikation fehlt | Lauf fehlgeschlagen | Review offen |
| Squad Panel | keine aktive Aufgabe | Agenten arbeiten | Aufgabe abgeschlossen | kein Squad aktiv | einzelne Agenten pausiert | Agentenlauf fehlgeschlagen | Supervisor stoppt |
| Memory Explorer | Suche bereit | Retrieval laeuft | Treffer / Summary da | kein passender Kontext | Teilindex verfuegbar | Retrieval fehlgeschlagen | Zugriff nicht erlaubt |
| 3D Game Surface | Szene bereit | Assets laden | Rendering aktiv | keine Szene geladen | WebGL-Fallback aktiv | Renderfehler | Browser / Runtime blockiert |

## 3. Regeln

1. Jeder MVP-Screen muss mindestens die fuer ihn relevanten Matrix-Zustaende behandeln.
2. `degraded` ist Pflicht, wenn Provider-, Rendering- oder Tool-Fallback existieren.
3. `blocked` ist Pflicht fuer Review-, Auth- oder Gate-gebundene Ablaufe.

## 4. Verifikation

Diese Matrix gilt fuer Phase 0 als ausreichend, wenn:

1. kritische Screens nicht nur im Happy Path gedacht sind,
2. Fallback- und Gate-Zustaende sichtbar sind,
3. 3D-Rendering und Agentensteuerung eigene Fehlerbilder haben.
