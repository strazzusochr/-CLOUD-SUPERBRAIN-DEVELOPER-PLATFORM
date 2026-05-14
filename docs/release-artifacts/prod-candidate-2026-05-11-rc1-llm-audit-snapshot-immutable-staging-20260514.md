# LLM Audit Snapshot Immutable Staging Proof

Release ID: `prod-candidate-2026-05-11-rc1`
Status: `verified`
Candidate SHA: `f5fb7d221d403b966b38d240bd5b936755ecc245`
Environment: `hetzner-staging`
Production rollout claimed: `false`
Promotion allowed: `false`

## Machine Contract

release_id: `prod-candidate-2026-05-11-rc1`
candidate_sha: `f5fb7d221d403b966b38d240bd5b936755ecc245`
production_rollout_claimed: `false`
hosted_selector_observed: `IMAGE_TAG=f5fb7d221d403b966b38d240bd5b936755ecc245`
image_pattern: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:f5fb7d221d403b966b38d240bd5b936755ecc245`
parity_verifier: `scripts\verify-current-immutable-staging-parity.ps1 -RequireVerified`

## Scope

This proof binds the Phase 3 / Layer 4 LLM Audit Feed Redaction Snapshot to the active immutable staging candidate. It is a read-only audit-log projection and does not enable live provider calls.

## Runtime Evidence

- Contract endpoint: `GET /api/v1/audit/llm/contract`
- Feed endpoint: `GET /api/v1/audit/llm`
- Snapshot endpoint: `GET /api/v1/audit/llm/snapshot`
- Evidence refs: `llm_audit_feed_visible`, `llm_audit_feed_event_visible`, `llm_audit_snapshot_visible`, `llm_audit_redaction_enforced`
- Snapshot fields: `prompt_bodies_returned=false`, `provider_credentials_returned=false`, `forbidden_pattern_hits=0`, `live_provider_calls_claimed=false`

## Verification

- Local compile: `py -3 -m py_compile services\agent-api\app\main.py services\agent-api\app\security.py`
- Frontend build: `npm run build`
- Local verifier: `scripts\verify-phase3-llm-audit-feed.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Local browser contract: `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- GHCR build/push: `scripts\build-and-push.ps1 -Tag f5fb7d221d403b966b38d240bd5b936755ecc245 -Platforms linux/arm64 -Builder codex-multiarch`
- Hetzner deploy: `scripts\deploy-to-staging.ps1 -UseImageFilesystem -ImageTag f5fb7d221d403b966b38d240bd5b936755ecc245`
- Hosted verifier: `scripts\verify-phase3-llm-audit-feed.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Hosted browser contract: `scripts\verify-browser-contract.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Hosted smoke: `scripts\verify-hosted-staging-smoke.ps1 -BaseUrl https://188-34-191-140.sslip.io`

## Non-Claims

- No production rollout.
- No live provider call.
- No live MCP write.
- No provider billing proof.
- No SOC/SIEM completeness claim.
- No secret exposure clearance beyond the verifier-scoped redaction snapshot.
