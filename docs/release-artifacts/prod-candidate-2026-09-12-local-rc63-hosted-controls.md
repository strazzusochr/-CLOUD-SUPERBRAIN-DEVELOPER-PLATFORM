# RC63 hosted-controls evidence — P08

release_id: `prod-candidate-2026-09-12-local-rc63`
source_commit_sha: `0e9c680c191927dc352c96d119fc909c7d842296`
immutable_image_commit_sha: `0e9c680c191927dc352c96d119fc909c7d842296`
control_commit_sha: `b5b5429df5b9504e9d10f005ff7ab2e52c902843`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:0e9c680c191927dc352c96d119fc909c7d842296`
immutable_tag_publish_status: `verified_candidate`
registry_publication_review: `docs/release-artifacts/prod-candidate-2026-09-12-local-rc63-evidence/registry/registry-publication-review.json`
registry_digest_contract: `docs/release-artifacts/prod-candidate-2026-09-12-local-rc63-evidence/registry/candidate-registry-digests.json`
registry_receipt_recovery: `docs/release-artifacts/prod-candidate-2026-09-12-local-rc63-evidence/registry/receipt-recovery-provenance.json`

P05 published six private GHCR images and twelve platform digests under the
protected `registry-publication` environment. Recovery Run 34768138336 rebuilt
the receipt read-only. All scan tuples are `critical=0`, `high=0`, `secret=0`.
This is tracked external-control evidence only: Phase 5 remains `17/19`, `89%`,
I1/I5 remain open, and `MARKET_READY:false` remains unchanged.