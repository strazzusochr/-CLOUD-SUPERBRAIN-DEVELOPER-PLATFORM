# Phase 6 3D Gameplay State Runtime

Contract: `phase6-3d-gameplay-state-runtime-v1`

Endpoint: `GET /api/v1/phase6/3d-gameplay-state/contract`

Evidence: `phase6_3d_gameplay_state_runtime_visible`

## Runtime boundary

The Organism surface owns a deterministic browser-memory state machine with the
ordered objectives `collect -> checkpoint -> survive -> collect`. Completing
`collect` or `survive` adds 10 score points. Completing `checkpoint` adds one
checkpoint. The same transition command is available through the visible button
and the `G` key.

The HUD exposes objective, score, checkpoints, completions, input events, loop
ticks, pause state, and `local_state_only=true`. The Three.js wrapper mirrors the
applied objective, counters, pause state, and ticks through bounded `data-*`
attributes. A procedural beacon changes position and color with the objective.

The one-second loop increments only while gameplay is active. Pausing freezes the
counter, resuming advances it again, and reset returns the objective and counters
to their deterministic initial values while preserving the selected pause mode.
No control action performs `fetch` or XHR.

## Verified scenarios

- `objective_state_overlay_visible`
- `local_score_counter_visible`
- `checkpoint_counter_visible`
- `deterministic_gameplay_state_machine`
- `pause_safe_game_loop_state`
- `input_event_binding_reused`
- `local_gameplay_state_only`
- `phase6_progress_gate_bound_to_gameplay_state_verifier`

## Progress rule

Phase 6 may move from `40%` to `48%` only after the runtime contract, source
guards, focused Chromium interaction proof, nonblank screenshot, manifest update,
and parent verifier integration all pass.

## Non-claims

- No multiplayer or netcode is claimed.
- No server-authoritative synchronization or physics engine is started.
- No external asset fetch, server-side GPU, or heavy local render is started.
- No provider write, live MCP write, live provider call, production deployment,
  secret output, or release promotion is performed.
- Localhost evidence is `DEV-ONLY`; hosted proof still remains separate.
