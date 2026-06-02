# Capability Report — MCP / Agents / Skills (honest, evidence-based)

No claim here is made without evidence from this build session or the repo.

## Agents (Claude subagents / workflows) — USED ✅
- **3 Explore subagents** (read-only) ran the platform audit: backend/API/audit-infra,
  22-route map, and /organism 3D quality. Evidence: this session's transcript + agent logs.
- **1 Workflow** `platform-quality-audit` (run `wf_1a072565-c0d`): 6 parallel dimension
  auditors (a11y, responsive, design, code, honesty, nav) + 1 synthesis agent —
  7 agents, ~694k subagent tokens, 250 tool uses. Findings were applied in commit `53d8b83`.
- Status: **PASS** — agents demonstrably used to build/audit this platform.

## Skills — NOT used this session ⛔
- No `anthropic-skills` (frontend-design, verify, code-review, etc.) were invoked.
- Status: **BLOCKED** — no claim of skill use is made. (Available; simply not called.)

## MCP — dev-environment only; repo config BLOCKED ⚠️
- The dev environment exposes MCP servers; **context7 was used** to fetch current
  three.js / WebGPU / R3F docs while building the 3D path (evidence: tool calls this session).
- **No `.mcp.json` in the repo** → a platform-level "MCP connected" claim is **BLOCKED**
  until a repo MCP config exists.
- `scripts/00-run-full-audit.ps1 -ProbeMcp` runs `claude mcp list` and records the line
  count (never secret values) when the CLI is available.

## Hard non-claims
- "Opus 4.8 uses agents" is true for **this build session** (workflow + subagents),
  not asserted as a running platform runtime feature.
- No live MCP write, no live LLM call, no provider write, no deploy, no push performed.
- No secret value was read, printed, or written to the UI or git.
