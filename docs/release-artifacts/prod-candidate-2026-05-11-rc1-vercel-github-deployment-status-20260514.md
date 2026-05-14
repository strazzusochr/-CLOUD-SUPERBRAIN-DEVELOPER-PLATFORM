# prod-candidate-2026-05-11-rc1 Vercel GitHub Deployment Status Proof

Date: 2026-05-14
Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
branch: `codex/live-agent-steering-ui-20260513`
github_status_context: `Vercel`
github_status_state: `success`
vercel_frontend_url: `https://frontend-seven-psi-78.vercel.app/`
hosted_staging_url: `https://188-34-191-140.sslip.io/`
production_rollout_claimed: `false`

## Scope

This proof binds the active RC1 evidence chain to the GitHub commit status reported by Vercel, the local Vercel project Git-link readiness gates, the public Vercel frontend URL, and the hosted Hetzner staging URL. It is release-readiness evidence only and does not mutate Vercel, deploy production, promote a release, or claim a production rollout.

## Evidence

- GitHub combined commit status includes context `Vercel` with state `success`.
- The Vercel status target URL is under `https://vercel.com/strazzusochrs-projects/frontend/`.
- `scripts\verify-vercel-project-git-readiness.ps1 -RequireBranchUpstream -ReportOnly -JsonOnly -OutputPath ""` reports `status=ready`, zero blocking failures, GitHub origin, and the current branch upstream.
- `scripts\verify-vercel-git-link.ps1 -ReportOnly -JsonOnly -OutputPath ""` reports `vercel_git_link_ready`, `framework=nextjs`, `rootDirectory=apps/frontend`, GitHub org/repo linkage, production branch `chore/repo-bootstrap`, and verified domain `frontend-seven-psi-78.vercel.app`.
- `https://frontend-seven-psi-78.vercel.app/` returns HTTP `200` and title `Cloud Superbrain`.
- `https://188-34-191-140.sslip.io/` returns HTTP `200` and shows `Cloud Superbrain`.
- Direct Vercel project/deployment listing through the session Vercel connector was forbidden for the configured team scope, so this proof uses GitHub status plus existing read-only Vercel Git-link verifiers instead of claiming Vercel API deployment-list authority.

## Verification

- `scripts\verify-phase5-vercel-github-deployment-status.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-current-runtime-selector-truth.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-current-release-candidate.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify.ps1 -Suite phase5 -Plan`
- `scripts\verify-security.ps1`
- `scripts\verify-evidence-artifact-safety.ps1`

## Non-Claims

This proof does not claim a production rollout.
This proof does not include secret values.
No Vercel mutation, deployment promotion, GHCR push, live LLM provider call, live MCP write, provider billing proof, or SOC/SIEM completeness proof is claimed.
