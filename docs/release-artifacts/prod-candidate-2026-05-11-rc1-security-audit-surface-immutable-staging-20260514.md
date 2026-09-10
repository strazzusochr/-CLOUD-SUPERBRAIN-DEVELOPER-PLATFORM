# Phase 3 Security Audit Surface Immutable Staging Proof

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
candidate_sha: `54bb064c8a5650f9a5c811179d3b4d0e1f38cfbf`
verified_at_utc: `2026-05-14T01:41:37Z`
environment: `hetzner-staging`
base_url: `https://188-34-191-140.sslip.io`
production_rollout_claimed: `false`

## Evidence

- Added `GET /api/v1/security/events/contract` and `GET /api/v1/security/events` as a read-only, audit-log-backed Product Surface & Security view.
- Frontend renders `Security Audit Surface` with `security-audit-surface-v1`, `security_audit_surface_visible`, `security_audit_event_visible`, and `GET /api/v1/security/events`.
- Local checks passed before build: `py -3 -m py_compile services\agent-api\app\main.py`, `npm run build`, `scripts\verify-phase3-security-audit-surface-hosted.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, and `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`.
- Docker Desktop readiness was proven with `docker info --format '{{.ServerVersion}}'`; arm64 binfmt was installed with `docker run --privileged --rm tonistiigi/binfmt --install arm64`.
- GHCR images for all six application services were built and pushed with `scripts\build-and-push.ps1 -Tag 54bb064c8a5650f9a5c811179d3b4d0e1f38cfbf -Platforms linux/arm64 -Builder codex-multiarch`.
- Staging deploy used `scripts\deploy-to-staging.ps1 -UseImageFilesystem -ImageTag 54bb064c8a5650f9a5c811179d3b4d0e1f38cfbf`.
- Remote `.env` selector is `IMAGE_TAG=54bb064c8a5650f9a5c811179d3b4d0e1f38cfbf`.
- Running service images use `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:54bb064c8a5650f9a5c811179d3b4d0e1f38cfbf`.
- Hosted checks passed: Security Audit Surface verifier, browser-contract verifier, and hosted staging smoke.

## Verification Commands

- `scripts\verify-phase3-security-audit-surface-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-browser-contract.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-hosted-staging-smoke.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-current-immutable-staging-parity.ps1 -RequireVerified -BaseUrl https://188-34-191-140.sslip.io -KeyPath <local-private-key>`
- `scripts\manual\verify-phase5-staging-immutable-parity.ps1 -RequireVerified -ReleaseId prod-candidate-2026-05-11-rc1 -CandidateSha 54bb064c8a5650f9a5c811179d3b4d0e1f38cfbf -BaseUrl https://188-34-191-140.sslip.io -KeyPath <local-private-key>`

## Non-Claims

- No production rollout was performed.
- No production tag promotion was performed.
- No live provider call is claimed.
- No live MCP write is claimed.
- No secret value is recorded in this proof.
