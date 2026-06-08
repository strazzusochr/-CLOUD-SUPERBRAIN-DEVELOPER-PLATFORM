# Staging Environment Baseline

Stand: 2026-06-08
Status: active cloud baseline

## Ziel

Staging ist ab `PHASE 1` Pflicht und kein spaeteres Optional.
Jede aenderungsrelevante Pipeline laeuft zuerst ueber `staging`.

## Zielumgebung

- Vercel Frontend mit HTTPS Preview/Staging
- Fly.io Runtime-Services fuer Agent API, Worker, MCP Gateway, LLM Gateway, Redis und PostgreSQL/pgvector
- GHCR als Image Registry
- Grafana Cloud als Observability-Ziel
- gleiche logische Servicetopologie wie spaeter `production`
- kleinere Ressourcenlimits als `production`
- Retired legacy providers sind keine aktiven Staging-Defaults

## Aktive Fly-Origin-Apps

Die drei oeffentlichen Origin-Gates werden durch getrennte Fly.io Apps vorbereitet:

| Gate | App | Config | Health |
| --- | --- | --- | --- |
| `AGENT_API_BASE_URL` | `cloud-superbrain-agent-api` | `fly.agent-api.toml` | `/api/v1/health` |
| `MCP_GATEWAY_BASE_URL` | `cloud-superbrain-mcp-gateway` | `fly.mcp-gateway.toml` | `/api/v1/health` |
| `LLM_GATEWAY_BASE_URL` | `cloud-superbrain-llm-gateway` | `fly.llm-gateway.toml` | `/api/v1/health` |

`fly.toml` bleibt als Default-/Compatibility-Config fuer die Agent-API erhalten; neue Gate-Runs sollen die expliziten `fly.*.toml` Dateien verwenden.

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
