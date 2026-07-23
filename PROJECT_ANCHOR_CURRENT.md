# Cloud Superbrain Project Anchor

Anchor ID: `cloud-superbrain-anchor-2026-07-23T20-54-57+02-00-session8-s1-green-pre-rc8`

Status: `ACTIVE_RESUME_POINT`

Workspace: `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`

Branch: `claude/cloud-superbrain-analysis-127d2e`

Committed runtime reference before S1: `6c344b37f2cef21d952c1f2b5235ae6c4c36dbf9`

Detailed handoff: `CODEX_UEBERGABE_2026-07-23-SESSION7.md`

## Purpose

Exact resume point after the S1 Agent-Pool UI/verifier slice passed the full serial static,
runtime, and browser gates. S1 is ready for an explicit-file commit and branch push. The current
local production candidate remains RC7 until RC8 is built and verified from the new committed
source. This anchor is a resume snapshot, not a progress authority.

## Required Resume Order

1. Read `CODEX_UEBERGABE_2026-07-23-SESSION7.md` completely.
2. Read the active goal objective attachment and `AGENTS.md` start-protocol documents.
3. Read `PROJECT_STATE.md`, `AI_HANDOFF.md`, `docs/verification-register.md`, and
   `docs/project-progress.manifest.json`.
4. Set `TEMP` and `TMP` to `D:\_sb_tmp` before every verifier.
5. Inspect `git status --short`; preserve every foreign dirty file.
6. Continue at the exact next step below. Do not restart the project or overwrite foreign work.

## Current Canonical Progress

- Overall: `86%`
- Horizontal: `P0 100 | P1 100 | P2 100 | P3 44 | P4 100 | P5 68 | P6 90`
- Vertical: `Frontend 100 | Orchestrator 100 | Agent Pool 69 | LLM 55 | MCP 56 | Memory 90 | Observability 100`
- `MARKET_READY: false`
- S1 receives no percentage credit.

## S1 Verified Truth

- Canonical UI: `/agents`.
- Runtime contracts: `autonomous-agent-roster-v1`, `autonomous-master-plan-v1`,
  `autonomous-coding-team-v1`, and `autonomous-task-dispatch-v1`.
- Visible parity: 14 persisted roster roles; 7 phases; 7 layers; 5 operating-core roles;
  3 dispatch endpoints; 5 UUIDv4-bound coding-team members with mappings and queue state.
- Strict frontend parsing fails closed on contract/source/evidence/binding drift.
- Focused roster, master-plan, coding-team, and release-workflow PlanOnly verifiers passed.
- Frontend lint passed; production build passed `21/21`.
- `npm run verify`, `npm run verify:runtime`, and `npm run verify:browser` passed serially.
- Browser responsive proof passed 22 routes x 2 viewports = 44 clicks.
- Runtime log SHA-256:
  `B2C239B91BB9C41852A862EBEB3D8BAF12353E98330BA424A68A06EF8FE40541`.
- Browser log SHA-256:
  `CB720B156EB6248BB448181458CF569A1AA9D1A14013AE939275906BD5D644A5`.
- Docker is `10/10 healthy`.
- PostCSS exact override is `8.5.12`; npm audit reports zero vulnerabilities.
- Fresh runtime cloud read without Owner inputs remained `5/8` providers and `4/7` layers.

## Exact Next Step

1. Explicitly stage only S1-owned implementation, verifier, manifest, RC6/RC7 artifact, and
   canonical truth-mirror files.
2. Inspect the staged diff and run the staged secret scan.
3. Commit and push only `claude/cloud-superbrain-analysis-127d2e`.
4. Build RC8 from the new committed SHA with rollback bound to RC7
   `6c344b37f2cef21d952c1f2b5235ae6c4c36dbf9`.
5. Verify RC8 locally with the focused candidate and current-candidate Chromium gates.
6. Run the final MARKET_READY audit and produce the exact OWNER-BLOCKED packet.

## Current Candidate Before RC8

- Release: `prod-candidate-2026-07-23-local-rc7`
- Source: `6c344b37f2cef21d952c1f2b5235ae6c4c36dbf9`
- Rollback: RC6 at `60d48868fbcad29d010d348916b261760d6a74ed`
- Candidate report SHA-256:
  `E3F6106A636BD5F6FC059A5F8B9D75B36E9DB92ED4F2A480780A2775FE03842C`
- Verification SHA-256:
  `4227B5DCEB3AAACFBE5F8AC1863A1D52FDD91DD325F9FE797AF24CFDD5BE6957`
- `candidate_technical=true`
- `runtime_source_parity=true`
- `promotion_eligible=false`
- DEV-ONLY; hosted proof still blocked.

## Explicit Non-Claims

- `autonomous_release_workflow_verified` means parser plus PlanOnly validation only; no workflow
  execution, push, publication, or release occurred.
- Persisted roster does not mean Codex Desktop task persistence.
- Local dispatch does not prove hosted or autonomous rollout.
- `live_provider_calls=false`
- `live_mcp_writes=false`
- `model_downloads=false`
- `production_deploy=false`
- `production_rollout_claimed=false`
- `secret_output=false`

## Owner Walls

- Production OAuth identity and credential configuration.
- Cloudflare Vectorize edit scope, architecture approval, and hosted semantic-search proof.
- Fly.io or Scale payment/billing activation.
- GHCR publication and release promotion.
- Live MCP writes and live agent/provider activation.
- Password, CAPTCHA, secret disclosure, or permission expansion.

## Foreign Dirty Files: Never Stage, Revert, Or Rewrite

- `CODEX_ZIELVERFOLGUNG_KURZ.md`
- `apps/frontend/next-env.d.ts`
- `.codex/cache/`
- `.codex/environments/`
- `.codex/tmp/`
- `.playwright-cli/`
- all pre-existing untracked goal, handoff, screenshot, Python-environment, agent-api core/test,
  model-registry, and local-helper files unless ownership is independently re-established.

## Non-Negotiable Rules

- No `git add -A`.
- No fake completion or duplicate percentage credit.
- No secret values in output, files, reports, logs, commits, or screenshots.
- No main push, force push, registry publication, production deployment, or release promotion.
- No parallel verifier, Playwright, or Docker-build execution.
- Localhost evidence label: `DEV-ONLY; hosted proof still blocked`.
- Keep working on autonomous items; stop only at a real Owner gate.
