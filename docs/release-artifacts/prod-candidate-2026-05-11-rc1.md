# Release Artifact

release_id: `prod-candidate-2026-05-11-rc1`
scope: `release-boundary cleanup, HF router truth, frontend build, agent-api/runtime compile checks, hosted staging smoke checks`
environment: `production-candidate`
source_branch: `codex-release-boundary-cleanup-20260511`
source_commit_sha: `aa52877d009e2b0a51fd8676e06943a65064c2be`
source_commit_semantics: `candidate app/runtime source commit; later release-metadata-only verifier/docs commits may wrap this source without changing runtime scope`
workflow_run_url: `not-run-yet-local-verification-only`
pipeline_status: `local verification passed; GitHub Actions not run for this candidate`
smoke_result: `passed`
observability_check: `present`
rollback_note: `no production rollout performed; rollback remains the existing hosted staging rollback path`
owner_decision: `approved`
hosted_selector_observed: `IMAGE_TAG=deploy-20260511-agentfix-full`
hosted_selector_observed_at: `2026-05-11T21:30:52Z`

## Verification Evidence

- Python compile check: `py -3 -m compileall services\agent-api\app services\agent-worker\app services\llm-gateway\app`
- Frontend production build: `npm run build --prefix apps/frontend`
- Security suite: `scripts\verify.ps1 -Suite security`
- Hosted staging smoke: `scripts\verify.ps1 -Suite hosted-staging-smoke -BaseUrl https://188-34-191-140.sslip.io`
- Hosted staging safe profile: `scripts\verify.ps1 -Suite hosted-staging -BaseUrl https://188-34-191-140.sslip.io -SafeProfile`
- Release boundary suite: `scripts\verify.ps1 -Suite release-boundary -ReportOnly`

## Cloud Surfaces

- Vercel frontend: `https://frontend-seven-psi-78.vercel.app/`
- Hetzner hosted platform: `https://188-34-191-140.sslip.io/`
- Agent API health: `https://188-34-191-140.sslip.io/api/v1/health`
- LLM gateway health: `https://188-34-191-140.sslip.io/llm/api/v1/health`

## Guardrails

- This artifact approves the current clean repository boundary as a production candidate.
- The runtime source boundary is commit `aa52877d009e2b0a51fd8676e06943a65064c2be`; subsequent release-metadata-only commits do not change app/runtime source scope.
- This artifact does not claim a production rollout.
- This artifact does not replace the historical `prod-candidate-2026-05-05-rc1` no-release evidence.
- The hosted selector line records the current Hetzner staging selector observed after later deployment work; it does not rewrite the historical 2026-05-05 rollback selector.
- Production deployment still requires the release-candidate gate bundle and a separate rollout proof.
