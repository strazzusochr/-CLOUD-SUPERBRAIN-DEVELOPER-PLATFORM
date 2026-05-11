# Cloud Truth - 2026-05-11 HF Router Checkpoint

Status: verified
Date: 2026-05-11

## Active Cloud Surfaces

- Hetzner staging: `https://188-34-191-140.sslip.io`
- Hetzner active image tag: `deploy-20260511-agentfix-full`
- Hetzner previous base image tag: `deploy-20260511-182742-hfrouter`
- Hetzner interim frontend hotfix image override was `frontend-agentfix-20260511`; it has been folded into the active six-service tag set.
- Vercel production alias: `https://frontend-seven-psi-78.vercel.app`
- Vercel deployment: `https://frontend-6rz8tkr79-strazzusochrs-projects.vercel.app`
- Vercel backend rewrites:
  - `AGENT_API_BASE_URL=https://188-34-191-140.sslip.io`
  - `MCP_GATEWAY_BASE_URL=https://188-34-191-140.sslip.io/mcp`
  - `LLM_GATEWAY_BASE_URL=https://188-34-191-140.sslip.io/llm`

## LLM Runtime Truth

- OpenAI API key is not required for the active LLM gateway.
- Active live provider is Hugging Face Router through OpenAI-compatible HTTP semantics.
- Required LLM secret for current live generation: `HF_TOKEN`.
- No model downloads are performed by the runtime.
- Live provider calls are disabled by default.
- Live calls require explicit request metadata: `metadata.live_provider_calls_allowed=true`.
- Default model: `deepseek-ai/DeepSeek-V4-Flash:fastest`.
- Planner route: `deepseek-ai/DeepSeek-V4-Pro:fastest`.

## Open-Source-First Model Families

Configured runtime routes use Hugging Face router models from:

- DeepSeek
- Qwen
- Google Gemma
- Meta Llama
- Z.ai GLM
- inclusionAI Ling
- Moonshot Kimi

## Verification Evidence

Local verification:

- Python compile passed for changed gateway/API modules.
- `npm audit --omit=dev` returned `0 vulnerabilities`.
- Next.js production build passed locally.
- Local HF router live gateway check passed for chat completions and Responses adapter.

Cloud build and deploy:

- Remote ARM64 Docker build completed on Hetzner.
- Initial images were pushed to GHCR using tag `deploy-20260511-182742-hfrouter`.
- The current six-service staging parity tag is `deploy-20260511-agentfix-full`.
- Hetzner deploy completed with image filesystem enabled.
- All cloud compose services reported healthy after deployment.

Hosted API verification:

- `GET https://188-34-191-140.sslip.io/api/v1/health` returned `200`.
- `GET https://188-34-191-140.sslip.io/llm/api/v1/health` returned `provider=huggingface_inference_router`, `provider_status=live_verified`.
- `GET https://188-34-191-140.sslip.io/llm/v1/models` returned configured HF router models plus visible router model inventory.
- Hosted chat completion live call returned `200` with `live_provider_calls=true`.
- Hosted Responses adapter live call returned `200` with `status=completed` and `live_provider_calls=true`.

Browser verification:

- Hetzner browser check showed `HF router verified`, `huggingface_inference_router`, and no new browser errors/warnings.
- Vercel browser check showed no `budget 404`, `HF router verified`, backend provider text visible, and no new browser errors/warnings.

Verifier results:

- `scripts/verify-hosted-staging-smoke.ps1 -BaseUrl https://188-34-191-140.sslip.io`: passed.
- `scripts/verify-hosted-staging.ps1 -BaseUrl https://188-34-191-140.sslip.io -SafeProfile`: passed.
- `scripts/verify-phase4-orchestrator-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`: passed.
- `scripts/verify-phase4-rotation-events-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`: passed.
- `scripts/verify-phase4-rotation-policy-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`: passed.
- `scripts/verify-phase4-agent-profiles-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`: passed.
- `scripts/verify-phase4-model-capabilities-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`: passed.
- `scripts/verify.ps1 -Suite security`: passed.
- `scripts/verify.ps1 -Suite hosted-staging-smoke -BaseUrl https://188-34-191-140.sslip.io`: passed.
- `scripts/verify.ps1 -Suite hosted-staging -BaseUrl https://188-34-191-140.sslip.io -SafeProfile`: passed.
- `scripts/verify.ps1 -Suite external-gates-with-tokens -BaseUrl https://188-34-191-140.sslip.io`: passed with generated artifact `.phase1-artifacts/external-gate-audit-20260511-203512.json` and `status=verified`.

## Gate Caveat

`scripts/verify.ps1 -Suite external-gates -BaseUrl https://188-34-191-140.sslip.io` runs without private env bootstrap and can still report `action_required` for token-backed checks. The authoritative token-backed gate result for this checkpoint is `external-gates-with-tokens`, which passed.

## Multi-Agent Follow-Up - 2026-05-11

Coordinator agents rechecked the platform split by role:

- Planner: confirmed the HF-router cloud surface is operationally verified, while the canonical release truth still remains fail-closed until worktree/rebaseline decisions are resolved.
- QA: independently verified security, evidence-artifact safety, Vercel access, external gates, Hetzner health, and Vercel rewrite health.
- Security: found no hardcoded secret values in tracked diffs, but flagged parent-workspace local artifacts that must stay outside commit/share scope.
- Cloud/DevOps: confirmed Hetzner and Vercel health/rewrite behavior, GHCR image tag presence, remote Hetzner `.env` selector, and absence of `/app/app` hot mounts on the deployed services.
- Coder review: identified frontend render-crash risks from partial API payloads; the dashboard now defensively handles optional arrays and nested objects in the affected progress, agent-activity, MCP pinning, and memory-embedding sections.

Additional verification after the follow-up:

- `npm run build --prefix apps/frontend`: passed after the known Windows sandbox `spawn EPERM` was rerun outside sandbox.
- Vercel production deploy passed: `dpl_5wWtQqb7eed5aTqGnWiEdUwchR8s`, deployment `https://frontend-6rz8tkr79-strazzusochrs-projects.vercel.app`, alias `https://frontend-seven-psi-78.vercel.app`.
- Post-deploy Vercel HTTP checks passed for `/`, `/api/v1/health`, `/llm/api/v1/health`, and the direct deployment root.
- In-app browser verification on the Vercel alias showed `Cloud Superbrain`, `HF router verified`, `Agent Activity`, and `Progress Integrity` visible. A retained browser log entry from the older Hetzner chunk was observed, but no current Vercel asset URL was implicated by the page HTML.
- `scripts/verify.ps1 -Suite release-boundary-regression`: passed after rebasing expected Vercel access from the historical blocked state to `project_visible_with_configured_team`.
- `scripts/verify.ps1 -Suite release-boundary -ReportOnly -MaxWaitSeconds 1`: completed all 24 scripts with `failed=0` and an explicit blocked truth state.
- `scripts/verify.ps1 -Suite security`: passed.
- `scripts/verify.ps1 -Suite hosted-staging-smoke -BaseUrl https://188-34-191-140.sslip.io`: passed.

Hetzner image refresh status:

- Target server is Hetzner CAX21 ARM.
- Local Docker is ready outside sandbox (`docker info` server `29.4.1`).
- Local default builder cannot run `linux/arm64` build steps and fails with `exec format error`.
- Docker cloud builder `cloud-hansibert83hi-gfh` advertises `linux/arm64`, but build is blocked by `concurrent build limit of 0`.
- A native remote ARM frontend-only hotfix build on Hetzner succeeded with local image tag `frontend-agentfix-20260511`, and the hosted smoke check passed afterward.
- A local-only Hetzner staging tag set `deploy-20260511-agentfix-full` was prepared on the Hetzner host by retagging the five existing service images plus the new frontend hotfix image. This tag set is present on the host only.
- GHCR publication for all six `deploy-20260511-agentfix-full` service images passed after a fresh `GHCR_TOKEN` was provided.
- Hetzner staging deploy passed with `scripts/deploy-to-staging.ps1 -UseImageFilesystem -ImageTag deploy-20260511-agentfix-full`.
- Remote selector now reports `IMAGE_TAG=deploy-20260511-agentfix-full`.
- All six application services (`agent-api`, `agent-worker`, `memory-worker`, `llm-gateway`, `mcp-gateway`, `frontend`) are running the `deploy-20260511-agentfix-full` GHCR tag and report healthy on the Hetzner host.
- Hosted smoke and hosted safe-profile verification passed after the deploy.
- This is a staging-parity improvement, not a final production release claim. The remaining release blockers are still worktree cleanup/review batching and release rebaseline.

## Release Governance Rebaseline - 2026-05-11

Owner decision is no longer missing:

- Created `docs/analysis/worktree-owner-decision-20260510.json`.
- Strategy: `cleanup-first`.
- Allowed: `may_move=true`, `may_unstage=true`.
- Still forbidden: `may_delete=false`, `may_stage=false`, `may_commit=false`, `may_push=false`, `may_deploy=false`.

Verified governance gates:

- `scripts/verify-worktree-owner-decision.ps1 -ReportOnly`: `owner-decision-valid-mutation-authorized`.
- The owner-decision verifier now preserves JSON date strings with PowerShell `ConvertFrom-Json -DateKind String`; this prevents valid UTC `decided_at` values from being converted to locale-specific `DateTime` text before validation.
- `scripts/verify-worktree-owner-action-packet.ps1 -ReportOnly`: `owner-action-packet-valid-ready`, `finding_count=0`.
- `scripts/verify-owner-decision-readiness-packet.ps1 -ReportOnly`: `owner-decision-readiness-valid-blocked`, `finding_count=0`.
- Controlled index normalization was executed for the 8 split-required paths using `git restore --staged -- <paths>`. Working file contents were not reset or deleted.
- The remaining 2 staged-only paths were also unstaged with `git restore --staged -- <paths>`. Working file contents were not reset or deleted.
- The 9 exclude/quarantine debug/browser helper scripts were moved to `debug-artifacts/quarantine/2026-05-10/scripts/`; `debug-artifacts/` is gitignored and these files no longer appear in release-boundary status.
- `scripts/verify-worktree-change-inventory.ps1 -ReportOnly`: `split_required=0`.
- `scripts/verify-worktree-split-plan.ps1 -ReportOnly`: `split-plan-clear`, `split_path_count=0`.
- `scripts/verify-worktree-split-action-packet.ps1 -ReportOnly`: `split-action-packet-clear`, `action_count=0`.
- `scripts/verify-worktree-quarantine-action-packet.ps1 -ReportOnly`: `quarantine-action-packet-clear`, `action_count=0`.
- Created `docs/analysis/security-review-clearance-20260511.json`; it contains only paths, counts, and dispositions, with no raw secret values, file contents, or diff contents.
- High-confidence token/private-key/JWT pattern checks on the 7 security-review paths and all detect-secrets baseline hotspot lines returned zero pattern hits.
- `scripts/verify-worktree-security-review-packet.ps1 -ReportOnly`: `security-review-packet-clear`, `security_review_count=0`, `finding_count=0`.
- `scripts/verify-worktree-security-review-action-packet.ps1 -ReportOnly`: `security-review-action-packet-clear`, `action_count=0`, `baseline_hotspot_count=0`, `baseline_hotspot_finding_count=0`.
- Created `docs/analysis/release-rebaseline-decision-20260511.json`.
- Selected rebaseline path: `evidence-only-rebaseline`.
- The rebaseline decision explicitly keeps `release_claim_allowed=false`, `may_stage=false`, `may_commit=false`, `may_push=false`, `may_deploy=false`, and `may_release=false`.
- `scripts/verify-release-rebaseline-plan.ps1 -ReportOnly`: `release-rebaseline-evidence-only-selected-blocked`, `valid=True`, `ready=False`, `needs_rebaseline=True`.
- `scripts/verify.ps1 -Suite release-boundary -ReportOnly -MaxWaitSeconds 1`: completed all 24 scripts with `failed=0`; project truth remains explicitly blocked.
- `scripts/verify-release-boundary-regression.ps1 -ReportOnly`: passed with `finding_count=0` after rebasing expectations from the historical missing-owner-decision, split-required, quarantine-pending, security-review-pending, and undecided-rebaseline states to the current valid-decision/split-clear/quarantine-clear/security-clear/evidence-only-rebaseline state.
- HTTPS cloud sanity check via Python/OpenSSL passed for Vercel `/`, Vercel `/api/v1/health`, Hetzner `/api/v1/health`, and Hetzner `/llm/api/v1/health`, each returning `200`. PowerShell `Invoke-WebRequest` and Windows `curl.exe` failed locally before request completion with Schannel credential/TLS errors, so Python/OpenSSL is the reliable shell probe for this checkpoint.
- Runtime sanity recheck after continuing work:
  - `py -3 -m compileall services\agent-api\app services\agent-worker\app services\llm-gateway\app`: passed.
  - `scripts\verify.ps1 -Suite security`: passed with `gitleaks findings: 0` and `secret-scan no secret patterns found`.
  - `npm run build --prefix apps/frontend`: sandbox run failed with Windows `spawn EPERM`; rerun outside sandbox passed, including type checks and static page generation.
  - `scripts\verify.ps1 -Suite hosted-staging-smoke -BaseUrl https://188-34-191-140.sslip.io`: passed.
  - `scripts\verify.ps1 -Suite hosted-staging -BaseUrl https://188-34-191-140.sslip.io -SafeProfile`: passed.

Current fail-closed release blockers:

- worktree remains dirty with unstaged and untracked files;
- current release-boundary count is `staged=0`, `unstaged=50`, `untracked=222`, `staged_and_modified=0`;
- current `HEAD` does not match the older RC1 candidate source SHA;
- the old RC1 artifact still has `owner_decision=no-release`;
- blocking review items remain in the cleanup/review matrix, but no longer from split, quarantine, or security gates;
- release rebaseline is evidence-only selected; final release remains blocked until the worktree is reviewed/clean and a real release candidate is approved.

## Optional Later Provider Keys

No additional provider key is required for the current verified state. Optional future expansion keys for broader open-weight provider routing:

- `TOGETHER_API_KEY`
- `FIREWORKS_API_KEY`
- `DEEPINFRA_API_TOKEN`
- `REPLICATE_API_TOKEN`
- `FAL_KEY`
- `CLOUDFLARE_AI_GATEWAY_URL`

Do not request an OpenAI API key for the current open-source-first LLM gateway path.
