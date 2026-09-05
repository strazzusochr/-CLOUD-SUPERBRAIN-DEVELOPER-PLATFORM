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
| `layer_2` Orchestrator / LangGraph | Runtime host and API service boundary | Cloudflare-native stateful runtime |
| `layer_3` Agent Pool | Agent worker runtime host | Cloudflare-native stateful runtime |
| `layer_4` LLM Gateway | Gateway-only Workers AI path and optional model identity | Cloudflare, Hugging Face |
| `layer_5` MCP Gateway / Tools | CI, registry, branch protection, optional mirror and developer-workspace identity | GitHub Actions, GHCR, GitLab |
| `layer_6` Memory | Cloudflare D1 bounded-text artifacts/persistence, Durable Object coordination, Queue dispatch, and separately gated Vectorize; R2 is historical-only | Cloudflare-native stateful runtime |
| `layer_7` Observability / Evidence | Hosted proof, zero-card gate, audit gate visibility | Vercel, Cloudflare, GitHub Actions, Grafana Cloud |

## Providers

The local contract exposes eight provider slots:

1. `vercel_frontend`
2. `fly_io`
3. `cloudflare_edge`
4. `github_actions`
5. `ghcr_registry`
6. `huggingface_identity`
7. `gitlab_identity`
8. `grafana_cloud`

Fly.io remains visible only as an optional historical/read-only inventory source. It is not an active Layer 2, 3, or 6 deployment target.

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

### Fly.io Historical Read

If `FLY_API_TOKEN` is configured, the Agent API calls Fly.io read-only endpoints for apps, machines, and volumes.

Rules:

- The token is never returned.
- Fly.io reads are `historical_only` and cannot satisfy active Layer 2, 3, 6, preflight, completion, or go-live readiness.
- Public IP addresses are masked in the dashboard payload.
- No Fly.io price or resource read is used by the active zero-card infrastructure budget projection.

### Cloudflare Live Read

If `CLOUDFLARE_API_TOKEN` is configured, the Agent API may call Cloudflare read-only endpoints:

- `/user/tokens/verify` to prove the token is valid without returning the token value.
- `/accounts/{account_id}` when `CLOUDFLARE_ACCOUNT_ID` is configured.
- `/zones/{zone_id}` when `CLOUDFLARE_ZONE_ID` is configured.

Rules:

- The token is never returned.
- Active Layer 2, 3, and 6 readiness additionally requires `CLOUDFLARE_STATEFUL_BASE_URL`, `CLOUDFLARE_ACCOUNT_ID`, the least-privilege scope set, canonical `external-gate-summary-v2` approval, and `scripts/verify-cloudflare-stateful-runtime.ps1`.
- A successful token/account read does not prove the Cloudflare-native hosted runtime.
- The bounded O6 Workers AI gateway proof does not make Layer 4 equal 100 or prove the stateful hosted runtime.
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

### Grafana Cloud Live Read

If `GRAFANA_CLOUD_API_KEY` is configured, the Agent API performs one real provider read:

- `glc_` Cloud Access Policy tokens call fixed host `https://grafana.com/api/v1/accesspolicies` with `pageSize=1` and the validated region from the token metadata.
- `glsa_` service-account tokens call `GET /api/access-control/user/permissions` on the configured HTTPS `*.grafana.net` instance.

Rules:

- The token is never returned.
- Decoding `glc_` routing metadata alone is never accepted as live evidence; the provider request must succeed.
- Cloud Access Policy tokens are never sent to the Grafana instance HTTP API.
- A successful identity read proves credential/provider access, not telemetry ingestion or stack availability.
- `GRAFANA_CLOUD_URL` is metadata for `glc_` tokens and the allowlisted instance target for `glsa_` tokens.
- No dashboard creation, log mutation, alert modification, or team configuration write is performed.

## Fail-Closed Rules

- No production deployment is claimed.
- No hosted staging success is claimed without `STAGING_BASE_URL` and the hosted verifier.
- No cloud-only success is claimed if the frontend is deployed without hosted Agent API, MCP Gateway, and LLM Gateway rewrites.
- No protected-main success is claimed without `BRANCH_PROTECTION_TOKEN` or an equivalent verified GitHub token.
- No Vercel hosted frontend state is claimed without `VERCEL_TOKEN`.
- No Fly.io read is treated as an active runtime claim; Fly remains historical only.
- No Cloudflare-native hosted runtime state is claimed without canonical `cloudflare_native_zero_card_hosted_runtime_claim_allowed=true`.
- No Cloudflare management-plane read is claimed without `CLOUDFLARE_API_TOKEN`.
- No GitHub CI/CD state is claimed without `GITHUB_TOKEN`.
- No GHCR registry state is claimed without `GHCR_TOKEN`.
- No Hugging Face identity state is claimed without `HF_TOKEN`.
- No GitLab identity state is claimed without `GITLAB_TOKEN`.
- No Grafana Cloud observability state is claimed without `GRAFANA_CLOUD_API_KEY`.
- No Cloudflare DNS, Workers, D1, Durable Object, Queue, R2, Vectorize, AI Gateway, GitHub, GHCR, GitLab, Grafana Cloud, Hugging Face, Vercel, or Fly.io write is performed by this endpoint.
- The dashboard may show configured/missing status, never raw token material.

## Verification

Static verification must check:

- `services/agent-api/app/clouds.py` compiles.
- `GET /api/v1/clouds` returns `cloud-provider-inventory-v1`.
- `GET /api/v1/clouds/layers` returns `cloud-layer-readiness-v1`.
- The frontend renders `Cloud Inventory`, `GET /api/v1/clouds`, `7 Layer Map`, and `cloud_provider_inventory_visible`.
- The frontend renders `Cloud 7-Layer Readiness`, `GET /api/v1/clouds/layers`, and `cloud_layer_readiness_visible`.
- Secret scans pass with no provider token persisted.
