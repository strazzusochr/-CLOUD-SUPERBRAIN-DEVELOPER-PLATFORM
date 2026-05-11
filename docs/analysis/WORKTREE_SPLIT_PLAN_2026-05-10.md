# Worktree Split Plan

Stand: 2026-05-10

Repo: `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`

## Purpose

This gate turns the `MM` worktree condition into a path-only, non-mutating review plan.

`MM` means a file has staged content and additional unstaged worktree changes. That state is unsafe for release cutting because a commit can accidentally capture only one half of the real working state.

## Verifier

```text
scripts\verify-worktree-split-plan.ps1
```

Evidence artifact:

```text
.phase1-artifacts\worktree-split-plan-20260510.json
```

Suite:

```text
scripts\verify.ps1 -Suite release-boundary -ReportOnly -MaxWaitSeconds 1
```

## Expected Current Verdict

```text
status=split-plan-blocked
clear=false
split_path_count=8
```

## Current Split Paths

```text
docs/runbooks/README.md
scripts/deploy-to-staging.ps1
scripts/verify-browser-contract.ps1
scripts/verify-external-gates.ps1
scripts/verify-hosted-staging.ps1
scripts/verify-phase1-runtime.ps1
scripts/verify-phase1.ps1
scripts/verify-phase5-candidate.ps1
```

## Dry-Run Command Shape

For each path, the artifact emits command examples only:

```text
git diff --cached -- '<path>'
git diff -- '<path>'
git restore --staged -- '<path>'
git add -- '<path>'
```

The verifier never executes those commands.

## Policy Result

```text
mutates_repository=false
executes_requested_actions=false
may_unstage=false
may_stage=false
may_commit=false
may_push=false
may_deploy=false
may_release=false
```

## Non-Claims

- This gate does not normalize the worktree.
- This gate does not unstage files.
- This gate does not stage files.
- This gate does not approve commit, push, deployment, or release.
- The owner decision file is still required before any cleanup or commit boundary.
