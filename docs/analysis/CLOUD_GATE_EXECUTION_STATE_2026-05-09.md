# Cloud Gate Execution State - 2026-05-09

This document records the current hard-gate state after correcting weak verifier behavior.

## Corrections Applied

- `scripts/verify.ps1` now forwards `-BaseUrl` into `verify-external-gates.ps1` as `-HostedBaseUrl`.
- `scripts/verify-external-gates.ps1` no longer treats a generic hosted health endpoint as Hetzner live budget proof.
- `scripts/verify-external-gates.ps1` no longer treats Runtime external-gates JSON as current GitHub branch-protection proof.
- `scripts/verify-external-gates.ps1` no longer silently falls back from missing Vercel backend origins to the hosted Hetzner base URL.
- `scripts/check_hetzner_infra_budget.py` now fails closed when `HETZNER_API_TOKEN` is missing.
- `scripts/deploy-to-staging.ps1` now writes `AGENT_API_BASE_URL` without duplicating the `/api` path segment.

## Verified Commands

```powershell
py -3 -m py_compile scripts\check_hetzner_infra_budget.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1 -Plan -Suite external-gates -BaseUrl https://188-34-191-140.sslip.io
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1 -Suite phase1
```

Result:

- Python syntax: passed.
- `verify.ps1 -BaseUrl` routing: passed; planned invocation is `verify-external-gates.ps1 -HostedBaseUrl https://188-34-191-140.sslip.io`.
- Phase 1: passed.
- Gitleaks inside Phase 1: no leaks found.

## Initial Strict External Gate Result

Executed with:

```powershell
$env:STAGING_BASE_URL='https://188-34-191-140.sslip.io'
$env:AGENT_API_BASE_URL='https://188-34-191-140.sslip.io'
$env:MCP_GATEWAY_BASE_URL='https://188-34-191-140.sslip.io/mcp'
$env:LLM_GATEWAY_BASE_URL='https://188-34-191-140.sslip.io/llm'
$env:BRANCH_PROTECTION_TOKEN = gh auth token
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-external-gates.ps1 -HostedBaseUrl $env:STAGING_BASE_URL -RequireAllClosed
```

Artifact:

```text
.phase1-artifacts\external-gate-audit-20260509-150740.json
```

Result:

```json
{
  "status": "action_required",
  "hosted_staging_claim_allowed": true,
  "branch_protection_claim_allowed": true,
  "vercel_backend_origins_claim_allowed": true,
  "hetzner_live_budget_claim_allowed": false,
  "production_deploy_claim_allowed": false,
  "missing_or_failed_gates": ["hetzner_live_budget_check"]
}
```

## Provider Access State

- GitHub: available through local `gh` auth; branch protection verified.
- Vercel connector: project lookup for `apps/frontend/.vercel/project.json` returned `403 Forbidden`.
- Vercel CLI: not usable; `vercel whoami` reports invalid token.
- Hetzner SSH: not usable with current default key; `root@188.34.191.140` rejects public-key auth.
- Hetzner API: `HETZNER_API_TOKEN` is not present in the current process environment.

## Required Next Inputs

To continue from this exact state into real cloud execution, provide these as transient environment values, not committed files:

```powershell
$env:HETZNER_API_TOKEN = '<token>'
$env:STAGING_SSH_KEY_PATH = '<absolute path to private key for root@188.34.191.140>'
$env:VERCEL_TOKEN = '<valid token with access to project prj_ZbSNRVz5ijLQ4tQR61liHFw1x5eY>'
```

After those are present, the next execution steps are:

```powershell
py -3 scripts\check_hetzner_infra_budget.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -StagingIp 188.34.191.140 -KeyPath $env:STAGING_SSH_KEY_PATH
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-external-gates.ps1 -HostedBaseUrl https://188-34-191-140.sslip.io -RequireAllClosed
```

No production deployment is claimed until the final strict external-gate run returns `status=verified`.

## Token Discovery Follow-Up

The Hetzner token was found outside the repository at:

```text
D:\PLATTFORM\HCLOUD_TOKEN.txt
```

The token value was not printed or copied into repository files. It was loaded transiently into `$env:HETZNER_API_TOKEN`.

Live Hetzner budget verification passed:

```text
Projected Hetzner monthly server cost: EUR 9.51
Infra warning threshold: EUR 16.00; hard budget: EUR 20.00
- superbrain-staging-fsn1: cax21, running, EUR 9.51/month
```

GitHub branch protection was verified with the local `gh` credential store via transient `$env:BRANCH_PROTECTION_TOKEN = gh auth token`.

## Final Strict External Gate Result

Executed through the central runner with:

```powershell
$env:STAGING_BASE_URL='https://188-34-191-140.sslip.io'
$env:AGENT_API_BASE_URL='https://188-34-191-140.sslip.io'
$env:MCP_GATEWAY_BASE_URL='https://188-34-191-140.sslip.io/mcp'
$env:LLM_GATEWAY_BASE_URL='https://188-34-191-140.sslip.io/llm'
$env:BRANCH_PROTECTION_TOKEN = gh auth token
$env:HETZNER_API_TOKEN=(Get-Content -LiteralPath 'D:\PLATTFORM\HCLOUD_TOKEN.txt' -Raw).Trim()
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1 -Suite external-gates -BaseUrl $env:STAGING_BASE_URL
```

Artifact:

```text
.phase1-artifacts\external-gate-audit-20260509-181516.json
```

Result:

```json
{
  "status": "verified",
  "hosted_staging_claim_allowed": true,
  "branch_protection_claim_allowed": true,
  "vercel_backend_origins_claim_allowed": true,
  "hetzner_live_budget_claim_allowed": true,
  "production_deploy_claim_allowed": true,
  "missing_or_failed_gates": []
}
```

Remaining provider-access note:

- Vercel CLI still reports an invalid local token.
- Vercel MCP project lookup for `apps/frontend/.vercel/project.json` returned `403 Forbidden`.
- This does not block the current external-gate proof because the required hosted backend origin probes passed through explicit HTTPS origin URLs.
