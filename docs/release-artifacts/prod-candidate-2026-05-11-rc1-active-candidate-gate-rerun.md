# Active Candidate Gate Rerun

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
base_url: `https://188-34-191-140.sslip.io`
active_release_id: `prod-candidate-2026-05-11-rc1`
source_commit_sha: `1d87de96d74ed75bbafff9840e963f2075253df9`
immutable_image_commit_sha: `b0c2773b1d122745947315a8d39734d5a6c96d6b`
production_rollout_claimed: `false`
bundle_status: `passed`
bundle_gate_count: `3`
current_release_candidate_status: `verified`
vercel_git_link_status: `ready`
vercel_project_git_readiness_status: `ready`
policy_mutates_production: `false`
policy_deploys_production: `false`
policy_claims_rollout: `false`
policy_includes_secrets: `false`

## Executed Gates

- `powershell -ExecutionPolicy Bypass -File scripts\verify-active-release-candidate-bundle.ps1 -ReportOnly -JsonOnly -BaseUrl https://188-34-191-140.sslip.io`
- `powershell -ExecutionPolicy Bypass -File scripts\verify-current-release-candidate.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-active-candidate-gate-rerun.ps1 -BaseUrl https://188-34-191-140.sslip.io`

## Bound Surfaces

- Active release config: `docs/release-artifacts/current-release-candidate.json`
- Active release artifact: `docs/release-artifacts/prod-candidate-2026-05-11-rc1.md`
- Hosted staging URL: `https://188-34-191-140.sslip.io`
- Vercel frontend URL: `https://frontend-seven-psi-78.vercel.app/`
- Active release candidate bundle gates: `current-release-candidate`, `vercel-project-git-readiness`, `vercel-git-link`

## Non Claims

- This rerun does not claim a production rollout.
- This rerun does not mutate production.
- This rerun does not deploy production.
- This rerun does not include secret values.
- This rerun keeps the active candidate scoped to staging evidence and release-boundary verification.
