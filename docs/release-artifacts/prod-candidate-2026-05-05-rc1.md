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
staging_tag_parity_status: `blocked`
staging_tag_parity_blocked_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-staging-parity-blocked.md`
repo_worktree_parity_blocked_proof: `.phase1-artifacts/phase5-repo-worktree-parity-blocked-20260507.md`
rollback_drill_proof: `.phase1-artifacts/phase5-rollback-drill-prod-candidate-20260505-rc1.md`
executed_rollback_reference: `.phase1-artifacts/phase5-executed-rollback-prod-candidate-20260505-rc1.md`
executed_rollback_rerun_proof: `.phase1-artifacts/phase5-executed-rollback-rerun-20260507.md`
owner_decision_proof: `.phase1-artifacts/phase5-owner-decision-no-release-20260505.md`
owner_decision_reconciliation_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-owner-decision-reconciliation.md`
executed_smoke_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-smoke-proof.md`
incident_drill_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-incident-drill.md`
observability_review_reference: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-observability-review.md`
secret_rotation_drill_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-secret-rotation-drill.md`
provider_failover_drill_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-provider-failover-drill.md`
memory_recovery_drill_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-memory-recovery-drill.md`
handoff_packet_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-handoff-packet.md`
risk_review_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-risk-review.md`
post_handoff_stability_watch_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-handoff-stability-watch.md`
promotion_gate_refusal_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-promotion-gate-refusal.md`
post_rollback_requalification_reference: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-requalification.md`
post_rollback_requalification_rerun_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-requalification-rerun.md`
post_rollback_stability_watch_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-stability-watch.md`
post_rollback_promotion_gate_refusal_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-promotion-gate-refusal.md`
post_rollback_observability_revalidation_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-observability-revalidation.md`
post_rollback_provenance_revalidation_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-provenance-revalidation.md`
post_rollback_completion_gate_freeze_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-completion-gate-freeze.md`
post_phase4_rebaseline_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-phase4-rebaseline.md`
runbook_applicability_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-runbook-applicability.md`
checklist_conformance_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-checklist-conformance.md`
integration_plan_rebaseline_reference: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-plan-rebaseline.md`
integration_smoke_plan_rerun_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-smoke-plan-rerun.md`
auth_gate_recheck_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-auth-gate-recheck.md`
budget_review_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-budget-review.md`
open_questions_acceptance_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-open-questions-acceptance.md`
risk_review_recheck_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-risk-review-recheck.md`
provenance_review_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-provenance-review.md`
smoke_recheck_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-smoke-recheck.md`
observability_recheck_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-observability-recheck.md`
historical_browser_evidence_reactivation_proof: `.phase1-artifacts/phase5-browser-evidence-reactivation-20260507.md`
historical_browser_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md`
historical_post_rollback_browser_revalidation_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-browser-revalidation.md`
historical_final_browser_e2e_recheck_proof: `.phase1-artifacts/phase5-final-browser-e2e-recheck-20260507.md`
historical_full_verifier_sweep_proof: `.phase1-artifacts/phase5-full-verifier-sweep-20260507.md`
historical_truth_mirror_rebaseline_proof: `.phase1-artifacts/phase5-truth-mirror-rebaseline-20260507.md`
release_readiness_rerun_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-release-readiness-rerun.md`
browser_rerun_status: `superseded; historical sslip/Hetzner browser artifacts retained for provenance only; current browser evidence requires Vercel HTTPS STAGING_BASE_URL plus reachable Fly origins`
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
- [x] Release-relevant open questions explicitly accepted for this candidate
- [x] Production non-claim preserved until rollout proof exists

## Evidence

- Historical hosted browser baseline only (not current candidate evidence): `.phase1-artifacts/hosted-browser-proof-20260504-235540.md`
- External gate audit proof: `.phase1-artifacts/external-gate-audit-20260510-001431.json`
- Staging tag parity blocked proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-staging-parity-blocked.md`
- Repo worktree parity blocked proof: `.phase1-artifacts/phase5-repo-worktree-parity-blocked-20260507.md`
- Rollback readiness proof: `.phase1-artifacts/phase5-rollback-readiness-20260505.md`
- Rollback drill proof: `.phase1-artifacts/phase5-rollback-drill-prod-candidate-20260505-rc1.md`
- Historical executed rollback reference: `.phase1-artifacts/phase5-executed-rollback-prod-candidate-20260505-rc1.md`
- Executed rollback rerun proof: `.phase1-artifacts/phase5-executed-rollback-rerun-20260507.md`
- Owner decision proof: `.phase1-artifacts/phase5-owner-decision-no-release-20260505.md`
- Owner decision reconciliation proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-owner-decision-reconciliation.md`
- Historical integration plan reference: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-plan.md`
- Executed smoke proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-smoke-proof.md`
- Incident drill proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-incident-drill.md`
- Historical observability review reference: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-observability-review.md`
- Secret rotation drill proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-secret-rotation-drill.md`
- Provider failover drill proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-provider-failover-drill.md`
- Memory recovery drill proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-memory-recovery-drill.md`
- Handoff packet proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-handoff-packet.md`
- Risk review proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-risk-review.md`
- Post-handoff stability watch proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-handoff-stability-watch.md`
- Promotion gate refusal proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-promotion-gate-refusal.md`
- Historical post-rollback requalification reference: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-requalification.md`
- Post-rollback requalification rerun proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-requalification-rerun.md`
- Post-rollback stability watch proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-stability-watch.md`
- Post-rollback promotion gate refusal proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-promotion-gate-refusal.md`
- Post-rollback observability revalidation proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-observability-revalidation.md`
- Post-rollback provenance revalidation proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-provenance-revalidation.md`
- Post-rollback completion gate freeze proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-completion-gate-freeze.md`
- Post-phase4 rebaseline proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-phase4-rebaseline.md`
- Runbook applicability proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-runbook-applicability.md`
- Checklist conformance proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-checklist-conformance.md`
- Historical integration plan rebaseline reference: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-plan-rebaseline.md`
- Active integration smoke plan proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-smoke-plan-rerun.md`
- Auth gate recheck proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-auth-gate-recheck.md`
- Budget review proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-budget-review.md`
- Open questions acceptance proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-open-questions-acceptance.md`
- Risk review recheck proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-risk-review-recheck.md`
- Provenance review proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-provenance-review.md`
- Smoke recheck proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-smoke-recheck.md`
- Observability recheck proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-observability-recheck.md`
- Historical browser evidence reactivation proof: `.phase1-artifacts/phase5-browser-evidence-reactivation-20260507.md`
- Historical browser proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md`
- Historical post-rollback browser revalidation proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-browser-revalidation.md`
- Historical final browser E2E recheck proof: `.phase1-artifacts/phase5-final-browser-e2e-recheck-20260507.md`
- Historical full verifier sweep proof: `.phase1-artifacts/phase5-full-verifier-sweep-20260507.md`
- Historical truth mirror rebaseline proof: `.phase1-artifacts/phase5-truth-mirror-rebaseline-20260507.md`
- Release readiness rerun proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-release-readiness-rerun.md`
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
- The executed rollback lane and the post-rollback requalification lane were rerun again on `2026-05-07` against the current hosted truth.
- Hosted staging currently follows the mutable selector `IMAGE_TAG=staging`; digest parity against the immutable candidate tag set is blocked and is not claimed. Service hot-mounts can also override image-contained code, so runtime parity requires an image-filesystem deploy or a freshly built immutable candidate.
- Current repository `HEAD` and worktree are not claimed as candidate-equal; repo/worktree parity to `ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5` remains explicitly blocked.
- AI-browser reruns from `2026-05-07` are historical sslip/Hetzner provenance only; current browser evidence requires Vercel HTTPS `STAGING_BASE_URL` plus reachable Fly origins.
- Release readiness was rerun again on `2026-05-07` against the same active candidate and hosted truth.
- `no-release` means this candidate remains a verified production-candidate artifact only; it is not promoted to a rollout artifact.
