# Current Hosted Frontend Proof

Contract: `frontend-hosted-current-proof-v1`

Status: `verified`

The current hosted frontend evidence is bound to READY operational Production redeployment
`dpl_3K7iLgty3UEmsiW2k9cfxGDnTZoh` and Vercel-attested frontend security-overlay
Git source `d76cb75d2a8dfffbc73217b8985305d868a2245a`, a verified descendant of
frozen runtime source `e949cc1a50f21a3c565c2c2f2380a663f2cc4be7`. The redeploy exposes no
source-archive metadata, so the verifier requires that field to remain absent
rather than inventing an archive claim. Authenticated Vercel metadata requires the
exact deployment id, target `production`, immutable host, redeploy action, Git
source consensus, and an authoritative `/v4/aliases/` readback that binds
`frontend-seven-psi-78.vercel.app` to the same deployment. The binding is read
both before and after the browser/content checks.

Real Google Chrome `148.0.7778.96` opened all 22 canonical routes on the production
alias by command-palette clicks at desktop `1440x960` and mobile `390x844`.
The verifier requires 44 clicks, no visible not-found state, no console errors, no
incoherent overflow, no overlay collisions, and four non-empty screenshots. The
report timestamp must exactly match the configured timestamp and may not predate
either deployment creation or canonical alias assignment.

The verifier also checks 32 configured hosted read surfaces plus byte-parity of the
immutable deployment and production alias. Projection responses must keep every
live/write/deploy/secret claim false; this operational frontend deployment is not a
full-platform release promotion.

Evidence:

- State: `docs/runtime-state/frontend-hosted-current.json`
- Verifier: `scripts/verify-frontend-hosted-current.ps1`
- Report: `.phase1-artifacts/frontend-hosted-current-rc94-security-overlay/report.json`
- Verification: `.phase1-artifacts/frontend-hosted-current-rc94-security-overlay/verification.json`

`npm run verify:frontend-hosted-current` intentionally uses `-SkipBrowser`: it
revalidates the timestamp-bound canonical report, screenshots, authenticated
metadata, alias parity, and production reads without overwriting that report.
A new browser refresh is a separate truth-update step and must bind its exact new
timestamp and browser version in the state file before verification.

Non-claims:

- This evidence records an operational Production-target frontend redeploy and
  canonical alias parity; it does not claim a full-platform production release.
- The Vercel project remains parked on `codex/vercel-production-hold-rc38` and
  automatic custom-domain assignment remains disabled.
- It is not full six-service hosted parity, Worker-source proof, live-provider
  proof, hosted MCP-write proof, release-candidate promotion, or `MARKET_READY:true`.
