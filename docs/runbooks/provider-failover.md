# Provider Failover Runbook

Stand: 2026-05-05
Status: Active baseline for Phase 5

## Trigger

- provider degradation
- sustained timeout rate
- owner-approved provider switch

## Schritte

1. Betroffenen Provider und Scope benennen
2. Verifier- und Audit-Lage pruefen
3. Fallback-Route oder blockierten Scope dokumentieren
4. Nur owner-approved externe Provider-Umschaltung ausfuehren
5. Hosted health und relevante contracts erneut pruefen

## Verifikation

- betroffener Provider benannt
- Fallback-Entscheidung dokumentiert
- Hosted proof nach dem Wechsel gruen oder Wechsel klar blockiert

## Eskalation

- Wenn Kosten-/Policy-Grenzen beruehrt werden -> Owner Review

## Non-Claims

- Dieses Runbook ist kein Live-Provider-Claim.
