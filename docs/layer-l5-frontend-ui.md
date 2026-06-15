## L5 — Frontend & UI (Next.js 15, Organism, Workbench)

### Implementierung (Ist-Stand)

- Next.js 15 App Router mit zentralen Surfaces (Home, Workbench, Organism, Tools, Evidence, Diagnostics, usw.).
- 3D Organism (Three.js/R3F) + Reduced Motion Support.
- Browser Contracts (Marker/Contracts) fuer UI/Runtime sind implementiert.

### Wiring (L5 ↔ L4)

- UI konsumiert agent-api/mcp/llm Surfaces ueber nginx (`http://localhost:8081`).
- Rewrites/Origins fuer Hosted sind env-gated (keine Fake-Live Calls).

### Verifikation (DEV-ONLY)

- `npm --prefix apps/frontend test` (Playwright E2E) prueft UI-Flaechen + Organism Rendering.
- `npm run verify:browser` prueft Title/Favicon + Contract Surfaces.
