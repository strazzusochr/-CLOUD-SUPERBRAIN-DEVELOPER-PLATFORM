# Active Runtime Selector Truth Proof

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
overall_percent: `80`
phase_5_percent: `77`
current_hosted_selector: `IMAGE_TAG=4364d31d7f1e6d0dec1f4d9f686715fec41d3b35`
frontend_runtime_image: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/frontend:4364d31d7f1e6d0dec1f4d9f686715fec41d3b35`
immutable_candidate_tag: `4364d31d7f1e6d0dec1f4d9f686715fec41d3b35`
immutable_candidate_parity_claimed: `true`
production_rollout_claimed: `false`
new_ghcr_push_claimed: `false`
immutable_staging_parity_status: `verified`
remote_proof_required: `true`
next_allowed_action: `continue_release_readiness_without_production_rollout`

## Scope

This proof rebaselines the active release candidate after the immutable image-filesystem staging deploy. The hosted platform now runs the immutable candidate selector for all application services, including the frontend image, while still remaining a staging-candidate claim only.

## Evidence

- Remote `.env` selector: `IMAGE_TAG=4364d31d7f1e6d0dec1f4d9f686715fec41d3b35`.
- Remote frontend service image: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/frontend:4364d31d7f1e6d0dec1f4d9f686715fec41d3b35`.
- Remote image-filesystem proof confirms no service `./services/.../app:/app/app:ro` hot-mounts are present.
- Hosted root returns HTTP `200` and shows `Live Agent Control` plus `Runtime Guard`.
- Hosted progress returns `overall=80`, `phase_5=77`, and integrity remains `verified`.
- `scripts\verify-current-immutable-staging-parity.ps1 -RequireVerified` proves the active immutable selector remotely.
- `scripts\verify-current-runtime-selector-truth.ps1 -RequireRemoteProof` binds the current remote selector, active candidate artifact, hosted progress truth, and immutable parity proof.

## Non-Claims

- No production rollout was performed.
- No Vercel production promotion was performed.
- No new GHCR image push is claimed by this selector rebaseline.
- No live LLM provider calls or live MCP writes are introduced.
- No secret values are included in this proof.
