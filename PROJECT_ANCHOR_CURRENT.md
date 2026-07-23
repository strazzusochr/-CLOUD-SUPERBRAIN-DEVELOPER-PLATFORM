# Cloud Superbrain Project Anchor

Anchor ID: `cloud-superbrain-anchor-2026-07-23T21-24-18+02-00-session8-rc8-verified`

Status: `ACTIVE_RESUME_POINT`

Workspace: `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`

Branch: `claude/cloud-superbrain-analysis-127d2e`

Committed and pushed RC8 source: `3bd216f0296afb3bd7ad94e44b6540c6201ab845`

Detailed handoff: `CODEX_UEBERGABE_2026-07-23-SESSION7.md`

## Purpose

Exact resume point after the S1 Agent-Pool UI/verifier slice passed the full serial static,
runtime, and browser gates, was explicitly committed and pushed, RC8 was rebuilt and verified,
and the final MARKET_READY audit proved there are no remaining autonomous-open items. All seven
below-100 cells now have exact Owner actions in `docs/runtime-state/owner-input-manifest.json`.
This anchor is a resume snapshot, not a progress authority.

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

1. Do not raise percentages or activate a gate without the corresponding O1-O6 Owner input.
2. After an Owner input changes, run its named verifier from
   `docs/runtime-state/owner-input-manifest.json`.
3. Re-run the full aggregate finish line only after every affected cell has new evidence.

## Current Candidate

- Release: `prod-candidate-2026-07-23-local-rc8`
- Source: `3bd216f0296afb3bd7ad94e44b6540c6201ab845`
- Rollback: RC7 at `6c344b37f2cef21d952c1f2b5235ae6c4c36dbf9`
- Candidate report SHA-256:
  `303F75382936576F1D36A2A45C2C388DC5D3964ED1C2AA1B6AA98B2AB8DE13B6`
- Verification SHA-256:
  `0E1A4B94EE2AC2B81435A0903B7954115B89F5710AF1BAC48D6BFF98BDBE8800`
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

## Final Audit

- `owner-input-matrix=PASS`
- Covered cells: `phase_3`, `phase_5`, `phase_6`, `layer_3`, `layer_4`, `layer_5`, `layer_6`
- Autonomous-open items: none
- Report SHA-256:
  `C32B68F42BDB4E4043492AFEEDEDD28AA219E07967D38819529BD6EE1868A01A`
- `MARKET_READY:false`
- Final packet: `master-goal-final.md`

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
