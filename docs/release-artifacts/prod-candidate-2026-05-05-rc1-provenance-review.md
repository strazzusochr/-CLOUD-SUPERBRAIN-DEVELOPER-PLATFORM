# Executed Candidate Provenance Review

Status: `verified`
release_id: `prod-candidate-2026-05-05-rc1`
environment: `production-candidate`
base_url: `https://188-34-191-140.sslip.io`
executed_at_utc: `2026-05-07T08:45:00Z`
overall_percent: `70`
phase_4_percent: `100`
phase_5_percent: `67`
integrity_status: `verified`
external_gates_status: `verified`
owner_decision: `no-release`
source_commit_sha: `ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`
workflow_run_url: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25392582005`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`

## Goal

Record one fresh candidate-scoped provenance review that binds the successful workflow run, the immutable GHCR tag set, and the current fail-closed release state before any rollout claim, while explicitly preserving the blocked staging-parity state.

## Verification

- Candidate artifact still carries the successful workflow run URL.
- Candidate artifact still carries the immutable SHA tag set.
- Candidate artifact still carries the explicit staging-parity blocker proof.
- GHCR manifests for all six immutable SHA tags remain available.
- Hosted external gates remain `verified`.
- Hosted completion remains fail-closed with `can_set_all_to_100=false`.
- Hosted progress integrity remains `verified`.

## Results

- Provenance classification: `candidate_provenance_review`
- Current progress carried in review: `overall=70`, `phase5=67`
- Immutable candidate SHA remains bound to the candidate artifact: `yes`
- Multi-service GHCR immutable tag set remains available: `yes`
- Staging parity remains explicitly blocked: `yes`
- Production claim introduced: `no`

## Non-Claims

- This is not a production rollout proof.
- This does not claim a new workflow run.
- This does not claim hosted staging currently equals the immutable candidate tag set.
- This does not override the current `no-release` decision.
