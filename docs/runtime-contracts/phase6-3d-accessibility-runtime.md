# Phase 6 3D Accessibility Runtime

Contract: `phase6-3d-accessibility-runtime-v1`

Endpoint: `GET /api/v1/phase6/3d-accessibility/contract`

Evidence: `phase6_3d_accessibility_runtime_visible`

## Runtime boundary

The Organism honors both a manual reduced-motion override and the live
`prefers-reduced-motion` system preference. Either condition replaces the animated
WebGL scene with a named static 2D region containing ten focusable topology items.

The fallback supports Arrow keys, Home, End, Enter, and Space through native button
semantics and bounded focus movement. The manual control exposes `aria-pressed` and
`aria-controls`; the scene is programmatically focusable, global focus-visible styling
remains active, and motion/render changes are exposed through a polite status region.

## Verified scenarios

- `manual_reduced_motion_toggle_visible`
- `system_reduced_motion_preference_honored`
- `semantic_2d_fallback_region_visible`
- `keyboard_fallback_navigation_visible`
- `focus_visible_and_programmatic_focus_visible`
- `accessible_status_live_region_visible`
- `accessibility_local_only`
- `phase6_progress_gate_bound_to_accessibility_verifier`

## Progress rule

Phase 6 may move from `64%` to `72%` only after contract, source, keyboard, focus,
manual/system reduced-motion, screenshot, manifest, and parent-gate proof all pass.

## Non-claims

- No speech service, telemetry export, persistent preference, or external
  accessibility provider is started.
- No provider write, live MCP write, deployment, secret output, or release promotion
  is performed.
- Localhost evidence is `DEV-ONLY`; hosted proof remains separate.
