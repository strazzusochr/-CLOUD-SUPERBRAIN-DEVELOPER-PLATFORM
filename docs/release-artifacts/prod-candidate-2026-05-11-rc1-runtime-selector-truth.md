# Active Runtime Selector Truth Proof

Status: `verified-blocked`
release_id: `prod-candidate-2026-05-11-rc1`
overall_percent: `71`
phase_5_percent: `69`
current_hosted_selector: `IMAGE_TAG=staging`
frontend_runtime_image: `cloud-superbrain-frontend:source-staging`
immutable_candidate_tag: `b0c2773b1d122745947315a8d39734d5a6c96d6b`
immutable_candidate_parity_claimed: `false`
production_rollout_claimed: `false`
ghcr_push_claimed: `false`
immutable_staging_parity_status: `blocked_after_frontend_source_build`
next_allowed_action: `build_new_immutable_candidate_or_run_image_filesystem_candidate_deploy`

## Scope

This proof keeps the active release candidate honest after the staging-only frontend source-build path. The hosted platform is healthy and current, but it is not currently an immutable image-filesystem candidate because backend services use mutable `IMAGE_TAG=staging` and the frontend uses a locally built staging source image.

## Evidence

- Remote `.env` selector: `IMAGE_TAG=staging`.
- Remote frontend service image: `cloud-superbrain-frontend:source-staging`.
- Remote frontend compose override includes `pull_policy: never`.
- Hosted root returns HTTP `200` and shows `Live Agent Control` plus `Runtime Guard`.
- Hosted progress returns `overall=71`, `phase_5=69`, integrity remains `verified`.
- `scripts\verify-current-immutable-staging-parity.ps1` now accepts this state only as `blocked` unless `-RequireVerified` proves a real immutable image-filesystem deploy.
- `scripts\verify-current-runtime-selector-truth.ps1` binds the current remote selector, active candidate artifact, and hosted progress truth.

## Non-Claims

- No production rollout was performed.
- No Vercel production promotion was performed.
- No GHCR image was pushed.
- No immutable parity is claimed for the current hosted staging runtime.
- No live LLM provider calls or live MCP writes are introduced.
