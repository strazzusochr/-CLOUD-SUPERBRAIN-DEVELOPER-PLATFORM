# AI Handoff - Cloud Superbrain Developer Platform

## Project Root

`<repo-root>`

Open this entire folder in the next IDE or AI-agent tool. Do not copy only tracked Git files: the current project state contains many new, untracked files that are required for a 1:1 handoff.

## Current RC21 Handoff — 2026-08-29

Active locally qualified candidate: `prod-candidate-2026-08-28-local-rc21`, frozen source
`c1b022a884eb16939fe0542b2eb9056b60706b20`, control commit
`9f2ee3838492079bd5c65b53a03cd4b29c9a6c49`, source-attested GitHub Actions run
`33217980790`. The committed candidate evidence contains the five independent local chains,
six committed-archive images, the real Chromium `22/22` and `161/161` proof, candidate
runtime identity, security evidence, and the CI checkout attestation. RC20 source
`c29c738b82e4e35cc1288bc603319cba60d167d2` is the exact rollback target. Readiness remains
`17/19 = 89%`; I1 `hosted_candidate_parity` and I5 `production_auth_identity` remain
zero-credit. `DEV-ONLY; hosted proof still blocked`.

The skipped-step gap is closed after an observed red run: RC21's prequalification run had
two mutually exclusive Phase-5 steps marked `skipped`. The workflow now routes all three
Phase-5 modes through one always-executed step. GitHub Actions run `33223542872`, head
`e98f68a6e5ce8544f8504f38a57c0e17672fe253`, passed `25/25` steps with `0` skipped. It
includes the generated-HTML guard, OAuth boundary, both Cloudflare contracts, secret scan,
and all six Phase-1 image builds.

The `github_actions=api_error` root cause is measured: the running DEV-ONLY Agent API had an
older container token while the local secret file and authenticated `gh` keyring matched and
`gh api rate_limit` succeeded. Recreating only `agent-api` with the existing local environment
restored `/api/v1/clouds` to `configured=true`, `live_verified=true`, `status=verified`, with
three resources and no error. No token was printed or rotated.

Owner console preparation is complete but does not close production auth: GitHub
`registry-publication` and `production` environments have Required Reviewer
`strazzusochr`; Cloudflare stores `AGENT_API_AUTH_TOKEN` and
`GITHUB_OAUTH_CLIENT_SECRET` as encrypted Worker secrets; the existing project OAuth App
uses the Worker homepage/callback with wildcard matching disabled; and Vercel Production and
Preview use the same callback URI. A current hosted deploy plus the full OAuth
start/callback/session/replay proof are still missing, so `production_auth_identity` remains
closed.

V0 now has the non-binding Owner draft
`docs/runtime-contracts/layer-credit-rubric.md`. Its proposed L4 and L5 tables each sum to
exactly 100 and name concrete evidence/verifier paths, but `credit_application_allowed=false`.
Until the Owner explicitly approves a rubric commit, L4 stays `55`, L5 stays `56`, and no
percentage moves.

No GHCR publication, default-branch write, production deploy, release promotion, payment,
secret output, Phase-6 hosted-write run, or visual approval is authorized or claimed.

## Current RC20 Handoff — 2026-08-28

Active locally qualified candidate: `prod-candidate-2026-08-28-local-rc20`, frozen source
`c29c738b82e4e35cc1288bc603319cba60d167d2`, control commit
`6f9387c6d492151b9195e3afcbf5a031b094dd67`, source-attested GitHub Actions run
`33200830176`. GitHub checked out the exact candidate SHA; the only control delta was
`scripts/verify-main-deploy-transition.ps1`. Artifact `9697753745`, its GitHub digest,
downloaded archive digest, and embedded attestation are preserved with the candidate.

All five independent chains passed: six committed-archive service images, full runtime,
full real-Chromium browser, candidate-runtime identity/parity with a real selection/click,
and candidate-archive npm-audit/gitleaks security. Browser proof includes a real Cloudflare
Workers AI build with held-key input across animation frames, `22/22` routes, `29/29` action
families, `161/161` action members, responsive `22x2` navigation, and O4
write/readback/rollback. The immutable evidence set has 27 files. Every local result is
`DEV-ONLY; hosted proof still blocked`.

RC20 corrects the real-interaction acceptance harness for generated games that poll held
keys inside `requestAnimationFrame`: ArrowRight and KeyD now stay down across multiple
animation frames before release, and the proof still requires a measurable visible state or
pixel change. This is a qualification-harness correction, not a visual implementation or
final visual approval. Organism polish and the 3-star look remain last.

Readiness remains `17/19 = 89%`. Exactly I1 `hosted_candidate_parity` and I5
`production_auth_identity` remain Owner-blocked and zero-credit. Rollback target is RC19 source
`5062de35a5c033354ba81a988d699aad418347c3`. Overall: `89%`; P0/P1/P2/P4 `100`, P3 `44`,
P5 `89`, P6 `90`; L1/L2/L3/L6/L7 `100`, L4 `55`, L5 `56`. `MARKET_READY:false`.

The RC20 selection truth is on top of control `6f9387c6`; final build, runtime, browser,
static, release-boundary, current-candidate, and market-readiness checks must remain serial.
Preserve the separately staged RC12 file; never use `git add -A`. No GHCR publication,
default-branch write, production deploy, release promotion, Owner approval, payment, secret
output, or final visual approval is authorized or claimed.

## Historical RC19 Handoff — 2026-08-28

RC19 `prod-candidate-2026-08-28-local-rc19` froze source
`5062de35a5c033354ba81a988d699aad418347c3` through control
`59b52fc4093d351970db2cb8f613359b10048bac` and source-attested GitHub Actions run
`33193522336`. Its five local chains and 27-file evidence set passed. RC19 raised the Workers
AI ceiling, made timeout budgets monotonic outward, required complete lit/shadowed 3D output,
and inherited the R3F canvas-ready remount guard. It is now the exact local rollback anchor
for RC20; no hosted rollback or release action is claimed.

## Historical RC17 Handoff — 2026-08-28

Active locally qualified candidate: `prod-candidate-2026-08-28-local-rc17`, frozen source
`bbc2ad481352e8d9ee1e8e9fc010a5d3407d7b85`, control commit
`fd268dbe14a8e9246567be0b1857246bee194a81`, source-attested GitHub Actions run
`33171020720`. GitHub checked out the exact candidate SHA; the only control delta was
`scripts/verify-main-deploy-transition.ps1`. Artifact `9685667549`, its GitHub digest,
downloaded archive digest, and embedded attestation are preserved with the candidate.

All five independent chains passed: six committed-archive service images, full runtime,
full real-Chromium browser, candidate-runtime identity/parity with a real selection/click,
and candidate-archive npm-audit/gitleaks security. Browser proof includes a real Cloudflare
Workers AI build, `22/22` routes, `29/29` action families, `161/161` action members,
responsive `22x2` navigation, and O4 write/readback/rollback. The immutable evidence set has
27 files. Every local result is `DEV-ONLY; hosted proof still blocked`.

RC17 adds an executable-by-contract generated-HTML boundary. Red-first tests reject dead
`examples/js` references, unsupported classic `examples/jsm` references, and `THREE` use
without a prior core dependency. The trusted frontend generation boundary inserts pinned
Three.js `0.160.0` before first use only for the missing-core case; Agent API and Cloudflare
D1 independently fail closed before persistence. The first full browser run caught the real
`THREE is not defined` regression and is not credited; the frozen repair passed all focused,
CI, runtime, candidate, security, and full `22-page-actions` proof.

The Coder target remains gateway-only `qwen3.7-plus`; the live acceptance provider remains
Cloudflare Workers AI. No authenticated Alibaba call occurred. Readiness remains
`17/19 = 89%`. Exactly I1 `hosted_candidate_parity` and I5
`production_auth_identity` remain Owner-blocked and zero-credit. Rollback target is RC16 source
`0a706beae17e25525a312843c236720a1efdf99b`. Overall: `89%`; P0/P1/P2/P4 `100`, P3 `44`,
P5 `89`, P6 `90`; L1/L2/L3/L6/L7 `100`, L4 `55`, L5 `56`. `MARKET_READY:false`.

The selection truth must be committed on top of control `fd268dbe` before the final
source-bound rerun. Then run build, runtime, DEV-LIVE browser/22-page/O4, static and release
boundary verifiers serially and push only `codex/organism-visual-v2`. O4 must stay the last
source-bound browser/write proof. Generated O4 and runtime gate files are evidence, not
selection-commit inputs. Preserve the separately staged RC12 file; never use `git add -A`.
No GHCR publication, default-branch write, production deploy, release promotion, Owner
approval, payment, or secret output is authorized.

## Historical RC16 Handoff — 2026-08-28

Active locally qualified candidate: `prod-candidate-2026-08-28-local-rc16`, frozen source
`0a706beae17e25525a312843c236720a1efdf99b`, control commit
`c37caea08155474b5a8403aa901764b26b2d568f`, source-attested GitHub Actions run
`33122645862`. GitHub checked out the exact candidate SHA; the only control delta was
`scripts/verify-main-deploy-transition.ps1`. Artifact `9667130968`, its GitHub digest,
downloaded archive digest, and embedded attestation are preserved with the candidate.

All five independent chains passed: six committed-archive service images, full runtime,
full real-Chromium browser, candidate-runtime identity/parity with a real selection/click,
and candidate-archive npm-audit/gitleaks security. Browser proof includes a real Cloudflare
Workers AI build, `22/22` routes, `29/29` action families, `161/161` action members,
responsive `22x2` navigation, and O4 write/readback/rollback. The immutable evidence set has
27 files. Every local result is `DEV-ONLY; hosted proof still blocked`.

RC16 keeps RC15's gateway-only `qwen3.7-plus` Coder route and changes one DEV-LIVE error
delimiter from a Unicode em dash to an ASCII hyphen. This repairs Windows PowerShell 5 parsing
without changing runtime behavior, provider routing, permissions, gates, or cost. Qwen Code
`0.22.2` remains gateway-bound; Alibaba is inactive and no authenticated Alibaba call occurred.
The real acceptance provider remained Cloudflare Workers AI.

Readiness remains `17/19 = 89%`. Exactly I1 `hosted_candidate_parity` and I5
`production_auth_identity` remain Owner-blocked and zero-credit. Rollback target is RC15 source
`2e945a6cfd7217ee71372ad3ddc9ad63f4840a2f`. Overall: `89%`; P0/P1/P2/P4 `100`, P3 `44`,
P5 `89`, P6 `90`; L1/L2/L3/L6/L7 `100`, L4 `55`, L5 `56`. `MARKET_READY:false`.

The selection truth is committed before the final source-bound rerun. After that commit, run
build, runtime, DEV-LIVE browser/22-page/O4, static/release-boundary checks, and feature-branch
push serially. O4 must stay the last source-bound browser/write proof. Generated O4 and runtime
gate files are evidence, not selection-commit inputs. Preserve the separately staged RC12 file;
never use `git add -A`. No GHCR publication, default-branch write, production deploy, release
promotion, Owner approval, payment, or secret output is authorized.

## Historical RC15 Handoff — 2026-08-27

Active locally qualified candidate: `prod-candidate-2026-08-27-local-rc15`, frozen source
`2e945a6cfd7217ee71372ad3ddc9ad63f4840a2f`, control commit
`dbb5822f42f742a223ada07820f9e82c0813cbc2`, source-attested GitHub Actions run
`33095778510`. GitHub checked out the exact candidate SHA; the only control delta was
`scripts/verify-main-deploy-transition.ps1`. All CI jobs passed, including source integrity,
frontend audit, OAuth, Cloudflare stateful/LLM, gitleaks, six image builds, and attestation
upload. The downloaded GitHub artifact digest and embedded attestation are preserved in the
RC15 evidence directory.

All five independent candidate chains passed with immutable hashes: committed-archive images
for six services, full runtime, full real-Chromium browser, candidate-runtime image/source
identity plus a real selection/click, and candidate-archive npm-audit/gitleaks security. The
browser chain passed Browser Contract, real Cloudflare Workers AI product generation,
`22/22` routes, `29/29` families, `161/161` action members, responsive `22x2` navigation,
and O4 write/readback/rollback proof. Every local result is `DEV-ONLY; hosted proof still
blocked`.

RC15 adds `qwen3.7-plus` as the gateway-only Coder primary. Qwen Code `0.22.2` is installed
user-scope and its local client points to the LLM Gateway, not Alibaba directly. The dedicated
Alibaba key was absent, the Owner live-provider gate remained closed, and no authenticated
Alibaba request occurred. The real provider used by product acceptance remained Cloudflare
Workers AI. Direct-provider bypass, secret output, GHCR publication, production deployment,
release promotion, default-branch write, and production rollout remain false.

The active pointer, readiness contract, 27-file immutable evidence set, and Phase-5 itemization
are synchronized at `17/19 = 89%`. Exactly I1 `hosted_candidate_parity` and I5
`production_auth_identity` remain Owner-blocked and zero-credit. Rollback target is RC14 source
`d0674bfc1367b04d95ca2bf745e89fabf12046ad`. Overall: `89%`; P0/P1/P2/P4 `100`, P3 `44`,
P5 `89`, P6 `90`; L1/L2/L3/L6/L7 `100`, L4 `55`, L5 `56`. `MARKET_READY:false`.

Do not stage or alter the separately staged historical RC12 artifact. Do not use `git add -A`.
The generated O4, product-acceptance, capability-gate, external-gate, and owner-manifest files
remain working-tree evidence and must not be swept into the RC15 selection commit. O4/browser
must remain the final source-bound write proof after that exact commit. No backup or recovery
clone is needed; protected `.phase1-artifacts/` and `docs/release-artifacts/` are never cleanup
targets.

## Historical Pre-RC15 Development Handoff — 2026-08-27

The active branch is `codex/organism-visual-v2`. The newest completed source slices after RC14
repair browser hydration/retry races, derive the five-axis audit from evidence, and add the
Alibaba Model Studio `qwen3.7-plus` coder strictly through the LLM Gateway. The red-first test
commit is `b586d309`; the implementation commit is `16052d72`; runtime-contract compatibility
fix `f6a20a1` preserves both the established open-source-first routing note and the new Qwen
provider-bound note. DEV-LIVE rehydrate fix `46cefe4` wires the new owner master gate into the
explicit Cloudflare test launcher while keeping Compose and DryRun fail-closed. Preserve the
separately staged historical RC12 file and the generated dirty runtime/evidence files; never use
`git add -A`.

Qwen Code standalone `0.22.2` is installed in user scope. Its provider configuration uses the
DEV-ONLY local gateway boundary `http://localhost:8081/llm/v1`. The repository stores only model
and environment-variable names. `DASHSCOPE_API_KEY` is absent, the owner live-provider gate is
false, and no authenticated Alibaba call was made. A real noninteractive Qwen CLI request reached
the gateway and returned the deterministic `qwen3.7-plus` response with zero tool/file actions.

Focused proof is green: LLM Gateway `23/23`, Agent API `78/78`, Python compile, TypeScript,
focused ESLint, dev/cloud Compose config, runtime Responses SSE, topology `246/500`, and the
fail-closed runtime matrix (`200` health, live request `403`, oversized tokens `422`, direct
provider denied, no secret output). `npm run verify` currently stops at the first O4 source-parity
check because O4 evidence predates the new commits. The first runtime rerun also exposed the
replaced routing note; `f6a20a1` fixed it additively and focused runtime/snapshot readback passed.
The first browser rerun then passed Browser Contract and all `22x2` responsive clicks but exposed
the missing owner-master-gate assignment as a masked Build `503`. `46cefe4` fixed that rehydrate
path and added static plus product-preflight guards. Both DryRun/Live starts reached `10/10`
healthy with effective gate `false/true`; a focused real Cloudflare product build, 3D interaction,
and reload passed. Alibaba remained disabled.
After the final truth commit, run serially:

1. `npm run build`
2. `npm run verify:runtime`
3. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/start-dev-live.ps1`
4. `npm run verify:browser` (O4 remains the last write/browser proof)
5. `npm run verify`
6. release-boundary/current-candidate/market-ready and canonical gitleaks checks
7. push only `codex/organism-visual-v2` if every in-scope check is green

The active qualified candidate remains RC14
`prod-candidate-2026-08-26-local-rc14` at source
`d0674bfc1367b04d95ca2bf745e89fabf12046ad`, CI `32996004920`. The newer branch source is not a
candidate until an independent qualification and source-attested CI run exist. Progress remains
Overall `89%`; P0/P1/P2/P4 `100`, P3 `44`, P5 `89`, P6 `90`; L1/L2/L3/L6/L7 `100`, L4 `55`,
L5 `56`. `MARKET_READY:false`. Open hard gates remain production auth identity, registry
publication and Phase-6 scale authorization. No production rollout, release promotion, GHCR push,
default-branch write, live Alibaba call, or secret use is authorized or claimed.

`DEV-ONLY; hosted proof still blocked` for the new local Qwen and final-build evidence.

## Current RC11 Qualification Truth — 2026-08-01

Active local candidate `prod-candidate-2026-07-31-local-rc11` is bound to committed
source `bae3cdc1692e1e99e7f546f72664a3c747958b8c`. GitHub Actions run
`30686367636` passed for that source. The five independent qualification chains
`runtime`, `browser`, `candidate_images`, `candidate_runtime`, and `security` passed
with real artifacts, hashes, and success anchors. This raises the evidence-derived
Phase 5 value to `89%` and Overall to `89%`; the vertical snapshot is Frontend `100%`,
Orchestrator `100%`, Agent Pool `100%`, LLM Gateway `55%`, MCP Gateway `56%`, Memory
`100%`, and Observability `100%`. `MARKET_READY:false` remains correct.

The remaining RC11 readiness items are exactly I1 `hosted_candidate_parity` and I5
`production_auth_identity`, both `OWNER-BLOCKED`. All five qualification chains are
`DEV-ONLY; hosted proof still blocked`. No GHCR publication, production deployment,
release promotion, default-branch write, or secret output is claimed. Current O4 proof
SHA-256 is `50304C69B3D748C95804C4C72C2970694748F469AE322D5C24DAA6BCB545B11B`.
The frontend and the stateless read-only Backend Contract Origin are deployed on Vercel;
that scoped operational proof does not satisfy I1 hosted candidate parity.

All dated RC10, Session-12, and earlier snapshots below are historical provenance unless
an explicitly current authority section says otherwise.

## Current DEV-ONLY L5 Filesystem Read — 2026-08-07

`filesystem-project-progress-read-v1` is a real but fixed read adapter. The Agent
accepts only `filesystem_project_progress` plus `canonical-project-progress`;
the MCP Gateway reads only the non-writable image-baked
`docs/project-progress.manifest.json` copy through one bounded descriptor. It
returns only overall percent, seven phase IDs/percents, seven layer IDs/percents,
`last_verified`, source SHA-256, and byte count. Caller paths, arbitrary
filenames/operations, label/status bulk, generic filesystem access, and unknown
response fields are rejected.

Authorization and completion MCP audits share trace/tool-request/run/session
identity. Agent API verifies both persisted rows and the content hash before its
own audit and before returning a result. Nginx and the Vercel ASGI MCP boundary
return `404` for the internal subtree. Low-level I/O, pre/post-audit, timeout,
trace, identity, symlink, writable-file, oversize, UTF-8/JSON, and schema failures
withhold the result. Focused proof passed: MCP `11` tests (one Windows symlink
skip), Agent `8/8`, static and live focused verifier, Docker `10/10`, and one
real Chromium click on `/tools`. Contract:
`docs/runtime-contracts/mcp-filesystem-project-progress-contract.md`.
`DEV-ONLY; hosted proof still blocked`. MCP Gateway remains `56%`, Overall
remains `89%`; no MCP write, provider call, secret output, deployment, release,
production right, or generic filesystem capability is claimed.

Historical RC10 guardrail: candidate `prod-candidate-2026-07-24-local-rc10` was a locally verified backend preparation artifact bound to committed and pushed source `2ae4c61aa876759abcaa83c36c0a3379206b91a4`; its six Docker image identities were local only and the planned GHCR tags were unpublished. Runtime-only and full-browser candidate verification artifacts were isolated. The verifier proved committed runtime-source parity, bound rollback to RC9 source `0cbe644c84812bbe72811516d58a70be8c27ffa5`, and reported `candidate_technical=true`, `runtime_source_parity=true`, `promotion_eligible=false`. Separately, the frontend and the stateless read-only Backend Contract Origin were deployed on Vercel, and the Cloudflare-native stateful candidate, hosted product acceptance, hosted 22-page action matrix, and hosted semantic Vectorize roundtrip were source/evidence-bound and verified. The canonical `external-gate-summary-v2` remained `blocked` only on GHCR digest proof; Branch Protection was read-only verified and `production_deploy_claim_allowed=false`. This did not prove Owner release approval, registry publication, full-platform production deployment, Phase-6 scale, or release promotion.

Historical pre-RC11 O5/source snapshot: the stateful Worker health contract reported
source `af61146e22d1a56e9d62232c159ea7b352405ba9` and archive SHA-256
`1d85f2cd6c948a43e0f79fb17d1f02706687d5857d80f4096780692d094b63fc`
after deployment version `757cf74c-7988-4790-ae03-ff51534ccea4`. Both source bindings
are Cloudflare `plain_text`; the earlier `wrangler secret put` instruction is superseded.
O5 evidence `.phase1-artifacts/live-vector-memory-search-proof.json` is bound by SHA-256
`18C3E1B54E547207FFD43B3E80FCAF5C0BCC31084A5392D53B5BAE35C205A831`,
proves a hosted semantic top result with zero lexical overlap, and does not reuse D1 credit.
Memory is `100%`; Overall remains `86%`. R2, paid-provider, secret, GHCR, release, and
Production claims remain false.

Historical Session-12 hosted-acceptance snapshot. Product report
`.codex/runs/CURRENT/master-goal/t5/product-acceptance-hosted-v5/report.json`
(SHA-256
`24C1A1C6FEEE18777EB9F534B66444A9E082B207ADFBF7005DBCD83424851F9F`)
proves one persisted/audited Cloudflare Workers AI Gateway build on source
`893d102020b7bcb267ebc01d3a77e94366e4dced`, with no direct provider
bypass, MCP write, mock, interception, console/page error, or secret output.
The exact hosted O2 action smoke passed `1/1`; then
`.codex/runs/CURRENT/master-goal/t5/22-page-actions-hosted-v2/report.json`
(SHA-256
`7F65488F60137CF8B1F4BA4361ACCAA923E302D216263A72483EF0B45EF98F8E`)
passed `22/22` routes, `29/29` families, and `161/161` members with zero
dead/unregistered actions and two permitted live Gateway build responses on
source `0bb1c326c01e988a153cf12cde36d2108a2ff8c5`.
`docs/runtime-state/cloudflare-native-hosted-current.json` binds both reports
and preserves R2 false/historical-only. Overall stays `86%`;
`MARKET_READY:false` until the named Owner/release gates close.

Historical RC10 scope covered the committed immutable Action/image pins, fail-closed pin verifier, prompt-persistence error redaction, and the fixed exact PostCSS `8.5.23` override. Its runtime-source parity was locally verified; DEV-ONLY; hosted proof still blocked.

Session 11 technology runtime binding supersedes the previous static
`/technology` stack claim. `TechnologyRuntimeView` reads exactly three
canonical read-only contracts (`GET /api/v1/clouds`,
`GET /api/v1/clouds/layers`, `GET /api/v1/clouds/deployment-preflight`),
schema-validates them together, cross-validates layer/provider membership,
keeps Fly as `historical_only` outside every layer mapping, and bounds the
response stream before parsing. `infrastructure/nginx/dev.conf` and
`cloud.conf` clear an inbound `X-Superbrain-Source`, hide any upstream value,
and stamp `agent-api-boundary`; `current_live_proof=true` requires that source
on all three responses, otherwise the UI shows `projection_not_current`
instead of a live status. Verified DEV-ONLY on 2026-07-27: technology verifier
static and runtime (`current_live_proof=true`), production build `exit 0`,
Chromium `6/6` including five fail-closed proofs, TypeScript `0`, ESLint `0`,
`scripts/verify-phase1.ps1` with gitleaks over `3726` files. `/technology`
moves STUB/MOCK → NUR CONTRACT; no percentage credit, hosted proof still
blocked.

Session 11 P3 four-role source analysis supersedes the original empty-source
and three-role Agent Research behavior. `agent-research-run-v3` fail-closes
unless all three fixed baked/read-only-mounted project-truth artifacts pass
layout, symlink, regular-file, 512 KiB, UTF-8, and sanitization guards before
the Gateway is called. It sends the same one-to-three lexical or baseline
extracts, with exact raw/sanitized/extract hashes, through four separate
Planner, Coder, Tester, and DevOps Gateway calls. `agent-research-four-role-v1`
binds exact canonical profile IDs without aliases, role, order, and source IDs
and caps each redacted role output at 2,000 Unicode code points. Every Gateway
response must carry the exact adapter contract, evidence ref, echoed trace ID,
and five real Boolean truth flags; missing or string-coerced values fail
closed. The UI strictly validates these truth fields and displays the four
roles, DevOps synthesis, and expandable inline sources.

This is explicitly source-grounded analysis only. Tool calls, filesystem
writes, test execution, deployment execution, autonomous software delivery,
external network, MCP writes, separate source-read audit persistence, and
file-wide secret certification are false. There is no source URL, arbitrary
path, or readback route. Overall remains 86%, P3 remains 44%, and
`MARKET_READY:false`; DEV-ONLY, hosted proof still blocked.

The current focused unit suite passes `23/23`; Agent API and LLM Gateway Python
compile, frontend TypeScript, focused ESLint, production build `21/21`,
progress-manifest verifier, full `scripts/verify-phase1.ps1`, npm audit, and
canonical gitleaks mirror over `3720` repository files all pass. Docker Desktop
remains unavailable, so there is no new runtime/browser/hosted proof. The
Session-10 22-page report remains historical green evidence and is not
exact-current-source-bound.

Session 11 also replaces `/organism/map`'s reused Phase-6 scene with a
dedicated same-origin, read-only `organism-topology-v1` client. It validates
strict contract identity, `source_kind=contract`, `live=false`, exact false
safety Booleans, bounded unique nodes and referentially closed edges, and caps
the response stream at 524,288 bytes before parsing. Only normalized display
fields survive validation. The map exposes real kind filtering, node
selection, directed incoming/outgoing adjacency, and a retry path that clears
rejected request state. Frontend and Agent API mirrors match exactly at 245
nodes and 494 edges, including resolved display labels, safety flags, edge
triples, and non-claims. The action runner requires an actual node-list delta
for filtering. Production build `21/21`, focused Chromium `4/4`, TypeScript,
ESLint, Python/PowerShell syntax, full Phase-1 verification, npm audit `0`, and
canonical gitleaks over `3723` files pass; final review reports `0 P1 / 0 P2`.
The map remains `NUR CONTRACT`: no live agent/tool/cloud telemetry is bound.
No progress credit: Overall `86%`, P3 `44%`, `MARKET_READY:false`; DEV-ONLY,
hosted proof still blocked.

Session 10 adds two current local acceptance proofs without creating a new
release candidate. `product-acceptance-3d-game-v1` produced persisted build
`8e51a068-8faa-4ff4-805a-accf91e1c145` through the Agent API and LLM Gateway
with Cloudflare Workers AI, no direct provider path, persisted audit, nonblank
WebGL, click pixel/DOM change, and identical artifact hash after reload.
Evidence: `.codex/runs/CURRENT/product-acceptance/report.json`, SHA-256
`1BC71C8D3C76C9CD68E67398A23FB573CA44E2F952643F5646BE6835C805AB7D`.
`workspace-action-matrix-v2` then verified 22/22 routes, 28/28 enabled
families, and 184/184 enabled actions: 183 direct effects plus one exact P0
proof, zero dead/unregistered/click-only/non-direct passes, and 2/2 allowed
live-provider build responses. There were no unexpected provider, console, or
page errors; the two observed HTTP 403 console entries were exactly correlated
to the intentionally blocked Games/Apps DELETE paths. Evidence:
`.codex/runs/CURRENT/22-page-actions/report.json`, SHA-256
`EBA64E765F9429A29D35092D0D2D357585812BBB5750B0122B6150811AB4BB3F`.
The original Session-10 `/agents` path was gateway-only
Planner→Researcher→Writer with empty sources instead of fabricated citations;
that historical behavior is superseded by the Session-11 bounded binding above.
The repaired `/tools` path exposes only internal read-only `memory_read` and
`task_router` execution with audit IDs. The strict 22-page primary verdict is
now 9 real, 10 contract-only, 3 stub/mock, and 0 missing/broken. Both proofs are
DEV-ONLY; hosted proof still blocked. Overall remains 86%;
`MARKET_READY:false`; RC10 remains active and is not requalified by this slice.
Final local gates passed: focused backend tests 13/13, TypeScript, focused
ESLint, repo-wide `verify-phase1.ps1` including gitleaks `no leaks found`,
`verify-phase1-runtime.ps1` ending in `phase1 runtime checks completed`, and
`verify-browser-contract.ps1` ending in `checks completed`. Docker was 10/10
healthy and the responsive proof was 22 routes x 2 viewports = 44 clicks.

P5 has an atomic Cloudflare-native gate rebase. The tracked authority is
`docs/runtime-state/external-gate-audit-v2.json` (`external-gate-audit-v2`,
SHA-256 `0678FB8C3AD2EAA4FCC2FEB7F9124846836340FCA297529A0BD3A750799E894F`)
and `docs/runtime-state/external-gate-summary.json` uses
`external-gate-summary-v2`. The latest full local run is
`.phase1-artifacts/external-gate-audit-v2-20260731-011557.json`. Both stay
`blocked` with `cloudflare_native_zero_card_hosted_runtime` verifier-open and
exactly `github_branch_protection_current_verify` plus
`ghcr_image_digest_verify` missing; Production remains false. The hosted
O2Core proof covers D1, Queue and SQLite Durable Object with source parity and
zero-card execution. The qualified active token proves O2Core 4/4 and O5 1/1;
R2 remains unbound and historical-only. The earlier GET-only 0/6 scope report
is retained as sanitized historical evidence, not current token truth. No
token output, percentage credit, registry push, or Production gate flip
occurred. RC10/Fly v1 is `historical_only`.

Session 9 selects Architecture A and removes Fly.io from new target work. The local
`cloudflare-native-runtime-candidate-v1` keeps LangGraph.js, labels D1 as custom persistence,
and adds SQLite Durable Object coordination, Queue dispatch and a private local R2 adapter.
Sixteen unit tests, Wrangler Preview dry-run and the real local create/queue/DO/R2
Put/Get/Delete flow pass, including effect-count `1`, replay/conflict, auth, oversize and
secret-sentinel guards. Evidence:
`.codex/runs/CURRENT/master-goal/t3/cloudflare-d1-local/report.json`, SHA-256
`FFB9693896C26B7831BE60E2A2DE323B7B1243F7DACDDE91727706BAF3E06F80`; tracked state:
`docs/runtime-state/cloudflare-native-local-candidate.json`. This earns zero percentage.
The new `brace-expansion` advisory is closed through fixed upstream `5.0.8` behind a
CommonJS compatibility adapter for the still-ESLint-9-compatible Next.js rule stack. Clean
`npm ci`, adapter smoke, lint, production build, npm audit `0`, full static verifier with
gitleaks, runtime verifier and the complete 22x2 browser verifier all pass serially.
O2' / `cloudflare_native_zero_card_hosted_runtime` stays closed. R2 free quota is not treated
as a zero-card activation proof because current setup documentation requires a subscription
checkout. Existing Fly external-gate files are RC10 historical provenance until an atomic
external-gate-audit-v2 rebase. That rebase is now complete; this Session-9 sentence is
historical context only. DEV-ONLY; hosted proof still blocked.

## Binding Truth

Primary project truth hierarchy:

- `docs/project-progress.manifest.json` is the canonical source for current progress percentages and current gate-closure status.
- `docs/verification-register.md` is the evidence register and may contain historical milestone notes, but it is not a separate progress authority.
- `PROJECT_STATE.md` and this handoff file are derived mirrors and must follow the manifest plus evidence register.
- `PROJECT_STATE.md`
- `PROJECT_ANCHOR.md`
- `docs/project-checkpoint-2026-04-30.json`
- `AGENTS.md`
- `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md`
- `docs/project-progress.manifest.json`
- `docs/verification-register.md`

Follow `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md` over older planning files when there is any conflict.

## Active Project Anchor

Anchor ID: `project-anchor-2026-04-30T00-49-26+02-00`

Use `PROJECT_ANCHOR.md` plus `docs/project-checkpoint-2026-04-30.json` as historical resume context. Their `70%` snapshot is provenance only; the canonical manifest and the Current Verified Progress section below now record `89%`, including the evidence-derived RC11 Phase-5 qualification. Continue evidence-based work without treating any historical candidate as current release parity.

## Current Verified Progress

Overall: `89%`

Horizontal:

- P0: `100%`
- P1: `100%`
- P2: `100%`
- P3: `44%`
- P4: `100%`
- P5: `89%`
- P6: `90%`

Vertical:

- Frontend / Next.js: `100%`
- Orchestrator / LangGraph: `100%`
- Agent Pool: `100%`
- LLM Gateway: `55%`
- MCP Gateway: `56%`
- Memory: `100%`
- Observability: `100%`

Older percentage lines below are historical proof points only. Current percentages must come from this section and `docs/project-progress.manifest.json`.

Latest fixed L5 read slice: commits `6978e3ab` and `553f6c48` implement and harden `filesystem-project-progress-read-v1`. The source is image-baked and non-writable, all caller-selected paths are absent, the response is allowlisted, pre/post MCP audits are identity-bound and read back by Agent API, and both Nginx and Vercel ASGI hide the internal endpoint. Focused unit, static, runtime, health, and real Chromium-click proof passed. No progress credit was assigned: MCP Gateway remains `56%`, Overall `89%`. DEV-ONLY; hosted proof still blocked.

Latest O4 revalidation: the source-bound DEV-ONLY proof on commit `1e15b308b59ecf4f541891587cddc71b21916f55` verifies the approved Agent-to-MCP filesystem write path inside the repository and active branch, with branch-protection readback, persisted pre/post audit, exact readback, and rollback on audit failure. Runtime, real Chromium browser, and promotion verification passed after the fixed L5 read slice. Both O4 capability gates remain verifier-opened and O4 is `resolved_verified`. Evidence: `.phase1-artifacts/o4-live-writes/proof.json`, SHA-256 `91D1653F14A0CD072EAA67A7D3BD8349E300A11E8ACFBB5E3A78FD28D2F2FFA0`. No new credit was assigned; Agent Pool remains `100%`, Overall `89%`, with no MCP/P6 double credit and no main, registry, provider, release, production, payment, or secret write.

Historical note: the following S1 UI-parity paragraph predates O4; its `69%` statement is superseded by the current `100%` value above.

Latest Agent-Pool UI/verifier parity slice: `/agents` is the canonical UI for the exact Runtime contracts `autonomous-agent-roster-v1`, `autonomous-master-plan-v1`, and `autonomous-coding-team-v1`. It displays the persisted 14-role roster, 7 phases, 7 layers, 5 operating-core roles, 3 dispatch endpoints, and one UUIDv4-bound 5-member coding-team dispatch with mappings and queues. Strict frontend parsers fail closed on contract/source/evidence/binding drift, and the three focused verifiers compare API data with the rendered SSR attributes. Frontend lint, 21/21 production build, `npm run verify`, `npm run verify:runtime`, and `npm run verify:browser` passed sequentially; Docker is `10/10 healthy`, responsive proof is `22x2=44`. The then-current PostCSS `8.5.12` override was later superseded by fixed `8.5.23`; current npm audit is zero. Runtime-log SHA-256: `B2C239B91BB9C41852A862EBEB3D8BAF12353E98330BA424A68A06EF8FE40541`; browser-log SHA-256: `CB720B156EB6248BB448181458CF569A1AA9D1A14013AE939275906BD5D644A5`. `autonomous_release_workflow_verified` proves parser plus PlanOnly contract only, not a workflow run, push, or release. Persisted roster does not mean Codex Desktop task persistence; local dispatch is not hosted rollout. Agent Pool remains `69%`, Overall `86%`; DEV-ONLY; hosted proof still blocked. No live provider call, live MCP write, model download, deploy, rollout, or secret output is claimed.

Latest RC11 finish audit: `docs/runtime-state/phase5-credit-itemization.json` and the RC11 readiness evidence derive `17/19 = 89%` from five independent passed chains. I1 `hosted_candidate_parity` and I5 `production_auth_identity` remain `OWNER-BLOCKED`. `MARKET_READY:false` remains correct; no gate was hand-set, no evidence slice was double-credited, and no GHCR publication, deployment, promotion, or production-auth claim was created.

Latest free-hardening slice: all `17` external GitHub Actions are pinned to `11` verified commit SHAs; `18` tracked external image occurrences are pinned to `9` registry-manifest digests, while exactly `6` variable internal GHCR service references remain release-selector controlled. `scripts/verify-supply-chain-pins.ps1` discovers every tracked `.github` YAML, Dockerfile, and root Compose file dynamically and is part of `npm run verify`. Manual review of `12` high/medium scanner candidates closed `11` as false positives and reclassified one prompt-persistence response as real `CWE-209`; that response is now generic and a sentinel regression test proves no internal exception reaches the client. Backend security tests are `20/20`; the newly published PostCSS path-traversal advisory was closed by upgrading the exact override to `8.5.23`, and npm audit is zero. The focused checks plus `npm run verify`, `npm run verify:runtime`, and `npm run verify:browser` passed serially on pushed source `2ae4c61aa876759abcaa83c36c0a3379206b91a4`; Docker is `10/10 healthy` and browser proof is `22x2=44`. Active RC10 is built from that clean archive: archive SHA-256 `ACDDF0E7BACD117E4796D618722A4DAEDE9ED84F5813045C2C58AFD727F1EBD1`, candidate report `F6DB74228773767857E301FE7A7E90C4B0D8FA5FA12E395C506EA6EE778C0078`, full verification `75B226536EDCDB8DB68E4B4B036E6B6BDF4BA73DBC0796F273F86C078725691B`. This historical slice predates the current O1-O5 plus resolved-O6 matrix; all percentages remain unchanged.

Latest Phase 3 credential-issuance repair: `phase3-auth-credential-issuance-fail-closed-v1` replaces the security-invalidated RC1 dry-run issuance path. One-time Redis OAuth state, exact `__Host-` binding, fixed GitHub exchange with positive numeric identity, minimal `read:user`, a base64url 256-bit signing-secret floor, active-registry refresh rotation, truthful logout, audit-before-cookie issuance, provider-payload shape checks, callback-cookie clearing, and query-safe access logging are implemented. Nineteen unit tests, a real-Redis concurrency probe, local HTTP negative paths, `npm run verify:runtime`, `npm run verify:browser`, and `npm run verify` passed sequentially. Evidence: `.codex/runs/CURRENT/phase3/auth-fail-closed/report.json`, SHA-256 `FB90E6D57FFBC6C646C583D6F5DD18F4EDB71D9E881B9B7090B3FFDD31FCADC1`. The same run resolved the new `sharp <0.35.0` advisory through exact override `0.35.3`; npm audit reports zero vulnerabilities. P3 remains `44%` and Overall `86%`; no duplicate credit. DEV-ONLY; hosted proof still blocked. Production identity and credential configuration remain Owner/review-gated.

Latest Phase 2 closure proof: `phase2-postgres-checkpoint-restart-recovery-v1` executed a completed deterministic LangGraph run, read its PostgreSQL checkpoint, force-recreated `agent-api` and `nginx`, and recovered the same terminal checkpoint by the original `thread_id`. The Compose healthcheck was hardened for the real aggregate health latency; both a focused recreation probe and the subsequent full `npm run verify:runtime` passed. Evidence: `.codex/runs/CURRENT/master-goal/phase2/checkpoint-restart-recovery-20260721.md`. This credits the seventh and final mandatory Phase-2 proof, raising Phase 2 `86% -> 100%` and Overall `84% -> 86%`. DEV-ONLY; no hosted stateful parity, live provider, live MCP write, registry, deploy, release, or production claim.

Latest hosted Agent Pool read-only proof: `hosted-agent-pool-readonly-v1` revalidates the current Cloudflare D1 runtime over unauthenticated HTTPS GET only. The contract, persisted run list, and concrete run readback agree on the exact four roles `planner`, `coder`, `tester`, and `devops`, four completed persisted task rows, D1 checkpointing, and false live-provider, live-MCP-write, deployment, and secret-output claims. Evidence: `.codex/runs/CURRENT/master-goal/t3/agent-pool-hosted-readonly/report-20260721-102425.json` (SHA-256 `1631A518300AA53A8CC0A302A1A0E6C82B64D3367C1644DCBF749454F1859C73`). Existing four-role, worker-status, and priority-queue markers were already credited; only the new current hosted D1 readback marker raises Agent Pool `68% -> 69%`. No token, mutation, new run, Redis worker scaling, live LLM, live MCP, release, or production claim.

Latest current hosted MCP read-only proof: `mcp-hosted-current-readonly-v1` binds the public Vercel Contract Origin to its recorded Production deployment and source snapshot, verifies blob parity for all seven deployed MCP source paths, and reads health, five dry-run contracts, exact dependency/tool pins, and the MCP audit contract over unauthenticated HTTPS GET only. Evidence: `.codex/runs/CURRENT/mcp-gateway/hosted-readonly-contract/report.json` (SHA-256 `67281BB2B9CE8A411D88954D7604D9205E13726644FDA21BA0DE5673A596D15C`). This credits only `mcp_current_hosted_readonly_contract_parity_verified`, raising MCP Gateway `55% -> 56%`; Overall remains `86%`. No token, MCP execution, audit write, provider write, stateful backend, release, or production claim.

Latest hosted LLM read-only proof: `cloudflare-llm-gateway-hosted-readonly-v1` binds the public Cloudflare Preview Worker to deployed source `67f41cecf38de109e762632ed971c9a7fdaff6ba` and a blob-identical current `services/cloudflare-llm-gateway` tree. Token-free HTTPS GET returned healthy AI/auth configuration and the exact two-model allowlist while `live_provider_calls=false`, `direct_provider_calls=false`, and `secret_output=false`. Evidence: `.codex/runs/CURRENT/llm-gateway/cloudflare-hosted-readonly/report.json` (SHA-256 `D9DE8F7C46309F1FDA1EED43D4C2F14A65D99A2D77D60B01AAC449A1CAB83D71`). Only `cloudflare_workers_ai_llm_gateway_preview_readonly_source_parity_verified` is credited, raising LLM Gateway `54% -> 55%`; Overall remains `86%`. No token, inference, provider write, Production Worker, release, or production claim.

Latest hosted Workbench repair: the reported `LLM Gateway HTTP 503` was reproduced on immutable Preview deployment `dpl_5myh9Wmi2RYtJtZH9Te5x18MqDzr`. Cloudflare Preview and Vercel gateway authentication/origin configuration were aligned without reading or reporting secret values, source `67f41cecf38de109e762632ed971c9a7fdaff6ba` was redeployed, and both the new Preview and the Production alias returned HTTP `200` from a real mini-build through Cloudflare Workers AI. Real Google Chrome then passed all 22 routes at desktop and mobile on both deployments (`44/44`, zero console, overflow, or overlay failures). Evidence: `.codex/runs/CURRENT/llm-gateway/frontend-build-503-fix/report.json` (SHA-256 `B66A02387CD5CCA631947DAC7E6A99BF9B1E0BC5A498F6828437018794F42F0A`). This is an operational repair only: the immutable failed URL remains historical, the frontend currently uses the Cloudflare Preview worker, and no full-platform production-readiness or release-promotion claim is made.

Latest local memory-safety proof: `memory-worker-secret-guard-v1` recursively inspects
working-memory text plus nested metadata keys and values before persistence. A generated
credential-shaped value located only under nested metadata was blocked without a memory row
or raw audit value; the Redis key was consumed, a sanitized `memory_consolidation_blocked`
audit was persisted, and safe nested metadata still consolidated. Evidence:
`.codex/runs/CURRENT/memory/worker-secret-guard/report.json`. Memory rises `72% -> 73%`;
Overall remains `84%`. DEV-ONLY; no live embedding, provider, MCP, deploy, or production claim.

Latest bounded frontend refresh: `frontend-hosted-current-proof-v1` verifies the current Vercel Production Alias against READY deployment `dpl_5uLu9a2BpEBb5BDPiuqRtyfkSFY1` and Vercel-attested Git source `67f41cecf38de109e762632ed971c9a7fdaff6ba`. That Git-integrated redeploy has no attested source-archive SHA-256, so none is claimed. Real Google Chrome `148.0.7778.96` opened all 22 routes at desktop and mobile for 44 clicks total; overflow failures, overlay collisions, visible not-found states, and console errors were zero. A 32-endpoint sweep returned HTTP 200 throughout, including all eight former HTTP-500 routes. READY/target, immutable host, Alias membership, agreeing Git SHA fields, and immutable/Alias content parity bind the result. Evidence is under `.codex/runs/CURRENT/master-goal/production/t1-67f41cec`; configuration and non-claims live in `docs/runtime-state/frontend-hosted-current.json`. Frontend remains `100%`; Overall remains `89%`. This was a read-only truth refresh for an already-active Alias, not a deploy, RC11 hosted parity, release-candidate promotion, or a full-platform production release.

Latest hosted backend boundary proof: `backend-hosted-current-proof-v1` binds Vercel Production deployment `dpl_AQaBJxdQwHLcQKid8xYXkNJ3wva2` explicitly to historical T1 source `21913f8c3ef13949ca962980c143e757ca87a7cc` and archive SHA-256 `314bd1d9c7830dc5ac9077398025fed4ab48041b31fefae491916e838d5f7080`. Authenticated read-only Vercel metadata proves READY state, target `production`, Alias assignment, and exact metadata. The immutable URL remains protected; public Alias reads prove the deployment snapshot at `overall=84`, `P4=100`, integrity `verified`, external gates `5/6 action_required`, summary `blocked`, only blocker `fly_cloud_stack`, MCP/LLM `healthy`, expected stateless Agent API `degraded`, and POST fail-closed with HTTP 503. Evidence is `.codex/runs/CURRENT/master-goal/production/t1-21913f8c/backend-verification.json`; configuration and non-claims live in `docs/runtime-state/backend-hosted-current.json`. This is an operational read-only Contract Origin, not the stateful Docker backend stack, release-candidate promotion, or a full-platform production release.

Latest Phase 5 boundary hardening: RC10 `prod-candidate-2026-07-24-local-rc10` rebuilt six images from the clean Git archive of pushed PostCSS-fixed source `2ae4c61aa876759abcaa83c36c0a3379206b91a4`. `scripts/verify-phase5-production-candidate-local.ps1` proves OCI/source identity, embedded hashes, Frontend `BUILD_ID` `K1RYRyr2WuLFjXFPVnOfu`, committed runtime-source parity, RC9 rollback identity, read-only methods, and a real Diagnostics Chromium click. `scripts/verify-current-release-candidate.ps1` distinguishes the source-bound Vercel read-only snapshot (`overall=84`) from current local manifest truth (`overall=86`) and reports `candidate_technical=true`, `runtime_source_parity=true`, `promotion_eligible=false`, canonical `blocked`. Evidence: `.codex/runs/CURRENT/master-goal/phase5/production-candidate-local` (Git archive SHA-256 `ACDDF0E7BACD117E4796D618722A4DAEDE9ED84F5813045C2C58AFD727F1EBD1`, candidate report SHA-256 `F6DB74228773767857E301FE7A7E90C4B0D8FA5FA12E395C506EA6EE778C0078`, verification SHA-256 `75B226536EDCDB8DB68E4B4B036E6B6BDF4BA73DBC0796F273F86C078725691B`). DEV-ONLY; hosted proof still blocked. No deployment, registry publication, percentage increase, or provider write is implied.

Latest local R0 truth proof: `r0-canonical-runtime-truth-v1` binds runtime gate claims to `docs/runtime-state/external-gate-summary.json`. After the token-free `20260720-191532` rebaseline, the DEV control plane reports External Gates `action_required` at `5/6` with the single blocker `fly_cloud_stack`, Deployment Preflight `action_required`, Completion and Go-live Readiness `blocked_external_gates`, and production claim `false`. Full `npm run verify`, `npm run verify:runtime`, and `npm run verify:browser` passed after the rebaseline; the browser proof covers all seven Phase-6 gates, the load-stable reference-design WebGL check, 22 pages, two viewports, 44 clicks, and zero overflow, overlay-collision, and console failures. Evidence: `.codex/runs/CURRENT/master-goal/r0-canonical-runtime-truth-20260719.md`, `.phase1-artifacts/external-gate-audit-20260720-191532.json`, `.phase1-artifacts/reference-design-browser-proof-latest.json`, and `.codex/runs/CURRENT/frontend/responsive-22/report.json`. No progress increase or production claim.

Latest T3 read-only cloud proof: Grafana `glc_` token metadata is now used only to select the validated region; `live_verified=true` requires a successful read against the fixed Grafana Cloud API. Cloudflare token verification, GitHub identity, and GHCR package-list reads also returned HTTP 200. `npm run verify:cloud-provider-live-read` and its integrated `npm run verify:runtime` invocation report `8/8` local providers and `7/7` local layers live verified in `.phase1-artifacts/cloud-provider-live-read-20260720-032243.json`. The owner-assisted audit `.phase1-artifacts/external-gate-audit-20260720-060043.json` remains blocked for `hosted_agent_api_contracts` and `vercel_backend_origin_health`, has `production_deploy_claim_allowed=false`, and is isolated as non-current candidate `docs/runtime-state/external-gate-summary.candidate-20260720-060043.json`; it did not supersede the canonical token-free summary. This is DEV-ONLY identity/inventory evidence, not telemetry ingestion or hosted backend proof. Observability remains `99%` and Overall remains `84%` because the configured Grafana stack endpoint returns HTTP 503.

Latest T4 frontend provider-boundary proof: the frontend no longer imports or calls Neon, Cloudflare Workers AI/D1/Vectorize, or the GitHub Store directly. Five retired provider modules were removed; mutation and persistence routes now cross only the configured Agent API, LLM Gateway, or MCP Gateway boundary and fail closed when unavailable. Read projections fall back honestly when hosted state is unavailable, and the Artifact Library effect dependency is stable. Lint, production build, `npm run verify`, `npm run verify:runtime`, and the exact-source `npm run verify:browser` passed. T1 subsequently promoted that source through a fully green Preview gate and repeated the hosted proof on Production. Evidence: `.codex/runs/CURRENT/master-goal/t4/frontend-provider-boundary/report.json` and `.codex/runs/CURRENT/master-goal/production/t1-21913f8c`. Overall remains `84%`; no live provider write, stateful hosted backend, release-candidate promotion, or percentage increase is claimed.

## Current Runtime

Local browser URL:

- `<local-control-plane-url>/`

Superbrain stream URL:

- `<local-control-plane-stream-url>`

Docker stack:

```powershell
docker compose -f docker-compose.dev.yml ps
```

Expected healthy services:

- `nginx`
- `agent-api`
- `frontend`
- `llm-gateway`
- `mcp-gateway`
- `agent-worker`
- `memory-worker`
- `postgres`
- `redis`

## Important Verified Commands

Run from the project root.

```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1
powershell -ExecutionPolicy Bypass -File scripts\verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost
powershell -ExecutionPolicy Bypass -File scripts\verify-hosted-staging.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost
powershell -ExecutionPolicy Bypass -File scripts\verify-external-gates.ps1
powershell -ExecutionPolicy Bypass -File scripts\verify-cloud-only-staging.ps1 -BaseUrl https://<hosted-staging-domain>
powershell -ExecutionPolicy Bypass -File scripts\verify-phase1-runtime.ps1
powershell -ExecutionPolicy Bypass -File scripts\verify-autopilot-mode.ps1 -AllowLocalhost
powershell -ExecutionPolicy Bypass -File scripts\verify-retired-hosted-boundary.ps1
py -3 scripts\verify_project_progress_manifest.py
```

Recent verification status: on 2026-06-11, the Platform UI Status Boundary Guard was added and passed `scripts\verify-platform-ui-status-boundary.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` with `product_surfaces=7` and `routes=6`, then passed through `npm run verify:browser`. It blocks project-status helpers, manifest snapshots, project progress endpoints, completion/gate/recovery wall markers, and go-live/external-gate audit markers from Home, Workbench, Games, Apps, Media, Docs-Output, and AppShell while keeping Evidence/Diagnostics/Organism/non-rendering wiring available. The Workspace Data Source Integrity Guard corrected stale `/api/v1/model-capabilities` refs to `/api/v1/models/capabilities`, added `GET /api/v1/files/local/contract`, and passed `scripts\verify-workspace-data-sources.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` with `api_refs=32`. It is now included in `npm run verify:browser` after the vertical-stack guard. The same session passed `py -3 -m py_compile services\agent-api\app\main.py`, `npm run lint --prefix apps/frontend`, `npm run build --prefix apps/frontend`, Docker DEV rebuild for frontend/agent-api/nginx, and `npm run verify:browser`. Earlier on 2026-06-11, the Organism Topology Integrity Guard passed `scripts\verify-organism-topology.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` with `151` nodes and `308` edges, then passed through `npm run verify:browser`; manifest validation and `git diff --check` also passed, with only line-ending warnings. The topology guard is part of `scripts\verify-browser-contract.ps1` and statically guarded by `scripts\verify-phase1.ps1`; `apps/frontend/lib/platform.ts` now mirrors Phase `P4` as `99%` instead of a stale `100%` snapshot. `scripts\verify-phase1.ps1` passed fully, including gitleaks over ~4.27 GB, and `npm run verify:external-gates` produced `.phase1-artifacts/external-gate-audit-20260615-121905.json` with the same external blockers. Earlier on 2026-06-10, the frontend runtime binding slice passed `npm run lint --prefix apps/frontend`, `npm run build --prefix apps/frontend`, focused `npx playwright test e2e/organism.spec.ts --project=chromium --grep "forwards run_id"`, full `npx playwright test e2e/organism.spec.ts --project=chromium` (`12 passed`), `scripts\verify-organism-runtime-events.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `npm run verify:browser`, `npm run verify:runtime`, `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`, `npm run verify:external-gates`, `py -3 scripts\verify_project_progress_manifest.py`, and `git diff --check`. `npm run verify` initially caught and blocked a missing exact no-token baseline phrase in this handoff; that mirror text was repaired. A later gitleaks block was traced to local `.claude` Secret/Session copies, redacted without printing secret values, and then gitleaks/Phase-1 verified clean. The Workbench budget-visibility slice passed lint, build, full Organism E2E (`13 passed`), Docker DEV frontend/nginx rebuild, `npm run verify:browser`, targeted Workbench HTTP proof, manifest validation, `git diff --check`, `scripts\verify-phase1.ps1`, and `npm run verify:external-gates`; `/workbench` hides `Metered Budget` unless a paid/metered option is selected or explicitly configured. The last external gate artifact is `.phase1-artifacts/external-gate-audit-20260615-121905.json`, blocked for `hosted_agent_api_contracts` and `vercel_backend_origin_health`; `canonical_gitleaks_scan` and `ghcr_image_digest_verify` are verified. GitLab, Hugging Face, and Grafana identity checks are fail-closed in this no-token baseline. Current hosted proof requires Vercel HTTPS `STAGING_BASE_URL` plus reachable Fly origins.

Current Master Goal external gate mirror: the tracked canonical audit `docs/runtime-state/external-gate-audit-v2.json` and `external-gate-summary-v2` are `blocked` with `production_deploy_claim_allowed=false`; the only active audit blocker is `ghcr_image_digest_verify`. Hosted contracts, Vercel origins, Branch Protection, Cloudflare O2Core, and the canonical secret scan are positive. RC10/Fly v1 and the owner-assisted `125413` candidate are `historical_only` and never current authority. Current verified progress is 86 percent.

Autopilot stream proof now runs through the active Agent API/Nginx stack at `<local-control-plane-stream-url>` and emits `status:init`, `status:llm`, `token`, and `done` with `autopilot-mode-stream-proof`.

## Latest Completed Proof

Fixed filesystem project-progress read guard:

- `services/mcp-gateway/app/main.py` reads only the fixed, image-baked manifest through one bounded descriptor and returns an exact allowlisted projection.
- `services/agent-api/app/main.py` accepts only the canonical tool/query pair, passes the outer trace, validates the bounded MCP response, reads both correlated MCP audits back, and persists its own audit before returning.
- `api/mcp.py`, `infrastructure/nginx/dev.conf`, and `infrastructure/nginx/cloud.conf` return `404` for the internal MCP subtree on public boundaries.
- `scripts/verify-mcp-filesystem-project-progress.ps1` is wired into static, runtime, and browser umbrella scripts; the frontend exposes the option only in exact DEV mode.
- Focused proof passed MCP `11` tests (one platform symlink skip), Agent `8/8`, Python compile, PowerShell parser, focused ESLint/TypeScript, compose validation, `10/10` health, the live focused verifier, and one real Chromium click.
- Localhost evidence is `DEV-ONLY; hosted proof still blocked`; no generic filesystem access, write, provider call, secret, deploy, release, production permission, or progress increase is claimed.

Live agent steering contract guard:

- `services/agent-api/app/main.py` keeps trace/role/project/provider-gate metadata server-owned, bounds caller metadata to 8192 bytes, and mirrors LLM Gateway safety plus `continuity_reset` on steering responses.
- Steering responses expose `trace_id`, `evidence_ref`, `llm_gateway_contract_version`, `llm_gateway_evidence_ref`, `live_provider_calls=false`, `model_downloads=false`, `audit_persisted=true`, and `secret_output=false` in the DEV-ONLY dry-run path.
- `scripts/verify-live-agent-steering-contract.ps1` checks source guards, runtime contract, LLM Gateway contract, reset, steering, Redis session state, audit trace visibility, compatibility route, and caller metadata spoof/provider-authorization rejection.
- The guard is wired into `scripts/verify-browser-contract.ps1` and statically guarded by `scripts/verify-phase1.ps1`; `docs/runtime-contracts/live-agent-steering-contract.md` documents the boundary.
- Current v2 slice is verified by Python compile, service-container unit tests, 10/10 healthy DEV containers, and the isolated runtime verifier; full serial truth suites remain separate gates.
- Localhost evidence is `DEV-ONLY`; no hosted proof, cloud mutation, deploy, release promotion, live provider call, live MCP write, secret use, or progress increase.

LLM responses adapter contract guard:

- `services/llm-gateway/app/main.py` exposes `GET /api/v1/responses/contract` with `contract_version=llm-responses-adapter-contract-v2`, protocol `openai-responses-sse-v1`, and evidence `llm_responses_adapter_contract_visible`.
- `POST /llm/v1/responses` returns a Responses-compatible payload with `output`, `output_text`, `trace_id`, `live_provider_calls=false`, `model_downloads=false`, and `audit_persisted=true` in the DEV-ONLY dry-run path.
- `services/agent-api/app/main.py` links the same contract from `GET /api/v1/live-agents/contract` through `GET /llm/api/v1/responses/contract` and keeps Agent API direct-provider calls closed.
- `scripts/verify-llm-responses-contract.ps1` checks non-stream compatibility, audit trace visibility, bounded instruction/previous-response continuity, exact SSE ordering/reconstruction, audit-before-emit policy, and typed/bounded negative cases.
- The guard is wired into `scripts/verify-browser-contract.ps1` and statically guarded by `scripts/verify-phase1.ps1`; `docs/runtime-contracts/llm-responses-adapter-contract.md` documents the boundary.
- Current v2 slice is verified by Python compile, 9/9 gateway unit tests, 26/26 Agent API unit tests, the focused runtime verifiers (traces `llm-responses-contract-6414d2cef5034562bccaee730feb964f` and `trace-b531e01f-bdab-4ddb-ab25-9a357aee9abe`), and 10/10 healthy DEV containers. The serial browser-contract, product-acceptance, and 22-page action components also produced verified DEV-ONLY reports; the 30-minute calling-tool timeout is not represented as a full `npm run verify:browser` exit-0 claim. After the L5 slice, O4 browser/runtime/promotion re-passed on source `1e15b308b59ecf4f541891587cddc71b21916f55` with combined SHA-256 `91D1653F14A0CD072EAA67A7D3BD8349E300A11E8ACFBB5E3A78FD28D2F2FFA0`.
- Localhost evidence is `DEV-ONLY`; no hosted proof, cloud mutation, deploy, release promotion, live provider call, live MCP write, secret use, or progress increase.

Platform UI status boundary guard:

- `scripts/verify-platform-ui-status-boundary.ps1` protects Home, Workbench, Games, Apps, Media, Docs-Output, and `AppShell.tsx` from direct project-status helpers, manifest imports, project-progress endpoints, completion/gate/recovery wall markers, and go-live/external audit markers.
- Evidence/Diagnostics/Organism and non-rendering wiring contracts remain allowed places for project progress and gate truth.
- The guard is wired into `scripts/verify-browser-contract.ps1` and statically guarded by `scripts/verify-phase1.ps1`.
- Verified by isolated boundary proof and full `npm run verify:browser`.
- Localhost evidence is `DEV-ONLY`; no hosted proof, cloud mutation, deploy, release promotion, live provider call, live MCP write, secret use, or progress increase.

Workspace data source integrity guard:

- `apps/frontend/lib/workspaceWiring.ts` and the Agent API mirror now use the real model capability route `GET /api/v1/models/capabilities` for Marketplace and Media.
- `GET /api/v1/files/local/contract` exists as `local-files-readonly-contract-v1`; it declares no host filesystem mount, no live filesystem reads, no writes, no secret output, and no MCP filesystem write enablement.
- `scripts/verify-workspace-data-sources.ps1` validates the 22-page wiring, vertical stack, organism topology, model capabilities, local files contract, source route markers, static assets/routes, and 32 API-like data-source refs.
- `scripts/verify-browser-contract.ps1` runs this guard after the vertical-stack proof; `scripts/verify-phase1.ps1` statically checks parser, stale route absence, and required Agent API markers.
- Verified by Python compile, frontend lint/build, Docker DEV rebuild, isolated data-source proof, and full `npm run verify:browser`.
- Localhost evidence is `DEV-ONLY`; no hosted proof, cloud mutation, deploy, release promotion, live provider call, live MCP write, secret use, or progress increase.

Organism topology integrity guard:

- `scripts/verify-organism-topology.ps1` validates `organism-topology-v1`, `organism-surface-v1`, `workspace-surface-wiring-v1`, and `workspace-vertical-stack-v1` together.
- Current normalized Frontend/Agent-API mirror proof reports `245` nodes and `494` edges, with exact UI-label parity and coverage for 22 workspace pages, 7 architecture layers, 10 brain regions, agents, tools, LLM models, skills, cloud providers, safety gates, data sources, and verifiers.
- Every topology edge must reference an existing node; every workspace page must have layer, brain-region, hub, data-source, and verifier edges. The client caps the response stream before parsing, normalizes display fields, and retries without caching a rejected request.
- The guard forbids active `Hetzner`, `GitKraken`, `Oracle`, secret output, write claims, and production deployment claims.
- `scripts/verify-browser-contract.ps1` runs the topology guard, and `scripts/verify-phase1.ps1` statically checks parser, route, contract, Agent API mirror, and the current manifest-aligned `P4=100` frontend progress mirror.
- Verified by exact mirror proof, production build `21/21`, focused Chromium `4/4`, full Phase-1 verification, manifest validation, and `git diff --check`.
- Localhost evidence is `DEV-ONLY`; no hosted proof, cloud mutation, deploy, release promotion, live provider call, live MCP write, secret use, or progress increase.

Workspace vertical stack contract:

- `apps/frontend/lib/workspaceVerticalStack.ts` derives `workspace-vertical-stack-v1` from the canonical 22-page wiring registry.
- `GET /api/v1/workspace/vertical-stack` exists in the frontend and is mirrored by Agent API with `workspace_vertical_stack_visible`, `page_count=22`, `expected_page_count=22`, and `layers_required=7`.
- Each page declares UI, API, data, verification, deploy, and safety stages. The contract keeps direct provider calls, default writes, secret output, live state, and production deploy claims closed.
- `scripts/verify-workspace-vertical-stack.ps1` validates the runtime payload against `/api/v1/workspace/wiring` and asserts Vercel/Fly/GHCR deploy mapping plus `hostedProofStatus=blocked_external_gates`.
- `scripts/verify-browser-contract.ps1` runs the runtime guard, and `scripts/verify-phase1.ps1` statically guards source, route, Agent API mirror, and verifier markers.
- `/files/local` now renders the read-only search affordance as a static `role=searchbox` element to avoid disabled-input hydration drift in the 22-page proof.
- Verified by frontend lint/build, Python compile, Docker DEV rebuild, isolated vertical-stack proof, isolated 22-page browser proof, and full `npm run verify:browser`.
- Localhost evidence is `DEV-ONLY`; no hosted proof, cloud mutation, deploy, release promotion, live provider call, live MCP write, secret use, or progress increase.

Workspace pages browser proof:

- `scripts/verify-workspace-pages-browser.ps1` and `scripts/verify-workspace-pages-browser.cjs` run a DEV-ONLY Playwright proof across all 22 canonical Workbench routes.
- The proof cross-checks `workspace-surface-wiring-v1` and `reference-design-conformance-v1`, then writes `.phase1-artifacts/workspace-pages-browser-proof-latest.json` plus 22 screenshots under `apps/frontend/e2e/__artifacts__/workspace-pages/`.
- Assertions cover unique route/page numbering, layer/brain-region/hub/data-source/verifier/event wiring, `.app-shell`, `.main`, `.topbar`, active rail navigation, visible page text, design tokens, bounded panel radius, hidden retired providers, hidden project-status/gate-matrix markers, and hidden unpaid `Metered Budget`.
- `apps/frontend/components/shell/AppShell.tsx` now marks parent and bottom rail routes correctly; `/files/local` activates the Files rail item.
- `apps/frontend/app/files/local/page.tsx` and `apps/frontend/app/styles.css` remove a local files hydration drift by replacing volatile inline disabled-input styling with stable classes.
- `scripts/verify-browser-contract.ps1` now runs the reference design browser proof before the longer 22-page proof and uses retry-safe temp file cleanup on Windows.
- `scripts/verify-reference-design-browser.cjs` now checks HTTP status with bounded transient retry and verifies the visible CSS-transformed `RUN BINDING` marker.
- Verified by frontend lint/build, Node syntax checks, PowerShell parser check, isolated reference browser proof, isolated 22-page browser proof, and full `npm run verify:browser`.
- Localhost evidence is `DEV-ONLY`; no hosted proof, pixel-perfect completion claim, cloud mutation, deploy, release promotion, live provider call, live MCP write, secret use, or progress increase.

Reference design browser proof:

- `scripts/verify-reference-design-browser.ps1` and `scripts/verify-reference-design-browser.cjs` run a DEV-ONLY Playwright proof against `/workbench`, `/organism`, and `GET /api/v1/design/reference-contract`.
- The proof writes `apps/frontend/e2e/__artifacts__/reference-design-workbench.png`, `apps/frontend/e2e/__artifacts__/reference-design-organism.png`, and `.phase1-artifacts/reference-design-browser-proof-latest.json`.
- Workbench assertions cover the industrial workbench shell, preview tabs for Game/App/Video/Docs, `Run Binding`, panel-radius bounds, design tokens, and absence of status-wall/gate-matrix/budget markers.
- Organism assertions cover canvas dimensions, WebGL, runtime feed `agent_api_redacted`, screenshot size, and PNG pixel variance (`uniqueColorBuckets`, `visiblePixels`, `accentPixels`).
- Agent API now mirrors `GET /api/v1/platform/verify`, because nginx routes `/api/*` to Agent API and the shell 7-layer pill must not depend on a frontend-only route in the proxied DEV path.
- `infrastructure/nginx/dev.conf` and `infrastructure/nginx/cloud.conf` forward Frontend WebSocket upgrades so client hydration and runtime fetches are stable through nginx.
- Verified by Python compile, Node syntax, PowerShell parser checks, Docker DEV rebuild, direct `GET /api/v1/platform/verify`, `scripts\verify-reference-design-browser.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `npm run verify:browser`, and `scripts\verify-phase1.ps1`.
- Localhost evidence is `DEV-ONLY`; no hosted proof, pixel-perfect completion claim, cloud mutation, deploy, release promotion, live provider call, live MCP write, secret use, or progress increase.

Reference design contract:

- `apps/frontend/lib/referenceDesign.ts` defines `reference-design-conformance-v1` with industrial workbench design rules, reference asset inventory, 22 canonical pages, organism event kinds, and explicit non-claims.
- `GET /api/v1/design/reference-contract` exists in the frontend and as an Agent API mirror in `services/agent-api/app/main.py`.
- `scripts/verify-reference-design-contract.ps1` checks real `docs/reference` assets: at least 4 root images, 15 current-design screenshots, and 1 motion reference video, plus frontend route, Agent API mirror, and browser-contract wiring.
- `scripts/verify-browser-contract.ps1` validates the runtime endpoint; `scripts/verify-phase1.ps1` runs the static guard.
- Verified by Python compile, frontend lint/build, Docker DEV frontend/Agent API/Nginx rebuild, `scripts\verify-reference-design-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, and `npm run verify:browser`.
- Localhost evidence is `DEV-ONLY`; no hosted proof, no pixel-perfect completion claim, no cloud mutation, deploy, release promotion, live provider call, live MCP write, secret use, or progress increase.

Go-live runbook guard:

- `docs/SUPERBRAIN_GO_LIVE.md` is now an owner-gated, read-only runbook. It does not override the project AGENTS.md and cannot be used as authority for cloud mutation, deployment, registry publication, live provider activation, MCP writes, or production claims.
- It mirrors the current external truth: `docs/runtime-state/external-gate-audit-v2.json`, `external-gate-summary-v2`, `GET /api/v1/clouds/go-live-readiness`, and `cloudflare_native_zero_card_hosted_runtime`.
- It mirrors the current frontend version baseline from `apps/frontend/package.json` without claiming latest versions or performing upgrades.
- `scripts/verify-superbrain-go-live-runbook.ps1` statically guards the runbook for required owner-gated markers, forbidden unsafe override text, package-version drift, retired hosted URLs, and secret-like patterns.
- Wired into `scripts/verify-phase1.ps1`; targeted proof passed with `scripts\verify-superbrain-go-live-runbook.ps1`.
- No cloud mutation, deploy, release promotion, live provider call, live MCP write, secret use, hosted proof, or progress increase.

Go-live readiness contract:

- `services/agent-api/app/main.py` exposes `GET /api/v1/clouds/go-live-readiness` and `/contract`.
- The runtime payload composes Project Completion, External Gates, Cloud Layer Readiness, Deployment Preflight, 22-page Workspace Wiring, and the owner activation plan without executing cloud commands.
- `scripts/verify-go-live-readiness.ps1` validates the runtime contract, contract endpoint, required owner inputs, PlanOnly owner activation, 22 pages, 7 layers, and the latest external gate audit artifact.
- `scripts/verify-browser-contract.ps1` now calls the readiness verifier; `scripts/verify-phase1.ps1` statically guards the verifier and its parser.
- Verified on 2026-06-10 by Python compile, PowerShell parser checks, Docker DEV Agent API/Nginx rebuild, direct readiness verifier, DEV-ONLY browser contract, and Phase-1 verifier.
- Status remains `blocked_external_gates`. No cloud mutation, deploy, release promotion, live provider call, live MCP write, secret use, hosted proof, or progress increase.

Workbench budget visibility guard:

- `apps/frontend/lib/paidCapabilities.ts` no longer treats raw provider key environment variables as a Workbench budget-UI enablement signal.
- `Metered Budget` and `paid/metered Capability` remain hidden on plain `/workbench`, and become visible through explicit paid selection such as `/workbench?billing=paid` or explicit paid capability/gateway configuration.
- `apps/frontend/e2e/organism.spec.ts` includes the regression proof for both hidden and visible states.
- Docker DEV frontend/nginx were rebuilt so the running local control plane matches the code path.
- Verified on 2026-06-10 by lint, build, full Organism E2E (`13 passed`), DEV-ONLY browser contract, targeted Workbench HTTP proof, manifest validation, `git diff --check`, Phase-1 verifier, and external-gate audit `.phase1-artifacts/external-gate-audit-20260615-121905.json` (`blocked`).
- No cloud mutation, deploy, release promotion, live provider call, live MCP write, secret use, hosted proof, or progress increase.

Organism UI runtime run binding:

- `apps/frontend/components/organism/OrganismView.tsx` now reads a sanitized `run_id` from `/organism?run_id=...` or `/organism/replay?run_id=...` and forwards it to both `/api/v1/organism/events?run_id=...` and `/api/v1/organism/replay?run_id=...`.
- The runtime feed panel exposes the active binding through `data-run-id` and a visible `run_id=...` marker while preserving the redacted, read-only projection guard.
- `apps/frontend/e2e/organism.spec.ts` now includes a request-intercept proof that both outgoing Runtime API calls carry the same `run_id`, then verifies `agent_api_redacted`, `data-live=true`, replay frames, and redaction markers.
- Verified on 2026-06-10 by lint, build, focused Playwright run-id proof, full Organism E2E (`12 passed`), DEV-ONLY `scripts\verify-organism-runtime-events.ps1`, `npm run verify:browser`, `npm run verify:runtime`, `scripts\verify-phase1.ps1`, `npm run verify:external-gates`, manifest validation, and `git diff --check`.
- No cloud mutation, deploy, release promotion, live provider call, live MCP write, secret use, hosted proof, or progress increase.

Organism runtime event projection:

- `services/agent-api/app/main.py` now turns local Phase-2 runtime audit records into redacted Organism events and replay frames for `GET /api/v1/organism/events?run_id=...` and `GET /api/v1/organism/replay?run_id=...`.
- The projection reads only `audit_log.event_type`, `severity`, and `created_at`, maps them to event kind, hub, route, run state, and brain regions, and intentionally omits raw `details`, `user_id`, `session_id`, prompts, and secrets.
- `scripts/verify-organism-runtime-events.ps1` proves `source=agent-api`, `source_kind=agent_api_redacted`, `live=true`, `replay_available=true`, events/frames present, `secret_output=false`, `writes=false`, and no raw audit-detail fields. It is wired into both `scripts/verify-browser-contract.ps1` and `scripts/verify-phase1-runtime.ps1` after the existing Phase-2 runtime run-status checks.
- Verified by focused compile/parser checks, Docker DEV rebuild, `scripts\verify-organism-runtime-events.ps1`, `npm run verify:browser`, `npm run verify:runtime`, `scripts\verify-phase1.ps1`, `py -3 scripts\verify_project_progress_manifest.py`, `git diff --check`, and `npm run verify:external-gates`.
- No cloud mutation, deploy, release promotion, live provider call, live MCP write, secret use, hosted proof, or progress increase.

22-page organism wiring contract:

- `apps/frontend/lib/workspaceWiring.ts` defines `workspace-surface-wiring-v1` for the canonical 22 Workbench pages with page id, brain region, capability hub, data sources, verifier refs, event kinds, and explicit non-claims `live=false`, `writes=false`, and `secretOutput=false`.
- `GET /api/v1/workspace/wiring` is exposed by the frontend and mirrored by the Agent API in `services/agent-api/app/main.py`, returning `workspace_surface_wiring_visible` and `page_count=22`.
- `GET /api/v1/organism/contract` and `GET /api/v1/organism/topology` now include `workspace_page_count=22`, page nodes, and edges for `page_to_brain_region`, `page_to_capability_hub`, `page_to_data_source`, and `page_to_verifier`.
- Canonical page ids/layers were aligned in the backend mirror, including `/technology` as `stack` and the `/organism*` routes as the current 22-page taxonomy requires.
- Verified by `py -3 -m py_compile services\agent-api\app\main.py`, `npm run lint --prefix apps/frontend`, `npm run build --prefix apps/frontend`, `npm run test:e2e --prefix apps/frontend` (`10 passed`), `scripts\verify-workspace-pages-layer-map.ps1`, `npm run verify:runtime`, `npm run verify:browser`, `scripts\verify-phase1.ps1`, `py -3 scripts\verify_project_progress_manifest.py`, `git diff --check`, and `npm run verify:external-gates`.
- No cloud mutation, deploy, release promotion, live provider call, live MCP write, secret use, or progress increase.

Previous latest completed proof:

Frontend local E2E rewrite/hydration recovery:

- `apps/frontend/next.config.mjs` no longer emits default Fly rewrites during plain local `next start`; defaults require `STAGING_REWRITES_ENABLED`, while explicit safe origins and explicit `FLY_APP_*` names remain supported.
- `scripts/verify-frontend-cloud-rewrites.ps1` now asserts the plain-local no-rewrite contract, unsafe-origin rejection, cloud-mode default Fly fallback, explicit HTTPS origins, stale hosted fallback bypass, and custom Fly app names.
- `apps/frontend/components/organism/CortexLive.tsx` and `apps/frontend/components/organism/OrganismView.tsx` defer WebGL/GPU detection until client mount, eliminating the React hydration mismatch on `/organism`.
- `scripts/verify-browser-contract.ps1`, `scripts/verify-phase1-runtime.ps1`, and `scripts/verify-phase1.ps1` now assert current completion/preflight gate lists without stale single-item assumptions: `fly_api_token` plus `vercel_backend_origins`, and `fly_cloud_stack` plus `hosted_backend_origins`.
- Verified by `scripts/verify-frontend-cloud-rewrites.ps1`, `scripts/verify-workspace-pages-layer-map.ps1`, `npm run lint --prefix apps/frontend`, `npm run build --prefix apps/frontend`, `npm run test:e2e --prefix apps/frontend` (`9 passed`), `npm run verify:browser`, `npm run verify:runtime`, `scripts\verify-phase1.ps1`, and `npm run verify:external-gates`.
- No cloud mutation, deploy, release promotion, live provider call, live MCP write, secret use, or progress increase.

22-page / 7-layer registry guard:

- Added `scripts/verify-workspace-pages-layer-map.ps1`.
- It verifies exactly 22 `WORKSPACE_PAGES`, real app route files for each canonical page, no return of retired alias routes, and explicit supplemental treatment for `/`, `/organism/live`, and `/responsive`.
- It maps page layer codes to the binding `docs/system-architecture.md` taxonomy: Frontend, Orchestration, Agent Pool, LLM Gateway, Tool MCP, Memory, Observability.
- Wired into `scripts/verify-phase1.ps1`. No product UI status wall, cloud mutation, deploy, or progress increase.

Phase-5 Browser Manifest Retire Guard:

- `docs/project-progress.manifest.json` no longer carries the retired `sslip.io`/Hetzner browser bridge, browser proof, post-rollback browser proof, final browser E2E proof, full sweep, or truth-mirror browser tokens as active candidate evidence.
- `scripts/verify-retired-hosted-boundary.ps1` now verifies those manifest tokens together with the RC1 candidate and browser proof artifacts.
- Verified by `py -3 scripts\verify_project_progress_manifest.py` and `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-retired-hosted-boundary.ps1`.
- No progress increase, cloud mutation, production deployment, registry push, or live-provider claim.

Cloud-Gate-Realignment 2026-06-08:

- Active cloud path is Vercel/Fly.io/GHCR/Grafana Cloud. Hetzner, GitKraken, and Oracle are no longer active defaults.
- Hosted verifier defaults now fail closed without a real HTTPS, non-localhost `STAGING_BASE_URL`.
- Fly live budget verification is routed through `scripts/check_fly_infra_budget.py` and requires `FLY_API_TOKEN`; no provider evidence is faked.
- Direct Fly MCP/LLM origins are now probed at `/api/v1/health`; path-prefixed reverse-proxy origins such as `/mcp` and `/llm` remain supported.
- Separate Fly origin configs are prepared for `cloud-superbrain-agent-api`, `cloud-superbrain-mcp-gateway`, and `cloud-superbrain-llm-gateway`; `scripts/verify-phase1.ps1` verifies them offline.
- `scripts/verify-all-gates-with-tokens.ps1` now resolves origin precedence as explicit non-placeholder origin, then Fly app/default derivation, then hosted rewrite fallback; a no-secret Temp proof confirmed old hosted rewrites are not used when Fly app names are available.
- `apps/frontend/next.config.mjs` now applies the same precedence to Vercel rewrites, and `scripts/verify-frontend-cloud-rewrites.ps1` proves the rewrite matrix without secrets or deploy.
- `scripts/verify-external-gates.ps1` now bounds HTTP and native process probes; timeout proofs fail closed with `status=timeout`, `claim_allowed=false`, and a non-secret artifact instead of hanging.
- Frontend dependency baseline: Next.js `16.2.7`, React `19.2.7`, Three `0.184.0`, `@types/node` `25.9.2`, ESLint `9.39.4` as the newest peer-compatible ESLint line for the current Next plugin stack.
- Result: local proof green; hosted/external proof still blocked until cloud environment variables and Fly token are available. No production rollout, registry push, live provider activation, or secret exposure occurred.

Phase 5 Integration Smoke Plan Rerun:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-smoke-plan-rerun.md` records one fresh candidate-scoped hosted smoke-plan rerun on the active truth `overall=70`, `phase_5=67`, with hosted root/API/MCP/LLM `200`, hosted progress/integrity, fail-closed completion, external gates `verified`, external-gates mirror visibility, and deployment-preflight `verified`.
- `scripts/verify-phase5-integration-smoke-plan-rerun.ps1` re-checks that artifact, the active candidate link, the hosted HTML title `Cloud Superbrain`, the hosted API surface set, and the current manifest-backed hosted truth.
- The rerun preserves `IMAGE_TAG=staging` as the current selector and `IMAGE_TAG=ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5` as the immutable rollback selector.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-staging-parity-blocked.md` and `scripts/verify-phase5-staging-parity-blocked.ps1` now keep the resulting digest-parity blocker explicit: the mutable `:staging` tag set currently does not equal the immutable candidate SHA tag set, so hosted parity is not claimed.
- Historically verified against the now-retired `sslip.io`/Hetzner surface. Current hosted proof must be rerun against a real Vercel HTTPS `STAGING_BASE_URL`; the current external-gate artifact remains blocked until then.
- Progress change: Overall remains `70%`; Phase 5 rises to `67%`. This is not a rollout or production deployment claim.

Previous latest completed proof:

Phase 5 Executed Rollback + Post-Rollback Requalification + Release Readiness Rerun:

- `.phase1-artifacts/phase5-executed-rollback-rerun-20260507.md` records one fresh rerun of the existing executed rollback lane on the active hosted truth `overall=70`, `phase_5=66`, confirms the immutable selector `ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`, and re-checks the restored hosted selector `IMAGE_TAG=staging`.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-requalification-rerun.md` records one fresh rerun of the post-rollback requalification lane on the same hosted truth and reconfirms hosted root/API/MCP/LLM `200`, fail-closed completion, and external gates `verified`.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-release-readiness-rerun.md` records one fresh candidate-scoped release-readiness rerun against the same hosted truth, active runbooks, active candidate links, and the active browser-evidence chain.
- `.phase1-artifacts/phase5-owner-decision-no-release-20260505.md`, `.phase1-artifacts/phase5-rollback-readiness-20260505.md`, and `.phase1-artifacts/phase5-release-baseline-refresh-20260507.md` were corrected in the same batch so the active candidate no longer depends on stale `50/8` and `67/40` truth fragments.
- Verified by `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-executed-rollback-rerun.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-post-rollback-requalification-rerun.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-release-readiness-rerun.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-release-baseline-refresh.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`, and Hetzner re-sync.
- Progress change: Overall remains `70%`; Phase 5 rises to `66%`. This is not a rollout or production deployment claim.

Previous latest completed proof:

Phase 5 Final Browser E2E + Full Verifier Sweep + Truth Mirror Rebaseline:

- The old `.phase1-artifacts/phase5-final-browser-e2e-recheck-20260507.md`, `.phase1-artifacts/phase5-full-verifier-sweep-20260507.md`, and `.phase1-artifacts/phase5-truth-mirror-rebaseline-20260507.md` references are historical `sslip.io`/Hetzner provenance only in the current Vercel/Fly boundary.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md` and `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-browser-revalidation.md` are `superseded` and no longer current candidate evidence.
- Current browser evidence requires Vercel HTTPS `STAGING_BASE_URL` plus reachable Fly origins. The latest external-gate artifact remains blocked until those origins are live.

Previous latest completed proof:

Phase 5 Browser Claims Fail-Closed Repair:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md` and `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-browser-revalidation.md` are now explicitly historical `superseded` artifacts, not current candidate evidence.
- `scripts/verify-phase5-browser-proof.ps1` and `scripts/verify-phase5-post-rollback-browser-revalidation.ps1` now verify the fail-closed blocked state instead of carrying non-reproducible current browser claims.
- `scripts/verify-phase5-candidate.ps1` and `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` no longer link the two browser artifacts as active candidate evidence; the current blocker is documented directly in the candidate artifact.
- Hard blocker evidence is explicit: `node_repl` + `iab` fails with `failed to start codex app-server ... (os error 3)`, `chrome_devtools` fails with `Target.setDiscoverTargets): Target closed`, and Playwright closes with launcher `exit code 13`.
- Progress change: Overall remains `69%`; Phase 5 is corrected fail-closed to `57%`. This removes two stale current claims and still does not create a rollout or production deployment claim.

Previous latest completed proof:

Phase 5 Post-Rollback Provenance + Incident + Rollback Drill Rerun:

- `scripts/verify-phase5-post-rollback-provenance-revalidation.ps1` now rebinds the legacy post-rollback provenance artifact to current hosted `overall=69`, hosted `phase_5=57`, workflow run `25392582005`, immutable GHCR SHA `ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`, and hosted root/API/MCP/LLM health.
- `scripts/verify-phase5-incident-drill.ps1` now validates deployment preflight through the runtime endpoint `GET /api/v1/clouds/deployment-preflight`, binds the drill to current hosted `overall=69`, hosted `phase_5=57`, and replaces the obsolete rollback selector `5464c922...` with the current immutable SHA `ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`.
- `scripts/verify-phase5-rollback-drill.ps1` now validates the rollback drill against GitHub Actions run `25392582005` and the immutable rollback SHA `ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5` through the GitHub API instead of the stale old run/SHA pair.
- `scripts/verify-phase5-candidate.ps1` now derives the expected rollback-drill SHA and workflow run directly from the candidate artifact, so the candidate verifier no longer conserves the obsolete rollback pin.
- `scripts/verify-phase5-integration-plan.ps1` and `docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-plan.md` were updated in the same batch so the legacy integration plan also uses runtime deployment preflight and the current immutable rollback selector.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-post-rollback-provenance-revalidation.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-incident-drill.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-rollback-drill.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-integration-plan.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall remains `69%`; Phase 5 had previously risen to `59%`, but current manifest-backed truth is now `57%` after the browser claims were removed fail-closed. This is still not a rollout or production deployment.

Phase 5 Risk + Observability + Smoke Rerun:

- `scripts/verify-phase5-risk-review.ps1` now reads expected hosted progress from the canonical manifest instead of the stale `53/18` pin and re-checks `owner_decision=no-release`, hosted progress/integrity, fail-closed completion truth, external gates, and hosted audit/escalation visibility.
- `scripts/verify-phase5-observability-review.ps1` now reads expected hosted progress from the canonical manifest instead of the stale `52/11` pin and re-checks hosted health, progress, integrity, metrics, audit feed, escalation feed, and external gates.
- `scripts/verify-phase5-executed-smoke.ps1` now binds the smoke proof to current hosted `overall=69`, hosted `phase_4=100`, hosted `phase_5=56` and fixes the real contract-vs-runtime check by validating deployment preflight through `GET /api/v1/clouds/deployment-preflight` instead of the contract endpoint.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-risk-review.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-observability-review.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-executed-smoke.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall rises to `69%`; Phase 5 rises to `56%`. This is still not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Project Progress + Layer Progress Contract Runtime Parity:

- Historical note: `scripts/verify-phase4-project-progress-contract-runtime-hosted.ps1` previously bound `GET /api/v1/project/progress/contract` to the retired hosted runtime; this is no longer current hosted gate truth.
- `scripts/verify-phase4-project-progress-layers-contract-runtime-hosted.ps1` now binds `GET /api/v1/project/progress/layers/contract` directly to the new hosted layer-only projection at `GET /api/v1/project/progress/layers` and proves the seven layer ids, label parity, count parity, overall-percent parity, and runtime alignment with the canonical progress feed.
- `.phase1-artifacts/phase4-project-progress-contract-runtime-hosted-proof-20260507.md` and `.phase1-artifacts/phase4-project-progress-layers-contract-runtime-hosted-proof-20260507.md` record the successful hosted proofs.
- Historical verified commands used the retired `sslip.io` URL. Current verification must use Vercel HTTPS staging plus Fly origins.
- Progress change: Overall remains `63%`; Phase 4 rises to `86%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Task Assignment + Agent LLM Streaming Contract Runtime Parity:

- `scripts/verify-phase4-task-assignment-contract-runtime-hosted.ps1` now binds `GET /api/v1/tasks/assignment-contract` to a fresh hosted internal task over `POST /api/v1/internal/tasks` and proves the same task through `GET /api/v1/internal/tasks/{task_id}`, `GET /api/v1/tasks/recent`, `GET /api/v1/agents/status`, and `GET /api/v1/metrics`.
- Historical note: `scripts/verify-phase4-agent-llm-streaming-contract-runtime-hosted.ps1` previously bound the LLM SSE contract on the retired hosted runtime; current Vercel/Fly hosted proof is still blocked.
- `.phase1-artifacts/phase4-task-assignment-contract-runtime-hosted-proof-20260507.md` and `.phase1-artifacts/phase4-agent-llm-streaming-contract-runtime-hosted-proof-20260507.md` record the successful hosted proofs.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-task-assignment-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-agent-llm-streaming-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall remains `62%`; Phase 4 rises to `82%`; Agent Pool rises to `68%`; LLM Gateway rises to `54%`. This is a hosted integration proof, not a rollout or production deployment.

Phase 4 Hosted Health Contract Runtime Parity:

- `services/agent-api/app/main.py` now exposes `GET /api/v1/health/contract` via `health_contract_payload()`, so the public health runtime surface now has its own visible contract instead of being covered only indirectly through fallback, budget, and external-gate proofs.
- the new visible health contract declares `contract_version=health-surface-v1`, the required top-level runtime fields, the required service keys, the embedded budget and infra-budget field sets, the embedded external-gates field set, and the currently supported health and gate statuses.
- `scripts/verify-phase4-health-contract-runtime-hosted.ps1` previously proved the contract against the retired Hetzner runtime; current hosted proof must be rerun on Vercel/Fly.
- `.phase1-artifacts/phase4-health-contract-runtime-hosted-proof-20260507.md` records the successful hosted proof.
- Historical verified commands used a retired staging deploy path and are no longer an active runbook. Current activation uses `scripts\owner-cloud-gate-activation.ps1`.
- Progress change: Overall remains `61%`; Phase 4 rises to `72%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Costs Contract Runtime Parity:

- `services/agent-api/app/main.py` now exposes `GET /api/v1/costs/contract` via `costs_contract_payload()`, so the public costs runtime surface now has its own visible contract instead of being covered only indirectly through budget, metrics, and export proofs.
- the new visible costs contract declares `contract_version=costs-surface-v1`, the required top-level runtime fields, the required `breakdown[]` fields, the supported budget levels, and the runtime budget limit binding.
- `scripts/verify-phase4-costs-contract-runtime-hosted.ps1` previously proved the contract on the retired Hetzner runtime; current Vercel/Fly hosted proof is still blocked.
- `.phase1-artifacts/phase4-costs-contract-runtime-hosted-proof-20260507.md` records the successful hosted proof.
- Historical verified commands used a retired staging deploy path and are no longer an active runbook. Current activation uses `scripts\owner-cloud-gate-activation.ps1`.
- Progress change: Overall remains `61%`; Phase 4 rises to `71%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Budget Contracts Runtime Parity:

- `services/agent-api/app/main.py` now exposes `GET /api/v1/budget/contract` via `budget_contract_payload()` and `GET /api/v1/infra/budget/contract` via `infra_budget_contract_payload()`, so both public budget surfaces now have their own visible runtime contracts instead of being covered only indirectly through metrics and older budget guard proofs.
- the new visible budget contracts declare `contract_version=budget-surface-v1` and `contract_version=infra-budget-surface-v1`, their required top-level runtime fields, supported levels, supported infra sources, and the required hosted `items[]` fields for the infra budget surface.
- `scripts/verify-phase4-budget-contracts-runtime-hosted.ps1` previously proved both hosted contracts on the retired Hetzner runtime; `source=hetzner_api_readonly` is historical only.
- `.phase1-artifacts/phase4-budget-contracts-runtime-hosted-proof-20260506.md` records the successful hosted proof.
- Historical verified commands used a retired staging deploy path and are no longer an active runbook. Current activation uses `scripts\owner-cloud-gate-activation.ps1`.
- Progress change: Overall rises to `61%`; Phase 4 rises to `70%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted MCP Audit Feed Contract Runtime Parity:

- `services/agent-api/app/main.py` now exposes `GET /api/v1/audit/mcp/contract` via `mcp_audit_feed_contract_payload()`, so the public MCP audit feed has its own visible contract instead of being covered only indirectly through the generic audit feed and MCP safe-envelope proofs.
- the new visible MCP-audit contract declares `contract_version=mcp-audit-feed-v1`, the top-level event fields, the required `mcp_tool_executed` detail fields, and the supported statuses `success|blocked|timeout|degraded`.
- `scripts/verify-phase4-mcp-audit-feed-contract-runtime-hosted.ps1` previously proved the contract on the retired Hetzner runtime; current Vercel/Fly hosted proof is still blocked.
- `scripts/deploy-to-staging.ps1` was hardened in the same slice: remote hot-mount source directories are now reset before recursive copy so stale nested `app/app` trees cannot shadow newer runtime code on the host.
- `.phase1-artifacts/phase4-mcp-audit-feed-contract-runtime-hosted-proof-20260506.md` records the successful hosted proof.
- Verified commands: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-mcp-audit-feed-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall remains `60%`; Phase 4 rises to `68%`; MCP Gateway rises to `55%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Session History Contract Runtime Parity:

- `services/agent-api/app/main.py` now exposes `GET /api/v1/sessions/history/contract` via `session_history_contract_payload()`, so the public session-history runtime surface has its own visible contract instead of being covered only indirectly through stream/history proofs.
- `scripts/verify-phase4-session-history-contract-runtime-hosted.ps1` proves the hosted session-history contract against the real runtime by creating one real hosted prompt session through `POST /api/v1/prompt`, waiting for completion, then reading `GET /api/v1/sessions/history/contract`, `GET /api/v1/sessions/{session_id}/history`, `GET /api/v1/sessions/recent`, `GET /api/v1/tasks/recent`, `GET /api/v1/agent-activity/recent`, and `GET /api/v1/audit/recent`.
- the proof confirms that the dedicated session-history contract and the real hosted session-history feed stay aligned on top-level sections, session fields, task fields, audit-event fields, and request/trace/correlation/audit-feed visibility.
- `.phase1-artifacts/phase4-session-history-contract-runtime-hosted-proof-20260506.md` records the successful hosted proof for session-history-contract runtime parity.
- Verified commands: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-session-history-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall remains `59%`; Phase 4 rises to `57%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Recent Sessions Contract Runtime Parity:

- `services/agent-api/app/main.py` now exposes `GET /api/v1/sessions/recent/contract` via `recent_sessions_contract_payload()`, so the public recent-sessions runtime surface has its own visible contract instead of being covered only indirectly through session-stream, failure-history, and cross-surface runtime proofs.
- `scripts/verify-phase4-recent-sessions-contract-runtime-hosted.ps1` proves the hosted recent-sessions contract against the real runtime by creating one real hosted prompt session through `POST /api/v1/prompt`, waiting for completion, then reading `GET /api/v1/sessions/recent/contract`, `GET /api/v1/sessions/recent`, `GET /api/v1/sessions/{session_id}/history`, `GET /api/v1/tasks/recent`, `GET /api/v1/agent-activity/recent`, and `GET /api/v1/audit/recent`.
- the proof confirms that the dedicated recent-sessions contract and the real hosted recent-sessions feed stay aligned on top-level session fields, supported status coverage, latest-task failure metadata, and request/trace/correlation/audit-feed visibility.
- `.phase1-artifacts/phase4-recent-sessions-contract-runtime-hosted-proof-20260506.md` records the successful hosted proof for recent-sessions-contract runtime parity.
- Verified commands: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-recent-sessions-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall rises to `59%`; Phase 4 rises to `56%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Recent Tasks Contract Runtime Parity:

- `services/agent-api/app/main.py` now exposes `GET /api/v1/tasks/recent/contract` via `recent_tasks_contract_payload()`, so the public recent-tasks runtime surface has its own visible contract instead of being covered only indirectly through worker-priority and cross-surface runtime proofs.
- the same runtime patch also closes a real correlation gap: `POST /api/v1/internal/tasks` now writes trace/request/correlation metadata into `agent_sessions`, and `GET /api/v1/tasks/recent` now falls back to session projection when fresh audit correlation for the task itself is not available yet.
- `scripts/verify-phase4-recent-tasks-contract-runtime-hosted.ps1` proves the hosted recent-tasks contract against the real runtime by creating one real hosted `planner` task through `POST /api/v1/internal/tasks`, waiting for completion, then reading `GET /api/v1/tasks/recent/contract`, `GET /api/v1/tasks/recent`, `GET /api/v1/internal/tasks/{task_id}`, and `GET /api/v1/audit/recent`.
- the proof confirms that the dedicated recent-tasks contract and the real hosted recent-tasks feed stay aligned on top-level task fields, queue fields, status coverage, trace visibility, and task policy metadata.
- `.phase1-artifacts/phase4-recent-tasks-contract-runtime-hosted-proof-20260506.md` records the successful hosted proof for recent-tasks-contract runtime parity.
- Verified commands: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-recent-tasks-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall remains `58%`; Phase 4 rises to `55%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Escalation Contract Runtime Parity:

- `services/agent-api/app/main.py` now exposes `GET /api/v1/escalations/contract` via `escalation_contract_payload()`, so the public escalation runtime surface has its own visible contract instead of being covered only indirectly through request and audit parity.
- `scripts/verify-phase4-escalation-contract-runtime-hosted.ps1` proves the hosted escalation contract against the real runtime by seeding one escalated `coder` path with shared `request_id`, `trace_id`, `correlation_evidence_ref=request_id_audit_correlation`, and `audit_feed_evidence_ref=request_id_audit_feed_visible`, then reading `GET /api/v1/escalations/contract`, `GET /api/v1/escalations/recent`, and `GET /api/v1/audit/recent`.
- the proof confirms that the dedicated escalation contract and the real hosted escalation feed stay aligned on top-level fields plus request/trace/correlation/audit-feed evidence.
- `.phase1-artifacts/phase4-escalation-contract-runtime-hosted-proof-20260506.md` records the successful hosted proof for escalation-contract runtime parity.
- Verified commands: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-escalation-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall remains `58%`; Phase 4 rises to `54%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Request Contract Negative-State Parity:

- `services/agent-api/app/main.py` now extends the request contract registry with explicit `supported_statuses`, so each public runtime surface declares whether it carries `escalated`, `abandoned_after_queue_drain`, or both negative worker end states.
- `scripts/verify-phase4-request-contract-negative-state-parity-hosted.ps1` proves the hosted request contract against the real runtime by seeding one escalated `coder` path and one `abandoned_after_queue_drain` `tester` path with shared `request_id`, `trace_id`, `correlation_evidence_ref=request_id_audit_correlation`, and `audit_feed_evidence_ref=request_id_audit_feed_visible`, then reading `GET /api/v1/request/contract`.
- the proof re-checks `/api/v1/agents/status`, `/api/v1/agent-activity/recent`, `/api/v1/tasks/recent`, `/api/v1/sessions/recent`, `/api/v1/sessions/{session_id}/history`, `/api/v1/audit/recent`, and `/api/v1/escalations/recent` on the live Hetzner staging stack and confirms the declared `supported_statuses` plus the registered request/trace/correlation/audit-feed fields stay aligned on the real runtime surfaces.
- `.phase1-artifacts/phase4-request-contract-negative-state-parity-hosted-proof-20260506.md` records the successful hosted proof for request-contract negative-state parity.
- Verified commands: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-request-contract-negative-state-parity-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall remains `58%`; Phase 4 rises to `53%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Request Contract Runtime Parity:

- `scripts/verify-phase4-request-contract-runtime-parity-hosted.ps1` proves the hosted request contract against the real runtime by seeding one escalated `coder` path with shared `request_id`, `trace_id`, `correlation_evidence_ref=request_id_audit_correlation`, and `audit_feed_evidence_ref=request_id_audit_feed_visible`, then reading `GET /api/v1/request/contract` and using its `public_surface_registry` as the binding source of field names.
- the proof re-checks `/api/v1/agents/status`, `/api/v1/agent-activity/recent`, `/api/v1/tasks/recent`, `/api/v1/sessions/recent`, `/api/v1/sessions/{session_id}/history`, `/api/v1/audit/recent`, and `/api/v1/escalations/recent` on the live Hetzner staging stack and confirms the registered request/trace/correlation/audit-feed fields are present and value-aligned on the real runtime surfaces.
- `.phase1-artifacts/phase4-request-contract-runtime-parity-hosted-proof-20260506.md` records the successful hosted proof for request-contract-to-runtime parity.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-request-contract-runtime-parity-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`
- Progress change: Overall remains `58%`; Phase 4 rises to `52%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Request Contract Surface Registry Parity:

- `services/agent-api/app/main.py` now extends `request_id_contract_payload()` with a visible `public_surface_registry` that enumerates the public runtime surfaces carrying top-level request, trace, correlation, and audit-feed evidence fields.
- `scripts/verify-phase4-request-contract-surface-registry-hosted.ps1` proves the hosted request contract surface end to end by checking `GET /api/v1/request/contract` on the live Hetzner staging stack and confirming that all seven public runtime surfaces are explicitly registered with their request/trace/correlation/audit-feed fields.
- `.phase1-artifacts/phase4-request-contract-surface-registry-hosted-proof-20260506.md` records the successful hosted proof for request-contract surface-registry parity.
- Verified commands: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-request-contract-surface-registry-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`
- Progress change: Overall remains `58%`; Phase 4 rises to `51%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Dual-Path Audit Feed Parity:

- `scripts/verify-phase4-dual-path-audit-feed-parity-hosted.ps1` proves the hosted public audit-feed parity surface end to end by seeding one escalated `coder` path and one `abandoned_after_queue_drain` `tester` path with a shared `trace_id`, shared `request_id`, `correlation_evidence_ref=request_id_audit_correlation`, and `audit_feed_evidence_ref=request_id_audit_feed_visible`, then re-checking `GET /api/v1/agents/status`, `GET /api/v1/agent-activity/recent`, `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent`, `GET /api/v1/sessions/{session_id}/history`, and `GET /api/v1/audit/recent` for both paths plus `GET /api/v1/escalations/recent` for the escalated path.
- the proof confirms that both negative worker paths now keep top-level request-/trace-correlation and `audit_feed_evidence_ref` aligned across all relevant hosted public surfaces.
- `.phase1-artifacts/phase4-dual-path-audit-feed-parity-hosted-proof-20260506.md` records the successful hosted proof for dual-path audit-feed parity.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-dual-path-audit-feed-parity-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`
- Progress change: Overall remains `58%`; Phase 4 rises to `50%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Audit Feed Evidence Cross-Surface Parity:

- `scripts/verify-phase4-audit-feed-evidence-cross-surface-hosted.ps1` proves the hosted public audit-feed evidence surface end to end by seeding one escalated `coder` path with a shared `trace_id`, shared `request_id`, `correlation_evidence_ref=request_id_audit_correlation`, and `audit_feed_evidence_ref=request_id_audit_feed_visible`, then re-checking `GET /api/v1/escalations/recent`, `GET /api/v1/agents/status`, `GET /api/v1/agent-activity/recent`, `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent`, `GET /api/v1/sessions/{session_id}/history`, and `GET /api/v1/audit/recent`.
- the proof confirms that top-level request-/trace-correlation and `audit_feed_evidence_ref` now stay aligned across all seven hosted public surfaces for the escalated worker path.
- `.phase1-artifacts/phase4-audit-feed-evidence-cross-surface-hosted-proof-20260506.md` records the successful hosted proof for audit-feed-evidence cross-surface parity.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-audit-feed-evidence-cross-surface-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`
- Progress change: Overall rises to `58%`; Phase 4 rises to `49%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Escalation Request Correlation Parity:

- `services/agent-api/app/main.py` now projects top-level request-/trace-correlation onto `GET /api/v1/escalations/recent` via `request_id`, `trace_id`, `correlation_evidence_ref`, and `audit_feed_evidence_ref`.
- `scripts/verify-phase4-escalation-request-correlation-hosted.ps1` proves the hosted public escalation surface end to end by seeding one escalated `coder` path with a shared `trace_id`, shared `request_id`, and explicit `correlation_evidence_ref=request_id_audit_correlation`, then re-checking `GET /api/v1/escalations/recent`, `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent`, `GET /api/v1/sessions/{session_id}/history`, and `GET /api/v1/audit/recent`.
- the proof confirms that top-level request-/trace-correlation now stays aligned on the hosted escalation surface with the already correlated task/session/audit surfaces for the escalated worker path.
- `.phase1-artifacts/phase4-escalation-request-correlation-hosted-proof-20260506.md` records the successful hosted proof for escalation request correlation parity.
- Verified commands: `py -3 -m py_compile services/agent-api/app/main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-escalation-request-correlation-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall remains `57%`; Phase 4 rises to `48%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Agent Status Request Correlation Parity:

- `services/agent-api/app/main.py` now projects top-level request-/trace-correlation onto `GET /api/v1/agents/status` via `latest_trace_id`, `latest_request_id`, `latest_correlation_evidence_ref`, and `latest_audit_feed_evidence_ref`.
- `scripts/verify-phase4-agent-status-request-correlation-hosted.ps1` proves the hosted public agent-status surface end to end by seeding one escalated `coder` path and one `abandoned_after_queue_drain` `tester` path with a shared `trace_id`, shared `request_id`, and explicit `correlation_evidence_ref=request_id_audit_correlation`, then re-checking `GET /api/v1/agents/status`, `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent`, `GET /api/v1/sessions/{session_id}/history`, and `GET /api/v1/audit/recent`.
- the proof confirms that top-level request-/trace-correlation now stays aligned on the hosted agent-status surface with the already correlated task/session/audit surfaces for both negative worker paths.
- `.phase1-artifacts/phase4-agent-status-request-correlation-hosted-proof-20260506.md` records the successful hosted proof for agent-status request correlation parity.
- Verified commands: `py -3 -m py_compile services/agent-api/app/main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-agent-status-request-correlation-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall remains `57%`; Phase 4 rises to `47%`; Agent Pool rises to `66%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Request Correlation Cross-Surface Parity:

- `services/agent-api/app/main.py` now projects top-level `trace_id`, `request_id`, and `correlation_evidence_ref` from the hosted audit trail onto `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent`, `GET /api/v1/sessions/{session_id}/history`, and `GET /api/v1/agent-activity/recent`.
- `scripts/verify-phase4-request-correlation-cross-surface-hosted.ps1` proves the hosted public correlation surfaces end to end by seeding one escalated `coder` path and one `abandoned_after_queue_drain` `tester` path with a shared `trace_id`, shared `request_id`, and explicit `correlation_evidence_ref=request_id_audit_correlation`, then re-checking `GET /api/v1/agent-activity/recent?trace_id=...`, `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent`, `GET /api/v1/sessions/{session_id}/history`, and `GET /api/v1/audit/recent`.
- the proof confirms that top-level `trace_id`, `request_id`, and `correlation_evidence_ref` stay aligned across all five hosted public surfaces for both negative worker paths.
- `.phase1-artifacts/phase4-request-correlation-cross-surface-hosted-proof-20260506.md` records the successful hosted proof for cross-surface request correlation parity.
- Verified commands: `py -3 -m py_compile services/agent-api/app/main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-request-correlation-cross-surface-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Progress change: Overall remains `57%`; Phase 4 rises to `46%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Agent Activity Filter Parity:

- `scripts/verify-phase4-agent-activity-filter-parity-hosted.ps1` now proves the hosted public filter surface end to end by seeding one escalated `coder` path and one `abandoned_after_queue_drain` `tester` path with a shared `trace_id`, then re-checking `GET /api/v1/agent-activity/recent?trace_id=...` plus the narrower `agent_type`, `event_type`, and `severity` combinations for each path, and finally mirroring the results against `GET /api/v1/audit/recent`.
- the proof confirms that the filtered agent-activity feed isolates exactly the intended failure event and keeps `task_id`, `trace_id`, and retry metadata aligned with the public audit feed.
- `.phase1-artifacts/phase4-agent-activity-filter-parity-hosted-proof-20260506.md` records the successful hosted proof for filter parity on the public agent-activity surface.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-agent-activity-filter-parity-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `57%`; Phase 4 rises to `45%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Trace + Request Correlation Parity:

- `scripts/verify-phase4-trace-request-correlation-hosted.ps1` now proves the hosted public correlation surfaces end to end by seeding one escalated `coder` path and one `abandoned_after_queue_drain` `tester` path with a shared `trace_id`, a shared `request_id`, and explicit `correlation_evidence_ref=request_id_audit_correlation`, then re-checking `GET /api/v1/agent-activity/recent?trace_id=...`, `GET /api/v1/audit/recent`, `GET /api/v1/sessions/{session_id}/history`, and `GET /api/v1/request/contract` for the same ids and evidence refs.
- the proof confirms that `trace_id`, `request_id`, `request_id_audit_correlation`, and `request_id_audit_feed_visible` stay aligned between the hosted agent-activity feed, hosted audit feed, and hosted session-history audit events for both negative worker paths.
- `.phase1-artifacts/phase4-trace-request-correlation-hosted-proof-20260506.md` records the successful hosted proof for trace/request correlation parity.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-trace-request-correlation-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `57%`; Phase 4 rises to `44%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Failure Audit + Escalation Parity:

- `scripts/verify-phase4-failure-audit-escalation-parity-hosted.ps1` now proves the hosted public audit and escalation surfaces end to end by seeding one escalated `coder` path and one `abandoned_after_queue_drain` `tester` path on the real Hetzner staging stack, then re-checking `GET /api/v1/audit/recent`, `GET /api/v1/escalations/recent`, and `GET /api/v1/sessions/{session_id}/history` for the same ids and failure fields.
- the verifier was corrected to the real feed contracts: both feeds expose `events`, `trace_id` on the escalation feed lives inside `details`, and `escalations/recent` intentionally includes the escalated path rather than the queue-drain abandonment path.
- `.phase1-artifacts/phase4-failure-audit-escalation-hosted-proof-20260506.md` records the successful hosted proof for audit/escalation/history parity of the negative worker end states.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-failure-audit-escalation-parity-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `57%`; Phase 4 rises to `43%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Agent Status Cross-Surface Parity:

- `scripts/verify-phase4-agent-status-cross-surface-hosted.ps1` now proves the hosted public agent-status surface end to end by seeding one escalated `coder` path and one `abandoned_after_queue_drain` `tester` path on the real Hetzner staging stack, then re-checking `GET /api/v1/agents/status`, `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent`, and `GET /api/v1/sessions/{session_id}/history` for the same ids and failure fields.
- no runtime code change was required for this slice; the proof closes the hosted parity gap between the already-existing public surfaces.
- `.phase1-artifacts/phase4-agent-status-cross-surface-hosted-proof-20260506.md` records the successful hosted proof for cross-surface parity of `escalated` and `abandoned_after_queue_drain` from the `agents/status` perspective.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-agent-status-cross-surface-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall rises to `57%`; Phase 4 rises to `42%`; Agent Pool rises to `65%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Failure Cross-Surface Parity:

- `scripts/verify-phase4-failure-cross-surface-hosted.ps1` now proves the hosted public failure surface end to end by seeding one escalated `coder` path and one `abandoned_after_queue_drain` `tester` path on the real Hetzner staging stack, then re-checking `GET /api/v1/agent-activity/recent`, `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent`, and `GET /api/v1/sessions/{session_id}/history` for the same ids and failure fields.
- the verifier itself had a real seed-parser defect and now parses only the final remote JSON line before building the hosted `trace_id` filter URL; no runtime surface change was required for this slice.
- `.phase1-artifacts/phase4-failure-cross-surface-hosted-proof-20260505.md` records the successful hosted proof for cross-surface parity of `escalated` and `abandoned_after_queue_drain`.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-failure-cross-surface-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `56%`; Phase 4 rises to `41%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Agent Activity Contract Parity:

- `services/agent-api/app/main.py` now declares `task_id`, `task_status`, `retry_count`, `max_retries`, and `error` in `agent_activity_contract_payload()`, and adds explicit contract markers `failure_surface_visible` plus `agent_activity_failure_surface_visible`.
- `scripts/verify-phase4-agent-activity-contract-hosted.ps1` proves the hosted public contract/runtime surface end to end by checking `GET /api/v1/agent-activity/contract`, seeding one escalated `coder` audit path and one `abandoned_after_queue_drain` `tester` audit path on the real Hetzner staging stack, then re-checking `GET /api/v1/agent-activity/recent?trace_id=...`.
- `.phase1-artifacts/phase4-agent-activity-contract-hosted-proof-20260505.md` records the successful hosted proof for public contract/runtime parity of the surfaced failure fields on the same task ids.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-agent-activity-contract-hosted.ps1`, `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `56%`; Phase 4 rises to `40%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Worker Failure / Stale Queue Parity:

- `scripts/verify-phase4-worker-failure-parity-hosted.ps1` now proves the hosted worker failure path end to end by seeding real Hetzner Redis/Postgres state for one escalating task with a missing session, one stale queued rehydrate path with a completed audit, and one stale queued abandon path without queue membership; it then re-checks `GET /api/v1/internal/tasks/{task_id}`, `GET /api/v1/tasks/recent`, `GET /api/v1/audit/recent`, `GET /api/v1/escalations/recent`, `GET /api/v1/metrics`, and `GET /api/v1/health`.
- `.phase1-artifacts/phase4-worker-failure-parity-hosted-proof-20260505.md` records the successful hosted proof for `task_retry`, `task_failed`, `task_escalated`, `task_status_rehydrated_from_audit`, and `task_abandoned_after_queue_drain` parity on the real staging stack.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-worker-failure-parity-hosted.ps1`, `py -3 -m py_compile services\agent-api\app\main.py`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall rises to `56%`; Phase 4 rises to `35%`; Agent Pool rises to `63%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Orchestrator Stream / Checkpoint Replay Parity:

## Previous Latest Completed Proof

Phase 4 Hosted Session History / SSE Replay Parity:

- `scripts/verify-phase4-session-stream-history-hosted.ps1` now proves the hosted session history and stream path end to end through `POST /api/v1/prompt`, `GET /api/v1/sessions/{session_id}/history`, `GET /api/v1/session/{session_id}/stream`, replay against the same stream with `Last-Event-ID: 0`, `GET /api/v1/sessions/recent`, and `GET /api/v1/audit/recent`.
- `.phase1-artifacts/phase4-session-stream-history-hosted-proof-20260505.md` records the successful hosted proof for session visibility, session history, live SSE, replay SSE, and audit parity.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-session-stream-history-hosted.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `55%`; Phase 4 rises to `33%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 4 Hosted Session / Memory Worker Runtime Parity:

- `scripts/verify-phase4-session-memory-parity-hosted.ps1` now proves the hosted session and memory-worker runtime path end to end through `POST /api/v1/prompt`, `GET /api/v1/sessions/{session_id}/history`, `GET /api/v1/sessions/recent`, a real SSH-seeded hosted `memory:working:*` key plus `memory-worker --once`, `GET /api/v1/memory/search`, `GET /api/v1/memory/consolidation/recent`, and `GET /api/v1/metrics`.
- `.phase1-artifacts/phase4-session-memory-parity-hosted-proof-20260505.md` records the successful hosted proof for session visibility, session history, deterministic worker completion, Redis-to-Postgres memory consolidation, public memory search, consolidation audit, and metrics parity.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-session-memory-parity-hosted.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `55%`; Phase 4 rises to `32%`; Memory rises to `71%`. This is a hosted integration proof, not a rollout or production deployment.
## Previous Latest Completed Proof

Phase 4 Hosted Worker / Priority Queue Runtime Parity:

- `scripts/verify-phase4-worker-priority-runtime-hosted.ps1` now proves the hosted worker runtime path end to end through `GET /api/v1/tasks/assignment-contract`, `POST /api/v1/internal/tasks`, `GET /api/v1/internal/tasks/{task_id}`, `GET /api/v1/tasks/recent`, `GET /api/v1/agents/status`, `GET /api/v1/sessions/recent`, `GET /api/v1/metrics`, and `GET /api/v1/audit/recent`.
- `services/agent-api/app/main.py` now initializes `agent_sessions` before internal task enqueue and writes `latest_task_id/latest_task_type` metadata for the hosted internal-task path; this fixes the real `ForeignKeyViolation`/`status=escalated` bug previously triggered by hosted worker proof tasks.
- `.phase1-artifacts/phase4-worker-priority-queue-hosted-proof-20260505.md` records the successful hosted proof for high/mid/low task priorities, worker completion, session visibility, audit visibility, and metrics parity.
- Verified commands: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-worker-priority-runtime-hosted.ps1`
- Progress change: Overall remains `55%`; Phase 4 rises to `31%`; Agent Pool rises to `62%`. This is a hosted integration proof, not a rollout or production deployment.

## Previous Latest Completed Proof

Phase 5 Post-Rollback Provenance + Completion Gate Freeze:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-provenance-revalidation.md` now binds the current production-candidate to a fresh post-rollback provenance revalidation across GitHub Actions run `25392582005`, immutable GHCR SHA tags for all six services, multi-arch `amd64/arm64` availability, and hosted root/API/MCP/LLM health at `overall=55`, `phase5=28`.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-completion-gate-freeze.md` now binds the same candidate to the still fail-closed completion boundary after rollback/restore: external gates remain `verified`, `blocked_release_gates=[]`, but `can_set_all_to_100=false` and `owner_decision=no-release` remain hard true.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now links both new post-rollback provenance and completion-gate-freeze artifacts directly beside the existing rollback/requalification evidence.
- `scripts/verify-phase5-post-rollback-provenance-revalidation.ps1` and `scripts/verify-phase5-post-rollback-completion-gate-freeze.ps1` verify the new artifacts fail-closed against live GitHub workflow truth, live GHCR manifests, and current hosted truth.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-post-rollback-provenance-revalidation.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-post-rollback-completion-gate-freeze.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `55%`; Phase 5 rises to `28%`. These are post-rollback release-readiness proofs, not a rollout or production deployment.

## Previous Latest Completed Proof

Historical, now superseded browser section - Phase 5 Post-Rollback Observability + Browser Revalidation:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-observability-revalidation.md` now binds the current production-candidate to a fresh hosted observability revalidation after rollback/restore, checking health, progress, integrity, metrics, audit, escalations, and external gates at `overall=55`, `phase5=26`.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-browser-revalidation.md` is now a historical `superseded` artifact only; fresh browser reruns are currently blocked and are not counted in current candidate evidence.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now links only the post-rollback observability artifact as active current evidence; the browser revalidation artifact is excluded from the current candidate truth.
- `scripts/verify-phase5-post-rollback-observability-revalidation.ps1` remains on current hosted truth, while `scripts/verify-phase5-post-rollback-browser-revalidation.ps1` now verifies the fail-closed blocked historical state.
- Blocker evidence is explicit: `failed to start codex app-server ... (os error 3)`, `Target.setDiscoverTargets): Target closed`, and Playwright launcher `exit code 13`.
- The progress line in this historical section is retained only as provenance and is not the current manifest-backed truth.

## Previous Completed Proof

Phase 5 Executed Candidate Risk Review:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-risk-review.md` now binds the current production-candidate to an executed risk and open-questions review.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now links the risk review directly as candidate evidence.
- `scripts/verify-phase5-risk-review.ps1` verifies the risk-review artifact fail-closed against the required decision state, hosted progress/integrity truth, completion guard, external-gate truth, and hosted audit/escalation visibility.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-risk-review.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `53%`; Phase 5 rises to `18%`. This is a release-readiness risk-review evidence step, not a rollout or production deployment.

## Previous Completed Proof

Phase 5 Executed Candidate Handoff Packet:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-handoff-packet.md` now binds the current production-candidate to an executed release-communication and operator-handoff packet.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now links the handoff packet directly as candidate evidence.
- `scripts/verify-phase5-handoff-packet.ps1` verifies the packet artifact fail-closed against the required packet files, current handoff/state/register mirrors, and hosted progress/integrity truth.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-handoff-packet.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `53%`; Phase 5 rises to `17%`. This is a release-readiness communication evidence step, not a rollout or production deployment.

## Previous Completed Proof

Phase 5 Executed Candidate Memory Recovery Drill:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-memory-recovery-drill.md` now binds the current production-candidate to an executed memory-recovery decision drill without any live restore claim.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now links the memory-recovery drill directly as candidate evidence.
- `scripts/verify-phase5-memory-recovery-drill.ps1` verifies the drill artifact fail-closed against the runbook links, explicit no-restore decision, hosted progress/integrity, memory embedding consistency, purge contract, purge-job status, consolidation feed, and audit feed.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-memory-recovery-drill.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `53%`; Phase 5 rises to `16%`. This is a release-readiness operations evidence step, not a rollout or production deployment.

## Previous Completed Proof

Phase 5 Executed Candidate Provider Failover Drill:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-provider-failover-drill.md` now binds the current production-candidate to an executed provider-failover decision drill without any live external provider switch.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now links the provider-failover drill directly as candidate evidence.
- `scripts/verify-phase5-provider-failover-drill.ps1` verifies the drill artifact fail-closed against the runbook links, explicit no-switch decision, hosted LLM/API health, hosted progress/integrity, external gates, deployment preflight, and audit feed.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-provider-failover-drill.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `53%`; Phase 5 rises to `15%`. This is a release-readiness operations evidence step, not a rollout or production deployment.

## Previous Completed Proof

Phase 5 Executed Candidate Secret Rotation Drill:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-secret-rotation-drill.md` now binds the current production-candidate to an executed candidate-scoped secret-rotation drill without storing any secret values in Git.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now links the secret-rotation drill directly as candidate evidence.
- `scripts/verify-phase5-secret-rotation-drill.ps1` verifies the drill artifact fail-closed against the runbook links, repo-storage prohibition, hosted health/progress/integrity surfaces, external gates, and deployment preflight.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-secret-rotation-drill.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `53%`; Phase 5 rises to `14%`. This is a release-readiness operations evidence step, not a rollout or production deployment.

## Previous Completed Proof

Historical, now superseded browser section - Phase 5 Executed Hosted Candidate Browser Proof:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md` is now a historical `superseded` artifact only; fresh browser reruns are currently blocked and are not counted in current candidate evidence.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` no longer links the browser proof as active candidate evidence.
- `scripts/verify-phase5-browser-proof.ps1` now verifies the fail-closed blocked historical state instead of a current browser-proof claim.
- Blocker evidence is explicit: `failed to start codex app-server ... (os error 3)`, `Target.setDiscoverTargets): Target closed`, and Playwright launcher `exit code 13`.
- Progress change: Overall remains `53%`; Phase 5 rises to `13%`. This is a release-readiness browser evidence step, not a rollout or production deployment.

## Previous Completed Proof

Phase 5 Candidate Observability Review Proof:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-observability-review.md` now binds the current production-candidate to an executed hosted observability review.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now links the observability review directly as candidate evidence.
- `scripts/verify-phase5-observability-review.ps1` verifies the observability-review artifact fail-closed against the hosted health, progress, integrity, metrics, audit, escalation, and external-gate surfaces.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-observability-review.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall rises to `53%`; Phase 5 rises to `12%`. This is a release-readiness observability evidence step, not a rollout or production deployment.

## Previous Completed Proof

Phase 5 Executed Candidate Incident Drill:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-incident-drill.md` now binds the current production-candidate to an executed incident/escalation drill for a simulated unhealthy candidate scenario.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now links the incident drill directly as candidate evidence.
- `scripts/verify-phase5-incident-drill.ps1` verifies the incident-drill artifact fail-closed against incident classification, evidence capture, rollback decision path, hosted health/integrity/metrics/audit/escalation surfaces, and the external gate / deployment preflight state.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-incident-drill.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-rollback-drill.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `52%`; Phase 5 rises to `11%`. This is a release-readiness operations evidence step, not a rollout or production deployment.

## Previous Completed Proof

Phase 5 Executed Hosted Candidate Smoke Proof:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-smoke-proof.md` is historical candidate evidence from the retired Hetzner staging target; it is not current hosted gate truth.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now links the executed smoke proof directly as candidate evidence.
- `scripts/verify-phase5-executed-smoke.ps1` verifies the executed smoke artifact fail-closed against the hosted root title marker, the four hosted health paths, hosted progress/integrity/completion truth, and the external gate / deployment preflight contracts.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-executed-smoke.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-rollback-drill.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `52%`; Phase 5 rises to `10%`. This is a release-readiness evidence step, not a rollout or production deployment.

## Previous Completed Proof

Phase 5 Candidate Integration Plan Proof:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-plan.md` now binds the current production-candidate to an explicit hosted smoke sequence, expected outcomes, failure handling, evidence links, and non-claims.
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now closes `Integration plan documented` and links the integration-plan artifact as candidate evidence.
- `scripts/verify-phase5-integration-plan.ps1` verifies the integration-plan artifact fail-closed against the required structure, hosted target, exact verifier links, and the candidate-artifact evidence line.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-integration-plan.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `52%`; Phase 5 rises to `9%`. This is a release-readiness evidence step, not a rollout or production deployment.

## Previous Completed Proof

Phase 5 Owner Decision + P3 Browser Proof Hardening:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now carries `owner_decision_proof`, `review_gate=reviewed`, and `owner_decision=no-release`.
- `.phase1-artifacts/phase5-owner-decision-no-release-20260505.md` documents the explicit no-release decision against the current `50%` overall state and preserves the production non-claim.
- `scripts/verify-phase5-candidate.ps1` now verifies the owner-decision artifact fail-closed instead of allowing a generic pending review state.
- `scripts/verify-browser-contract.ps1` now also asserts the already-shipped Product Surface & Security markers for `Auth Contract` and `System Unavailable Fallback`, so these contracts have a repeatable local browser proof in addition to the hosted verifier coverage.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change: Overall remains `50%`; Phase 5 rises to `8%`. This is an owner decision plus verifier hardening step, not a production deployment.

## Previous Completed Proof

Phase 5 Candidate Pipeline + Rollback Drill Proof:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` now binds the first concrete production-candidate artifact to the hosted staging runtime, external-gate closure, GHCR candidate tags, successful GitHub Actions run `25318349068`, source commit `5464c922f8871e4ff36e620ff53026fb1a2a05b3`, immutable rollback tag set, rollback runbook path, and the owner/review decision path.
- `.phase1-artifacts/phase5-rollback-readiness-20260505.md` remains the candidate-specific rollback-readiness proof, and `.phase1-artifacts/phase5-rollback-drill-prod-candidate-20260505-rc1.md` now captures the documented good-tag rollback drill with the hosted root, Agent API, MCP Gateway, and LLM Gateway as post-revert verification targets.
- `scripts/verify-phase5-candidate.ps1` and `scripts/verify-phase5-rollback-drill.ps1` verify the candidate fail-closed against the release artifact, rollback-readiness proof artifact, rollback-drill artifact, hosted endpoints, GHCR `staging` tags, GHCR commit tags, GitHub workflow run truth, and the hosted runtime truth endpoints.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-release-readiness.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-rollback-drill.ps1`, `gh run view 25318349068 --json conclusion,status,headSha,url,name`, `docker manifest inspect ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:staging` for all six services, `docker manifest inspect ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:5464c922f8871e4ff36e620ff53026fb1a2a05b3` for all six services, and hosted `GET /`, `GET /api/v1/health`, `GET /mcp/api/v1/health`, `GET /llm/api/v1/health`
- Progress change: Overall stays at `50%`; Phase 5 rises to `7%`. This is a verified production-candidate pipeline and immutable rollback-drill step, not a production deployment.

## Previous Completed Proof

Phase 5 Release Readiness Baseline Proof:

- `docs/release-checklist.md` now defines the active Phase-5 release-readiness baseline with four mandatory sections: `Code Readiness`, `Infrastructure Readiness`, `Observability Readiness`, and `Operations Readiness`; all checklist items are `JA/NEIN`, the Git artifact path is `docs/release-artifacts/<release_id>.md`, and explicit stop-gates plus non-claims are included.
- `docs/release-artifacts/README.md` and `docs/release-artifacts/TEMPLATE.md` now define the per-release Git artifact location and required candidate fields such as `release_id`, `pipeline_status`, `review_gate`, and `owner_decision`.
- `docs/runbooks/rollback-deploy.md`, `docs/runbooks/incident-response.md`, `docs/runbooks/secret-rotation.md`, `docs/runbooks/provider-failover.md`, and `docs/runbooks/memory-recovery.md` now provide the Phase-5 baseline runbooks with trigger, verification, escalation, and non-claims; `docs/runbooks/README.md` was promoted from Phase-0 draft to an active baseline index.
- `scripts/verify-phase5-release-readiness.ps1` verifies the release-checklist baseline fail-closed against the checklist, release-artifact template, runbooks, hosted browser proof artifact, and deploy workflow guard.
- Verified commands: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-release-readiness.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Progress change at that milestone: none yet. The baseline alone did not raise progress until the concrete production-candidate artifact and candidate verifier were added.

## Previous Completed Proof

Hosted Runtime Truth Alignment Proof:

- Hosted URL: `<hosted-staging-url>`
- Runtime endpoints now aligned: `GET /api/v1/external-gates`, `GET /api/v1/external-gates/mirror`, `GET /api/v1/clouds/deployment-preflight/contract`, and `GET /api/v1/project/progress/completion`
- Result: Hosted `external-gates status=verified`, `verified_count=6`, `blocked_release_gates=[]`; hosted deployment preflight `status=verified`, `missing_or_blocked_gates=[]`, `cloud_deploy_claim_allowed=true`, `production_deploy_claim_allowed=true`; hosted mirror `status=verified`, `hosted_staging_claim_allowed=true`, `branch_protection_claim_allowed=true`
- Runtime correction: `services/agent-api/app/main.py` now derives cloud-gate verification from the binding progress manifest markers, so the hosted panels stop advertising stale blockers after the external gate audit is already closed.
- Verified commands: Python compile for `services\agent-api\app\main.py`, `scripts\deploy-to-staging.ps1`, `scripts\verify-cloud-only-staging.ps1 -BaseUrl <hosted-staging-url>`, `scripts\verify-external-gates.ps1 -HostedBaseUrl <hosted-staging-url> -LocalBaseUrl <local-control-plane-url>`, direct hosted API inspection of the three gate endpoints and the completion endpoint, and remote `docker compose --env-file .env -f docker-compose.cloud.yml up -d --force-recreate agent-api`.
- Progress change: Overall remains `49%`; Phase 4 rises to `24%`. This is runtime-truth alignment after real gate closure, not a production deployment.

## Previous Completed Proof

External Gate Audit Closure Proof:

- Hosted URL: `<hosted-staging-url>`
- Audit artifact: `.phase1-artifacts\external-gate-audit-20260504-212633.json`
- Result: `status=verified`, `frontend_preview_claim_allowed=True`, `hosted_staging_claim_allowed=True`, `production_deploy_claim_allowed=True`
- Closed gates: GHCR digest resolution, Hetzner live budget proof, hosted backend-origin health, hosted HTTPS staging, branch protection verify-only, and canonical gitleaks.
- Branch protection proof: remote verifier upload to `/tmp/apply_github_branch_protection.py` plus remote `python3 /tmp/apply_github_branch_protection.py --verify-only --repo strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM --branch chore/repo-bootstrap` executed successfully against the GitHub API using the existing remote `.env` secret context.
- Verifier hardening: `scripts/verify-external-gates.ps1` now resolves the remote default branch first, accepts hosted Hetzner budget proof by contract marker instead of brittle JSON spacing, and falls back to remote branch-protection verification when local `BRANCH_PROTECTION_TOKEN` is absent.
- Progress change: Overall rises to `49%`; Phase 4 rises to `23%`. This is gate closure and release-readiness hardening only. It is not a production deployment.

## Previous Completed Proof

Hosted HTTPS Staging Proof:

- Hosted URL: `<hosted-staging-url>`
- Deploy path: `scripts/deploy-to-staging.ps1` now requires an existing remote `.env`, copies only non-secret files, sets non-local `STAGING_BASE_URL`, `AGENT_API_BASE_URL`, `MCP_GATEWAY_BASE_URL`, and `LLM_GATEWAY_BASE_URL`, and deploys the pull-based cloud stack under `/app`.
- TLS layer: `docker-compose.cloud.yml` now runs `caddy` in front of `nginx`; `infrastructure/caddy/Caddyfile` terminates HTTPS for `<hosted-staging-hostname>`; `infrastructure/nginx/cloud.conf` preserves forwarded proto/host markers from the TLS proxy.
- Live proof: Python/OpenSSL probes returned HTTP `200` for `<hosted-staging-url>/` and `<hosted-staging-url>/api/v1/health`; the hosted progress endpoint returned `overall_percent=48`; remote `docker compose ... ps` showed `caddy`, `nginx`, `frontend`, `agent-api`, `mcp-gateway`, `llm-gateway`, `postgres`, `redis`, `agent-worker`, and `memory-worker` healthy.
- Gate proof: `scripts/verify-cloud-only-staging.ps1 -BaseUrl <hosted-staging-url>` now passes with `hosted_staging_claim_allowed=True`. The later external-gate audit closure proof supersedes the older note about still-open branch, GHCR, backend-origin, and Hetzner gates.
- Browser proof: Puppeteer navigated to `<hosted-staging-url>/` and confirmed title `Cloud Superbrain`, visible `Project Progress`, visible `External Gates`, visible `48%`, and the hosted URL. Playwright/Chrome DevTools screenshot proof remained locally blocked because Chrome is not installed on this machine.
- Progress change at that milestone: Overall remained `48%`; Phase 4 rose to `16%`. The newer external-gate audit closure proof supersedes the older open-gate state.

## Previous Completed Proof

External Gates Alignment Contract Proof:

- API: `GET /api/v1/external-gates`
- Contract: `external-gates-state-v1`
- Evidence: `external_gates_state_visible`
- Coverage: the local external-gates endpoint now publishes the same release-gate vocabulary as the cloud deployment preflight through `preflight_gate_id` mappings for `branch_protection`, `hosted_staging`, `hetzner_cloud_stack`, `ghcr_images`, `hosted_backend_origins`, and `canonical_secret_scan`.
- UI: the `External Gates` panel now renders contract version, evidence ref, endpoint marker, blocked release gates, the preflight endpoint link, and per-gate alias rows such as `ghcr_image_digest_proof -> ghcr_images` and `vercel_backend_origins -> hosted_backend_origins`.
- Verifier hardening: `scripts/verify-browser-contract.ps1`, `scripts/verify-hosted-staging.ps1`, `scripts/verify-phase1-runtime.ps1`, and `scripts/verify-phase1.ps1` now assert the alignment markers. `scripts/verify-hosted-staging.ps1` no longer fails on a global `latest_task_id` race; it verifies stable agent-status markers instead.
- AI browser proof: Chrome DevTools MCP opened `<local-control-plane-url>/`, confirmed `External Gates`, `external-gates-state-v1`, `external_gates_state_visible`, `Release blockers`, the deployment preflight link, the GHCR/Vercel alias mapping, and `47%`; network proof showed HTTP `200` for the page and contract endpoints; screenshot `<repo-root>\superbrain-external-gates-alignment-proof-2026-05-04.png` was captured.
- Verified commands: Python compile for `services\agent-api\app\main.py`, project-progress manifest validation, `scripts\verify-phase1.ps1`, Docker rebuild of `agent-api`, `frontend`, and `nginx`, `scripts\verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts\verify-hosted-staging.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, and direct API inspection of `GET /api/v1/external-gates`.

No progress percentage changed at that point: Overall remained `48%`, Phase 4 remained `15%`. This was contract/verifier hardening, not a live hosted or production cloud proof.

## Previous Completed Proof

Cloud Deployment Preflight Fail-Closed Contract Proof:

- API: `GET /api/v1/clouds/deployment-preflight/contract`
- Contract: `cloud-deployment-preflight-v1`
- Evidence: `cloud_deployment_preflight_visible`
- Coverage: separates environment presence from verified cloud proof; `cloud_deploy_claim_allowed=false` and `production_deploy_claim_allowed=false` until all external gates prove real hosted/non-local cloud state.
- Required gates: `ghcr_images` with `ghcr_image_digest_proof`, `hetzner_cloud_stack`, `hosted_backend_origins`, `hosted_staging`, `branch_protection`, and `canonical_secret_scan`.
- External gate hardening: hosted URLs must be non-local HTTPS; branch protection requires `BRANCH_PROTECTION_TOKEN`; GHCR proof requires both `GITHUB_TOKEN` and `GHCR_TOKEN`; Vercel backend origins require `AGENT_API_BASE_URL`, `MCP_GATEWAY_BASE_URL`, and `LLM_GATEWAY_BASE_URL`.
- Frontend renders `Cloud Deployment Preflight`, `cloud-deployment-preflight-v1`, `cloud_deployment_preflight_visible`, `GET /api/v1/clouds/deployment-preflight/contract`, and blocked cloud/production claims.
- AI browser proof: Chrome DevTools MCP opened `<local-control-plane-url>/`, confirmed `Project Progress 47%`, `Verified: 2026-05-03`, the Preflight panel, the endpoint marker, all six blockers, and captured screenshot `<repo-root>\superbrain-cloud-deployment-preflight-proof-2026-05-03.png`. Network proof showed the page and `/api/v1/clouds/deployment-preflight/contract` returning HTTP `200`; console showed no JavaScript runtime errors, only an accessibility issue about unnamed form fields.
- Verified commands: Python compile for `services\agent-api\app\main.py`, project-progress manifest validation, PowerShell parser checks for the updated verifiers, `scripts\verify-phase1.ps1`, Docker rebuild, direct API checks for deployment preflight and external gate mirror, `scripts\verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts\verify-hosted-staging.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts\verify-external-gates.ps1 -LocalBaseUrl <local-control-plane-url>`, intentional negative proof from `scripts\verify-cloud-only-staging.ps1 -BaseUrl <local-control-plane-url>`, and full `scripts\verify-phase1-runtime.ps1`.
- External gate artifact: `.phase1-artifacts\external-gate-audit-20260503-184218.json` reported `status=action_required`, `frontend_preview_claim_allowed=false`, `hosted_staging_claim_allowed=false`, and `production_deploy_claim_allowed=false`.

No progress percentage changed: Overall remains `47%`, Phase 4 remains `15%`. This was fail-closed cloud readiness hardening, not a live hosted staging or production deployment.

## Previous Completed Proof

Gemini Priority Queue Correction + Sandbox Rule Proof:

- Scope: reviewed the reported `tasks.py` and `orchestrator.py` changes instead of accepting the `49%` claim; current manifest truth remains `47%`.
- Queue contract: Agent API publishes each task to exactly one priority queue; Worker consumes `tasks:agent:queue:high`, `tasks:agent:queue`, then `tasks:agent:queue:low`.
- Role priority proof: Planner priority `9` and DevOps priority `8` resolve to high priority; Coder and Tester priority `5` remain mid/default.
- Orchestrator evidence proof: `task_assignment_completed` is emitted only for completed tasks; missing `[DONE]` or unproven `live_provider_calls=false` becomes partial failure instead of false completion.
- Redaction proof: `task_description` is redacted before validation/persistence.
- Sandbox rule proof: `Unexpected response type` is documented as an MCP wrapper/transport hint in `<workspace-root>\AGENTS.md` and `<workspace-root>\SANDBOX_INSTRUCTIONS.md`, not as an automatic ULTIMATE_SANDBOX failure.
- AI browser proof: Chrome DevTools MCP opened `<local-control-plane-url>/`, listed 75 network requests with HTTP `200`, and the DOM contained `Task Assignment Queue Contract`, `Priority Routing`, `high -> mid -> low`, `Total Project`, and `47%`; Puppeteer MCP confirmed the same markers and captured screenshot `superbrain-priority-routing-section-2026-05-01`.
- Verified commands: Python compile for Agent API/Worker files, `py -3 scripts\verify_project_progress_manifest.py`, `scripts\verify-phase1.ps1`, Docker rebuild, direct API priority-contract checks, `scripts\verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts\verify-hosted-staging.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, and `scripts\verify-phase1-runtime.ps1`.

No progress percentage changed: Overall remains `47%`, Phase 4 remains `15%`. This was corrective hardening, not external gate closure.

## Previous Completed Proof

Cloud Render Offload Contract Proof:

- API: `GET /api/v1/clouds/render-offload/contract`
- Contract: `cloud-render-offload-v1`
- Evidence: `cloud_render_offload_contract_visible`
- Coverage: `localhost_heavy_render_allowed=false`, `home_pc_protection=true`, `webgl_3d_rendering`, `browser_gpu_smoke`, and `asset_generation` are cloud-only, while `control_plane` remains local dev-only.
- Required cloud gates: `STAGING_BASE_URL`, `AGENT_API_BASE_URL`, `MCP_GATEWAY_BASE_URL`, `LLM_GATEWAY_BASE_URL`, and `FLY_API_TOKEN`.
- Frontend renders `Cloud Render Offload`, `Local Render blocked`, `WebGL / 3D rendering cloud-only`, and `GET /api/v1/clouds/render-offload/contract`.
- Verified commands: `py -3 -m py_compile services\agent-api\app\main.py`, `scripts\verify-phase1.ps1`, `docker compose -f docker-compose.dev.yml up -d --build agent-api frontend nginx`, direct API curl, `scripts\verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts\verify-hosted-staging.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts\verify-external-gates.ps1 -LocalBaseUrl <local-control-plane-url>`, and Playwright DOM proof.

No progress percentage changed: Overall remains `47%`, Phase 4 remains `15%`. The contract is local/fail-closed and does not claim live cloud servers.

## Previous Completed Proof

Grafana Cloud Inventory Contract Proof:

- API: `GET /api/v1/clouds`
- Contract: `cloud-provider-inventory-v1`
- Evidence: `cloud_provider_inventory_visible`
- Coverage: the inventory exposes the active cloud line and includes `grafana_cloud` with `GRAFANA_CLOUD_API_KEY` as key name/status only.
- Layer readiness: `GET /api/v1/clouds/layers` includes `grafana_cloud` in Layer 7.
- External gate audit: `scripts/verify-external-gates.ps1` emits `grafana_cloud_claim_allowed=false` until a real Grafana Cloud key is injected.
- Docs/runtime: `.env.example`, `docker-compose.cloud.yml`, `docs/runbooks/cloud-secret-runtime-injection.md`, `docs/runtime-contracts/cloud-provider-inventory-contract.md`, and `docs/runtime-contracts/external-gate-audit-contract.md` now include active cloud gates without storing secrets.
- Verified commands: `py -3 -m py_compile services\agent-api\app\clouds.py`, `py -3 scripts\verify_project_progress_manifest.py`, `scripts\verify-phase1.ps1`, `scripts\verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts\verify-hosted-staging.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts\verify-external-gates.ps1 -LocalBaseUrl <local-control-plane-url>`, and `scripts\verify-phase1-runtime.ps1`.
- Browser proof confirms `Cloud Inventory`, `Cloud 7-Layer Readiness`, `grafana_cloud`, `cloud_provider_inventory_visible`, and `cloud_layer_readiness_visible`.

No progress percentage changed: Overall remains `47%`, Phase 4 remains `15%`, MCP Gateway remains `53%`, Observability remains `99%`.

## Previous Completed Proof

Local Rebuild + Runtime Re-Proof:

- Rebuilt and restarted local Docker services with `docker compose -f docker-compose.dev.yml up -d --build agent-api agent-worker memory-worker frontend nginx`.
- `GET /api/v1/health` returned `healthy` after rebuild.
- `GET /api/v1/memory/embedding-consistency/contract` returned `status=verified`, `memory-embedding-consistency-v1`, `vector(1536)`, `embedding_model_version`, and `lexical_fallback`.
- `scripts/verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost` passed.
- `scripts/verify-hosted-staging.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost` passed.
- `scripts/verify-phase1-runtime.ps1` passed, including Docker recreate, worker regression, SSE replay, Memory Embedding Consistency, and post-recreate steady-state proof.
- Playwright opened `<local-control-plane-url>/` and confirmed `Cloud Superbrain`, `Project Progress`, and `Memory Embedding Consistency Contract`.

No progress percentage changed: Overall remains `47%`, Phase 4 remains `15%`, Memory remains `70%`.

Audit L-09 Memory Embedding Consistency Contract Proof:

- API: `GET /api/v1/memory/embedding-consistency/contract`
- Contract: `memory-embedding-consistency-v1`
- Evidence: `memory_embedding_consistency_contract_visible`
- Coverage: runtime verifies `memory_entries.content_embedding vector(1536)`, `memory_entries.embedding_model_version`, deterministic `text-embedding-3-small`, `lexical_fallback`, and a fail-closed re-embedding policy before future vector search can mix versions.
- Frontend renders `Memory Embedding Consistency Contract`; docs live in `docs/runtime-contracts/memory-embedding-consistency-contract.md`.

This raised Memory from `69%` to `70%`. Overall remains `47%`, Phase 4 remains `15%`.

## Previous Completed Proof

Runtime Post-Recreate Steady-State Proof:

- Verifier: `scripts/verify-phase1-runtime.ps1`
- Coverage: transient `curl` noise is suppressed while waiting through Docker/Nginx recreate windows; failed probes still fail after bounded retry exhaustion. Session-SSE stream and replay probes now use bounded `Wait-SseContains` retries in both runtime and hosted-local verifiers.
- Post-recreate proof: `GET /api/v1/health`, `GET /api/v1/project/progress/integrity`, `GET /mcp/api/v1/version-pinning/contract`, and `/favicon.ico`.
- Purpose: a green runtime run cannot leave an unverified 502, stale Nginx upstream, or browser asset regression behind.

No percentage change. Overall remains `47%`, Phase 4 remains `15%`.

## Previous Completed Proof

L-09 Project Progress Integrity Runtime Proof:

- API: `GET /api/v1/project/progress/integrity`
- Contract: `project-progress-integrity-v1`
- Evidence: `project_progress_integrity_runtime_proof`
- Coverage: runtime recomputes `computed_overall_percent` from the seven horizontal phases, compares it to `manifest_overall_percent`, reports mismatches fail-closed, and keeps the binding manifest/document visible.
- Frontend renders `Progress Integrity`; docs live in `docs/runtime-contracts/project-progress-integrity-contract.md`.

This raised Phase 4 from `14%` to `15%`. Overall remains `47%`.

## Previous Completed Proof

L-08 MCP Version Pinning Contract Proof:

- API: `GET /mcp/api/v1/version-pinning/contract`
- Contract: `mcp-version-pinning-v1`
- Evidence: `mcp_version_pinning_contract_visible`
- Coverage: MCP Gateway version `0.1.0`, exact Python dependency pins, pinned tool contract versions for GitHub, PostgreSQL, Filesystem, Playwright, and E2B, ToolRequest shape, drift policy, and no-live-MCP-write non-claims.
- Frontend renders `MCP Version Pinning Contract`; docs live in `docs/runtime-contracts/mcp-version-pinning-contract.md`.

This raised Phase 4 from `13%` to `14%` and MCP Gateway from `52%` to `53%`. Overall remains `47%`.

## Previous Completed Proof

L-07 Agent LLM Streaming Contract Proof:

- API: `GET /api/v1/agents/llm-streaming-contract`
- Contract: `agent-llm-streaming-contract-v1`
- Evidence: `agent_llm_streaming_contract_visible`
- Coverage: Layer 3 to Layer 4 streaming boundary from Agent Pool to LLM Gateway, `call_llm_gateway_for_task`, `parse_llm_gateway_sse_line`, routing policy preflight, OpenAI-compatible SSE frames, `data: [DONE]`, `stream_done_seen`, and no-live-provider non-claims.
- Frontend renders `Agent LLM Streaming Contract`; docs live in `docs/runtime-contracts/agent-llm-streaming-contract.md`.

This raised Phase 4 from `12%` to `13%` and LLM Gateway from `52%` to `53%`. Overall remains `47%`.

## Previous Completed Proof

Fly.io Budget Gate Projection:

- Script: `scripts/check_fly_infra_budget.py`
- Proof doc: `docs/runbooks/fly-live-budget-proof-2026-06-08.md`
- Result: projected Fly.io monthly server cost `EUR 9.00`
- Thresholds: warning `EUR 16.00`, hard budget `EUR 20.00`
- Interpretation: projection under warning threshold; live external gate still requires `FLY_API_TOKEN`.
- Token handling: no token value is stored or printed.

This raised Phase 4 from `11%` to `12%`. Overall remains `47%`.

## Previous Completed Proof

L-06 Task Assignment Queue Contract Proof:

- API: `GET /api/v1/tasks/assignment-contract`
- Contract: `task-assignment-queue-contract-v1`
- Evidence: `task_assignment_queue_contract_visible`
- Coverage: Layer 2 to Layer 3 task assignment, Redis queue key, status key pattern, TTL, worker consumer, public visibility endpoints, backpressure, stale-queue rescue, and policy fail-closed semantics.
- Frontend renders `Task Assignment Queue Contract`; docs live in `docs/runtime-contracts/task-assignment-queue-contract.md`.

This raised Phase 4 from `10%` to `11%` and Agent Pool from `60%` to `61%`. Overall remains `47%`.

## Previous Completed Proof

L-05 Layer Interface Contracts Proof:

- API: `GET /api/v1/layer-interfaces/contract`
- Contract: `layer-interface-contracts-v1`
- Evidence: `layer_interface_contracts_visible`
- Coverage: seven runtime layer boundaries with method, path, request schema, response schema, status, and evidence ref.
- Frontend renders `Layer Interface Contracts`; docs live in `docs/runtime-contracts/layer-interface-contracts.md`.

Historical proof point: this raised Phase 4 from `9%` to `10%` and Frontend from `96%` to `97%`; current verified progress remains defined by the `Current Verified Progress` section above.

## Previous Completed Proof

Audit Runtime Closure Proof:

- Task intake rejects invalid `session_id` values fail-closed with HTTP 422.
- Agent Worker rejects malformed raw queue payloads without crashing.
- Orchestrator MCP calls carry `session_id` and `trace_id` into MCP Gateway and Agent API audit persistence.
- `GET /api/v1/audit/mcp` exposes `session_bound=true`, top-level `trace_id`, and `mcp_tool_session_bound_audit` for orchestrator tool calls.
- ADR-008 and ADR-009 close the single-tenant and auth-design audit documentation gaps.

Historical proof point: this raised Phase 4 from `8%` to `9%`, Agent Pool from `59%` to `60%`, MCP Gateway from `51%` to `52%`, and Overall from `46%` to `47%`; current verified progress remains defined by the `Current Verified Progress` section above.

## Previous Completed Proof

External Gate Mirror Proof:

- API: `GET /api/v1/external-gates/mirror`
- Contract: `external-gate-mirror-v1`
- Evidence: `external_gate_mirror_proof`
- Hosted workflow mirror: `.github/workflows/hosted-staging-proof.yml`
- Hosted verifier mirror: `scripts/verify-hosted-staging.ps1`
- Progress mirror evidence: `project_progress_manifest_proof`

Historical proof point: this raised Phase 4 from `7%` to `8%` while Overall was still `46%`; current verified progress remains defined by the `Current Verified Progress` section above.

## Non-Claims / Closed Gates

Do not claim these until external evidence exists:

- Live LLM calls are verified only in the bounded Cloudflare Workers AI
  gateway acceptance paths above; general provider activation, dynamic
  routing, and hosted full-product parity are not verified.
- No live MCP writes are verified.
- No stateful full-backend or full-platform production release is verified; the scoped Vercel frontend and stateless read-only Backend Contract Origin are verified separately.
- `production_deploy_claim_allowed=true` is only a gate-closure statement, not a deploy statement.

## Next Safe Work

1. Commit only the current Qwen 3.7 gateway implementation and synchronized Truth/Handoff files; preserve all unrelated dirty and staged files.
2. Run the final chain strictly serially: `npm run build`, `npm run verify:runtime`, `scripts/start-dev-live.ps1`, `npm run verify:browser`, `npm run verify`, `npm run verify:release-boundary`, `npm run verify:current-release-candidate`, and `npm run verify:market-ready`.
3. Keep O4 as the last source-bound runtime/browser proof after the final tracked-source commit. Any later tracked change invalidates that proof and requires the browser/O4 chain again.
4. Push only `codex/organism-visual-v2` after the in-scope chain is green, then inspect its GitHub Actions result. Do not push `main`, publish GHCR images, deploy Production, activate Alibaba live-provider traffic, or promote a release without the documented Owner gates.

## Git State Warning

The current workspace is intentionally not clean. Generated runtime evidence, the foreign staged RC12 mirror, and unrelated untracked files must remain outside this slice. Never use `git add -A`; stage or commit only explicit pathspecs. A clone reproduces only committed and pushed project truth, not these preserved local artifacts.

## Historical Hosted Snapshot (superseded by Current Verified Progress at the top)

- Overall: `70%`
- Horizontal `P0 100 | P1 100 | P2 86 | P3 40 | P4 99 | P5 67 | P6 0`
- Vertical `Frontend 99 | Orchestrator 99 | Agent Pool 68 | LLM 54 | MCP 55 | Memory 72 | Observability 99`

## Latest Completed Hosted Proofs

**Project Progress Completion Contract Runtime Parity**

- API:
  - `GET /api/v1/project/progress/completion/contract`
  - `GET /api/v1/project/progress/completion`
- Contract: `project-progress-completion-surface-v1`
- Runtime stayed fail-closed with `can_set_all_to_100=false`
- Proof: `.phase1-artifacts/phase4-progress-completion-contract-runtime-hosted-proof-20260507.md`

**Orchestrator Manifest Contract Runtime Parity**

- API:
  - `GET /api/v1/orchestrator/manifest/contract`
  - `GET /api/v1/orchestrator/manifest`
- Contract: `orchestrator-manifest-surface-v1`
- Hosted dry-run stayed aligned with `engine=langgraph`, `checkpointing=postgres`, `live_provider_calls=false`
- Proof: `.phase1-artifacts/phase4-orchestrator-manifest-contract-runtime-hosted-proof-20260507.md`
