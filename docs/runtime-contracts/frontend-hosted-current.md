# Current Hosted Frontend Proof

Contract: `frontend-hosted-current-proof-v1`

Status: `verified`

The current hosted frontend evidence is bound to READY Preview redeployment
`dpl_CpAPVum4NhqxMG63oTwDiecx5A13`, Vercel-attested Git source
`1ad419cb56368fb747d65e8ceec3798e18badbc4`, and source-archive SHA-256
`119d388bac0ad296e66b7c4ac1ac6d50996ea625338bb4f789db4c6b1d26e44f`.
Authenticated Vercel metadata requires the exact deployment id, target `preview`,
immutable host, redeploy action, archive binding, and consensus across every
populated source-SHA field. The binding is read both before and after the
browser/content checks.

Real Google Chrome `148.0.7778.96` opened all 22 canonical routes on the immutable
Preview host by command-palette clicks at desktop `1440x960` and mobile `390x844`.
The verifier requires 44 clicks, no visible not-found state, no console errors, no
incoherent overflow, no overlay collisions, and four non-empty screenshots. The
report timestamp must exactly match the configured timestamp and may not predate
either deployment creation or alias assignment.

The verifier also checks the configured hosted read surfaces. Projection responses
must keep every live/write/deploy/secret claim false; a READY Preview never turns a
read-only projection into live provider state.

Evidence:

- State: `docs/runtime-state/frontend-hosted-current.json`
- Verifier: `scripts/verify-frontend-hosted-current.ps1`
- Report: `.phase1-artifacts/frontend-hosted-current-rc28-preview/report.json`
- Verification: `.phase1-artifacts/frontend-hosted-current-rc28-preview/verification.json`

`npm run verify:frontend-hosted-current` intentionally uses `-SkipBrowser`: it
revalidates the timestamp-bound canonical report, screenshots, authenticated
metadata, and immutable Preview reads without overwriting that report.
A new browser refresh is a separate truth-update step and must bind its exact new
timestamp and browser version in the state file before verification.

Non-claims:

- This evidence records a Preview redeploy; it does not promote or modify the Production Alias.
- It is not full six-service hosted parity or release-candidate promotion and does not set
  `MARKET_READY: true`.
- It is not proof of a stateful hosted Agent API, registry publication, live MCP
  writes, Production Alias parity, or a full-platform production release.
