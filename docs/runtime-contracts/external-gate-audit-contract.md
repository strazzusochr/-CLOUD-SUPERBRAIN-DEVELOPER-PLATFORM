# External Gate Audit Contract

Contract version: `external-gate-audit-v1`

Verifier: `scripts/verify-external-gates.ps1`

Cloud-only verifier: `scripts/verify-cloud-only-staging.ps1`

Evidence ref: `external_gate_audit_proof`

## Purpose

The external gate audit prevents a frontend-only deployment from being treated as full hosted staging. It records the current state of every external proof gate without writing secret values into the repository or generated artifacts.

Frontend preview reachability is not hosted staging.

No secret values are written by this verifier.

## Required Gates

- Hosted frontend preview: `/` must render `Cloud Superbrain`, and `/api/health` must return the frontend health contract.
- Cloud-only frontend health: `/health` must return `ok` over HTTPS and must never use localhost.
- Hosted Agent API staging: `/api/v1/health`, `/api/v1/project/progress/integrity`, and `/api/v1/project/progress/completion` must all pass on the hosted base URL.
- Cloud deployment preflight: `/api/v1/clouds/deployment-preflight/contract` must return `cloud-deployment-preflight-v1` with evidence `cloud_deployment_preflight_visible`.
- Cloud provider inventory: `/api/v1/clouds` must return `cloud-provider-inventory-v1` with evidence `cloud_provider_inventory_visible`, including the active Vercel, Fly.io, Cloudflare, GitHub, GHCR, Hugging Face, GitLab, and Grafana Cloud provider surfaces when their tokens are configured.
- Cloud layer readiness: `/api/v1/clouds/layers` must return `cloud-layer-readiness-v1` with evidence `cloud_layer_readiness_visible`.
- GHCR image digest: all six application service image manifests must resolve under the configured GHCR namespace and tag before image publication is claimable.
- Vercel backend origins: `AGENT_API_BASE_URL`, `MCP_GATEWAY_BASE_URL`, and `LLM_GATEWAY_BASE_URL` must be HTTPS non-local origins and must pass health probes. Direct Fly/service origins are probed at `/api/v1/health`; path-prefixed reverse-proxy origins such as `/mcp` or `/llm` are probed under that prefix. Fly app names may be converted by the private runner into `https://<app>.fly.dev`; when private app-name env vars are absent, the runner falls back to the checked-in Fly config app names. The frontend Next.js rewrite layer uses the same precedence and is guarded by `scripts/verify-frontend-cloud-rewrites.ps1`, but only real hosted responses can close the gate.
- GitHub branch protection: `scripts/apply_github_branch_protection.py --verify-only` must pass for the repository default branch with a configured token.
- Canonical secret scan: `gitleaks detect --no-git --source . --config .gitleaks.toml --redact` must pass.
- Fly.io live budget: `scripts/check_fly_infra_budget.py` must pass with `FLY_API_TOKEN` configured.
- Optional GitLab identity: `GITLAB_TOKEN` can verify access to the configured GitLab profile URL, but this is not a production-release gate in the current patched architecture.
- Optional Hugging Face identity: `HF_TOKEN` can verify access to the configured Hugging Face profile URL, but this is not a production-release gate in the current patched architecture.
- Optional grafana identity: `GRAFANA_CLOUD_API_KEY` can verify access to the configured Grafana Cloud URL, but this is not a production-release gate in the current patched architecture.

## Fail-Closed Rules

- `frontend_preview_claim_allowed=true` does not imply hosted staging.
- `cloud-only-staging-proof-v1` refuses localhost, loopback, non-HTTPS, and frontend-only success as full platform success.
- `verify-external-gates.ps1` also refuses localhost, loopback, `host.docker.internal`, and non-HTTPS hosted URLs.
- `hosted_staging_claim_allowed=true` requires the hosted `/api/v1` contracts.
- `production_deploy_claim_allowed=true` requires hosted staging, cloud deployment preflight visibility, current branch-protection verification, GHCR image digest proof, Vercel backend origin health, canonical gitleaks, and Fly.io live budget proof.
- Missing tokens produce `action_required`; they are not counted as verified.
- Bounded HTTP and native process probes time out fail-closed with `status=timeout` and `claim_allowed=false`; the verifier must still write a non-secret audit artifact.
- Generated artifacts are non-secret JSON files under `.phase1-artifacts/`.
- The optional GitLab identity proof may include the username and profile URL, never the token.
- The optional Hugging Face identity proof may include the username and profile URL, never the token.
- The optional grafana identity proof may include the org/stack URL, never the token.

## Current Non-Claims

- No production deployment is claimed from a Vercel frontend preview alone.
- No GitHub branch-protection current-state claim is made while the local GitHub CLI/token is invalid or absent.
- No Fly.io live infrastructure state is current unless a real Fly.io token is configured for the check.
- Retired legacy providers are historical/non-active references only and do not satisfy active release gates.
