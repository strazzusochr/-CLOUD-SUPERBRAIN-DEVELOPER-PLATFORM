# Docker Desktop WSL2 Readiness

Status: `active`

## Purpose

Docker Desktop is ready only when the Docker server answers `docker info --format '{{.ServerVersion}}'`.

Running Docker Desktop processes, tray icons, or WSL processes are diagnostics only. They are never readiness proof.

Docker-dependent scripts should call:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\require-docker-readiness.ps1 -GateName "<gate-name>"
```

This makes blocked gates fail explicitly before compose/build/backup logic starts.

## Readiness Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-docker-readiness.ps1
```

Report-only mode for Codex/session diagnostics:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-docker-readiness.ps1 -ReportOnly -OutputPath .phase1-artifacts\docker-readiness.json
```

## Failure Classification

If Docker does not answer `docker info`, mark Docker-dependent gates explicitly:

- `[BLOCKED] docker-compose gates`
- `[SKIPPED-REASON: docker-unavailable] docker-dependent verification`

Do not mark Docker gates as complete from process checks.

## Self-Heal Order

The verifier supports guarded self-heal mode:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-docker-readiness.ps1 -AttemptSelfHeal
```

Self-heal waits at least 120 seconds before actions, then tries:

1. `wsl --shutdown`, start Docker Desktop, wait, rerun `docker info`.
2. `wsl --update`, `wsl --shutdown`, start Docker Desktop, wait, rerun `docker info`.

The destructive Docker distro reset path is not allowed by default. It requires an explicit destructive flag:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-docker-readiness.ps1 -AttemptSelfHeal -AllowDestructiveDockerReset
```

Use that only when Docker data loss is acceptable.

## Required Diagnostics On Block

The verifier records:

- `docker info` exit code and output excerpt
- `wsl --status` exit code and output excerpt
- `wsl -l -v` exit code and output excerpt
- Docker pipe existence for `\\.\pipe\dockerDesktopLinuxEngine`
- Process list as diagnostic-only context

## Non-Claims

This runbook does not prove cloud readiness.

This runbook does not authorize production deployment.

This runbook does not replace hosted staging, GHCR, Vercel, branch-protection, or owner-decision gates.
