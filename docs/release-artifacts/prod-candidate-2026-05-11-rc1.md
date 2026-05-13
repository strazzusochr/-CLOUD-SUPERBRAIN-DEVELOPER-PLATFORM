# Release Artifact

release_id: `prod-candidate-2026-05-11-rc1`
scope: `release-boundary cleanup, HF router truth, frontend build, agent-api/runtime compile checks, hosted staging smoke checks, immutable staging image candidate`
environment: `production-candidate`
source_branch: `chore/repo-bootstrap`
source_commit_sha: `1d87de96d74ed75bbafff9840e963f2075253df9`
source_commit_semantics: `current validated CI/runtime head including production tag gate ordering, Node24 workflow migration, and current cloud handoff metadata; later release-metadata-only verifier/docs commits may wrap this source without changing runtime scope`
immutable_image_commit_sha: `b0c2773b1d122745947315a8d39734d5a6c96d6b`
workflow_run_url: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25735275873`
pipeline_status: `main-deploy success for immutable_image_commit_sha b0c2773b1d122745947315a8d39734d5a6c96d6b; release-boundary source head 1d87de96d74ed75bbafff9840e963f2075253df9 passed main-deploy run 25765691998; latest metadata/verifier wrapper head 66c9a7fc1f5f51e60dc73ad4def0e4d35ba7a403 passed main-deploy run 25782828285`
smoke_result: `passed`
observability_check: `present`
rollback_note: `no production rollout performed; rollback remains the existing hosted staging rollback path`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:b0c2773b1d122745947315a8d39734d5a6c96d6b`
owner_decision: `approved`
hosted_selector_observed: `IMAGE_TAG=b0c2773b1d122745947315a8d39734d5a6c96d6b`
hosted_selector_observed_at: `2026-05-12T14:08:00Z`
immutable_staging_parity_status: `verified`

## Verification Evidence

- Python compile check: `py -3 -m compileall services\agent-api\app services\agent-worker\app services\llm-gateway\app`
- Frontend production build: `npm run build --prefix apps/frontend`
- Security suite: `scripts\verify.ps1 -Suite security`
- Hosted staging smoke: `scripts\verify.ps1 -Suite hosted-staging-smoke -BaseUrl https://188-34-191-140.sslip.io`
- Hosted staging safe profile: `scripts\verify.ps1 -Suite hosted-staging -BaseUrl https://188-34-191-140.sslip.io -SafeProfile`
- Release boundary suite: `scripts\verify.ps1 -Suite release-boundary -ReportOnly`
- Main deploy workflow for immutable staging image commit: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25735275873`
- Main deploy workflow for release-boundary source head: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25765691998`
- Main deploy workflow for metadata/verifier wrapper head: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25782828285`
- Hosted staging proof workflow: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25738288780`
- Production tag gate ordering: `production-gate` depends on `verify`, uses environment `production`, and `build-and-push` waits for `production-gate` before publishing production tags.
- Immutable staging plan: `scripts\deploy-to-staging.ps1 -PlanOnly -UseImageFilesystem -ImageTag b0c2773b1d122745947315a8d39734d5a6c96d6b`
- Immutable staging parity ready check: `scripts\manual\verify-phase5-staging-immutable-parity.ps1 -ReleaseId prod-candidate-2026-05-11-rc1 -CandidateSha b0c2773b1d122745947315a8d39734d5a6c96d6b`
- Immutable staging parity remote proof: `scripts\manual\verify-phase5-staging-immutable-parity.ps1 -RequireVerified -ReleaseId prod-candidate-2026-05-11-rc1 -CandidateSha b0c2773b1d122745947315a8d39734d5a6c96d6b -BaseUrl https://188-34-191-140.sslip.io -KeyPath <local-private-key>`

## Cloud Surfaces

- Vercel frontend: `https://frontend-seven-psi-78.vercel.app/`
- Hetzner hosted platform: `https://188-34-191-140.sslip.io/`
- Agent API health: `https://188-34-191-140.sslip.io/api/v1/health`
- LLM gateway health: `https://188-34-191-140.sslip.io/llm/api/v1/health`

## Guardrails

- This artifact approves the current clean repository boundary as a production candidate.
- The release boundary source commit is `1d87de96d74ed75bbafff9840e963f2075253df9`; the immutable image commit deployed to staging is `b0c2773b1d122745947315a8d39734d5a6c96d6b`.
- This artifact does not claim a production rollout.
- Remote immutable Hetzner parity is verified for the six owned service images at `b0c2773b1d122745947315a8d39734d5a6c96d6b`; this remains staging evidence only.
- This artifact does not replace the historical `prod-candidate-2026-05-05-rc1` no-release evidence.
- The hosted selector line records the current Hetzner staging selector observed after later deployment work; it does not rewrite the historical 2026-05-05 rollback selector.
- Production deployment still requires the release-candidate gate bundle and a separate rollout proof.
