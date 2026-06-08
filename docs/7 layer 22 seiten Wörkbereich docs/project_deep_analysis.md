# 🔬 Ehrliche Deep-Analyse: Wahrer Projektstand
_Erstellt: 2026-06-07 | Quellen: Live-URLs, Docker-Stack, REST-APIs, Codebase_

---

## 1. DOCKER-STACK (localhost) — REALITÄT

**Alle 9 Services laufen und sind healthy:**

| Container | Status | Ports |
|---|---|---|
| `nginx` (Proxy) | ✅ healthy (4h) | **:8081 → :8080** |
| `agent-api` | ✅ healthy (4h) | :8000 intern |
| `frontend` (Next.js) | ✅ healthy (3h) | :3000 intern |
| `mcp-gateway` | ✅ healthy (7h) | :9000 intern |
| `llm-gateway` | ✅ healthy (7h) | :4000 intern |
| `agent-worker` | ✅ healthy | — |
| `memory-worker` | ✅ healthy | — |
| `postgres` | ✅ healthy (20h) | :5432 intern |
| `redis` | ✅ healthy | :6379 intern |

**Zusätzlich: Ein zweiter Compose-Stack** (`cloud-superbrain-phase1-*`, ohne `-dev-`) läuft parallel seit **22 Stunden** — ebenfalls healthy, aber **ohne Nginx, ohne öffentlichen Port**! Das ist der separate "Background"-Stack, den der User meint.

> [!IMPORTANT]
> Es existieren **zwei parallele lokale Stacks** — einer mit Nginx auf :8081 (der aktive Dev-Stack), einer ohne öffentlichen Nginx-Port (der Background-Stack, 22h alt). Die meisten API-Tests liefen gegen :8081 (Dev-Stack).

---

## 2. AGENT-API HEALTH — WAS WIRKLICH LÄUFT

```json
{
  "status": "healthy",
  "service": "agent-api",
  "services": {
    "postgres": "healthy (db: superbrain_prod, pgcrypto+vector)",
    "redis": "healthy",
    "agent_worker": "idle",
    "memory_worker": "healthy",
    "mcp_gateway": "healthy",
    "llm_gateway": "healthy (mode: deterministic_dry_run)"
  },
  "budget": {"level": "ok", "spent_percentage": 0%, "allow_new_calls": true},
  "infra_budget": {"level": "ok", "spent_percentage": 45%, "live_verified": false, "source": "configured_phase1_projection"},
  "external_gates": {"status": "verified", "configured_count": 6, "local_execution_allowed": true}
}
```

### Was das wirklich bedeutet:
- ✅ Alle Microservices lokal gesund
- ✅ PostgreSQL mit pgvector läuft
- ✅ Redis läuft
- ✅ External gates: 6/6 konfiguriert und "verified"
- ⚠️ LLM Gateway ist im **dry_run Modus** — keine echten KI-Calls
- ⚠️ Infra-Budget: 45% spent, aber aus **Projektion**, nicht aus Live-API
- ❌ `live_verified: false` für Infra-Budget (kein echtes Hetzner/Fly.io Reading)

---

## 3. CLOUD PROVIDERS — KRITISCHE WAHRHEIT

`GET /api/v1/clouds` liefert **8 Provider — alle `action_required`:**

| Provider-ID | Status | Blocker |
|---|---|---|
| `vercel_frontend` | ❌ action_required | fehlt `STAGING_BASE_URL` in Docker-Env |
| `hetzner_cloud` | ❌ action_required | fehlt `HETZNER_API_TOKEN` in Docker-Env |
| `cloudflare_edge` | ❌ action_required | fehlt `CLOUDFLARE_API_TOKEN` in Docker-Env |
| `github_actions` | ❌ action_required | fehlt `GITHUB_TOKEN` in Docker-Env |
| `ghcr_registry` | ❌ action_required | fehlt `GHCR_TOKEN` in Docker-Env |
| `huggingface_identity` | ❌ action_required | fehlt `HF_TOKEN` in Docker-Env |
| `gitlab_identity` | ❌ action_required | fehlt `GITLAB_TOKEN` in Docker-Env |
| `gitkraken_identity` | ❌ action_required | fehlt `GITKRAKEN_API_TOKEN` in Docker-Env |

> [!CAUTION]
> **clouds.py wurde in der letzten Session auf Fly.io/Grafana migriert, ABER der Live-Docker-Stack verwendet noch die alten Provider-IDs** (`hetzner_cloud`, `gitkraken_identity`)! Das bedeutet: Die Änderungen an `clouds.py` **wurden noch nicht in den laufenden Docker-Container deployed** — der Container läuft mit dem alten Image.

---

## 4. CLOUDS.PY — WIDERSPRUCH ZWISCHEN CODE UND RUNTIME

**Was der Code sagt (nach unserer Migration):**
- `clouds.py` hat `FLY_GRAPHQL_URL`, `_fly_graphql()`, `_grafana_cloud_get()` implementiert
- Fly.io und Grafana-Cloud-Provider statt Hetzner in Layer 2, 3, 6

**Was der Live-Docker-Stack zurückgibt:**
- 8 Provider: `hetzner_cloud`, `gitkraken_identity` — KEINE Fly.io, KEINE Grafana Cloud!

**Ursache:** Der Docker-Container `agent-api` wurde **nicht neu gebaut** — er läuft noch mit dem alten Image von vor der Migration.

---

## 5. CLOUD LAYERS — 0 VON 7 BEREIT

`GET /api/v1/clouds/layers` liefert:
- `status: action_required`
- `ready_layer_count: 0`
- `total_layer_count: 7`

Alle 7 Layer blockiert, weil die Cloud-Provider-Tokens nicht in die Docker-Umgebung injiziert sind.

---

## 6. VERCEL LIVE-DEPLOYMENTS — WAS WIRKLICH AUSGELIEFERT WIRD

### `cloud-superbrain-developer-platform.vercel.app` (Root)
- Liefert eine **statische HTML-Splash-Page** (kein Next.js App Router!)
- Zeigt: Vercel, **Hetzner**, Cloudflare, GitHub, GHCR, HuggingFace, GitLab, **GitKraken**
- **Kein Backend angebunden** — reine statische Seite

### `frontend-seven-psi-78.vercel.app` (Frontend App)
- ✅ Vollständige **22-seitige Next.js App** deployed und erreichbar
- Navigation mit allen Seiten: Workbench, Organism, Agents, Files, Tools, Marketplace, Observe, Games, Apps, Media, Docs, Evidence, Diagnostics, Design System, **Technology**, Settings, Open Source, Login
- Technology-Seite zeigt **"7 Layers × 8 Cloud Providers"**
- **Zeigt aber immer noch Hetzner Cloud und GitKraken** (gleiche alte Daten)
- Layer-Status: alle auf **"spec"** (grau) — nicht live_verified
- `runState: idle`, `Gates: CLOSED` (in der TopBar)

---

## 7. DISKREPANZ-MATRIX: Versprechen vs. Realität

| Was im Code / Docs steht | Wahrer Live-Zustand |
|---|---|
| Fly.io in clouds.py migriert | ❌ Docker-Container noch mit altem Image |
| Grafana Cloud in clouds.py | ❌ Docker-Container noch mit altem Image |
| `verify-tooling-readiness.ps1` grün | ✅ Grün (prüft Tokens per HTTP, nicht Docker-Runtime) |
| `grafana_cloud_claim_allowed=True` | ❌ Tatsächlich `False` in letztem Verifier-Run |
| `hosted_staging_claim_allowed=True` | ❌ `False` — staging hat keinen live Agent-API Backend |
| 7 Layers ready | ❌ 0 von 7 ready (alle action_required) |
| External gates verified | ✅ Lokal ja (6/6) — aber nur Konfigurationscheck |
| GitKraken entfernt | ❌ Vercel-Frontend zeigt noch GitKraken |
| Hetzner → Fly.io Wechsel | ❌ Frontend + Live-Docker zeigt noch Hetzner |

---

## 8. WAS WIRKLICH FUNKTIONIERT (Positiv)

✅ **Der lokale Docker Dev-Stack ist stabil und vollständig**
- Alle 9 Services healthy
- PostgreSQL mit pgvector, Redis, alle Microservices
- Agent API antwortet korrekt auf Health + API-Calls

✅ **Das Next.js Frontend ist auf Vercel deployed** (`frontend-seven-psi-78.vercel.app`)
- 22 Seiten navigierbar
- Vollständiges App-Shell-Design

✅ **verify-tooling-readiness.ps1 ist grün**
- Docker, Vercel, Fly.io, Cloudflare, HuggingFace, GitLab, Grafana: alle HTTP 200

✅ **GHCR-Images existieren** (docker manifest inspect bestätigt frontend:staging)

---

## 9. WAS OFFEN / DEFEKT / UNFERTIG IST

❌ **clouds.py Migration nicht in Docker deployed** — alter Container-Stand
❌ **Vercel Frontend zeigt alte Provider** (Hetzner, GitKraken) — Code nicht rebuilt
❌ **0/7 Cloud Layers live_verified** — keine Tokens in Docker-Umgebung
❌ **Grafana Cloud** erscheint nirgendwo im Live-System
❌ **Hosted Staging Backend unreachable** — staging URL zeigt nur auf Vercel Frontend, kein Agent-API dahinter
❌ **LLM Gateway dry_run** — keine echten KI-Calls möglich

---

## 10. NÄCHSTE EHRLICHE SCHRITTE (Priorisiert)

1. **Docker Dev-Stack neu bauen** — damit clouds.py Migration live geht: `docker compose -f docker-compose.dev.yml build agent-api && docker compose -f docker-compose.dev.yml up -d agent-api`
2. **Tokens in Docker-Env injizieren** (via .env oder staging.local.env) — damit Provider live_verified werden können
3. **Frontend-Code-Review** — Technology-Page shows Hetzner/GitKraken, muss auf Fly.io/Grafana aktualisiert werden
4. **Staging-Backend** aufsetzen — entweder auf Fly.io deployen oder Vercel Rewrites auf einen echten Backend-Host konfigurieren
