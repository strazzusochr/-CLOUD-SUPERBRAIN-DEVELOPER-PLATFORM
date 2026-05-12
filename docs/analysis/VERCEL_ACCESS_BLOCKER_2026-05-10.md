# Vercel Access Readiness History

Stand: 2026-05-11

Repo: `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`

## Purpose

This document records the Vercel readiness truth without storing or exposing token values.

It exists so another AI agent or human reviewer can distinguish between:

- missing local token;
- invalid token;
- reachable Vercel API with no project visibility;
- correct project/team deploy readiness.

## Current Verdict

Vercel access is ready as of the latest 2026-05-11 verification.

Classification:

```text
project_visible_with_configured_team
```

Evidence artifact:

```text
.phase1-artifacts\vercel-access-20260510.json
```

Verifier:

```text
scripts\verify-vercel-access.ps1
```

Suite registration:

```text
scripts\verify.ps1 -Suite tooling-readiness -ReportOnly -MaxWaitSeconds 1
```

## What Was Verified

The verifier loaded local credentials transiently from:

```text
C:\Users\immer\.codex\secrets\cloud-superbrain.local.env
```

No secret values were printed or written.

Configured non-secret Vercel identifiers:

```text
project_id=prj_ZbSNRVz5ijLQ4tQR61liHFw1x5eY
team_id=team_v9yzEnXKNsbQMEIrdf0pd4RT
project_name=frontend
```

Historical 2026-05-10 read-only Vercel REST probes:

| Probe | Result |
| --- | --- |
| `GET /v9/projects/<project>?teamId=<team>` | `404 not_found` |
| `GET /v9/projects/<project>` | `404 not_found` |
| `GET /v9/projects?teamId=<team>&limit=100` | `200`, `project_count=0` |
| `GET /v9/projects?limit=100` | `200`, `project_count=0` |

Historical interpretation:

- The token is present.
- The Vercel API is reachable.
- The token is not simply malformed at HTTP level, because project list probes return `200`.
- The configured project is not visible to the current token/account/team scope.

Latest 2026-05-11 interpretation:

- The token is present.
- The Vercel API is reachable.
- The configured project/team scope is visible.
- `safe_to_deploy_via_vercel=True`.

## Required Fix

No Vercel access remediation is currently required. These were the historical remediation options before the 2026-05-11 ready result:

1. The current `VERCEL_TOKEN` is replaced with a token that can read project `prj_ZbSNRVz5ijLQ4tQR61liHFw1x5eY` under team `team_v9yzEnXKNsbQMEIrdf0pd4RT`.
2. The Vercel project is relinked and `apps\frontend\.vercel\project.json` is updated to the project/team that the token can read.
3. Vercel is explicitly removed from the required cloud scope and documented as a non-claim.

## Pass Criteria

The blocker is cleared only when this command returns `status=ready`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-vercel-access.ps1 -ReportOnly -OutputPath .phase1-artifacts\vercel-access-20260510.json
```

Expected ready semantics:

```text
classification=project_visible_with_configured_team
safe_to_deploy_via_vercel=True
```

## Fail-Closed Rules

Even with Vercel access ready:

- do not claim full production release readiness while release-boundary remains blocked;
- keep `verify-vercel-access.ps1` green before any Vercel deploy, env mutation, or promotion;
- keep owner-decision and worktree/rebaseline gates separate from Vercel access readiness.

## Non-Claims

- This document does not prove Cloudflare, Hetzner, GHCR, or GitHub readiness.
- This document does not authorize production deployment.
- This document does not contain token values.
