# Orchestrator Completion Evidence

Contract version: `orchestrator-completion-evidence-v1`

Evidence reference: `orchestrator_completion_evidence_verified`

Endpoint: `GET /api/v1/orchestrator/completion/contract`

## Scope

This contract closes the final locally provable Orchestrator / LangGraph layer gap. It binds the existing deterministic graph to one reproducible completion matrix instead of treating separate feature contracts as sufficient evidence.

The focused verifier must execute three fresh graph runs: a complete four-role success path, a policy hard-stop for production deploy plus main merge, and a controlled tester MCP timeout that terminates as an explicit partial failure. Each run must remain on LangGraph with PostgreSQL checkpointing and must be correlated with checkpoint and audit evidence.

## Required Runtime Proof

- Success reaches `completed`, includes planner, coder, tester, and devops result envelopes, and proves aggregation, LLM streaming completion, completed assignments, read-only MCP success, and memory update persistence.
- Policy input reaches `hard_stop` with `policy_or_budget_guard_rejected`, detects both forbidden actions, and creates no task assignment or MCP call.
- Forced tester MCP timeout reaches a terminal `completed` graph with `partial_failure=true`, a tester timeout envelope, persisted MCP audit, and controlled-error evidence.
- Success and hard-stop checkpoints are found through the PostgreSQL checkpoint endpoint and corresponding completion/stopped audit events are correlated by thread id.
- The parent runtime verifier proves SSE event/replay behavior, checkpoint survival across Agent API recreation, and post-recreate steady state.
- Chromium selects `Orchestrator Completion Evidence` through the real Diagnostics LiveConsole, loads the contract with HTTP 200, and writes a screenshot without console or page errors.

## Closed Boundaries

The proof uses deterministic dry-run LLM routing and read-only MCP envelopes. It does not activate live LLM providers, live MCP writes, provider writes, production deployment, registry publication, release promotion, or secret output. Localhost evidence remains `DEV-ONLY` and does not close hosted staging or production parity.

## Progress Gate

The Orchestrator vertical layer may move from `99%` to `100%` only after the dedicated verifier, parent static/runtime/browser gates, manifest integrity, truth mirrors, production build, lint, and secret scan all pass. Horizontal phase percentages and Overall remain unchanged.
