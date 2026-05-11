# Release Rebaseline Plan

Stand: 2026-05-11

Repo: `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`

## Purpose

This gate turns the release candidate SHA mismatch into a concrete, reviewable owner decision.

It is intentionally non-mutating. It does not reset git, rewrite release artifacts, stage files, commit, push, deploy, or release.

## Verifier

```text
scripts\verify-release-rebaseline-plan.ps1
```

Evidence artifact:

```text
.phase1-artifacts\release-rebaseline-plan-20260511.json
```

Suite:

```text
scripts\verify.ps1 -Suite release-boundary -ReportOnly -MaxWaitSeconds 1
```

## Expected Current Verdict

```text
status=release-rebaseline-valid-blocked
valid=true
ready=false
needs_rebaseline=true
option_count=4
finding_count=0
```

## Current Problem

```text
current_head_does_not_match_candidate_source_sha
```

The current HEAD is not the same commit declared by the existing RC1 release artifact. Therefore, release truth cannot be claimed until the owner chooses a rebaseline path.

## Allowed Decision Paths

```text
keep-rc1-and-restore-head
create-new-candidate-from-current-head
evidence-only-rebaseline
runtime-rebaseline-after-clean-sweep
```

These are options for human/owner review. The verifier only documents them.

## Policy Result

```text
mutates_repository=false
executes_requested_actions=false
may_cleanup=false
may_stage=false
may_commit=false
may_push=false
may_deploy=false
may_release=false
```

## Non-Claims

- This plan does not choose a rebaseline strategy.
- This plan does not create or edit the owner decision file.
- This plan does not change the release candidate artifact.
- This plan does not modify the git worktree.
- This plan does not authorize deployment or release.
