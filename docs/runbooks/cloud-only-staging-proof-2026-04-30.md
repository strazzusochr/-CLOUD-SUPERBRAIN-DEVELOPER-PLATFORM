# Cloud-Only Staging Proof 2026-04-30

Status: `action_required`

Cloud frontend preview:

- `https://frontend-mzssjbtcw-strazzusochrs-projects.vercel.app`
- Vercel deployment: `dpl_CvU8PHAUT8CEGTfjXdELTm6qQ16S`
- `/` returned the Cloud Superbrain UI.
- `/health` returned `ok`.
- `/api/health` returned the frontend health contract.

Cloud-only verifier:

- Script: `scripts/verify-cloud-only-staging.ps1`
- Artifact: `.phase1-artifacts/cloud-only-staging-proof-20260430-124141.json`
- Result: `action_required`
- Localhost allowed: `false`

Browser evidence:

- Playwright snapshot: `cloud-preview-redeploy-snapshot-20260430.md`
- Playwright screenshot: `cloud-preview-redeploy-viewport-20260430.png`
- Chrome DevTools/Lighthouse artifact: `.phase1-artifacts/lighthouse-cloud-redeploy-20260430/`
- Lighthouse snapshot scores: Accessibility `94`, Best Practices `100`, SEO `100`

Current cloud blockers:

- `cloud_agent_api_health`
- `cloud_provider_inventory`
- `cloud_layer_readiness`
- `cloud_mcp_gateway_health`
- `cloud_llm_gateway_health`

Observed root cause:

- Vercel frontend is live.
- The frontend now supports cloud rewrites via `AGENT_API_BASE_URL`, `MCP_GATEWAY_BASE_URL`, and `LLM_GATEWAY_BASE_URL`.
- No Vercel environment variables are configured for those cloud backend URLs.
- Historical note: the old Hetzner path is not an active staging gate.
- Active staging proof must use Vercel/Fly.io HTTPS targets.
- `hcloud` is installed but has no active context or token.
- GitHub CLI has an invalid stored token, so workflow dispatch and branch-protection verification are blocked.

Follow-up substrate patch:

- `docker-compose.cloud.yml` now defines the pull-based Fly.io/GHCR stack for `frontend`, `agent-api`, `agent-worker`, `memory-worker`, `mcp-gateway`, `llm-gateway`, `postgres`, `redis`, and `nginx`.
- `.github/workflows/main-deploy.yml` now publishes all six application images to the stable lowercase namespace `ghcr.io/${{ github.repository_owner }}/cloud-superbrain-developer-platform/<service>`.
- `infrastructure/nginx/cloud.conf` routes `/`, `/api/`, `/mcp/`, `/llm/`, and `/health` inside the cloud stack.
- Fly.io usage expects a repo checkout or release bundle with `docs/project-progress.manifest.json`, then `GHCR_IMAGE_NAMESPACE=ghcr.io/strazzusochr/cloud-superbrain-developer-platform` and `IMAGE_TAG=staging` before `docker compose -f docker-compose.cloud.yml pull` and `docker compose -f docker-compose.cloud.yml up -d`.
- After the Fly.io backend is reachable, set Vercel `AGENT_API_BASE_URL`, `MCP_GATEWAY_BASE_URL`, and `LLM_GATEWAY_BASE_URL` to that cloud origin, then rerun `scripts/verify-cloud-only-staging.ps1` without `-AllowLocalhost`.

Non-claims:

- This is not hosted staging success.
- This is not production deployment.
- This is not a live Agent API, MCP Gateway, or LLM Gateway cloud proof.
- No provider token values are stored in this file.
