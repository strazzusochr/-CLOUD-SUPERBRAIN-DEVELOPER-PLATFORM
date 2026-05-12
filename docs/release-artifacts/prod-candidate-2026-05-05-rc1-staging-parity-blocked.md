# Executed Candidate Staging Tag Parity Blocker

Status: `blocked`
release_id: `prod-candidate-2026-05-05-rc1`
environment: `production-candidate`
base_url: `https://188-34-191-140.sslip.io`
executed_at_utc: `2026-05-09T12:20:00Z`
overall_percent: `70`
phase_4_percent: `100`
phase_5_percent: `67`
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
- Hosted progress remains `overall=70`, `phase_4=100`, `phase_5=67`.
- Hosted progress integrity remains `verified`.
- Hosted completion remains fail-closed with `can_set_all_to_100=false`.
- GHCR top-level digests for the mutable `:staging` tags were compared against the immutable candidate SHA tags for all six services.
- The cloud compose service hot-mounts are treated as a release blocker until the deploy path runs with image-contained service code via `-UseImageFilesystem`.
- Runtime source drift between the active repository/worktree and candidate source SHA remains a blocker until a new immutable candidate is built or the hosted runtime is deliberately moved to image-contained candidate code and reverified.
- Immutable SHA deploy plans are guarded: a 40-character SHA image tag is rejected unless it uses `-UseImageFilesystem` or a matching `-SourceRef`.
- Remote staging selector files are backed up before mutation and restored if copy, selector update, compose pull/up, or hosted health probes fail.
- Positive parity verification is prepared as an opt-in manual verifier in `scripts/manual/verify-phase5-staging-immutable-parity.ps1`; default mode proves readiness only, while `-RequireVerified` must be used after an actual immutable staging deploy.

## Live Digest Comparison

- `agent-api`: staging `sha256:1b3fcfbb6875ede2d3488171c8aeeefa4fff7ccc7e9b65af82b8dd159da94890` != immutable `sha256:48b66077a9f65cd788c069f7469b91ce0ed9fac0eed0cc42d8a0810b06d29ed4`
- `mcp-gateway`: staging `sha256:3b8e95d0a45f85d4cee4178d76751825d3484273309350c8da84b6119ca238bd` != immutable `sha256:cc177575a564491976c7894af19b9997785d86c1f950bb4a5c89bbab7f1fd2b0`
- `frontend`: staging `sha256:b5d023c8e40765c768676b4e923897e0f9df6aa664de0a0ddbdeaa21703cd668` != immutable `sha256:0200ddffb69e5efce034792a5f05440fb06f38bdfcdccc08a06b87b2bf361822`
- `llm-gateway`: staging `sha256:fc886b97d18fa8bf8eff4cdbb8b9d810fd0b267834ff55e4befeeda54b30f76c` != immutable `sha256:1c50fd9c5fc9880b7f890b689ed3ebaaafa048a98674da733c42551febed4a8f`
- `agent-worker`: staging `sha256:739d40ad26bdaccb475feed5d34e42b3bac8df2b84b9b112ecfa330e8e0d33b3` != immutable `sha256:b80215c7d9484ae30f42ccf44aa9fe537812b23d8c3f91d5db4a5b5495168add`
- `memory-worker`: staging `sha256:f5f508b520d446f379d4332119fa32ec1c400c84bc70c5f2cf6ee8a5eda797e1` != immutable `sha256:71b3e42646c36df03c37827364738b7eaa19b6cd18d7116c9748f1250a0bafd4`

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
