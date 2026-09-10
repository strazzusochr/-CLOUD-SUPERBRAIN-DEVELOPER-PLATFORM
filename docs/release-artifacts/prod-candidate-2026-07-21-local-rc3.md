# Release Artifact

release_id: `prod-candidate-2026-07-21-local-rc3`
scope: `current runtime-source production-candidate requalification for six owned service images`
environment: `production-candidate`
source_branch: `claude/cloud-superbrain-analysis-127d2e`
source_commit_sha: `90b57ecaa54e0ab750a57d0e1acfb33779675f5a`
source_commit_semantics: `committed green runtime source after hosted MCP parity and repository-root GHCR build-context repair; candidate images are built exclusively from the Git archive and exclude dirty or untracked worktree content`
immutable_image_commit_sha: `90b57ecaa54e0ab750a57d0e1acfb33779675f5a`
workflow_run_url: `unavailable-local-proof`
pipeline_status: `local clean-archive build and candidate verification; hosted stateful pipeline remains blocked`
smoke_result: `verified-local-chromium`
observability_check: `local-present-hosted-release-blocked`
rollback_note: `local rollback target is prod-candidate-2026-07-20-local-rc2 at 1d8304456a6a95a2a05de65cf0d576ee68c20733; no hosted rollback is authorized or executed`
rollback_target_commit_sha: `1d8304456a6a95a2a05de65cf0d576ee68c20733`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:90b57ecaa54e0ab750a57d0e1acfb33779675f5a`
immutable_tag_publish_status: `unpublished`
review_gate: `pending`
owner_decision: `no-release`
owner_decision_proof: `AGENTS.md Stop Gate remains closed`
hosted_staging_parity: `false`
production_rollout_claimed: `false`

## Local Verification Evidence

- Source boundary: committed Git archive only.
- Six production targets: frontend, agent-api, agent-worker, memory-worker, mcp-gateway, llm-gateway.
- Local image identity: Docker image IDs plus OCI revision/source/version labels.
- Embedded source parity: image file SHA256 equals the archived source file SHA256.
- Frontend proof: production target contains a non-empty Next.js `BUILD_ID`.
- Runtime-source parity: no committed drift exists from the candidate source to HEAD across the six service trees, canonical progress and external-gate state, the autonomous roster, or the root Docker context policy.
- Browser proof: real Chromium selection and click on the Diagnostics contract surface.
- Runtime-only verification writes `verification-runtime.json` and cannot overwrite the full browser artifact.
- Current hosted boundary proof follows the canonical external-gate summary and keeps promotion eligibility false while that summary is blocked.
- Focused commands: `npm run verify:phase5-candidate-local` and `npm run verify:current-release-candidate`.

## Guardrails / Non-Claims

- DEV-ONLY; hosted stateful proof remains blocked.
- The GHCR tag set above is planned and unpublished; local Docker image IDs are not registry digests.
- Hosted stateful parity, production deploy, release promotion, and Owner approval are false.
- The Vercel backend proof remains a stateless read-only Contract Origin, not this six-service candidate.
- No registry push, provider write, live LLM call, live MCP write, or secret output is performed.
- This freshness requalification claims no new Phase-5 percentage credit; Phase 5 remains `68%`.
- This artifact does not claim a production rollout.
- Production deployment still requires the release-candidate gate bundle and a separate rollout proof.
