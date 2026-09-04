# Release Artifact

release_id: `prod-candidate-2026-07-13-local-rc1`
scope: `local content-addressed production-candidate preparation for six owned service images`
environment: `production-candidate`
source_branch: `claude/cloud-superbrain-analysis-127d2e`
source_commit_sha: `c451fa8ff2b631685ad07ebcfcf4dc4a5b418e81`
source_commit_semantics: `last committed green runtime source; candidate images are built exclusively from git archive, excluding dirty and untracked worktree content`
immutable_image_commit_sha: `c451fa8ff2b631685ad07ebcfcf4dc4a5b418e81`
workflow_run_url: `unavailable-local-proof`
pipeline_status: `local candidate build and verifier required; hosted pipeline remains blocked`
smoke_result: `blocked-hosted`
observability_check: `local-present-hosted-blocked`
rollback_note: `candidate-scoped rollback target is dev-candidate source 7be0ac03de2a5f435d98629de3d310253c00e3f3; no hosted rollback was executed`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:c451fa8ff2b631685ad07ebcfcf4dc4a5b418e81`
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
- Browser proof: real Chromium selection and click on the Diagnostics contract surface.
- Focused command: `npm run verify:phase5-candidate-local`.

## Guardrails / Non-Claims

- DEV-ONLY; hosted proof still blocked.
- The GHCR tag set above is planned and unpublished; local Docker image IDs are not registry digests.
- Hosted staging parity, production deploy, release promotion, and Owner approval are false.
- No registry push, provider write, live LLM call, live MCP write, or secret output is performed.
- This artifact does not claim a production rollout.
- Production deployment still requires the release-candidate gate bundle and a separate rollout proof.
