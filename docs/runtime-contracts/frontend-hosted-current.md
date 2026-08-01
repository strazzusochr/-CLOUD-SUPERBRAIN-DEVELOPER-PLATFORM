# Current Hosted Frontend Proof

Contract: `frontend-hosted-current-proof-v1`

Status: `verified`

The current Vercel Production frontend is bound to READY deployment
`dpl_5uLu9a2BpEBb5BDPiuqRtyfkSFY1` and Vercel-attested Git source
`67f41cecf38de109e762632ed971c9a7fdaff6ba`. This Git-integrated redeploy has
no attested source-archive SHA-256, so none is claimed. Authenticated Vercel
metadata requires the exact deployment id, target `production`, immutable host,
Production Alias membership, and consensus across every populated source-SHA
field. The binding is read both before and after the browser/content checks.

Real Google Chrome `148.0.7778.96` opened all 22 canonical routes on the
Production Alias by command-palette clicks at desktop `1440x960` and mobile
`390x844`. The verifier
requires 44 clicks, no visible not-found state, no console errors, no incoherent
overflow, no overlay collisions, and four non-empty screenshots. Root and
`/api/v1/workspace/wiring` must return HTTP 200 from both the immutable deployment
and the Production Alias with byte-identical content.
The report timestamp must exactly match the configured timestamp and may not
predate either deployment creation or Alias assignment.

The same verifier permanently guards 32 Production read endpoints. This includes the
eight routes that previously returned HTTP 500: agent activity, MCP/recent audit,
escalations, memory consolidation, rotation events, recent sessions, and workspace
artifacts. All must return directly with HTTP 200, the advertised content type, and
valid JSON except for the text metrics endpoint. The eight former-500 projection
responses must remain explicitly labeled `frontend-projection` with every live/write/
deploy/secret flag false; the operational deployment does not turn them into live state.

Evidence:

- State: `docs/runtime-state/frontend-hosted-current.json`
- Verifier: `scripts/verify-frontend-hosted-current.ps1`
- Report: `.codex/runs/CURRENT/master-goal/production/t1-67f41cec/responsive/report.json`
- Verification: `.codex/runs/CURRENT/master-goal/production/t1-67f41cec/responsive/verification.json`

`npm run verify:frontend-hosted-current` intentionally uses `-SkipBrowser`: it
revalidates the timestamp-bound canonical report, screenshots, authenticated
metadata, immutable/Alias parity, and all 32 reads without overwriting that report.
A new browser refresh is a separate truth-update step and must bind its exact new
timestamp and browser version in the state file before verification.

Non-claims:

- This is a read-only truth refresh for the already-active Alias, not a deploy.
- It is not RC11 hosted parity or release-candidate promotion and does not set
  `MARKET_READY: true`.
- It is not proof of a stateful hosted Agent API, registry publication, live MCP
  writes, or a full-platform production release.
