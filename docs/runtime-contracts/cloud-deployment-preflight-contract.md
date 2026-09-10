# Cloud Deployment Preflight Contract

Contract version: `cloud-deployment-preflight-v1`

Endpoint: `GET /api/v1/clouds/deployment-preflight/contract`

Evidence ref: `cloud_deployment_preflight_visible`

Status: Phase 4 local contract implemented, external execution still gated

## Purpose

This contract exposes the exact external actions that must be completed before any cloud deployment, hosted staging success, or production release claim is allowed.

Environment variables, installed tools, and static workflow files are only prerequisites. They never count as proof that GHCR images were published, the Cloudflare-native stateful runtime passed its hosted verifier, Vercel uses hosted backend origins, branch protection is current, or secrets were scanned.

## Required Sequence

1. `publish_ghcr_images`
2. `verify_cloudflare_native_zero_card_hosted_runtime`
3. `configure_vercel_backend_origins`
4. `run_hosted_staging_verifier`
5. `verify_branch_protection`
6. `run_canonical_secret_scan`
7. `owner_review_before_production`

## Required Gates

| Gate | Required env | Required verifier | Evidence |
| --- | --- | --- | --- |
| `ghcr_images` | `GITHUB_TOKEN`, `GHCR_TOKEN` | `docker manifest inspect` for all service images | `ghcr_image_digest_proof` |
| `cloudflare_native_zero_card_hosted_runtime` | `CLOUDFLARE_STATEFUL_BASE_URL`, `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_API_TOKEN` | `scripts/verify-cloudflare-stateful-runtime.ps1` | `cloudflare_native_zero_card_hosted_runtime` |
| `hosted_backend_origins` | `AGENT_API_BASE_URL`, `MCP_GATEWAY_BASE_URL`, `LLM_GATEWAY_BASE_URL` | `scripts/verify-cloud-only-staging.ps1` | `hosted_backend_origin_env_required` |
| `hosted_staging` | `STAGING_BASE_URL` | `scripts/verify-hosted-staging.ps1` against HTTPS non-local URL | `hosted_staging_base_url_required` |
| `branch_protection` | `BRANCH_PROTECTION_TOKEN` | `scripts/apply_github_branch_protection.py --verify-only --branch main` | `branch_protection_verify_contract` |
| `canonical_secret_scan` | none | `gitleaks detect --no-git --source .` | `canonical_gitleaks_scan` |

## Fail-Closed Rules

- Runtime gate claims are derived from the sanitized canonical external-gate summary; progress-manifest integration markers are never release-gate authority.
- `cloud_deploy_claim_allowed` is `true` only when every required canonical gate is verified and the summary allows the hosted staging claim.
- `production_deploy_claim_allowed` is `true` only when the canonical summary is `verified`, has no missing gates, and explicitly allows the production claim.
- `configured` remains `false` until verifier artifacts prove the gate, even when env keys are present.
- `environment_configured` only means the process can see required env-key names.
- The Cloudflare-native O2Core gate additionally requires least-privilege
  `workers_scripts_edit`, `d1_edit`, `durable_objects_edit` and `queues_edit`
  scope evidence from the named verifier. R2 is `historical_only`, has no
  active binding and is not a conditional hosted prerequisite.
- `manual_external_actions` are instructions for owner-gated execution, not commands the API runs.
- Localhost is `dev_control_plane_only` and cannot satisfy hosted staging.
- No provider token value may be returned, logged, or written to generated artifacts.

## Verification

Static, runtime, hosted-local, cloud-only, and external-gate verifiers must assert:

- API contract version `cloud-deployment-preflight-v1`.
- Endpoint `GET /api/v1/clouds/deployment-preflight/contract`.
- Evidence ref `cloud_deployment_preflight_visible`.
- `canonical_summary_status` and `canonical_summary_source_artifact` match the sanitized summary.
- Cloud and production claims equal the canonical summary-derived expected values; they remain `false` for the current blocked standard bootstrap.
- Required sequence contains `publish_ghcr_images`, `verify_cloudflare_native_zero_card_hosted_runtime`, `configure_vercel_backend_origins`, and `owner_review_before_production`.
- `BRANCH_PROTECTION_TOKEN`, `CLOUDFLARE_STATEFUL_BASE_URL`, the least-privilege Cloudflare scope markers, `scripts/verify-cloudflare-stateful-runtime.ps1`, and `canonical_secret_scan` remain visible as gates.
