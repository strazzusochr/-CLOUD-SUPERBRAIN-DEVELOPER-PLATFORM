# Phase 6 3D Camera And Lighting Runtime

## Contract

- Version: `phase6-3d-camera-lighting-runtime-v1`
- Endpoint: `GET /api/v1/phase6/3d-camera-lighting/contract`
- Evidence: `phase6_3d_camera_lighting_runtime_visible`
- Strategy: `local_camera_rig_lighting_profile_state`
- Frontend: `/organism`

The client exposes three camera presets (`wide`, `close`, `top`), safe FOV steps
(`38`, `45`, `58` degrees), three bounded lighting profiles (`studio`, `night`,
`sunrise`), and an exposure control limited to `0.72..1.18` in `0.02` steps.

## Runtime Requirements

- `camera_preset_switch_visible`: each preset is visible and applied to the active
  Three.js perspective camera.
- `fov_step_control_visible`: only the declared safe FOV steps are accepted.
- `lighting_profile_switch_visible`: profile changes update bounded scene lights,
  environment lightformers, bloom, and renderer exposure.
- `safe_exposure_bounds_visible`: both bounds are reachable and values outside the
  interval are clamped.
- `camera_lighting_state_overlay_visible`: selected state is visible in the UI and
  applied state is mirrored through runtime data attributes.
- `local_camera_lighting_state_only`: control changes stay in browser memory and do
  not issue API or provider requests.
- `cloud_render_boundary_still_closed`: this is a lightweight client proof, not a
  server GPU, benchmark, or heavy local workload.
- `phase6_progress_gate_bound_to_camera_lighting_verifier`: progress changes only
  after contract, source, browser, screenshot, manifest, and documentation proof.

## Evidence

`scripts/verify-phase6-3d-camera-lighting-runtime.ps1` checks the runtime contract,
all eight guarded scenarios, source markers, manifest status, and the focused Chromium
test in `apps/frontend/e2e/organism.spec.ts`. The browser test clicks every camera and
lighting mode, changes FOV, reaches both exposure bounds, resets the selected camera,
asserts the applied Three.js state, confirms no XHR/fetch occurs during control changes,
checks for console errors, and writes `phase6-camera-lighting.png`.

The established rubric allows Phase 6 to move from `32%` to `40%` after all of those
proofs pass. Overall is recomputed by the manifest verifier; no other phase or vertical
layer is changed by this bounded slice.

## Non-Claims

- Localhost evidence is `DEV-ONLY`; hosted staging proof is not claimed.
- No shader hotload or external asset fetch is performed.
- No server-side GPU, benchmark, load test, or heavy local render is started.
- No provider write, live MCP write, live provider call, secret use/output,
  production deployment, registry push, or release promotion is performed.
