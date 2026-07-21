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
Runtime integration may use `-SkipBrowser`, but that bounded run writes a separate
`verification-runtime.json`; it cannot replace or downgrade the canonical full-browser
`verification.json`.

The current-candidate boundary verifier treats technical candidate verification and
promotion eligibility as separate claims. Its hosted external-gate expectation follows
the canonical sanitized summary. A blocked canonical summary can therefore verify the
candidate boundary while promotion remains explicitly false.

The active RC3 additionally requires no committed drift from its source commit to HEAD
across the six service source trees, the root Docker context policy, the canonical progress
manifest, external-gate state, and autonomous roster. The Vercel Contract Origin is checked
against its own source-bound progress snapshot, not falsely against a newer local manifest.
This freshness repair carries no additional percentage credit.

## Evidence

- Candidate: `docs/release-artifacts/prod-candidate-2026-07-21-local-rc3.md`
- Builder: `scripts/build-phase5-production-candidate-local.ps1`
- Verifier: `scripts/verify-phase5-production-candidate-local.ps1`
- Report: `.codex/runs/CURRENT/master-goal/phase5/production-candidate-local/candidate-images.json`
- Verification: `.codex/runs/CURRENT/master-goal/phase5/production-candidate-local/verification.json`
- Runtime-only verification: `.codex/runs/CURRENT/master-goal/phase5/production-candidate-local/verification-runtime.json`
- Screenshot: `.codex/runs/CURRENT/master-goal/phase5/production-candidate-local/diagnostics-phase5-production-candidate.png`
- Candidate report SHA-256: `D1FCBD53D601B4BEE726F57B6EE12426B8DED130C4023A898D97846CB8513FBD`
- Full verification SHA-256: `E5361F5E0B888C69C31DA4F0EEAC8B2C115FFB690C26816CDBC23D3577DB9A61`

## Non-Claims

- DEV-ONLY; hosted proof still blocked.
- Local Docker image IDs are not GHCR digests.
- The planned GHCR tag set is unpublished.
- Hosted staging parity, Owner approval, production deploy, and release promotion are false.
- No registry push, provider write, live provider call, live MCP write, or secret output occurred.
