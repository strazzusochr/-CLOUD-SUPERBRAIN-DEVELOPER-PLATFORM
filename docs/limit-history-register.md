# Limit History Register

Stand: 2026-04-23
Status: Draft fuer Phase 0
Bezug: `docs/cost-policy.md`

## 1. Zweck

Dieses Register sammelt Aenderungen an Budget-, Iterations-, Token- und Laufzeitgrenzen. Es verhindert, dass Schutzgrenzen still erweitert oder aufgeweicht werden.

## 2. Register

| Datum | Bereich | Alter Wert | Neuer Wert | Grund | Freigabe |
| --- | --- | --- | --- | --- | --- |
| 2026-04-23 | Infrastruktur-Budget | n/a | `20 EUR/Monat` | Goal Lock fuer Betriebsobergrenze verankert | project baseline |
| 2026-04-23 | LLM-API-Budget Phase 1-3 | n/a | `200 EUR/Monat` | Kostenpolitik fuer fruehe Phasen definiert | project baseline |
| 2026-04-23 | Wiederholungen pro Aufgabe | n/a | `3` | Schutz gegen unkontrollierte Loops | project baseline |
| 2026-04-23 | Tool-Iterationen pro Agent-Task | n/a | `12` | Schutz gegen Ressourcen- und Zeitdrift | project baseline |

## 3. Regeln

1. Jede Aenderung an Limits wird hier vor oder spaetestens mit ihrer Einfuehrung dokumentiert.
2. Hoehere Limits ohne Grund, Risikoabwägung und Freigabe sind unzulaessig.
3. Kostenbezogene Limit-Aenderungen muessen mit der Cost Policy konsistent bleiben.

## 4. Verifikation

Dieses Register gilt fuer Phase 0 als ausreichend, wenn:

1. die initialen Schutzgrenzen sichtbar eingetragen sind,
2. kuenftige Aenderungen nachvollziehbar gemacht werden,
3. Budget- und Loop-Schutz nicht still aufweichen koennen.
