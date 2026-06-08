## External Gates Setup (no secrets in repo)

Dieses Dokument beschreibt nur, welche Umgebungsvariablen du setzen musst, damit `npm run verify:external-gates` die External Gates als `verified` prüfen kann.

Wichtig:
- Keine Tokens/Secrets committen oder in Dateien im Repo schreiben.
- Werte als Environment-Variablen (Shell, CI Secrets, Docker Desktop Env) setzen.
- Hosted Targets müssen HTTPS sein (kein localhost).

### hosted_agent_api_contracts (Hosted Staging URL)

- Variable: `STAGING_BASE_URL`
- Erwartung: echte HTTPS Base-URL deiner Staging-Instanz (Frontend + API Rewrites erreichbar)
- Beispiel:
  - `STAGING_BASE_URL=https://staging.example.com`

### vercel_backend_origin_health (Vercel Origins)

Diese 3 Origins müssen auf echte HTTPS-URLs zeigen (jeweils die Base-URL, ohne trailing slash).

- Variable: `AGENT_API_BASE_URL`
  - Erwartung: HTTPS Origin, der unter `/api/v1/health` den Marker `agent-api` zurückliefert
  - Beispiel: `AGENT_API_BASE_URL=https://agent-api-staging.example.com`

- Variable: `MCP_GATEWAY_BASE_URL`
  - Erwartung: HTTPS Origin, der unter `/mcp/api/v1/health` den Marker `mcp-gateway` zurückliefert
  - Beispiel: `MCP_GATEWAY_BASE_URL=https://mcp-gateway-staging.example.com`

- Variable: `LLM_GATEWAY_BASE_URL`
  - Erwartung: HTTPS Origin, der unter `/llm/api/v1/health` den Marker `llm-gateway` zurückliefert
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
