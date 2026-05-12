# Owner Operator Runbook - 2026-05-11

This runbook is not an approval. It records the current operator procedure and fail-closed controls for the active release-boundary candidate.

## Current State

```text
truth_ready=true
status=ready-for-next-gate
release_boundary_clear=true
release_id=prod-candidate-2026-05-11-rc1
owner_decision_valid=true
vercel_access_ready=true
security_passed=true
classification=project_visible_with_configured_team
```

## Fail-Closed Policy

```text
may_commit=false
may_push=false
may_deploy=false
may_release=false
```

Do not run `git restore --staged .`, `git add`, `git commit`, `git push`, `vercel deploy`, `docker push`, production deploy, or release promotion unless a later explicit owner-approved release procedure changes these policy values and records fresh evidence.

## Owner Decision Artifacts

```text
docs\analysis\worktree-owner-decision-20260510.json
docs\analysis\WORKTREE_OWNER_DECISION_TEMPLATE_2026-05-10.json
docs\analysis\WORKTREE_OWNER_DECISION_SCHEMA_2026-05-11.json
cleanup-first
create-new-candidate-from-current-head
runtime-rebaseline
defer
keep-rc1-and-restore-head
```

## Review And Cleanup Evidence

```text
.phase1-artifacts\worktree-review-action-matrix-20260511.json
.phase1-artifacts\worktree-quarantine-action-packet-20260511.json
.phase1-artifacts\worktree-split-action-packet-20260511.json
.phase1-artifacts\worktree-security-review-action-packet-20260511.json
.phase1-artifacts\vercel-remediation-plan-20260511.json
.phase1-artifacts\release-rebaseline-plan-20260511.json
review_action_matrix_batches=0
review_action_matrix_unique_paths=0
review_action_matrix_path_references=0
cleanup_candidate_actions=0
baseline_hotspot_count=0
detect-secrets baseline hotspots
```

## Required Checks

```text
scripts\verify.ps1 -Suite security
scripts\verify.ps1 -Suite release-boundary -ReportOnly -MaxWaitSeconds 1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-release-rebaseline-plan.ps1 -ReportOnly
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-worktree-release-boundary.ps1 -ReportOnly
```

## Operator Rules

- Keep `prod-candidate-2026-05-05-rc1` immutable as historical `no-release` evidence.
- Use `prod-candidate-2026-05-11-rc1` as the active release-boundary candidate.
- Treat `fc00a787b54399133a90158bb63f6228859b5c96` as the candidate source boundary commit.
- Treat `b0c2773b1d122745947315a8d39734d5a6c96d6b` as the candidate immutable image commit deployed to staging.
- Treat later verifier/docs-only commits as metadata wrappers only when the verifier reports `release_metadata_only_delta=true`.
- Remote immutable Hetzner parity is verified for staging after the image-filesystem deploy and `verify-phase5-staging-immutable-parity.ps1 -RequireVerified`.
- Do not claim production readiness from this runbook alone.
