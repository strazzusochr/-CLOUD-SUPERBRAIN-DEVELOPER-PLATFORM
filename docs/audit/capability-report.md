# Capability Report — MCP / Agents / Skills (honest, evidence-based)

No claim here is made without evidence from this build session or the repo.

## Agents (Claude subagents / workflows) — USED ✅
- **3 Explore subagents** (read-only) ran the platform audit: backend/API/audit-infra,
  22-route map, and /organism 3D quality. Evidence: this session's transcript + agent logs.
- **Workflow #1** `platform-quality-audit` (`wf_1a072565-c0d`): 6 parallel dimension
  auditors + 1 synthesis — 7 agents, ~694k tokens, 250 tool uses. Applied in `53d8b83`.
- **Workflow #2** `platform-quality-audit` (`wf_36841338-681`): 6 parallel read-only Explore
  auditors (design-consistency, accessibility, content-honesty, responsive, code-quality,
  organism-3d) + 1 synthesis agent — **7 agents, ~514k subagent tokens, 251 tool uses**.
  Produced a verified 19-item punch-list (9 false positives self-dropped); items 1–18
  applied in `5d46705`, item 19 in `a5b8a5f`. Findings included a real fake-live badge, a
  901–1279px responsive dead zone, and 3D state-colour binding gaps — all fixed + verified.
- Status: **PASS** — agents demonstrably used to build *and* harden this platform.

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
