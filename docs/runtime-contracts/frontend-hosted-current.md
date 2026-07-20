# Current Hosted Frontend Proof

Contract: `frontend-hosted-current-proof-v1`

Status: `verified`

The current Vercel preview is bound to committed source
`2e0f57179956ad88657567be65ebe33f1da0d255` and archive SHA-256
`deae678aafe375251023401c06c5b65e8891c3350e542e51ecf8413aaff0253b`.
Authenticated Vercel metadata requires deployment `dpl_J7BC3uPPUcQBgZckU29kKHXc5Wm9`
to be `READY` with target `preview` and exact source/archive metadata.

Real Google Chrome `148.0.7778.96` opened all 22 canonical routes by
command-palette clicks at desktop `1440x960` and mobile `390x844`. The verifier
requires 44 clicks, no visible not-found state, no console errors, no incoherent
overflow, no overlay collisions, and four non-empty screenshots. Root and
`/api/v1/workspace/wiring` must return HTTP 200 from the immutable preview URL.

Production Alias parity is deliberately not required or claimed for preview target
proofs. Production mode remains supported and still requires byte-identical root and
workspace-wiring content between the immutable deployment and Production Alias.

Evidence:

- State: `docs/runtime-state/frontend-hosted-current.json`
- Verifier: `scripts/verify-frontend-hosted-current.ps1`
- Report: `.codex/runs/CURRENT/master-goal/frontend/hosted-22x2-2e0f5717-preview-chrome/report.json`
- Verification: `.codex/runs/CURRENT/master-goal/frontend/hosted-22x2-2e0f5717-preview-chrome/verification.json`

Non-claims:

- This proves the immutable Frontend / Next.js preview only.
- It does not promote or mutate the existing Production Alias.
- It is not proof of a stateful hosted Agent API, registry publication, live MCP
  writes, or a platform production release.
