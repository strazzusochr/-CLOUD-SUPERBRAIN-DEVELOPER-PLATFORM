# Codex Desktop Handoff - Cloud Superbrain Developer Platform

Created: 2026-04-30
Purpose: 1:1 handoff from the hanging chat environment into Codex Desktop.

This file is intentionally token-free. It names secret locations and variable names, but it does not copy secret values.

## Copy-Paste Prompt For Codex Desktop

```text
You are continuing the Cloud Superbrain Developer Platform.

Open this project folder:
<repo-root>

Do not use a clean git clone as the only source. The current state contains many required untracked and modified files. Use the whole local folder or commit/stage/push all local changes first.

First read, in this order:
1. CODEX_DESKTOP_HANDOFF_2026-04-30.md
2. PROJECT_STATE.md
3. PROJECT_ANCHOR.md
4. AI_HANDOFF.md
5. docs/project-checkpoint-2026-04-30.json
6. AGENTS.md
7. docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md
8. docs/project-progress.manifest.json
9. docs/verification-register.md

Current verified state:
- Overall progress: 47%
- Phase 0: 100%
- Phase 1: 98%
- Phase 2: 86%
- Phase 3: 33%
- Phase 4: 15%
- Phase 5: 0%
- Phase 6: 0%
- Frontend: 97%
- Orchestrator/LangGraph: 99%
- Agent Pool: 61%
- LLM Gateway: 53%
- MCP Gateway: 53%
- Memory: 69%
- Observability: 99%

Runtime entrypoints:
- Browser: <local-control-plane-url>/
- Agent stream/autopilot: <local-control-plane-stream-url>
- Health: <local-control-plane-url>/api/v1/health
- Progress integrity: <local-control-plane-url>/api/v1/project/progress/integrity

Before making changes, verify:
cd <repo-root>
docker compose -f docker-compose.dev.yml ps
curl.exe -s <local-control-plane-url>/api/v1/health
curl.exe -s <local-control-plane-url>/api/v1/project/progress/integrity
powershell -ExecutionPolicy Bypass -File scripts\verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost
powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1

Important rules:
- Never paste or print secret values.
- Do not raise progress percentages without code, runtime proof, verifier proof, and documentation update.
- No production deployment claim.
- No hosted staging success claim until STAGING_BASE_URL points to a real hosted stack and hosted verifiers pass.
- No live LLM provider claim.
- No live MCP write claim.
- No branch protection claim without BRANCH_PROTECTION_TOKEN or equivalent verified GitHub token.
- Keep LangGraph + PostgreSQL checkpointing as the orchestration spine.
- Keep memory in PostgreSQL/pgvector through the service.
- Keep deterministic local proofs unless external gates are explicitly configured.
```

## Project Identity

Primary project:

- Path: `<repo-root>`
- Remote: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM.git`
- Branch: `chore/repo-bootstrap`
- Local branch state: ahead of `origin/chore/repo-bootstrap` by 1 commit
- Latest local commit: `0591200 chore: Phase-0 Audit-Merge - Patch Ultimatum Finale`

Parent workspace:

- Path: `<workspace-root>`
- Branch: `chore/repo-bootstrap`
- State: ahead 1, behind 3, dirty
- The primary project appears as a modified nested repo/subtree from the parent workspace.

Secondary/older workspace:

- Path: `<workspace-root>\cloud-superbrain-fresh`
- Contains an actual `.env` with older/fresh-build secrets and settings.
- Treat it as a legacy/reference working copy unless a human explicitly says to switch roots.

## Binding Truth

Use these files as the current truth:

- `PROJECT_STATE.md`
- `PROJECT_ANCHOR.md`
- `AI_HANDOFF.md`
- `docs/project-checkpoint-2026-04-30.json`
- `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md`
- `docs/project-progress.manifest.json`
- `docs/verification-register.md`
- `docs/phase-2-readiness-matrix.md`

If older docs conflict, prefer `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md`, `PROJECT_STATE.md`, and `docs/project-progress.manifest.json`.

## Current Goal

Build the Cloud Superbrain Developer Platform: a cloud-native, prompt-driven, multi-agent AI developer platform that is LangGraph-orchestrated, PostgreSQL/pgvector-backed, observable, budget-guarded, and able to run specialist agent workflows for application and 3D web-game delivery.

Hard constraints:

- Infrastructure budget: hard cap around 20 EUR/month.
- LLM/API budget: 200 EUR/month for early phases.
- No local model downloads as runtime architecture.
- No Qdrant in Phase 1-5.
- No active Supabase/LanceDB/Ollama/Railway/HuggingFace Spaces runtime unless a new ADR and owner gate explicitly change that.
- Production is cloud-hosted, not localhost.
- Vercel frontend, Hetzner backend, Cloudflare edge/cache are the intended cloud path.
- Evidence-based progress only.

## Current Runtime State

Checked during this handoff:

- `GET <local-control-plane-url>/api/v1/health`: healthy.
- `GET <local-control-plane-url>/api/v1/project/progress/integrity`: verified.
- `GET <local-control-plane-url>/api/v1/sessions/recent?limit=3`: returned recent hosted-proof sessions.
- `docker compose -f docker-compose.dev.yml ps`: all expected services healthy.

Healthy Compose services:

- `agent-api`
- `agent-worker`
- `frontend`
- `llm-gateway`
- `mcp-gateway`
- `memory-worker`
- `nginx` on `0.0.0.0:8081`
- `postgres`
- `redis`

One sandbox note: in the previous chat environment, `docker compose ps` initially failed due Docker pipe permissions and then passed with elevated Docker access. Codex Desktop should usually be able to run Docker directly if Docker Desktop is available.

## Current Progress

Authoritative source: `docs/project-progress.manifest.json`.

Overall:

- Total project: `47%`

Horizontal phases:

- P0 Reboot and Goal Lock: `100%`
- P1 Foundation Runtime: `98%`
- P2 Core Runtime: `86%`
- P3 Product Surface and Security: `33%`
- P4 Integration and Hardening: `15%`
- P5 Release Readiness: `0%`
- P6 Scale and 3D Platform: `0%`

Vertical architecture layers:

- Frontend / Next.js: `97%`
- Orchestrator / LangGraph: `99%`
- Agent Pool: `61%`
- LLM Gateway: `53%`
- MCP Gateway: `53%`
- Memory: `69%`
- Observability: `99%`

Current progress integrity:

- Contract: `project-progress-integrity-v1`
- Runtime evidence: `project_progress_integrity_runtime_proof`
- Manifest overall: `47`
- Computed overall: `47`
- Mismatches: none

## Reconstructed Chat/Work History

The UI chat history was unreliable/hanging, but the local project and Codex session artifacts allow a useful reconstruction.

Local Codex history/index paths:

- `C:\Users\immer\.codex\session_index.jsonl`
- `C:\Users\immer\.codex\history.jsonl`
- `C:\Users\immer\.codex\sessions\2026\04\29\rollout-2026-04-29T23-15-08-019ddb18-7cdd-7a23-a329-6c45c42a95de.jsonl`
- `C:\Users\immer\.codex\sessions\2026\04\29\rollout-2026-04-29T23-48-12-019ddb36-c41a-7592-bf65-c67081b1dd55.jsonl`
- `C:\Users\immer\.codex\sessions\2026\04\30\rollout-2026-04-30T03-53-35-019ddc17-6c09-7481-a2ec-e6c9ebdeae60.jsonl`
- `C:\Users\immer\.codex\archived_sessions\rollout-2026-04-30T01-11-33-019ddb83-133c-7cc2-887e-5d21e1622297.jsonl`

Relevant thread names found in `session_index.jsonl`:

- `Chatverlauf wiederherstellen` on 2026-04-20
- `Fix Chatverlauf-Zugriff` on 2026-04-29
- `Behebe Chatverlauf <local-control-plane-host>` on 2026-04-29
- `Clouds zu <local-control-plane-host> hinzufuegen` on 2026-04-30

Reconstructed work sequence:

1. The project was rebooted around a patched ultimatum/goal-lock architecture.
2. Phase 1 foundation runtime was implemented locally with Docker Compose, PostgreSQL/pgvector, Redis, Agent API, frontend, workers, MCP Gateway, and LLM Gateway.
3. Phase 2 deterministic runtime contracts were implemented and repeatedly proven locally without live provider calls.
4. The dashboard chat/run history broke or appeared stuck.
5. The history regression was investigated and fixed:
   - stale `agent-api` container while local code already had the route,
   - stale Nginx upstream IPs after service recreates,
   - slow recent-task listing due Redis one-GET-per-key behavior,
   - noisy frontend refresh loop,
   - unrelated optional root Docker restart loops.
6. Fixes were applied:
   - rebuild/verify `agent-api` and frontend,
   - dynamic Docker DNS resolver in `infrastructure/nginx/dev.conf`,
   - `mcp-gateway` health-gated Nginx dependency,
   - Redis `MGET` chunking in `services/agent-api/app/tasks.py`,
   - frontend data-load/refresh split in `apps/frontend/app/page.tsx`,
   - session-history regression guard in `scripts/verify-browser-contract.ps1`,
   - static guard strings in `scripts/verify-phase1.ps1`,
   - root Codex sandbox runner repaired at `<workspace-root>\codex-github-runner.py`,
   - optional invalid MCP restart loops marked host-CLI-only.
7. Evidence showed the run history panel opening again:
   - `GET /api/v1/sessions/ee81f6c1-703b-499d-9a33-b11d6b3cc0e0/history => 200 OK`
   - Contract: `session-history-v1`
   - Evidence: `session_history_openable_project_state`
   - Messages: `4`
   - Tasks: `4`
   - Audit events: `9`
8. Cloud preview work then started:
   - Vercel frontend preview exists and serves the Cloud Superbrain UI.
   - Cloud-only proof remains `action_required` because backend cloud URLs are not configured and the known Hetzner host is not serving the Cloud Superbrain Agent API.

## Important Evidence Artifacts

Root-level screenshots and snapshots:

- `<workspace-root>\superbrain-history-open-verified-2026-04-29.png`
- `<workspace-root>\superbrain-opened-history-panel-verified-2026-04-29.png`
- `<workspace-root>\superbrain-ai-browser-clean-proof-2026-04-29.png`
- `<workspace-root>\superbrain-live-proof-2026-04-29.png`
- `<workspace-root>\superbrain-live-ui-proof-47-viewport.png`
- `<workspace-root>\superbrain-progress-live-2026-04-29T2045.png`
- `<workspace-root>\superbrain-progress-section-2026-04-29T2045.png`
- `<workspace-root>\cloud-preview-redeploy-snapshot-20260430.md`
- `<workspace-root>\cloud-preview-redeploy-viewport-20260430.png`

Project artifacts:

- `<repo-root>\.phase1-artifacts\`
- `.phase1-artifacts\cloud-only-staging-proof-20260430-124141.json`
- `.phase1-artifacts\cloud-only-staging-proof-20260430-124747.json`
- `.phase1-artifacts\lighthouse-cloud-preview-20260430\`
- `.phase1-artifacts\lighthouse-cloud-redeploy-20260430\`
- `.phase1-artifacts\postgres-backups\`

Cloud preview runbook:

- `docs/runbooks/cloud-only-staging-proof-2026-04-30.md`

## Cloud State

Known cloud frontend preview:

- `https://frontend-mzssjbtcw-strazzusochrs-projects.vercel.app`
- Vercel deployment: `dpl_CvU8PHAUT8CEGTfjXdELTm6qQ16S`
- `/` returned the Cloud Superbrain UI.
- `/health` returned `ok`.
- `/api/health` returned the frontend health contract.
- Lighthouse redeploy snapshot: Accessibility `94`, Best Practices `100`, SEO `100`.

Cloud blockers from `docs/runbooks/cloud-only-staging-proof-2026-04-30.md`:

- `cloud_agent_api_health`
- `cloud_provider_inventory`
- `cloud_layer_readiness`
- `cloud_mcp_gateway_health`
- `cloud_llm_gateway_health`

Observed cloud root cause:

- Vercel frontend is live.
- Frontend supports rewrites through `AGENT_API_BASE_URL`, `MCP_GATEWAY_BASE_URL`, and `LLM_GATEWAY_BASE_URL`.
- Those Vercel environment variables are not configured for real cloud backend URLs.
- The known Hetzner IP responds over HTTPS but serves an `OpenHands` frontend instead of Cloud Superbrain Agent API.
- SSH to the Hetzner host was reachable but rejected the available local keys.
- `hcloud` is installed but has no active context/token.
- GitHub CLI had an invalid stored token during the cloud proof attempt.

Current cloud status:

- Frontend preview exists.
- Hosted staging success is not proven.
- Production deployment is not proven.
- Backend cloud stack is not proven.

## Current Open Gates

Do not close these without new proof:

- `STAGING_BASE_URL`: required for hosted staging proof.
- `BRANCH_PROTECTION_TOKEN`: required for branch protection apply/verify.
- `HETZNER_API_TOKEN`: required for live Hetzner inventory/budget proof.
- `VERCEL_TOKEN`: required for live Vercel project/deployment inventory.
- `CLOUDFLARE_API_TOKEN`: required for live Cloudflare inventory.
- `GITHUB_TOKEN`: required for live GitHub inventory/actions beyond automatic workflow context.
- `GHCR_TOKEN`: required for registry state.
- `HF_TOKEN`: optional Hugging Face identity proof.
- `GITLAB_TOKEN`: optional GitLab identity proof.
- canonical `gitleaks`: optional preferred scanner; fallback scanner exists.

## Secret And Token Locations

Do not paste secret values into Codex chat. Let Codex Desktop read the local files only if necessary and only use values as environment variables or provider secret-store values.

Project env template:

- `<repo-root>\.env.example`
- This is a template, not a real secret store.
- It lists active runtime keys including:
  - `STAGING_BASE_URL`
  - `BRANCH_PROTECTION_TOKEN`
  - `VERCEL_TOKEN`
  - `HETZNER_API_TOKEN`
  - `CLOUDFLARE_API_TOKEN`
  - `GITHUB_TOKEN`
  - `GHCR_TOKEN`
  - `HF_TOKEN`
  - `GITLAB_TOKEN`
  - `E2B_API_KEY`
  - `LANGFUSE_PUBLIC_KEY`
  - `LANGFUSE_SECRET_KEY`
  - `AGENT_API_BASE_URL`
  - `MCP_GATEWAY_BASE_URL`
  - `LLM_GATEWAY_BASE_URL`

Legacy/fresh-build actual env:

- `<workspace-root>\cloud-superbrain-fresh\.env`
- Contains real-looking local values for keys such as:
  - `OPENAI_API_KEY`
  - `ANTHROPIC_API_KEY`
  - `DATABASE_URL_PROD`
  - `DATABASE_URL_LANGFUSE`
  - `LANGFUSE_PUBLIC_KEY`
  - `LANGFUSE_SECRET_KEY`
  - `POSTGRES_USER`
  - `POSTGRES_PASSWORD`
- Treat this as sensitive. Also treat it as possibly legacy relative to the patched current architecture.

Legacy/fresh env templates:

- `<workspace-root>\cloud-superbrain-fresh\.env.example`
- `<workspace-root>\cloud-superbrain-fresh\infrastructure\hetzner\.env.prod.example`

Local Codex auth and config:

- `C:\Users\immer\.codex\auth.json`
- `C:\Users\immer\.codex\.credentials.json`
- `C:\Users\immer\.codex\cap_sid`
- `C:\Users\immer\.codex\config.toml`
- `C:\Users\immer\.codex\state_5.sqlite`
- `C:\Users\immer\.codex\logs_2.sqlite`

Important: the local Codex configuration currently contains MCP server configuration and sensitive provider credentials. Do not copy any values into docs or chat. Rotate any credential that was exposed or if Codex Desktop/GitHub reports auth problems.

Local Codex secret folder:

- Private local secret store (outside this repository)
- This likely contains provider/API tokens for this project. Do not paste values.

Sandbox secret folder:

- `C:\Users\immer\.codex\.sandbox-secrets\sandbox_users.json`

Production source-of-truth according to `docs/secrets-strategy.md`:

- GitHub Environment Secrets in environment `production`:
  - `OPENAI_API_KEY`
  - `ANTHROPIC_API_KEY`
  - `OPENROUTER_API_KEY`
  - `GROQ_API_KEY`
  - `GITHUB_APP_PRIVATE_KEY`
  - `GITHUB_WEBHOOK_SECRET`
  - `JWT_SIGNING_KEY`
  - `SESSION_ENCRYPTION_KEY`
  - `DATABASE_URL`
  - `EMBEDDING_PROVIDER_API_KEY`
  - `HETZNER_API_TOKEN`
  - `VERCEL_DEPLOY_HOOK_SECRET`
  - `MCP_INTERNAL_SHARED_SECRET`
- GitHub Environment Secrets in environment `preview`:
  - preview-specific copies of the above as needed.

GitHub workflow/repo secret names currently used:

- `.github/workflows/hosted-staging-proof.yml`: `STAGING_BASE_URL`
- `.github/workflows/branch-protection.yml`: `BRANCH_PROTECTION_TOKEN`
- `.github/workflows/infra-cost-check.yml`: `HETZNER_API_TOKEN`
- `.github/workflows/pr-check.yml`: automatic `GITHUB_TOKEN`
- `.github/workflows/main-deploy.yml`: automatic `GITHUB_TOKEN`

Runtime cloud injection contract:

- See `docs/runbooks/cloud-secret-runtime-injection.md`.
- Agent API reads provider credentials only from process environment variables.
- It must expose only configured/missing booleans, masked metadata, and non-claim text.

## Important Commands

Static/local checks:

```powershell
cd <repo-root>
powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1
py -3 scripts\verify_project_progress_manifest.py
```

Runtime checks:

```powershell
cd <repo-root>
docker compose -f docker-compose.dev.yml ps
curl.exe -s <local-control-plane-url>/api/v1/health
curl.exe -s <local-control-plane-url>/api/v1/project/progress/integrity
powershell -ExecutionPolicy Bypass -File scripts\verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost
powershell -ExecutionPolicy Bypass -File scripts\verify-hosted-staging.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost
powershell -ExecutionPolicy Bypass -File scripts\verify-phase1-runtime.ps1
powershell -ExecutionPolicy Bypass -File scripts\verify-autopilot-mode.ps1 -AllowLocalhost
```

Hosted proof once a real staging URL exists:

```powershell
cd <repo-root>
$env:STAGING_BASE_URL = "https://YOUR-REAL-STAGING-URL"
powershell -ExecutionPolicy Bypass -File scripts\verify-hosted-staging.ps1 -BaseUrl $env:STAGING_BASE_URL
powershell -ExecutionPolicy Bypass -File scripts\verify-cloud-only-staging.ps1 -BaseUrl $env:STAGING_BASE_URL
```

External gates:

```powershell
cd <repo-root>
powershell -ExecutionPolicy Bypass -File scripts\verify-external-gates.ps1
py -3 scripts\apply_github_branch_protection.py --repo strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM --verify-only
py -3 scripts\check_hetzner_infra_budget.py
```

## Worktree State

The primary project worktree is dirty and intentionally not a clean clone.

Modified tracked files include many docs and governance files, such as:

- `.gitignore`
- `docs/PHASE_0_AUDIT.md`
- `docs/PHASE_2_IMPLEMENTATION_PLAN.md`
- `docs/codex-integration/CODEX_AGENT_SKILL_MASTER.md`
- `docs/phase-2-readiness-matrix.md`
- `docs/verification-register.md`
- `docs/system-architecture.md`
- `infrastructure/docker-compose.design.md`
- `memory/schema.md`
- `observability/strategy.md`

Untracked required project files include the real current application/runtime surface, such as:

- `.env.example`
- `.github/workflows/*.yml`
- `.gitleaks.toml`
- `AGENTS.md`
- `AI_HANDOFF.md`
- `PROJECT_ANCHOR.md`
- `PROJECT_STATE.md`
- `apps/frontend/**`
- `docker-compose.dev.yml`
- `docs/project-checkpoint-2026-04-30.json`
- `docs/project-progress.manifest.json`
- `docs/runbooks/**`
- `docs/runtime-contracts/**`
- `infrastructure/nginx/dev.conf`
- `infrastructure/postgres/init/01-init-databases.sh`
- `scripts/**`
- `services/**`

This is why Codex Desktop must use the whole folder, not only `git clone`.

Parent workspace `<workspace-root>` is also dirty:

- modified root Docker/MCP files,
- deleted `full_config.json`,
- many Playwright MCP page snapshots,
- cloud preview screenshots and proof files.

## What Is Done

Done with local deterministic proof:

- Docker Compose local Phase 1 stack.
- PostgreSQL/pgvector foundation schema.
- Redis persistence and worker queues.
- Agent API health/progress/contracts.
- Next.js frontend dashboard.
- LangGraph deterministic orchestration with PostgreSQL checkpointing.
- Four-role agent executor: planner, coder, tester, devops.
- Task assignment queue contract.
- LLM Gateway deterministic OpenAI-compatible dry-run and streaming contract.
- MCP Gateway safe contracts and version pinning.
- Memory write/search/consolidation flow.
- Project progress integrity contract.
- Session history openability regression proof.
- Browser/Playwright proof of clean dashboard state.
- Local hosted-staging mirror checks with `-AllowLocalhost`.

## What Is Not Done

Not proven and must not be claimed:

- Real hosted backend staging success.
- Production deployment.
- Live external LLM provider calls.
- Live MCP write tools.
- Branch protection apply/verify.
- Real Cloudflare edge proof.
- Real Vercel backend rewrite proof.
- Real Hetzner Cloud Superbrain backend serving Agent API/MCP/LLM Gateway.
- 100% project completion.

## Next Best Work Item

Primary next step:

1. Configure real cloud backend URLs:
   - `AGENT_API_BASE_URL`
   - `MCP_GATEWAY_BASE_URL`
   - `LLM_GATEWAY_BASE_URL`
2. Ensure the Hetzner backend actually serves the Cloud Superbrain Agent API stack, not the unrelated `OpenHands` frontend.
3. Set `STAGING_BASE_URL` to the real hosted staging URL.
4. Run hosted verifiers without `-AllowLocalhost`.
5. Configure `BRANCH_PROTECTION_TOKEN` and verify branch protection.
6. Run external gate verifier.
7. Only after evidence passes, update:
   - `docs/verification-register.md`
   - `docs/project-progress.manifest.json`
   - `PROJECT_STATE.md`
   - `AI_HANDOFF.md`

Acceptance criteria for hosted staging:

- Hosted `/api/v1/health` is healthy.
- Hosted `/api/v1/project/progress/integrity` is verified.
- Hosted session history opens with `session-history-v1`.
- Browser console remains clean after opening Recent Runs/history.
- Cloud provider inventory endpoints show sanitized configured/missing state.
- No secret values appear in outputs or artifacts.

## 2026-04-30 Cloud Substrate Addendum

Additional work completed in this Codex session:

- Added `docker-compose.cloud.yml` as the pull-based Hetzner/GHCR stack for `frontend`, `agent-api`, `agent-worker`, `memory-worker`, `mcp-gateway`, `llm-gateway`, `postgres`, `redis`, and `nginx`.
- Added `infrastructure/nginx/cloud.conf` for cloud routing of `/`, `/api/`, `/mcp/`, `/llm/`, and `/health`.
- Updated `.github/workflows/main-deploy.yml` so all six application images are built and pushed to the stable lowercase namespace `ghcr.io/${{ github.repository_owner }}/cloud-superbrain-developer-platform/<service>`.
- Updated `.env.example`, `scripts/verify-phase1.ps1`, `docs/runbooks/cloud-only-staging-proof-2026-04-30.md`, and `docs/verification-register.md` with the cloud deploy substrate and fail-closed guards.
- Verified `docker compose -f docker-compose.cloud.yml config` locally. This is syntax/static substrate proof only; no GHCR push, Hetzner deploy, hosted staging success, live provider call, or production deploy was performed.

Next cloud handoff step:

1. Repair GitHub auth or dispatch the workflow in GitHub so the six GHCR images exist.
2. On Hetzner, provide secrets only via environment/secret store, then run the cloud compose pull/up from a repo checkout or release bundle that includes `docs/project-progress.manifest.json`.
3. Configure Vercel `AGENT_API_BASE_URL`, `MCP_GATEWAY_BASE_URL`, and `LLM_GATEWAY_BASE_URL` to the cloud backend origin.
4. Run `scripts/verify-cloud-only-staging.ps1` without `-AllowLocalhost`.

## Safety Notes

- Rotate any token that was pasted into chat, screenshots, docs, shell history, or config output.
- The local Codex config may contain plaintext credentials; treat it as sensitive.
- The private local secret store is sensitive; read only locally, never quote.
- Do not commit `.env` files.
- Do not commit Codex auth files.
- Do not include `.phase1-artifacts` only selectively if the next agent needs evidence; the artifacts are useful for reconstruction.

## Rollback Note

This handoff file itself does not change runtime behavior.

If this handoff file is unwanted, remove:

- `CODEX_DESKTOP_HANDOFF_2026-04-30.md`

No database migration, service code, Docker config, or cloud setting was changed by creating this handoff.
