# Security Review Gate Immutable Staging Proof

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
candidate_sha: `9f1e52266b3d9f9ddbdfc226d68bd2379ead9fad`
production_rollout_claimed: `false`
promotion_allowed: `false`

## Selector

- Hosted selector: `IMAGE_TAG=9f1e52266b3d9f9ddbdfc226d68bd2379ead9fad`
- Immutable tag set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:9f1e52266b3d9f9ddbdfc226d68bd2379ead9fad`
- Parity verifier: `scripts\verify-current-immutable-staging-parity.ps1 -RequireVerified`

## Security Review Gate Evidence

- Local API/UI proof: `scripts\verify-phase3-security-review-gate.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Local browser proof: `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Hosted API/UI proof: `scripts\verify-phase3-security-review-gate.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Hosted browser proof: `scripts\verify-browser-contract.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Hosted smoke proof: `scripts\verify-hosted-staging-smoke.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Gate endpoint: `GET /api/v1/security/review-queue/gate`

## Evidence Refs

- `security_review_gate_summary_visible`
- `security_review_queue_visible`
- `security_review_evidence_snapshot_visible`
- `security_review_redaction_enforced`
- `security_review_mutation_blocked`

## Verified Fields

- `gate_status=blocked_by_open_security_reviews` after CSP verifier seed creates a redacted needs-review audit row.
- `blocker_count` is visible and derived from read-only queue items.
- `production_rollout_claimed=false` and `promotion_allowed=false` are explicit.
- Blockers expose request/trace/evidence refs without raw audit details or secret payloads.

## Non-Claims

- No production rollout is claimed.
- No production release approval is granted.
- No live provider call is claimed.
- No live MCP write is claimed.
- No secret payload, raw credential, screenshot, cookie, or prompt body exposure is claimed.
