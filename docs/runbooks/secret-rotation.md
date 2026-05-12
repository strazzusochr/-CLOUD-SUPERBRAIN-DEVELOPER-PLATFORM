# Secret Rotation Runbook

Stand: 2026-05-05
Status: Active baseline for Phase 5

## Trigger

- secret exposure
- owner-requested rotation
- provider-side revocation

## Schritte

1. Betroffenen Secret-Typ bestimmen
2. Neues Secret im offiziellen Secret-System erzeugen
3. Secret nur in Secret-Store / Environment aktualisieren
4. Betroffene Hosted- oder Workflow-Probes erneut laufen lassen
5. Alte Werte deaktivieren oder loeschen
6. Rotation im Incident- oder Release-Artefakt dokumentieren

## Verifikation

- neuer Secret-Wert wird nicht im Repo gespeichert
- Hosted- oder Workflow-Probe nach Rotation gruen
- alter Wert ist deaktiviert oder ersetzt

## Eskalation

- Wenn Rotation Hosted-Deploy bricht -> Rollback Deploy Runbook
- Wenn Missbrauch vermutet wird -> Incident Response Runbook

## Non-Claims

- Dieses Runbook speichert keine Secret-Werte im Git.
