# Memory Worker Health Contract Local Proof - 2026-05-15

Status: DEV-ONLY local proof. Hosted parity and production rollout are not claimed.

## Slice

- Added `GET /api/v1/memory/worker-health/contract`.
- Contract: `memory-worker-health-contract-v1`.
- Evidence: `memory_worker_health_contract_visible`.
- Hardened `check_memory_worker()` to require a fresh Redis heartbeat, accepted heartbeat status, and `stale_heartbeat=false`.
- Replaced dependency-only Memory Worker Docker healthchecks with `python -m app.worker --healthcheck`.
- Raised Memory Worker healthcheck timeout to `15s` after direct proof showed the Python module healthcheck can exceed `5s` during container runtime.

## Files

- `services/memory-worker/app/worker.py`
- `services/agent-api/app/db.py`
- `services/agent-api/app/main.py`
- `apps/frontend/app/page.tsx`
- `docker-compose.dev.yml`
- `docker-compose.cloud.yml`
- `scripts/verify-memory-worker-health-contract.ps1`
- `scripts/verify-browser-contract.ps1`
- `scripts/verify-phase1-runtime.ps1`
- `scripts/verify-phase1.ps1`
- `docs/runtime-contracts/memory-worker-health-contract.md`
- `docs/runtime-contracts/memory-consolidation-job.md`
- `docs/verification-register.md`

## Verification

- `py -3 -m py_compile services\agent-api\app\main.py services\agent-api\app\db.py services\memory-worker\app\worker.py` passed.
- `npm run lint --prefix apps/frontend` passed.
- `npm run build --prefix apps/frontend` passed.
- `npm audit --prefix apps/frontend --audit-level=moderate` passed with `0 vulnerabilities`.
- `docker info --format '{{.ServerVersion}}'` returned `29.4.1`.
- `docker compose -f docker-compose.dev.yml build agent-api memory-worker frontend` passed.
- `docker compose -f docker-compose.dev.yml up -d --no-deps --force-recreate agent-api memory-worker frontend nginx` passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-memory-worker-health-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1` passed, including gitleaks with no leaks found.
- `py -3 scripts\verify_project_progress_manifest.py` passed with `overall=82%`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-phase1-runtime.ps1` passed.
- `docker inspect --format '{{json .State.Health}}' cloud-superbrain-phase1-dev-memory-worker-1` returned `Status=healthy`, `FailingStreak=0`, and `stale_heartbeat=false`.
- `git diff --check` passed.
- Browser Use / Node REPL in-app browser DOM proof passed for `Memory Worker Health Contract`, `memory-worker-health-contract-v1`, `memory_worker_health_contract_visible`, `GET /api/v1/memory/worker-health/contract`, `python -m app.worker --healthcheck`, `stale_heartbeat=false`, no live embedding provider call, no local model download, no live MCP write / production rollout / release promotion / hosted parity claim, and no console errors.

## Non-Claims

- No progress percentage changed.
- No hosted staging update is claimed.
- No production rollout or release promotion is claimed.
- No live embedding provider call, live LLM provider call, live MCP write, external MCP mutation, local model download, or secret exposure is claimed.
