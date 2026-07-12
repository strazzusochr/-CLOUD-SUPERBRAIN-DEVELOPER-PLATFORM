# Owner Go-Live Checklist

Generated: 2026-06-13

Status: `READINESS_PACK_CREATED`; no deploy executed, no Fly app created, no
secret set, no registry push, no production action, no external gate opened.

This checklist is for the Owner shell only. Codex may verify and prepare the
plan, but must not run the cloud mutation commands without the explicit project
gates.

## Current Truth

- Project progress remains controlled by `docs/project-progress.manifest.json`.
- Localhost evidence remains `DEV-ONLY`; hosted proof is still blocked until a
  real HTTPS `STAGING_BASE_URL` exists.
- Active cloud defaults remain Vercel frontend, Fly.io service runtime, GHCR,
  Grafana Cloud, Postgres/pgvector, and Redis.
- Retired active defaults stay out: Hetzner, GitKraken, Oracle, Supabase,
  Qdrant, LanceDB, Ollama, Railway, Hugging Face Spaces, GPU servers.

## Fly Apps

Read from the checked-in Fly configs:

| Service | Fly config | App name | Region | Internal port | Existence proof |
| --- | --- | --- | --- | --- | --- |
| Agent API | `fly.agent-api.toml` | `cloud-superbrain-agent-api` | `fra` | `8000` | Unknown: local Fly CLI has no token |
| MCP Gateway | `fly.mcp-gateway.toml` | `cloud-superbrain-mcp-gateway` | `fra` | `9000` | Unknown: local Fly CLI has no token |
| LLM Gateway | `fly.llm-gateway.toml` | `cloud-superbrain-llm-gateway` | `fra` | `4000` | Unknown: local Fly CLI has no token |

Read-only command attempted:

```powershell
& $env:USERPROFILE\.fly\bin\flyctl.exe apps list
```

Observed result:

```text
Error: no access token available. Please login with 'flyctl auth login'
```

Conclusion: app existence is `unverified`, not `missing`. The Owner must
authenticate and rerun the read-only app list before creating anything.

## Owner Decisions Required

- Fly organization for app creation: `<OWNER_FLY_ORG>`.
- Postgres provider/app name, region, database/user policy, and migration owner.
- Redis provider and final `REDIS_URL`.
- Vercel project/org and real HTTPS `STAGING_BASE_URL`.
- Whether LLM Gateway remains dry-run or a live LLM provider gate is opened.
- Whether GitHub MCP read/write scope is approved; write-capable MCP remains
  gated.
- Whether external verifier tokens are supplied privately for read-only gate
  checks.

Do not set `E2B_API_KEY` as an active default. The project does not currently
use E2B as an active cloud/runtime default; any reintroduction needs an ADR and
Owner gate.

## Runtime Secrets And Env Names

Only names and placeholders are listed here. Do not paste real secret values into
the repo, chat, docs, logs, screenshots, or artifacts.

### Agent API

Required for cloud runtime:

- `DATABASE_URL`
- `REDIS_URL`
- `MCP_GATEWAY_URL`
- `LLM_GATEWAY_URL`
- `JWT_SIGNING_SECRET`
- `STAGING_BASE_URL`
- `AGENT_API_BASE_URL`
- `MCP_GATEWAY_BASE_URL`
- `LLM_GATEWAY_BASE_URL`

Optional/auth or external verifier names:

- `GITHUB_OAUTH_CLIENT_ID`
- `GITHUB_OAUTH_CLIENT_SECRET`
- `FLY_API_TOKEN`
- `BRANCH_PROTECTION_TOKEN`
- `VERCEL_TOKEN`
- `VERCEL_PROJECT_ID`
- `VERCEL_ORG_ID`
- `GITHUB_TOKEN`
- `GHCR_TOKEN`
- `GHCR_OWNER`
- `GHCR_PACKAGE`
- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_ZONE_ID`
- `CLOUDFLARE_AI_GATEWAY_URL`
- `CLOUDFLARE_DASHBOARD_URL`
- `GRAFANA_CLOUD_API_KEY`
- `GRAFANA_CLOUD_URL`
- `HF_TOKEN`
- `GITLAB_TOKEN`
- `GITLAB_PROFILE_URL`
- `GITLAB_API_URL`

Copyable staged template:

```powershell
& $env:USERPROFILE\.fly\bin\flyctl.exe secrets set --app cloud-superbrain-agent-api --stage `
  DATABASE_URL="<POSTGRES_DATABASE_URL_WITH_PGVECTOR>" `
  REDIS_URL="<REDIS_URL>" `
  MCP_GATEWAY_URL="https://<STAGING_HOST>/mcp" `
  LLM_GATEWAY_URL="https://<STAGING_HOST>/llm" `
  JWT_SIGNING_SECRET="<OWNER_GENERATED_JWT_SIGNING_SECRET>" `
  STAGING_BASE_URL="<VERCEL_STAGING_HTTPS_URL>" `
  AGENT_API_BASE_URL="https://<STAGING_HOST>" `
  MCP_GATEWAY_BASE_URL="https://<STAGING_HOST>/mcp" `
  LLM_GATEWAY_BASE_URL="https://<STAGING_HOST>/llm"
```

### MCP Gateway

Required for cloud runtime:

- `AGENT_API_INTERNAL_URL`
- `GITHUB_TOKEN` only when scoped GitHub MCP capabilities are Owner-approved.

Config value already in `fly.mcp-gateway.toml`:

- `FILESYSTEM_ROOT=/tmp/agent-workspace`

Copyable staged template:

```powershell
& $env:USERPROFILE\.fly\bin\flyctl.exe secrets set --app cloud-superbrain-mcp-gateway --stage `
  AGENT_API_INTERNAL_URL="https://<STAGING_HOST>"
```

If GitHub MCP scope is not approved, omit `GITHUB_TOKEN`. Live MCP writes remain
closed until the project write gate explicitly opens them.
If it is approved, set `GITHUB_TOKEN` in a separate private Owner-shell command
without recording the value in this runbook or terminal evidence.

### LLM Gateway

Required for dry-run cloud runtime and audit callbacks:

- `AGENT_API_INTERNAL_URL`
- `LLM_GATEWAY_MODE`
- `LLM_LIVE_PROVIDER_DEFAULT`

Required only after Owner opens a live provider gate:

- `HF_TOKEN` for Hugging Face Router live calls.
- `HF_ROUTER_BASE_URL`
- `HF_DEFAULT_CHAT_MODEL`
- `HF_ROUTER_TIMEOUT_SECONDS`

`HUGGINGFACE_HUB_TOKEN` is accepted by code as an alias, but this project should
use canonical `HF_TOKEN` for clarity.

Copyable staged template:

```powershell
& $env:USERPROFILE\.fly\bin\flyctl.exe secrets set --app cloud-superbrain-llm-gateway --stage `
  AGENT_API_INTERNAL_URL="https://<STAGING_HOST>" `
  HF_ROUTER_BASE_URL="https://router.huggingface.co/v1" `
  HF_DEFAULT_CHAT_MODEL="<OWNER_APPROVED_MODEL_ID>" `
  HF_ROUTER_TIMEOUT_SECONDS="90" `
  LLM_GATEWAY_MODE="deterministic_dry_run" `
  LLM_LIVE_PROVIDER_DEFAULT="false"
```

Set `HF_TOKEN` only after the live-provider Owner gate opens, using a separate
private Owner-shell command that does not record the value in evidence.

For strict dry-run, omit `HF_TOKEN` and keep `LLM_LIVE_PROVIDER_DEFAULT=false`.

## Postgres Pgvector And Redis

Postgres is required for Agent API startup. The code raises when
`DATABASE_URL` is missing. The cloud database must support:

- `CREATE EXTENSION IF NOT EXISTS vector;`
- `CREATE EXTENSION IF NOT EXISTS pgcrypto;`

Owner-side Fly Postgres pattern, if Fly Postgres is selected:

```powershell
& $env:USERPROFILE\.fly\bin\flyctl.exe postgres create --name <OWNER_POSTGRES_APP_NAME> --region fra --org <OWNER_FLY_ORG>
& $env:USERPROFILE\.fly\bin\flyctl.exe postgres attach --app cloud-superbrain-agent-api <OWNER_POSTGRES_APP_NAME>
```

Then run the extension and migration/init path through the approved migration
owner. Example command shape, using the private database URL only in Owner shell:

```powershell
psql "$env:DATABASE_URL" -c "CREATE EXTENSION IF NOT EXISTS vector; CREATE EXTENSION IF NOT EXISTS pgcrypto;"
```

Redis is required by the Agent API for working memory, queues, and runtime
health. Attach it by setting `REDIS_URL` on `cloud-superbrain-agent-api`. The MCP
Gateway and LLM Gateway do not require Redis in the current service code.

## Local Docker Build Check

No deploy or push was run.

Commands required for local Fly build readiness:

```powershell
docker build -f services/agent-api/Dockerfile -t cloud-superbrain-agent-api:fly-build-check services/agent-api
docker build -f services/mcp-gateway/Dockerfile -t cloud-superbrain-mcp-gateway:fly-build-check services/mcp-gateway
docker build -f services/llm-gateway/Dockerfile -t cloud-superbrain-llm-gateway:fly-build-check services/llm-gateway
```

Observed local result:

| Build | Result |
| --- | --- |
| Agent API | `BLOCKED_LOCAL_DOCKER_TIMEOUT` after 600s |
| MCP Gateway | `BLOCKED_LOCAL_DOCKER_TIMEOUT` after 600s |
| LLM Gateway | Not run after Docker daemon/BuildKit became unresponsive |

After the two timeouts, `docker version` and `docker ps` also timed out locally.
This is a local Docker/BuildKit readiness blocker. Restart Docker Desktop or
BuildKit, rerun all three build commands, and continue only after all return exit
code `0`.

## Exact Owner Go-Live Order

### 0. Confirm Boundary

```powershell
git status --short
```

Confirm no real tokens are in the repo, chat, docs, logs, or generated
artifacts.

### 1. Authenticate Fly Locally

```powershell
& $env:USERPROFILE\.fly\bin\flyctl.exe auth login
& $env:USERPROFILE\.fly\bin\flyctl.exe apps list
```

If a private automation shell is used instead:

```powershell
# FLY_API_TOKEN vor diesem Schritt in der privaten Owner-Shell bereitstellen; nie inline dokumentieren.
& $env:USERPROFILE\.fly\bin\flyctl.exe apps list
```

### 2. Create Missing Fly Apps Only If Needed

Run this only for apps absent from `apps list`:

```powershell
& $env:USERPROFILE\.fly\bin\flyctl.exe apps create cloud-superbrain-agent-api --org <OWNER_FLY_ORG>
& $env:USERPROFILE\.fly\bin\flyctl.exe apps create cloud-superbrain-mcp-gateway --org <OWNER_FLY_ORG>
& $env:USERPROFILE\.fly\bin\flyctl.exe apps create cloud-superbrain-llm-gateway --org <OWNER_FLY_ORG>
```

### 3. Provision And Attach Postgres/Redis

Provision Postgres with pgvector support and Redis through the Owner-approved
provider. Attach by setting:

- `DATABASE_URL` on `cloud-superbrain-agent-api`
- `REDIS_URL` on `cloud-superbrain-agent-api`

If Fly Postgres is selected, use the pattern in the Postgres section above.

### 4. Stage Runtime Secrets

Run the three `flyctl secrets set --stage` templates from the service sections.
Keep real values only in the Owner shell.

Verify names only:

```powershell
& $env:USERPROFILE\.fly\bin\flyctl.exe secrets list --app cloud-superbrain-agent-api
& $env:USERPROFILE\.fly\bin\flyctl.exe secrets list --app cloud-superbrain-mcp-gateway
& $env:USERPROFILE\.fly\bin\flyctl.exe secrets list --app cloud-superbrain-llm-gateway
```

### 5. Re-run Local Docker Build Check

Proceed only when all three local build commands return exit code `0`.

### 6. Owner Deploys The Three Fly Apps

Owner-only cloud mutation:

```powershell
& $env:USERPROFILE\.fly\bin\flyctl.exe deploy -c fly.agent-api.toml --app cloud-superbrain-agent-api --remote-only
& $env:USERPROFILE\.fly\bin\flyctl.exe deploy -c fly.mcp-gateway.toml --app cloud-superbrain-mcp-gateway --remote-only
& $env:USERPROFILE\.fly\bin\flyctl.exe deploy -c fly.llm-gateway.toml --app cloud-superbrain-llm-gateway --remote-only
```

### 7. Health Check The Fly Origins

```powershell
Invoke-RestMethod https://<STAGING_HOST>/api/v1/health
Invoke-RestMethod https://<STAGING_HOST>/mcp/api/v1/health
Invoke-RestMethod https://<STAGING_HOST>/llm/api/v1/health
```

Do not continue unless all three return HTTP `200` and the expected service
markers.

### 8. Set Vercel Preview/Staging Env

Required names:

- `STAGING_REWRITES_ENABLED=1`
- `STAGING_BASE_URL=<VERCEL_STAGING_HTTPS_URL>`
- `AGENT_API_BASE_URL=https://<STAGING_HOST>`
- `MCP_GATEWAY_BASE_URL=https://<STAGING_HOST>/mcp`
- `LLM_GATEWAY_BASE_URL=https://<STAGING_HOST>/llm`

Example command shape:

```powershell
vercel env add STAGING_REWRITES_ENABLED preview
vercel env add STAGING_BASE_URL preview
vercel env add AGENT_API_BASE_URL preview
vercel env add MCP_GATEWAY_BASE_URL preview
vercel env add LLM_GATEWAY_BASE_URL preview
```

Use the Vercel dashboard instead if that is the Owner-approved path.

### 9. Hosted Verifiers

Run against the real Vercel HTTPS staging URL, without `-AllowLocalhost`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-browser-contract.ps1 -BaseUrl <STAGING_BASE_URL>
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-external-gates.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-all-gates-with-tokens.ps1 -HostedBaseUrl <STAGING_BASE_URL>
```

If optional identity tokens are not supplied, those identity gates may remain
blocked by design.

### 10. Owner Cloud Gate Activation PlanOnly

PlanOnly command, no apply:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\owner-cloud-gate-activation.ps1 `
  -StagingBaseUrl "<STAGING_BASE_URL>" `
  -AgentApiBaseUrl "https://<STAGING_HOST>" `
  -McpGatewayBaseUrl "https://<STAGING_HOST>/mcp" `
  -LlmGatewayBaseUrl "https://<STAGING_HOST>/llm"
```

The script is fail-closed for apply mode inside Codex. Use the emitted artifact
for Owner review.

### 11. Post-Deploy Hosted Human-Click-Proof

Use the real `STAGING_BASE_URL`, not localhost:

```powershell
node tools\ultimate_22_human_click_proof.mjs --base-url <STAGING_BASE_URL> --routes /home,/login,/workbench,/organism,/organism/replay,/organism/map,/agents,/files,/files/local,/tools,/marketplace,/observe,/games,/apps,/media,/docs-output,/evidence,/diagnostics,/design-system,/technology,/settings,/open-source --out .codex\runs\CURRENT\go-live\hosted-human-click-proof
```

Accept only if `report.json`, `report.md`, HAR, and screenshots exist and
`fail_count=0`. The report must be hosted proof, not `DEV-ONLY` localhost proof.

## Evidence From This Preparation

- `flyctl.exe secrets set --help` verified `--stage` is available.
- `flyctl.exe apps create --help` verified app creation syntax.
- `flyctl.exe deploy --help` verified `--remote-only`, `--config`, and `--app`.
- `flyctl.exe apps list` could not verify app existence because no access token
  is available locally.
- Local Docker build readiness is blocked by Docker/BuildKit timeout, not by an
  executed cloud deploy.

## Non-Claims

- No Fly deploy executed.
- No Fly app created.
- No Fly secret set.
- No Vercel env changed.
- No GHCR image pushed.
- No live LLM call made.
- No live MCP write enabled.
- No production deployment or release promotion.
- No external gate closed by localhost evidence.
