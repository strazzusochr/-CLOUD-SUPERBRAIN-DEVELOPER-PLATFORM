# Release Artifact

release_id: `prod-candidate-2026-07-22-local-rc5`
scope: `auth/security production-candidate requalification for six owned service images`
environment: `production-candidate`
source_branch: `claude/cloud-superbrain-analysis-127d2e`
source_commit_sha: `255e328a76b3f84bf74358bc7258b9ffb797b339`
source_commit_semantics: `committed green source after fail-closed OAuth/JWT credential issuance, one-time OAuth state and refresh registries, persisted auth-audit enforcement before cookie issuance, query-safe access logging, and the patched frontend sharp dependency; candidate images are built exclusively from the Git archive and exclude dirty or untracked worktree content`
immutable_image_commit_sha: `255e328a76b3f84bf74358bc7258b9ffb797b339`
workflow_run_url: `unavailable-local-proof`
pipeline_status: `local clean-archive build and candidate verification passed; hosted stateful pipeline remains blocked`
smoke_result: `verified-local-chromium`
observability_check: `local-present-hosted-release-blocked`
rollback_note: `local rollback target is prod-candidate-2026-07-21-local-rc4 at 0679f6ffda099a6fcddf6830839a195ebe7d13a7; no hosted rollback is authorized or executed`
rollback_target_commit_sha: `0679f6ffda099a6fcddf6830839a195ebe7d13a7`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:255e328a76b3f84bf74358bc7258b9ffb797b339`
immutable_tag_publish_status: `unpublished`
review_gate: `pending`
owner_decision: `no-release`
owner_decision_proof: `AGENTS.md Stop Gate remains closed`
hosted_staging_parity: `false`
production_rollout_claimed: `false`

## Local Build Evidence

- Report: `.codex/runs/CURRENT/master-goal/phase5/production-candidate-local/candidate-images.json`.
- Generated: `2026-07-22T02:37:29.2047215Z`.
- Git archive SHA256: `56630e8765093f50175966b6d6a8a3c796a06dd4dea420194c8d5a670cab00fb`.
- Source boundary: committed Git archive only.
- Six production targets: frontend, agent-api, agent-worker, memory-worker, mcp-gateway, llm-gateway.
- Local image identity: Docker image IDs plus OCI revision/source/version labels.
- Embedded source parity: every image file SHA256 equals the archived source file SHA256.
- Frontend production image contains Next.js `BUILD_ID` `Ll84IOZZ5oKQ6KeZkRpFj`.
- Candidate report SHA256: `906C202FF2A74D32E52DD3AD77D17910B7777C97C4B3A90A1A761A88603E54B9`.
- Full browser verification SHA256: `BEA1898986560DE6B987B01752AA2A802EA8209FE171034FFB0E30FD03867EBC`.
- `npm run verify:phase5-candidate-local`: `1 passed`; image identity, embedded source parity, runtime-source parity, rollback binding, read-only API contract, and browser click verified.
- `npm run verify:current-release-candidate`: `candidate_technical=true`, `runtime_source_parity=true`, `promotion_eligible=false`, canonical status `blocked`; hosted snapshot `84` remains stale against local manifest `86`.

## Guardrails / Non-Claims

- DEV-ONLY; hosted proof still blocked.
- The GHCR tag set above is planned and unpublished; local Docker image IDs are not registry digests.
- Hosted stateful parity, production deploy, release promotion, and Owner approval are false.
- The Vercel backend proof remains a stateless read-only Contract Origin, not this six-service candidate.
- No registry push, provider write, live LLM call, live MCP write, or secret output is performed.
- This freshness requalification claims no new Phase-5 percentage credit; Phase 5 remains `68%`.
- This artifact does not claim a production rollout.
- Production deployment still requires the release-candidate gate bundle and a separate rollout proof.
