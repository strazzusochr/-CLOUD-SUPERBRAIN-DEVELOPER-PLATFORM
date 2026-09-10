# MCP Filesystem Project Progress Read Contract

Status: Implemented and DEV-ONLY runtime verified
Date: 2026-08-07
Owner layer: Layer 5 - MCP Gateway
Contract version: `filesystem-project-progress-read-v1`
Evidence ref: `filesystem_project_progress_read_verified`

## Purpose

This adapter provides one real, bounded filesystem read without opening a generic
filesystem capability. It reads only the image-baked
`docs/project-progress.manifest.json` copy and returns a strict allowlisted project
progress projection. It does not accept a path, filename, operation, provider
selection, or arbitrary query from the caller.

## Surfaces

| Purpose | Method | Path |
| --- | --- | --- |
| Public contract | `GET` | `/mcp/api/v1/filesystem/project-progress/contract` |
| Agent entry point | `POST` | `/api/v1/tools/read-only/execute` |
| Docker-internal MCP execution | `GET` | `/internal/v1/filesystem/project-progress` |

The Agent request is fixed to:

- `tool_id=filesystem_project_progress`
- `query=canonical-project-progress`

The internal endpoint requires the existing service token and exact
`SUPERBRAIN_RUNTIME_MODE=dev-only`. Nginx returns `404` for `/mcp/internal/`, and
the Vercel ASGI MCP boundary returns `404` for `/mcp/internal` and its subtree
before the service mount. Hosted execution remains disabled.

## Source and Bounds

- Image path: `/app/readonly/project-progress.manifest.json`
- Image mode: `0444`; parent directory mode: `0555`
- Maximum source size: `65536` bytes
- Read method: one descriptor with `O_NOFOLLOW` where supported, `fstat`, bounded
  descriptor reads, identity/size/mtime checks, and guaranteed close handling
- Encoding: strict UTF-8
- JSON: duplicate keys and non-standard constants are rejected
- Source identity: `progress_source=docs/project-progress.manifest.json`
- Horizontal IDs: exact ordered `phase_0` through `phase_6`
- Vertical IDs: exact ordered `layer_1` through `layer_7`
- Percent values: integer, not Boolean, from `0` through `100`

The response exposes only:

- `overall_percent`
- `horizontal[]` with exact `{id, percent}` fields
- `vertical[]` with exact `{id, percent}` fields
- `last_verified`
- `source_sha256`
- `bytes_read`

No path, filename, raw file content, label/status bulk, or unknown response field
crosses the Agent boundary.

## Audit and Correlation

The MCP Gateway persists an authorization audit before the descriptor is opened
and a completion audit after a successful read. Both events share the same
`trace_id`, `tool_request_id`, `run_id`, and `session_id`; their phase tags are
`read_phase:authorized` and `read_phase:completed`. The Agent API reads both audit
rows back, verifies the shared identity and source hash, and only then persists
its own `read_only_tool_executed` event and returns the result.
Successful responses must expose `audit_before_read=true` and
`audit_after_read=true`.

Pre-audit failure prevents the read. Completion-audit failure, source validation
failure, low-level I/O failure, malformed/oversize MCP response, trace mismatch,
or audit-identity mismatch withholds the result. Timeout is three seconds with no
retry.

## Verification

- `11` focused MCP unit tests pass; one Windows-only symlink case is skipped when
  the platform cannot create the link.
- `8/8` focused Agent API unit tests pass.
- `scripts/verify-mcp-filesystem-project-progress.ps1` passes statically and
  against `http://localhost:8081` with a real read and persisted audit readback.
- A real Chromium click on `/tools` selects the DEV-ONLY adapter, submits the
  canonical request, and verifies the bounded result plus audit flags (`1/1`).
- Docker health is `10/10` after `scripts/start-dev-live.ps1`.

This evidence is `DEV-ONLY; hosted proof still blocked`. It creates no progress
credit. Overall remains `89%`; MCP Gateway remains `56%`.

## Non-Claims

- No generic filesystem read or caller-selected path is enabled.
- No filesystem write or live MCP write is enabled.
- No direct or live provider call is made by this adapter.
- No database, GitHub, Playwright, E2B, registry, deployment, release, or
  production action is performed.
- No secret value or raw manifest content is returned.
- No hosted execution or production readiness is claimed.
