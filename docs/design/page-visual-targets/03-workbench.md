# 03 Workbench Visual Target

Source: `docs/reference/ChatGPT Image 10. Juni 2026, 01_10_17.png` and `docs/END_ZIEL_GESAMTSPEC.md`.

Target:
- Industrial Developer Workbench, dense IDE layout, not a landing page.
- Top toolbar with project, branch, dry-run/runtime state, team and gated tool buttons.
- Three main panes: read-only explorer, editor, preview/assets.
- Bottom operational panes: prompt/run, agent assistance, terminal output, mini cortex.
- Preview tabs must switch visible state locally.
- File tree must open a file into the editor.
- Run must call a local dry-run endpoint, show terminal/result, and create evidence/artifact.
- Mini cortex must reflect run state without fake-live claims.
- Disabled controls must explain gate/owner requirement.

Non-claims:
- No production deploy.
- No live LLM provider call.
- No live MCP write.
- Localhost is DEV-ONLY proof.
