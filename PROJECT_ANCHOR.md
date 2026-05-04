# Project Anchor - Cloud Superbrain Developer Platform

Anchor ID: `project-anchor-2026-04-30T00-49-26+02-00`
Created: `2026-04-30 00:49:26 +02:00`
Project root: `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`
Checkpoint file: `docs/project-checkpoint-2026-04-30.json`

## Binding Truth

This anchor is a resume point, not a new architecture source. Binding truth remains:

- `PROJECT_STATE.md`
- `AI_HANDOFF.md`
- `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md`
- `docs/project-progress.manifest.json`
- `docs/verification-register.md`

If any older document conflicts with this anchor or the files above, use the patched ultimatum and the progress manifest.

## Project Goal

Build the Cloud Superbrain Developer Platform as a cloud-native, evidence-driven, multi-agent AI developer platform. The target system is prompt-driven, LangGraph-orchestrated, pgvector-backed, observable, budget-guarded, and capable of running specialist agent workflows for application and 3D web-game delivery without making unsupported hosted, production, live-provider, or live-MCP claims.

Core goal constraints:

- Keep the 7-layer architecture from `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md`.
- Keep LangGraph plus PostgreSQL checkpointing as the orchestration spine.
- Keep memory in PostgreSQL/pgvector through the service.
- Keep local Phase 1/2 proofs deterministic unless external gates are explicitly configured.
- Keep infrastructure inside the hard budget envelope; the latest Hetzner live budget proof was under the hard cap but above warning threshold.
- Never increase progress percentages without code, runtime proof, and verifier/doc evidence.

## Current Project State

Verified local timestamp: `2026-04-30 00:49:26 +02:00`

Current progress:

| Dimension | Value |
| --- | ---: |
| Overall | 47% |
| P0 | 100% |
| P1 | 98% |
| P2 | 86% |
| P3 | 33% |
| P4 | 15% |
| P5 | 0% |
| P6 | 0% |
| Frontend | 97% |
| Orchestrator | 99% |
| Agent Pool | 61% |
| LLM Gateway | 53% |
| MCP Gateway | 53% |
| Memory | 69% |
| Observability | 99% |

Runtime snapshot:

- Browser entrypoint: `http://localhost:8081/`
- Stream entrypoint: `http://localhost:8081/api/stream`
- `GET /api/v1/health`: `healthy`
- Postgres: `healthy`
- Redis: `healthy`
- Agent Worker: `healthy`
- Memory Worker: `healthy`
- MCP Gateway: `healthy`
- LLM Gateway: `healthy`, `deterministic_dry_run`
- Project progress integrity: `verified`, `computed_overall_percent=47`, `manifest_overall_percent=47`
- Recent sessions endpoint returned 3 sessions in the live probe.

Docker compose state for `cloud-superbrain-phase1-dev`:

- `agent-api`: healthy
- `agent-worker`: healthy
- `frontend`: healthy
- `llm-gateway`: healthy
- `mcp-gateway`: healthy
- `memory-worker`: healthy
- `nginx`: healthy on `0.0.0.0:8081`
- `postgres`: healthy
- `redis`: healthy

## Latest Protocol Report

The latest repair cycle focused on the user-visible regression where chat/run history no longer opened from the dashboard.

Root causes found:

- The live `agent-api` container was stale while local code already contained the history route.
- Nginx held stale Docker upstream IPs after backend service recreates.
- `list_recent_tasks()` performed one Redis `GET` per task key, causing visible delays when Redis contained thousands of task status keys.
- The frontend fired many dashboard requests every 3 seconds, causing network pressure and making the opened history panel appear stuck on `loading`.
- The local root Docker environment had unrelated restart loops in optional `codex-sandbox-superbrain`, `docker-mcp-gateway`, and `mcp-nginx` containers.

Fixes implemented:

- Rebuilt and verified `agent-api` and frontend so `/api/v1/sessions/{session_id}/history` is live.
- Added dynamic Docker DNS resolver behavior to `infrastructure/nginx/dev.conf` so Nginx resolves service names after recreates.
- Added `mcp-gateway` as a health-gated Nginx dependency in `docker-compose.dev.yml`.
- Optimized recent task loading with Redis `MGET` chunking in `services/agent-api/app/tasks.py`.
- Split frontend data loading into primary, delayed background, 15-second live refresh, and 60-second activity refresh groups in `apps/frontend/app/page.tsx`.
- Added a regression guard to `scripts/verify-browser-contract.ps1` proving session history opens for a freshly started Phase 2 runtime run.
- Added static guard strings to `scripts/verify-phase1.ps1` so the browser verifier cannot drop the history proof silently.
- Repaired the root-level Codex sandbox with a stdlib-only health runner at `D:\PLATTFORM\codex-github-runner.py`.
- Marked the optional root Docker MCP gateway/nginx profile as host-CLI-only to stop invalid restart loops.

Evidence from the repair:

- Browser click opened a real run history panel.
- Network proof: `GET /api/v1/sessions/ee81f6c1-703b-499d-9a33-b11d6b3cc0e0/history => 200 OK`.
- Console proof after opening history: 0 errors, 0 warnings.
- Opened history panel showed:
  - Progress: 47%
  - Integrity: verified
  - Evidence: `session_history_openable_project_state`
  - Messages: 4
  - Tasks: 4
  - Audit Events: 9
  - Manifest evidence: `project_progress_integrity_runtime_proof`
- Screenshot artifacts:
  - `D:\PLATTFORM\superbrain-history-open-verified-2026-04-29.png`
  - `D:\PLATTFORM\superbrain-opened-history-panel-verified-2026-04-29.png`

Verification commands that passed in the repair cycle:

- `py -3 -m py_compile services\agent-api\app\tasks.py services\agent-api\app\main.py`
- `npm run build --prefix apps/frontend`
- `docker compose -f docker-compose.dev.yml config --quiet`
- `nginx -t` against the dev Nginx config
- `powershell -ExecutionPolicy Bypass -File scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- `powershell -ExecutionPolicy Bypass -File scripts\verify-hosted-staging.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`

Verification commands that passed for this anchor:

- `GET http://localhost:8081/api/v1/health`
- `GET http://localhost:8081/api/v1/project/progress`
- `GET http://localhost:8081/api/v1/project/progress/integrity`
- `GET http://localhost:8081/api/v1/sessions/recent?limit=3`
- `GET http://localhost:8081/api/v1/sessions/ee81f6c1-703b-499d-9a33-b11d6b3cc0e0/history`
- `docker compose -f D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM\docker-compose.dev.yml ps`

## Current Non-Claims

Do not claim these as done:

- No real hosted staging success is proven without a real `STAGING_BASE_URL`.
- No production deployment is proven.
- No live external LLM provider call is proven.
- No live MCP write is proven.
- No branch protection change is proven without `BRANCH_PROTECTION_TOKEN`.
- No infrastructure expansion is approved while the Hetzner budget proof is above warning threshold.

## Next Step

Next safe work item: external gate configuration and hosted staging proof.

Objective:

1. Configure only explicitly provided external gates:
   - `STAGING_BASE_URL`
   - `BRANCH_PROTECTION_TOKEN`
   - optional canonical `gitleaks`
   - optional fresh Hetzner token for another live budget proof
2. Run hosted verifier against the real hosted URL, not localhost:
   - `powershell -ExecutionPolicy Bypass -File scripts\verify-hosted-staging.ps1 -BaseUrl <STAGING_BASE_URL>`
3. Confirm branch protection through the GitHub-protected path only after the token exists.
4. Keep local deterministic verifiers green after every code or infra change.
5. Only then raise Phase 4 / hosted-readiness progress if code, runtime proof, and verification-register updates agree.

Immediate acceptance criteria for the next step:

- Hosted staging endpoint returns the same contract set currently proven on localhost.
- `GET /api/v1/health` is healthy on hosted URL.
- `GET /api/v1/project/progress/integrity` is verified on hosted URL.
- Session history opens on hosted URL with `session-history-v1`.
- Browser console remains clean after opening Recent Runs history.
- Non-claims remain explicit for any still-missing gate.

## Checkpoint

Checkpoint ID: `project-anchor-2026-04-30T00-49-26+02-00`

Resume prompt:

```text
Resume from PROJECT_ANCHOR.md and docs/project-checkpoint-2026-04-30.json.
First verify localhost:8081 health, project progress integrity, Docker compose health,
and session history opening. Then continue external gate / hosted staging proof work
without changing progress percentages until runtime evidence exists.
```

Resume commands:

```powershell
cd D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM
docker compose -f docker-compose.dev.yml ps
curl.exe -s http://localhost:8081/api/v1/health
curl.exe -s http://localhost:8081/api/v1/project/progress/integrity
powershell -ExecutionPolicy Bypass -File scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost
powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1
```

Rollback note:

- No database migration was introduced by this anchor.
- This anchor adds documentation/checkpoint state only.
- To roll back the anchor, remove `PROJECT_ANCHOR.md`, remove `docs/project-checkpoint-2026-04-30.json`, and remove the anchor references from `PROJECT_STATE.md` and `AI_HANDOFF.md`.

## Memory Persistence

Platform memory checkpoint persisted through `POST /api/v1/prompt`:

- Session ID: `d4e09879-49a2-401a-80b2-228cfa5cfb6b`
- Task ID: `db11d606-0d34-4041-bbe9-3aaeb7861c59`
- Memory ID: `55a3959e-c570-481f-9d02-9755ff421733`
- Task status: `completed`
- Worker result: Planner accepted `prompt_intake`; deterministic execution completed without LLM calls.
- Memory search verification: `GET /api/v1/memory/search` found the anchor with `search_mode=lexical_fallback` and relevance `1.0`.
