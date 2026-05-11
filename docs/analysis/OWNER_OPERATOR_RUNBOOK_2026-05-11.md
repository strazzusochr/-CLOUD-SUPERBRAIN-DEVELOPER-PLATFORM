# Owner Operator Runbook

Stand: 2026-05-11

Repo: `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`

## Purpose

This runbook is the concrete operator path for clearing the current fail-closed state.

It is intentionally non-mutating. It does not grant cleanup, staging, commit, push, deployment, or release permission by itself.

## Current Truth

```text
truth_ready=false
status=blocked
release_boundary_clear=false
worktree_clean=false
owner_decision_valid=true
vercel_access_ready=true
security_passed=true
```

Current inventory:

```text
total_status_entries=272
staged_and_modified=0
staged=0
unstaged=50
untracked=222
```

## Hard Stop

Do not run any of these until the matching verification gate is green:

```text
git restore --staged .
git add
git commit
git push
vercel deploy
docker push
production deploy
release promotion
```

## Step 1 - Owner Decision File

Required file:

```text
docs\analysis\worktree-owner-decision-20260510.json
```

Template:

```text
docs\analysis\WORKTREE_OWNER_DECISION_TEMPLATE_2026-05-10.json
```

Schema:

```text
docs\analysis\WORKTREE_OWNER_DECISION_SCHEMA_2026-05-11.json
```

Allowed strategies:

```text
cleanup-first
evidence-only-rebaseline
runtime-rebaseline
defer
```

Current actionable strategy:

```text
cleanup-first
evidence-only-rebaseline
```

Hard-false fields:

```text
may_commit=false
may_push=false
may_deploy=false
```

Shape constraints:

```text
additional root properties are rejected
additional allowed_actions properties are rejected
additional scope properties are rejected
allowed_actions values must be booleans
scope values must be non-empty strings
decided_at must use UTC ISO-8601 seconds format
```

Verification:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-worktree-owner-decision.ps1 -ReportOnly
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-worktree-owner-action-packet.ps1 -ReportOnly
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-owner-decision-readiness-packet.ps1 -ReportOnly
```

Current state:

```text
owner_decision_valid=true
owner-decision-valid-mutation-authorized
owner-decision-packet-valid-ready
owner-decision-candidates-valid-ready
owner-action-packet-valid-ready
```

The verifier preserves `decided_at` as a JSON string during validation. PowerShell `DateTime` auto-conversion must not be allowed to turn valid UTC JSON into locale-specific text.

Required invariant:

```text
owner_decision_valid=true
```

Only continue if the verifier returns a valid owner decision.

## Step 2 - Resolve Security Review Paths

Source artifact:

```text
.phase1-artifacts\worktree-security-review-action-packet-20260511.json
```

Current count:

```text
security_review_action_count=0
baseline_hotspot_count=0
baseline_hotspot_finding_count=0
```

Required action:

Keep the security clearance artifact green. Re-run the security gate after any future change to secret-adjacent files. The detect-secrets baseline hotspots were cleared as path-only review work; do not copy values into notes.

Verification:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-worktree-security-review-action-packet.ps1 -ReportOnly
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1 -Suite security
```

Do not paste secret values, token values, environment values, or screenshot contents into review notes.

## Step 3 - Resolve Quarantine Paths

Source artifact:

```text
.phase1-artifacts\worktree-quarantine-action-packet-20260511.json
```

Current count:

```text
quarantine_action_count=0
```

Allowed handling per path:

```text
include
exclude
quarantine
defer
```

Verification:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-worktree-quarantine-action-packet.ps1 -ReportOnly
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-worktree-quarantine-plan.ps1 -ReportOnly
```

## Step 4 - Normalize Split Paths

Source artifact:

```text
.phase1-artifacts\worktree-split-action-packet-20260511.json
```

Current count:

```text
split_action_count=0
```

Current blocker:

```text
none
```

Required action:

For each split path, inspect staged and unstaged diffs, then choose exactly one reviewed state before any commit boundary.

Verification:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-worktree-split-action-packet.ps1 -ReportOnly
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-worktree-split-plan.ps1 -ReportOnly
```

## Step 5 - Clear Or Rebaseline Worktree Inventory

Source artifacts:

```text
.phase1-artifacts\worktree-change-inventory-20260510.json
.phase1-artifacts\worktree-cleanup-plan-20260510.json
.phase1-artifacts\worktree-review-action-matrix-20260511.json
.phase1-artifacts\worktree-cleanup-execution-plan-20260510.json
```

Current counts:

```text
review_action_matrix_batches=7
review_action_matrix_unique_paths=265
review_action_matrix_path_references=265
cleanup_candidate_actions=0
```

Required action:

Use the owner decision to either reduce inventory to zero through reviewed cleanup, or explicitly record an evidence/runtime rebaseline.

Verification:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-worktree-change-inventory.ps1 -ReportOnly
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-worktree-cleanup-plan.ps1 -ReportOnly
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-worktree-cleanup-execution-plan.ps1 -ReportOnly
```

## Step 6 - Resolve Vercel Project Visibility

Source artifacts:

```text
.phase1-artifacts\vercel-access-20260510.json
.phase1-artifacts\vercel-remediation-plan-20260511.json
```

Current blocker:

```text
classification=project_visible_with_configured_team
safe_to_deploy_via_vercel=true
```

Current remediation status:

```text
vercel-remediation-ready
```

Verification:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-vercel-access.ps1 -ReportOnly
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-vercel-remediation-plan.ps1 -ReportOnly
```

Do not write Vercel tokens into repo files, docs, logs, screenshots, or final reports.

## Step 7 - Choose Release Rebaseline Path

Source artifact:

```text
.phase1-artifacts\release-rebaseline-plan-20260511.json
```

Current blocker:

```text
current_head_does_not_match_candidate_source_sha
needs_rebaseline=true
```

Available options:

```text
keep-rc1-and-restore-head
create-new-candidate-from-current-head
evidence-only-rebaseline
runtime-rebaseline-after-clean-sweep
```

Verification:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-release-rebaseline-plan.ps1 -ReportOnly
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-worktree-release-boundary.ps1 -ReportOnly
```

## Step 8 - Final Gate Sweep

Run after every required item above is resolved:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1 -Suite security
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1 -Suite release-boundary -ReportOnly -MaxWaitSeconds 1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-release-boundary-regression.ps1 -ReportOnly
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-project-truth-state.ps1 -ReportOnly
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-project-truth-consistency.ps1 -ReportOnly
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-external-review-packet.ps1 -ReportOnly
```

Only if all relevant gates are green may an operator consider staging, commit, push, deployment, or release actions under the project approval rules.

## Non-Claims

- This runbook is not an approval.
- This runbook does not create or edit the owner decision file.
- This runbook does not execute cleanup.
- This runbook does not repair Vercel access.
- This runbook does not choose a release rebaseline path.
- This runbook does not stage, commit, push, deploy, or release.
