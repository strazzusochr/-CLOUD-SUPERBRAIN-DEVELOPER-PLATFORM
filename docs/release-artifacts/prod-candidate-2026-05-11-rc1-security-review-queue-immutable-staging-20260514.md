# Security Review Queue Immutable Staging Proof

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
candidate_sha: `70660b500748d5ac6b16d3c863408699029b1c0a`
production_rollout_claimed: `false`

## Selector

- Hosted selector: `IMAGE_TAG=70660b500748d5ac6b16d3c863408699029b1c0a`
- Immutable tag set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:70660b500748d5ac6b16d3c863408699029b1c0a`
- Parity verifier: `scripts\verify-current-immutable-staging-parity.ps1 -RequireVerified`

## Security Review Queue Evidence

- Local API/UI proof: `scripts\verify-phase3-security-review-queue.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Local browser proof: `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Hosted API/UI proof: `scripts\verify-phase3-security-review-queue.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Hosted browser proof: `scripts\verify-browser-contract.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Hosted smoke proof: `scripts\verify-hosted-staging-smoke.ps1 -BaseUrl https://188-34-191-140.sslip.io`

## Evidence Refs

- `security_review_queue_visible`
- `security_review_item_visible`
- `security_review_redaction_enforced`
- `security_review_mutation_blocked`

## Non-Claims

- No production rollout is claimed.
- No production tag promotion is claimed.
- No live provider call is claimed.
- No live MCP write is claimed.
- No secret payload, raw credential, screenshot, cookie, or prompt body exposure is claimed.
