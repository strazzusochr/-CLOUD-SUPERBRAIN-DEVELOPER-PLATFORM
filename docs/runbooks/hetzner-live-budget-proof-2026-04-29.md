# Hetzner Live Budget Proof - 2026-04-29

Status: Verified one-time live API proof
Gate: `HETZNER_API_TOKEN`
Scope: Infrastructure budget only, not LLM/API provider budget

## Result

`scripts/check_hetzner_infra_budget.py` was executed with `HETZNER_API_TOKEN` provided only as a transient process environment variable. The token was not written to repository files, `.env`, Docker Compose, GitHub workflow files, logs, or docs.

Observed output:

- Projected Hetzner monthly server cost: `EUR 19.03`
- Infra warning threshold: `EUR 16.00`
- Hard infrastructure budget: `EUR 20.00`
- Running server type observed: `cax31`
- Result: under hard budget, above warning threshold

## Decision

The hard `20 EUR/month` infrastructure budget is currently not exceeded, but the warning threshold is active. No additional Hetzner server, separate staging server, GPU server, CPX/CCX upgrade, snapshot expansion, or K3s migration is allowed without a new live budget proof and owner approval.

## Non-Claims

- The token is not persisted as `HETZNER_API_TOKEN` for the local Docker stack.
- The token is not configured as a GitHub secret.
- `GET /api/v1/infra/budget` may still report `live_verified=false` unless the runtime container receives `HETZNER_API_TOKEN`.
- This proof does not authorize production deployment.
