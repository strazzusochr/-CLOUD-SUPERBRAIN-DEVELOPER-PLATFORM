# Hetzner Server Setup Baseline

Stand: 2026-04-23
Status: Phase-1 design only

## Ziel

Dieses Dokument definiert die minimale, budgetkonforme Server-Baseline fuer `PHASE 1`.
Es ist absichtlich kein Betriebsrunbook und kein ausgefuehrtes Provisioning.

## Scope

- Produktionsbasis auf Hetzner fuer das spaetere MVP
- Staging-Basis auf eigenem, kleineren Hetzner-Server
- Sicherheits- und Betriebsminima vor erstem Deployment

## Nicht im Scope

- Produktivdeployment
- DNS-Switch
- Secret-Einspielung
- Live-Migrationen
- Datenbank-Cutover von externen Alt-Systemen; Phase-1-Quelle ist bereits PostgreSQL/pgvector

## Serverklassen

| Umgebung | Ziel-SKU | Region | Zweck | Budget-Hinweis |
| --- | --- | --- | --- | --- |
| `production` | `CX21` oder vergleichbar klein | `fsn1` Frankfurt | spaetere Hauptlaufzeit fuer API, Gateway, Memory, Observability | Phase-1-Start, solange Messwerte im 20-EUR-Limit bleiben |
| `staging` | kleinste budgetkonforme CX-Klasse | `fsn1` Frankfurt | alle Deployments zuerst hier | erst aktivieren, wenn `STAGING_BASE_URL` und Budget-Gate gesetzt sind |

## Basisbetriebssystem

- `Ubuntu 24.04 LTS`
- Zeitzone intern auf `UTC`
- SSH-Zugriff nur mit Schluessel, kein Passwort-Login
- Root-Login ueber SSH deaktivieren
- automatisierte Security-Updates aktiv
- Docker Engine und Docker Compose Plugin als Laufzeitbasis
- `8 GB` Swap auf `production`, um Lastspitzen von Observability-Komponenten kontrolliert abzufedern

## Netzwerk- und Firewall-Baseline

Extern offen:

- `22/tcp` fuer SSH
- `80/tcp` fuer HTTP
- `443/tcp` fuer HTTPS

Extern geschlossen:

- `5432/tcp`
- `6379/tcp`
- `6333/tcp`
- `8000/tcp`
- `9000/tcp`
- `3000/tcp`

Interne Servicekommunikation laeuft ausschliesslich ueber das Docker-Netzwerk.

## Betriebsminima vor erstem Deployment

1. Basis-OS gepatcht und automatische Security-Updates bestaetigt
2. SSH-Key-Only nachweisbar aktiv
3. Host-Firewall auf `22/80/443` beschraenkt
4. Docker und Compose installiert
5. Volumes fuer Datenhaltung und Backups geplant
6. Monitoring-Endpunkte nur intern oder ueber abgesicherte Admin-Pfade erreichbar
7. Staging-Server vor Production vorhanden und erreichbar

## Review-Gates

Expliziter Stopp vor:

- erstem Production-Deployment
- echtem Secret-Import
- Datenbank-Cutover
- oeffentlicher Exposition von Grafana oder Admin-Oberflaechen
- Veraenderung der Hetzner-SKU ausserhalb des `20 EUR/Monat`-Budgets oder ohne Messwertbeleg und Owner-Freigabe

## Definition of Done fuer dieses Artefakt

Dieses Dokument ist fertig, wenn:

- Production- und Staging-Basis klar getrennt sind
- Sicherheits- und Port-Baseline dokumentiert ist
- keine lokale Laufzeit vorausgesetzt wird
- keine implizite Freigabe fuer Live-Betrieb behauptet wird
