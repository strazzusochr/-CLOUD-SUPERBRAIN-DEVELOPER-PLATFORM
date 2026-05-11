# Worktree Release Boundary

Stand: 2026-05-10

Repo: `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`

## Purpose

This document records the current Git/worktree release boundary without changing staged files, unstaging files, committing, pushing, or deploying.

It exists because the repository currently contains many modified and untracked files, including files that are already staged and then modified again. That state must be visible before any release, deploy, or commit boundary is claimed.

## Current Verdict

Release boundary is blocked.

Evidence artifact:

```text
.phase1-artifacts\worktree-release-boundary-20260510.json
```

Verifier:

```text
scripts\verify-worktree-release-boundary.ps1
```

Suite:

```text
scripts\verify.ps1 -Suite release-boundary -ReportOnly -MaxWaitSeconds 1
```

## What Was Verified

Candidate:

```text
release_id=prod-candidate-2026-05-05-rc1
candidate_source_sha=ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5
owner_decision=no-release
```

Current repo:

```text
current_head_sha=2a1e4c71700ebad30759cc2211f8f5fa159bf781
head_matches_candidate=false
worktree_clean=false
release_boundary_clear=false
```

Observed status counts:

```text
total_status_entries=254
staged=10
unstaged=44
untracked=208
staged_and_modified=8
risky_artifact_paths=0
```

Staged and modified at the same time:

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

## Blockers

```text
current_head_does_not_match_candidate_source_sha
worktree_is_dirty
staged_changes_present
unstaged_changes_present
untracked_files_present
same_files_are_staged_and_modified
owner_decision_not_approved_in_candidate_artifact
```

## Policy Result

```text
may_stage_or_commit=false
may_release=false
may_deploy_production=false
```

This does not mean no future commit is possible. It means the current workspace cannot be treated as a release boundary until a deliberate rebaseline or cleanup strategy is chosen and verified.

## Pass Criteria

The boundary is clear only when:

1. Current `HEAD` matches the intended candidate source SHA, or a new candidate artifact is created for the current `HEAD`.
2. `git status --porcelain=v1` is clean.
3. No file is both staged and modified.
4. The candidate artifact has `owner_decision=approved`.
5. Security gates remain clean.
6. Vercel either passes its project/team visibility gate or is explicitly documented as a non-claim.

## Non-Claims

- This document does not clean the worktree.
- This document does not authorize staging, commit, push, deploy, or production release.
- This document does not contain diff contents or secret values.
