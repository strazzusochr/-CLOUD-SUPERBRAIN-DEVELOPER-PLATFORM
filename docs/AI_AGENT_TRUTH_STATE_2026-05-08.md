# AI Agent Truth State

Stand: 2026-05-08

Status: active handoff document for external AI review

Purpose: give another AI agent one audit-ready file that distinguishes clearly between:

- target architecture
- implemented code and wiring
- locally verified runtime truth
- hosted/cloud verified truth
- blocked or non-claim areas

This document is intentionally strict. If a claim is not backed by code, runtime proof, or an existing verifier/artifact, it is not presented here as truth.

## 1. Scope

This handoff covers three related but different surfaces:

1. Main product repo:
   - `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`
2. Local desktop supervision runtime:
   - `D:\PLATTFORM\agent_runtime`
3. Local desktop monitor app:
   - `D:\PLATTFORM\_tmp_codex_live_agent_app\codex-live-agent-app`

The main repo is the cloud/runtime truth source.
The desktop runtime and desktop monitor are supervisory tools and local observability aids. They are not by themselves cloud deployment proof.

## 2. Authority Order

Use these files in this order when judging truth:

1. `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md`
2. `docs/system-architecture.md`
3. `docs/project-progress.manifest.json`
4. `docs/verification-register.md`
5. `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md`
6. `PROJECT_STATE.md`
7. `AI_HANDOFF.md`

If a lower document contradicts a higher one, the higher one wins.

## 3. Current Top-Level Truth

### 3.1 Current repo/worktree state

- Current branch: `chore/repo-bootstrap`
- Current repo HEAD: `2a1e4c71700ebad30759cc2211f8f5fa159bf781`
- Last verified production-candidate commit:
  - `ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`
- Worktree state:
  - dirty
  - many modified files
  - many untracked files

This means:

- the repository in its current working state is not claimable as equal to the last verified release candidate
- repo/worktree parity is explicitly blocked and already recorded in the verification register

### 3.2 Current progress authority

From `docs/project-progress.manifest.json` and mirrored in `docs/verification-register.md`:

- total: `70%`
- phase 1: `100%`
- phase 2: `86%`
- phase 3: `40%`
- phase 4: `100%`
- phase 5: `67%`
- phase 6: `0%`

Vertical layer/module progress:

- Frontend: `97%`
- Orchestrator: `99%`
- Agent Pool: `68%`
- LLM Gateway: `54%`
- MCP Gateway: `55%`
- Memory: `72%`
- Observability: `99%`

### 3.3 Current hard non-claims

These remain true and must not be softened:

- no production deployment is verified
- no full repo/worktree parity to the last verified candidate is claimed
- hosted staging currently follows mutable `IMAGE_TAG=staging`
- digest parity from mutable `:staging` to immutable candidate SHA is explicitly blocked
- no live provider activation claim is made beyond the documented hosted proofs and read-only checks

## 4. Seven-Layer Architecture

Binding seven-layer model from `docs/system-architecture.md`:

1. Frontend
2. Orchestration
3. Agent Pool
4. LLM Gateway
5. Tool MCP Layer
6. Memory
7. Observability

Exact responsibilities:

### Layer 1: Frontend / Next.js

- user prompt UI
- session state
- REST/SSE interaction with agent-api
- status and budget visualization

Forbidden:

- direct DB calls
- direct model/provider calls
- secrets

### Layer 2: Orchestrator / LangGraph / FastAPI

- intent parsing
- routing
- graph state
- budget guard
- recovery
- SSE contract emission

Forbidden:

- provider bypass
- uncontrolled schema drift

### Layer 3: Agent Pool

- planner/coder/tester/devops-style execution
- result envelopes
- bounded retries and review gates

Forbidden:

- uncontrolled loops
- direct production deploy claims
- direct main-branch mutation as an unproven assumption

### Layer 4: LLM Gateway

- LiteLLM-compatible model routing
- rate limiting
- fallback policy
- cost and provider events

Forbidden:

- direct provider calls from agents
- sensitive prompt caching

### Layer 5: MCP Gateway / Tools

- GitHub
- filesystem
- browser/playwright
- postgres readonly
- safe tool execution envelopes

Forbidden:

- unlogged tool calls
- untimed tool calls

### Layer 6: Memory / PostgreSQL pgvector / Redis

- working memory
- memory search
- consolidation
- retention and purge

Forbidden:

- Qdrant in phases 1 to 5
- production MemorySaver assumptions

### Layer 7: Observability

- traces
- metrics
- audit
- evidence
- cost tracking

Forbidden:

- mixing observability UI concerns into main application truth
- secrets in telemetry

## 5. Cloud Structure

This is the key distinction the next AI agent must keep straight.

### 5.1 Intended cloud boundary

From `docs/system-architecture.md` and `docs/runtime-contracts/cloud-provider-inventory-contract.md`:

- Vercel:
  - frontend hosting only
  - no DB responsibility
  - no agent runtime responsibility
- Hetzner:
  - primary runtime host
  - agent-api
  - agent-worker
  - memory-worker
  - mcp-gateway
  - llm-gateway
  - postgres
  - redis
  - nginx/caddy ingress
- Cloudflare:
  - DNS/CDN
  - optional AI Gateway caching/edge metadata
  - not the primary state store

Additional cloud-adjacent providers in the visible inventory model:

- GitHub Actions
- GHCR
- Hugging Face identity
- GitLab identity
- GitKraken identity

### 5.2 Actual hosted deployment shape in code

From `docker-compose.cloud.yml`, `infrastructure/nginx/cloud.conf`, `infrastructure/caddy/Caddyfile`, and `scripts/deploy-to-staging.ps1`:

Hosted path:

`Internet -> Caddy (80/443) -> nginx -> frontend / agent-api / mcp-gateway / llm-gateway`

Concrete hosted components:

- `frontend`
  - image from GHCR
  - internal port `3000`
- `agent-api`
  - image from GHCR
  - internal port `8000`
- `agent-worker`
  - image from GHCR
- `memory-worker`
  - image from GHCR
- `mcp-gateway`
  - image from GHCR
  - internal port `9000`
- `llm-gateway`
  - image from GHCR
  - internal port `4000`
- `postgres`
  - `pgvector/pgvector:0.8.2-pg16`
- `redis`
  - `redis:7.4.2-alpine`
- `nginx`
  - internal reverse proxy
- `caddy`
  - external TLS termination on `80/443`

Hosted routing in nginx:

- `/` -> frontend
- `/api/` -> agent-api
- `/internal/` -> agent-api
- `/mcp/` -> mcp-gateway
- `/llm/` -> llm-gateway
- `/health` -> nginx health endpoint

Hosted TLS ingress in caddy:

- `{$STAGING_HOSTNAME}` -> reverse proxy to `nginx:80`

### 5.3 Hosted staging URL currently used in release artifacts

- `https://188-34-191-140.sslip.io`

This URL appears throughout the candidate and verification evidence and is the current documented hosted staging truth.

## 6. Localhost vs Cloud Truth

This distinction is mandatory.

### 6.1 What localhost means here

Localhost is used for:

- dev control plane
- deterministic local verification
- browser contract checks against local stack
- desktop supervision tools

Important local surfaces:

- `http://localhost:8081/`
  - repo dev stack ingress
- `http://127.0.0.1:8000`
  - local desktop-agent orchestrator
- `http://127.0.0.1:43110`
  - desktop monitor relay

### 6.2 What localhost does not mean

Localhost is not:

- hosted staging proof
- production deployment proof
- proof that Vercel is currently fronting hosted backend origins
- proof that mutable staging equals immutable candidate SHA

### 6.3 Hosted boundary

Hosted staging proof begins only when:

- the HTTPS staging URL is used
- the hosted verifier runs against that URL
- hosted health/progress/integrity/external-gates surfaces agree

## 7. What Is Implemented in the Main Repo

### 7.1 Frontend

Implemented:

- Next.js application surface
- dashboard/UI surfaces for:
  - project progress
  - integrity
  - external gates
  - agent activity/status
  - memory
  - cloud inventory
  - layer interfaces
  - phase-2 runtime controls

Primary files:

- `apps/frontend/app/page.tsx`
- `apps/frontend/app/styles.css`
- `apps/frontend/Dockerfile`

### 7.2 Agent API / Orchestrator

Implemented:

- FastAPI control plane
- health, progress, integrity, completion
- task/session surfaces
- audit and activity feeds
- cloud inventory and layer readiness surfaces
- deployment preflight contract
- phase-2 orchestration and dry-run surfaces
- external gates and mirrors

Primary files:

- `services/agent-api/app/main.py`
- `services/agent-api/app/tasks.py`

### 7.3 LLM Gateway

Implemented:

- OpenAI-compatible gateway service
- deterministic dry-run mode
- routing and policy surfaces

Primary file:

- `services/llm-gateway/app/main.py`

### 7.4 MCP Gateway

Implemented:

- MCP service surface
- safe envelope and health path

Primary repo area:

- `services/mcp-gateway/app`

### 7.5 Memory

Implemented:

- Redis-backed working memory
- PostgreSQL/pgvector long-term memory
- consolidation worker
- search and purge surfaces

Primary repo areas:

- `services/memory-worker/app`
- `docs/memory/schema.md`

### 7.6 Workers

Implemented:

- task worker runtime
- queue/status/state handling
- bounded stale queue/failure paths

Primary file:

- `services/agent-worker/app/worker.py`

### 7.7 Cloud/Deploy scripts

Implemented:

- local dev stack via `docker-compose.dev.yml`
- hosted stack via `docker-compose.cloud.yml`
- staging deploy via `scripts/deploy-to-staging.ps1`
- nginx and caddy ingress configs

## 8. What Is Implemented Outside the Main Repo

These tools are real and currently used, but they are not the same thing as the product runtime.

### 8.1 Local desktop agent runtime

Path:

- `D:\PLATTFORM\agent_runtime`

Implemented:

- local orchestrator on `:8000`
- local agent roles on `:8001` to `:8005`
- state/event persistence through Redis when available, fallback in-memory otherwise
- explicit `/status`, `/task`, `/message`, `/complete`, `/fail` paths per agent

Key files:

- `D:\PLATTFORM\agent_runtime\orchestrator.py`
- `D:\PLATTFORM\agent_runtime\base.py`
- `D:\PLATTFORM\agent_runtime\catalog.py`

Purpose:

- local supervision and demonstration of agent status/state transitions
- not a substitute for hosted product runtime proof

### 8.2 Desktop monitor app

Path:

- `D:\PLATTFORM\_tmp_codex_live_agent_app\codex-live-agent-app`

Implemented:

- local relay on `http://127.0.0.1:43110`
- auto-detection between phase-stack and local-orchestrator runtime modes
- browser/Electron dashboard
- operator note delivery to agents
- zoom/scroll/window controls

Key files:

- `D:\PLATTFORM\_tmp_codex_live_agent_app\codex-live-agent-app\services\relay\src\server.js`
- `D:\PLATTFORM\_tmp_codex_live_agent_app\codex-live-agent-app\launch-monitor.ps1`

Purpose:

- operator-facing monitoring and supervision
- not a cloud release artifact

## 9. Verified Truth

### 9.1 Existing repo-documented verified truth

Already documented before this session:

- hosted staging truth exists for the active candidate
- phase 4 is documented as `100%`
- phase 5 current documented candidate truth is `67%`
- hosted external gates are documented as verified
- numerous candidate artifacts and phase verifiers are recorded in:
  - `docs/verification-register.md`
  - `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md`

### 9.2 Local verifications completed in this session

Performed on 2026-05-08:

1. Security suite refresh:
   - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1 -Suite security -RefreshSecretScans`
   - passed

2. Verifier registry coverage:
   - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1 -List`
   - confirms `suite=all` now covers all `verify-*.ps1`

3. Dev stack health:
   - `docker compose -f docker-compose.dev.yml up -d`
   - frontend needed rebuild
   - after rebuild the dev stack became healthy

4. Local runtime suite:
   - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1 -Suite phase1-runtime`
   - passed end to end

5. Local browser contract:
   - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1 -Suite browser-contract -AllowLocalhost`
   - passed

6. Final local dev stack status:
   - all containers healthy in `docker compose -f docker-compose.dev.yml ps`

### 9.3 Desktop monitor verification completed earlier in this session chain

Previously verified in this workspace:

- relay health on `http://127.0.0.1:43110/health`
- local desktop agent runtime summary endpoints
- operator note delivery from monitor UI path
- live card/status rendering in the monitor

This is real local software truth, but not cloud-staging proof.

## 10. Security / Secret Truth

### 10.1 What is true

- secret scanning was centralized through:
  - `scripts/run-secret-scans.ps1`
  - `scripts/verify-security.ps1`
- verifier registry wrapper now supports security refresh through:
  - `scripts/verify.ps1`
- current security suite passed locally in this session

### 10.2 What remains imperfect

- `gitleaks` binary is not installed locally in this environment
- current run reused the cached JSON report path
- detect-secrets baseline still reports hotspots

Current detect-secrets hotspots seen in this session:

- `vercel_storage.json`
- `scripts\verify-phase1-runtime.ps1`
- `services\agent-api\app\main.py`
- `apps\frontend\.vercel\project.json`

Interpretation:

- the security path is operational
- the hotspot list is still a review queue
- the biggest obvious sensitive artifact remains `vercel_storage.json`

## 11. Release / Hosted Truth

### 11.1 Active production-candidate

Active candidate file:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md`

Current candidate facts from that file:

- release id: `prod-candidate-2026-05-05-rc1`
- source branch: `chore/repo-bootstrap`
- source candidate commit:
  - `ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`
- workflow run:
  - `25392582005`
- owner decision:
  - `no-release`
- staging tag parity:
  - `blocked`
- repo worktree parity:
  - `blocked`

### 11.2 What this means

The project has a verified production-candidate evidence chain.
It does not have a verified production rollout claim.

That distinction must stay explicit.

## 12. Main Truth Gaps

These are the most important remaining truth gaps:

1. Current repo HEAD is not the last verified candidate commit.
2. Current worktree is dirty and not parity-clean.
3. Mutable hosted `:staging` tag is not proven equal to the immutable candidate tag set.
4. Local security scan path works, but secret hotspots still exist and must be reviewed.
5. Desktop monitor/local agent runtime are valid local tools, but they are not proof that the cloud runtime itself has identical state.

## 13. What Another AI Agent Must Not Claim

The reviewing AI agent must not claim any of the following unless it produces new proof:

- current repo HEAD equals the verified candidate commit
- current worktree is release-clean
- mutable `:staging` equals the immutable candidate SHA tag set
- production is deployed
- local monitor truth equals hosted truth automatically
- localhost-only proof equals hosted proof

## 14. What Another AI Agent Can Safely Claim

The reviewing AI agent can safely claim:

- a seven-layer cloud-native architecture is documented and partially/mostly implemented
- the main repo contains both local and hosted runtime paths
- local dev/runtime/browser/security verifiers are operational
- a hosted staging candidate evidence chain exists and is extensively documented
- release truth is currently fail-closed with `no-release`
- repo/worktree parity and staging-tag parity are explicitly blocked, not hidden

## 15. Recommended Review Order for Another AI Agent

1. Read:
   - `docs/system-architecture.md`
   - `docs/runtime-contracts/cloud-provider-inventory-contract.md`
   - `docs/runtime-contracts/cloud-deployment-preflight-contract.md`
   - `docs/runtime-contracts/layer-interface-contracts.md`
2. Read:
   - `docs/project-progress.manifest.json`
   - `docs/verification-register.md`
3. Read:
   - `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md`
4. Check:
   - current `git rev-parse HEAD`
   - current `git status --short`
5. Run local proofs:
   - `scripts\verify.ps1 -Suite security -RefreshSecretScans`
   - `scripts\verify.ps1 -Suite phase1-runtime`
   - `scripts\verify.ps1 -Suite browser-contract -AllowLocalhost`
6. Only then judge whether hosted and release claims still line up with current repo state.

## 16. Session Addendum: Changes Performed in This Session

Main repo changes made in this session include:

- verifier suite registry cleanup and expansion
- `suite=all` coverage check in `scripts/verify.ps1`
- centralized secret-scan refresh path
- extra root artifact ignores for sensitive debug outputs
- local dev stack bring-up and frontend rebuild fix
- successful rerun of local runtime and browser-contract verification

Desktop/local-monitor changes completed earlier in this working chain include:

- local runtime probing hardening
- relay summary normalization across runtime modes
- operator note handling without overwriting failure state
- monitor start/restart flow hardening

## 17. Bottom Line

The true system state is:

- cloud architecture: documented and materially implemented
- local runtime path: working and freshly re-verified
- hosted staging candidate path: extensively documented and previously verified
- production rollout: not claimed
- current repo/worktree parity to last verified candidate: blocked

That is the honest truth boundary as of 2026-05-08.
