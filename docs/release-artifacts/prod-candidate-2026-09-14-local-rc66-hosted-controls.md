# RC66 hosted-controls evidence — P08

release_id: `prod-candidate-2026-09-14-local-rc66`
source_commit_sha: `4e0767eb4c284acc1ddc5d96808dc670958768d8`
control_commit_sha: `573116b18c4ab065e381bb5904a22287aa24b342`
immutable_image_commit_sha: `4e0767eb4c284acc1ddc5d96808dc670958768d8`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:4e0767eb4c284acc1ddc5d96808dc670958768d8`
immutable_tag_publish_status: `verified_candidate`
registry_publication_review: `docs/release-artifacts/prod-candidate-2026-09-14-local-rc66-evidence/registry/registry-publication-review.json`
registry_digest_contract: `docs/release-artifacts/prod-candidate-2026-09-14-local-rc66-evidence/registry/candidate-registry-digests.json`
registry_receipt_recovery: `docs/release-artifacts/prod-candidate-2026-09-14-local-rc66-evidence/registry/receipt-recovery-provenance.json`
registry_manifest: `docs/release-artifacts/prod-candidate-2026-09-14-local-rc66-evidence/registry/ghcr-candidate-manifest.json`
registry_remote_scan: `docs/release-artifacts/prod-candidate-2026-09-14-local-rc66-evidence/registry/remote-image-scan.json`
i1_hosted_candidate_parity: `docs/release-artifacts/prod-candidate-2026-09-14-local-rc66-evidence/i1/i1-hosted-candidate-parity.json`
frontend_hosted_current: `docs/release-artifacts/prod-candidate-2026-09-14-local-rc66-evidence/frontend/frontend-hosted-current.json`
frontend_browser_proof: `docs/release-artifacts/prod-candidate-2026-09-14-local-rc66-evidence/frontend/report.json`
frontend_verification: `docs/release-artifacts/prod-candidate-2026-09-14-local-rc66-evidence/frontend/verification.json`
frontend_alias_readback: `docs/release-artifacts/prod-candidate-2026-09-14-local-rc66-evidence/frontend/vercel-deployment-alias-readback.json`

P05 published six private GHCR images and twelve platform digests under the protected `registry-publication` environment. Main-deploy run `34911092680` and read-only recovery run `34916430966` are bound to control SHA `573116b...`; Trivy reports are critical=0, high=0, secrets=0.
P06 verified digest-only Codespaces parity with six healthy services, same-origin HTTPS, SSE, and zero registry/provider writes; the Codespace was stopped and port 8080 was returned to private.
P07 verified the Vercel production deployment `dpl_oEArn9VcPZU5nL3VaJeknJ64U2Hf`, canonical alias binding, 32 endpoint reads, and 26x2 Chrome route proof. The previous alias target `dpl_AZKFkveny2PZjteiCa8yqxrUkQUF` remains the rollback target.
The verifier compatibility note is narrow and provider-specific: Vercel promotion metadata reports `meta.action=promote`; the repository verifier currently accepts only `redeploy/cli`, so the readback was run with a temporary validation-only compatibility copy. No repository verifier or product code was changed.
This is tracked external-control evidence only. Phase 3 remains unchanged at 44, Phase 5 remains 17/19 and 89%, overall remains 90% / 1333 of 1400, I1/I5 credit remains unawarded, and `MARKET_READY:false` remains unchanged.
No secrets were written to evidence. No production OAuth identity, Cloudflare production runtime, gate promotion, release promotion, live provider call, or product release claim is made.

