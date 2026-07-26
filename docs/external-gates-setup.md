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

| Variable | Rolle |
| --- | --- |
| `AGENT_API_BASE_URL` | Hosted Agent-API-Origin oder konsolidierter Staging-Origin |
| `MCP_GATEWAY_BASE_URL` | Hosted MCP-Origin oder `<STAGING_BASE_URL>/mcp` |
| `LLM_GATEWAY_BASE_URL` | Hosted LLM-Origin oder `<STAGING_BASE_URL>/llm` |

`scripts/verify-all-gates-with-tokens.ps1` verwendet ausschließlich explizite HTTPS-Origins oder den konsolidierten `STAGING_BASE_URL`-Fallback. Es leitet keine Fly.io-Origins ab. Platzhalter oder nicht-HTTPS-Werte bleiben blockiert.

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
- Den Wert ausschließlich in einer privaten Owner-Shell bereitstellen; dieses Dokument enthält bewusst keine Inline-Zuweisung.

Option B (Remote Verify-only via SSH auf Staging):
- Variablen:
  - `STAGING_SSH_HOST` (IPv4/Hostname)
  - `STAGING_SSH_USER`
  - `STAGING_SSH_KEY_PATH` (lokaler Pfad zur Private Key Datei)
  - `STAGING_APP_DIR` (Remote App Verzeichnis mit `.env`)

### cloudflare_native_zero_card_hosted_runtime (O2′)

- Variablen: `CLOUDFLARE_STATEFUL_BASE_URL`, `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_API_TOKEN`
- Erforderliche Least-Privilege-Scopes: Workers Scripts Edit, D1 Edit, Durable Objects Edit, Queues Edit, Workers AI Read sowie R2 Edit nur nach verifizierter Zero-Card-Freigabe.
- Hosted-Proof: `scripts/verify-cloudflare-stateful-runtime.ps1 -BaseUrl <CLOUDFLARE_STATEFUL_BASE_URL> -AllowHostedWrites`
- Der Hosted-Lauf und jede Ressourcenänderung bleiben Owner-gated. Tokenwerte dürfen nie in Repo, Log oder Artefakt geschrieben werden.

Der frühere `fly_live_budget_check` ist `historical_only` und kein aktives Gate.
