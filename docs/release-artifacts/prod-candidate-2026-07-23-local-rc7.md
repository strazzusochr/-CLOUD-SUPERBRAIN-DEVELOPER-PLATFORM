# Release Artifact

release_id: `prod-candidate-2026-07-23-local-rc7`
scope: `Session 5 browser-hardening and Next.js security-update production-candidate requalification for six owned service images`
environment: `production-candidate`
source_branch: `claude/cloud-superbrain-analysis-127d2e`
source_commit_sha: `6c344b37f2cef21d952c1f2b5235ae6c4c36dbf9`
source_commit_semantics: `committed green source after deterministic browser-contract hardening, keyed run-build loading, and the Next.js 16.2.11 security update; candidate images are built exclusively from the Git archive and exclude dirty or untracked worktree content`
immutable_image_commit_sha: `6c344b37f2cef21d952c1f2b5235ae6c4c36dbf9`
workflow_run_url: `unavailable-local-proof`
pipeline_status: `local clean-archive build and candidate verification passed; hosted stateful pipeline remains blocked`
smoke_result: `verified-local-chromium`
observability_check: `local-present-hosted-release-blocked`
rollback_note: `local rollback target is prod-candidate-2026-07-22-local-rc6 at 60d48868fbcad29d010d348916b261760d6a74ed; no hosted rollback is authorized or executed`
rollback_target_commit_sha: `60d48868fbcad29d010d348916b261760d6a74ed`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:6c344b37f2cef21d952c1f2b5235ae6c4c36dbf9`
immutable_tag_publish_status: `unpublished`
review_gate: `pending`
owner_decision: `no-release`
owner_decision_proof: `AGENTS.md Stop Gate remains closed`
hosted_staging_parity: `false`
production_rollout_claimed: `false`

## Local Build Evidence

- Report: `.codex/runs/CURRENT/master-goal/phase5/production-candidate-local/candidate-images.json`.
- Generated: `2026-07-23T03:16:25.6091862Z`.
- Git archive SHA256: `4f8153107ff0e1b01fc87483c4fe836f3cbb99819e5004a492f7254714b5a42f`.
- Source boundary: committed Git archive only.
- Six production targets: frontend, agent-api, agent-worker, memory-worker, mcp-gateway, llm-gateway.
- Local image identity: Docker image IDs plus OCI revision/source/version labels.
- Embedded source parity: every image file SHA256 equals the archived source file SHA256.
- Frontend production image contains Next.js `BUILD_ID` `unkoWDsiDR97T29Fl_x8U`.
- Candidate report SHA256: `E3F6106A636BD5F6FC059A5F8B9D75B36E9DB92ED4F2A480780A2775FE03842C`.
- Full browser verification SHA256: `4227B5DCEB3AAACFBE5F8AC1863A1D52FDD91DD325F9FE797AF24CFDD5BE6957`.
- `npm run verify:phase5-candidate-local`: `1 passed`; image identity, embedded source parity, runtime-source parity, rollback binding, read-only API contract, and browser click verified.

## Guardrails / Non-Claims

- DEV-ONLY; hosted proof still blocked.
- The GHCR tag set above is planned and unpublished; local Docker image IDs are not registry digests.
- Hosted stateful parity, production deploy, release promotion, and Owner approval are false.
- The Vercel backend proof remains a stateless read-only Contract Origin, not this six-service candidate.
- No registry push, provider write, live LLM call, live MCP write, or secret output is performed.
- This freshness requalification claims no new Phase-5 percentage credit; Phase 5 remains `68%`.
- This artifact does not claim a production rollout.
- Production deployment still requires the release-candidate gate bundle and a separate rollout proof.
