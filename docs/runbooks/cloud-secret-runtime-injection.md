# Cloud Secret Runtime Injection

Status: active, token-free

## Purpose

Cloud provider tokens must never live in repository files, generated docs, Docker Compose defaults, screenshots, or verifier artifacts.

The cloud inventory endpoints read provider credentials only from process environment variables injected into the running service.

## Runtime Keys

The Agent API can consume these active environment variable names:

- `VERCEL_TOKEN`
- `STAGING_BASE_URL`
- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_STATEFUL_BASE_URL`
- `GITHUB_TOKEN`
- `BRANCH_PROTECTION_TOKEN`
- `GHCR_TOKEN`
- `HF_TOKEN`
- `GITLAB_TOKEN`
- `GRAFANA_CLOUD_API_KEY`

Optional metadata keys:

- `VERCEL_PROJECT_ID`
- `VERCEL_ORG_ID`
- `CLOUDFLARE_ZONE_ID`
- `CLOUDFLARE_AI_GATEWAY_URL`
- `CLOUDFLARE_DASHBOARD_URL`
- `GITHUB_REPOSITORY`
- `GHCR_OWNER`
- `GHCR_PACKAGE`
- `HF_PROFILE_URL`
- `GITLAB_PROFILE_URL`
- `GITLAB_API_URL`
- `GRAFANA_CLOUD_URL`

Historical read-only inventory compatibility may consume `FLY_API_TOKEN`,
`FLY_ORG_SLUG`, `FLY_APP_NAME`, `FLY_MACHINE_ID`, `FLY_REGION`, and
`FLY_DASHBOARD_URL`. These values cannot satisfy an active gate and must not be
required by readiness or rollout tooling.

## Local Rule

For local testing, inject secrets into the shell or Docker runtime from a private secret store that is outside the repository. Do not write real values to `.env`, `.env.example`, docs, Compose files, PowerShell history snippets, or generated artifacts.

The canonical local helper for transient shell injection is:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\import-local-env.ps1
```

By default it reads `C:\Users\<user>\.codex\secrets\cloud-superbrain.local.env`, sets process environment variables only, does not print values, and does not overwrite already-set process variables. It also fills safe alias names when the target is missing:

- `VERCEL_TEAM_ID -> VERCEL_ORG_ID`
- `VERCEL_ORG_ID -> VERCEL_TEAM_ID`
- `FLY_TOKEN -> FLY_API_TOKEN` (historical read-only inventory only)
- `GITHUB_TOKEN -> BRANCH_PROTECTION_TOKEN`

Use `scripts\verify-all-gates-with-tokens.ps1` for external gate verification with the same private env bootstrap. Optional identity provider tokens remain optional unless the verifier is run with an explicit strict identity policy.

Validate the bootstrap behavior without real tokens by running:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-env-bootstrap.ps1
```

The verifier uses only dummy values, confirms alias filling and no-overwrite behavior, and fails if the helper prints secret-like values.

`GET /api/v1/clouds` and `GET /api/v1/clouds/layers` must show only:

- env key names
- configured/missing booleans
- sanitized provider metadata
- masked IP addresses
- non-claim text

## Rotation

Rotate any token that has appeared in chat, screenshots, repository files, terminal history, or generated artifacts. After rotation, rerun:

- `py -3 scripts\secret_scan_fallback.py`
- `gitleaks detect --no-git --source . --config .gitleaks.toml --redact`
- `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`

## Non-Claims

This document does not contain provider tokens.

This document does not authorize production deployment.

This document does not replace the hosted staging, branch protection, gitleaks, live budget, and owner review gates.
