# Current Hosted Backend Contract-Origin Proof

Contract: `backend-hosted-current-proof-v1`

Status: `verified`

The active Vercel backend deployment is bound to committed source
`e1a3ec1f7942e54058e56915f4fb29636c5c4f3e` and archive SHA-256
`c1106b6cb2a36f643664a3f428483685f27231f8e0128f5581925ab2196ea1cb`.
The verifier uses the authenticated read-only Vercel API to require immutable deployment
status `READY`, exact source/archive metadata, and assignment of the public Production
Alias. The immutable URL must remain Vercel-SSO protected with HTTP 302. Runtime checks
use the public alias and require HTTP 200, `overall_percent=84`, Phase 4 `100`, progress
integrity `verified`, canonical external gates `5/6 action_required` with only
`hosted_backend_origins` blocked, MCP/LLM health `healthy`, and the expected stateless
Agent API health `degraded`. The hosted verifier reads these expected gate values from
the canonical state config; it does not hardcode a successful release-gate state.

The verifier also sends one mutation-shaped request and requires HTTP 503 with
`reason=stateless_contract_origin_read_only`. This proves that the public origin does
not silently expose write behavior.

Evidence:

- State: `docs/runtime-state/backend-hosted-current.json`
- Verifier: `scripts/verify-backend-hosted-current.ps1`
- Runtime verification: `.codex/runs/CURRENT/master-goal/backend/hosted-contract-origin-e1a3ec1f/verification.json`

Non-claims:

- This is a stateless Vercel contract origin, not the stateful Docker backend stack.
- The protected immutable URL is not claimed to have byte-identical unauthenticated
  content with the public Production Alias.
- Agent API `degraded` is expected because PostgreSQL, Redis, agent-worker, and
  memory-worker are not configured on this target.
- It is not a full-platform production release, registry publication, live MCP write,
  or live LLM provider activation.
