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
`.phase1-artifacts/external-gate-audit-20260713-122529.json`

Status: `blocked`

Missing or failed gate: `vercel_backend_origin_health`.

The token/origin-injected audit `20260713-125413` reported `verified`, but it is retained
only as a non-current owner-assisted candidate and cannot replace the reproducible standard.
The canonical standard allows no production-deploy claim while the consolidated Vercel
MCP/LLM origin health probes fail.

`production_deploy_claim_allowed=false`; no production rollout or release promotion occurred.

## Frontend Provider Boundary

The active frontend no longer contains direct Neon, Cloudflare Workers AI/D1/Vectorize,
or GitHub Store execution paths. Mutation and persistence routes cross only the configured
Agent API, LLM Gateway, or MCP Gateway boundaries and fail closed when unavailable. The
stateless hosted wrappers remain read-only. The local T4 report is
`.codex/runs/CURRENT/master-goal/t4/frontend-provider-boundary/report.json`; it is integrated
into `npm run verify` and was followed by green runtime, browser, lint, and production-build
checks. This is DEV-ONLY until a new source-bound hosted proof is recorded and does not
activate a live provider or close a production gate.

## Current Hosted Frontend Proof

`frontend-hosted-current-proof-v1` binds the active Vercel frontend to an immutable
deployment and source commit. Real Google Chrome `148.0.7778.96` opened all 22 canonical
routes through 44 command-palette clicks at desktop `1440x960` and mobile `390x844`.
Overflow failures, visible not-found states, and console errors were zero. The verifier
also requires HTTP `200` and byte-identical root and workspace-wiring content between the
immutable deployment and Production Alias. Evidence is under
`.codex/runs/CURRENT/master-goal/frontend/hosted-22x2-0555b0bd-chrome`.

This closes the Frontend / Next.js layer proof only. It does not close Hosted Agent API,
MCP Gateway, LLM Gateway, registry, release-promotion, or full-platform production gates.

## Current Hosted Backend Contract Origin

`backend-hosted-current-proof-v1` binds the active Vercel backend deployment to source
`e1a3ec1f7942e54058e56915f4fb29636c5c4f3e` and archive SHA-256
`c1106b6cb2a36f643664a3f428483685f27231f8e0128f5581925ab2196ea1cb`.
Authenticated read-only Vercel metadata proves READY state and Production Alias assignment;
the immutable URL is SSO-protected. The public alias proves `overall=84`, `P4=100`,
integrity `verified`, external gates `5/6 action_required`, canonical summary `blocked`,
MCP/LLM `healthy`, expected stateless Agent API `degraded`, and a fail-closed HTTP 503
response for mutation-shaped requests.

This proves the stateless read-only Contract Origin only. It does not prove the stateful
Docker stack, persistent PostgreSQL/Redis workers, registry publication, release promotion,
or a full-platform production release.

## Local Production Candidate Preparation

Candidate `prod-candidate-2026-07-20-local-rc2` is locally verified against source
commit `1d8304456a6a95a2a05de65cf0d576ee68c20733`. Six production targets were built
only from a committed Git archive; local image IDs, OCI labels, embedded source hashes,
the frontend build ID, the read-only API contract, and a real Diagnostics Chromium click
passed. Runtime-only verification cannot overwrite the full-browser artifact. The hosted
boundary passes technically and keeps promotion ineligible under the blocked canonical
summary. P5 remains 68 and Overall remains 84.

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
