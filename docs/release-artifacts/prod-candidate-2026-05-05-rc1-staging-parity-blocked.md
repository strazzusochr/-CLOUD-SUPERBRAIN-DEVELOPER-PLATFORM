# Executed Candidate Staging Tag Parity Blocker

Status: `blocked`
release_id: `prod-candidate-2026-05-05-rc1`
environment: `production-candidate`
base_url: `https://188-34-191-140.sslip.io`
executed_at_utc: `2026-05-14T00:05:00Z`
overall_percent: `71`
phase_4_percent: `100`
phase_5_percent: `69`
integrity_status: `verified`
owner_decision: `no-release`
current_hosted_selector: `IMAGE_TAG=staging`
immutable_candidate_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`
parity_classification: `blocked_staging_tag_parity`
service_hot_mount_parity: `blocked`
runtime_source_drift: `blocked`
immutable_image_filesystem_plan: `supported_by scripts/deploy-to-staging.ps1 -UseImageFilesystem -ImageTag ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`
positive_parity_verifier: `scripts/manual/verify-phase5-staging-immutable-parity.ps1 -RequireVerified`

## Goal

Record the current release-readiness blocker honestly: the active hosted selector still tracks the mutable `:staging` tag set, while the immutable candidate SHA tag set remains the only trustworthy rollback anchor.

This blocker is now classified wider than tag parity. The hosted cloud compose can hot-mount service source directories over container image code, so matching `IMAGE_TAG` alone is not sufficient evidence of immutable runtime parity.

## Verification

- Candidate rollback note still records that the hosted selector was restored to `IMAGE_TAG=staging`.
- The active integration smoke rerun still records `IMAGE_TAG=staging` as the current hosted selector.
- Hosted progress remains `overall=71`, `phase_4=100`, `phase_5=69`.
- Hosted progress integrity remains `verified`.
- Hosted completion remains fail-closed with `can_set_all_to_100=false`.
- GHCR top-level digests for the mutable `:staging` tags were compared against the immutable candidate SHA tags for all six services.
- Because `:staging` is retagged by every successful `main-deploy` run, the digest lines below are historical evidence. The verifier re-queries GHCR live and requires current `:staging` to remain different from the immutable candidate tag set.
- The cloud compose service hot-mounts are treated as a release blocker until the deploy path runs with image-contained service code via `-UseImageFilesystem`.
- Runtime source drift between the active repository/worktree and candidate source SHA remains a blocker until a new immutable candidate is built or the hosted runtime is deliberately moved to image-contained candidate code and reverified.
- Immutable SHA deploy plans are guarded: a 40-character SHA image tag is rejected unless it uses `-UseImageFilesystem` or a matching `-SourceRef`.
- Remote staging selector files are backed up before mutation and restored if copy, selector update, compose pull/up, or hosted health probes fail.
- Positive parity verification is prepared as an opt-in manual verifier in `scripts/manual/verify-phase5-staging-immutable-parity.ps1`; default mode proves readiness only, while `-RequireVerified` must be used after an actual immutable staging deploy.

## Observed Digest Comparison

- `agent-api`: staging `sha256:6eb738c883f6454b00c50c3370f8be00c170d94c4334c64c2b8755a1c8e44abb` != immutable `sha256:48b66077a9f65cd788c069f7469b91ce0ed9fac0eed0cc42d8a0810b06d29ed4`
- `mcp-gateway`: staging `sha256:fce0c4b6efebaab7d8b830c14782449b8f9a3672b1b03fabd45b62749c0cd84e` != immutable `sha256:cc177575a564491976c7894af19b9997785d86c1f950bb4a5c89bbab7f1fd2b0`
- `frontend`: staging `sha256:5313a825bcbafcc8dcd58051e30d03a7cacc403b2e2438470ee2db782781cb90` != immutable `sha256:0200ddffb69e5efce034792a5f05440fb06f38bdfcdccc08a06b87b2bf361822`
- `llm-gateway`: staging `sha256:a3481cbb2e0822a6d085f9248032a5bae739562a9179c3eeb02117eb2f52d1f1` != immutable `sha256:1c50fd9c5fc9880b7f890b689ed3ebaaafa048a98674da733c42551febed4a8f`
- `agent-worker`: staging `sha256:0db4219d4e9c33369634d97b085719f724797cbd32ccc120bf7ade88ac9f03ec` != immutable `sha256:b80215c7d9484ae30f42ccf44aa9fe537812b23d8c3f91d5db4a5b5495168add`
- `memory-worker`: staging `sha256:117f90324d9229c2c5278a88e857fe9cc1eb264553a0ab344b0a0594aecb5221` != immutable `sha256:71b3e42646c36df03c37827364738b7eaa19b6cd18d7116c9748f1250a0bafd4`

## Results

- Immutable candidate SHA remains available: `yes`
- Hosted staging selector remains mutable: `yes`
- Hosted staging digest parity to immutable candidate tag set: `blocked`
- Hosted service hot-mount parity to immutable candidate tag set: `blocked`
- Runtime source parity to immutable candidate source SHA: `blocked`
- Immutable image-filesystem staging deploy plan exists: `yes`
- Positive immutable staging parity verifier exists: `yes`
- Candidate remains fail-closed for release: `yes`
- Production claim introduced: `no`

## Non-Claims

- This is not a production rollout proof.
- This does not claim hosted staging currently equals the immutable candidate tag set.
- This does not claim hosted service source equals the immutable candidate source SHA.
- This does not override the current `no-release` decision.
