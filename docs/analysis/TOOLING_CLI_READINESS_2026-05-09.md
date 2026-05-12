# Tooling CLI Readiness

Stand: 2026-05-09
Repo: `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`
Secret source checked: `C:\Users\immer\.codex\secrets\cloud-superbrain.local.env`

## Purpose

This report records the current local CLI and provider-connectivity state for Phase 2 readiness and later cloud verification work.

No secret values are stored here. All token checks were done by loading local environment variables transiently.

## Installed CLI Status

| Tool | Status | Observed version/path | Notes |
| --- | --- | --- | --- |
| Node.js | installed | `C:\Program Files\nodejs\node.exe` | Node `v24.15.0` observed in tool error output |
| npm | installed | `C:\Program Files\nodejs\npm.ps1` | available |
| Vercel CLI | installed | `52.0.0` | `vercel whoami --token` works for account auth |
| Wrangler | installed | `4.84.1` | needs non-sandbox execution in this Codex environment; sandboxed run hits `spawn EPERM` |
| hcloud | installed | `1.62.2` | works with the known token file at `D:\PLATTFORM\HCLOUD_TOKEN.txt` |
| Git | installed | `C:\Program Files\Git\cmd\git.exe` | available |
| Git LFS | installed | `git-lfs/3.7.1` | available |
| GitKraken CLI | present outside PATH | `C:\Users\immer\AppData\Local\GitKrakenCLI\gk.exe` | direct executable exists; `gk` is not on PATH |

## Secret File Key Status

The local secret file exists and contains these relevant non-empty key names:

- `VERCEL_TOKEN`
- `VERCEL_TOKEN_BACKUP`
- `VERCEL_PROJECT_ID`
- `VERCEL_TEAM_ID`
- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_ZONE_ID`
- `CLOUDFLARE_PRODUCTION_DOMAIN`
- `HETZNER_API_TOKEN`
- `HF_TOKEN`
- `GITLAB_TOKEN`
- `GITKRAKEN_ORG_ID`
- `OWNER_DECISION`
- `RELEASE_CANDIDATE_STRATEGY`
- `LIVE_LLM_TEST_CALL_APPROVED`
- `LIVE_LLM_MAX_BUDGET_USD`

Missing from that file:

- `GITKRAKEN_API_TOKEN`
- `VERCEL_ORG_ID` by that exact name; file uses `VERCEL_TEAM_ID`
- `HCLOUD_TOKEN` by that exact name; file uses `HETZNER_API_TOKEN`

## Connectivity Results

| Provider/tool | Result | Evidence |
| --- | --- | --- |
| Vercel account auth | partial | `vercel whoami --token VERCEL_TOKEN` returned account `strazzusochr` |
| Vercel project access | failed | Vercel API returned `404 not_found` for env and `.vercel/project.json` project/team combinations |
| Vercel team listing | failed | Vercel API returned `403` for team listing with the current token |
| Vercel backup token | failed | CLI reported backup token is not valid |
| Cloudflare API token | verified | `GET /user/tokens/verify` returned HTTP `200`, `success=true`, `status=active` |
| Wrangler CLI | verified outside sandbox | `wrangler whoami` worked with `CLOUDFLARE_API_TOKEN`; sandboxed run hits `spawn EPERM` |
| Hetzner via `HETZNER_API_TOKEN` in local secret file | failed | `hcloud` rejected that token as unauthorized |
| Hetzner via `D:\PLATTFORM\HCLOUD_TOKEN.txt` | verified | `hcloud server list` returned `superbrain-staging-fsn1`, `running`, `cax21`, `188.34.191.140` |
| Hugging Face | verified | `whoami-v2` returned HTTP `200`, user `Wrzzzrzr` |
| GitLab | failed | `GET /api/v4/user` returned HTTP `401 Unauthorized` |
| GitKraken | blocked | `GITKRAKEN_API_TOKEN` is not present; only `GITKRAKEN_ORG_ID` is present |

## Commands Used

Representative commands, with secrets loaded transiently and not printed:

```powershell
vercel whoami --token $env:VERCEL_TOKEN
vercel api ("/v9/projects?teamId=" + $env:VERCEL_TEAM_ID) --token $env:VERCEL_TOKEN
wrangler whoami
hcloud server list -o columns=name,status,type,ipv4
```

Direct API probes were also used for Vercel, Cloudflare, Hugging Face, and GitLab via Node `fetch` to avoid Windows PowerShell TLS noise and to keep output sanitized.

## Current Required Fixes

1. Replace or correct the Vercel token/team/project binding so the token can access the project linked in `apps\frontend\.vercel\project.json`.
2. Replace the stale `HETZNER_API_TOKEN` in `C:\Users\immer\.codex\secrets\cloud-superbrain.local.env` with the known-good value source or add `HCLOUD_TOKEN` from the known-good source.
3. Replace the GitLab token if GitLab identity verification is required.
4. Add `GITKRAKEN_API_TOKEN` if GitKraken identity verification is required.
5. Add `C:\Users\immer\AppData\Local\GitKrakenCLI` to PATH only if `gk` must be callable without an absolute path.
6. Run Wrangler commands outside the current Codex sandbox or keep using Cloudflare API probes for non-mutating verification.

## Non-Claims

- This report does not authorize production deployment.
- This report does not store or reveal any token value.
- Vercel is not ready for deploy/promote until project access is verified.
- GitLab and GitKraken identity claims remain fail-closed.
- The local secret-file Hetzner token is not the currently verified Hetzner token source.

## 2026-05-10 Addendum

The Vercel blocker has now been rechecked through `scripts\verify-vercel-access.ps1`.

Evidence:

```text
.phase1-artifacts\vercel-access-20260510.json
```

Current classification:

```text
token_valid_but_project_not_visible
```

Observed read-only probes:

- configured project with configured team: `404 not_found`
- configured project without team: `404 not_found`
- project list with configured team: `200`, zero visible projects
- project list without team: `200`, zero visible projects

This means Vercel is blocked by project/team visibility, not by missing local token material.
