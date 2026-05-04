# Project Progress 100 Percent Completion Contract

Stand: 2026-04-30

Contract: `project-progress-100-percent-contract-v1`
Evidence: `project_progress_100_percent_gate_contract`
Endpoint: `GET /api/v1/project/progress/completion`

## Purpose

This contract is the fail-closed gate for requests to set all horizontal phases and vertical layers to `100%`.

It does not raise progress by itself. It reads the canonical manifest-backed project progress, mirrors external proof gates, and reports whether a 100-percent claim is currently allowed.

## Required Behavior

- `can_set_all_to_100` must remain `false` while any external proof gate is missing.
- `status` must be `blocked_external_gates` when hosted staging, branch protection, canonical secret scan, or live budget proof gates are missing.
- `missing_external_gates` must list missing gate IDs from `GET /api/v1/external-gates`.
- `missing_external_gate_blockers` must name the corresponding blocker strings, including `hosted_staging_proof_requires_STAGING_BASE_URL` and `production_release_requires_hosted_staging_branch_protection_secret_scan_and_owner_review` when applicable.
- `hard_blockers` must include `local_progress_gaps_require_verified_evidence_for_each_phase_and_layer` while any phase or layer is still below `100%`.
- Phase and layer records must expose current percent, target percent, remaining percent, status, blockers, and next safe action.

## Non-Claims

- No hosted staging success without `STAGING_BASE_URL`.
- No protected-main success without `BRANCH_PROTECTION_TOKEN` or equivalent GitHub token.
- No canonical gitleaks success without the `gitleaks` binary.
- No live infrastructure budget refresh without `HETZNER_API_TOKEN`.
- No production deployment, live LLM provider calls, or live MCP writes from this contract.

## Verifier Coverage

- Static: `scripts/verify-phase1.ps1`
- Browser contract: `scripts/verify-browser-contract.ps1`
- Hosted HTTP contract: `scripts/verify-hosted-staging.ps1`
- Full runtime: `scripts/verify-phase1-runtime.ps1`
