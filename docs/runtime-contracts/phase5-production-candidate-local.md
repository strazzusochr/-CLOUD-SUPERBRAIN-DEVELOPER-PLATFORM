# Phase 5 Local Production Candidate Contract

Status: `verified` locally

Contract: `phase5-production-candidate-local-v1`

Evidence ref: `phase5_local_production_candidate_verified`

Endpoint: `GET /api/v1/release-candidate/local/contract`

## Scope

The local candidate builder reads `source_commit_sha` from the active release artifact,
creates a Git archive for exactly that commit, and builds six production targets from
the extracted archive. Dirty and untracked worktree content is therefore excluded.

The report records the Git archive SHA256, local Docker image IDs, OCI source/revision/
version labels, Dockerfile hashes, embedded source-file hash parity, and the frontend
Next.js `BUILD_ID`. The dedicated verifier re-inspects the existing images, checks the
read-only API methods, and drives a real Chromium selection and click in Diagnostics.

## Evidence

- Candidate: `docs/release-artifacts/prod-candidate-2026-07-13-local-rc1.md`
- Builder: `scripts/build-phase5-production-candidate-local.ps1`
- Verifier: `scripts/verify-phase5-production-candidate-local.ps1`
- Report: `.codex/runs/CURRENT/master-goal/phase5/production-candidate-local/candidate-images.json`
- Verification: `.codex/runs/CURRENT/master-goal/phase5/production-candidate-local/verification.json`
- Screenshot: `.codex/runs/CURRENT/master-goal/phase5/production-candidate-local/diagnostics-phase5-production-candidate.png`

## Non-Claims

- DEV-ONLY; hosted proof still blocked.
- Local Docker image IDs are not GHCR digests.
- The planned GHCR tag set is unpublished.
- Hosted staging parity, Owner approval, production deploy, and release promotion are false.
- No registry push, provider write, live provider call, live MCP write, or secret output occurred.
