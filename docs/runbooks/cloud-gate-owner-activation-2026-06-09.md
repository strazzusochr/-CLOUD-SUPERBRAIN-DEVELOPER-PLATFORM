# Owner Cloud Gate Activation

Status: prepared, owner-gated, no hosted gate closure.

This runbook is the next safe bridge from local evidence to cloud-only evidence. It keeps the developer platform clean and separates project-state proof from product UI work.

## Rules

- Plan-only by default: `scripts\owner-cloud-gate-activation.ps1` writes a local plan artifact and performs no cloud mutation.
- `-Apply` is fail-closed in Codex; owner-approved mutation must be executed deliberately in an owner shell, then verified by hosted artifacts.
- No secret values are printed or written. Token checks are presence-only.
- Vercel HTTPS staging is required for `STAGING_BASE_URL`.
- Retired `sslip.io` staging targets are blocked.
- Localhost is DEV-ONLY and cannot close hosted gates.
- No progress percentage changes happen from this plan alone.

## Required Owner Inputs

- `VERCEL_TOKEN` present in the private shell environment.
- `FLY_API_TOKEN` present in the private shell environment.
- Reachable Fly.io origins:
  - `AGENT_API_BASE_URL`
  - `MCP_GATEWAY_BASE_URL`
  - `LLM_GATEWAY_BASE_URL`
- Vercel preview/staging env:
  - `STAGING_REWRITES_ENABLED=1`
  - `AGENT_API_BASE_URL`
  - `MCP_GATEWAY_BASE_URL`
  - `LLM_GATEWAY_BASE_URL`
- Final Vercel HTTPS staging URL as `STAGING_BASE_URL`.

## Activation Order

1. Generate the dry-run plan:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\owner-cloud-gate-activation.ps1
```

2. Owner approves cloud mutation outside the normal Codex turn.

3. Ensure Fly.io origins exist and are reachable for:

```text
fly.agent-api.toml
fly.mcp-gateway.toml
fly.llm-gateway.toml
```

4. Set Vercel preview/staging origin env values:

```text
STAGING_REWRITES_ENABLED
AGENT_API_BASE_URL
MCP_GATEWAY_BASE_URL
LLM_GATEWAY_BASE_URL
```

5. Verify hosted staging:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-browser-contract.ps1 -BaseUrl <STAGING_BASE_URL>
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-external-gates.ps1
```

## Expected Gate Effect

Only a real hosted artifact may close:

- `hosted_agent_api_contracts`
- `vercel_backend_origin_health`

The plan itself does not create production deployment, registry-push, live-provider, live MCP write, or release-readiness claims.
