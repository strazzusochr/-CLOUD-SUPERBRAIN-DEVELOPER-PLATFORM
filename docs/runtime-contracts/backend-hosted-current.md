# Current Hosted Backend Contract-Origin Proof

Contract: `backend-hosted-current-proof-v1`

Status: `verified`

The active Vercel backend deployment is bound to committed source
`72e829357ed20e818f228e61af745c7fba43f445` and archive SHA-256
`cfeabc024621d300d930c03f6c1251e002dfd569f03b0a2b6fe08f44c522206c`.
The verifier uses the authenticated read-only Vercel API to require immutable deployment
status `READY`, exact source/archive metadata, and assignment of the public Production
Alias. The immutable URL must remain Vercel-SSO protected with HTTP 302. Runtime checks
use the public alias and require HTTP 200, `overall_percent=84`, Phase 4 `100`, progress
integrity `verified`, external gates `6/6 verified`, MCP/LLM health `healthy`, and the
expected stateless Agent API health `degraded`.

The verifier also sends one mutation-shaped request and requires HTTP 503 with
`reason=stateless_contract_origin_read_only`. This proves that the public origin does
not silently expose write behavior.

Evidence:

- State: `docs/runtime-state/backend-hosted-current.json`
- Verifier: `scripts/verify-backend-hosted-current.ps1`
- Runtime verification: `.codex/runs/CURRENT/master-goal/backend/hosted-contract-origin-72e8293/verification.json`

Non-claims:

- This is a stateless Vercel contract origin, not the stateful Docker backend stack.
- The protected immutable URL is not claimed to have byte-identical unauthenticated
  content with the public Production Alias.
- Agent API `degraded` is expected because PostgreSQL, Redis, agent-worker, and
  memory-worker are not configured on this target.
- It is not a full-platform production release, registry publication, live MCP write,
  or live LLM provider activation.
