# Release Artifact

release_id: `prod-candidate-2026-07-22-local-rc6`
scope: `memory vector-gate and D1 boundary-verifier production-candidate requalification for six owned service images`
environment: `production-candidate`
source_branch: `claude/cloud-superbrain-analysis-127d2e`
source_commit_sha: `60d48868fbcad29d010d348916b261760d6a74ed`
source_commit_semantics: `committed green source after separating verified Cloudflare D1 lexical persistence from fail-closed Vectorize semantic-search approval and hosted proof, plus the strengthened stateful build ownership-boundary verifier; candidate images are built exclusively from the Git archive and exclude dirty or untracked worktree content`
immutable_image_commit_sha: `60d48868fbcad29d010d348916b261760d6a74ed`
workflow_run_url: `unavailable-local-proof`
pipeline_status: `local clean-archive build and candidate verification passed; hosted stateful pipeline remains blocked`
smoke_result: `verified-local-chromium`
observability_check: `local-present-hosted-release-blocked`
rollback_note: `local rollback target is prod-candidate-2026-07-22-local-rc5 at 255e328a76b3f84bf74358bc7258b9ffb797b339; no hosted rollback is authorized or executed`
rollback_target_commit_sha: `255e328a76b3f84bf74358bc7258b9ffb797b339`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:60d48868fbcad29d010d348916b261760d6a74ed`
immutable_tag_publish_status: `unpublished`
review_gate: `pending`
owner_decision: `no-release`
owner_decision_proof: `AGENTS.md Stop Gate remains closed`
hosted_staging_parity: `false`
production_rollout_claimed: `false`

## Local Build Evidence

- Report: `.codex/runs/CURRENT/master-goal/phase5/production-candidate-local/candidate-images.json`.
- Generated: `2026-07-22T09:15:04.5025328Z`.
- Git archive SHA256: `2d8f2d6448aef1062ecab053db9f2419b964fab180ec0d0326a25b5bde076759`.
- Source boundary: committed Git archive only.
- Six production targets: frontend, agent-api, agent-worker, memory-worker, mcp-gateway, llm-gateway.
- Local image identity: Docker image IDs plus OCI revision/source/version labels.
- Embedded source parity: every image file SHA256 equals the archived source file SHA256.
- Frontend production image contains Next.js `BUILD_ID` `DIzdbYhGUawr_csoQGaT7`.
- Candidate report SHA256: `6DD8295C66B187CF3275870302CB100463555A36ED788F77539C875248FE4651`.
- Full browser verification SHA256: `B16E40D8B52FD3245E70C859C24D8F23EDD4ABD4C67FAAD04305BB6E538551F3`.
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
