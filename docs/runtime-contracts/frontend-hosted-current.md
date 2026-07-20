# Current Hosted Frontend Proof

Contract: `frontend-hosted-current-proof-v1`

Status: `verified`

The current Vercel Production frontend is bound to committed source
`21913f8c3ef13949ca962980c143e757ca87a7cc` and archive SHA-256
`314bd1d9c7830dc5ac9077398025fed4ab48041b31fefae491916e838d5f7080`.
Authenticated Vercel metadata requires deployment `dpl_9KPqcjNPnV9irpJ9W8tyjff8LMbX`
to be `READY`, target `production`, assigned to the configured Production Alias,
and to expose the exact source/archive metadata.

Real Google Chrome `148.0.7778.96` opened all 22 canonical routes on the
Production Alias by command-palette clicks at desktop `1440x960` and mobile
`390x844`. The verifier
requires 44 clicks, no visible not-found state, no console errors, no incoherent
overflow, no overlay collisions, and four non-empty screenshots. Root and
`/api/v1/workspace/wiring` must return HTTP 200 from both the immutable deployment
and the Production Alias with byte-identical content.

The same verifier permanently guards 32 Production read endpoints. This includes the
eight routes that previously returned HTTP 500: agent activity, MCP/recent audit,
escalations, memory consolidation, rotation events, recent sessions, and workspace
artifacts. All must return HTTP 200. Projection responses remain explicitly labeled
`frontend-projection`; the operational deploy does not turn them into live state.

Evidence:

- State: `docs/runtime-state/frontend-hosted-current.json`
- Verifier: `scripts/verify-frontend-hosted-current.ps1`
- Report: `.codex/runs/CURRENT/master-goal/production/t1-21913f8c/responsive/report.json`
- Endpoint sweep: `.codex/runs/CURRENT/master-goal/production/t1-21913f8c/endpoint-sweep.json`
- Verification: `.codex/runs/CURRENT/master-goal/production/t1-21913f8c/responsive/verification.json`

Non-claims:

- This proves the scoped operational Frontend / Next.js Production deployment.
- It is not release-candidate promotion and does not set `MARKET_READY: true`.
- It is not proof of a stateful hosted Agent API, registry publication, live MCP
  writes, or a full-platform production release.
