# Release Artifact

release_id: `prod-candidate-2026-07-24-local-rc10`
scope: `Session 8 free PostCSS security-patch production-candidate requalification for six owned service images`
environment: `production-candidate`
source_branch: `claude/cloud-superbrain-analysis-127d2e`
source_commit_sha: `2ae4c61aa876759abcaa83c36c0a3379206b91a4`
source_commit_semantics: `committed green source after replacing the vulnerable exact PostCSS 8.5.12 override with fixed 8.5.23, refreshing the lockfile, confirming npm audit zero, and rerunning the full static, runtime, and browser gates; candidate images are built exclusively from the Git archive and exclude dirty or untracked worktree content`
immutable_image_commit_sha: `2ae4c61aa876759abcaa83c36c0a3379206b91a4`
workflow_run_url: `unavailable-local-proof`
pipeline_status: `local clean-archive build and candidate verification passed; hosted stateful pipeline remains blocked`
smoke_result: `verified-local-chromium`
observability_check: `local-present-hosted-release-blocked`
rollback_note: `local rollback target is prod-candidate-2026-07-24-local-rc9 source 0cbe644c84812bbe72811516d58a70be8c27ffa5; no hosted rollback is authorized or executed`
rollback_target_commit_sha: `0cbe644c84812bbe72811516d58a70be8c27ffa5`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:2ae4c61aa876759abcaa83c36c0a3379206b91a4`
immutable_tag_publish_status: `unpublished`
review_gate: `pending`
owner_decision: `no-release`
owner_decision_proof: `AGENTS.md Stop Gate remains closed`
hosted_staging_parity: `false`
production_rollout_claimed: `false`

## Local Build Evidence

- Report: `.codex/runs/CURRENT/master-goal/phase5/production-candidate-local/candidate-images.json`.
- Generated: `2026-07-24T19:18:49.0017614Z`.
- Git archive SHA256: `acddf0e7bacd117e4796d618722a4daede9ed84f5813045c2c58afd727f1ebd1`.
- Source boundary: committed Git archive only.
- Six production targets: frontend, agent-api, agent-worker, memory-worker, mcp-gateway, llm-gateway.
- Local image identity: Docker image IDs plus OCI revision/source/version labels.
- Embedded source parity: every image file SHA256 equals the archived source file SHA256.
- Frontend production image contains Next.js `BUILD_ID` `K1RYRyr2WuLFjXFPVnOfu`.
- Candidate report SHA256 before candidate verification: `F6DB74228773767857E301FE7A7E90C4B0D8FA5FA12E395C506EA6EE778C0078`.
- Full project verification: `npm run verify`, `npm run verify:runtime`, and `npm run verify:browser` passed after the dependency patch; responsive proof covered 22 routes x 2 viewports = 44 clicks.
- Frontend dependency audit: `0 vulnerabilities`.
- Full candidate verification SHA256: `75B226536EDCDB8DB68E4B4B036E6B6BDF4BA73DBC0796F273F86C078725691B`.
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
