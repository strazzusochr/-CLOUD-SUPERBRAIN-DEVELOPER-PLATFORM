# Cloud Superbrain Project Anchor

Anchor ID: `cloud-superbrain-anchor-2026-07-21T23-48-28+02-00-session4`

Status: `ACTIVE_RESUME_POINT`

Workspace: `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`

Branch: `claude/cloud-superbrain-analysis-127d2e`

Committed reference before this anchor: `a80c35619bb1826b15f4a729267778c1869ba290`

Machine checkpoint: `docs/project-checkpoint-2026-07-21-session4.json`

Detailed handoff: `CODEX_UEBERGABE_2026-07-21-SESSION4.md`

Memory protocol: `docs/codex-integration/CODEX_MEMORY_PROTOCOL_2026-07-21_SESSION4.md`

## Purpose

This is the exact restart point for a new Codex chat. It preserves the completed hosted LLM
repair and RC4 work, the current uncommitted Phase-3 auth hardening slice, all verified evidence,
the dirty-worktree ownership boundary, and the next commands. It is a resume snapshot, not a new
progress authority. Canonical percentages still come only from
`docs/project-progress.manifest.json`, with `PROJECT_STATE.md` and
`docs/verification-register.md` as truth mirrors.

## Required Resume Order

1. Read this file completely.
2. Read `CODEX_UEBERGABE_2026-07-21-SESSION4.md` completely.
3. Read `docs/project-checkpoint-2026-07-21-session4.json`.
4. Read `docs/codex-integration/CODEX_MEMORY_PROTOCOL_2026-07-21_SESSION4.md`.
5. Read `PROJECT_STATE.md`, the two binding patched ultimatum files, and the autonomous roster
   required by `AGENTS.md`.
6. Verify `git log -1` is at least the anchor commit and `origin` is reachable. Stop if either
   prerequisite fails.
7. Set `$env:TEMP='D:\_sb_tmp'` and `$env:TMP='D:\_sb_tmp'` before every verifier.
8. Inspect `git status --short`; preserve every foreign dirty file listed below.
9. Continue the auth hardening slice at the exact next step below. Do not restart the project or
   overwrite the current worktree.

## Current Canonical Progress

- Overall: `86%`
- Horizontal: `P0 100 | P1 100 | P2 100 | P3 44 | P4 100 | P5 68 | P6 90`
- Vertical: `Frontend 100 | Orchestrator 100 | Agent Pool 69 | LLM 55 | MCP 56 | Memory 90 | Observability 100`
- `MARKET_READY: false`
- Progress has not been increased for the auth repair.

## Completed And Pushed In This Session

- `76f46446` - hosted Cloudflare LLM Preview read-only source parity, LLM `54 -> 55`, truth
  mirrors, and the documented Workbench LLM HTTP 503 repair.
- `0679f6ff` - frontend WebGL fallback state synchronization plus supported Node runtime metadata.
- `a80c3561` - RC4 local clean-archive candidate requalification.
- All three commits were pushed to `origin/claude/cloud-superbrain-analysis-127d2e`.
- Hosted Workbench mini-builds return HTTP `200` through Cloudflare Workers AI.
- Preview and Production each passed real-Chrome 22 routes x 2 viewports (`44/44`) with zero
  console, overflow, or overlay failures.
- RC4 built six Docker images from committed source
  `0679f6ffda099a6fcddf6830839a195ebe7d13a7` and passed the focused Chromium candidate proof.
- `npm run verify:current-release-candidate` passed with
  `candidate_technical=true`, `runtime_source_parity=true`, `promotion_eligible=false`.
- The full static `npm run verify` passed before the auth hardening edits (`205.9s`, gitleaks
  clean, npm audit zero vulnerabilities).

## Current Verified Pending-Commit Slice

Phase 3 auth credential issuance is being hardened because the old implementation accepted any
callback `code/state` and minted credentials, while any previously unseen refresh token could mint
a new JWT. That was a real security defect and invalidated the old dry-run issuance proof.

Implemented and fully verified, but not yet committed:

- one-time Redis-backed OAuth state plus `__Host-sb_oauth_state` binding;
- production credential issuance requires complete OAuth configuration, a strong signing secret,
  successful GitHub code exchange, and a verified numeric GitHub user id;
- process-random JWT signing fallback when no strong secret exists, with production issuance
  disabled;
- Redis active-refresh registry, transactional one-time consumption, rotation blacklist, and
  verified subject binding;
- JSON-body refresh tokens rejected;
- unknown or arbitrary refresh values cannot mint credentials;
- logout claims revocation only for an active registered cookie token;
- token values, callback code/state, and blacklist keys removed from responses and audit details;
- frontend stateless auth projection updated to the same fail-closed contract;
- old local/hosted auth verifier paths changed away from arbitrary dry-run issuance;
- nineteen backend unit tests, real-Redis concurrency proof, and a dedicated runtime verifier added;
- successful callback/refresh cookies require persisted PostgreSQL audit evidence;
- JWT signing configuration requires non-placeholder base64url material carrying at least 256 bits;
- Uvicorn access logging is disabled and Nginx logs path-only without callback query parameters;
- hosted auth verification is contract-read-only and performs no OAuth/session mutation;
- frontend `sharp` is overridden to patched `0.35.3` after the audit detected the new `<0.35.0` advisory.

Focused evidence already passed:

- `py -3.14 -m unittest discover -s services\agent-api\tests -p test_auth_security.py -v`: `19/19` passed.
- `scripts\verify-phase3-auth-fail-closed.ps1 -StaticOnly`: passed.
- `scripts\verify-phase3-auth-fail-closed.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`:
  passed against the restarted Docker runtime.
- Runtime statuses: arbitrary callback `503`, body refresh `400`, unknown cookie refresh `401`,
  unknown cookie logout `200` with `refresh_token_revoked=false`.
- Evidence: `.codex/runs/CURRENT/phase3/auth-fail-closed/report.json`.
- Evidence SHA-256: `FB90E6D57FFBC6C646C583D6F5DD18F4EDB71D9E881B9B7090B3FFDD31FCADC1`.
- Docker is currently `10/10 healthy`.
- `npm run verify:runtime`, `npm run verify:browser`, and `npm run verify`: passed sequentially.
- `npm audit --audit-level=high`: `0 vulnerabilities`.
- Progress remains P3 `44%`, Overall `86%`; no duplicate credit. DEV-ONLY; hosted proof still blocked.

## Exact Next Step

1. Review the diff, stage only the auth-owned changes, and partial-stage
   `scripts/verify-phase1.ps1` so the foreign Cloudflare-D1 hunk is excluded.
2. Commit and push only to `claude/cloud-superbrain-analysis-127d2e`.
3. Requalify RC5 from the new committed runtime source because Agent API, frontend projection, and
   the manifest changed after RC4. Do not claim RC4 as current runtime parity after that commit.
4. Continue the market-ready audit and remaining autonomous slices.

## Foreign Dirty Files: Never Stage, Revert, Or Rewrite

- `.gitignore`
- `apps/frontend/app/api/v1/build/route.ts`
- `apps/frontend/app/run/[id]/page.tsx`
- `apps/frontend/components/goal-b-actions.tsx`
- `apps/frontend/lib/frontendBoundary.ts`
- `apps/frontend/tsconfig.tsbuildinfo`
- root `package.json`
- `scripts/verify-cloudflare-llm-gateway.ps1`
- the pre-existing Cloudflare stateful runtime files and verifier files
- `apps/frontend/components/run-build.tsx`
- all pre-existing untracked handoff/goal files, screenshots, Python environment files, and local
  helper scripts visible in `git status` unless ownership is re-established from evidence.

`scripts/verify-phase1.ps1` is mixed ownership: the Phase-3 auth additions belong to this slice;
the uncommitted `Cloudflare D1 stateful runtime static contract` block is foreign and must remain
unstaged unless its owner slice is deliberately resumed and verified.

## Non-Negotiable Rules

- No fake completion, no hand-setting `live_verified`, no duplicate percentage credit.
- No secret values in chat, files, reports, logs, commits, or screenshots.
- No main push, force push, release promotion, registry publication, or production database write.
- No parallel verifier, Playwright, or Docker build execution.
- Localhost evidence must remain labeled `DEV-ONLY`.
- Production auth identity remains Owner-gated until a real hosted callback verifies GitHub identity.
- Payment, password-account creation, CAPTCHA, and secret disclosure are hard Owner walls.
- Keep working on autonomous items; do not stop merely because one wall remains.

## Git-Diff Hang Clarification

The UI displayed an old `git diff --cached -- scripts/verify-phase1.ps1` command as running for a
long time. No `git`, `git-remote-https`, or pager process existed. The safe command
`git --no-pager diff --cached --no-ext-diff -- scripts/verify-phase1.ps1` completed with exit `0`
and no output in about four seconds. This was stale UI state, not a repository lock or running Git
operation. Use `--no-pager --no-ext-diff` for future diagnostic diffs.
