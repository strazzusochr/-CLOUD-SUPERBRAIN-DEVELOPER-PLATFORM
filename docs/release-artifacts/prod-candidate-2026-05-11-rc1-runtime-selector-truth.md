# Active Runtime Selector Truth Proof

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
overall_percent: `82`
phase_5_percent: `89`
agent_pool_percent: `76`
llm_gateway_percent: `67`
mcp_gateway_percent: `68`
memory_percent: `74`
frontend_percent: `100`
orchestrator_percent: `100`
current_hosted_selector: `IMAGE_TAG=5053a8c4a2c9a0e6ff245ec3d9e6c5b2a62a5ad1`
frontend_runtime_image: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/frontend:5053a8c4a2c9a0e6ff245ec3d9e6c5b2a62a5ad1`
immutable_candidate_tag: `5053a8c4a2c9a0e6ff245ec3d9e6c5b2a62a5ad1`
immutable_candidate_parity_claimed: `true`
production_rollout_claimed: `false`
new_ghcr_push_claimed: `true`
ghcr_publication_scope: `staging-candidate`
immutable_staging_parity_status: `verified`
remote_proof_required: `true`
next_allowed_action: `continue_release_readiness_without_production_rollout`

## Scope

This proof rebaselines the active release candidate after the immutable image-filesystem staging deploy. The hosted platform now runs the immutable candidate selector for all application services, including the frontend image, while still remaining a staging-candidate claim only.

## Evidence

- Remote `.env` selector: `IMAGE_TAG=5053a8c4a2c9a0e6ff245ec3d9e6c5b2a62a5ad1`.
- Remote frontend service image: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/frontend:5053a8c4a2c9a0e6ff245ec3d9e6c5b2a62a5ad1`.
- Remote image-filesystem proof confirms no service `./services/.../app:/app/app:ro` hot-mounts are present.
- Hosted root returns HTTP `200` and shows `Live Agent Control` plus `Runtime Guard`.
- Hosted progress returns `overall=82`, `phase_2=89`, `phase_5=89`, `frontend=100`, `orchestrator=100`, `agent_pool=76`, `llm_gateway=67`, `mcp_gateway=68`, `memory=74`, and integrity remains `verified`.
- `scripts\verify-current-immutable-staging-parity.ps1 -RequireVerified` proves the active immutable selector remotely.
- `scripts\verify-current-runtime-selector-truth.ps1 -RequireRemoteProof` binds the current remote selector, active candidate artifact, hosted progress truth, and immutable parity proof.

## Non-Claims

- No production rollout was performed.
- No Vercel production promotion was performed.
- No production GHCR tag promotion is claimed by this selector rebaseline.
- No live LLM provider calls or live MCP writes are introduced.
- No secret values are included in this proof.
