# Release Artifact

release_id: `prod-candidate-2026-05-11-rc1`
scope: `release-boundary cleanup, HF router truth, frontend build, agent-api/runtime compile checks, hosted staging smoke checks, immutable staging image candidate`
environment: `production-candidate`
source_branch: `chore/repo-bootstrap`
source_commit_sha: `b0c2773b1d122745947315a8d39734d5a6c96d6b`
source_commit_semantics: `current immutable image candidate commit; later release-metadata-only verifier/docs commits may wrap this source without changing runtime scope`
workflow_run_url: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25735275873`
pipeline_status: `main-deploy success for source_commit_sha b0c2773b1d122745947315a8d39734d5a6c96d6b`
smoke_result: `passed`
observability_check: `present`
rollback_note: `no production rollout performed; rollback remains the existing hosted staging rollback path`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:b0c2773b1d122745947315a8d39734d5a6c96d6b`
owner_decision: `approved`
hosted_selector_observed: `IMAGE_TAG=deploy-20260511-agentfix-full`
hosted_selector_observed_at: `2026-05-11T21:30:52Z`
immutable_staging_parity_status: `ready-plan-only; remote RequireVerified proof still required before claiming Hetzner immutable parity`

## Verification Evidence

- Python compile check: `py -3 -m compileall services\agent-api\app services\agent-worker\app services\llm-gateway\app`
- Frontend production build: `npm run build --prefix apps/frontend`
- Security suite: `scripts\verify.ps1 -Suite security`
- Hosted staging smoke: `scripts\verify.ps1 -Suite hosted-staging-smoke -BaseUrl https://188-34-191-140.sslip.io`
- Hosted staging safe profile: `scripts\verify.ps1 -Suite hosted-staging -BaseUrl https://188-34-191-140.sslip.io -SafeProfile`
- Release boundary suite: `scripts\verify.ps1 -Suite release-boundary -ReportOnly`
- Main deploy workflow: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25735275873`
- Hosted staging proof workflow: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25738288780`
- Immutable staging plan: `scripts\deploy-to-staging.ps1 -PlanOnly -UseImageFilesystem -ImageTag b0c2773b1d122745947315a8d39734d5a6c96d6b`
- Immutable staging parity ready check: `scripts\manual\verify-phase5-staging-immutable-parity.ps1 -ReleaseId prod-candidate-2026-05-11-rc1 -CandidateSha b0c2773b1d122745947315a8d39734d5a6c96d6b`

## Cloud Surfaces

- Vercel frontend: `https://frontend-seven-psi-78.vercel.app/`
- Hetzner hosted platform: `https://188-34-191-140.sslip.io/`
- Agent API health: `https://188-34-191-140.sslip.io/api/v1/health`
- LLM gateway health: `https://188-34-191-140.sslip.io/llm/api/v1/health`

## Guardrails

- This artifact approves the current clean repository boundary as a production candidate.
- The immutable image candidate boundary is commit `b0c2773b1d122745947315a8d39734d5a6c96d6b`; subsequent release-metadata-only commits do not change app/runtime source scope.
- This artifact does not claim a production rollout.
- This artifact does not claim completed remote immutable Hetzner parity until `verify-phase5-staging-immutable-parity.ps1 -RequireVerified` passes after an image-filesystem staging deploy.
- This artifact does not replace the historical `prod-candidate-2026-05-05-rc1` no-release evidence.
- The hosted selector line records the current Hetzner staging selector observed after later deployment work; it does not rewrite the historical 2026-05-05 rollback selector.
- Production deployment still requires the release-candidate gate bundle and a separate rollout proof.
