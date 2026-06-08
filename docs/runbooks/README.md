# Runbook Index

Stand: 2026-05-05
Status: Active baseline for Phase 5
Bezug: `TEIL 10`

## 1. Zweck

Dieses Verzeichnis ist der Einstiegspunkt fuer operative Runbooks. Die Pflichtkategorien sind jetzt nicht mehr nur geplant, sondern als Phase-5-Baseline ausgearbeitet und muessen mit Release-Checklist, Verification Register und Hosted-Proofs zusammenpassen.

## 2. Pflichtkategorien

| Runbook | Zweck | Spaetester Bedarf |
| --- | --- | --- |
| `incident-response.md` | Vorgehen bei Produktions- oder Sicherheitsvorfaellen | vor erstem Production-Deploy |
| `secret-rotation.md` | kontrollierte Rotation und Nacharbeiten bei Secret-Aenderungen | vor produktiven Secrets |
| `rollback-deploy.md` | Ruecknahme eines fehlerhaften Releases | vor erster produktiver Pipeline |
| `provider-failover.md` | Wechsel auf alternativen LLM- oder Tool-Provider | vor Multi-Provider-Betrieb |
| `memory-recovery.md` | Umgang mit fehlerhaften Memory-Indizes oder Retention-Problemen | vor persistentem Langzeit-Memory |
| `single-region-frankfurt-outage.md` | historisches Hetzner-Runbook; retired, nicht aktiver Cloud-Gate-Pfad | nur fuer Legacy-Audit |
| `docker-desktop-wsl2-readiness.md` | lokaler Docker-Desktop/WSL2-Health-Check fuer dockerbasierte Gates | vor lokalen Docker-/Compose-Verifikationen |

## 3. Regeln

1. Jedes produktionsrelevante Runbook braucht Trigger, Schritte, Verifikation und Eskalation.
2. Kein Runbook darf echte Secrets enthalten.
3. Runbooks muessen mit Release-Checklist, Verification Register und Observability-Strategie zusammenpassen.

## 4. Verifikation

Der Runbook-Index gilt fuer Phase 0 als ausreichend, wenn:

1. die Pflichtkategorien sichtbar benannt sind,
2. ihr Einsatzzeitpunkt klar ist,
3. keine operative Grauzone fuer Release, Incident oder Secret-Rotation offen bleibt.
