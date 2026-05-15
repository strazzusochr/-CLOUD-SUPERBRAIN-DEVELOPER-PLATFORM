# LLM Provider Readiness Contract Local Proof - 2026-05-15

Status: DEV-ONLY local proof. Hosted parity and production rollout are not claimed.

## Slice

- Added `GET /llm/api/v1/providers/readiness/contract`.
- Contract: `llm-provider-readiness-contract-v1`.
- Evidence: `llm_provider_readiness_contract_visible`.
- The contract proves provider-readiness gates from configured routes and environment flags without calling the upstream provider.
- The Workbench LLM Gateway surface now renders the readiness contract, evidence marker, deterministic default, `external_probe_performed=false`, and non-claims.

## Files

- `services/llm-gateway/app/main.py`
- `apps/frontend/app/page.tsx`
- `scripts/verify-llm-provider-readiness-contract.ps1`
- `scripts/verify-browser-contract.ps1`
- `scripts/verify-phase1-runtime.ps1`
- `scripts/verify-phase1.ps1`
- `docs/runtime-contracts/llm-provider-readiness-contract.md`
- `docs/runtime-contracts/llm-gateway-routing.md`
- `docs/verification-register.md`

## Verification

- `py -3 -m py_compile services\llm-gateway\app\main.py services\agent-api\app\db.py` passed.
- `npm run lint --prefix apps/frontend` passed.
- `npm run build --prefix apps/frontend` passed.
- `npm audit --prefix apps/frontend --audit-level=moderate` passed with `0 vulnerabilities`.
- `docker info --format '{{.ServerVersion}}'` returned `29.4.1`.
- `docker compose -f docker-compose.dev.yml build llm-gateway agent-api frontend` passed.
- `docker compose -f docker-compose.dev.yml up -d --no-deps --force-recreate llm-gateway agent-api frontend nginx` passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-llm-provider-readiness-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1` passed, including gitleaks with no leaks found.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-phase1-runtime.ps1` passed.
- `py -3 scripts\verify_project_progress_manifest.py` passed with `overall=82%`.
- `git diff --check` passed.
- Browser Use / Node REPL in-app browser DOM proof passed for `Provider Readiness Contract`, `llm-provider-readiness-contract-v1`, `llm_provider_readiness_contract_visible`, `GET /llm/api/v1/providers/readiness/contract`, `external_probe_performed=false`, `live_provider_calls=false`, `model_downloads=false`, `provider_token_returned=false`, no live provider generation call, no upstream model-list probe, and no console errors.

## Non-Claims

- No progress percentage changed.
- No hosted staging update is claimed.
- No production rollout or release promotion is claimed.
- No live provider generation call, upstream model-list probe, live MCP write, local model download, or secret exposure is claimed.
