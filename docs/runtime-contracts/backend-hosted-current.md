# Current Hosted Backend Contract-Origin Proof

Contract: `backend-hosted-current-proof-v1`

Status: `verified`

The current Vercel backend preview is bound to committed source
`2e0f57179956ad88657567be65ebe33f1da0d255` and archive SHA-256
`deae678aafe375251023401c06c5b65e8891c3350e542e51ecf8413aaff0253b`.
The verifier uses authenticated read-only Vercel metadata to require deployment
`dpl_32rFKVF1W4rkVqq6rPhPsqtPvXEZ` to be `READY`, target `preview`, and to expose
the exact source/archive metadata.

Direct unsafe requests remain blocked by Vercel Deployment Protection with HTTP 401.
The verifier uses Vercel's authenticated automation bypass without exposing its secret,
then requires HTTP 200 for root, health, progress, integrity, external gates, MCP health,
and LLM health. The immutable deployment snapshot remains `overall=84`, Phase 4 `100`,
integrity `verified`, external gates `5/6 action_required` with only
`hosted_backend_origins` blocked, MCP/LLM `healthy`, and expected stateless Agent API
health `degraded`. The current local canonical standard is tracked independently in
`docs/runtime-state/external-gate-summary.json`; it is not retroactively substituted into
the source-bound preview response.

One authenticated mutation-shaped probe must reach the application and return HTTP 503
with `reason=stateless_contract_origin_read_only`. This proves that the preview does not
silently expose write behavior. Production Alias assignment or content parity is not
required or claimed in preview mode.

Evidence:

- State: `docs/runtime-state/backend-hosted-current.json`
- Verifier: `scripts/verify-backend-hosted-current.ps1`
- Runtime verification: `.codex/runs/CURRENT/master-goal/backend/hosted-contract-origin-2e0f5717-preview/verification.json`

Non-claims:

- This is a stateless Vercel contract origin, not the stateful Docker backend stack.
- Agent API `degraded` is expected because PostgreSQL, Redis, agent-worker, and
  memory-worker are not configured on this target.
- It does not promote or mutate the existing Production Alias.
- It is not a full-platform production release, registry publication, or live MCP write.
