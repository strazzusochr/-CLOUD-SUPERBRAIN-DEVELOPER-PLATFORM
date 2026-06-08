# CodeX Monitoring

## Logs
- `monitoring/watch.jsonl` — eine Zeile pro Ereignis
- `scripts/verify-codex-output.ps1` — schneller "ist es brauchbar?"-Check
- `scripts/auto-repair-codex.ps1` — minimale Korrekturmassnahmen gegen Luegen/Loops

## Schleifen-Erkennung
- Wiederholte gleiche `changes`-Anzahl ohne `verify`-Verbesserung -> Index inkrementieren und ESP/CrewAI/Benachrichtigung feuern
- Unveraenderte `verifierMsg` ueber viele Zyklen -> Alarm

## Phasen-Waechter
- `scripts/verify-phase5.ps1` — Phase-5-Platzhalter; fuer vollstaendige Freigabe muss die Phase-5-Blaupause explizit vorliegen.
