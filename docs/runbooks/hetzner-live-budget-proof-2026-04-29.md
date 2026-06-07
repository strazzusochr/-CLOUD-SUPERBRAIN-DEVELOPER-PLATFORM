# Fly.io Live Budget Proof - 2026-04-29

Status: Verified one-time live API proof
Gate: `FLY_API_TOKEN`
Scope: Infrastructure budget only, not LLM/API provider budget

## Result

`scripts/check_fly_infra_budget.py` was executed with `FLY_API_TOKEN` provided only as a transient process environment variable. The token was not written to repository files, `.env`, Docker Compose, GitHub workflow files, logs, or docs.

Observed output:

- Projected Fly.io monthly server cost: `EUR 9.00`
- Infra warning threshold: `EUR 16.00`
- Hard infrastructure budget: `EUR 20.00`
- Live Fly.io token probe: verified
- Result: under warning threshold

## Decision

The hard `20 EUR/month` infrastructure budget is currently not exceeded. No additional Fly.io scale-up, separate staging runtime, GPU worker, paid networking upgrade, or fleet expansion is allowed without a new live budget proof and owner approval.

## Non-Claims

- The token is not persisted as `FLY_API_TOKEN` for the local Docker stack.
- The token is not configured as a GitHub secret.
- `GET /api/v1/infra/budget` may still report `live_verified=false` unless the runtime container receives `FLY_API_TOKEN`.
- This proof does not authorize production deployment.
