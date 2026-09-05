# Phase 6 3D Netcode Loopback Runtime

Contract version: `phase6-3d-netcode-loopback-runtime-v1`

Evidence reference: `phase6_3d_netcode_loopback_runtime_visible`

Endpoint: `GET /api/v1/phase6/3d-netcode/contract`

## Scope

This contract closes one bounded Phase-6 netcode rubric block with a deterministic two-peer browser loopback. The Organism surface provides one volatile session, a host and guest slot, a two-peer ready barrier, manual lockstep ticks, monotonic packet sequence accounting, immediate disconnect handling, and a procedural Three.js guest marker.

The implementation is intentionally transport-free. All state remains in React browser memory and every interaction is local to the current page. A guest join contributes one handshake packet; each accepted lockstep step advances one tick and contributes exactly two packets and two sequence positions.

## Required Proof

- Session creation exposes one host and leaves start disabled.
- One deterministic guest may join; the peer count becomes `2/2`.
- Lockstep cannot start until host and guest are both ready.
- Every manual simulation step increments ticks by one and packets/sequence by two.
- Packet sequence is monotonic and visible in UI and Three.js runtime attributes.
- Guest disconnect stops the simulation immediately and removes the remote peer marker.
- Session close returns every loopback counter and readiness state to idle defaults.
- Chromium observes no control-triggered `fetch`, XHR, WebSocket, page, or console error.

## Closed Boundaries

The contract explicitly keeps WebSocket, WebRTC, matchmaking, public lobby, server-authoritative synchronization, provider writes, live MCP writes, deployment, secret output, and release promotion disabled. It is not proof of remote multiplayer, hosted relay capacity, latency tolerance, reconciliation, persistence, or production netcode.

## Progress Gate

Phase 6 may move from `72%` to `80%` and rounded Overall from `81%` to `82%` only when the API contract, source guards, manifest markers, focused Chromium flow, nonblank screenshot, dedicated verifier, and parent static/runtime/browser gates all pass.

Localhost evidence is `DEV-ONLY`; hosted proof still blocked.
