# Owner Cloud Gate Activation

Status: prepared, owner-gated, no hosted gate closure.

This runbook is the next safe bridge from local evidence to the active O2'
`cloudflare_native_zero_card_hosted_runtime` proof. The active external truth is
`external-gate-summary-v2`, sourced from a dynamically named
`external-gate-audit-v2-*.json` artifact.

## Rules

- Plan-only by default: `scripts\owner-cloud-gate-activation.ps1` writes a local plan artifact and performs no cloud mutation.
- `-Apply` is fail-closed in Codex; owner-approved mutation must be executed deliberately in an owner shell, then verified by hosted artifacts.
- No secret values are printed or written. Token checks are presence-only.
- Cloudflare HTTPS is required for `CLOUDFLARE_STATEFUL_BASE_URL`.
- Vercel HTTPS staging is required for `STAGING_BASE_URL`.
- Retired `sslip.io` staging targets are blocked.
- Localhost is DEV-ONLY and cannot close hosted gates.
- No progress percentage changes happen from this plan alone.
- The bounded O6 LLM path is already `owner_granted=true` and
  `live_verified=true`; O6 is not an Owner-required action. This does not make
  Layer 4 equal 100 and grants no percentage credit.
- Fly and `FLY_API_TOKEN` are retired from the active gate path. Legacy Fly
  artifacts remain `historical_only`.

## Required Owner Inputs

- `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN` present in the private
  Owner shell; values remain presence-only.
- Owner-approved least-privilege Cloudflare scopes:
  - `Workers Scripts:Edit`
  - `D1:Edit`
  - `Durable Objects:Edit`
  - `Queues:Edit`
- Explicit Owner approval for hosted writes and deployment.
- Reachable Cloudflare HTTPS runtime as `CLOUDFLARE_STATEFUL_BASE_URL`.
- Final Vercel HTTPS staging URL as `STAGING_BASE_URL`.
- Bounded UTF-8 artifacts use D1; R2 is disabled, unbound and
  `historical_only`. No R2 activation or bucket creation belongs to this path.

## Activation Order

1. Generate the dry-run plan:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\owner-cloud-gate-activation.ps1
```

2. Owner approves cloud mutation outside the normal Codex turn.

3. Owner reviews the exact Workers, D1, SQLite Durable Objects and Queues scopes
   and authorizes the bounded hosted write proof.

4. Verify the Cloudflare-native hosted runtime and hosted staging:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-cloudflare-stateful-runtime.ps1 -BaseUrl <CLOUDFLARE_STATEFUL_BASE_URL> -AllowHostedWrites
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-browser-contract.ps1 -BaseUrl <STAGING_BASE_URL>
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-external-gates.ps1
```

## Expected Gate Effect

Only a real hosted artifact may close:

- `cloudflare_native_zero_card_hosted_runtime`

The verifier remains fail-closed without Owner scopes, a Cloudflare HTTPS URL,
explicit hosted-write approval, and real hosted evidence. The plan itself does
not call Cloudflare, mutate providers, print secrets, deploy, publish images,
open MCP writes, increase progress, or make a production/release claim.
