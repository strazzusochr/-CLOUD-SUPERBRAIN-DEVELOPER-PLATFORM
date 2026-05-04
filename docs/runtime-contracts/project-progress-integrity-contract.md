# Project Progress Integrity Contract

Status: implemented-local
Phase: Phase 4 / L-09
Contract version: `project-progress-integrity-v1`
Evidence: `project_progress_integrity_runtime_proof`

## Purpose

This contract prevents invented progress numbers from being accepted by the runtime surface. The Agent API exposes a deterministic integrity view that recomputes the total project percentage from the seven horizontal phase percentages in `docs/project-progress.manifest.json`.

## Runtime Endpoint

| Capability | Method | Path | Evidence |
| --- | --- | --- | --- |
| Progress integrity proof | `GET` | `/api/v1/project/progress/integrity` | `project_progress_integrity_runtime_proof` |

## Required Fields

- `contract_version`: `project-progress-integrity-v1`
- `status`: `verified` when no mismatch is found, otherwise `blocked`
- `guarded_endpoint`: `GET /api/v1/project/progress`
- `source_manifest`: `docs/project-progress.manifest.json`
- `manifest_overall_percent`: value published by the manifest
- `computed_overall_percent`: rounded average of the seven horizontal phases
- `horizontal_phase_count`: must be `7`
- `vertical_layer_count`: must be `7`
- `horizontal_phase_percentages`: phase id to percent map
- `vertical_layer_percentages`: layer id to percent map
- `mismatches`: machine-readable list of detected integrity failures

## Fail-Closed Rules

1. `overall_percent` must equal the rounded average of the seven horizontal phase percentages.
2. The progress source must remain `docs/project-progress.manifest.json`.
3. The binding document must remain `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md`.
4. Phase 4 must carry `project_progress_integrity_runtime_proof` once this L-09 proof is claimed.
5. Progress increases require code, runtime proof, verifier proof, and documentation update.

## Verifier Coverage

- `scripts/verify-browser-contract.ps1` asserts the endpoint, contract version, verified status, evidence ref, and manifest/computed percentage parity.
- `scripts/verify-hosted-staging.ps1` asserts the same contract through the hosted-staging/local-mirror proof path.
- `scripts/verify-phase1-runtime.ps1` asserts the same contract in the full runtime harness.
- `scripts/verify-phase1.ps1` statically guards the API, UI, verifier, and this document.

## Non-Claims

- This proof does not increase progress by itself.
- No live provider call is claimed.
- No hosted staging success is claimed without `STAGING_BASE_URL`.
- No production deployment is claimed.
