# NEW CHAT RESUME ANCHOR - 2026-05-15 - MCP Guard Correlation Checkpoint

Checkpoint time: 2026-05-15, Europe/Berlin.
Repository: `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`
Branch: `codex/live-agent-steering-ui-20260513`

## User Operating Rules

- Continue autonomously and do not ask for confirmation unless the next action is impossible or destructive.
- Keep chat output short.
- Do not claim a production rollout.
- Do not print secrets.
- Do not stage unrelated or foreign files.
- Do not download local models. Keep the architecture API-inference/open-source-first.
- Docker readiness must always be checked with:

```powershell
docker info --format '{{.ServerVersion}}'
```

- If agents are spawned, always `wait_agent` before final output and close completed agents.

## Current True State

Latest pushed remote before this slice: `00496e1 docs(phase5): align llm guard verifier proof`.
Local runtime commit created but not pushed: `4ce557f7e195846afa39d89861f296202561f34a`.
Commit message: `feat(phase5): add mcp guard correlation bundle`.

Hosted staging:

```text
https://188-34-191-140.sslip.io/
```

Hosted staging image tag:

```text
4ce557f7e195846afa39d89861f296202561f34a
```

Current hosted/manifest progress after deploy:

```text
Overall: 82%
Horizontal: P0 100, P1 100, P2 89, P3 95, P4 100, P5 88, P6 0
Vertical: Frontend 99, Orchestrator 99, Agent Pool 76, LLM Gateway 67, MCP Gateway 68, Memory 74, Observability 99
```

Only changed from previous known state in this slice:

```text
Phase 5: 87 -> 88
MCP Gateway: 67 -> 68
```

The branch is expected to be ahead of origin by one commit and still dirty with docs/script alignment changes.

## Runtime Slice Completed

The implemented slice is "Active MCP Guard Correlation Bundle".

Runtime files changed in committed SHA `4ce557f7e195846afa39d89861f296202561f34a`:

- `services/mcp-gateway/app/main.py`
- `services/agent-api/app/main.py`
- `scripts/verify-phase5-active-mcp-guard-correlation-bundle.ps1`
- `scripts/verify-phase5-active-verifier-sweep-bundle.ps1`
- `scripts/verify-phase5-full-verifier-sweep.ps1`
- `scripts/verify-phase5-suite-active-candidate-plan.ps1`
- `scripts/verify.suites.json`
- `docs/project-progress.manifest.json`

Runtime behavior added:

- Blocked MCP tool attempts now carry guard evidence into the MCP audit path.
- `mcp_guard_correlation_evidence_ref = mcp_guard_correlation_audit_visible` is added for blocked MCP events.
- Agent API persists MCP audit details with MCP guard correlation evidence.
- MCP audit contract and snapshot now expose guard correlation evidence and counts.
- New verifier checks three blocked MCP paths and verifies correlation through MCP audit, global audit, agent activity, and gateway timeline.

Verifier path:

```text
scripts/verify-phase5-active-mcp-guard-correlation-bundle.ps1
```

Expected gate details:

```text
mcp_guard_gate_count: 8
changed_horizontal: Phase 5 87->88
changed_vertical: MCP Gateway 67->68
```

## Build And Deploy Completed

Local Docker readiness was checked with:

```powershell
docker info --format '{{.ServerVersion}}'
```

Observed Docker server version:

```text
29.4.1
```

Local dev stack rebuild succeeded:

```powershell
docker compose -f docker-compose.dev.yml up -d --build agent-api mcp-gateway nginx
```

GHCR build and push succeeded for all six linux/arm64 images:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-and-push.ps1 -Tag 4ce557f7e195846afa39d89861f296202561f34a -Platforms linux/arm64 -Builder superbrain_builder
```

Hosted immutable image-filesystem deploy succeeded:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -UseImageFilesystem -ImageTag 4ce557f7e195846afa39d89861f296202561f34a -KeyPath "$HOME\.ssh\oracle_key"
```

The deploy confirmed:

```text
target=https://188-34-191-140.sslip.io
image_tag=4ce557f7e195846afa39d89861f296202561f34a
image_filesystem=True
```

## Validation Already Done

These passed before the docs alignment phase:

```powershell
py -3 -m compileall services\agent-api\app services\mcp-gateway\app
py -3 scripts\verify_project_progress_manifest.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-phase5-suite-active-candidate-plan.ps1
```

The new verifier parser check also passed.

Important: the first local run of the new MCP guard verifier failed only because the proof document had not yet been added. The missing expected marker was:

```text
active_mcp_guard_correlation_bundle_proof
```

That proof document has now been created, but the full post-doc verification still needs to be rerun.

## Docs And Release Artifacts In Progress

New proof docs added:

- `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-mcp-guard-correlation-bundle-20260515.md`
- `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-mcp-guard-correlation-immutable-staging-20260515.md`

Docs updated in the dirty working tree:

- `AI_HANDOFF.md`
- `PROJECT_STATE.md`
- `docs/project-progress.manifest.json`
- `docs/verification-register.md`
- `docs/release-artifacts/current-release-candidate.json`
- `docs/release-artifacts/prod-candidate-2026-05-11-rc1.md`
- `docs/release-artifacts/prod-candidate-2026-05-11-rc1-runtime-selector-truth.md`
- active verifier sweep/full suite proof docs
- multiple active Phase 5 proof docs had their image/source SHA updated to `4ce557f7e195846afa39d89861f296202561f34a`
- multiple active verifier scripts were aligned to accept current Phase 5 `88` and MCP Gateway `68`

Before committing these docs, inspect the diff carefully:

```powershell
git status --short
git diff --stat
git diff -- docs\release-artifacts\current-release-candidate.json docs\release-artifacts\prod-candidate-2026-05-11-rc1.md docs\verification-register.md AI_HANDOFF.md PROJECT_STATE.md
```

Special attention:

- A broad text replacement updated old SHA `c0a9d461615e4ccad2397fb6c0821659969ede4d` to `4ce557f7e195846afa39d89861f296202561f34a` across many release artifact docs.
- This may be intentional if the active release candidate rebinds all active proof docs to the current immutable image.
- Do not blindly revert. Decide from the active candidate pattern and only stage files that are part of this release-candidate alignment.

## Suggested Next Verification Commands

Start with sanity:

```powershell
cd D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM
git status --short
git log --oneline -5
docker info --format '{{.ServerVersion}}'
```

Then run local checks:

```powershell
py -3 -m compileall services\agent-api\app services\mcp-gateway\app
py -3 scripts\verify_project_progress_manifest.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-phase5-suite-active-candidate-plan.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-phase5-active-mcp-guard-correlation-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost
```

Then run hosted checks:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-phase5-active-mcp-guard-correlation-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-current-immutable-staging-parity.ps1 -RequireVerified -ReleaseId prod-candidate-2026-05-11-rc1 -CandidateSha 4ce557f7e195846afa39d89861f296202561f34a -BaseUrl https://188-34-191-140.sslip.io -KeyPath "$HOME\.ssh\oracle_key"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-current-runtime-selector-truth.ps1 -RequireRemoteProof -BaseUrl https://188-34-191-140.sslip.io -KeyPath "$HOME\.ssh\oracle_key"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-phase5-active-verifier-sweep-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-phase5-full-verifier-sweep.ps1 -BaseUrl https://188-34-191-140.sslip.io
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-current-release-candidate.ps1 -BaseUrl https://188-34-191-140.sslip.io
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-evidence-artifact-safety.ps1
```

If all pass, commit the docs/script alignment:

```powershell
git add <only-related-files>
git commit -m "docs(phase5): verify mcp guard correlation candidate"
git push origin codex/live-agent-steering-ui-20260513
```

After push, inspect GitHub PR/CI and Vercel if relevant.

## GitHub / PR Context

Use the GitHub plugin/skill to inspect current PRs and CI after pushing.
Known active workflow target is the branch:

```text
codex/live-agent-steering-ui-20260513
```

Previous PR context in this project has used PR `#22`, but verify with GitHub before commenting or relying on it.

## Agent Lifecycle Status

All previously spawned agents were waited and closed before this checkpoint.

Closed agents:

- Planner: recommended MCP guard sweep, full suite/runtime selector, candidate gate rerun.
- Tester: identified missing docs/proof and stale candidate docs before the in-progress doc updates.
- DevOps: provided deploy guidance, but inspected before runtime commit and referenced old HEAD in its own notes.

No known active subagents remain.

## Start Prompt For New Chat

Copy this into the next chat:

```text
Use @github, @vercel, @openai-developers, @codex-security, @cloudflare, @hugging-face, and @browser-use only where useful. Work in D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM on branch codex/live-agent-steering-ui-20260513. First read docs\analysis\NEW_CHAT_RESUME_ANCHOR_2026-05-15_MCP_GUARD_CORRELATION_CHECKPOINT.md, then AGENTS.md, AI_HANDOFF.md, PROJECT_STATE.md, docs\project-progress.manifest.json, docs\verification-register.md, docs\release-artifacts\current-release-candidate.json, and docs\release-artifacts\prod-candidate-2026-05-11-rc1.md.

Continue autonomously from the checkpoint. True state: local runtime commit 4ce557f7e195846afa39d89861f296202561f34a exists and was built/pushed/deployed to hosted staging https://188-34-191-140.sslip.io, but the branch is still ahead 1 and has dirty docs/script alignment changes that need review, verification, commit, and push. Current progress: overall 82; H P0 100, P1 100, P2 89, P3 95, P4 100, P5 88, P6 0; V Frontend 99, Orchestrator 99, Agent Pool 76, LLM Gateway 67, MCP Gateway 68, Memory 74, Observability 99. Only this slice changed Phase 5 87->88 and MCP Gateway 67->68.

Do not claim production rollout, do not output secrets, do not download local models, do not stage unrelated files, and check Docker readiness only with docker info --format '{{.ServerVersion}}'. If spawning agents, never leave them running before final output. Start with git status --short, git diff --stat, manifest/release-candidate sanity, then rerun local and hosted MCP guard/full candidate verifiers, update docs only if needed, commit docs(phase5): verify mcp guard correlation candidate, push the branch, and report only changed percentages.
```
