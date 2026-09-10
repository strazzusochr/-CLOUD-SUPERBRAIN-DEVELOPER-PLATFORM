# Phase 6 3D Save And Load Runtime

Contract: `phase6-3d-save-load-runtime-v1`

Endpoint: `GET /api/v1/phase6/3d-save-load/contract`

Evidence: `phase6_3d_save_load_runtime_visible`

## Runtime boundary

The Organism surface can capture one typed snapshot containing fifteen allowlisted
camera, lighting, gameplay, and procedural asset fields. The snapshot exists only
in React component state. Load is disabled until a snapshot exists, restore applies
every field to the visible controls and Three.js runtime, and clear removes the
snapshot without mutating the already restored scene.

Reloading or unmounting the page discards the snapshot. The feature does not call
LocalStorage, IndexedDB, cookies, service-worker cache, cloud sync, an upload route,
or a server snapshot endpoint.

## Verified scenarios

- `scene_snapshot_capture_visible`
- `scene_snapshot_restore_visible`
- `scene_snapshot_clear_visible`
- `load_without_snapshot_blocked`
- `volatile_browser_memory_only`
- `persistent_browser_storage_blocked`
- `cloud_save_sync_blocked`
- `phase6_progress_gate_bound_to_save_load_verifier`

## Progress rule

Phase 6 may move from `56%` to `64%` only after the contract, source guards,
focused Chromium interaction proof, reload negative path, nonblank screenshot,
manifest update, and parent verifier integration all pass.

## Non-claims

- No persistent browser storage, cloud sync, binary upload, or server snapshot write
  is opened.
- No provider write, live MCP write, live provider call, production deployment,
  secret output, or release promotion is performed.
- Localhost evidence is `DEV-ONLY`; hosted proof remains separate.
