# Cloud Truth - 2026-05-11

## Active Surfaces

- Vercel frontend: `https://frontend-seven-psi-78.vercel.app/`
- Hetzner hosted platform: `https://188-34-191-140.sslip.io/`
- Agent API health: `https://188-34-191-140.sslip.io/api/v1/health`
- LLM gateway health: `https://188-34-191-140.sslip.io/llm/api/v1/health`

## Current Release Boundary

- Active candidate: `prod-candidate-2026-05-11-rc1`
- Candidate source commit: `1d87de96d74ed75bbafff9840e963f2075253df9`
- Candidate immutable image commit: `b0c2773b1d122745947315a8d39734d5a6c96d6b`
- Candidate immutable tag set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:b0c2773b1d122745947315a8d39734d5a6c96d6b`
- Historical candidate `prod-candidate-2026-05-05-rc1` remains preserved as `no-release`.
- Release metadata/docs/verifier commits after `1d87de96d74ed75bbafff9840e963f2075253df9` do not change app/runtime source scope when `release_metadata_only_delta=true`.
- Remote immutable Hetzner parity is verified for the six owned service images after image-filesystem staging deploy and `verify-phase5-staging-immutable-parity.ps1 -RequireVerified`.

## Verified Checks

- Python compile: `py -3 -m compileall services\agent-api\app services\agent-worker\app services\llm-gateway\app`
- Frontend build: `npm run build --prefix apps/frontend`
- Security: `scripts\verify.ps1 -Suite security`
- Hosted smoke: `scripts\verify.ps1 -Suite hosted-staging-smoke -BaseUrl https://188-34-191-140.sslip.io`
- Hosted safe profile: `scripts\verify.ps1 -Suite hosted-staging -BaseUrl https://188-34-191-140.sslip.io -SafeProfile`
- Release boundary: `scripts\verify.ps1 -Suite release-boundary -ReportOnly -MaxWaitSeconds 1`
- Immutable staging parity ready: `scripts\manual\verify-phase5-staging-immutable-parity.ps1 -ReleaseId prod-candidate-2026-05-11-rc1 -CandidateSha b0c2773b1d122745947315a8d39734d5a6c96d6b`
- Immutable staging parity remote proof: `scripts\manual\verify-phase5-staging-immutable-parity.ps1 -RequireVerified -ReleaseId prod-candidate-2026-05-11-rc1 -CandidateSha b0c2773b1d122745947315a8d39734d5a6c96d6b -BaseUrl https://188-34-191-140.sslip.io -KeyPath <local-private-key>`

## Latest Post-Merge Handoff

- Current handoff: `docs/analysis/CURRENT_CLOUD_HANDOFF_2026-05-13.md`
- Latest validated repository head: `66c9a7fc1f5f51e60dc73ad4def0e4d35ba7a403`
- Release-boundary source head: `1d87de96d74ed75bbafff9840e963f2075253df9`
- Main deploy run: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25782828285`
- Main deploy result: `success`
- Post-merge release-boundary suite: `scripts=24 failed=0`
- PR #7 production tag gate ordering: merged and verified.
- PR #8 current cloud handoff: merged and verified.
- PR #9/#10 GitHub Actions Node24 migration: merged and verified.
- PR #11/#12 current cloud handoff refresh/stabilization: merged and verified.
- PR #13 release-boundary truth rebaseline and verifier ordering: merged and verified.
- Production rollout remains unclaimed.

## Fail-Closed Policy

- `may_stage=false`
- `may_commit=false`
- `may_push=false`
- `may_deploy=false`
- `may_release=false`
- No production deploy is claimed in this document.

## Known Constraint

Docker multi-arch cloud builds remain constrained by the available builder quota. Local/cloud HTTP checks and Vercel access are verified separately.
