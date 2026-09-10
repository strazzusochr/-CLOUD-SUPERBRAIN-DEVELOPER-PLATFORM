# Phase 5 Immutable Staging Parity Proof

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
candidate_sha: `031c95c3e5af1101caf282eee463256285803495`
workflow_run_url: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25833000061`
verified_at_utc: `2026-05-14T00:38:28Z`
environment: `hetzner-staging`
base_url: `https://188-34-191-140.sslip.io`
production_rollout_claimed: `false`

## Evidence

- `main-deploy.yml` run `25833000061` passed verify plus `agent-api`, `agent-worker`, `memory-worker`, `mcp-gateway`, and `llm-gateway` GHCR builds on `codex/live-agent-steering-ui-20260513`.
- The frontend source did not change in commit `031c95c3e5af1101caf282eee463256285803495`; after the frontend build job stalled, the previously verified frontend image manifest from `97c7ea04b5180862ea9862cc18b9c5bac994f794` was copied to the new immutable tag with `docker buildx imagetools create`, then the stalled workflow run was force-cancelled.
- GHCR manifests were inspected for all six service tags before the Hetzner deploy.
- Staging deploy used `scripts\deploy-to-staging.ps1 -UseImageFilesystem -ImageTag 031c95c3e5af1101caf282eee463256285803495`.
- Remote `.env` selector is `IMAGE_TAG=031c95c3e5af1101caf282eee463256285803495`.
- Running service images use `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:031c95c3e5af1101caf282eee463256285803495`.
- Remote compose is image-filesystem mode; service hot-mounts are removed.
- Hosted root, Agent API health, MCP Gateway health, LLM Gateway health, and project progress integrity are reachable.

## Verification Commands

- `docker buildx imagetools inspect ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:031c95c3e5af1101caf282eee463256285803495`
- `docker buildx imagetools create -t ghcr.io/strazzusochr/cloud-superbrain-developer-platform/frontend:031c95c3e5af1101caf282eee463256285803495 ghcr.io/strazzusochr/cloud-superbrain-developer-platform/frontend:97c7ea04b5180862ea9862cc18b9c5bac994f794`
- `scripts\deploy-to-staging.ps1 -PlanOnly -UseImageFilesystem -ImageTag 031c95c3e5af1101caf282eee463256285803495`
- `scripts\deploy-to-staging.ps1 -UseImageFilesystem -ImageTag 031c95c3e5af1101caf282eee463256285803495 -KeyPath <local-private-key> -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`
- `scripts\verify-current-immutable-staging-parity.ps1 -RequireVerified -BaseUrl https://188-34-191-140.sslip.io -KeyPath <local-private-key>`

## Non-Claims

- No production rollout was performed.
- No production tag promotion was performed.
- No live provider call is claimed.
- No live MCP write is claimed.
- No secret value is recorded in this proof.

