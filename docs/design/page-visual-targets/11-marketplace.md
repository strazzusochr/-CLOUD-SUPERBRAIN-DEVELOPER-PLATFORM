# 11 Marketplace - Visual Target

Route: `/marketplace`

Goal: marketplace/catalog for skills, agents, MCP tools, and models with dry-run install planning only. Visual style follows the compact industrial blueprint: list/card density, small badges, thin borders, no cartoon tiles.

Required layout:
- Header with dry-run/spec catalog state.
- Category chips are visual filters only unless wired.
- Primary action panel lets the user select an item, view details, and create an install dry-run plan.
- Catalog cards are read-only inventory; installs happen through the action panel to keep proof deterministic.

Element rules:
- Details button must produce visible `PASS marketplace_details`.
- Install dry-run must persist a local artifact through `POST /api/v1/workspace/artifacts` and show `provider_writes=false`.
- No registry pull, no provider write, no live LLM/MCP activation.
- No Hetzner, GitKraken, Oracle active defaults.
