# Current Hosted Backend Contract-Origin Proof

Contract: `backend-hosted-current-proof-v1`

Status: `verified`

The current Vercel backend Production target is bound to committed source
`21913f8c3ef13949ca962980c143e757ca87a7cc` and archive SHA-256
`314bd1d9c7830dc5ac9077398025fed4ab48041b31fefae491916e838d5f7080`.
The verifier uses authenticated read-only Vercel metadata to require deployment
`dpl_AQaBJxdQwHLcQKid8xYXkNJ3wva2` to be `READY`, target `production`, assigned
to the configured Production Alias, and to expose the exact source/archive metadata.

The immutable URL remains protected and redirects to Vercel authentication. Public
contract reads use the assigned Production Alias and require HTTP 200 for root, health,
progress, integrity, external gates, MCP health, and LLM health. The source-bound
snapshot remains `overall=84`, Phase 4 `100`, integrity `verified`, external gates
`5/6 action_required` with only `fly_cloud_stack` blocked, MCP/LLM `healthy`, and
expected stateless Agent API health `degraded`.

One mutation-shaped probe against the Production Alias must return HTTP 503 with
`reason=stateless_contract_origin_read_only`. This proves that the operational
Production deployment does not silently expose write behavior.

Evidence:

- State: `docs/runtime-state/backend-hosted-current.json`
- Verifier: `scripts/verify-backend-hosted-current.ps1`
- Runtime verification: `.codex/runs/CURRENT/master-goal/production/t1-21913f8c/backend-verification.json`

Non-claims:

- This is a stateless Vercel contract origin, not the stateful Docker backend stack.
- Agent API `degraded` is expected because PostgreSQL, Redis, agent-worker, and
  memory-worker are not configured on this target.
- The operational Production deployment is not release-candidate promotion.
- It is not a full-platform production release, registry publication, or live MCP write.
