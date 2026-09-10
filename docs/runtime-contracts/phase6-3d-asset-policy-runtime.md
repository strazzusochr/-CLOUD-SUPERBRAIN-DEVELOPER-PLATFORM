# Phase 6 3D Asset Policy Runtime

Contract: `phase6-3d-asset-policy-runtime-v1`

Endpoint: `GET /api/v1/phase6/3d-asset-policy/contract`

Evidence: `phase6_3d_asset_policy_runtime_visible`

## Runtime boundary

The Organism surface exposes an allowlisted browser-memory catalog containing
three procedural primitives: `cube`, `beacon`, and `ring`. Each shape is produced
with a local Three.js geometry and can use one of three allowlisted material
variants: `cyan`, `amber`, or `rose`.

The visible local manifest reports three primitives, three materials, zero remote
assets, zero uploads, `external_fetch=false`, `binary_upload=false`, and
`local_only=true`. Applied profile, material, catalog counts, and blocked remote
paths are mirrored as bounded `data-*` values on the Three.js runtime wrapper.

Changing a shape or material never calls `fetch`, XHR, a CDN, an upload endpoint,
or an asset pipeline service. Reset returns the profile to `cube` and `cyan`.

## Verified scenarios

- `procedural_asset_catalog_visible`
- `asset_profile_switch_visible`
- `material_policy_variant_visible`
- `local_asset_manifest_visible`
- `external_asset_fetch_blocked`
- `binary_asset_upload_blocked`
- `local_asset_policy_only`
- `phase6_progress_gate_bound_to_asset_policy_verifier`

## Progress rule

Phase 6 may move from `48%` to `56%` only after the contract, source guards,
focused Chromium interaction proof, nonblank screenshot, manifest update, and
parent verifier integration all pass.

## Non-claims

- No external asset fetch or remote CDN path is opened.
- No binary asset upload or asset pipeline service is started.
- No server-side GPU or heavy local render workload is started.
- No provider write, live MCP write, live provider call, production deployment,
  secret output, or release promotion is performed.
- Localhost evidence is `DEV-ONLY`; hosted proof remains separate.
