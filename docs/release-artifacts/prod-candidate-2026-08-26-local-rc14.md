# Release Artifact

release_id: `prod-candidate-2026-08-26-local-rc14`
scope: `Responses SSE, fixed filesystem project-progress adapter, dependency and market-ready hardening, organism boot-flash repair, and fail-closed MCP audit transport stabilization`
environment: `production-candidate`
source_branch: `codex/organism-visual-v2`
source_commit_sha: `d0674bfc1367b04d95ca2bf745e89fabf12046ad`
source_commit_semantics: `frozen post-RC13 source with functional L4 and L5 slices, external-gate-aware market readiness, current dependency closures, the alternate-cortex boot-flash repair, and bounded fail-closed MCP audit transport`
immutable_image_commit_sha: `d0674bfc1367b04d95ca2bf745e89fabf12046ad`
workflow_run_url: `pending-source-checkout-attestation`
pipeline_status: `pending: all five local chains passed, but pr-check must still run with candidate_sha=d0674bfc1367b04d95ca2bf745e89fabf12046ad and source_prequalification=true so the source-checkout attestation binds this candidate`
smoke_result: `passed DEV-ONLY; six committed-archive service images, candidate runtime, full runtime, full browser with real Cloudflare Workers AI generation, 22 routes, 161 page-local actions, O4 write proof, and candidate-scoped security checks are green; hosted proof still blocked`
observability_check: `present in candidate-bound DEV-ONLY runtime and browser evidence`
rollback_note: `local rollback target is RC13 source db631ab3ffe2254309ae80aadc691b0bba6c372d; no hosted rollback is authorized or executed`
rollback_target_commit_sha: `db631ab3ffe2254309ae80aadc691b0bba6c372d`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:d0674bfc1367b04d95ca2bf745e89fabf12046ad`
immutable_tag_publish_status: `unpublished`
rollback_drill_proof: `docs/runbooks/rollback-deploy.md`
executed_rollback_rerun_proof: `pending-local-qualification`
owner_decision_proof: `docs/runtime-state/owner-input-manifest.json`
budget_review_proof: `pending-local-qualification`
open_questions_acceptance_proof: `pending-local-qualification`
risk_review_recheck_proof: `pending-local-qualification`
provenance_review_proof: `pending-local-qualification`
smoke_recheck_proof: `pending-local-qualification`
observability_recheck_proof: `pending-local-qualification`
browser_evidence_reactivation_proof: `docs/release-artifacts/prod-candidate-2026-08-26-local-rc14-evidence/browser.json`
browser_proof: `docs/release-artifacts/prod-candidate-2026-08-26-local-rc14-evidence/browser.json`
post_rollback_browser_revalidation_proof: `not-applicable-retired-rc1-boundary`
final_browser_e2e_recheck_proof: `docs/release-artifacts/prod-candidate-2026-08-26-local-rc14-evidence/browser.json`
full_verifier_sweep_proof: `pending-source-checkout-attestation`
truth_mirror_rebaseline_proof: `pending-local-qualification`
release_readiness_rerun_proof: `pending-local-qualification`
browser_rerun_status: `passed DEV-ONLY on 2026-08-26; browser contract, product acceptance with a real Cloudflare Workers AI generation, 22-page actions, responsive 22-route proof, and O4 write proof are green against source d0674bfc1367b04d95ca2bf745e89fabf12046ad`
review_gate: `pending`
owner_decision: `no-release`
hosted_staging_parity: `false`
production_rollout_claimed: `false`
checklist_verified_count: `pending-source-checkout-attestation; prior recorded score remains 17`
checklist_blocked_count: `2-owner-blocked-plus-source-checkout-attestation-pending`
phase5_computed_percent: `89 recorded and unchanged; RC14 receives no new credit before source-attested CI and final truth binding`

## Phase-5 Readiness Checklist

The five local qualification chains are green and preserved as immutable RC14
evidence. Source-attested CI and the final truth binding are still pending. No
new Phase-5 credit is claimed by this draft candidate transition. I1
`hosted_candidate_parity` and I5 `production_auth_identity` remain zero-credit
Owner blocks regardless of the local result.

## Candidate-Bound Observability

- Health: `/api/v1/health`, `/mcp/api/v1/health`, `/llm/api/v1/health`.
- Metrics: `/api/v1/metrics`.
- Audit: `/api/v1/audit/recent`, `/api/v1/audit/mcp`.
- Contracts: `/api/v1/errors/contract`, `/api/v1/rate-limit/contract`,
  `/api/v1/sessions/history/contract`, `/api/v1/request/contract`,
  `/api/v1/trace/contract`.
- Escalation: `docs/runbooks/incident-response.md`.

## Budget Review

- New recurring infrastructure: none.
- Paid provider/tier: none.
- Card/payment action: none.
- Existing ceiling: maximum 20 EUR/month; unchanged.
- GHCR publication: Post-Market Owner action, not executed and not credited.

## Open Questions Accepted Under No-Release

1. I1 stays `NEIN` until a non-local HTTPS surface is source-bound to RC14.
2. I5 stays `NEIN` until the Owner completes production OAuth and the hosted
   fail-closed verifier passes.

## What This Candidate Changes Against RC13

RC14 freezes the functional Responses SSE adapter and fixed filesystem
project-progress adapter delivered after RC13. It also binds the market-ready
entrypoint to external-gate evaluation, closes the subsequent frontend
dependency advisories, removes the alternate 2D cortex boot flash, and bounds
the MCP audit transport so an unavailable audit sink remains fail-closed
without an unbounded request.

## Guardrails / Non-Claims

- DEV-ONLY; hosted proof still blocked.
- Local Docker image IDs are not registry digests.
- GHCR publication is Post-Market and remains unexecuted.
- `docker_registry_publish` remains owner-granted false and live-verified false.
- This artifact does not claim a production rollout.
- Production deployment still requires the release-candidate gate bundle and a separate rollout proof.
- No registry push, provider write beyond the explicitly approved DEV-ONLY
  acceptance calls, production deploy, release promotion, Owner approval,
  payment, or secret output is performed.
