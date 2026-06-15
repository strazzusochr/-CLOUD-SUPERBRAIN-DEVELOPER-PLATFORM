# TRAE AI — RESUME / CONTINUE PROMPT
# Project: -CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM
# Use when: Trae stopped, aborted, crashed, ran out of context, or "just quit".
# Generated: 2026-06-15

> COPY THIS ENTIRE FILE as the next prompt whenever Trae stopped before the project was
> release-ready. It makes Trae re-orient itself and continue EXACTLY where it left off,
> without redoing finished work and without losing the mission. Assume NO memory of the
> previous session — reconstruct state from the repo, then keep going.

═══════════════════════════════════════════════════════════════════════════════
## 0. WHAT HAPPENED / WHAT TO DO
═══════════════════════════════════════════════════════════════════════════════

You were autonomously completing this project under `TRAE_FINAL_AUTONOMOUS_PROMPT.md` and you
stopped before the SUCCESS DECLARATION (§10 there) was true. Do NOT restart from scratch and do
NOT re-do completed pages. Re-derive the current state from the repository, find the exact last
point, and CONTINUE the relentless loop until the project is release-ready.

The full mission, the 7 layers, the 22 pages, the constraints, and the verifier pipeline are all
defined in `TRAE_FINAL_AUTONOMOUS_PROMPT.md`. That file is still binding. This prompt only tells
you how to RE-ENTER the loop safely.

═══════════════════════════════════════════════════════════════════════════════
## 1. RE-ORIENT — reconstruct state before touching anything (do all of this)
═══════════════════════════════════════════════════════════════════════════════

1. Read `TRAE_FINAL_AUTONOMOUS_PROMPT.md` in full — that is your mission, rules, and DoD.
2. Read `PROJECT_STATE.md` — especially "NÄCHSTER KONKRETER ARBEITSSCHRITT" and
   "ZULETZT ABGESCHLOSSEN". This is your last recorded checkpoint.
3. Read `docs/project-progress.manifest.json` and `docs/verification-register.md` — the last
   verified truth. Trust verified entries; distrust anything not backed by a verifier.
4. Inspect what is actually on disk (the code is the source of truth, not your memory):
   ```powershell
   git status
   git log --oneline -15
   git diff --stat
   ```
5. Bring the DEV stack up and confirm it is healthy:
   ```powershell
   docker compose -f docker-compose.dev.yml up -d --build
   docker compose -f docker-compose.dev.yml ps
   ```
6. Run a fast read-only status sweep to see what is currently GREEN vs RED:
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1
   powershell -ExecutionPolicy Bypass -File scripts\verify-workspace-pages-layer-map.ps1
   npm run verify:browser
   ```
   The 22-page browser proof tells you exactly which pages already pass and which still fail.

═══════════════════════════════════════════════════════════════════════════════
## 2. FIND THE LAST POINT — build the resume checklist
═══════════════════════════════════════════════════════════════════════════════

From the sweep in §1, produce (in your head / a short note) the list of OPEN items:

- Which of the 22 pages do NOT yet pass all of §5 (Definition of Done) in the main prompt.
- For each open page, which of the 6 vertical stages (UI / API / Data / Verification / Deploy /
  Safety) are missing.
- Which verifiers in §7 of the main prompt are currently RED.
- Any half-finished edit in `git diff` — finish or revert it cleanly first (no dangling code).

The single "last point" = the first open item in the dependency-aware order from §8 of the main
prompt. Start there.

═══════════════════════════════════════════════════════════════════════════════
## 3. CONTINUE — re-enter the relentless loop (do not stop until release-ready)
═══════════════════════════════════════════════════════════════════════════════

Resume the loop from `TRAE_FINAL_AUTONOMOUS_PROMPT.md` §8:
PLAN → CODE → WIRE → TEST → FIX → DOCUMENT → NEXT.

- Work the first open item to fully green (all of §5 + its verifiers), then the next, and so on.
- Never re-do a page that already passes. Never fake-pass a red verifier.
- On any failure: read the error, fix root cause, re-run. Do not stop.
- A single owner-gated stop-gate action (deploy / `main` push / registry publish / secret / live
  provider) blocks only THAT action — skip it, record it, and keep finishing everything else.
- After each real proof, update `PROJECT_STATE.md`, `docs/verification-register.md`, and the
  manifest so the NEXT resume (if any) starts from an accurate checkpoint.

Keep going until the SUCCESS DECLARATION (§10 of the main prompt) is literally true: all 22 pages
pass §5, the full verifier pipeline is green, manifest verified, gitleaks clean, 22 browser
screenshots pass, and the project is release-ready (production deploy left as the only owner gate).

═══════════════════════════════════════════════════════════════════════════════
## 4. ANTI-STALL RULES (so you do not "just quit" again)
═══════════════════════════════════════════════════════════════════════════════

- Do not end your turn with the job unfinished unless you hit a TRUE hard blocker you cannot solve
  in code. If you must stop, first write into `PROJECT_STATE.md`: the exact open item, the exact
  failing command + error, and the next safe command — so the next resume is instant.
- "I think I'm done" is not enough — verify against §10 of the main prompt with real commands.
- If context runs low: write the current checkpoint to `PROJECT_STATE.md` FIRST, then continue or
  hand off. Never lose the resume point.
- If a verifier is flaky/transient (502/503/504, timeout): retry, then diagnose — do not abandon.
- If unsure what to do next: re-read `PROJECT_STATE.md` + run the §1 sweep again. The answer is the
  first red item. Then act.

— END OF RESUME PROMPT —
