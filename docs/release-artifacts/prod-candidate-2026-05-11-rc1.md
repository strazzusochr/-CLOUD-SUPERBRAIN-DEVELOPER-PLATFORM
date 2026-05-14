# Release Artifact

release_id: `prod-candidate-2026-05-11-rc1`
scope: `release-boundary cleanup, HF router truth, frontend build, agent-api/runtime compile checks, hosted staging smoke checks, immutable staging image candidate, Phase 3 Security Audit Surface, Autonomous Team Dispatch UI, Security Review Queue, Security Review Queue Snapshot, Security Review Gate Summary, LLM Audit Feed Redaction Snapshot, LLM Audit Export, MCP Audit Redaction Snapshot, MCP Audit Export, Gateway Correlation Snapshot, Gateway Correlation Risk Rollup, Gateway Correlation Timeline, Auth Audit Snapshot, Auth Audit Risk Rollup, Auth Audit Timeline, Auth Audit Export`
environment: `production-candidate`
source_branch: `chore/repo-bootstrap`
image_build_branch: `codex/live-agent-steering-ui-20260513`
source_commit_sha: `21145b89634b330231b6fd66c8aa2654c55a047e`
source_commit_semantics: `Vercel production branch remains chore/repo-bootstrap; immutable GHCR images were built from codex/live-agent-steering-ui-20260513 at the current validated runtime head including live-agent UI/runtime state, Phase 5 runtime-selector truth, immutable image-filesystem staging proof, the Phase 3 Security Audit Surface, Autonomous Team Dispatch UI, Security Review Queue, Security Review Queue Snapshot, Security Review Gate Summary, LLM Audit Feed Redaction Snapshot, LLM Audit Export, MCP Audit Redaction Snapshot, MCP Audit Export, Gateway Correlation Snapshot, Gateway Correlation Risk Rollup, Gateway Correlation Timeline, Auth Audit Snapshot, Auth Audit Risk Rollup, Auth Audit Timeline, and Auth Audit Export`
immutable_image_commit_sha: `21145b89634b330231b6fd66c8aa2654c55a047e`
workflow_run_url: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25833000061`
pipeline_status: `local Docker Buildx with arm64 binfmt built and pushed all six GHCR images for 21145b89634b330231b6fd66c8aa2654c55a047e after py_compile, Next.js build, local MCP-audit export/snapshot verifiers, local browser-contract, security verifier, and evidence artifact safety verifier passed; hosted immutable deploy plus hosted MCP-audit export, hosted MCP-audit snapshot, full Phase-3 suite, browser, and hosted-staging verifiers passed after push`
smoke_result: `passed`
observability_check: `present`
rollback_note: `no production rollout performed; rollback remains the existing hosted staging rollback path`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:21145b89634b330231b6fd66c8aa2654c55a047e`
owner_decision: `approved`
hosted_selector_observed: `IMAGE_TAG=21145b89634b330231b6fd66c8aa2654c55a047e`
hosted_selector_observed_at: `2026-05-14T18:10:00+02:00`
frontend_runtime_image_observed: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/frontend:21145b89634b330231b6fd66c8aa2654c55a047e`
immutable_staging_parity_status: `verified`
active_candidate_gate_rerun_proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-candidate-gate-rerun.md`
runtime_selector_truth_proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-runtime-selector-truth.md`
immutable_staging_parity_proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-mcp-audit-export-immutable-staging-20260514.md`

## Verification Evidence

- Python compile check: `py -3 -m compileall services\agent-api\app services\agent-worker\app services\llm-gateway\app`
- Frontend production build: `npm run build --prefix apps/frontend`
- Phase 3 Security Audit Surface local proof: `scripts\verify-phase3-security-audit-surface-hosted.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Autonomous Team Dispatch UI local proof: `scripts\verify-autonomous-coding-team.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Security Review Queue local proof: `scripts\verify-phase3-security-review-queue.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` including snapshot endpoint, filter state, risk badges, decision history, evidence snapshot, redaction, and mutation block checks
- LLM Audit Feed Redaction Snapshot local proof: `scripts\verify-phase3-llm-audit-feed.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` including snapshot endpoint, prompt-body omission, forbidden-pattern count, redaction evidence, and no-live-provider checks
- LLM Audit Export local proof: `scripts\verify-phase3-llm-audit-export.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireSeed` including export contract, allowlisted CSV, response headers, redaction evidence, persisted export-audit metadata, and no-live-provider checks
- MCP Audit Export local proof: `scripts\verify-phase3-mcp-audit-export.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireSeed` including export contract, allowlisted CSV, response headers, redaction evidence, persisted export-audit metadata, and no-live-MCP-write checks
- MCP Audit Redaction Snapshot local proof: `scripts\verify-phase3-mcp-deny-audit-correlation.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` including snapshot endpoint, input-ref omission, forbidden-pattern count, redaction evidence, deny correlation, and no-live-MCP-write checks
- Gateway Correlation Snapshot local proof: `scripts\verify-phase3-gateway-correlation-snapshot.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` including shared-trace agent task, LLM dry-run audit row, denied MCP audit row, full `agent_llm_mcp_correlated` group, `forbidden_pattern_hits=0`, `live_provider_call_count=0`, and `live_mcp_write_count=0`
- Gateway Correlation Risk Rollup local proof: `scripts\verify-phase3-gateway-correlation-risk-rollup.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireFullCorrelation` including `gateway-correlation-risk-rollup-v1`, `read_only=true`, `promotion_allowed=false`, `production_rollout_claimed=false`, redaction/no-live-write evidence, parity with snapshot counts, risk badges, and zero blocker count
- Gateway Correlation Timeline local proof: `scripts\verify-phase3-gateway-correlation-timeline.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireFullCorrelation` including `gateway-correlation-timeline-v1`, ordered Agent/LLM/MCP timeline legs, `read_only=true`, `promotion_allowed=false`, `production_rollout_claimed=false`, redaction/no-live-write evidence, parity with snapshot/rollup counts, and zero forbidden hits
- Auth Audit Snapshot local proof: `scripts\verify-phase3-auth-audit-snapshot.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireLifecycle` including `auth-audit-snapshot-v1`, `auth_audit_snapshot_visible`, `auth_audit_redaction_enforced`, `auth_no_live_oauth_guard`, safe event field allowlist, no raw details, no token/cookie/header/code/state/blacklist-key return, and zero forbidden hits
- Browser contract local proof: `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Security proof: `scripts\verify-security.ps1` and `scripts\verify-evidence-artifact-safety.ps1`
- GHCR arm64 image build/push: `scripts\build-and-push.ps1 -Tag 21145b89634b330231b6fd66c8aa2654c55a047e -Platforms linux/arm64 -Builder codex-multiarch`
- Immutable staging deploy: `scripts\deploy-to-staging.ps1 -UseImageFilesystem -ImageTag 21145b89634b330231b6fd66c8aa2654c55a047e -KeyPath <local-private-key>`
- Phase 3 Security Audit Surface hosted proof: `scripts\verify-phase3-security-audit-surface-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Autonomous Team Dispatch UI hosted proof: `scripts\verify-autonomous-coding-team.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Security Review Queue hosted proof: `scripts\verify-phase3-security-review-queue.ps1 -BaseUrl https://188-34-191-140.sslip.io` including snapshot endpoint, filter state, risk badges, decision history, evidence snapshot, redaction, and mutation block checks
- Security Review Gate hosted proof: `scripts\verify-phase3-security-review-gate.ps1 -BaseUrl https://188-34-191-140.sslip.io` including blocked advisory gate, blocker count, production_rollout_claimed=false, promotion_allowed=false, redaction, and mutation block checks
- LLM Audit Feed Redaction Snapshot hosted proof: `scripts\verify-phase3-llm-audit-feed.ps1 -BaseUrl https://188-34-191-140.sslip.io` including `llm_audit_snapshot_visible`, `llm_audit_redaction_enforced`, `prompt_bodies_returned=false`, `provider_credentials_returned=false`, and `forbidden_pattern_hits=0`
- LLM Audit Export hosted proof: `scripts\verify-phase3-llm-audit-export.ps1 -BaseUrl https://188-34-191-140.sslip.io` including `llm_audit_export_visible`, `llm_audit_export_audit_persisted`, `llm_audit_no_live_provider_guard`, allowlisted CSV headers, redaction evidence, and no-live-provider checks
- MCP Audit Export hosted proof: `scripts\verify-phase3-mcp-audit-export.ps1 -BaseUrl https://188-34-191-140.sslip.io` including `mcp_audit_export_visible`, `mcp_audit_export_audit_persisted`, `mcp_audit_no_live_write_guard`, allowlisted CSV headers, redaction evidence, and no-live-MCP-write checks
- MCP Audit Redaction Snapshot hosted proof: `scripts\verify-phase3-mcp-deny-audit-correlation.ps1 -BaseUrl https://188-34-191-140.sslip.io` including `mcp_audit_snapshot_visible`, `mcp_audit_redaction_enforced`, `input_refs_returned=false`, `live_mcp_writes_claimed=false`, and `forbidden_pattern_hits=0`
- Gateway Correlation Snapshot hosted proof: `scripts\verify-phase3-gateway-correlation-snapshot.ps1 -BaseUrl https://188-34-191-140.sslip.io` including `gateway_correlation_snapshot_visible`, `gateway_correlation_redaction_enforced`, `gateway_correlation_no_live_write_guard`, `agent_llm_mcp_correlated`, `live_provider_call_count=0`, `live_mcp_write_count=0`, and `forbidden_pattern_hits=0`
- Gateway Correlation Risk Rollup hosted proof: `scripts\verify-phase3-gateway-correlation-risk-rollup.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireFullCorrelation` including `gateway_correlation_risk_rollup_visible`, `read_only=true`, `promotion_allowed=false`, `production_rollout_claimed=false`, `live_provider_calls_claimed=false`, `live_mcp_writes_claimed=false`, and `blocker_count=0`
- Gateway Correlation Timeline hosted proof: `scripts\verify-phase3-gateway-correlation-timeline.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireFullCorrelation` including `gateway_correlation_timeline_visible`, ordered Agent/LLM/MCP timeline legs, `read_only=true`, `promotion_allowed=false`, `production_rollout_claimed=false`, `live_provider_calls_claimed=false`, `live_mcp_writes_claimed=false`, and `forbidden_pattern_hits=0`
- Auth Lifecycle hosted proof: `scripts\verify-phase3-auth-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Auth Audit Snapshot hosted proof: `scripts\verify-phase3-auth-audit-snapshot.ps1 -BaseUrl https://188-34-191-140.sslip.io -RequireLifecycle` including `auth_audit_snapshot_visible`, `auth_audit_redaction_enforced`, `auth_no_live_oauth_guard`, `live_github_oauth_call_count=0`, and `forbidden_pattern_hits=0`
- Full Phase 3 hosted suite: `scripts\verify.ps1 -Suite phase3 -BaseUrl https://188-34-191-140.sslip.io -FailFast`
- Browser contract hosted proof: `scripts\verify-browser-contract.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Hosted staging smoke: `scripts\verify-hosted-staging-smoke.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Security suite: `scripts\verify.ps1 -Suite security`
- Hosted staging smoke: `scripts\verify.ps1 -Suite hosted-staging-smoke -BaseUrl https://188-34-191-140.sslip.io`
- Hosted staging safe profile: `scripts\verify.ps1 -Suite hosted-staging -BaseUrl https://188-34-191-140.sslip.io -SafeProfile`
- Release boundary suite: `scripts\verify.ps1 -Suite release-boundary -ReportOnly`
- Main deploy workflow for immutable staging image commit: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25833000061` (verify plus five service builds succeeded; frontend job was force-cancelled after OCI manifest retag proof)
- Frontend immutable manifest retag proof: `docker buildx imagetools create -t ghcr.io/strazzusochr/cloud-superbrain-developer-platform/frontend:031c95c3e5af1101caf282eee463256285803495 ghcr.io/strazzusochr/cloud-superbrain-developer-platform/frontend:97c7ea04b5180862ea9862cc18b9c5bac994f794`
- Main deploy workflow for release-boundary source head: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25765691998`
- Main deploy workflow for metadata/verifier wrapper head: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25782828285`
- Hosted staging proof workflow: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25738288780`
- Production tag gate ordering: `production-gate` depends on `verify`, uses environment `production`, and `build-and-push` waits for `production-gate` before publishing production tags.
- Immutable staging plan: `scripts\deploy-to-staging.ps1 -PlanOnly -UseImageFilesystem -ImageTag 10df3ea48627e6f11787587e3c984b72107e78f5`
- Immutable staging parity ready check: `scripts\manual\verify-phase5-staging-immutable-parity.ps1 -ReleaseId prod-candidate-2026-05-11-rc1 -CandidateSha 10df3ea48627e6f11787587e3c984b72107e78f5`
- Immutable staging parity remote proof: `scripts\manual\verify-phase5-staging-immutable-parity.ps1 -RequireVerified -ReleaseId prod-candidate-2026-05-11-rc1 -CandidateSha 10df3ea48627e6f11787587e3c984b72107e78f5 -BaseUrl https://188-34-191-140.sslip.io -KeyPath <local-private-key>`
- Active candidate gate rerun proof: `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-candidate-gate-rerun.md`
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
- The release boundary source commit is `21145b89634b330231b6fd66c8aa2654c55a047e`; the immutable image commit deployed to staging is `21145b89634b330231b6fd66c8aa2654c55a047e`.
- This artifact does not claim a production rollout.
- Remote immutable Hetzner parity for `21145b89634b330231b6fd66c8aa2654c55a047e` is current staging evidence only; production is still not rolled out.
- This artifact does not replace the historical `prod-candidate-2026-05-05-rc1` no-release evidence.
- The hosted selector line records the current Hetzner staging selector observed after later deployment work; it does not rewrite the historical 2026-05-05 rollback selector.
- Production deployment still requires the release-candidate gate bundle and a separate rollout proof.
