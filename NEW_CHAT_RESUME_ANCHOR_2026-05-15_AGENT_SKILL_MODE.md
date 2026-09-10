# New Chat Resume Anchor - 2026-05-15 - Agent Skill Mode / Workbench Checkpoint

## Start Here

Work in:

`D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`

Branch:

`codex/live-agent-steering-ui-20260513`

First read, in this order:

1. `AGENTS.md`
2. `PROJECT_STATE.md`
3. `AI_HANDOFF.md`
4. `docs/project-progress.manifest.json`
5. `docs/verification-register.md`
6. `docs/runtime-contracts/agent-skill-mode-capability-contract.md`
7. `docs/codex-integration/agent-skill-mode-capability-registry.json`
8. `docs/release-artifacts/current-release-candidate.json`
9. This anchor file

## Absolute Chat Output Rule

The operator requires chat output to stay under five lines and use only:

- `[PLAN]`
- `[PROGRESS: N%]`
- `[DONE]`
- `[ERROR]`

No prose in chat. Put detailed reports in files, not in chat.

## Current Truth

- Overall progress: `82%`
- Horizontal phases: `P0 100%`, `P1 100%`, `P2 89%`, `P3 95%`, `P4 100%`, `P5 89%`, `P6 0%`
- Vertical layers: `Frontend 100%`, `Orchestrator 100%`, `Agent Pool 76%`, `LLM Gateway 67%`, `MCP Gateway 68%`, `Memory 74%`, `Observability 99%`
- Progress source: `docs/project-progress.manifest.json`
- Last pushed commit before this anchor work: `ee52cda feat(frontend): add workbench squad mode`
- Current local slice: Agent Skill Mode capability contract plus Workbench hash/input UX repair
- Production rollout: not claimed
- Hosted staging update: not claimed for this local slice
- Live provider call: not claimed
- Live MCP write: not claimed
- External MCP server mutation: not claimed
- Local model download: not claimed
- Secret exposure: not claimed

## Completed Local Slice

Added a guarded Codex Agent Skill Mode capability surface:

- API: `GET /api/v1/agents/skill-mode/contract`
- Contract: `agent-skill-mode-capability-contract-v1`
- Evidence: `agent_skill_mode_capability_visible`
- Guard markers:
  - `agent_skill_mode_no_live_external_calls`
  - `agent_skill_mode_no_secret_material`
  - `agent_skill_mode_no_local_model_downloads`
- Declared Codex surface:
  - `plugins=11`
  - `apps=4`
  - `mcp_servers=1`
  - `skills=140`
- Workbench first viewport now shows:
  - `Agent Skill Mode`
  - `Plugins 11`
  - `Apps 4`
  - `MCPs 1`
  - `Skills 140`
  - the three guard markers above
- Workbench navigation now clears stale hash anchors when returning from deep technical surfaces to module, layer, launch-pack, command-result, or review navigation.
- Prompt/project/command fields select their text on focus for faster overwrite UX.

Files changed in this slice:

- `services/agent-api/app/main.py`
- `apps/frontend/app/page.tsx`
- `apps/frontend/app/styles.css`
- `scripts/verify-browser-contract.ps1`
- `scripts/verify-agent-skill-mode-contract.ps1`
- `docs/runtime-contracts/agent-skill-mode-capability-contract.md`
- `docs/codex-integration/agent-skill-mode-capability-registry.json`
- `docs/verification-register.md`
- `NEW_CHAT_RESUME_ANCHOR_2026-05-15_AGENT_SKILL_MODE.md`

## Verification Already Run

- `py -3 -m py_compile services\agent-api\app\main.py`
- `npm run build`
- `npm run lint --prefix apps/frontend`
- `npm audit --prefix apps/frontend --audit-level=moderate` -> `0 vulnerabilities`
- `docker info --format '{{.ServerVersion}}'` -> `29.4.1`
- `docker compose -f docker-compose.dev.yml build agent-api frontend`
- `docker compose -f docker-compose.dev.yml up -d --no-deps --force-recreate agent-api frontend nginx`
- `scripts\verify-agent-skill-mode-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- `scripts\verify-phase1.ps1`
- `py -3 scripts\verify_project_progress_manifest.py` -> `overall=82%`
- `git diff --check`
- In-app browser DOM proof:
  - `Agent Skill Mode` visible
  - `agent-skill-mode-capability-contract-v1` visible
  - `agent_skill_mode_capability_visible` visible
  - `Plugins 11`, `Apps 4`, `MCPs 1`, `Skills 140` visible
  - `agent_skill_mode_no_live_external_calls`, `agent_skill_mode_no_secret_material`, `agent_skill_mode_no_local_model_downloads` visible
  - `api_only`, `model_downloads=false`, `live_mcp_writes=false`, `production_rollout_claimed=false` visible
  - console errors: none
- `scripts\verify-phase1.ps1` included gitleaks and reported no leaks.

## User-Provided DevSecOps Protocol Note

The operator pasted an external protocol report attributed to `Antigravity AI (Autonomous Agent)` covering:

- Windows host security hardening
- Scheduled task scanner repairs
- WiFi deny-all / whitelist-only policy
- Frontend navigation deadlock repair
- Docker service health observations
- Memory worker health-check concern

Codex must treat that report as an operator-provided note unless independently verified in repo-safe commands. Do not claim Codex performed or verified Windows kernel/network hardening in this repo slice. Do not claim `SYSTEM SECURE` from the pasted report without a repo-bound verifier artifact. The repo-bound verified part is the frontend hash/input UX repair and the local verifier suite listed above.

## AGENTS.md Operational Details To Preserve

Identity:

- Permanent Codex supervisor for `CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`.
- Use GPT-5.5 when available; GPT-5.4 fallback only when GPT-5.5 is unavailable.

Truth hierarchy:

1. `PROJECT_STATE.md`
2. `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md`
3. `docs/CLOUD_SUPERBRAIN_ULTIMATUM_GPT55_PATCHED_2026-04-29.md`
4. `docs/system-architecture.md`
5. `docs/project-progress.manifest.json`

Start protocol:

1. Read `PROJECT_STATE.md`.
2. Read `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md`.
3. Read `docs/CLOUD_SUPERBRAIN_ULTIMATUM_GPT55_PATCHED_2026-04-29.md` if present.
4. Read `docs/codex-integration/AUTONOMOUS_AGENT_ROSTER.md`.
5. Read `docs/codex-integration/autonomous-agent-roster.json`.
6. Extract progress, phase/layer state, last verified step, next step, and closed gates.
7. Continue with the next safe step.
8. Never claim completion without evidence.

Hard constraints:

- Infra budget max `20 EUR/month` unless Owner approves measured upgrade.
- No Qdrant in Phase 1-5.
- No Supabase, LanceDB, Ollama, Railway, HuggingFace Spaces as active MVP runtime defaults.
- No CPX51/CPX31/GPU server before documented phase gate and ADR.
- No direct provider calls outside the LLM Gateway.
- No live provider calls, live MCP writes, Docker registry push, production deploy, or main-branch write without explicit review gate.
- No secrets in code, logs, examples, commits, generated files, or chat.
- No fake done: implementation, tests, integration, audit evidence, rollback note, and verifier update must exist.

Localhost rule:

- Localhost is DEV-ONLY smoke proof.
- Localhost cannot close hosted staging proof, production readiness, cloud browser proof, external integration proof, budget proof, or release readiness.
- Any localhost evidence must be labeled `DEV-ONLY; hosted proof still blocked`.

Stop gates:

- Production deployment or release promotion.
- Docker image push or registry publication.
- Direct write, merge, or push to `main`.
- Secret creation, token use, auth scope expansion, permission expansion.
- Production DB write, destructive migration, destructive filesystem operation.
- Live LLM provider activation or direct provider bypass.
- MCP tool activation with write access.
- Architecture deviation from seven-layer model or budget baseline.
- Reintroduction of superseded runtime stacks before gate and ADR.

Verification baseline:

- `scripts\verify-phase1.ps1`
- `scripts\verify-phase1-runtime.ps1` for runtime-impacting changes
- `scripts\verify-browser-contract.ps1 -BaseUrl <HOSTED_STAGING_URL>` for cloud proof
- `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` for DEV-ONLY smoke proof
- `py -3 scripts\verify_project_progress_manifest.py`
- gitleaks or configured CI secret scan before release claims

## Active Custom Agent Roles

Use these fixed roles when the user explicitly asks for agent/delegation/parallel agent work. After every spawn, wait for and close every agent before final output.

- `planner`: architecture, task decomposition, roadmap
- `coder`: implementation, debugging, full stack
- `tester`: tests, QA, security checks
- `researcher`: documentation, APIs, best practices
- `supervisor`: code review, monitoring, self-healing
- `backend_platform`: APIs, server logic, runtime architecture
- `cloud_infra_devops`: deployment, CI/CD, Docker, cloud runtime
- `game_design`: mechanics and player experience
- `gameplay_systems`: game logic and state machines
- `multiplayer_netcode`: networking, sync, latency
- `webgl_client`: WebGL, shaders, browser graphics
- `qa_validation`: testing and bug hunting
- `security_anticheat`: vulnerability analysis and anti-abuse
- `sentinel_runtime`: monitoring health, performance, failure modes
- `sentinel_truth`: claim verification, facts, logic
- `product_scope`: feature planning, milestones, documentation

## Codex Tool / CLI Inventory

Observed local CLI/runtime state:

- PowerShell: user reported `7.6.1`
- Git: `2.54.0.windows.1`
- Node: `v24.15.0`
- npm: `11.13.0`
- Python launcher: `py -3` -> `Python 3.14.3`
- Docker server: `29.4.1`
- Next.js build output: `Next.js 16.2.6`
- Secret scan through Phase 1 verifier: gitleaks, no leaks found

Active plugins declared in this Codex session:

- Browser Use
- Cloudflare
- Codex Security
- Documents
- Expo
- GitHub
- Hugging Face
- OpenAI Developers
- Presentations
- Spreadsheets
- Vercel

Active app/connectors to account for in planning:

- Browser Use / in-app browser
- GitHub
- OpenAI Platform
- Vercel

MCP/tooling notes:

- Operator UI declared `MCPs 1`.
- `node_repl` was used for in-app browser DOM proof.
- `atomic_time` is available for time checks.
- Do not use OpenAI key setup or any secret flow unless the user explicitly requests it and the required secure tool path is followed.

## Active Skill Inventory

The current Codex context declared `Skills 140`. Treat the list as capability inventory, not as authorization to execute live external writes.

Core/system:

- `imagegen`
- `openai-docs`
- `plugin-creator`
- `skill-creator`
- `skill-installer`
- `codex-superbrain-agent-squad`

Superbrain/local:

- `3d-web-game-swarm`
- `superbrain-backend-agent`
- `superbrain-codex-desktop-runner`
- `superbrain-database-agent`
- `superbrain-frontend-agent`
- `superbrain-memory-consolidator`
- `superbrain-observability-agent`
- `superbrain-project-manager`
- `superbrain-security-auditor`

Azure / Microsoft / Entra / Foundry:

- `airunway-aks-setup`
- `appinsights-instrumentation`
- `azure-ai`
- `azure-aigateway`
- `azure-cloud-migrate`
- `azure-compliance`
- `azure-compute`
- `azure-cost`
- `azure-deploy`
- `azure-diagnostics`
- `azure-enterprise-infra-planner`
- `azure-hosted-copilot-sdk`
- `azure-kubernetes`
- `azure-kubernetes-automatic-readiness`
- `azure-kusto`
- `azure-messaging`
- `azure-prepare`
- `azure-quotas`
- `azure-rbac`
- `azure-reliability`
- `azure-resource-lookup`
- `azure-resource-visualizer`
- `azure-storage`
- `azure-upgrade`
- `azure-validate`
- `capacity`
- `customize`
- `deploy-model`
- `microsoft-foundry`
- `preset`
- `entra-agent-id`
- `entra-app-registration`

Browser / Cloudflare / security:

- `browser-use:browser`
- `cloudflare:agents-sdk`
- `cloudflare:building-ai-agent-on-cloudflare`
- `cloudflare:building-mcp-server-on-cloudflare`
- `cloudflare:cloudflare`
- `cloudflare:durable-objects`
- `cloudflare:sandbox-sdk`
- `cloudflare:web-perf`
- `cloudflare:workers-best-practices`
- `cloudflare:wrangler`
- `codex-security:attack-path-analysis`
- `codex-security:finding-discovery`
- `codex-security:fix-finding`
- `codex-security:security-scan`
- `codex-security:threat-model`
- `codex-security:validation`

Documents / presentations / spreadsheets:

- `documents:documents`
- `presentations:Presentations`
- `spreadsheets:Spreadsheets`

Expo:

- `expo:building-native-ui`
- `expo:codex-expo-run-actions`
- `expo:expo-api-routes`
- `expo:expo-cicd-workflows`
- `expo:expo-deployment`
- `expo:expo-dev-client`
- `expo:expo-module`
- `expo:expo-tailwind-setup`
- `expo:expo-ui-jetpack-compose`
- `expo:expo-ui-swift-ui`
- `expo:native-data-fetching`
- `expo:upgrading-expo`
- `expo:use-dom`

GitHub:

- `github:gh-address-comments`
- `github:gh-fix-ci`
- `github:github`
- `github:yeet`

Hugging Face:

- `hf-cli`
- `hugging-face:hf-cli`
- `hugging-face:huggingface-community-evals`
- `hugging-face:huggingface-datasets`
- `hugging-face:huggingface-gradio`
- `hugging-face:huggingface-jobs`
- `hugging-face:huggingface-llm-trainer`
- `hugging-face:huggingface-paper-publisher`
- `hugging-face:huggingface-papers`
- `hugging-face:huggingface-trackio`
- `hugging-face:huggingface-vision-trainer`
- `hugging-face:transformers-js`

OpenAI Developers:

- `openai-developers:agents-sdk`
- `openai-developers:build-chatgpt-app`
- `openai-developers:chatgpt-app-submission`
- `openai-developers:openai-api-troubleshooting`
- `openai-developers:openai-platform-api-key`

Vercel:

- `vercel:agent-browser`
- `vercel:agent-browser-verify`
- `vercel:ai-elements`
- `vercel:ai-gateway`
- `vercel:ai-generation-persistence`
- `vercel:ai-sdk`
- `vercel:auth`
- `vercel:bootstrap`
- `vercel:chat-sdk`
- `vercel:cms`
- `vercel:cron-jobs`
- `vercel:deployments-cicd`
- `vercel:email`
- `vercel:env-vars`
- `vercel:geist`
- `vercel:geistdocs`
- `vercel:investigation-mode`
- `vercel:json-render`
- `vercel:marketplace`
- `vercel:micro`
- `vercel:ncc`
- `vercel:next-forge`
- `vercel:nextjs`
- `vercel:observability`
- `vercel:payments`
- `vercel:react-best-practices`
- `vercel:routing-middleware`
- `vercel:runtime-cache`
- `vercel:satori`
- `vercel:shadcn`
- `vercel:sign-in-with-vercel`
- `vercel:swr`
- `vercel:turbopack`
- `vercel:turborepo`
- `vercel:v0-dev`
- `vercel:vercel-agent`
- `vercel:vercel-api`
- `vercel:vercel-cli`
- `vercel:vercel-firewall`
- `vercel:vercel-flags`
- `vercel:vercel-functions`
- `vercel:vercel-queues`
- `vercel:vercel-sandbox`
- `vercel:vercel-services`
- `vercel:vercel-storage`
- `vercel:verification`
- `vercel:workflow`

## TOML Inventory

Do not copy TOML contents into chat or reports unless redacted. Some config files may reference auth/runtime setup. This is a path inventory only.

Current / active-looking TOML files:

- `D:\PLATTFORM\config-optimized.toml`
- `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM\.gitleaks.toml`
- `C:\Users\immer\.codex\config.toml`
- `C:\Users\immer\.codex\browser\config.toml`
- `C:\Users\immer\.codex\hcloud\cli.toml`
- `C:\Users\immer\.codex\agents\backend_platform.toml`
- `C:\Users\immer\.codex\agents\cloud_infra_devops.toml`
- `C:\Users\immer\.codex\agents\coder.toml`
- `C:\Users\immer\.codex\agents\codex_config_ergaenzungen.toml`
- `C:\Users\immer\.codex\agents\game_design.toml`
- `C:\Users\immer\.codex\agents\gameplay_systems.toml`
- `C:\Users\immer\.codex\agents\multiplayer_netcode.toml`
- `C:\Users\immer\.codex\agents\planner.toml`
- `C:\Users\immer\.codex\agents\product_scope.toml`
- `C:\Users\immer\.codex\agents\qa_validation.toml`
- `C:\Users\immer\.codex\agents\researcher.toml`
- `C:\Users\immer\.codex\agents\security_anticheat.toml`
- `C:\Users\immer\.codex\agents\sentinel_runtime.toml`
- `C:\Users\immer\.codex\agents\sentinel_truth.toml`
- `C:\Users\immer\.codex\agents\supervisor.toml`
- `C:\Users\immer\.codex\agents\tester.toml`
- `C:\Users\immer\.codex\agents\webgl_client.toml`

Backup / historical TOML files:

- `C:\Users\immer\.codex\backup_before_full_fix_20260501_040718\backend_platform.toml`
- `C:\Users\immer\.codex\backup_before_full_fix_20260501_040718\cloud_infra_devops.toml`
- `C:\Users\immer\.codex\backup_before_full_fix_20260501_040718\config.toml`
- `C:\Users\immer\.codex\backup_before_full_fix_20260501_040718\game_design.toml`
- `C:\Users\immer\.codex\backup_before_full_fix_20260501_040718\gameplay_systems.toml`
- `C:\Users\immer\.codex\backup_before_full_fix_20260501_040718\multiplayer_netcode.toml`
- `C:\Users\immer\.codex\backup_before_full_fix_20260501_040718\product_scope.toml`
- `C:\Users\immer\.codex\backup_before_full_fix_20260501_040718\qa_validation.toml`
- `C:\Users\immer\.codex\backup_before_full_fix_20260501_040718\security_anticheat.toml`
- `C:\Users\immer\.codex\backup_before_full_fix_20260501_040718\sentinel_runtime.toml`
- `C:\Users\immer\.codex\backup_before_full_fix_20260501_040718\sentinel_truth.toml`
- `C:\Users\immer\.codex\backup_before_full_fix_20260501_040718\webgl_client.toml`
- `C:\Users\immer\.codex\repair-backup-20260501-033652\agents\backend_platform.toml`
- `C:\Users\immer\.codex\repair-backup-20260501-033652\agents\cloud_infra_devops.toml`
- `C:\Users\immer\.codex\repair-backup-20260501-033652\agents\game_design.toml`
- `C:\Users\immer\.codex\repair-backup-20260501-033652\agents\gameplay_systems.toml`
- `C:\Users\immer\.codex\repair-backup-20260501-033652\agents\multiplayer_netcode.toml`
- `C:\Users\immer\.codex\repair-backup-20260501-033652\agents\product_scope.toml`
- `C:\Users\immer\.codex\repair-backup-20260501-033652\agents\qa_validation.toml`
- `C:\Users\immer\.codex\repair-backup-20260501-033652\agents\security_anticheat.toml`
- `C:\Users\immer\.codex\repair-backup-20260501-033652\agents\sentinel_runtime.toml`
- `C:\Users\immer\.codex\repair-backup-20260501-033652\agents\sentinel_truth.toml`
- `C:\Users\immer\.codex\repair-backup-20260501-033652\agents\webgl_client.toml`

Plugin example TOML:

- `C:\Users\immer\.codex\plugins\cache\openai-curated\vercel\b8edb371\skills\vercel-services\references\fastapi-vite\backend\pyproject.toml`

## Exact Start Prompt For Next Chat

Use this as the first message in a fresh chat:

```text
New Chat Resume Anchor - 2026-05-15 - Agent Skill Mode / Workbench Checkpoint

Work in D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM on branch codex/live-agent-steering-ui-20260513.

Read first: AGENTS.md, PROJECT_STATE.md, AI_HANDOFF.md, docs/project-progress.manifest.json, docs/verification-register.md, docs/runtime-contracts/agent-skill-mode-capability-contract.md, docs/codex-integration/agent-skill-mode-capability-registry.json, docs/release-artifacts/current-release-candidate.json, and NEW_CHAT_RESUME_ANCHOR_2026-05-15_AGENT_SKILL_MODE.md.

Chat output must stay max 5 lines and only use [PLAN], [PROGRESS: N%], [DONE], or [ERROR]. Put detailed reports in files, not chat.

Continue autonomously from the anchor. Preserve the seven-layer architecture, API-only model policy, no local model downloads, no direct provider calls, no live MCP writes, no production rollout claims, no secrets, no unverified security claims, and no percentage increases without code + runtime proof + verifier + docs. Use Docker readiness only with docker info --format '{{.ServerVersion}}'. Use browser-use/node_repl for local browser DOM proof. If subagents are explicitly requested, spawn only bounded roles, then wait for and close all agents before final.

Current verified progress remains: Overall 82%; P0 100, P1 100, P2 89, P3 95, P4 100, P5 89, P6 0; Frontend 100, Orchestrator 100, Agent Pool 76, LLM Gateway 67, MCP Gateway 68, Memory 74, Observability 99.

Latest local slice: Agent Skill Mode contract GET /api/v1/agents/skill-mode/contract with agent-skill-mode-capability-contract-v1, agent_skill_mode_capability_visible, Plugins 11, Apps 4, MCPs 1, Skills 140, agent_skill_mode_no_live_external_calls, agent_skill_mode_no_secret_material, agent_skill_mode_no_local_model_downloads; plus Workbench hash navigation repair and select-on-focus UX. Do not claim hosted parity or production rollout from this local slice.

Next safe work: finish commit/push state if not already clean, then continue large slices toward Agent Pool/LLM/MCP/Memory release-readiness gaps or hosted RC proof only if explicit deployment/release gates are satisfied.
```

## Next Safe Work

1. Commit and push the current Agent Skill Mode / Workbench UX checkpoint if not already done.
2. Start a larger runtime slice targeting one of the non-100 vertical layers: Agent Pool, LLM Gateway, MCP Gateway, or Memory.
3. Keep Phase 6 at `0%` until real Scale/3D runtime evidence exists.
4. Do not raise any percentage from this local anchor/report slice.
