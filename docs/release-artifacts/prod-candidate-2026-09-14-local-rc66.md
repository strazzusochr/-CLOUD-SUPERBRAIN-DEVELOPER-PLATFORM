# Release Artifact — local RC66 source-qualified candidate

release_id: `prod-candidate-2026-09-14-local-rc66`
scope: `source-qualified no-release candidate`
environment: `production-candidate`
source_branch: `codex/rc66-source-prequal`
source_commit_sha: `4e0767eb4c284acc1ddc5d96808dc670958768d8`
source_commit_semantics: `RC66 source candidate; direct-child qualification 51626aeadba3a33b8e5f0c61960dbd08a7a39387 changes only source-qualification-control.json`
immutable_image_commit_sha: `4e0767eb4c284acc1ddc5d96808dc670958768d8`
source_attestation_control_sha: `51626aeadba3a33b8e5f0c61960dbd08a7a39387`
source_archive_sha256: `f3ef6a2b861186a26b9c14895c92ec5d9031355b7f2f4bf433dad49d24ec178e`
workflow_run_url: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/34898119611`
pipeline_status: `success; source prequalification passed; failed=0; skipped=0; secret_scan=true; provider_writes=false`
local_validation_status: `six candidate images built from the committed RC66 archive; runtime proof and external publication remain pending`
security_validation: `source qualification CI passed syntax, security and supply-chain checks; no secret output`
smoke_result: `not claimed; hosted parity is not claimed`
rollback_note: `RC63 remains the last published rollback predecessor; no hosted rollback is authorized`
rollback_target_commit_sha: `63c854867cb1082c209718b64fddcbb52e5dd99b`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:4e0767eb4c284acc1ddc5d96808dc670958768d8`
immutable_tag_publish_status: `unpublished`
review_gate: `pending`
owner_decision: `no-release`
hosted_staging_parity: `false`
production_rollout_claimed: `false`
checklist_verified_count: `19`
checklist_blocked_count: `0`
phase5_computed_percent: `100`

## Qualification boundary

RC66 is source-qualified by GitHub Actions run 34898119611. The run checked
the exact source candidate 4e0767eb4c284acc1ddc5d96808dc670958768d8 and the
direct-child control commit 51626aeadba3a33b8e5f0c61960dbd08a7a39387. The
candidate images are local, immutable-tag builds only. GHCR publication,
hosted parity, production OAuth and release promotion remain separate gates.

- Current project truth remains verifier-computed at `100%` and `1400/1400`.
- This artifact does not claim a production rollout.
- Production deployment still requires the release-candidate gate bundle and a separate rollout proof.
- No production deploy, release promotion, provider-scope expansion, secret mutation, secret output, or percentage credit is claimed.
