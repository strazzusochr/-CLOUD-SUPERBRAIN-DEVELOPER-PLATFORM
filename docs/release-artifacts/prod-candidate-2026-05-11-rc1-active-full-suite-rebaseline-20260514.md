# Active Full-Suite Rebaseline Proof

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
environment: `production-candidate`
source_commit_sha: `052a05c295b640e69e50f6bfb73378306670713e`
immutable_image_commit_sha: `052a05c295b640e69e50f6bfb73378306670713e`
base_url: `https://188-34-191-140.sslip.io`
production_rollout_claimed: `false`
active_gate_count: `10`
phase5_suite_plan_status: `passed`
changed_horizontal: `Phase 5 75->76`
changed_vertical: `none`

## Verified Gates

- `py -3 scripts\verify_project_progress_manifest.py`
- `scripts\verify-phase5-suite-active-candidate-plan.ps1`
- `scripts\verify-current-release-candidate.ps1 -BaseUrl https://188-34-191-140.sslip.io -ReleaseId prod-candidate-2026-05-11-rc1`
- `scripts\verify-active-release-candidate-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io -ReleaseId prod-candidate-2026-05-11-rc1 -ReportOnly -JsonOnly`
- `scripts\verify-hosted-staging-smoke.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase5-active-runtime-evidence-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io -ReleaseId prod-candidate-2026-05-11-rc1`
- `scripts\verify-phase5-active-security-evidence-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io -ReleaseId prod-candidate-2026-05-11-rc1`
- `scripts\verify-phase5-active-verifier-sweep-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io -ReleaseId prod-candidate-2026-05-11-rc1`
- `scripts\verify-phase5-vercel-github-deployment-status.ps1 -BaseUrl https://188-34-191-140.sslip.io -ReleaseId prod-candidate-2026-05-11-rc1`
- `scripts\verify-evidence-artifact-safety.ps1`

## Evidence Bound

- Active Phase 5 suite plan now keeps the current RC1 verifier set on default parameters while preserving explicit historical coverage for retired `prod-candidate-2026-05-05-rc1` artifacts.
- Hosted staging status remains HTTP `200`, project progress remains `80%`, Phase 5 is `78%`, and immutable selector remains `052a05c295b640e69e50f6bfb73378306670713e`.
- Active runtime, active security, active verifier sweep, Vercel/GitHub status, active release-candidate bundle, current release-candidate, and evidence-artifact-safety gates pass together on the same active RC1 boundary.

## Non-Claims

- This proof does not claim a production rollout.
- This proof does not claim release promotion.
- This proof does not claim live LLM provider calls.
- This proof does not claim live MCP writes.
- This proof does not claim local model downloads.
- This proof does not claim provider billing proof.
- This proof does not include secret values.
