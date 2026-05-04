# Cloud Secret Runtime Injection

Status: active, token-free

## Purpose

Cloud provider tokens must never live in repository files, generated docs, Docker Compose defaults, screenshots, or verifier artifacts.

The cloud inventory endpoints read provider credentials only from process environment variables injected into the running service.

## Runtime Keys

The Agent API can consume these environment variable names:

- `VERCEL_TOKEN`
- `STAGING_BASE_URL`
- `HETZNER_API_TOKEN`
- `CLOUDFLARE_API_TOKEN`
- `GITHUB_TOKEN`
- `BRANCH_PROTECTION_TOKEN`
- `GHCR_TOKEN`
- `HF_TOKEN`
- `GITLAB_TOKEN`
- `GITKRAKEN_API_TOKEN`

Optional metadata keys:

- `VERCEL_PROJECT_ID`
- `VERCEL_ORG_ID`
- `HETZNER_PROJECT_ID`
- `HETZNER_SERVER_ID`
- `HETZNER_SERVER_NAME`
- `HETZNER_SERVER_TYPE`
- `HETZNER_SERVER_LOCATION`
- `HETZNER_SERVER_IPV4`
- `HETZNER_SERVER_IPV6_CIDR`
- `HETZNER_PRIMARY_IPV4_ID`
- `HETZNER_PRIMARY_IPV6_ID`
- `HETZNER_VOLUME_ID`
- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_ZONE_ID`
- `CLOUDFLARE_AI_GATEWAY_URL`
- `CLOUDFLARE_DASHBOARD_URL`
- `GITHUB_REPOSITORY`
- `GHCR_OWNER`
- `GHCR_PACKAGE`
- `HF_PROFILE_URL`
- `GITLAB_PROFILE_URL`
- `GITLAB_API_URL`
- `GITKRAKEN_ORG_ID`
- `GITKRAKEN_ORG_NAME`
- `GITKRAKEN_DASHBOARD_URL`
- `GITKRAKEN_API_URL`

## Local Rule

For local testing, inject secrets into the shell or Docker runtime from a private secret store that is outside the repository. Do not write real values to `.env`, `.env.example`, docs, Compose files, PowerShell history snippets, or generated artifacts.

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
