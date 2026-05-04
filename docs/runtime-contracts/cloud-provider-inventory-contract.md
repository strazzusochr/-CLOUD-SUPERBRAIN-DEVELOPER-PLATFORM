# Cloud Provider Inventory Contract

Contract version: `cloud-provider-inventory-v1`

Endpoint: `GET /api/v1/clouds`

Evidence ref: `cloud_provider_inventory_visible`

Layer readiness endpoint: `GET /api/v1/clouds/layers`

Layer readiness contract: `cloud-layer-readiness-v1`

Layer readiness evidence ref: `cloud_layer_readiness_visible`

Status: Phase 4 local contract implemented

## Purpose

This contract makes cloud provider wiring visible without storing provider secrets in the repository, Docker Compose files, generated artifacts, or dashboard payloads.

The inventory is a read-only status surface for the seven-layer Superbrain architecture. It does not create, mutate, deploy, delete, or rotate any cloud resource.

No secret values are returned by this endpoint.

The layer readiness endpoint projects the same provider inventory into all seven runtime layers and emits explicit blocker strings for missing provider env gates. It is the cloud-side complement to `GET /api/v1/layer-interfaces/contract`.

## Seven-Layer Mapping

| Layer | Cloud responsibility | Providers |
| --- | --- | --- |
| `layer_1` Frontend / Next.js | Hosted frontend and staging proof origin | Vercel / hosted frontend |
| `layer_2` Orchestrator / LangGraph | Runtime host and API service boundary | Hetzner Cloud |
| `layer_3` Agent Pool | Agent worker runtime host | Hetzner Cloud |
| `layer_4` LLM Gateway | Edge, AI gateway, and optional model identity | Cloudflare, Hugging Face |
| `layer_5` MCP Gateway / Tools | CI, registry, branch protection, optional mirror and developer-workspace identity | GitHub Actions, GHCR, GitLab, GitKraken |
| `layer_6` Memory / PostgreSQL pgvector | PostgreSQL/pgvector home | Hetzner Cloud |
| `layer_7` Observability / Evidence | Hosted proof, live budget proof, audit gate visibility | Vercel, Hetzner, Cloudflare, GitHub Actions, GitKraken |

## Providers

The local contract exposes eight provider slots:

1. `vercel_frontend`
2. `hetzner_cloud`
3. `cloudflare_edge`
4. `github_actions`
5. `ghcr_registry`
6. `huggingface_identity`
7. `gitlab_identity`
8. `gitkraken_identity`

Every provider record includes:

- `configured`: whether any required or optional environment binding is visible.
- `live_verified`: whether the endpoint performed a successful read-only live proof.
- `required_env` and `optional_env`: names only, never values.
- `env_status`: per-key configured/missing booleans only.
- `resources`: sanitized resource metadata.
- `non_claims`: fail-closed statements for the provider.

## Cloud Layer Readiness

`GET /api/v1/clouds/layers` returns:

- `ready_layer_count`
- `partial_layer_count`
- `total_layer_count`
- one record for each of the seven architecture layers
- `required_providers`
- `configured_providers`
- `live_verified_providers`
- `blockers`
- `next_safe_action`

Layer statuses are fail-closed:

- `live_verified` only when all required provider reads for the layer are live-verified.
- `partial_live_verified` when at least one provider is live-verified but the layer is not complete.
- `action_required` when provider env gates or live reads are missing.

No layer readiness status is a production deployment claim.

## Provider Live Reads

All live reads in this contract are token-gated, read-only, cached briefly by the Agent API, and fail closed to `api_error` without returning token values.

### Vercel Live Read

If `VERCEL_TOKEN` is configured, the Agent API calls Vercel read-only endpoints:

- `/v2/user` to verify the authenticated account.
- `/v10/projects` to list project metadata when the token scope allows it.

Rules:

- The token is never returned.
- `STAGING_BASE_URL` is still required before layer 1 can be treated as ready.
- Project reads may produce `partial_verified` while account verification can still remain live-verified.
- No deployment, environment variable, alias, domain, or rollback write is performed.

### Hetzner Live Read

If `HETZNER_API_TOKEN` is configured, the Agent API calls Hetzner Cloud read-only endpoints for servers, volumes, primary IPs, and floating IPs.

Rules:

- The token is never returned.
- Public IP addresses are masked in the dashboard payload.
- Server monthly gross prices from the Hetzner API feed the infrastructure budget as `hetzner_api_readonly`.
- Volume resources are listed, but volume pricing is not added unless a verified cost source exposes it.
- If the API call fails, the endpoint reports `api_error` and the infrastructure budget falls back to the configured Phase-1 projection.

### Cloudflare Live Read

If `CLOUDFLARE_API_TOKEN` is configured, the Agent API calls Cloudflare read-only endpoints:

- `/user/tokens/verify` to prove the token is valid without returning the token value.
- `/accounts/{account_id}` when `CLOUDFLARE_ACCOUNT_ID` is configured.
- `/zones/{zone_id}` when `CLOUDFLARE_ZONE_ID` is configured.

Rules:

- The token is never returned.
- Dashboard and AI Gateway URLs are reduced to non-secret host metadata.
- Optional account or zone read failures produce `partial_verified` while token verification can still remain live-verified.
- No DNS, Workers, AI Gateway, cache, or security rule write is performed.

### GitHub Live Read

If `GITHUB_TOKEN` is configured, the Agent API calls GitHub read-only endpoints:

- `/user` to verify the authenticated account.
- `/repos/{owner}/{repo}` when `GITHUB_REPOSITORY` is configured.

Rules:

- The token is never returned.
- Branch protection success is not claimed from this account check alone.
- No workflow dispatch, branch, commit, pull request, package, or repository write is performed.

### GHCR Live Read

If `GHCR_TOKEN` is configured, the Agent API calls the GitHub Packages read-only endpoint for authenticated-user container packages.

Rules:

- The token is never returned.
- Empty package lists can still prove the token can reach the package API.
- No image push, delete, package visibility change, or production pull is performed.

### Hugging Face Live Read

If `HF_TOKEN` is configured, the Agent API calls the Hugging Face authenticated `whoami` API.

Rules:

- The token is never returned.
- Hugging Face Spaces is not treated as the production runtime.
- No model, dataset, Space, inference endpoint, organization, or token write is performed.

### GitLab Live Read

If `GITLAB_TOKEN` is configured, the Agent API calls GitLab `GET /user` against `GITLAB_API_URL` or `https://gitlab.com/api/v4`.

Rules:

- The token is never returned.
- GitLab identity is optional and not a production-release gate in the patched architecture.
- No project, mirror, issue, pipeline, repository, group, or user write is performed.

### GitKraken Live Read

If `GITKRAKEN_API_TOKEN` is configured, the Agent API calls the GitKraken/GitClear read-only token-status endpoint `GET /api_tokens` against `GITKRAKEN_API_URL` or `https://gitkraken.gitclear.com/api/v1`.

Rules:

- The token is never returned.
- `GITKRAKEN_ORG_ID`, `GITKRAKEN_ORG_NAME`, and `GITKRAKEN_DASHBOARD_URL` are treated as optional metadata only.
- GitKraken identity is optional and does not replace GitHub branch protection or GHCR image proof.
- No organization, user, billing, team, workspace, repository, issue, or integration write is performed.

## Fail-Closed Rules

- No production deployment is claimed.
- No hosted staging success is claimed without `STAGING_BASE_URL` and the hosted verifier.
- No cloud-only success is claimed if the frontend is deployed without hosted Agent API, MCP Gateway, and LLM Gateway rewrites.
- No protected-main success is claimed without `BRANCH_PROTECTION_TOKEN` or an equivalent verified GitHub token.
- No Vercel hosted frontend state is claimed without `VERCEL_TOKEN`.
- No Hetzner live infrastructure state is claimed without `HETZNER_API_TOKEN`.
- No Cloudflare live edge state is claimed without `CLOUDFLARE_API_TOKEN`.
- No GitHub CI/CD state is claimed without `GITHUB_TOKEN`.
- No GHCR registry state is claimed without `GHCR_TOKEN`.
- No Hugging Face identity state is claimed without `HF_TOKEN`.
- No GitLab identity state is claimed without `GITLAB_TOKEN`.
- No GitKraken identity state is claimed without `GITKRAKEN_API_TOKEN`.
- No Cloudflare DNS, AI Gateway, GitHub, GHCR, GitLab, GitKraken, Hugging Face, or Vercel write is performed by this endpoint.
- The dashboard may show configured/missing status, never raw token material.

## Verification

Static verification must check:

- `services/agent-api/app/clouds.py` compiles.
- `GET /api/v1/clouds` returns `cloud-provider-inventory-v1`.
- `GET /api/v1/clouds/layers` returns `cloud-layer-readiness-v1`.
- The frontend renders `Cloud Inventory`, `GET /api/v1/clouds`, `7 Layer Map`, and `cloud_provider_inventory_visible`.
- The frontend renders `Cloud 7-Layer Readiness`, `GET /api/v1/clouds/layers`, and `cloud_layer_readiness_visible`.
- Secret scans pass with no provider token persisted.
