# 09 Files Local Visual Target

- Route: `/files/local`
- Style: IDE-style read-only file surface with tree, preview, and disabled search.
- Required: root chips, file tree spec, preview spec, Local-Files contract probe.
- Data boundary: `/api/v1/files/local/contract`; host filesystem is not mounted.
- Non-claims: no live filesystem reads, no writes, no `.env` or secret output.
- Reference: `docs/reference/` industrial blueprint and current design screenshots.
