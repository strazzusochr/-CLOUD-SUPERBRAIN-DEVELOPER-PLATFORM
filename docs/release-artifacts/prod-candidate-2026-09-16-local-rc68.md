# Release Artifact — local RC68 source-qualified successor candidate

release_id: `prod-candidate-2026-09-16-local-rc68`
scope: `source-qualified no-release candidate`
environment: `production-candidate`
source_branch: `codex/rc68-source-prequal`
source_commit_sha: `10bccfcfb5a62c6883c7162b8b2eed4f3da817ff`
source_commit_semantics: `RC68 successor candidate; direct-child qualification control 15b850fe03f07667e24a9a94987c1eab0fffa415 changes only source-qualification-control.json`
immutable_image_commit_sha: `10bccfcfb5a62c6883c7162b8b2eed4f3da817ff`
source_attestation_control_sha: `15b850fe03f07667e24a9a94987c1eab0fffa415`
source_archive_sha256: `352429b3a637112f34e7821eb89987d5e384e0e9de9c20168496747f80ce55a9`
review_gate: `pending`
owner_decision: `no-release`
hosted_staging_parity: `false`
production_rollout_claimed: `false`
percentage_credit_awarded: `0`
project_overall_percent: `90`
phase5_items: `17/19; I1 and I5 remain blocked until fresh RC68 evidence exists`

## Qualification boundary

RC68 is required because PR #142 changed browser-verifier logic. The immutable
source is `10bccfcfb5a62c6883c7162b8b2eed4f3da817ff`; the direct-child control
commit is `15b850fe03f07667e24a9a94987c1eab0fffa415`. RC67 evidence remains
historical and may be reused only when the responsible verifier proves forward
binding to RC68. No percentage credit, `MARKET_READY` promotion, production
deployment, registry publication, secret mutation, or provider-scope expansion
is claimed.
