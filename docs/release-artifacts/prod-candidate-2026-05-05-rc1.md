# Release Artifact

release_id: `prod-candidate-2026-05-05-rc1`
scope: `frontend, agent-api, mcp-gateway, llm-gateway, nginx/caddy, hosted staging truth, phase-5 release-readiness artifacts`
environment: `production-candidate`
source_branch: `chore/repo-bootstrap`
source_commit_sha: `ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`
workflow_run_url: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25392582005`
pipeline_status: `success via main-deploy run 25392582005 on commit ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`
smoke_result: `passed`
observability_check: `present`
rollback_note: `executed rollback proof exists for immutable GHCR tag set :ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5; hosted selector was switched to IMAGE_TAG=ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5, verified live, then restored to IMAGE_TAG=staging`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`
rollback_drill_proof: `.phase1-artifacts/phase5-rollback-drill-prod-candidate-20260505-rc1.md`
executed_rollback_proof: `.phase1-artifacts/phase5-executed-rollback-prod-candidate-20260505-rc1.md`
owner_decision_proof: `.phase1-artifacts/phase5-owner-decision-no-release-20260505.md`
executed_smoke_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-smoke-proof.md`
incident_drill_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-incident-drill.md`
observability_review_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-observability-review.md`
browser_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md`
secret_rotation_drill_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-secret-rotation-drill.md`
provider_failover_drill_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-provider-failover-drill.md`
memory_recovery_drill_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-memory-recovery-drill.md`
handoff_packet_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-handoff-packet.md`
risk_review_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-risk-review.md`
post_handoff_stability_watch_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-handoff-stability-watch.md`
promotion_gate_refusal_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-promotion-gate-refusal.md`
review_gate: `reviewed`
owner_decision: `no-release`

## Code Readiness

- [x] CI/CD successful
- [x] Smoke successful
- [x] Integration plan documented
- [x] Docs/registers aligned
- [x] No unexplained critical/high blocker

## Infrastructure Readiness

- [x] Hosted staging verified
- [x] GHCR candidate images verified
- [x] Rollback path named
- [x] Budget impact reviewed
- [x] No unresolved branch/secret/auth gate

## Observability Readiness

- [x] Health paths named
- [x] Metrics paths named
- [x] Audit paths named
- [x] Evidence artifacts linked
- [x] Escalation path named

## Operations Readiness

- [x] Rollback runbook applicable
- [x] Incident response runbook present
- [x] Secret rotation runbook present
- [x] Owner review documented
- [x] Production non-claim preserved until rollout proof exists

## Evidence

- Hosted browser proof: `.phase1-artifacts/hosted-browser-proof-20260504-235540.md`
- External gate audit proof: `.phase1-artifacts/external-gate-audit-20260504-212633.json`
- Rollback readiness proof: `.phase1-artifacts/phase5-rollback-readiness-20260505.md`
- Rollback drill proof: `.phase1-artifacts/phase5-rollback-drill-prod-candidate-20260505-rc1.md`
- Executed rollback proof: `.phase1-artifacts/phase5-executed-rollback-prod-candidate-20260505-rc1.md`
- Owner decision proof: `.phase1-artifacts/phase5-owner-decision-no-release-20260505.md`
- Integration plan proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-plan.md`
- Executed smoke proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-smoke-proof.md`
- Incident drill proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-incident-drill.md`
- Observability review proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-observability-review.md`
- Browser proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md`
- Secret rotation drill proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-secret-rotation-drill.md`
- Provider failover drill proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-provider-failover-drill.md`
- Memory recovery drill proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-memory-recovery-drill.md`
- Handoff packet proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-handoff-packet.md`
- Risk review proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-risk-review.md`
- Post-handoff stability watch proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-handoff-stability-watch.md`
- Promotion gate refusal proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-promotion-gate-refusal.md`
- Hosted URL: `https://188-34-191-140.sslip.io`
- Workflow run: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25392582005`
- Verify job: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25392582005/job/74470756685`
- Build/push jobs:
  - `agent-api`: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25392582005/job/74471031188`
  - `mcp-gateway`: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25392582005/job/74471031206`
  - `frontend`: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25392582005/job/74471031197`
  - `llm-gateway`: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25392582005/job/74471031182`
  - `agent-worker`: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25392582005/job/74471031176`
  - `memory-worker`: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25392582005/job/74471031226`
- Hosted runtime health endpoints:
  - `GET /`
  - `GET /api/v1/health`
  - `GET /mcp/api/v1/health`
  - `GET /llm/api/v1/health`
- GHCR candidate references:
  - `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/agent-api:staging`
  - `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/mcp-gateway:staging`
  - `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/frontend:staging`
  - `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/llm-gateway:staging`
  - `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/agent-worker:staging`
  - `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/memory-worker:staging`
- Immutable rollback tag set:
  - `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/agent-api:ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`
  - `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/mcp-gateway:ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`
  - `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/frontend:ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`
  - `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/llm-gateway:ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`
  - `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/agent-worker:ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`
  - `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/memory-worker:ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`

## Notes

- This is a production-candidate artifact, not a production rollout artifact.
- `Owner review documented` is now closed with an explicit `no-release` decision for this candidate.
- The rollback note is candidate-scoped and now names one immutable rollback target set with an executed hosted rollback proof.
- `no-release` means this candidate remains a verified production-candidate artifact only; it is not promoted to a rollout artifact.
