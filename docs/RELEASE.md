# Cloud Superbrain Release Status

Updated: 2026-08-01

Status: **not released**. RC11 is locally qualified on source
`bae3cdc1692e1e99e7f546f72664a3c747958b8c`; GitHub Actions run `30686367636`
passed. I1 hosted candidate parity and I5 production authentication remain Owner-blocked,
so no full-platform production release or promotion is claimed.

## Local Development Runtime

```powershell
docker compose -f docker-compose.dev.yml up -d
npm run verify
npm run verify:runtime
npm run verify:browser
```

Local URL: `http://localhost:8081`

Localhost is `DEV-ONLY; hosted proof still blocked`. It may prove deterministic runtime, API, audit, and browser
behavior, but it cannot close hosted staging, backend-origin, production, or release
gates.

## Current Evidence Snapshot

| Scope | Current verified value |
| --- | --- |
| Overall progress | 89 percent |
| Horizontal | P0 100, P1 100, P2 100, P3 44, P4 100, P5 89, P6 90 |
| Vertical | Frontend 100, Orchestrator 100, Agent Pool 100, LLM 55, MCP 56, Memory 100, Observability 100 |
| Project progress integrity | `verified` |
| Canonical workspace pages | 22/22 local and 22/22 hosted in real Google Chrome at desktop and mobile |
| Docker services | 10/10 healthy in the latest local check |
| Canonical secret scan | gitleaks pass, no leaks found |
| RC11 qualification | Five independent chains passed; `17/19`, `verified_with_owner_blocks` |
| Deployment | Vercel frontend and read-only backend contract origin verified; full-platform production release not performed |

Percentages come only from `docs/project-progress.manifest.json` and must match
`GET /api/v1/project/progress` plus `GET /api/v1/project/progress/integrity`.
All dated evidence paragraphs below preserve their historical milestone percentages;
they do not override the current RC11 snapshot above.

The current Phase-3 credential-issuance replacement is locally verified under
`phase3-auth-credential-issuance-fail-closed-v1`. It requires one-time Redis OAuth state,
verified numeric GitHub identity, exactly `read:user`, a base64url 256-bit signing-secret floor,
active-registry cookie-only refresh rotation, persisted audit evidence before successful auth
cookies, truthful logout events, error-response state-cookie clearing, and query-safe access logs.
Nineteen unit tests, a real-Redis concurrency probe, local HTTP negative paths, and the complete
static/runtime/browser suites passed sequentially. Evidence:
`.codex/runs/CURRENT/phase3/auth-fail-closed/report.json`, SHA-256
`FB90E6D57FFBC6C646C583D6F5DD18F4EDB71D9E881B9B7090B3FFDD31FCADC1`. The run also
closed the newly reported `sharp <0.35.0` advisory with exact override `0.35.3`; npm audit reports
zero vulnerabilities. This supersedes historical RC1 auth evidence without duplicate progress
credit; P3 remains `44%`, Overall `86%`. The repair is committed as
`255e328a76b3f84bf74358bc7258b9ffb797b339`, pushed on the working branch, and requalified as
RC5. DEV-ONLY; hosted proof still blocked.

The current hosted Agent Pool proof is read-only: `scripts/verify-agent-pool-hosted-readonly.ps1`
revalidates one existing Cloudflare D1-backed terminal run with exactly four completed role tasks.
It uses no token and performs no write. This credits only
`hosted_cloudflare_d1_four_role_agent_pool_readback_proof`, moving Agent Pool `68 -> 69`;
worker scaling, priority-queue parity, live LLM/MCP activity, release, and production remain unclaimed.

The current hosted MCP proof is also read-only: `scripts/verify-mcp-hosted-current-readonly.ps1`
binds the public Vercel Contract Origin to its recorded deployment and unchanged MCP source blobs,
then reads health, five dry-run contracts, exact pins, and the audit contract over HTTPS GET only.
Evidence `.codex/runs/CURRENT/mcp-gateway/hosted-readonly-contract/report.json` credits only
`mcp_current_hosted_readonly_contract_parity_verified`, moving MCP Gateway `55 -> 56` while
Overall remains `86`. It executes no tool and performs no token, audit, provider, or release write.

The current Cloudflare LLM Preview proof is read-only and source-bound:
`scripts/verify-cloudflare-llm-gateway-hosted-readonly.ps1` reads health and the exact
two-model allowlist over public HTTPS GET, then proves the deployed service tree is
blob-identical to current HEAD. Evidence
`.codex/runs/CURRENT/llm-gateway/cloudflare-hosted-readonly/report.json` credits only
`cloudflare_workers_ai_llm_gateway_preview_readonly_source_parity_verified`, moving LLM
Gateway `54 -> 55` while Overall remains `86`. It uses no token, sends no inference, and
performs no provider, deployment, release, or promotion write.

The reported Workbench `LLM Gateway HTTP 503` has been repaired operationally. Evidence
`.codex/runs/CURRENT/llm-gateway/frontend-build-503-fix/report.json` records the reproduced
failure, secret-value-free Cloudflare/Vercel configuration alignment, source-bound Preview and
Production deployments, HTTP `200` live mini-builds, and real-Chrome `22 x 2` route proofs on
both deployments. This adds no progress credit and is not a release-promotion claim: the
frontend currently targets the Cloudflare Preview worker and the failed immutable URL remains
a historical deployment.

## Current RC11 Gate Status

Status: `verified_with_owner_blocks` for local candidate qualification.

The remaining readiness items are exactly I1 `hosted_candidate_parity` and I5
`production_auth_identity`. Both require Owner action and their dedicated hosted
verifiers. The local runtime, browser, image, candidate-runtime, and security chains
cannot close either item.

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

## Phase 2 Local Runtime Closure

`phase2-postgres-checkpoint-restart-recovery-v1` proves the seventh and final mandatory
Phase-2 runtime item. The full runtime verifier recovered a completed LangGraph checkpoint
from PostgreSQL by the same `thread_id` after force-recreating `agent-api` and `nginx`.
The focused recreation probe and `npm run verify:runtime` both passed after hardening the
comprehensive healthcheck for its measured aggregate latency. Phase 2 is therefore `100`
and Overall is `86`. Evidence is under
`.codex/runs/CURRENT/master-goal/phase2/checkpoint-restart-recovery-20260721.md`.

This is local deterministic runtime closure only. It does not prove hosted stateful parity,
live provider calls, live MCP writes, registry publication, deployment, or release promotion.

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

Candidate `prod-candidate-2026-07-31-local-rc11` is locally qualified against committed
source `bae3cdc1692e1e99e7f546f72664a3c747958b8c`. GitHub Actions `pr-check` run
`30686367636` passed. The five independent chains `runtime`, `browser`,
`candidate_images`, `candidate_runtime`, and `security` passed with real artifacts,
SHA-256 values, and success anchors. The itemization derives `17/19 = 89%`, so P5 is
`89%` and Overall is `89%`.

Current O4 proof SHA-256 is
`50304C69B3D748C95804C4C72C2970694748F469AE322D5C24DAA6BCB545B11B`.
The remaining items are I1 hosted candidate parity and I5 production auth identity.
The GHCR tag set is unpublished; production deploy and release promotion remain false.
DEV-ONLY; hosted proof still blocked.

## Candidate And Release Requirements

A release claim requires all of the following against the exact approved immutable
candidate:

1. Complete and credited phase/layer work according to the binding rubric.
2. Green static, runtime, browser, progress-integrity, and canonical gitleaks checks.
3. Reachable HTTPS hosted Agent API, MCP Gateway, and LLM Gateway origins.
4. Fresh hosted browser and API proof against the configured staging URL.
5. Current verify-only branch-protection proof.
6. Current Cloudflare zero-card eligibility plus hosted-runtime proof within the
   20 EUR/month ceiling.
7. Immutable source/image provenance and tested rollback evidence.
8. Explicit Owner review of commit scope, permissions, budget, rollback, and promotion.
9. Separate Owner authorization for registry publication, deployment, and release
   promotion.

## Stop Gates

Without explicit Owner approval, or outside an already recorded scope-specific approval, do not:

- use or expand provider credentials;
- push container images or publish registry artifacts;
- mutate Vercel, Cloudflare, GitHub, Grafana, or production database state;
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
