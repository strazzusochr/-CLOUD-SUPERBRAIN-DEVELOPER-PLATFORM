# 14 Apps - Visual Target

Route: `/apps`

Goal: generated-app output index for real task/session projections. The page should look like an IDE output browser with compact cards, status badges, and direct Workbench/Evidence handoff.

Required layout:
- Header with app-output purpose, runtime/live state, and Workbench entry.
- Prominent local artifact action panel wired to the common workspace artifact pipeline.
- Dense output cards when real tasks exist; otherwise a clear empty state.
- Each card shows task type, description, agent/status, and same-origin review/open links.

Element rules:
- "Create local dry-run artifact" must create a local app artifact and show `provider_writes=false`.
- Card links navigate only to local Workbench/Evidence surfaces.
- Empty states must not imply generated apps exist.
- No provider write, no live LLM call, no production claim.
