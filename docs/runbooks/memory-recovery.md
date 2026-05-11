# Memory Recovery Runbook

Stand: 2026-05-05
Status: Active baseline for Phase 5

## Trigger

- memory corruption suspicion
- broken memory visibility or retrieval
- purge or delete path misbehavior

## Schritte

1. Betroffenen Scope und Session/Project festhalten
2. Health-, audit- und memory-contract evidence sichern
3. Nur dokumentierte purge/delete/recovery-Pfade nutzen
4. Wenn Datenintegritaet gefaehrdet ist, Release stoppen
5. Recovery- oder Restore-Entscheidung dokumentieren

## Verifikation

- betroffener Scope dokumentiert
- Recovery-Pfad benannt
- nach Recovery relevante memory contracts erneut pruefen

## Eskalation

- Wenn Datenverlust droht -> Owner + Incident Response

## Non-Claims

- Dieses Runbook ist kein automatischer Restore.
