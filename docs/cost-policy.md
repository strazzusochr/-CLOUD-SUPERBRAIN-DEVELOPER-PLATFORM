# Cost Policy

Stand: 2026-04-23
Status: Draft fuer Phase 0

## 1. Nicht verhandelbare Obergrenzen

1. Infrastruktur-Betrieb: maximal `20 EUR/Monat`
2. LLM-API-Budget in den Phasen `1-3`: maximal `200 EUR/Monat`
3. Bei `80%` Budgetverbrauch werden automatische Sparmassnahmen aktiv.
4. Bei `100%` des jeweiligen Limits wird die entsprechende Kategorie hart eingefroren, bis der Owner freigibt.

## 2. Infrastruktur-Budget-Aufteilung

Dies sind interne Budgetkorridore, keine Anbieterpreiszusagen:

| Kategorie | Zielkorridor pro Monat |
| --- | --- |
| Frontend Hosting | `0-4 EUR` |
| Backend / Worker Runtime | `4-8 EUR` |
| Datenbank / Memory Runtime | `4-6 EUR` |
| Observability | `0-2 EUR` |
| Reserve | `0-2 EUR` |

Regel:
Wenn eine Kategorie ihren Korridor reisst, muss eine andere Kategorie ausgleichen oder das Design wird zurueckgebaut.

## 3. LLM-Kostenklassen

Zur Steuerung werden Modelle ueber interne Kostenklassen statt ueber einzelne Anbieterpreise freigegeben:

| Klasse | Interner Kostendeckel pro 1M Input Tokens | Interner Kostendeckel pro 1M Output Tokens | Einsatz |
| --- | --- | --- | --- |
| `Tier-P` Premium Reasoning | `<= 15 EUR` | `<= 60 EUR` | harte Architekturfragen, Blocker, finale Reviews |
| `Tier-S` Standard Coding | `<= 5 EUR` | `<= 15 EUR` | Standard-Coding, Planung, Implementierung |
| `Tier-E` Economy Verify | `<= 1 EUR` | `<= 4 EUR` | Tests, Summaries, Memory-Verdichtung, Monitoring |

Regel:
Modelle oberhalb dieser Deckel duerfen nur nach expliziter Owner-Freigabe genutzt werden.

## 4. Rollen-zu-Kostenklassen

| Rolle | Standardklasse | Eskalationsklasse |
| --- | --- | --- |
| Planner | `Tier-S` | `Tier-P` |
| Coder | `Tier-S` | `Tier-P` nur bei festem Blocker |
| Tester | `Tier-E` | `Tier-S` |
| Reviewer | `Tier-S` | `Tier-P` |
| Memory Curator | `Tier-E` | `Tier-S` |
| Runtime / Observability Checks | `Tier-E` | `Tier-S` |

## 5. Session- und Squad-Limits

1. MVP-Default: `1` aktiver Squad mit `4` Agenten.
2. Zusätzliche Squads nur, wenn Budget- und Laufzeitdaten stabil sind.
3. Maximal `3` fehlgeschlagene Wiederholungen pro Aufgabe, danach Review-Gate.
4. Maximal `12` Tool-Iterationen pro Agent-Task, danach Abbruch oder Eskalation.
5. Maximal `12k` Output-Tokens fuer Planner/Reviewer pro Einzelantwort.
6. Maximal `8k` Output-Tokens fuer Coder pro Einzelantwort.
7. Maximal `4k` Output-Tokens fuer Tester.
8. Maximal `2k` Output-Tokens fuer Verdichtungs- und Statuslaeufe.

## 6. Sparmassnahmen ab 80%

1. `Tier-P` nur noch fuer echte Blocker und finale Review-Gates.
2. Standardmaessig kleinere Modelle fuer Tester, Summaries und Memory.
3. Kontext wird aggressiver verdichtet.
4. Parallelisierung wird reduziert, wenn sie keinen klaren Durchsatzgewinn liefert.
5. Nicht kritische Experimente werden eingefroren.

## 7. Open-Source-First-Regel

1. OSS oder OSS-nahe Loesungen sind Standard.
2. Proprietaere Abhaengigkeiten sind nur erlaubt, wenn:
   - keine tragfaehige OSS-Alternative existiert,
   - das Budget eingehalten wird,
   - und der Owner explizit freigibt.

## 8. Verifikation

Die Kostenrichtlinie gilt fuer `PHASE 0` als verifiziert, wenn:

1. beide harten Monatslimits numerisch definiert sind,
2. `80%` und `100%`-Trigger klar beschrieben sind,
3. Rollen- und Tokenlimits vorhanden sind,
4. keine Entscheidung still das `20 EUR/Monat`-Ziel unterlaeuft.
