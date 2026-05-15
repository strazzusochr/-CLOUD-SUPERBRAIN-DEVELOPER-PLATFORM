# Release Artifact

release_id: `prod-candidate-2026-05-11-rc1`
scope: `release-boundary cleanup, HF router truth, frontend build, agent-api/runtime compile checks, hosted staging smoke checks, immutable staging image candidate, Phase 2 Runtime Dual Surface, Phase 3 Security Audit Surface, Autonomous Team Dispatch UI, Autonomous Roster Master Plan, Security Review Queue, Security Review Queue Snapshot, Security Review Gate Summary, Security Review Queue Export, LLM Audit Feed Redaction Snapshot, LLM Audit Export, MCP Audit Redaction Snapshot, MCP Audit Export, Gateway Correlation Snapshot, Gateway Correlation Risk Rollup, Gateway Correlation Timeline, Gateway Correlation Export, Active Gateway Policy Bundle, Auth Audit Snapshot, Auth Audit Risk Rollup, Auth Audit Timeline, Auth Audit Export, Phase 5 Active Runtime Evidence Bundle, Phase 5 Active Security Evidence Bundle, Phase 5 Active Runtime Guard Matrix Bundle, Phase 5 Active Gateway Execution Bundle, Phase 5 Active Memory Operations Bundle, Phase 5 Active Agent Operations Bundle, Phase 5 Active LLM Operations Bundle, Phase 5 Active MCP Operations Bundle, Phase 5 Active MCP Success Correlation Bundle, Phase 5 Vercel GitHub Deployment Status, Phase 5 Active Verifier Sweep Bundle Rebaseline, Phase 5 Active Full-Suite Rebaseline, Phase 5 Active Runtime Selector Truth Rebaseline`
environment: `production-candidate`
source_branch: `chore/repo-bootstrap`
image_build_branch: `codex/live-agent-steering-ui-20260513`
source_commit_sha: `2d6d8ac7b7b74e3d8a5493fe52aa05ae98094569`
source_commit_semantics: `Vercel production branch remains chore/repo-bootstrap; immutable GHCR images were built from codex/live-agent-steering-ui-20260513 at source_commit_sha for the validated staging runtime state including live-agent UI/runtime state, Phase 3 runtime surfaces, Phase 5 Active Gateway Execution Bundle manifest state, Phase 5 Active Memory Operations manifest state, Phase 5 Active Agent Operations manifest state, Phase 5 Active LLM Operations manifest state, Phase 5 Active MCP Operations manifest state, and Phase 5 Active MCP Success Correlation manifest state. Post-image release-candidate evidence on this branch additionally binds Phase 2 Runtime Dual Surface, Phase 5 Active Runtime Evidence Bundle, Phase 5 Active Runtime Guard Matrix Bundle, Phase 5 Active Gateway Execution Bundle, Phase 5 Active Memory Operations Bundle, Phase 5 Active Agent Operations Bundle, Phase 5 Active LLM Operations Bundle, Phase 5 Active MCP Operations Bundle, Phase 5 Active MCP Success Correlation Bundle, Phase 5 runtime-selector truth, immutable image-filesystem staging proof, the Phase 3 Security Audit Surface, Autonomous Team Dispatch UI, Security Review Queue, Security Review Queue Snapshot, Security Review Gate Summary, Security Review Queue Export, LLM Audit Feed Redaction Snapshot, LLM Audit Export, MCP Audit Redaction Snapshot, MCP Audit Export, Gateway Correlation Snapshot, Gateway Correlation Risk Rollup, Gateway Correlation Timeline, Gateway Correlation Export, Active Gateway Policy Bundle, Auth Audit Snapshot, Auth Audit Risk Rollup, Auth Audit Timeline, Auth Audit Export, Vercel GitHub Deployment Status, Active Verifier Sweep Bundle Rebaseline, Active Full-Suite Rebaseline, and Active Runtime Selector Truth Rebaseline evidence`
immutable_image_commit_sha: `2d6d8ac7b7b74e3d8a5493fe52aa05ae98094569`
workflow_run_url: `local-docker-buildx-2026-05-14-no-github-workflow-run-for-2d6d8ac7b7b74e3d8a5493fe52aa05ae98094569`
workflow_run_note: `No GitHub Actions workflow run is claimed for the current immutable selector 2d6d8ac7b7b74e3d8a5493fe52aa05ae98094569; current GHCR evidence is local Docker Buildx publication plus registry inspection. Historical CI references below are retained only as prior release-boundary evidence.`
pipeline_status: `local Docker Buildx with arm64 binfmt published all six GHCR images for 2d6d8ac7b7b74e3d8a5493fe52aa05ae98094569 after docker readiness and manifest validation passed; hosted immutable deploy plus hosted smoke/progress, Active MCP Success Correlation Bundle, Active MCP Operations Bundle, Active LLM Operations Bundle, Active Agent Operations Bundle, Active Memory Operations Bundle, Active Gateway Execution Bundle, Active Runtime Guard Matrix Bundle, Active Runtime Evidence Bundle, Active Security Evidence Bundle, Active Gateway Policy Bundle, Vercel GitHub Deployment Status, Autonomous Roster Master Plan, Phase 2 Runtime Dual Surface, Active Verifier Sweep Bundle Rebaseline, Active Full-Suite Rebaseline, and Active Runtime Selector Truth Rebaseline verifiers are bound to the same immutable staging selector`
smoke_result: `passed`
observability_check: `present`
rollback_note: `no production rollout performed; rollback remains the existing hosted staging rollback path`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:2d6d8ac7b7b74e3d8a5493fe52aa05ae98094569`
owner_decision: `approved`
hosted_selector_observed: `IMAGE_TAG=2d6d8ac7b7b74e3d8a5493fe52aa05ae98094569`
hosted_selector_observed_at: `2026-05-15T05:22:06+02:00`
frontend_runtime_image_observed: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/frontend:2d6d8ac7b7b74e3d8a5493fe52aa05ae98094569`
immutable_staging_parity_status: `verified`
active_candidate_gate_rerun_proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-candidate-gate-rerun.md`
active_runtime_evidence_bundle_proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-runtime-evidence-bundle-20260514.md`
active_gateway_policy_bundle_proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-gateway-policy-bundle-20260514.md`
active_runtime_guard_matrix_bundle_proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-runtime-guard-matrix-bundle-20260515.md`
active_gateway_execution_bundle_proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-gateway-execution-bundle-20260515.md`
active_memory_operations_bundle_proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-memory-operations-bundle-20260515.md`
active_agent_operations_bundle_proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-agent-operations-bundle-20260515.md`
active_llm_operations_bundle_proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-llm-operations-bundle-20260515.md`
active_mcp_operations_bundle_proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-mcp-operations-bundle-20260515.md`
active_mcp_success_correlation_bundle_proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-mcp-success-correlation-bundle-20260515.md`
active_verifier_sweep_bundle_proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-verifier-sweep-bundle-20260515.md`
active_full_suite_rebaseline_proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-full-suite-rebaseline-20260515.md`
active_security_evidence_bundle_proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-security-evidence-bundle-20260514.md`
vercel_github_deployment_status_proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-vercel-github-deployment-status-20260514.md`
autonomous_roster_master_plan_proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-autonomous-roster-master-plan-20260514.md`
phase2_runtime_dual_surface_proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-phase2-runtime-dual-surface-20260514.md`
runtime_selector_truth_proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-runtime-selector-truth.md`
immutable_staging_parity_proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-mcp-success-correlation-immutable-staging-20260515.md`

## Verification Evidence

- Python compile check: `py -3 -m compileall services\agent-api\app services\agent-worker\app services\llm-gateway\app`
- Frontend production build: `npm run build --prefix apps/frontend`
- Phase 3 Security Audit Surface local proof: `scripts\verify-phase3-security-audit-surface-hosted.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Autonomous Team Dispatch UI local proof: `scripts\verify-autonomous-coding-team.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Security Review Queue local proof: `scripts\verify-phase3-security-review-queue.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` including snapshot endpoint, filter state, risk badges, decision history, evidence snapshot, redaction, and mutation block checks
- Security Review Queue Export local proof: `scripts\verify-phase3-security-review-export.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` including export contract, allowlisted CSV headers, response headers, redaction evidence, persisted export-audit metadata, and mutation-block/no-live-provider/no-live-MCP-write checks
- LLM Audit Feed Redaction Snapshot local proof: `scripts\verify-phase3-llm-audit-feed.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` including snapshot endpoint, prompt-body omission, forbidden-pattern count, redaction evidence, and no-live-provider checks
- LLM Audit Export local proof: `scripts\verify-phase3-llm-audit-export.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireSeed` including export contract, allowlisted CSV, response headers, redaction evidence, persisted export-audit metadata, and no-live-provider checks
- MCP Audit Export local proof: `scripts\verify-phase3-mcp-audit-export.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireSeed` including export contract, allowlisted CSV, response headers, redaction evidence, persisted export-audit metadata, and no-live-MCP-write checks
- MCP Audit Redaction Snapshot local proof: `scripts\verify-phase3-mcp-deny-audit-correlation.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` including snapshot endpoint, input-ref omission, forbidden-pattern count, redaction evidence, deny correlation, and no-live-MCP-write checks
- Gateway Correlation Snapshot local proof: `scripts\verify-phase3-gateway-correlation-snapshot.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` including shared-trace agent task, LLM dry-run audit row, denied MCP audit row, full `agent_llm_mcp_correlated` group, `forbidden_pattern_hits=0`, `live_provider_call_count=0`, and `live_mcp_write_count=0`
- Gateway Correlation Risk Rollup local proof: `scripts\verify-phase3-gateway-correlation-risk-rollup.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireFullCorrelation` including `gateway-correlation-risk-rollup-v1`, `read_only=true`, `promotion_allowed=false`, `production_rollout_claimed=false`, redaction/no-live-write evidence, parity with snapshot counts, risk badges, and zero blocker count
- Gateway Correlation Timeline local proof: `scripts\verify-phase3-gateway-correlation-timeline.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireFullCorrelation` including `gateway-correlation-timeline-v1`, ordered Agent/LLM/MCP timeline legs, `read_only=true`, `promotion_allowed=false`, `production_rollout_claimed=false`, redaction/no-live-write evidence, parity with snapshot/rollup counts, and zero forbidden hits
- Gateway Correlation Export local proof: `scripts\verify-phase3-gateway-correlation-export.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireFullCorrelation` including `gateway-correlation-export-v1`, allowlisted CSV headers, response headers, redaction evidence, persisted export-audit metadata, and no-live-provider/no-live-MCP-write checks
- Auth Audit Snapshot local proof: `scripts\verify-phase3-auth-audit-snapshot.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireLifecycle` including `auth-audit-snapshot-v1`, `auth_audit_snapshot_visible`, `auth_audit_redaction_enforced`, `auth_no_live_oauth_guard`, safe event field allowlist, no raw details, no token/cookie/header/code/state/blacklist-key return, and zero forbidden hits
- Browser contract local proof: `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Security proof: `scripts\verify-security.ps1` and `scripts\verify-evidence-artifact-safety.ps1`
- GHCR arm64 image build/push: `scripts\build-and-push.ps1 -Tag 2d6d8ac7b7b74e3d8a5493fe52aa05ae98094569 -Builder superbrain_builder`; `docker buildx imagetools inspect` confirmed all six service tags for `linux/arm64`
- Immutable staging deploy: `scripts\deploy-to-staging.ps1 -UseImageFilesystem -ImageTag 2d6d8ac7b7b74e3d8a5493fe52aa05ae98094569 -KeyPath <local-private-key>`
- Phase 3 Security Audit Surface hosted proof: `scripts\verify-phase3-security-audit-surface-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Autonomous Team Dispatch UI hosted proof: `scripts\verify-autonomous-coding-team.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Security Review Queue hosted proof: `scripts\verify-phase3-security-review-queue.ps1 -BaseUrl https://188-34-191-140.sslip.io` including snapshot endpoint, filter state, risk badges, decision history, evidence snapshot, redaction, and mutation block checks
- Security Review Gate hosted proof: `scripts\verify-phase3-security-review-gate.ps1 -BaseUrl https://188-34-191-140.sslip.io` including blocked advisory gate, blocker count, production_rollout_claimed=false, promotion_allowed=false, redaction, and mutation block checks
- Security Review Queue Export hosted proof: `scripts\verify-phase3-security-review-export.ps1 -BaseUrl https://188-34-191-140.sslip.io` including `security_review_queue_export_visible`, `security_review_queue_export_audit_persisted`, `security_review_redaction_enforced`, `security_review_mutation_blocked`, allowlisted CSV headers, response headers, and persisted export-audit metadata
- LLM Audit Feed Redaction Snapshot hosted proof: `scripts\verify-phase3-llm-audit-feed.ps1 -BaseUrl https://188-34-191-140.sslip.io` including `llm_audit_snapshot_visible`, `llm_audit_redaction_enforced`, `prompt_bodies_returned=false`, `provider_credentials_returned=false`, and `forbidden_pattern_hits=0`
- LLM Audit Export hosted proof: `scripts\verify-phase3-llm-audit-export.ps1 -BaseUrl https://188-34-191-140.sslip.io` including `llm_audit_export_visible`, `llm_audit_export_audit_persisted`, `llm_audit_no_live_provider_guard`, allowlisted CSV headers, redaction evidence, and no-live-provider checks
- MCP Audit Export hosted proof: `scripts\verify-phase3-mcp-audit-export.ps1 -BaseUrl https://188-34-191-140.sslip.io` including `mcp_audit_export_visible`, `mcp_audit_export_audit_persisted`, `mcp_audit_no_live_write_guard`, allowlisted CSV headers, redaction evidence, and no-live-MCP-write checks
- MCP Audit Redaction Snapshot hosted proof: `scripts\verify-phase3-mcp-deny-audit-correlation.ps1 -BaseUrl https://188-34-191-140.sslip.io` including `mcp_audit_snapshot_visible`, `mcp_audit_redaction_enforced`, `input_refs_returned=false`, `live_mcp_writes_claimed=false`, and `forbidden_pattern_hits=0`
- Gateway Correlation Snapshot hosted proof: `scripts\verify-phase3-gateway-correlation-snapshot.ps1 -BaseUrl https://188-34-191-140.sslip.io` including `gateway_correlation_snapshot_visible`, `gateway_correlation_redaction_enforced`, `gateway_correlation_no_live_write_guard`, `agent_llm_mcp_correlated`, `live_provider_call_count=0`, `live_mcp_write_count=0`, and `forbidden_pattern_hits=0`
- Gateway Correlation Risk Rollup hosted proof: `scripts\verify-phase3-gateway-correlation-risk-rollup.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireFullCorrelation` including `gateway_correlation_risk_rollup_visible`, `read_only=true`, `promotion_allowed=false`, `production_rollout_claimed=false`, `live_provider_calls_claimed=false`, `live_mcp_writes_claimed=false`, and `blocker_count=0`
- Gateway Correlation Timeline hosted proof: `scripts\verify-phase3-gateway-correlation-timeline.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireFullCorrelation` including `gateway_correlation_timeline_visible`, ordered Agent/LLM/MCP timeline legs, `read_only=true`, `promotion_allowed=false`, `production_rollout_claimed=false`, `live_provider_calls_claimed=false`, `live_mcp_writes_claimed=false`, and `forbidden_pattern_hits=0`
- Gateway Correlation Export hosted proof: `scripts\verify-phase3-gateway-correlation-export.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireFullCorrelation` including `gateway_correlation_export_visible`, `gateway_correlation_export_audit_persisted`, `gateway_correlation_redaction_enforced`, `gateway_correlation_no_live_write_guard`, allowlisted CSV headers, response headers, and persisted export-audit metadata
- Auth Lifecycle hosted proof: `scripts\verify-phase3-auth-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Auth Audit Snapshot hosted proof: `scripts\verify-phase3-auth-audit-snapshot.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireLifecycle` including `auth_audit_snapshot_visible`, `auth_audit_redaction_enforced`, `auth_no_live_oauth_guard`, `live_github_oauth_call_count=0`, and `forbidden_pattern_hits=0`
- Full Phase 3 hosted suite: `scripts\verify.ps1 -Suite phase3 -BaseUrl https://188-34-191-140.sslip.io -FailFast`
- Browser contract hosted proof: `scripts\verify-browser-contract.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Hosted staging smoke: `scripts\verify-hosted-staging-smoke.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Security suite: `scripts\verify.ps1 -Suite security`
- Hosted staging smoke: `scripts\verify.ps1 -Suite hosted-staging-smoke -BaseUrl https://188-34-191-140.sslip.io`
- Hosted staging safe profile: `scripts\verify.ps1 -Suite hosted-staging -BaseUrl https://188-34-191-140.sslip.io -SafeProfile`
- Release boundary suite: `scripts\verify.ps1 -Suite release-boundary -ReportOnly`
- Historical main deploy workflow for the previous immutable staging image commit: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25833000061` (retained as prior evidence only; it is not claimed as the workflow for `2d6d8ac7b7b74e3d8a5493fe52aa05ae98094569`)
- Historical frontend immutable manifest retag proof for the previous selector: `docker buildx imagetools create -t ghcr.io/strazzusochr/cloud-superbrain-developer-platform/frontend:031c95c3e5af1101caf282eee463256285803495 ghcr.io/strazzusochr/cloud-superbrain-developer-platform/frontend:97c7ea04b5180862ea9862cc18b9c5bac994f794`
- Main deploy workflow for release-boundary source head: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25765691998`
- Main deploy workflow for metadata/verifier wrapper head: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25782828285`
- Hosted staging proof workflow: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25738288780`
- Production tag gate ordering: `production-gate` depends on `verify`, uses environment `production`, and `build-and-push` waits for `production-gate` before publishing production tags.
- Immutable staging plan: `scripts\deploy-to-staging.ps1 -PlanOnly -UseImageFilesystem -ImageTag 2d6d8ac7b7b74e3d8a5493fe52aa05ae98094569`
- Immutable staging parity ready check: `scripts\manual\verify-phase5-staging-immutable-parity.ps1 -ReleaseId prod-candidate-2026-05-11-rc1 -CandidateSha 2d6d8ac7b7b74e3d8a5493fe52aa05ae98094569`
- Immutable staging parity remote proof: `scripts\manual\verify-phase5-staging-immutable-parity.ps1 -RequireVerified -ReleaseId prod-candidate-2026-05-11-rc1 -CandidateSha 2d6d8ac7b7b74e3d8a5493fe52aa05ae98094569 -BaseUrl https://188-34-191-140.sslip.io -KeyPath <local-private-key>`
- Active candidate gate rerun proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-candidate-gate-rerun.md`
- Active Runtime Evidence Bundle proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-runtime-evidence-bundle-20260514.md`
- Active Runtime Evidence Bundle local and hosted proof: `scripts\verify-phase5-active-runtime-evidence-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` and `scripts\verify-phase5-active-runtime-evidence-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Active Gateway Policy Bundle proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-gateway-policy-bundle-20260514.md`
- Active Gateway Policy Bundle local and hosted proof: `scripts\verify-phase3-active-gateway-policy-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` and `scripts\verify-phase3-active-gateway-policy-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Active Runtime Guard Matrix Bundle proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-runtime-guard-matrix-bundle-20260515.md`
- Active Runtime Guard Matrix Bundle local and hosted proof: `scripts\verify-phase5-active-runtime-guard-matrix-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` and `scripts\verify-phase5-active-runtime-guard-matrix-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Active Gateway Execution Bundle proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-gateway-execution-bundle-20260515.md`
- Active Gateway Execution Bundle local and hosted proof: `scripts\verify-phase5-active-gateway-execution-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` and `scripts\verify-phase5-active-gateway-execution-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Active Memory Operations Bundle proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-memory-operations-bundle-20260515.md`
- Active Memory Operations Bundle local and hosted proof: `scripts\verify-phase5-active-memory-operations-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` and `scripts\verify-phase5-active-memory-operations-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io -KeyPath <local-private-key>`
- Active Agent Operations Bundle proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-agent-operations-bundle-20260515.md`
- Active Agent Operations Bundle local and hosted proof: `scripts\verify-phase5-active-agent-operations-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` and `scripts\verify-phase5-active-agent-operations-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Active LLM Operations Bundle proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-llm-operations-bundle-20260515.md`
- Active LLM Operations Bundle local and hosted proof: `scripts\verify-phase5-active-llm-operations-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` and `scripts\verify-phase5-active-llm-operations-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Active MCP Operations Bundle proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-mcp-operations-bundle-20260515.md`
- Active MCP Operations Bundle local and hosted proof: `scripts\verify-phase5-active-mcp-operations-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` and `scripts\verify-phase5-active-mcp-operations-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Active MCP Success Correlation Bundle proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-mcp-success-correlation-bundle-20260515.md`
- Active MCP Success Correlation Bundle local and hosted proof: `scripts\verify-phase5-active-mcp-success-correlation-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` and `scripts\verify-phase5-active-mcp-success-correlation-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Active Verifier Sweep Bundle proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-verifier-sweep-bundle-20260515.md`
- Active Verifier Sweep Bundle hosted proof: `scripts\verify-phase5-active-verifier-sweep-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Active Full-Suite Rebaseline proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-full-suite-rebaseline-20260515.md`
- Active Full-Suite Rebaseline hosted proof: `scripts\verify-phase5-full-verifier-sweep.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Active Runtime Selector Truth Rebaseline proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-runtime-selector-truth.md`
- Active Runtime Selector Truth Rebaseline remote proof: `scripts\verify-current-runtime-selector-truth.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireRemoteProof -KeyPath <local-private-key>`
- Active Security Evidence Bundle proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-security-evidence-bundle-20260514.md`
- Active Security Evidence Bundle hosted proof: `scripts\verify-phase5-active-security-evidence-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Vercel GitHub Deployment Status proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-vercel-github-deployment-status-20260514.md`
- Vercel GitHub Deployment Status hosted proof: `scripts\verify-phase5-vercel-github-deployment-status.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Autonomous Roster Master Plan proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-autonomous-roster-master-plan-20260514.md`
- Autonomous Roster Master Plan local and hosted proof: `scripts\verify-autonomous-roster-master-plan-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` and `scripts\verify-autonomous-roster-master-plan-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Phase 2 Runtime Dual Surface proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-phase2-runtime-dual-surface-20260514.md`
- Phase 2 Runtime Dual Surface local and hosted proof: `scripts\verify-phase2-runtime-dual-surface.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` and `scripts\verify-phase2-runtime-dual-surface.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Runtime selector truth proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-runtime-selector-truth.md`

## Cloud Surfaces

- Vercel frontend: `https://frontend-seven-psi-78.vercel.app/`
- Hetzner hosted platform: `https://188-34-191-140.sslip.io/`
- Agent API health: `https://188-34-191-140.sslip.io/api/v1/health`
- LLM gateway health: `https://188-34-191-140.sslip.io/llm/api/v1/health`

## LLM Audit Feed Redaction Snapshot Evidence

- Contract: `llm-audit-feed-v1`
- Endpoint: `GET /api/v1/audit/llm`
- Snapshot endpoint: `GET /api/v1/audit/llm/snapshot`
- Evidence refs: `llm_audit_feed_visible`, `llm_audit_feed_event_visible`, `llm_audit_snapshot_visible`, `llm_audit_redaction_enforced`
- Snapshot guards: `prompt_bodies_returned=false`, `provider_credentials_returned=false`, `forbidden_pattern_hits=0`, `live_provider_calls_claimed=false`
- Feed guards: `prompt_body_stored=false`, `redaction_evidence_ref=llm_audit_redaction_enforced`, `live_provider_calls=false`, `cost_cents=0` for deterministic dry-run proof rows
- Non-claims: no production rollout, no secret disclosure, no provider billing proof, no SOC/SIEM completeness claim, no live provider or live MCP writes.

## LLM Audit Export Evidence

- Contract: `llm-audit-export-v1`
- Endpoint: `GET /api/v1/audit/llm/export`
- Contract endpoint: `GET /api/v1/audit/llm/export/contract`
- Evidence refs: `llm_audit_export_visible`, `llm_audit_export_audit_persisted`, `llm_audit_redaction_enforced`, `llm_audit_no_live_provider_guard`
- CSV guards: allowlisted columns only; no prompt body, provider credential, cookie, authorization header, token, raw detail, production rollout, release promotion, or live provider claim is returned.
- Audit guards: export access persists redacted `llm_audit_export_generated` metadata only and keeps `prompt_body_stored=false`.
- Non-claims: no production rollout, no secret disclosure, no provider billing proof, no SOC/SIEM completeness claim, no live provider or live MCP writes.

## MCP Audit Export Evidence

- Contract: `mcp-audit-export-v1`
- Endpoint: `GET /api/v1/audit/mcp/export`
- Contract endpoint: `GET /api/v1/audit/mcp/export/contract`
- Evidence refs: `mcp_audit_export_visible`, `mcp_audit_export_audit_persisted`, `mcp_audit_redaction_enforced`, `mcp_audit_no_live_write_guard`
- CSV guards: allowlisted columns only; no tool input refs, prompt body, provider credential, cookie, authorization header, token, raw detail, production rollout, release promotion, or live MCP write claim is returned.
- Audit guards: export access persists redacted `mcp_audit_export_generated` metadata only and keeps `input_ref_stored=false`.
- Non-claims: no production rollout, no secret disclosure, no provider billing proof, no SOC/SIEM completeness claim, no live provider or live MCP writes.

## MCP Audit Redaction Snapshot Evidence

- Contract: `mcp-audit-feed-v1`
- Endpoint: `GET /api/v1/audit/mcp`
- Snapshot endpoint: `GET /api/v1/audit/mcp/snapshot`
- Evidence refs: `mcp_audit_feed_contract_runtime_visible`, `mcp_tool_session_bound_audit`, `mcp_audit_snapshot_visible`, `mcp_audit_redaction_enforced`
- Snapshot guards: `input_refs_returned=false`, `provider_credentials_returned=false`, `forbidden_pattern_hits=0`, `live_mcp_writes_claimed=false`
- Feed guards: `input_ref_stored=false`, `redaction_evidence_ref=mcp_audit_redaction_enforced`, `denied_tool_correlation_evidence_ref=mcp_denied_tool_audit_correlation` for blocked proof rows
- Non-claims: no production rollout, no secret disclosure, no provider billing proof, no SOC/SIEM completeness claim, no live provider or live MCP writes.

## Gateway Correlation Snapshot Evidence

- Contract: `gateway-correlation-snapshot-v1`
- Endpoint: `GET /api/v1/security/gateway-correlation/snapshot`
- Contract endpoint: `GET /api/v1/security/gateway-correlation/contract`
- Evidence refs: `gateway_correlation_snapshot_visible`, `gateway_correlation_redaction_enforced`, `gateway_correlation_no_live_write_guard`
- Source rows: `task_completed`, `autonomous_team_dispatch`, `langgraph_dry_run_completed`, `langgraph_dry_run_stopped`, `llm_gateway_request`, and `mcp_tool_executed`
- Snapshot guards: `prompt_bodies_returned=false`, `tool_input_refs_returned=false`, `provider_credentials_returned=false`, `forbidden_pattern_hits=0`, `live_provider_calls_claimed=false`, and `live_mcp_writes_claimed=false`
- Proof shape: one deterministic agent task, one LLM Gateway dry-run event, and one denied MCP event share a trace id and produce an `agent_llm_mcp_correlated` group.
- Non-claims: no production rollout, no live provider call, no live MCP write, no external SOC/SIEM completeness claim, no provider billing proof, and no raw prompt/tool input exposure.

## Gateway Correlation Timeline Evidence

- Contract: `gateway-correlation-timeline-v1`
- Endpoint: `GET /api/v1/security/gateway-correlation/timeline`
- Parent endpoints: `GET /api/v1/security/gateway-correlation/contract`, `GET /api/v1/security/gateway-correlation/snapshot`, and `GET /api/v1/security/gateway-correlation/risk-rollup`
- Evidence refs: `gateway_correlation_timeline_visible`, `gateway_correlation_snapshot_visible`, `gateway_correlation_redaction_enforced`, `gateway_correlation_no_live_write_guard`
- Timeline guards: `read_only=true`, `prompt_bodies_returned=false`, `tool_input_refs_returned=false`, `provider_credentials_returned=false`, `forbidden_pattern_hits=0`, `live_provider_calls_claimed=false`, `live_mcp_writes_claimed=false`, `production_rollout_claimed=false`, and `promotion_allowed=false`
- Proof shape: ordered timeline entries expose sequence index, event type, timeline leg, correlation key, trace/request/session ids, status, severity, and evidence refs only; no raw audit details are returned.
- Non-claims: no production rollout, no live provider call, no live MCP write, no external SOC/SIEM completeness claim, no provider billing proof, and no raw prompt/tool input exposure.

## Security Review Gate Summary Evidence

- Contract: `security-review-queue-v1`
- Endpoint: `GET /api/v1/security/review-queue`
- Snapshot endpoint: `GET /api/v1/security/review-queue/snapshot`
- Gate endpoint: `GET /api/v1/security/review-queue/gate`
- Evidence refs: `security_review_queue_visible`, `security_review_item_visible`, `security_review_filter_state_visible`, `security_review_decision_history_visible`, `security_review_evidence_snapshot_visible`, `security_review_gate_summary_visible`, `security_review_redaction_enforced`, `security_review_mutation_blocked`
- Risk badges: `release_blocker_review`, `review_required`, `runtime_monitor`, and `monitor` are derived from queue status/severity/category without leaking raw payload details.
- Decision history: queue entries expose deterministic review history references and evidence snapshots while keeping the surface read-only.
- Gate summary: open `needs_review` items produce `blocked_by_open_security_reviews`; `production_rollout_claimed=false` and `promotion_allowed=false` are always explicit.
- Mutation policy: `POST/PUT/PATCH/DELETE /api/v1/security/review-queue` return HTTP `403`; queue is read-only and redacted.
- Non-claims: no production rollout, no secret disclosure, no SOC/SIEM completeness claim, no live provider or live MCP writes.

## Guardrails

- This artifact approves the current clean repository boundary as a production candidate.
- The current release boundary source commit is `2d6d8ac7b7b74e3d8a5493fe52aa05ae98094569`; the immutable image commit deployed to staging is `2d6d8ac7b7b74e3d8a5493fe52aa05ae98094569`.
- This artifact does not claim a production rollout.
- Remote immutable Hetzner parity for `2d6d8ac7b7b74e3d8a5493fe52aa05ae98094569` is current staging evidence only; production is still not rolled out.
- This artifact does not replace the historical `prod-candidate-2026-05-05-rc1` no-release evidence.
- The hosted selector line records the current Hetzner staging selector observed after later deployment work; it does not rewrite the historical 2026-05-05 rollback selector.
- Production deployment still requires the release-candidate gate bundle and a separate rollout proof.
