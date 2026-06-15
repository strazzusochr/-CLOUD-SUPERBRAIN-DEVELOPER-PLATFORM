# 10 Tools / Cloud Hub - Visual Target

Route: `/tools`

Goal: professional MCP/control-room page for read-only tool execution and cloud-provider wiring. It should look like an IDE tool registry, not a marketing page.

Required layout:
- Header with read-only and no-secret-output language.
- Cloud wiring panel for Vercel/Fly/MCP/LLM origin status, status-only.
- Read-only execute panel wired to `POST /api/v1/tools/read-only/execute`.
- MCP tool table and provider grid as read-only inventory.

Element rules:
- `memory_read` and `task_router` execute buttons are real dry-run/read-only controls.
- Broader MCP rows are inventory, not active buttons.
- Write-capable scopes remain visibly gated.
- No provider mutation, no token output, no production claim.
