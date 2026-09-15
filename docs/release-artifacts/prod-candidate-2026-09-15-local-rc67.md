# Release Artifact — local RC67 source-qualified successor candidate

release_id: `prod-candidate-2026-09-15-local-rc67`
scope: `source-qualified no-release candidate`
environment: `production-candidate`
source_branch: `codex/rc67-source-prequal`
source_commit_sha: `987871c40d603ba4d3ba93752df14d5fcd53d3cd`
source_commit_semantics: `RC67 successor candidate; direct-child qualification control a952755669a979a619799bdd9e500e38448ee53d changes only source-qualification-control.json`
immutable_image_commit_sha: `987871c40d603ba4d3ba93752df14d5fcd53d3cd`
source_attestation_control_sha: `a952755669a979a619799bdd9e500e38448ee53d`
source_archive_sha256: `740d03442a5a3391b39f9b0f7de908bf709d5289dad184c905cf4222c434d37f`
local_candidate_evidence: `.codex/runs/RC67/production-candidate-local/candidate-images.json`
local_validation_status: `six candidate images built from the committed RC67 source archive; hosted parity and external publication remain pending`
security_validation: `source qualification control and Cloudflare production OAuth ValidateOnly preflight passed; no secret output`
smoke_result: `not claimed; hosted parity is not claimed`
rollback_note: `RC63 remains the last published rollback predecessor; no hosted rollback is authorized`
rollback_target_commit_sha: `0e9c680c191927dc352c96d119fc909c7d842296`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:987871c40d603ba4d3ba93752df14d5fcd53d3cd`
immutable_tag_publish_status: `unpublished`
review_gate: `pending`
owner_decision: `no-release`
hosted_staging_parity: `false`
production_rollout_claimed: `false`
checklist_verified_count: `19`
checklist_blocked_count: `0`
phase5_computed_percent: `89`

## Qualification boundary

RC67 is a source-qualified successor candidate. The immutable source is `987871c40d603ba4d3ba93752df14d5fcd53d3cd`; the direct-child control commit is `a952755669a979a619799bdd9e500e38448ee53d`. The six images are local, immutable-tag builds only. GHCR publication, hosted parity, production OAuth and release promotion remain separate gates.

The active project pointer remains RC63/S16 until a reviewed successor control is merged. No percentage credit, `MARKET_READY` promotion, production deployment, registry publication, secret mutation, or provider-scope expansion is claimed.
