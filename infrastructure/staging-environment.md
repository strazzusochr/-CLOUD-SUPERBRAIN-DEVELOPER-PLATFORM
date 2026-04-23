# Staging Environment Baseline

Stand: 2026-04-23
Status: Phase-1 design only

## Ziel

Staging ist ab `PHASE 1` Pflicht und kein spaeteres Optional.
Jede aenderungsrelevante Pipeline laeuft zuerst ueber `staging`.

## Zielumgebung

- Hetzner `CX22`
- Region `fsn1`
- dauerhaft aktiv
- gleiche logische Servicetopologie wie spaeter `production`
- kleinere Ressourcenlimits als `production`

## Zugriffsregeln

- keine oeffentliche Marketing-URL
- Zugriff nur ueber bekannte Team-Endpunkte, VPN oder gleichwertige Zugangskontrolle
- Grafana und Admin-Oberflaechen nicht oeffentlich

## Pflichtfaelle fuer Staging

Staging muss vor `production` die Referenz sein fuer:

- Smoke-Tests
- Integrations-Tests
- Rollback-Probe
- Health-Check-Probe
- Observability-Pruefung

## Was Staging nachweisen muss

1. Reverse Proxy erreicht die internen Dienste korrekt
2. API-Health ist gruen
3. Datenpfade fuer Sessions und Memory funktionieren
4. Traces, Metriken und Logs sind sichtbar
5. Rollback kann auf letztes gesundes Staging-Artefakt zurueckgehen

## Abgrenzung zu Production

- kleinere Limits
- geringere Datenmenge
- keine Produktivdaten
- keine Production-Secrets

## Definition of Done fuer dieses Artefakt

Dieses Dokument ist fertig, wenn:

- `staging` als Pflicht-Gate dokumentiert ist
- immer-an-Betrieb festgelegt ist
- die Schutz- und Sichtbarkeitsregeln klar sind
