# Current Hosted Frontend Proof

Contract: `frontend-hosted-current-proof-v1`

Status: `verified`

The current hosted frontend evidence is bound to READY operational Production deployment
`dpl_Fc62aha6yjHRBS9EBBZcbVdZNw7C` and Vercel-attested Git source
`a25d9bcb1ef6253bfafbea37df08a0073bc2a76e`, a verified descendant of frozen
RC68 source `10bccfcfb5a62c6883c7162b8b2eed4f3da817ff`. The deployment exposes no
source-archive metadata, so the verifier requires that field to remain absent
rather than inventing an archive claim. Authenticated Vercel metadata requires the
exact deployment id, target `production`, Git source consensus, and an authoritative
`/v4/aliases/` readback that binds `frontend-seven-psi-78.vercel.app` to the same
deployment. The binding is read both before and after the browser/content checks.

Vercel may describe this exact provider operation as an authenticated `promote`
transport instead of a `redeploy`. The verifier accepts only these explicit
provider transport labels while retaining the independent source, project, target,
alias, timestamp and content-parity checks.

Real Google Chrome `148.0.7778.96` opened all 26 canonical routes on the production
alias by command-palette clicks at desktop and mobile viewports, for 52 navigation
checks. The verifier requires no visible not-found state, no console errors, no
incoherent overflow, no overlay collisions, and four non-empty screenshots. The
report timestamp must exactly match the configured timestamp and may not predate
either deployment creation or canonical alias assignment.

The verifier also checks 32 configured hosted read surfaces plus content-parity
through the authenticated alias binding. Projection responses must keep every
live/write/deploy/secret claim false; this operational frontend deployment is not a
full-platform release promotion.

Evidence:

- State: `docs/runtime-state/frontend-hosted-current.json`
- Verifier: `scripts/verify-frontend-hosted-current.ps1`
- Report: `docs/release-artifacts/prod-candidate-2026-09-16-local-rc68-evidence/frontend/report.json`
- Verification: `docs/release-artifacts/prod-candidate-2026-09-16-local-rc68-evidence/frontend/verification.json`

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
