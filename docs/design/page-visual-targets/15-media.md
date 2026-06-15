# 15 Media - Visual Target

Route: `/media`

Goal: media workflow surface for image/video/audio planning without fake generation. It should use the same industrial panel language as Workbench: storyboard rail, media stage, prompt/action panel.

Required layout:
- Header with media workflow purpose and runtime/live state.
- Left storyboard rail showing real media-like tasks or an honest empty state.
- Center media stage with non-interactive mode chips and no fake preview output.
- Right prompt brief with local artifact action panel.

Element rules:
- "Create local dry-run artifact" must create a local media artifact and show `provider_writes=false`.
- Image/Video/Audio chips are decorative unless future wiring adds real state/results.
- Media generation/previews must remain absent unless backed by real artifacts.
- No provider write, no live LLM call, no production claim.
