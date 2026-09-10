# Staging Environment Baseline

Stand: 2026-07-26
Status: Cloudflare-native target; hosted proof blocked

## Ziel

Staging ist ab `PHASE 1` Pflicht und kein spaeteres Optional.
Jede aenderungsrelevante Pipeline laeuft zuerst ueber `staging`.

## Zielumgebung

- Vercel Frontend mit HTTPS Preview/Staging
- Cloudflare-native Runtime fuer Workers/LangGraph.js, D1, SQLite Durable
  Objects und Queues; Artefaktadapter nur nach Zero-Card-Proof
- GHCR als Image Registry
- Grafana Cloud als Observability-Ziel
- gleiche logische Servicetopologie wie spaeter `production`
- kleinere Ressourcenlimits als `production`
- Retired legacy providers sind keine aktiven Staging-Defaults

## Hosted Origins

Die oeffentlichen Origin-Gates duerfen nur auf freigegebene Cloudflare-native
HTTPS-Dienste zeigen:

| Gate | App | Config | Health |
| --- | --- | --- | --- |
| `CLOUDFLARE_STATEFUL_BASE_URL` | Cloudflare-native stateful runtime | Owner-gated O2' plan | `/health` plus stateful verifier |
| `AGENT_API_BASE_URL` | Approved Agent API boundary | Environment-only configuration | `/api/v1/health` |
| `MCP_GATEWAY_BASE_URL` | Approved MCP boundary | Environment-only configuration | `/api/v1/health` |
| `LLM_GATEWAY_BASE_URL` | Approved LLM boundary | Environment-only configuration | `/api/v1/health` |

Fly configs remain historical RC10 provenance only and must not be used by a
new gate run.

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
- keine retired-legacy-provider-Abhaengigkeit als Gate-Ersatz

## Definition of Done fuer dieses Artefakt

Dieses Dokument ist fertig, wenn:

- `staging` als Pflicht-Gate dokumentiert ist
- immer-an-Betrieb festgelegt ist
- die Schutz- und Sichtbarkeitsregeln klar sind
