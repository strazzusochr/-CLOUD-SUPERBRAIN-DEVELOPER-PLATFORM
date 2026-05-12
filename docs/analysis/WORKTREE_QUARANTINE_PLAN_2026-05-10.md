# Worktree Quarantine Plan

Stand: 2026-05-10

Repo: `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`

## Purpose

This is a non-mutating quarantine and owner-review plan generated from the worktree cleanup plan.

It does not create directories, move files, delete files, unstage files, stage files, commit, push, or deploy.

## Verifier

```text
scripts\verify-worktree-quarantine-plan.ps1
```

Evidence artifact:

```text
.phase1-artifacts\worktree-quarantine-plan-20260510.json
```

Suite:

```text
scripts\verify.ps1 -Suite release-boundary -ReportOnly -MaxWaitSeconds 1
```

## Current Verdict

```text
status=quarantine-plan-blocked
recommended_first_strategy=cleanup-first-before-rebaseline
security_review=7
exclude_or_quarantine=9
split_required=8
```

## Quarantine Candidates

These paths are proposed for owner decision before any release scope inclusion:

```text
scripts/debug_hetzner_modal.py
scripts/debug_hetzner_ui.py
scripts/debug_vercel.py
scripts/extract_hetzner_data.py
scripts/list_hetzner_buttons.py
scripts/list_hetzner_keys.py
scripts/list_hetzner_servers_api.py
scripts/scan_hetzner.py
scripts/test_playwright.py
```

Default policy:

```text
exclude_from_release_scope_unless_explicitly_accepted
```

The generated artifact proposes destinations under:

```text
debug-artifacts/quarantine/2026-05-10/
```

No directory is created and no file is moved by the verifier.

## Security Review Paths

These paths require manual security review before staging or committing:

```text
docs/runbooks/cloud-secret-runtime-injection.md
scripts/secret_scan_fallback.py
docs/release-artifacts/prod-candidate-2026-05-05-rc1-secret-rotation-drill.md
docs/runbooks/secret-rotation.md
scripts/run-secret-scans.ps1
scripts/verify-all-gates-with-tokens.ps1
scripts/verify-phase5-secret-rotation-drill.ps1
```

Gate:

```text
security suite clean after review; no secret values in diff or artifacts
```

## Split-Required Paths

These paths are staged and modified at the same time and must be normalized before any commit boundary:

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

Gate:

```text
git status must show no staged-and-modified MM entries
```

## Leak Prevention

The generated JSON is path-only:

```text
file_contents_included=false
secret_values_included=false
tokens_included=false
env_values_included=false
path_only_artifact=true
```

## Policy Result

```text
mutates_repository=false
may_create_quarantine_directory=false
may_move=false
may_delete=false
may_unstage=false
may_stage=false
may_commit=false
may_push=false
may_deploy=false
```

## Non-Claims

- This document is not a cleanup execution.
- This document does not authorize deleting, moving, staging, committing, pushing, or deploying.
- This document does not contain file contents or secret values.
