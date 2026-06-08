# CLOUD-SUPERBRAIN DEVELOPER PLATFORM — Deep Architecture Layer Map
Datum: 2026-06-07
Ziel: Alle Cloud-Seiten, Gateways, Worker und Datenpfade logisch verdrahtet; der optische Workbereich bleibt strikt getrennt.

---

## 1. Grundannahme

Es laufen:

- Next.js 15 + React 19 Frontend
- LangGraph Orchestrator
- FastAPI Agent API / MCP Gateway / LLM Gateway
- PostgreSQL 16 + pgvector, Redis
- Hetzner Hetzner-Staging unter `https://188-34-191-140.sslip.io`
- Lokale DEV-Runtime auf `http://localhost:8081`

Die **22 Seiten** sind der Benutzer-Workbereich (`/workbench`, `/organism`, `/agents`, `/technology`, `/files`, `/docs-output`, `/home`, `/diagnostics`, `/evidence`, `/tools`, `/marketplace`, `/apps`, `/settings`, `/audit`, `/monitoring`, `/docs`, `/runtime`, `/clouds`, `/memory`, `/budget`, `/security`, `/inbox` / äquivalent).

---

## 2. Sieben Layer (Kernsystem)

| Layer | Name | Hauptservices | Rolle |
|---|---|---|---|
| L1 | Daten & Speicher | postgres/pgvector, redis | Persistenz, Checkpoints, Memory, Queue |
| L2 | Modelle & LLM Gateway | llm-gateway | Routen, Dry-Run, Streaming, Policy |
| L3 | Agent Pool & Worker | agent-worker, memory-worker | Tasks, Memory-Konsolidierung |
| L4 | API & Gateways | agent-api, mcp-gateway, nginx | REST/SSE-Surfaces, Security, Auth |
| L5 | Frontend & UI | frontend, nginx `:8081` | Workbereich, Organism, Diagnose |
| L6 | Cloud & Infrastruktur | docker-comose.cloud, caddy, hetzner | Deployment, Routing, Container |
| L7 | Integration & Verification | verify-*, docs/* | Runtime-Contracts, Evidence, Gates |

---

## 3. Physikalische Host-Zuordnung

| Provider | Dienste |
|---|---|
| **Vercel** | Frontend-Routing, Edge JWT (geplant über `STAGING_BASE_URL`) |
| **Hetzner** | Gesamter Runtime-Stack (`188-34-191-140.sslip.io`) |
| **Cloudflare** | DNS, Cache, optional AI-Gateway (noch nicht aktiv geschaltet) |
| **Fly.io** | Cloud-Run-Maschine für Worker-Skalierung, Memory-Run, Memory (geplant über `FLY_API_TOKEN`, aktuell blocked) |
| **GitHub / GHCR** | Repo, CI, Image-Registry (`ghcr.io/strazzusochr/cloud-superbrain-developer-platform/...`) |
| **Grafana Cloud / Langfuse** | Observability, Traces, Audit |

---

## 4. Logische Verdrahtung Layer-zu-Layer

### 4.1 L1 → L2/L3/L4

- L1 stellt Redis Queue `tasks:agent:queue` und Postgres Checkpoints bereit.
- L2 liest `DATABASE_URL`, `REDIS_URL` aus Compose-ENV.
- L4 nutzt Postgres für Audit/Memory-Felder.

### 4.2 L2 → L3

- L3 ruft `/llm/api/v1/chat/completions` mit `stream=true` über `LLM_GATEWAY_INTERNAL_URL` auf.
- Antwort wird über SSE an Frontend/Monitoring weitergereicht.

### 4.3 L3 → L4

- `POST /api/v1/tasks/...` und `POST /api/v1/internal/tasks` schreiben in Redis/Postgres.
- `GET /api/v1/agents/status`, `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent` lesen aus Postgres/Audit.

### 4.4 L4 → L5

- Alle Seiten laden Daten über `/api/...`, `/mcp/...`, `/llm/...`.
- Frontend Seitenpfade sind optisch getrennt (`/workbench`, `/organism`, `/agents`, …).

### 4.5 L5 → L6

- L6 routed via nginx/caddy an die L5-Services:
  - `/api` → `agent-api:8000`
  - `/mcp` → `mcp-gateway:9000`
  - `/llm` → `llm-gateway:4000`
  - `/` → `frontend:3000`

### 4.6 L6 → L7

- L7 startet `verify-phase1*.ps1`, `verify-external-gates.ps1`, `verify-hosted-staging.ps1`.
- Artefakte landen in `.phase1-artifacts/`, Logs in `trae-hermes-test.log`, `docs/**`.

---

## 5. Cloud-Provider-Seiten (optisch getrennte Bereiche im 22-Workbereich)

Diese Bereiche werden in der UI optisch abgegrenzt:

| Bereich | Cloud-Seite | Datenherkunft |
|---|---|---|
| `organism` | Cloud-Betriebsstatus (L1–L7) | `GET /api/v1/clouds/layers` |
| `clouds` | Provider-Inventar | `GET /api/v1/clouds` |
| `agents` | Worker-Kontrolle | `GET /api/v1/agents/status` |
| `tools`, `marketplace` | MCP-Toolsets | `GET /mcp/api/v1/...` |
| `technology` | Stack-Dokumentation | `GET /api/v1/technology/*` |
| `monitoring` | Langfuse / Grafana | `GET /api/v1/metrics`, Langfuse |
| `budget`, `costs` | Budget UI | `GET /api/v1/budget`, `GET /api/v1/costs` |
| `security` | Security-Headers, Auth, Secrets | `GET /api/v1/security/*` |
| `audit` | Audit Feed | `GET /api/v1/audit/recent` |

---

## 7. Sieben-Cloud-Layer-Map (logische Verschachtelung)

Diese Map zeigt, wie der **22-Seiten-Arbeitsbereich** sauber vom **7-Layer-Cloud-Superbrain** getrennt ist — astrophysisch getrennt, aber voll verdrahtet.

### Blatt A — Optischer Arbeitsbereich (Frontend/UI)

Erreichbar über `http://localhost:8081/*`, optisch eigenständig:

| Route | Rolle im Arbeitsbereich |
|---|---|
| `/home` | Einstiegspunkt, Status-Cockpit |
| `/workbench` | Kommandozentrale, Prompts, Streaming |
| `/organism` | 3D Cortex + Live-Organismus |
| `/organisms/live` | Live-Puls, SSE-Events |
| `/organisms/map` | 3D-Kartenansicht |
| `/organisms/replay` | Replay-Stream |
| `/agents` | Agenten-Steuerung |
| `/files`, `/files/local` | Dateisystem |
| `/tools`, `/marketplace` | MCP-Toolsets |
| `/technology` | Stack-Dokumentation |
| `/apps` | Erzeugte Ausgaben |
| `/games` | 3D-Webgame-Konnektor |
| `/settings` | Governance/Secrets |
| `/diagnostics` | Archiv/Fehleranalyse |
| `/evidence` | Nachweise/Contracts |
| `/observe` | Langfuse/Grafana |
| `/monitoring` | Live-Metriken |
| `/budget`, `/costs` | Budget |
| `/security` | Security-Headers/Contracts |
| `/audit` | Audit-Feed |
| `/media` | Media-Workflow |

*Hinweis: Die genaue Anzahl kann je nach Branch variieren; die Liste oben entspricht dem aktuellen App-Router.*

### Blatt B — Cloud-System (7 Layer, optisch nicht im Arbeitsbereich)

| Layer | Cloud-Seite | Primäre URL | Optisch getrennt? |
|---|---|---|---|
| **L1** Daten & Speicher | `postgres`, `redis` | intern | ✅ |
| **L2** Modelle & LLM Gateway | `llm-gateway` | `/llm/api/v1/...` | ✅ |
| **L3** Agent Pool & Worker | `agent-worker`, `memory-worker` | intern | ✅ |
| **L4** API & Gateways | `agent-api`, `mcp-gateway`, `nginx` | `/api/`, `/mcp/` | ⚠️ (API-Surfaces sind sichtbar, aber nicht der Worker selbst) |
| **L5** Frontend & UI | `frontend`, `nginx:8081` | `http://localhost:8081` | ⚠️ (Frontend ist der Arbeitsbereich, aber getrennt von den Workers) |
| **L6** Cloud & Infrastruktur | `docker-compose.cloud`, `caddy`, `hetzner` | `https://188-34-191-140.sslip.io` | ✅ |
| **L7** Integration & Verification | `scripts/verify-*`, `docs/` | lokal | ✅ |

### Verschachtelungsmatrix (Verdrahtung)

```
L5 Frontend/UI  <--->  L4 API/Gateways (nginx:8081)
      |                         |
      v                         v
L3 Agent/Worker  <--->  L2 LLM Gateway
      |                         |
      v                         v
L1 Daten&Speicher (Postgres, Redis)
      |
      v
L6 Cloud/Runtime (docker-compose.cloud)
      |
      v
L7 Verification (scripts, docs)
```

### Cloud-Provider-Verschachtelung

| Provider | Layer | Zweck |
|---|---|---|
| **Vercel** | L5 | Frontend Hosting, Edge-Routing |
| **Hetzner** | L1, L2, L3, L4, L6 | Runtime-System |
| **Cloudflare** | L4, L6 | DNS, Cache, optional AI-Gateway |
| **Fly.io** | L3 | Worker-Skalierung (geplant) |
| **GitHub** | L6 | CI/CD |
| **GHCR** | L6 | Image-Registry |
| **Langfuse** | L7 | Observability/Traces |

### Fazit

- Der **22-Seiten-Arbeitsbereich** ist optisch vollständig getrennt über `apps/frontend/app/*`.
- Das **7-Layer-Cloud-System** läuft über Provider (Vercel, Hetzner, Cloudflare, Fly.io, GitHub, Langfuse), ohne den Arbeitsbereich optisch zu durchbrechen.
- Die Verdrahtung erfolgt ausschließlich über klare API-/SSE-/Queue-Schnittstellen.
- Lokal bleibt `localhost:8081` reiner **Dev-Control-Plane**; alle Cloud-Seiten sind auf echtes Hosting via `STAGING_BASE_URL` gated.

| Gate | Status | Wo sichtbar |
|---|---|---|
| Hosted staging via `STAGING_BASE_URL` | BLOCKED (kein echte HTTPS-URL) | `verify-external-gates.ps1` |
| Branch protection via `GITHUB_TOKEN` | BLOCKED (kein Token) | `apply_github_branch_protection.py` |
| Vercel Backend Origins | BLOCKED (leer) | `VERCEL_*_ORIGIN` |
| Fly-Live-Budget via `FLY_API_TOKEN` | BLOCKED (kein Token) | `check_fly_infra_budget.py` |
| Hetzner-Budget via `HETZNER_API_TOKEN` | HISTORISCH VERIFIZIERT | `docs/runbooks/hetzner-live-budget-proof-2026-04-29.md` |
| GitHub CI / GHCR | HISTORISCH VERIFIZIERT | `verification-register.md` |

---

## 7. Was ab jetzt *nicht* lokal laufen soll

- Keine Fake-Credentials in `docker-compose.*.yml`.
- Keine Hetzner-/Fly-/Vercel-/Branch-Protection-Claims ohne echte Tokens.
- Lokale DEV-Runtime bleibt auf `localhost:8081` beschränkt.
- Alle Cloud-Anbindungen laufen über die offiziellen Provider-Kanäle.

