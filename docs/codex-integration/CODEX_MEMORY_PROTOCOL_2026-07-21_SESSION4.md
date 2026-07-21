# Codex Memory Protocol - Session 4 Resume

## Memory Contract

This file preserves operational memory for the next Codex chat. It does not override
`AGENTS.md`, `PROJECT_STATE.md`, the patched ultimatum, or the progress manifest. Where a memory
statement conflicts with live repository evidence, inspect and follow the live evidence.

## Identity And Workspace Memory

- Project: Cloud Superbrain Developer Platform.
- Workspace is always `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`.
- Do not relocate work to `C:`. Only Codex/tool configuration and read-only attachment files live
  there.
- Active branch is `claude/cloud-superbrain-analysis-127d2e`.
- Never force push or write to `main`.
- Base pushed commit at handoff is `a80c35619bb1826b15f4a729267778c1869ba290`.

## Startup Memory

At the beginning of the next chat:

1. Read `PROJECT_ANCHOR_CURRENT.md`.
2. Read `CODEX_UEBERGABE_2026-07-21-SESSION4.md`.
3. Read `docs/project-checkpoint-2026-07-21-session4.json`.
4. Read this file.
5. Follow the project `AGENTS.md` start protocol.
6. Check the current branch, HEAD ancestry, and origin reachability.
7. Set TEMP/TMP to `D:\_sb_tmp` before verification.
8. Inspect current status and continue the dirty auth slice without resetting it.

## Truth Memory

- Overall is `86%`, not 100.
- P3 is `44%` and remains `44%` after the current auth repair.
- LLM Gateway is `55%` after the source-bound Cloudflare Preview read-only proof.
- RC4 is locally verified but predates the auth worktree and will require RC5 after auth is
  committed.
- Production release promotion remains false.
- The canonical token-free external summary remains authoritative.
- Localhost evidence is always `DEV-ONLY`.

## Incident Memory

### Workbench LLM 503

The 503 was real and reproduced on an immutable Vercel deployment. It was repaired by aligning
the Vercel LLM origin/auth configuration with the Cloudflare Preview Worker and redeploying source
`67f41ce`. Preview and Production mini-builds returned HTTP 200 and both passed 22 x 2 Chrome
proofs. Do not reopen this incident without new contradictory evidence.

### Long Browser Failure

The earlier ChunkLoadError/Three.js failures were caused by Docker Desktop Resource Saver shutting
down the engine during a long run. Resource Saver is disabled. The frontend GL boundary now sets
the visible mode to 2D on fallback. The complete browser gate passed after this repair.

### Git Diff Timer

The UI's long-running `git diff --cached -- scripts/verify-phase1.ps1` display was stale. No Git or
pager process existed. The no-pager diff completed in about four seconds. It is not a repository
lock and must not trigger a reset or process kill.

### Auth Credential-Minting Defect

The old callback accepted arbitrary code/state and the old refresh route accepted arbitrary unseen
tokens. The current dirty worktree fixes this. Never restore the old behavior to satisfy legacy
tests. Update or supersede those tests instead.

## Current Auth Design Memory

- OAuth state is random, Redis-backed, cookie-bound, and consumed once.
- Production issuance is disabled unless OAuth client id/secret, valid callback URL, and a strong
  signing secret are configured.
- Callback issuance requires a real GitHub token exchange and verified numeric user id.
- Refresh tokens must be in the Redis active registry and bind to `github:<numeric-id>`.
- Rotation transactionally consumes the old active token before issuing a replacement.
- Unknown, malformed, blacklisted, or replayed refresh tokens fail closed.
- JSON-body refresh tokens are rejected.
- Logout never claims arbitrary-token revocation.
- Responses and audits omit code/state values, token values, and blacklist keys.
- Positive identity exchange is mocked only in unit tests. The focused runtime verifier makes no
  GitHub call and makes no production identity claim.

## Evidence Memory

Current auth evidence:

- Contract: `phase3-auth-credential-issuance-fail-closed-v1`.
- Report: `.codex/runs/CURRENT/phase3/auth-fail-closed/report.json`.
- SHA-256: `C7E0B8D30B0D6725645D855765403E14F1502A75676CA6813BE48B864C6AD9AF`.
- Unit tests: `10/10`.
- Arbitrary callback: `503`, no credentials.
- Body refresh token: `400`.
- Unknown cookie refresh token: `401`.
- Unknown cookie logout: `200`, revoked false.
- Live GitHub call: false.
- Secret output: false.

Current RC4 evidence:

- Candidate SHA-256: `A471CB2DB722D5E37130B710D59D9FF47A8F31844239D4C3064AF3B212DE13A6`.
- Verification SHA-256: `1348B1640C3DF630D57DA29202F3076348319496ECA007D12E0B291197315EF4`.
- Promotion eligible: false.

## Dirty-Tree Memory

Owned in-progress auth files are listed in the machine checkpoint. Foreign dirty files must not be
touched. The most dangerous mixed file is `scripts/verify-phase1.ps1`: auth hunks are owned, while
the Cloudflare D1 static invocation is foreign. Partial staging is mandatory.

Do not use:

```powershell
git add -A
git add .
git checkout -- .
git reset --hard
```

Use explicit file lists and inspect the staged diff with `git --no-pager diff --cached --no-ext-diff`.

## Verification Memory

- Always export TEMP/TMP to `D:\_sb_tmp` before a verifier.
- Prefer bundled Node 24 through the existing `D:\_sb_tmp\node24-bin` wrappers for npm/Playwright.
- Never run `verify`, Playwright, or Docker builds concurrently.
- The full static gate before auth was green. Full static/runtime/browser gates after auth are still
  required.
- Browser verification can take roughly 25 minutes. Silence while the process runs is not a hang;
  poll the running cell and provide tiny status updates.

## Decision Memory

- Repair security truth even when it invalidates a previous green verifier.
- A passing legacy test is not evidence if it requires insecure behavior.
- Replacement proof gets no automatic percentage increase.
- Hosted operational repair is not release promotion.
- A Preview Worker is not a Production Worker claim.
- A stateless Vercel contract origin is not the stateful backend stack.
- Free-only policy remains binding; paid capability does not satisfy a free gate.

## Next-Action Memory

The next agent should finish auth hardening, not begin Vectorize, Agent Pool, MCP write, GHCR, or a
new UI slice first. Specifically:

1. finish legacy verifier/document cleanup;
2. update ADR and truth mirrors;
3. run manifest/static/runtime/browser gates;
4. stage auth files precisely;
5. commit and push;
6. build/verify RC5;
7. then resume the broader MARKET_READY queue.

## Owner-Wall Memory

Hard walls are payment/credit card, password-account creation, CAPTCHA, and secret disclosure or
commit. OAuth production identity also needs Owner-configured credentials/callback. Record those
walls honestly, continue all other autonomous work, and never manufacture evidence.
