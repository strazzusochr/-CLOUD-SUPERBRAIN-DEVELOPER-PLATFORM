# Owner Go-Live Checklist

Updated: 2026-07-30

Status: `OWNER_BLOCKED_AUTONOMOUS_COMPLETE`; `MARKET_READY=false`.

## Current truth

- Overall: `86%`.
- Active hosted target: Cloudflare-native, zero-card.
- Canonical gate: `cloudflare_native_zero_card_hosted_runtime`.
- Canonical audit: `docs/runtime-state/external-gate-audit-v2.json`.
- Fly.io rollout and `FLY_API_TOKEN` are `historical_only`.
- Localhost evidence is `DEV-ONLY; hosted proof still blocked`.

## Owner gates

| ID | Required action | State |
| --- | --- | --- |
| O1 | Production OAuth identity and callback approval | configuration complete; hosted identity proof open |
| O2' | Cloudflare least-privilege scopes, zero-card activation, hosted stateful proof | O2Core 4/4; hosted W/R/D proof open |
| O3 | GHCR publication plus release review | open |
| O4 | Bounded live agent/MCP writes plus protected-branch approval | Owner scope approved; live-write proofs open |
| O5 | Vectorize Edit plus hosted semantic-search proof | O5 1/1; hosted semantic proof open |
| O6 | Bounded gateway-only Workers AI path | resolved_verified; 0% credit |

The exact scope and verifier mapping is binding in
`docs/runtime-state/owner-input-manifest.json`.

## O2' inputs

Provide in the private Owner shell without printing values:

- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_STATEFUL_BASE_URL`
- `STAGING_BASE_URL`

The historical read-only inventory result did not prove resource absence. The current
candidate has separately passed `O2Core 4/4` and `O5 1/1`; only the real hosted verifier
can qualify it for activation. The weaker active token is not silently replaced.

Required least-privilege capabilities:

- Workers Scripts Edit
- D1 Edit
- Durable Objects Edit
- Queues Edit

R2 is historical-only and must not be enabled, created, or added as a binding.

- Vectorize Edit separately for O5

## Safe plan

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\owner-cloud-gate-activation.ps1
```

This is PlanOnly. The script remains fail-closed in Apply mode.

After the Owner has separately approved and executed the exact hosted action,
run the named verifiers from `docs/runtime-state/owner-input-manifest.json`.
Do not claim gate closure from credentials, dashboard state, or a free-quota
description alone.

## Stop conditions

Stop before any hosted write, deployment, registry push, production promotion,
main write, scope expansion, payment step, secret output, or destructive
action unless the exact Owner gate is explicit and current.
