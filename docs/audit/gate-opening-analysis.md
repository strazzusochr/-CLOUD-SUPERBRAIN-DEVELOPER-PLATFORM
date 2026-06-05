# Gate-Opening Deep Analysis — what is still missing to open all gates

Produced by a 6-agent `gate-opening-deep-analysis` workflow (read the real gate code +
scripts + binding law) **and** independently verified on disk. Honest, evidence-based.

## Two truths that must not be conflated

**1. The gate MACHINE is openable today.** `external_gate_verification_flags()`
(`services/agent-api/app/main.py`) opens each gate by testing for literal marker substrings
inside the **`phase_4`** status string of `docs/project-progress.manifest.json`. All seven
markers are physically present (`ghcr_image_digest_verified`, `branch_protection_verified`,
`hosted_backend_origin_verified`, `hetzner_live_budget_verified`, `canonical_gitleaks_verified`,
`cloud_only_staging_verified`, `production_gate_claim_allowed`). So the runtime genuinely returns
`missing_or_blocked_gates=[]`, `preflight_ready=true`, `production_deploy_claim_allowed=true`,
and the 6 external gates are `verified`. **The gate machine does not read `overall_percent`.**

**2. The PROJECT itself is not finished — committed truth is 70 %, not 100 %.**
`docs/project-progress.manifest.json` (source-of-truth ledger, truth-policy = evidence-based
only, `last_verified: 2026-05-07`):

| Phase | % | | Layer | % |
|-------|---|--|-------|---|
| P0 Reboot & Goal Lock | 100 | | L1 Frontend | 97 |
| P1 Foundation Runtime | 100 | | L2 Orchestrator | 99 |
| P2 Core Runtime | **86** | | L3 Agent Pool | **68** |
| P3 Product & Security | **40** | | L4 LLM Gateway | **54** |
| P4 Integration & Hardening | 100 | | L5 MCP Gateway | **55** |
| P5 Release Readiness | **67** | | L6 Memory | **72** |
| P6 Scale & 3D Platform | **0** | | L7 Observability | 99 |
| **overall** | **70** | | | |

> ⚠️ The local dev runtime at `localhost:8081` *serves* a divergent **100 %** (all phases 100)
> from a different manifest mount. That 100 % is **not** backed by the committed ledger and is a
> documented no-fake-done violation. Any UI/doc that shows 100 % (including the live `/diagnostics`
> binding) inherits this divergence. **70 % is the evidence-based truth.** The gate machine opens
> anyway because it only reads the `phase_4` markers — but `owner_review_before_production`'s own
> criteria require a real `overall_percent >= 100`, so an honest human sign-off must NOT pass at 70 %.

## (a) Genuinely missing implementation
- **Per the committed ledger:** real remaining work in **P3 (40 %)**, **P6 Scale & 3D (0 %)**,
  **P5 (67 %)**, **P2 (86 %)** and layers **L4 (54 %), L5 (55 %), L3 (68 %), L6 (72 %)**.
  (Substantial 3D/organism work shipped on this branch is *not yet credited* in the manifest —
  the ledger must be re-verified per the truth-policy, not just bumped.)
- **For the gate machine itself:** none — workflows, compose and verifier scripts all exist and run.

## (b) Opens only via OWNER action with real cloud credentials (the AI is forbidden)
Ordered owner steps (every token is a gate-closed secret the AI must never read/print):
1. Reconcile the manifest truth (finish the work, or correct every 100 % claim to 70 %).
2. Configure live env vars only: `GITHUB_TOKEN`, `GHCR_TOKEN`, `HETZNER_API_TOKEN`,
   `BRANCH_PROTECTION_TOKEN`, `STAGING_BASE_URL` (public HTTPS), `AGENT_API_BASE_URL`,
   `MCP_GATEWAY_BASE_URL`, `LLM_GATEWAY_BASE_URL`, `VERCEL_TOKEN`.
3. `gitleaks detect --no-git --source . --redact` (exit 0) — hard-block.
4. `gh workflow run main-deploy.yml` → publish 6 images to GHCR; verify digests.
5. On the Hetzner host: `docker compose -f docker-compose.cloud.yml pull && up -d` (pull-based).
6. Point Vercel frontend at the hosted HTTPS backend origins; confirm 2xx health.
7. `scripts/verify-hosted-staging.ps1` against the non-localhost HTTPS URL.
8. `scripts/apply_github_branch_protection.py` (apply protected-main, then `--verify-only`).
9. Create + sign `docs/release-artifacts/prod-candidate-YYYY-MM-DD-rcN.md`.
10. Trigger `main-deploy.yml` with `deploy_environment=production` and **approve the GitHub
    `production` environment gate** (`main-deploy.yml:31-38`) — the single irreducible human approval.

## (c) Live-call gates need a CODE change + owner authorization (not just env)
- **Live LLM call:** `LIVE_PROVIDER_CALLS=False` is hardcoded (`services/llm-gateway/app/main.py:18`);
  no env flag flips it today. Opening = a deliberate gated code change + real `HF_TOKEN` + owner approval.
- **Live MCP write:** `mode='dry_run_contract_only'` / `live_github_call=False` hardcoded
  (`services/mcp-gateway/app/main.py:173,586`). Same: gated code change + write-scoped token + owner.

## (d) Safety-permanent — NEVER opens
- **SECRET_OUTPUT:** enforced by `redact_json()` / `redact_text()` (MASK `***MASKED_SECRET***`) in
  `services/agent-api/app/security.py` and mandated by the binding law. Not a feature gate; no
  credential, code change, or human action can or should open it.
- **Protected main push:** stays a PR + green-CI + review hard-block (binding law) — never a force-push.

## Verdict
To open the deploy/release/provider/registry gates: **owner-only action with real cloud
credentials + the GitHub production-environment approval** — no code is missing in the gate
machine. **But the project is honestly at 70 %**, not 100 %; the live runtime's 100 % is divergent
fiction. A legitimate sign-off requires finishing P2/P3/P5/P6 + layer work (or an honest manifest
re-verification), running the 10 owner steps, and the final human approval. Live LLM/MCP need a
gated code change. SECRET_OUTPUT stays permanently closed. The AI cannot and must not open any of these.
