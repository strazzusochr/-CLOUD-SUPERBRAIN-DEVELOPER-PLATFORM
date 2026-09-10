# Release Artifact

release_id: `prod-candidate-2026-07-24-local-rc9`
scope: `Session 8 free supply-chain and Agent API error-redaction production-candidate requalification for six owned service images`
environment: `production-candidate`
source_branch: `claude/cloud-superbrain-analysis-127d2e`
source_commit_sha: `0cbe644c84812bbe72811516d58a70be8c27ffa5`
source_commit_semantics: `committed green source after pinning 17 GitHub Actions to commit SHAs, 18 external image occurrences to nine registry digests, enforcing six internal GHCR references, and redacting prompt-persistence exceptions; candidate images are built exclusively from the Git archive and exclude dirty or untracked worktree content`
immutable_image_commit_sha: `0cbe644c84812bbe72811516d58a70be8c27ffa5`
workflow_run_url: `unavailable-local-proof`
pipeline_status: `local clean-archive build and candidate verification passed; hosted stateful pipeline remains blocked`
smoke_result: `verified-local-chromium`
observability_check: `local-present-hosted-release-blocked`
rollback_note: `local rollback target is prod-candidate-2026-07-23-local-rc8 source 3bd216f0296afb3bd7ad94e44b6540c6201ab845; no hosted rollback is authorized or executed`
rollback_target_commit_sha: `3bd216f0296afb3bd7ad94e44b6540c6201ab845`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:0cbe644c84812bbe72811516d58a70be8c27ffa5`
immutable_tag_publish_status: `unpublished`
review_gate: `pending`
owner_decision: `no-release`
owner_decision_proof: `AGENTS.md Stop Gate remains closed`
hosted_staging_parity: `false`
production_rollout_claimed: `false`

## Local Build Evidence

- Report: `.codex/runs/CURRENT/master-goal/phase5/production-candidate-local/candidate-images.json`.
- Generated: `2026-07-24T17:52:36.4718925Z`.
- Git archive SHA256: `43a497aa7866bc9012858d0304b48453bbb26ad47c13c1404d89ef3d70646f96`.
- Source boundary: committed Git archive only.
- Six production targets: frontend, agent-api, agent-worker, memory-worker, mcp-gateway, llm-gateway.
- Local image identity: Docker image IDs plus OCI revision/source/version labels.
- Embedded source parity: every image file SHA256 equals the archived source file SHA256.
- Frontend production image contains Next.js `BUILD_ID` `0YM1seuQwj03IjqEoT5Ae`.
- Candidate report SHA256: `D08AC2F8FE8512C47823E8EE15457337A8A01E7EBF85B97D92A77AF553DEBA4F`.
- Full browser verification SHA256: `E143230BA6E5EB7F00FEEDD19EE10295BFB5B7B7A0DB75A03484202D5F30A205`.
- `npm run verify:phase5-candidate-local`: `1 passed`; image identity, embedded source parity, runtime-source parity, rollback binding, read-only API contract, and browser click verified.

## Guardrails / Non-Claims

- DEV-ONLY; hosted proof still blocked.
- The GHCR tag set above is planned and unpublished; local Docker image IDs are not registry digests.
- Hosted stateful parity, production deploy, release promotion, and Owner approval are false.
- The Vercel backend proof remains a stateless read-only Contract Origin, not this six-service candidate.
- No registry push, provider write, live LLM call, live MCP write, model download, or secret output is performed.
- This freshness requalification claims no new Phase-5 percentage credit; Phase 5 remains `68%`.
- This artifact does not claim a production rollout.
- Production deployment still requires the release-candidate gate bundle and a separate rollout proof.
