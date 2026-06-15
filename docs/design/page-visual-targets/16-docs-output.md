# 16 Docs Output - Visual Target

Route: `/docs-output`

Goal: document-output workspace for real assistant/session results and gated export plans. It should feel like a technical document desk: document list, preview pane, citation/export controls.

Required layout:
- Header with document-output purpose, runtime/live state, and Workbench entry.
- Left document list from real session outputs or an honest empty state.
- Center preview pane that renders only real assistant output.
- Right export panel with common artifact creation and PDF/MD PlanOnly buttons.

Element rules:
- "Create local dry-run artifact" must create a local document artifact and show `provider_writes=false`.
- PDF and MD export buttons must create local PlanOnly artifacts and show `provider_writes=false`.
- Export remains gated; no file/provider mutation is claimed.
- No live LLM call, no production claim, no secret output.
