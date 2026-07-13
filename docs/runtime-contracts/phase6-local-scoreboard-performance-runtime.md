# Phase 6 Local Scoreboard And Performance Runtime

Contract version: `phase6-local-scoreboard-performance-runtime-v1`

Evidence reference: `phase6_local_scoreboard_performance_runtime_visible`

Endpoint: `GET /api/v1/phase6/local-scoreboard-performance/contract`

## Scope

This contract closes one bounded Phase-6 client-runtime rubric block. The Organism surface captures current deterministic gameplay results into a volatile top-three leaderboard and samples the existing Three.js renderer statistics over a fixed twelve-sample window.

The leaderboard ordering is deterministic: score descending, completed objectives descending, then capture sequence ascending. Entries contain only capture sequence, score, and completions; there is no player-controlled name or identity field. The frame sample reports count, average FPS, the frame interval derived from FPS, and a local budget result against `25 FPS` minimum and `40 ms` maximum average interval.

Samples arrive on the existing renderer-stat update at approximately 500 ms, non-finite or non-positive values are ignored, and averages are arithmetic means rounded to one decimal. Restart discards the prior sample set. A ten-second timeout terminates an inactive-renderer sample as a visible failure instead of hanging.

## Required Proof

- Capturing actual gameplay state creates ranked entries and never retains more than three.
- Ties are resolved deterministically by completions and capture sequence.
- Reset removes every leaderboard entry from React memory.
- Performance sampling uses twelve live renderer-stat updates and reaches `pass` or `fail` without a hardcoded result.
- The result exposes the measured averages and both budget thresholds.
- Chromium observes no control-triggered fetch, XHR, WebSocket, LocalStorage, IndexedDB, cookie, cache, page, or console error.
- The Three.js canvas remains nonblank and a screenshot is persisted with the JSON report.

## Closed Boundaries

Leaderboard synchronization, account identity, persistent browser storage, telemetry, provider writes, live MCP writes, deployment, secret output, and release promotion remain disabled. The bounded local frame sample is interaction evidence only. It is not a load, concurrency, scale, capacity, hosted, or production performance benchmark.

## Progress Gate

Phase 6 may move from `80%` to `90%` and rounded Overall from `82%` to `84%` only when the API contract, source guards, manifest markers, focused Chromium flow, nonblank screenshot, dedicated verifier, and parent static/runtime/browser gates all pass.

The final Phase-6 gap remains bound to the separately approved scale-budget and live-MCP gates. Localhost evidence is `DEV-ONLY`; hosted proof remains separate.
