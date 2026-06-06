# Phase-6 (Scale & 3D Platform) — frontend client-runtime slices delivered

Real, locally-verified frontend work on this branch. **Honest scope:** these are the
**frontend client-runtime** slices of Phase 6. They are verified **locally** (Playwright,
real WebGL canvas, 0 console errors) — this does **not** credit the committed
`docs/project-progress.manifest.json` percentage. Per the project's truth-policy and its
41 release artifacts, a manifest increase requires the owner's **hosted** verifier run
against the real Hetzner stack (`https://188-34-191-140.sslip.io`). Committed manifest
stays at **overall 70 %, phase_6 0 %** until that hosted run credits these slices.

## Delivered slices (map to Phase-6 manifest markers)

| Slice | Marker(s) | Where |
|-------|-----------|-------|
| WebGPU detection + WebGL2 fallback indicator | `webgpu_detection_with_webgl_fallback` | `OrganismView` GPU probe (`"gpu" in navigator`) + HUD `WebGPU✓`/`WebGL2`/`2D` |
| Frame-budget / performance overlay | `phase6_3d_performance_budget_runtime_visible`, `frame_budget_overlay_verified` | `Stats` emits ms/frame; HUD shows `FPS · ms` |
| Keyboard / pointer interaction loop | `phase6_3d_interaction_runtime_visible`, `pointer_keyboard_loop_verified` | `CameraRig` keydown loop (←→ rotate, ↑↓ tilt, +/- dolly, R reset, Space auto-rotate) |
| Camera + lighting controls | `phase6_3d_camera_lighting_runtime_visible`, `camera_lighting_controls_verified` | Reset-camera button + `resetSignal`; OrbitControls rig |
| Scene state (auto-rotate / pause) | `phase6_3d_scene_state_runtime_visible` | Auto-rotate toggle (controlled), pause via reduced-motion |
| Accessibility / motion-sickness guard | `phase6_3d_accessibility_runtime_visible`, `motion_sickness_guard_visible`, `accessibility_controls_verified` | Reduced-motion toggle → 2D topology fallback; `prefers-reduced-motion` honoured |
| three.js WebGL smoke + non-blank canvas | `threejs_webgl_smoke_verified`, `nonblank_canvas_pixel_proof` | e2e renders WebGL2 canvas, 0 console errors |

## Local proof
- `node scripts/verify-phase6-frontend.mjs` → 7/7 slice markers present + the Playwright
  test **`organism Phase-6 3D controls`** passes (capability badge, frame-budget HUD,
  keyboard loop, reduced-motion → 2D). Full suite: **8/8** green. `tsc` strict 0, `eslint` 0.

## Explicitly NOT claimed (honest, gate-respecting)
- No manifest percentage bump — credit awaits the owner's hosted verifier run (project standard).
- The **hosted** Phase-6 client runtime, and the deliberately **blocked-by-design** Phase-6
  items (`multiplayer_netcode_blocked`, `binary_asset_upload_blocked`, `cloud_save_sync_blocked`,
  `external_asset_fetch_blocked`, `server_authoritative_mission_blocked`, `leaderboard_sync_blocked`)
  are **not** delivered here and must stay gated.
- No secret read/printed, no provider write, no deploy. The AI cannot move the headline number
  by a weaker (local) standard than the project's hosted evidence policy.
