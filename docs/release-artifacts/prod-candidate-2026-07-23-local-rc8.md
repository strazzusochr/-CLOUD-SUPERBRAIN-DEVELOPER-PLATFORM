# Release Artifact

release_id: `prod-candidate-2026-07-23-local-rc8`
scope: `Session 8 Agent-Pool runtime UI parity and PostCSS security-fix production-candidate requalification for six owned service images`
environment: `production-candidate`
source_branch: `claude/cloud-superbrain-analysis-127d2e`
source_commit_sha: `3bd216f0296afb3bd7ad94e44b6540c6201ab845`
source_commit_semantics: `committed green source after strict Agent-Pool API-to-SSR verifier parity, current RC6/RC7 truth synchronization, and exact PostCSS 8.5.12 security override; candidate images are built exclusively from the Git archive and exclude dirty or untracked worktree content`
immutable_image_commit_sha: `3bd216f0296afb3bd7ad94e44b6540c6201ab845`
workflow_run_url: `unavailable-local-proof`
pipeline_status: `local clean-archive build and candidate verification passed; hosted stateful pipeline remains blocked`
smoke_result: `verified-local-chromium`
observability_check: `local-present-hosted-release-blocked`
rollback_note: `local rollback target is prod-candidate-2026-07-23-local-rc7 at 6c344b37f2cef21d952c1f2b5235ae6c4c36dbf9; no hosted rollback is authorized or executed`
rollback_target_commit_sha: `6c344b37f2cef21d952c1f2b5235ae6c4c36dbf9`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:3bd216f0296afb3bd7ad94e44b6540c6201ab845`
immutable_tag_publish_status: `unpublished`
review_gate: `pending`
owner_decision: `no-release`
owner_decision_proof: `AGENTS.md Stop Gate remains closed`
hosted_staging_parity: `false`
production_rollout_claimed: `false`

## Local Build Evidence

- Report: `.codex/runs/CURRENT/master-goal/phase5/production-candidate-local/candidate-images.json`.
- Generated: `2026-07-23T19:17:43.8346186Z`.
- Git archive SHA256: `bb3336b424bca9777e420f1ed7f3d7972b10761bd0e81ac10303d936dc645c6d`.
- Source boundary: committed Git archive only.
- Six production targets: frontend, agent-api, agent-worker, memory-worker, mcp-gateway, llm-gateway.
- Local image identity: Docker image IDs plus OCI revision/source/version labels.
- Embedded source parity: every image file SHA256 equals the archived source file SHA256.
- Frontend production image contains Next.js `BUILD_ID` `4ppPqqriea7Dt5-A2EN5E`.
- Candidate report SHA256: `303F75382936576F1D36A2A45C2C388DC5D3964ED1C2AA1B6AA98B2AB8DE13B6`.
- Full browser verification SHA256: `0E1A4B94EE2AC2B81435A0903B7954115B89F5710AF1BAC48D6BFF98BDBE8800`.
- `npm run verify:phase5-candidate-local`: `1 passed`; image identity, embedded source parity, runtime-source parity, rollback binding, read-only API contract, and browser click verified.
- `npm run verify:current-release-candidate`: `candidate_technical=true`, `runtime_source_parity=true`, `promotion_eligible=false`, canonical `blocked`.

## Guardrails / Non-Claims

- DEV-ONLY; hosted proof still blocked.
- The GHCR tag set above is planned and unpublished; local Docker image IDs are not registry digests.
- Hosted stateful parity, production deploy, release promotion, and Owner approval are false.
- The Vercel backend proof remains a stateless read-only Contract Origin, not this six-service candidate.
- No registry push, provider write, live LLM call, live MCP write, model download, or secret output is performed.
- This freshness requalification claims no new Phase-5 percentage credit; Phase 5 remains `68%`.
- This artifact does not claim a production rollout.
- Production deployment still requires the release-candidate gate bundle and a separate rollout proof.
