# TRAE AI — HOSTED DEPLOY / OPEN-THE-GATES PROMPT
# Project: -CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM
# Hand-off point: GHCR staging images are built & verified; now deploy to Fly + Vercel and close the gates.
# Generated: 2026-06-15

> COPY THIS as the Trae prompt. You run in the owner's environment with access to the Fly.io
> runtime host, Vercel, and the secrets file — things a sandboxed dev assistant cannot reach.
> Pick up exactly at ROLLOUT STEP 4. Do not rebuild what is already done.

═══════════════════════════════════════════════════════════════════════════════
## 0. WHERE WE ARE (do not redo steps 0–3)
═══════════════════════════════════════════════════════════════════════════════

DONE and verified:
- Branch `fly-cloud-redirect`, **current HEAD `8826805c`** pushed to origin (full locally-tested code state).
- All local/DEV gates green: `verify-phase1` (incl. gitleaks, no leaks), `verify-phase1-runtime`,
  `npm run verify:browser` (22 pages + phase2 + organism + memory), lint, build (21/21).
- **Cloud compose stack validated locally: 10/10 containers healthy** with the GHCR `:staging` images
  + `docker-compose.cloud.yml`. Three cloud-deploy bugs were fixed while bringing it up (commit `8826805c`):
  1. llm-gateway `/api/v1/health` only probes `local_llm_health()` when local is enabled (otherwise it
     blocked ~4s on the missing local-llm host and failed the healthcheck).
  2. agent-api manifest bind-mount source fixed `./progress` -> `./docs` (wrong path made Docker create a
     directory -> `IsADirectoryError`).
  3. Caddy site address defaults to `:80` when `STAGING_HOSTNAME` is empty (was crash-looping).
- Read-only token gate check ran: tokens authenticate (HF, GitLab identity OK), but external gates are
  **blocked only because nothing is publicly deployed yet**:
  `missing_or_failed_gates = hosted_agent_api_contracts, vercel_backend_origin_health`.

TWO STALENESS ITEMS TO FIX FIRST:
- **GHCR images are stale**: the last successful build was commit `42c8447d` (tags `42c8447d`,`staging`),
  which is BEFORE the llm-gateway health fix. Re-dispatch the build so `:staging` = HEAD `8826805c`:
  `gh workflow run main-deploy.yml --ref fly-cloud-redirect` (staging only; production job stays skipped).
- **The current Vercel deployment is stale**: `frontend-cn3c6w99n-…vercel.app` still shows retired nav
  routes `/about/stack` and `/about/open-source` and old labels ("Open by Design", "Tools / Cloud Hub").
  The committed code uses `/technology`, `/open-source`, "MCP / Tools", "Open Source". Redeploy the frontend
  from `fly-cloud-redirect` (HEAD `8826805c`) so the nav matches the corrected, tested code.

YOUR JOB: (a) re-dispatch the GHCR build for HEAD, (b) execute ROLLOUT STEPS 4→6 (deploy backend to a
public HTTPS host + redeploy frontend + prove), then 7→8, and guide the owner through owner-only STEP 9
(manual GitHub UI). Keep STEP 10 (post-rollout verify) green. NOTE: a backend running only on the owner's
localhost cannot close the hosted gates — the Fly origins must be public HTTPS.

═══════════════════════════════════════════════════════════════════════════════
## 1. SECRETS & SAFETY (absolute — never break)
═══════════════════════════════════════════════════════════════════════════════

- Secrets live at `C:\Users\immer\.trae\secrets\cloud-superbrain.local.env` (OUTSIDE the repo).
  Present keys: `GITHUB_TOKEN, GHCR_TOKEN, FLY_API_TOKEN, VERCEL_TOKEN, STAGING_BASE_URL, HF_TOKEN`.
  **Missing: `BRANCH_PROTECTION_TOKEN`** (needed for step 7 — either add a PAT with `admin:repo`,
  or use `GITHUB_TOKEN` if it has admin rights).
- Load them only into the process env (e.g. `. .\scripts\import-local-env.ps1 -EnvFilePath "C:\Users\immer\.trae\secrets\cloud-superbrain.local.env"`).
  **Never print a token value, never write a secret into the repo, never commit one.**
- Budget is a **hard €20/month** cap across Vercel + Fly.io + GHCR + Grafana. Run
  `py -3 scripts/check_fly_infra_budget.py` (needs `FLY_API_TOKEN` in env) before/after scaling.
- **STEP 9 (production environment approval) is a MANUAL GitHub-UI action by the human owner.**
  You must NOT auto-approve it. No fake "done", no fake metrics, no secret output.
- `flyctl` is already authenticated as `strazzusochr@gmail.com`; `gh` is authenticated too.

═══════════════════════════════════════════════════════════════════════════════
## 2. ROLLOUT STEP 4 — Fly.io backend runtime
═══════════════════════════════════════════════════════════════════════════════

The hosted backend is `docker-compose.cloud.yml` (agent-api, agent-worker, memory-worker,
mcp-gateway, llm-gateway, postgres, redis, nginx, caddy) pulling the GHCR `:staging` images.
Frontend goes to Vercel separately (step 5). The 3 origin apps do not exist yet.

These are **PowerShell** lines (this repo's shell). Run them ONE AT A TIME, top to bottom.
Do NOT type a `PS D:\...>` prompt, do NOT add a leading `$`, do NOT type any `...`.

**Path A — compose stack pulling the GHCR `:staging` images (matches the rollout):**
```powershell
. .\scripts\import-local-env.ps1 -EnvFilePath "C:\Users\immer\.trae\secrets\cloud-superbrain.local.env"
[string]::IsNullOrWhiteSpace($env:GHCR_TOKEN)
$env:GHCR_TOKEN | docker login ghcr.io -u strazzusochr --password-stdin
$env:IMAGE_TAG = "staging"
docker compose -f docker-compose.cloud.yml pull
docker compose -f docker-compose.cloud.yml up -d
docker compose -f docker-compose.cloud.yml ps
```
Success checks:
- after the import line: output shows `env_file=present` and `loaded_keys=...`
- after `[string]::IsNullOrWhiteSpace($env:GHCR_TOKEN)`: it must print `False`
- after `docker login`: `Login Succeeded`
- after `ps`: every service shows healthy/running
Run the import line FIRST and confirm `False` before doing the docker lines.

**Path B — per-app `fly deploy` for the 3 gateways (flyctl already authed):**
```powershell
flyctl apps create cloud-superbrain-agent-api
flyctl apps create cloud-superbrain-llm-gateway
flyctl apps create cloud-superbrain-mcp-gateway
flyctl deploy -c fly.agent-api.toml --image ghcr.io/strazzusochr/cloud-superbrain-developer-platform/agent-api:staging
flyctl deploy -c fly.llm-gateway.toml --image ghcr.io/strazzusochr/cloud-superbrain-developer-platform/llm-gateway:staging
flyctl deploy -c fly.mcp-gateway.toml --image ghcr.io/strazzusochr/cloud-superbrain-developer-platform/mcp-gateway:staging
```
For Path B you must also provide Postgres (Fly Managed Postgres / pgvector) + Redis and wire
`DATABASE_URL` / `REDIS_URL` as Fly secrets via `flyctl secrets set`, and keep within budget.
Keep `LLM_GATEWAY_MODE=deterministic_dry_run` (default; local llama stays opt-in). Set `HF_TOKEN`
as a Fly secret only if/when live LLM is explicitly wanted.

After step 4: each origin must answer `GET /api/v1/health` over HTTPS.

**KNOWN FLY PER-APP GAPS (Path B) — handle these or the deploy fails:**
- The agent-api Dockerfile only does `COPY app ./app`; it does NOT bake the files that
  `docker-compose.cloud.yml` bind-mounts: `docs/project-progress.manifest.json`,
  `docs/runtime-state/external-gate-summary.json`, `PROJECT_STATE.md`,
  `docs/codex-integration/autonomous-agent-roster.json`. On Fly there are no bind-mounts, so either
  (a) bake these into the image (COPY them in the Dockerfile with a repo-root build context), or
  (b) ship them another way. Health no longer 500s without them (it degrades — commit `f5adbe05`),
  but progress/gate DATA will be empty until the manifest is present, so the gate verifiers stay red.
- `fly.agent-api.toml [env]` has no `DATABASE_URL` / `REDIS_URL`. Provide Postgres (Fly Managed
  Postgres / pgvector) + Redis and set `flyctl secrets set DATABASE_URL=... REDIS_URL=...` per app.
- Path A (compose on a Fly runtime VM) keeps the bind-mounts and avoids both gaps, but needs a VM
  with the repo checked out. The compose stack is already proven healthy locally (10/10).

**CLOUD/FLY CONFIG AUDIT (2026-06-15, by the dev agent) — RECOMMENDATION: prefer Path A.**
Verified consistent: container ports (agent-api 8000, llm-gateway 4000, mcp-gateway 9000 all match
`internal_port`/`EXPOSE`/uvicorn), and all cloud-compose bind-mount sources now exist. Path B (three
standalone Fly apps) is currently INCOMPLETE — fix all of these before using it:
- `fly.agent-api.toml [env]` lacks `DATABASE_URL`, `REDIS_URL`, `LLM_GATEWAY_INTERNAL_URL`,
  `MCP_GATEWAY_INTERNAL_URL`; agent-api runs DB migrations at startup and will crash without DB/Redis.
- No Fly config exists for `agent-worker` or `memory-worker` (no hosted task/memory processing) and
  no managed Postgres/Redis is declared.
- Build-from-source on Fly fails (Dockerfile `COPY` paths are relative to `services/<svc>/`, Fly's
  context is the repo root) → you MUST deploy with `--image ghcr.io/...:staging`, never a source build.
- `fly.toml` duplicates agent-api (app `cloud-superbrain`) — pick one, avoid double-deploy.
- Fly `[http_service]` blocks have no HTTP health-check path (TCP-only); add an `[[http_service.checks]]`
  hitting `/api/v1/health` so a degraded backend is detected.
Path A (compose on a single Fly runtime VM) sidesteps all five (workers + Postgres + Redis + bind-mounts
included) and is already proven healthy locally. Use Path A unless you intend to fully build out Path B.

═══════════════════════════════════════════════════════════════════════════════
## 3. ROLLOUT STEP 5 — Vercel frontend + backend origins
═══════════════════════════════════════════════════════════════════════════════

PowerShell, one line at a time. Replace the three URLs with the real HTTPS Fly hostnames from
step 4 (these origins are URLs, not secrets):
```powershell
# Path A (single compose staging host behind Caddy/nginx):
"https://<STAGING_HOST>" | vercel env add AGENT_API_BASE_URL production
"https://<STAGING_HOST>/mcp" | vercel env add MCP_GATEWAY_BASE_URL production
"https://<STAGING_HOST>/llm" | vercel env add LLM_GATEWAY_BASE_URL production

# Path B (three separate Fly apps):
"https://cloud-superbrain-agent-api.fly.dev" | vercel env add AGENT_API_BASE_URL production
"https://cloud-superbrain-mcp-gateway.fly.dev" | vercel env add MCP_GATEWAY_BASE_URL production
"https://cloud-superbrain-llm-gateway.fly.dev" | vercel env add LLM_GATEWAY_BASE_URL production

vercel deploy --prod
```
Use the Path A values only when step 4 was deployed as the single hosted compose stack. Use the Path B values only when the three standalone Fly gateway apps really exist and answer health checks over HTTPS.
Confirm each origin returns 2xx through the deployed frontend rewrites. `STAGING_BASE_URL` must be
the live HTTPS Vercel (or Fly) host.

═══════════════════════════════════════════════════════════════════════════════
## 4. ROLLOUT STEP 6 — prove the gates close (THIS is the goal)
═══════════════════════════════════════════════════════════════════════════════

PowerShell, one line at a time:
```powershell
. .\scripts\import-local-env.ps1 -EnvFilePath "C:\Users\immer\.trae\secrets\cloud-superbrain.local.env"
powershell -ExecutionPolicy Bypass -File scripts\verify-hosted-staging.ps1 -BaseUrl $env:STAGING_BASE_URL
powershell -ExecutionPolicy Bypass -File scripts\verify-all-gates-with-tokens.ps1 -EnvFilePath "C:\Users\immer\.trae\secrets\cloud-superbrain.local.env"
```
Success = `hosted_agent_api_contracts` and `vercel_backend_origin_health` move from
missing/failed to verified, and `hosted_staging_claim_allowed=true`. If a gate stays red, read
the audit JSON in `.phase1-artifacts/external-gate-audit-*.json`, fix the origin/env, redeploy,
re-run. Never fake-pass a gate.

═══════════════════════════════════════════════════════════════════════════════
## 5. ROLLOUT STEPS 7–10
═══════════════════════════════════════════════════════════════════════════════

- **7 · Branch protection:** `py -3 scripts\apply_github_branch_protection.py --verify-only`
  (apply WITHOUT `--verify-only` only as the owner; needs `BRANCH_PROTECTION_TOKEN` or admin `GITHUB_TOKEN`).
- **8 · Release artifact:** create `docs/release-artifacts/prod-candidate-2026-06-15-rc1.md` with the
  real hosted evidence + explicit owner written sign-off. No fabricated results.
- **9 · Production approval (OWNER, MANUAL):** trigger `gh workflow run main-deploy.yml -f deploy_environment=production`,
  then APPROVE the GitHub `production` environment gate in the Actions UI. **You do not do this — the human owner does.**
- **10 · Post-rollout:** re-run hosted health + smoke, update `docs/project-progress.manifest.json`
  ONLY after real proof (no fake % increase), and `verify-all-gates-with-tokens.ps1` once more.

═══════════════════════════════════════════════════════════════════════════════
## 6. DO-NOT-REGRESS (verified posture from the 2026-06-15 build test)
═══════════════════════════════════════════════════════════════════════════════

- LLM gateway default = `deterministic_dry_run`, `LLM_LIVE_PROVIDER_DEFAULT=false`. Local llama is
  opt-in via `LLM_GATEWAY_MODE=local_openai_live` (it reports `model_downloads:true` but always
  `live_provider_calls:false`; bounded by `LOCAL_LLM_MAX_TOKENS_DEFAULT`).
- Phase-2 orchestration is deterministic (`metadata.deterministic_dry_run=true`); the gateway must
  honor it and the orchestrator must degrade (never 500) on gateway errors.
- `local-llm` dev healthcheck uses `curl`; dev stack = 10 containers.
- When you change code, update its guard/verifier in the same change and re-run it. Never weaken a
  guard or set a "no-live/no-download" flag false just to pass — make checks context-aware.
- Full evidence: `FINAL_BUILD_TEST_PROTOCOL_2026-06-15.md`. Architecture truth: `docs/system-architecture.md`,
  `AGENTS.md`, `PROJECT_STATE.md`.

═══════════════════════════════════════════════════════════════════════════════
## 7. REPORT FORMAT
═══════════════════════════════════════════════════════════════════════════════

After each step report: (1) what ran + result, (2) gate status delta, (3) remaining blockers,
(4) next safe command. Localhost evidence stays labeled `DEV-ONLY`. Stop and ask the owner before
step 9 and before anything that exceeds the €20/month budget.

— END OF DEPLOY PROMPT —
