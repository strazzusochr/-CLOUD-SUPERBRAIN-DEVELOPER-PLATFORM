# Gate-Opening Deep Analysis

Updated: 2026-07-12

This document describes the current fail-closed gate truth. It supersedes the older
70/100 percent and Hetzner-era analysis that previously occupied this path.

## Current Truth

`docs/project-progress.manifest.json` is the progress authority. The local Agent API
serves the same values and `GET /api/v1/project/progress/integrity` reports `verified`.

| Phase | Percent | Layer | Percent |
| --- | ---: | --- | ---: |
| P0 Reboot & Goal Lock | 100 | L1 Frontend | 97 |
| P1 Foundation Runtime | 100 | L2 Orchestrator | 99 |
| P2 Core Runtime | 86 | L3 Agent Pool | 68 |
| P3 Product & Security | 42 | L4 LLM Gateway | 54 |
| P4 Integration & Hardening | 99 | L5 MCP Gateway | 55 |
| P5 Release Readiness | 67 | L6 Memory | 72 |
| P6 Scale & 3D Platform | 80 | L7 Observability | 99 |
| **Overall** | **82** | | |

Localhost is `DEV-ONLY`. It proves the Docker runtime, API contracts, and browser
behavior, but it cannot prove hosted staging, cloud origins, production readiness, or
release promotion.

## External Gate Truth

The latest direct no-token audit is
`.phase1-artifacts/external-gate-audit-20260712-145800.json`. It is `blocked` on:

- `hosted_agent_api_contracts`
- `github_branch_protection_current_verify`
- `vercel_backend_origin_health`
- `fly_live_budget_check`

It also reports `production_deploy_claim_allowed=false`. The earlier private read-only
bootstrap audit `20260712-000113` and the custom process-input audit `20260711-215936`
are useful provenance, but neither replaces the latest standard direct run.

The local `go-live-readiness-v1` surface therefore remains
`status=blocked_external_gates`. Runtime markers, environment-variable presence, a
frontend-only Vercel URL, or temporary origin rewrites cannot independently close these
external proofs.

## What Is Still Missing

### Evidence-backed implementation

- P2, P3, P5, and P6 still have uncredited or unimplemented rubric slices.
- Agent Pool, LLM Gateway, MCP Gateway, and Memory still have substantial local and/or
  hosted runtime work before they can reach 100 percent.
- Phase 6 has real client-runtime, interaction, scene-state, performance, and full
  camera/lighting proof at 40 percent. Accessibility, gameplay, asset, save,
  multiplayer, and scale slices remain open.

### External read-only proof

- A reachable HTTPS hosted Agent API and matching Vercel backend origins.
- Current GitHub protected-main verification using the owner-approved verify-only path.
- Current Fly.io budget proof under the 20 EUR/month ceiling.
- A fresh standard external-gate audit after those inputs are available.

### Owner-only mutation and promotion

The following remain stop gates and require explicit Owner approval at the time of use:

- token use or scope expansion;
- Vercel environment writes;
- Fly app, machine, volume, secret, or deployment writes;
- GHCR image publication;
- GitHub branch-protection writes, workflow dispatch, or main-branch changes;
- production deployment or release promotion;
- live LLM provider activation or live MCP write activation.

## Safe Sequence

1. Continue bounded local implementation with code, verifier, browser/runtime proof, and
   truth-document updates.
2. Keep the standard external audit blocked until the real HTTPS origins and verify-only
   credentials are available under an explicit Owner gate.
3. Re-run hosted browser, backend-origin, branch-protection, budget, and secret-scan
   evidence against the exact approved candidate commit.
4. Prepare immutable candidate and rollback evidence without promoting it.
5. Request a separate Owner decision for registry publication, deployment, and release
   promotion.

## Permanent Safety Boundaries

- Secret output never opens. Redaction and no-secret-output rules are permanent.
- Force-push and direct main writes remain forbidden.
- Localhost never closes hosted or production gates.
- A green contract or environment presence is not a live external proof.
- No percentage reaches 100 without implementation, tests, runtime evidence, browser
  evidence where applicable, verifier coverage, and synchronized documentation.

## Verdict

The project is locally healthy and evidence-backed at 76 percent overall, not complete
and not released. Four direct external gates remain blocked, production deployment is
not allowed, and substantial phase/layer work remains. The next safe work is local,
bounded, verifier-backed implementation; external mutations and promotion stay Owner-only.
