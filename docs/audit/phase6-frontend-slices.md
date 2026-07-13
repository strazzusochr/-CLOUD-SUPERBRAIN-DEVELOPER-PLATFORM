# Phase-6 (Scale & 3D Platform) — frontend client-runtime slices delivered

Real frontend work on this branch with local and hosted runtime proof. **Honest scope:**
these are the **frontend client-runtime** slices of Phase 6. The verifier exercises a
real WebGL canvas, camera presets, bounded lighting controls, deterministic gameplay state, a procedural asset policy, volatile scene save/load, deterministic two-peer browser loopback, a volatile local Top 3, bounded frame-budget classification, keyboard input, frame-budget HUD, and the 2D
reduced-motion fallback with zero browser-console errors. The current hosted proof ran
against `https://frontend-seven-psi-78.vercel.app`; it does not claim that every Phase-6
scale capability or any production release is complete.

## Delivered slices (map to Phase-6 manifest markers)

| Slice | Marker(s) | Where |
|-------|-----------|-------|
| WebGPU detection + WebGL2 fallback indicator | `webgpu_detection_with_webgl_fallback` | `OrganismView` GPU probe (`"gpu" in navigator`) + HUD `WebGPU✓`/`WebGL2`/`2D` |
| Frame-budget / performance overlay | `phase6_3d_performance_budget_runtime_visible`, `frame_budget_overlay_verified` | `Stats` emits ms/frame; HUD shows `FPS · ms` |
| Keyboard / pointer interaction loop | `phase6_3d_interaction_runtime_visible`, `pointer_keyboard_loop_verified` | `CameraRig` keydown loop (←→ rotate, ↑↓ tilt, +/- dolly, R reset, Space auto-rotate) |
| Camera + lighting runtime | `phase6_3d_camera_lighting_runtime_visible`, `camera_lighting_controls_verified` | Three applied camera presets, FOV 38/45/58, studio/night/sunrise lighting, exposure 0.72..1.18, reset and state overlay |
| Gameplay state runtime | `phase6_3d_gameplay_state_runtime_visible`, `gameplay_state_controls_verified` | Deterministic objective cycle, score/checkpoint counters, button/keyboard parity, pause-safe loop, reset and applied Three.js state |
| Procedural asset policy | `phase6_3d_asset_policy_runtime_visible`, `asset_policy_controls_verified` | Three allowlisted local primitives, three material variants, reset, visible manifest and blocked external fetch/upload paths |
| Volatile scene save/load | `phase6_3d_save_load_runtime_visible`, `browser_memory_snapshot_restore_verified` | One typed React-state slot, 15 allowlisted fields, disabled empty load, complete restore, clear and reload loss |
| Scene state (auto-rotate / pause) | `phase6_3d_scene_state_runtime_visible` | Auto-rotate toggle (controlled), pause via reduced-motion |
| Accessibility runtime | `phase6_3d_accessibility_runtime_visible`, `reduced_motion_keyboard_focus_verified` | Manual/system Reduced Motion, semantic 2D fallback, ten focus targets, keyboard navigation, scene focus and live status |
| Netcode loopback runtime | `phase6_3d_netcode_loopback_runtime_visible`, `two_peer_lockstep_verified` | One volatile session, host/guest join-leave, ready barrier, manual lockstep ticks, monotonic packet sequence, disconnect stop and procedural remote peer marker |
| Local scoreboard + frame classification | `phase6_local_scoreboard_performance_runtime_visible`, `phase6_deterministic_top3_ordering_verified`, `phase6_frame_budget_classification_verified` | Volatile Top 3 from gameplay snapshots plus twelve real renderer-stat samples, recomputed averages, terminal pass/fail classification, reload loss, pixel variance and zero network/persistence guards |
| three.js WebGL smoke + non-blank canvas | `threejs_webgl_smoke_verified`, `nonblank_canvas_pixel_proof` | e2e renders WebGL2 canvas, 0 console errors |

## Runtime proof
- Local DEV-ONLY: `node scripts/verify-phase6-frontend.mjs --out .codex/runs/CURRENT/phase6/frontend-local`
  passed 7/7 markers and the Playwright interaction test.
- Hosted HTTPS: `node scripts/verify-phase6-frontend.mjs --base-url https://frontend-seven-psi-78.vercel.app --out .codex/runs/CURRENT/phase6/frontend-hosted`
  passed the same 7/7 markers and interaction test.
- Hosted evidence: `report.json`, `report.md`, `phase6-3d-before.png`, and
  `phase6-2d-after.png`; the screenshots are nonblank and the report records zero
  console errors.
- `npm run build --prefix apps/frontend` completed successfully with 21/21 static pages.
- Local camera/lighting evidence: `scripts/verify-phase6-3d-camera-lighting-runtime.ps1`
  plus `.codex/runs/CURRENT/phase6/camera-lighting-local/report.json` and
  `phase6-camera-lighting.png` prove every bounded control, applied Three.js state,
  no control-triggered XHR/fetch, and zero browser-console errors.
- Local gameplay-state evidence: `scripts/verify-phase6-3d-gameplay-state-runtime.ps1`
  plus `.codex/runs/CURRENT/phase6/gameplay-state-local/report.json` and
  `phase6-gameplay-state.png` prove deterministic transitions, pause/resume/reset,
  button/keyboard parity, applied Three.js state, no control-triggered XHR/fetch,
  and zero browser-console errors.
- Local asset-policy evidence: `scripts/verify-phase6-3d-asset-policy-runtime.ps1`
  plus `.codex/runs/CURRENT/phase6/asset-policy-local/report.json` and
  `phase6-asset-policy.png` prove every procedural profile and material variant,
  reset, applied Three.js state, no control-triggered XHR/fetch, and zero browser-console errors.
- Local save/load evidence: `scripts/verify-phase6-3d-save-load-runtime.ps1`
  plus `.codex/runs/CURRENT/phase6/save-load-local/report.json` and
  `phase6-save-load.png` prove capture, mutation, complete UI/Three.js restore,
  clear, reload loss, no control-triggered XHR/fetch, and zero browser-console errors.
- Local netcode loopback evidence: `scripts/verify-phase6-3d-netcode-loopback-runtime.ps1`
  plus `.codex/runs/CURRENT/phase6/netcode-local/report.json` and
  `phase6-netcode-loopback.png` prove create/join/ready/start/tick/disconnect/close,
  deterministic packet accounting, applied Three.js state, no fetch/XHR/WebSocket,
  and zero browser-console errors.
- Local scoreboard/performance evidence: `scripts/verify-phase6-local-scoreboard-performance-runtime.ps1`
  plus `.codex/runs/CURRENT/phase6/scoreboard-performance-local` prove four gameplay captures,
  deterministic Top 3, reset/reload loss, twelve finite renderer samples, recomputed classification,
  pixel variance, and zero network/persistence guard counters. The observed headless DEV result is
  `fail` at `4.0 FPS` and `252.8 ms`; it is not a performance-success or GPU-benchmark claim.

## Progress credit
- The established project rubric credits client-runtime, interaction, scene-state,
  performance-budget, full camera/lighting, gameplay-state, procedural asset-policy,
  volatile save/load, full accessibility, local netcode loopback, local Top-3, and bounded classification slices as **Phase 6 = 90%**.
- The rounded phase average is now **84%**.
- Vertical layer percentages stay unchanged. In particular, Frontend remains **99%**
  because this proof does not close every frontend/release gap.

## Explicitly NOT claimed (honest, gate-respecting)
- The remote capabilities behind `remote_multiplayer_netcode_blocked`, `binary_asset_upload_blocked`,
  `cloud_save_sync_blocked`, `external_asset_fetch_blocked`,
  `server_authoritative_mission_blocked`, and `leaderboard_sync_blocked` are not opened.
  The asset-policy slice verifies the local procedural alternative and fail-closed guards only.
- The loopback slice is not WebSocket/WebRTC, matchmaking, a public lobby, hosted relay,
  server-authoritative synchronization, latency/reconciliation, persistence, or capacity proof.
- Save/load is intentionally volatile. No LocalStorage, IndexedDB, cookie/cache
  persistence, cloud sync, upload, or server snapshot capability is claimed.
- Client-side FPS/ms values are interaction evidence, not a scale benchmark or capacity claim.
- No secret read/printed, provider write, deploy, release promotion, or production claim occurred.
