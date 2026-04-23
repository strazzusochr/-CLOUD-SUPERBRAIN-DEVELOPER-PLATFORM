# Docker Compose Design

Stand: 2026-04-23
Status: Phase-1 design only

## Ziel

Dieses Dokument beschreibt die geplante `docker compose`-Topologie fuer die Foundation-Phase.
Es ersetzt bewusst kein lauffaehiges `docker-compose.yml`, weil `PHASE 1` laut North-Star-Vorgabe nur Design- und Schema-Arbeit umfasst.

## Designprinzipien

- keine `latest`-Tags
- alle Datenservices nur intern erreichbar
- klare `depends_on`-Ketten
- Health Checks fuer jeden Service
- Ressourcenlimits pro Container
- staging-first, production spaeter
- keine versteckten Zusatzservices ohne dokumentiertes Gate

## Geplante Service-Topologie

| Service | Geplantes Image / Tag | Externer Port | Interner Port | Rolle | Status |
| --- | --- | --- | --- | --- | --- |
| `nginx` | `nginx:1.29.2-alpine` | `80`, `443` | `80` | Reverse Proxy und TLS-Termination | design-ready |
| `agent-api` | `ghcr.io/strazzusochr/cloud-superbrain-agent-api:phase1-design-v1` | keiner | `8000` | FastAPI-Steuerung fuer Prompt, Sessions, Tools und Orchestrierung | planned image, noch nicht gebaut |
| `redis` | `redis:7.4.8-alpine3.21` | keiner | `6379` | Queue, Cache, Rate-Limit-Hilfszustand | design-ready |
| `postgres` | `pgvector/pgvector:0.8.2-pg16-bookworm` | keiner | `5432` | relationale Daten und Vektor-Erweiterung | design-ready |
| `qdrant` | `qdrant/qdrant:v1.17.1-unprivileged` | keiner | `6333` | Retrieval-Index fuer semantisches Memory | design-ready |
| `langfuse-server` | `ghcr.io/langfuse/langfuse:3.163.0` | keiner | `3000` | Traces, Prompt-Observability, Ops-UI | blocked by backing-service gap |
| `langfuse-worker` | `ghcr.io/langfuse/worker:3.163.0` | keiner | n/a | asynchrone Trace-Verarbeitung | blocked by backing-service gap |
| `mcp-gateway` | `ghcr.io/strazzusochr/cloud-superbrain-mcp-gateway:phase1-design-v1` | keiner | `9000` | normalisierte Tool-Zugriffe ueber MCP | planned image, noch nicht gebaut |

## Wichtige Ehrlichkeitsmarkierungen

1. `agent-api` und `mcp-gateway` sind geplante Repo-Images. Die Tags sind bewusst Design-Tags und keine existierenden Releases.
2. `langfuse-server` und `langfuse-worker` sind fuer die Zielarchitektur gesetzt, aber die aktuelle `8`-Service-Vorgabe kollidiert mit der offiziellen Langfuse-v3-Architektur, die zusaetzliche Storage-Komponenten erwartet.
3. Diese Compose-Topologie ist deshalb ein kontrolliertes Design-Artefakt, kein claim auf sofortige Ausfuehrbarkeit.

## Abhaengigkeiten

| Service | Harte Abhaengigkeiten | Hinweis |
| --- | --- | --- |
| `nginx` | `agent-api`, `langfuse-server` | routed nur auf intern gesunde Services |
| `agent-api` | `redis`, `postgres`, `qdrant`, `mcp-gateway` | startet erst nach gesunden Kernabhaengigkeiten |
| `redis` | none | Basiskomponente |
| `postgres` | none | Basiskomponente |
| `qdrant` | none | Basiskomponente |
| `langfuse-server` | `redis`, `postgres` plus externe oder zusaetzliche Langfuse-Backends | Phase-1-Gate offen |
| `langfuse-worker` | `langfuse-server`, `redis` plus externe oder zusaetzliche Langfuse-Backends | Phase-1-Gate offen |
| `mcp-gateway` | `redis` | kann ohne Haupt-API laufen, bleibt intern |

## Ressourcenlimits

### Production-Zielbild auf `CPX51`

| Service | CPU-Limit | Memory-Limit | Persistenz |
| --- | --- | --- | --- |
| `nginx` | `0.50` | `256 MB` | Konfiguration, Zertifikate |
| `agent-api` | `2.00` | `2 GB` | kein lokaler State, nur Logs |
| `redis` | `1.00` | `1 GB` | Redis-Volume fuer AOF/RDB je nach Modus |
| `postgres` | `2.00` | `4 GB` | Datenvolume |
| `qdrant` | `1.50` | `2 GB` | Datenvolume |
| `langfuse-server` | `1.00` | `2 GB` | Konfig und temporäre Daten |
| `langfuse-worker` | `1.00` | `2 GB` | Queue- und Jobverarbeitung |
| `mcp-gateway` | `1.00` | `1 GB` | kein persistenter Kernzustand |

### Staging-Zielbild auf `CX22`

| Service | CPU-Limit | Memory-Limit | Hinweis |
| --- | --- | --- | --- |
| `nginx` | `0.25` | `128 MB` | reduzierte Last |
| `agent-api` | `1.00` | `1 GB` | nur Staging-Traffic |
| `redis` | `0.50` | `512 MB` | kleine Queue-Tiefe |
| `postgres` | `1.00` | `1.5 GB` | reduzierte Testdaten |
| `qdrant` | `0.75` | `1 GB` | begrenzter Index |
| `langfuse-server` | `0.50` | `1 GB` | nur nach geklaertem Backing-Modell |
| `langfuse-worker` | `0.50` | `1 GB` | nur nach geklaertem Backing-Modell |
| `mcp-gateway` | `0.50` | `512 MB` | intern |

## Health-Check-Strategie

| Service | Check |
| --- | --- |
| `nginx` | `GET /healthz` ueber internen Listener |
| `agent-api` | `GET /healthz` mit DB-, Redis- und Qdrant-Probe |
| `redis` | `redis-cli ping` |
| `postgres` | `pg_isready` |
| `qdrant` | `GET /healthz` |
| `langfuse-server` | `GET /api/public/health` oder dokumentierter v3-Health-Endpunkt |
| `langfuse-worker` | Queue-Heartbeat oder interner Ready-Check |
| `mcp-gateway` | `GET /healthz` mit Tool-Registry-Ladeprobe |

## Netzwerke und Volumes

- ein internes Default-Netz fuer Applikationsverkehr
- kein direktes Host-Port-Mapping fuer Datenservices
- getrennte Volumes fuer `postgres`, `qdrant`, `redis`, `nginx`
- Audit- und Debug-Logs nicht als Container-Standardoutput allein betrachten, sondern ueber strukturierte Log-Pfade und Rotation mitfuehren

## Konflikte und Gates

### Gate 1: Langfuse-Service-Envelope

Die offizielle Langfuse-v3-Architektur beschreibt neben Web und Worker weitere Storage-Abhaengigkeiten. Die aktuelle `8`-Service-Vorgabe im Master-Dokument laesst diese nicht als eigene Container zu.

Phase-1-konforme Konsequenz:

- kein Fake-Claim, dass das Compose-Design sofort lauffaehig ist
- vor Implementierung muss entschieden werden, ob
  - die fehlenden Langfuse-Backends externalisiert werden, oder
  - die Service-Obergrenze per ADR angepasst wird

### Gate 2: Datenbank-Baseline

`ADR-004` legt fuer das MVP Supabase als Startdatenbank fest. Dieses Phase-1-Zielbild beschreibt parallel eine spaetere Self-Hosted-PostgreSQL-Topologie fuer Hetzner.

Phase-1-konforme Konsequenz:

- Schema bleibt strikt PostgreSQL-kompatibel
- kein stiller Cutover in Phase 1
- Aktivierung der Self-Hosted-Postgres-Rolle braucht explizite Owner-Freigabe oder neues ADR

## Definition of Done fuer dieses Artefakt

Dieses Dokument ist fertig, wenn:

- alle `8` Zielservices benannt sind
- keine unversionierten Images enthalten sind
- interne und externe Ports getrennt sind
- Ressourcen- und Health-Check-Strategie sichtbar ist
- reale Konflikte als Gates markiert statt kaschiert werden
