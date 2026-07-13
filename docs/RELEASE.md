# Cloud Superbrain Release Status

Updated: 2026-07-13

Status: **not released**. This repository has a healthy local development runtime and a
verified Vercel frontend deployment, but it does not yet have the hosted backend proof or
Owner approvals required for a full-platform production release or release promotion.

## Local Development Runtime

```powershell
docker compose -f docker-compose.dev.yml up -d
npm run verify
npm run verify:runtime
npm run verify:browser
```

Local URL: `http://localhost:8081`

Localhost is `DEV-ONLY`. It may prove deterministic runtime, API, audit, and browser
behavior, but it cannot close hosted staging, backend-origin, production, or release
gates.

## Current Evidence Snapshot

| Scope | Current verified value |
| --- | --- |
| Overall progress | 84 percent |
| Horizontal | P0 100, P1 100, P2 86, P3 43, P4 99, P5 68, P6 90 |
| Vertical | Frontend 100, Orchestrator 100, Agent Pool 68, LLM 54, MCP 55, Memory 72, Observability 99 |
| Project progress integrity | `verified` |
| Canonical workspace pages | 22/22 local and 22/22 hosted in real Google Chrome at desktop and mobile |
| Docker services | 10/10 healthy in the latest local check |
| Canonical secret scan | gitleaks pass, no leaks found |
| Deployment | Vercel frontend and read-only backend contract origin verified; full-platform production release not performed |

Percentages come only from `docs/project-progress.manifest.json` and must match
`GET /api/v1/project/progress` plus `GET /api/v1/project/progress/integrity`.

## External Gate Status

Latest read-only audit:
`.phase1-artifacts/external-gate-audit-20260713-122705.json`

Status: `verified`

Missing or failed gates: none.

Hosted Agent API, all three explicitly configured consolidated Vercel backend origins,
verify-only branch protection, GHCR, canonical gitleaks, and Fly budget checks pass.
Existing credentials were loaded only into the audit process; no values were printed or
persisted and the audit performed no provider mutation.

`production_deploy_claim_allowed=true` is permission from the gate bundle, not evidence
that a production rollout or release promotion occurred.

## Current Hosted Frontend Proof

`frontend-hosted-current-proof-v1` binds the active Vercel frontend to an immutable
deployment and source commit. Real Google Chrome `148.0.7778.96` opened all 22 canonical
routes through 44 command-palette clicks at desktop `1440x960` and mobile `390x844`.
Overflow failures, visible not-found states, and console errors were zero. The verifier
also requires HTTP `200` and byte-identical root and workspace-wiring content between the
immutable deployment and Production Alias. Evidence is under
`.codex/runs/CURRENT/master-goal/frontend/hosted-22x2-eabdf208-chrome`.

This closes the Frontend / Next.js layer proof only. It does not close Hosted Agent API,
MCP Gateway, LLM Gateway, registry, release-promotion, or full-platform production gates.

## Local Production Candidate Preparation

Candidate `prod-candidate-2026-07-13-local-rc1` is locally verified against source
commit `c451fa8ff2b631685ad07ebcfcf4dc4a5b418e81`. Six production targets were built
only from a committed Git archive; local image IDs, OCI labels, embedded source hashes,
the frontend build ID, the read-only API contract, and a real Diagnostics Chromium click
passed. This raises P5 from 67 to 68 while Overall remains 84.

The GHCR tag set is planned and unpublished. Hosted parity, Owner approval, registry
publication, production deploy, and release promotion remain false.

## Candidate And Release Requirements

A release claim requires all of the following against the exact approved immutable
candidate:

1. Complete and credited phase/layer work according to the binding rubric.
2. Green static, runtime, browser, progress-integrity, and canonical gitleaks checks.
3. Reachable HTTPS hosted Agent API, MCP Gateway, and LLM Gateway origins.
4. Fresh hosted browser and API proof against the configured staging URL.
5. Current verify-only branch-protection proof.
6. Current Fly budget proof within the 20 EUR/month ceiling.
7. Immutable source/image provenance and tested rollback evidence.
8. Explicit Owner review of commit scope, permissions, budget, rollback, and promotion.
9. Separate Owner authorization for registry publication, deployment, and release
   promotion.

## Stop Gates

Without explicit Owner approval, or outside an already recorded scope-specific approval, do not:

- use or expand provider credentials;
- push container images or publish registry artifacts;
- mutate Vercel, Fly, GitHub, Grafana, or production database state;
- dispatch production workflows;
- write or merge to `main`;
- enable live LLM provider calls or live MCP writes;
- deploy to production or promote a release.

## Current Non-Claims

- The hosted frontend alone is not hosted backend proof.
- Temporary environment overrides do not replace the standard external audit.
- A green local runtime is not production readiness.
- No hosted backend production deployment, full-platform release, registry push, release
  promotion, live provider call, live MCP write, or secret output is claimed.
