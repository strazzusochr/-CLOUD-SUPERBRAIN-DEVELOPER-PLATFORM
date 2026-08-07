# MCP Version Pinning Contract

Status: Implemented local runtime contract
Date: 2026-04-29
Phase: Phase 4 / L-08
Owner layer: Layer 5 - MCP Gateway

## Purpose

This contract closes audit gap `L-08`: MCP Gateway dependencies and tool contracts must be version-pinned so tool compatibility cannot silently drift. The proof is local and deterministic; it does not enable live MCP writes.

## Runtime Endpoint

| Purpose | Method | Path | Evidence |
| --- | --- | --- | --- |
| Public MCP version pinning contract | `GET` | `/mcp/api/v1/version-pinning/contract` | `mcp_version_pinning_contract_visible` |

## Pinned Gateway

| Field | Value |
| --- | --- |
| Service | `mcp-gateway` |
| App version | `0.1.0` |
| Runtime | `python:3.14-slim` |
| Requirements file | `services/mcp-gateway/requirements.txt` |
| Dependency pin policy | `exact_version_required` |

Pinned dependencies:

- `fastapi==0.136.3`
- `uvicorn[standard]==0.49.0`
- `pydantic==2.13.4`

## Pinned Tool Contracts

| Toolset | Capability | Contract version | Endpoint |
| --- | --- | --- | --- |
| `github` | `plan_branch_pr` | `github-branch-pr-plan-v1` | `GET /mcp/api/v1/github/branch-pr/contract` |
| `postgresql` | `query_readonly` | `postgresql-readonly-query-v1` | `GET /mcp/api/v1/postgresql/readonly-query/contract` |
| `filesystem` | `plan_workspace_access` | `filesystem-workspace-scope-v1` | `GET /mcp/api/v1/filesystem/workspace-scope/contract` |
| `filesystem` | `read_project_progress` | `filesystem-project-progress-read-v1` | `GET /mcp/api/v1/filesystem/project-progress/contract` |
| `playwright` | `plan_browser_proof` | `playwright-browser-proof-v1` | `GET /mcp/api/v1/playwright/browser-proof/contract` |
| `e2b` | `plan_sandbox_lifecycle` | `e2b-sandbox-lifecycle-v1` | `GET /mcp/api/v1/e2b/sandbox-lifecycle/contract` |

## Request Contract

- Model: `ToolRequest`.
- Toolset pattern: `^(github|e2b|playwright|filesystem|postgresql|puppeteer)$`.
- `session_id`: UUID or null.
- `timeout_ms`: 1 to 1800000.
- `retry_budget`: 0 to 2.
- `redaction_required`: defaults to true.

## Drift Policy

- Every runtime dependency in `services/mcp-gateway/requirements.txt` must use exact `==` pinning.
- Every exposed MCP tool contract must publish a stable `contract_version`.
- Adding or changing a tool capability requires updating this endpoint, docs, UI, and verifiers in the same change.
- Unknown toolsets or scope-violating capabilities fail closed before live execution.
- Live mutations remain disabled until a separate external gate and human review are configured.

## Evidence

- `GET /mcp/api/v1/version-pinning/contract` returns `mcp-version-pinning-v1`.
- The additive `filesystem-project-progress-read-v1` pin covers the fixed DEV-ONLY read adapter without changing the global v1 pinning contract.
- Frontend renders `MCP Version Pinning Contract` with `mcp_version_pinning_contract_visible`.
- Static, runtime, hosted, and browser-contract verifiers assert exact dependency pins, pinned tool contract versions, drift policy, evidence refs, and non-claims.

## Non-Claims

- This contract does not enable live MCP writes; No live MCP write path is opened by this proof.
- This contract does not claim an external MCP server version beyond the local gateway and its pinned Python dependencies.
- This contract does not claim production deployment or hosted staging success.
