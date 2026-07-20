# Current Hosted Frontend Proof

Contract: `frontend-hosted-current-proof-v1`

Status: `verified`

The active Vercel frontend deployment is bound to committed source
`e1a3ec1f7942e54058e56915f4fb29636c5c4f3e`. A real Google Chrome 148 run opened all
22 canonical routes by command-palette clicks at desktop `1440x960` and mobile
`390x844`. The verifier requires 44 clicks, no visible not-found state, no console
errors, no incoherent overflow, no collision between the Organism performance HUD and
gate badges, and four non-empty screenshots.

The wrapper also rechecks HTTP 200 and byte-identical root and workspace-wiring
content between the immutable deployment URL and the production alias.

Evidence:

- State: `docs/runtime-state/frontend-hosted-current.json`
- Verifier: `scripts/verify-frontend-hosted-current.ps1`
- Report: `.codex/runs/CURRENT/master-goal/frontend/hosted-22x2-0555b0bd-chrome/report.json`
- Verification: `.codex/runs/CURRENT/master-goal/frontend/hosted-22x2-0555b0bd-chrome/verification.json`

Non-claims:

- This closes the Frontend / Next.js hosted proof only.
- It is not proof of the full hosted Agent API, MCP Gateway, or LLM Gateway stack.
- It is not a platform production release, registry publication, live MCP write, or
  live LLM provider activation.
