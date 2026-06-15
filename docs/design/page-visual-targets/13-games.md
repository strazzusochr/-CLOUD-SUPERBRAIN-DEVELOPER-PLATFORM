# 13 Games - Visual Target

Route: `/games`

Goal: game-project workspace surface inside the industrial developer platform. It should feel like a compact game-production desk: templates, scene/task preview, assets, and a real Workbench handoff without fake rendered gameplay.

Required layout:
- Header with game workflow purpose, runtime/live state, and Workbench entry.
- Left template rail with compact game categories.
- Center scene/task preview panel that only shows real runtime tasks or an honest empty state.
- Right assets panel for indexed assets/read-only handoff.
- Local artifact action panel wired to `POST /api/v1/workspace/artifacts`.

Element rules:
- "Create local dry-run artifact" must create a local game artifact and show `provider_writes=false`.
- Workbench/Organism/Files links are same-origin navigation only.
- Scene and asset previews must not fake generated gameplay or media.
- No provider write, no live LLM call, no production claim.
