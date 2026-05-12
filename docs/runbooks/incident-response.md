# Incident Response Runbook

Stand: 2026-05-05
Status: Active baseline for Phase 5

## Trigger

- hosted runtime unhealthy
- security incident
- repeated failed release candidate

## Schritte

1. Incident klassifizieren: runtime, security, deploy, data, provider
2. Scope und betroffene Services festhalten
3. Hosted health, metrics und audit evidence sichern
4. Wenn noetig Release stoppen oder Rollback einleiten
5. Owner informieren und Incident-Timeline pflegen

## Verifikation

- betroffene Services klar benannt
- Beweise gesichert
- naechste Aktion dokumentiert

## Eskalation

- security -> Secret Rotation Runbook
- deploy/runtime -> Rollback Deploy Runbook
- data issue -> Memory Recovery Runbook

## Non-Claims

- Dieses Runbook ist kein Beweis fuer behobene Produktion.
