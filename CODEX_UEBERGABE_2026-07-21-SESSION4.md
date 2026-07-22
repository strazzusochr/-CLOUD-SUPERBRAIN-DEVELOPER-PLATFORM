# Codex Handover 2026-07-21 Session 4

## Executive Status

Cloud Superbrain is at canonical Overall `86%`, with seven cells already at `100%`. The hosted
Workbench LLM HTTP 503 has been repaired and proved in Preview and Production. A new local RC4 was
built from committed source and verified. The current worktree then entered a security-critical
Phase-3 auth repair. That auth slice has focused source, unit, and local runtime proof but has not
yet received the full verifier chain, truth-mirror update, clean commit, push, or RC5 rebuild.

This document exists so a fresh Codex chat continues from that exact state without repeating old
work, losing uncommitted changes, staging foreign files, or making a false completion claim.

## Post-Handover Update — 2026-07-22

The auth slice is now fully implemented and locally verified. Nineteen unit tests, real-Redis
concurrent one-winner consumption, HTTP negative paths, `npm run verify:runtime`, the complete
51-minute `npm run verify:browser`, and `npm run verify` passed sequentially. Evidence is
`.codex/runs/CURRENT/phase3/auth-fail-closed/report.json`, SHA-256
`FB90E6D57FFBC6C646C583D6F5DD18F4EDB71D9E881B9B7090B3FFDD31FCADC1`. The static run also
detected a new `sharp <0.35.0` advisory; exact override `0.35.3` closes it and npm audit reports
zero vulnerabilities. P3 remains `44%`, Overall `86%`; no duplicate credit. DEV-ONLY; hosted proof
still blocked. The next step is selective commit/push, followed by RC5 clean-archive requalification.

## Authoritative Resume References

- Stable anchor: `PROJECT_ANCHOR_CURRENT.md`
- Machine checkpoint: `docs/project-checkpoint-2026-07-21-session4.json`
- Memory rules: `docs/codex-integration/CODEX_MEMORY_PROTOCOL_2026-07-21_SESSION4.md`
- New-chat prompt: `CODEX_START_PROMPT_2026-07-21_SESSION4.md`
- Canonical progress: `docs/project-progress.manifest.json`
- Canonical truth mirrors: `PROJECT_STATE.md`, `docs/verification-register.md`, `AI_HANDOFF.md`
- Binding supervisor rules: `AGENTS.md`

## Repository Reference Point

- Workspace: `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`
- Branch: `claude/cloud-superbrain-analysis-127d2e`
- Pushed base HEAD before anchor creation:
  `a80c35619bb1826b15f4a729267778c1869ba290`
- Subject: `verify(release): requalify runtime candidate rc4`
- Origin branch matched local HEAD when checked.
- Prerequisite `807553b` is an ancestor.
- Origin was reachable.

## Current Progress Matrix

| Horizontal | Percent |
| --- | ---: |
| P0 | 100 |
| P1 | 100 |
| P2 | 100 |
| P3 | 44 |
| P4 | 100 |
| P5 | 68 |
| P6 | 90 |

| Vertical | Percent |
| --- | ---: |
| Frontend | 100 |
| Orchestrator | 100 |
| Agent Pool | 69 |
| LLM Gateway | 55 |
| MCP Gateway | 56 |
| Memory | 90 |
| Observability | 100 |

Overall remains `86%`. `MARKET_READY` remains false. The auth security repair is replacement
evidence for an invalid old proof and must not increase P3 or Overall by itself.

## Work Completed And Pushed

### Hosted LLM Read-Only Parity

Commit `76f46446` added a source-bound, token-free Cloudflare Preview Worker health/model proof.
It credits only `cloudflare_workers_ai_llm_gateway_preview_readonly_source_parity_verified`, moving
LLM Gateway `54 -> 55`. It makes no inference, provider-write, Production Worker, release, or full
production claim.

Evidence:
`.codex/runs/CURRENT/llm-gateway/cloudflare-hosted-readonly/report.json`

SHA-256:
`D9DE8F7C46309F1FDA1EED43D4C2F14A65D99A2D77D60B01AAC449A1CAB83D71`

### Hosted Workbench LLM 503 Repair

The reported immutable Vercel Preview failure was reproduced as HTTP `503`. Cloudflare Preview and
Vercel origin/auth configuration were aligned without displaying secret values. Source `67f41ce`
was redeployed. A real mini-build returned HTTP `200` through Cloudflare Workers AI in both the new
Preview and Production alias.

Real Chrome then passed all 22 canonical routes at desktop and mobile on both deployments:

- Preview: `44/44`, zero console/overflow/overlay failures.
- Production: `44/44`, zero console/overflow/overlay failures.

Evidence:
`.codex/runs/CURRENT/llm-gateway/frontend-build-503-fix/report.json`

SHA-256:
`B66A02387CD5CCA631947DAC7E6A99BF9B1E0BC5A498F6828437018794F42F0A`

This was an operational repair, not a release promotion. The frontend still targets the Cloudflare
Preview Worker, and the failed immutable deployment remains historical.

### Browser Runtime Stability

Docker Desktop Resource Saver was found shutting down the engine during long browser runs. The
local Docker setting `UseResourceSaver=false` was applied outside the repository. The frontend
WebGL error boundary was updated so the visible render mode changes to `2d` after a Three.js/chunk
fallback. Frontend package metadata now declares ESM and Node `>=20.9 <26`.

Commit: `0679f6ff`

The full local browser gate subsequently passed all suites, including 22 x 2 responsive navigation.

### RC4 Requalification

Commit `a80c3561` recorded local candidate
`prod-candidate-2026-07-21-local-rc4` from committed source
`0679f6ffda099a6fcddf6830839a195ebe7d13a7`.

- Six images built from a clean Git archive.
- OCI revision/source/version labels passed.
- Embedded source hashes matched.
- Frontend Next.js `BUILD_ID` was non-empty.
- Real Chromium Diagnostics selection/click passed (`1/1`).
- Rollback target is RC3 at `90b57ecaa54e0ab750a57d0e1acfb33779675f5a`.
- `candidate_technical=true`.
- `runtime_source_parity=true`.
- `promotion_eligible=false`.
- P5 remains `68%`; no duplicate credit.

Candidate report SHA-256:
`A471CB2DB722D5E37130B710D59D9FF47A8F31844239D4C3064AF3B212DE13A6`

Verification SHA-256:
`1348B1640C3DF630D57DA29202F3076348319496ECA007D12E0B291197315EF4`

## Last Full Green Baseline

Before the auth edits, `npm run verify` passed in `205.9s` with:

- progress manifest valid at Overall `86%`;
- frontend npm audit: zero vulnerabilities;
- Cloudflare LLM tests: `4/4`;
- Cloudflare D1 static tests: `5/5` from a foreign in-progress slice;
- gitleaks: about 165 MB scanned, no leaks.

The current auth worktree has not yet rerun that full gate.

## Security Defect Found After RC4

The Agent API auth implementation had two credential-minting defects:

1. `GET /api/v1/auth/callback` accepted any non-empty `code` and `state`, then minted access and
   refresh credentials for a fixed local subject without validating OAuth state or GitHub identity.
2. `POST /api/v1/auth/refresh` treated any previously unseen string as a valid refresh token,
   blacklisted it, and minted new credentials. A caller did not need a token issued by this service.

Additional weaknesses included a predictable default JWT signing secret, raw OAuth state in audit
details, JSON-body refresh-token acceptance, blacklist-key disclosure, and logout claiming that an
arbitrary token had been revoked.

The old `local_auth_lifecycle_browser_proof` and `hosted_auth_lifecycle_staging_proof` markers were
therefore removed from the current manifest status and replaced by fail-closed markers without a
percentage increase.

## Auth Repair Implemented In The Dirty Worktree

### Agent API

`services/agent-api/app/main.py` now contains:

- `AUTH_OAUTH_STATE_PREFIX` and a ten-minute Redis state lifetime;
- `__Host-sb_oauth_state`, `__Host-sb_access`, and `__Host-sb_refresh` cookies;
- one-time transactional OAuth-state consumption;
- complete configuration checks for client id, client secret, redirect URI, and a non-placeholder
  base64url signing secret carrying at least 256 bits before production credential issuance;
- random process-local signing fallback when no strong secret is configured;
- fixed GitHub token and user endpoints with no redirect following;
- credential issuance only after a verified numeric GitHub user id;
- Redis active-refresh registry with a subject record;
- transactional single-use refresh consumption and blacklist rotation;
- body refresh token rejection;
- unknown, malformed, invalid-record, invalid-subject, and blacklisted rejection paths;
- logout revocation only when the cookie token was active;
- persisted PostgreSQL audit evidence before successful callback/refresh cookies;
- no OAuth code/state, token value, or blacklist key in response/audit details.

### Tests And Contract

- `services/agent-api/tests/test_auth_security.py`: nineteen unit tests.
- `scripts/verify-phase3-auth-fail-closed.ps1`: source guards, unit tests, and runtime negative probes.
- `docs/runtime-contracts/phase3-auth-credential-issuance-fail-closed.md`: bounded contract and
  non-claims.
- `apps/frontend/lib/endpointDefaults.ts`: stateless projection aligned to fail-closed behavior.
- Browser, local runtime, hosted staging, Phase-3 hosted auth, Phase-5 auth recheck, and static
  phase-one verifier scripts were edited to stop treating arbitrary input as authentication proof.
- `docs/project-progress.manifest.json`: old insecure current markers replaced by
  `auth_credential_issuance_fail_closed`, `oauth_state_one_time_enforced`, and
  `refresh_token_registry_enforced`; P3 remains `44%`.

## Auth Evidence Already Green

Unit command:

```powershell
$env:PYTHONPATH='services\agent-api'
py -3 -m unittest discover -s services\agent-api\tests -v
```

Result: `19/19 passed`.

Static focused verifier:

```powershell
$env:TEMP='D:\_sb_tmp'; $env:TMP='D:\_sb_tmp'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-phase3-auth-fail-closed.ps1 -StaticOnly
```

Result: passed.

Runtime focused verifier:

```powershell
$env:TEMP='D:\_sb_tmp'; $env:TMP='D:\_sb_tmp'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-phase3-auth-fail-closed.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost
```

Result: passed.

Evidence:
`.codex/runs/CURRENT/phase3/auth-fail-closed/report.json`

SHA-256:
`FB90E6D57FFBC6C646C583D6F5DD18F4EDB71D9E881B9B7090B3FFDD31FCADC1`

Observed negative statuses:

- arbitrary callback: HTTP `503` because OAuth is not configured;
- body refresh token: HTTP `400`;
- unknown cookie refresh token: HTTP `401` with reason `unknown`;
- unknown cookie logout: HTTP `200`, but `refresh_token_revoked=false`;
- credentials issued: false;
- live GitHub call: false;
- secret output: false.

Docker was restarted after the Agent API edit and all ten services are healthy.

## Work Still Required Before RC5

1. Review all diffs and stage only owned auth/security changes, excluding the foreign D1 hunk in
   `scripts/verify-phase1.ps1`.
2. Commit and push the verified repair to `claude/cloud-superbrain-analysis-127d2e`.
3. Rebuild and verify RC5 because RC4 predates the Agent API, frontend projection, dependency lock,
   and manifest changes.

## Exact Verification Sequence

```powershell
Set-Location 'D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM'
$env:TEMP='D:\_sb_tmp'
$env:TMP='D:\_sb_tmp'
$env:PATH='D:\_sb_tmp\node24-bin;C:\Users\immer\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin;'+$env:PATH

py -3 -m py_compile services\agent-api\app\main.py
$env:PYTHONPATH='services\agent-api'
py -3 -m unittest discover -s services\agent-api\tests -v
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-phase3-auth-fail-closed.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost
py -3 scripts\verify_project_progress_manifest.py
npm run verify
npm run verify:runtime
npm run verify:browser
```

Never overlap `verify`, Playwright, or Docker build commands.

## Owned Auth Files To Stage After Green Gates

- `services/agent-api/app/main.py`
- `services/agent-api/tests/test_auth_security.py`
- `apps/frontend/lib/endpointDefaults.ts`
- `scripts/verify-phase3-auth-fail-closed.ps1`
- `scripts/verify-browser-contract.ps1`
- `scripts/verify-phase1-runtime.ps1`
- `scripts/verify-hosted-staging.ps1`
- `scripts/verify-phase3-auth-hosted.ps1`
- `scripts/verify-phase5-auth-gate-recheck.ps1`
- auth hunks only in `scripts/verify-phase1.ps1`
- `docs/runtime-contracts/phase3-auth-credential-issuance-fail-closed.md`
- `docs/project-progress.manifest.json`
- the truth/ADR files added while finishing the slice.

## Dirty-Worktree Ownership Boundary

Do not stage, revert, rewrite, format, or delete these foreign changes:

- `.gitignore`
- `apps/frontend/app/api/v1/build/route.ts`
- `apps/frontend/app/run/[id]/page.tsx`
- `apps/frontend/components/goal-b-actions.tsx`
- `apps/frontend/lib/frontendBoundary.ts`
- `apps/frontend/tsconfig.tsbuildinfo`
- root `package.json`
- `scripts/verify-cloudflare-llm-gateway.ps1`
- untracked `apps/frontend/components/run-build.tsx`
- untracked Cloudflare stateful runtime source/verifiers/browser proof files
- pre-existing untracked goal, handoff, screenshot, Python environment, and helper files.

`scripts/verify-phase1.ps1` contains both owned auth edits and a foreign uncommitted D1 static
contract invocation. Use partial staging. Do not use broad `git add -A`.

## Git UI Hang Finding

The displayed `git diff --cached -- scripts/verify-phase1.ps1` timer was stale UI state. Process
inspection found no Git or pager process. This command completed normally with no output:

```powershell
git --no-pager diff --cached --no-ext-diff -- scripts/verify-phase1.ps1
```

Use the safe no-pager form for future diffs.

## Project Goal

The finish line remains:

```text
npm run verify:market-ready
MARKET_READY: true
```

Every matrix cell must have real evidence. Owner walls must remain explicit and cannot be faked.
If only genuine Owner walls remain after all autonomous work is complete, produce the exact Owner
action packet and keep all claims false until verified.

## Always Do

- Read the current anchor/checkpoint before acting.
- Preserve foreign changes.
- Set TEMP/TMP to `D:\_sb_tmp` before every verifier.
- Bind progress to code, runtime proof, verifier, artifact, and truth update.
- Keep token values and OAuth code/state out of output and evidence.
- Keep local proof labeled `DEV-ONLY`.
- Commit and push only the owned slice to the existing branch.
- Requalify the release candidate after runtime-source changes.
- Continue autonomously until market ready or only real Owner walls remain.

## Never Do

- Never hand-edit `live_verified`.
- Never increase P3 for merely repairing invalid evidence.
- Never reuse the old arbitrary callback/refresh lifecycle as proof.
- Never stage the full dirty worktree.
- Never push or merge to `main`, force push, publish GHCR, or promote a release without its gate.
- Never expose or commit secrets.
- Never run expensive gates in parallel.
- Never treat localhost, a stateless Vercel contract origin, or a Preview Worker as full production
  stateful parity.
