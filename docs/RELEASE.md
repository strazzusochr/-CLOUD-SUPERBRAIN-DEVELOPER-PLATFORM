# Cloud Superbrain Release Status

Updated: 2026-07-12

Status: **not released**. This repository has a healthy local development runtime and
hosted frontend evidence, but it does not yet have the external proof or Owner approvals
required for production deployment or release promotion.

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
| Overall progress | 82 percent |
| Horizontal | P0 100, P1 100, P2 86, P3 42, P4 99, P5 67, P6 80 |
| Vertical | Frontend 97, Orchestrator 99, Agent Pool 68, LLM 54, MCP 55, Memory 72, Observability 99 |
| Project progress integrity | `verified` |
| Canonical workspace pages | 22/22 local browser-functional |
| Docker services | 10/10 healthy in the latest local check |
| Canonical secret scan | gitleaks pass, no leaks found |
| Production deployment | blocked / not performed |

Percentages come only from `docs/project-progress.manifest.json` and must match
`GET /api/v1/project/progress` plus `GET /api/v1/project/progress/integrity`.

## External Gate Status

Latest standard direct audit:
`.phase1-artifacts/external-gate-audit-20260712-145800.json`

Status: `blocked`

- `hosted_agent_api_contracts`
- `github_branch_protection_current_verify`
- `vercel_backend_origin_health`
- `fly_live_budget_check`

`production_deploy_claim_allowed=false`. Earlier private/custom audits are provenance,
not the current standard release truth.

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

Without explicit Owner approval, do not:

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
- No production deployment, registry push, release promotion, live provider call, live
  MCP write, or secret output is claimed.
