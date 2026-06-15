# Cloud Render Offload Contract

Contract version: `cloud-render-offload-v1`

Endpoint: `GET /api/v1/clouds/render-offload/contract`

Evidence ref: `cloud_render_offload_contract_visible`

Status: Phase 4 local contract implemented, cloud live proof still gated

## Purpose

This contract protects the local Windows/Home-PC workstation from becoming the heavy graphics runtime.

Localhost is allowed only as a lightweight development control plane for API contracts, dashboard visibility, and fail-closed verifiers. It must not be treated as the production or hosted staging runtime for heavy WebGL, 3D rendering, GPU browser smoke, generated graphics, texture previews, or video capture.

## Required Cloud Gates

The contract remains `action_required` until these environment bindings exist in the running Agent API process:

- `STAGING_BASE_URL`
- `AGENT_API_BASE_URL`
- `MCP_GATEWAY_BASE_URL`
- `LLM_GATEWAY_BASE_URL`
- `FLY_API_TOKEN`

Optional provider bindings may enrich proof but do not replace the required gates:

- `VERCEL_TOKEN`
- `CLOUDFLARE_API_TOKEN`
- `GITHUB_TOKEN`
- `GHCR_TOKEN`
- `GRAFANA_CLOUD_API_KEY`

## Workload Policy

| Workload | Localhost | Required runtime |
| --- | --- | --- |
| `webgl_3d_rendering` | blocked | hosted cloud browser or cloud GPU worker |
| `browser_gpu_smoke` | blocked | hosted cloud browser proof |
| `asset_generation` | blocked | cloud worker queue |
| `control_plane` | allowed | localhost dev control plane only |

## Fail-Closed Rules

- `localhost_heavy_render_allowed` is always `false`.
- Missing cloud env bindings are emitted as `cloud_render_offload_requires_<ENV_KEY>` blockers.
- The contract does not start cloud servers.
- The contract does not claim production deployment.
- The contract does not bypass the Fly.io budget guard.
- The contract does not store or return provider token values.

## Verification

Static and runtime verifiers must assert:

- API contract version `cloud-render-offload-v1`.
- Endpoint `GET /api/v1/clouds/render-offload/contract`.
- Evidence ref `cloud_render_offload_contract_visible`.
- `localhost_heavy_render_allowed=false`.
- Blocker `cloud_render_offload_requires_STAGING_BASE_URL` while hosted staging is not configured.
- Frontend renders `Cloud Render Offload`.
