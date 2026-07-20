# Cloud Superbrain Release Status

Updated: 2026-07-20

Status: **not released**. This repository has a healthy local development runtime, a
verified Vercel frontend deployment, and a reachable stateless read-only Backend Contract
Origin. It does not yet have the stateful hosted Docker-stack proof or Owner approvals
required for a full-platform production release or release promotion.

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
| Horizontal | P0 100, P1 100, P2 86, P3 44, P4 100, P5 68, P6 90 |
| Vertical | Frontend 100, Orchestrator 100, Agent Pool 68, LLM 54, MCP 55, Memory 73, Observability 99 |
| Project progress integrity | `verified` |
| Canonical workspace pages | 22/22 local and 22/22 hosted in real Google Chrome at desktop and mobile |
| Docker services | 10/10 healthy in the latest local check |
| Canonical secret scan | gitleaks pass, no leaks found |
| Deployment | Vercel frontend and read-only backend contract origin verified; full-platform production release not performed |

Percentages come only from `docs/project-progress.manifest.json` and must match
`GET /api/v1/project/progress` plus `GET /api/v1/project/progress/integrity`.

## External Gate Status

Canonical reproducible standard-bootstrap audit:
`.phase1-artifacts/external-gate-audit-20260720-191532.json`

Status: `blocked`

Missing or failed gates: `hosted_agent_api_contracts`,
`github_branch_protection_current_verify`, `vercel_backend_origin_health`, and
`fly_live_budget_check`.

The token/origin-injected audit `20260713-125413` reported `verified`, but it is retained
only as a non-current owner-assisted candidate and cannot replace the reproducible standard.
The canonical standard allows no production-deploy claim while hosted contracts,
branch-protection verification, Vercel backend-origin health, and Fly budget proof remain open.

`production_deploy_claim_allowed=false`; no production rollout or release promotion occurred.

## Frontend Provider Boundary

The active frontend no longer contains direct Neon, Cloudflare Workers AI/D1/Vectorize,
or GitHub Store execution paths. Mutation and persistence routes cross only the configured
Agent API, LLM Gateway, or MCP Gateway boundaries and fail closed when unavailable. The
stateless hosted wrappers remain read-only. The local T4 report is
`.codex/runs/CURRENT/master-goal/t4/frontend-provider-boundary/report.json`; it is integrated
into `npm run verify` and was followed by green runtime, browser, lint, production-build,
and T1 source-bound Production checks. T4 does not activate a live provider; the scoped
operational deploy remains distinct from release-candidate promotion.

## Current Hosted Frontend Proof

`frontend-hosted-current-proof-v1` binds Vercel Production deployment
`dpl_9KPqcjNPnV9irpJ9W8tyjff8LMbX` to source
`21913f8c3ef13949ca962980c143e757ca87a7cc` and archive SHA-256
`314bd1d9c7830dc5ac9077398025fed4ab48041b31fefae491916e838d5f7080`.
Real Google Chrome `148.0.7778.96` opened all 22 canonical routes through 44
command-palette clicks at desktop `1440x960` and mobile `390x844`. Overflow failures,
overlay collisions, visible not-found states, and console errors were zero. The verifier
also requires exact Vercel metadata, byte-identical immutable/Alias root and workspace
wiring, and HTTP `200` for 32 read endpoints including all eight former HTTP-500 routes.
Evidence is under `.codex/runs/CURRENT/master-goal/production/t1-21913f8c`.

This is a scoped operational Production repair, not release-candidate promotion. It does
not close the stateful Agent API, registry, live-provider, or full-platform release gates.

## Current Hosted Backend Contract Origin

`backend-hosted-current-proof-v1` binds Vercel Production deployment
`dpl_AQaBJxdQwHLcQKid8xYXkNJ3wva2` to the same source and archive hash. Authenticated
read-only Vercel metadata proves READY state, target `production`, and Alias assignment.
The immutable URL remains deployment-protected; public Alias reads prove the source-bound
snapshot at `overall=84`, `P4=100`, integrity `verified`,
external gates `5/6 action_required`, summary `blocked`, MCP/LLM `healthy`, expected stateless Agent API `degraded`,
and a fail-closed application HTTP 503 response for mutation-shaped requests.

That `5/6` value is embedded in the deployed source commit. The current local canonical
standard is tracked separately by audit `20260720-191532` and reports `5/6`.

This proves the stateless read-only operational Production Contract Origin only. It does
not prove the stateful Docker stack, persistent PostgreSQL/Redis workers, registry
publication, release-candidate promotion, or a full-platform production release.

## Local Production Candidate Preparation

Candidate `prod-candidate-2026-07-20-local-rc2` is locally verified against source
commit `1d8304456a6a95a2a05de65cf0d576ee68c20733`. Six production targets were built
only from a committed Git archive; local image IDs, OCI labels, embedded source hashes,
the frontend build ID, the read-only API contract, and a real Diagnostics Chromium click
passed. Runtime-only verification cannot overwrite the full-browser artifact. The hosted
boundary passes technically and keeps promotion ineligible under the blocked canonical
summary. The read-only hosted response is matched to its deployment snapshot, while only
the current local canonical summary controls promotion. P5 remains 68 and Overall remains 84.

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
- No stateful full-backend rollout, full-platform release, registry push, release
  promotion, live provider call, live MCP write, or secret output is claimed.
