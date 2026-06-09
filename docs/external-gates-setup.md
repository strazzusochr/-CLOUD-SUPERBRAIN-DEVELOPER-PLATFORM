## External Gates Setup (no secrets in repo)

Dieses Dokument beschreibt nur, welche Umgebungsvariablen du setzen musst, damit `npm run verify:external-gates` die External Gates als `verified` prüfen kann.

Wichtig:
- Keine Tokens/Secrets committen oder in Dateien im Repo schreiben.
- Werte als Environment-Variablen (Shell, CI Secrets, Docker Desktop Env) setzen.
- Hosted Targets müssen HTTPS sein (kein localhost).

### hosted_agent_api_contracts (Hosted Staging URL)

- Variable: `STAGING_BASE_URL`
- Erwartung: echte HTTPS Base-URL deiner Staging-Instanz (Frontend + API Rewrites erreichbar)
- Darf kein retired `sslip.io`/Hetzner-era Ziel sein; aktive Hosted-Gates erwarten die Vercel HTTPS-Staging-/Preview-Domain.
- Beispiel:
  - `STAGING_BASE_URL=https://staging.example.com`

### vercel_backend_origin_health (Vercel Origins)

Diese 3 Origins müssen auf echte HTTPS-URLs zeigen (jeweils die Base-URL, ohne trailing slash).

Repo-seitig vorbereitet:

| Variable | Fly-App | Config |
| --- | --- | --- |
| `AGENT_API_BASE_URL` | `cloud-superbrain-agent-api` | `fly.agent-api.toml` |
| `MCP_GATEWAY_BASE_URL` | `cloud-superbrain-mcp-gateway` | `fly.mcp-gateway.toml` |
| `LLM_GATEWAY_BASE_URL` | `cloud-superbrain-llm-gateway` | `fly.llm-gateway.toml` |

Wenn `AGENT_API_BASE_URL`, `MCP_GATEWAY_BASE_URL` oder `LLM_GATEWAY_BASE_URL` fehlen, kann `scripts/verify-all-gates-with-tokens.ps1` sie aus den privaten Fly-App-Name-Variablen `FLY_APP_AGENT_API`, `FLY_APP_MCP_GATEWAY` und `FLY_APP_LLM_GATEWAY` als `https://<app>.fly.dev` ableiten. Sind diese Variablen nicht gesetzt, verwendet der Runner die in den Fly-Config-Dateien geprüften App-Namen als Default. Platzhalter oder nicht-HTTPS-Werte bleiben blockiert.

Die Vercel/Next.js-Rewrites in `apps/frontend/next.config.mjs` nutzen dieselbe Reihenfolge: explizite HTTPS-Origin-URL, dann Fly-App-Name oder Fly-Default, dann erst der `STAGING_REWRITES_ENABLED=true` Hosted-Rewrite-Fallback. `scripts/verify-frontend-cloud-rewrites.ps1` prueft diese Matrix ohne Secrets und ohne Deploy.

Deploy-Kommandos bleiben owner-gated und duerfen erst mit explizitem Deploy-Gate ausgefuehrt werden:

```powershell
flyctl deploy --config fly.agent-api.toml
flyctl deploy --config fly.mcp-gateway.toml
flyctl deploy --config fly.llm-gateway.toml
```

- Variable: `AGENT_API_BASE_URL`
  - Erwartung: HTTPS Origin, der unter `/api/v1/health` den Marker `agent-api` zurückliefert
  - Beispiel: `AGENT_API_BASE_URL=https://agent-api-staging.example.com`

- Variable: `MCP_GATEWAY_BASE_URL`
  - Erwartung: HTTPS Origin, der unter `/api/v1/health` den Marker `mcp-gateway` zurueckliefert; path-prefixed Reverse-Proxy-URLs wie `https://staging.example.com/mcp` werden weiterhin als `/mcp/api/v1/health` geprueft.
  - Beispiel: `MCP_GATEWAY_BASE_URL=https://mcp-gateway-staging.example.com`

- Variable: `LLM_GATEWAY_BASE_URL`
  - Erwartung: HTTPS Origin, der unter `/api/v1/health` den Marker `llm-gateway` zurueckliefert; path-prefixed Reverse-Proxy-URLs wie `https://staging.example.com/llm` werden weiterhin als `/llm/api/v1/health` geprueft.
  - Beispiel: `LLM_GATEWAY_BASE_URL=https://llm-gateway-staging.example.com`

### github_branch_protection_current_verify (Branch Protection Verify)

Option A (empfohlen, API-basiert):
- Variable: `BRANCH_PROTECTION_TOKEN`
- Erwartung: GitHub Token mit Rechten, Branch Protection für das Repo zu lesen (verify-only)
- Beispiel: `BRANCH_PROTECTION_TOKEN=<your_token>`

Option B (Remote Verify-only via SSH auf Staging):
- Variablen:
  - `STAGING_SSH_HOST` (IPv4/Hostname)
  - `STAGING_SSH_USER`
  - `STAGING_SSH_KEY_PATH` (lokaler Pfad zur Private Key Datei)
  - `STAGING_APP_DIR` (Remote App Verzeichnis mit `.env`)

### fly_live_budget_check (Fly.io)

- Variable: `FLY_API_TOKEN`
- Erwartung: echter Fly.io API Token (wird nur für Live-State Probe verwendet)
- Beispiel: `FLY_API_TOKEN=<your_token>`
