# Security Review Queue Snapshot Immutable Staging Proof

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
candidate_sha: `8fc8654f4a77a7b6705f351e060244bfc42d664e`
production_rollout_claimed: `false`

## Selector

- Hosted selector: `IMAGE_TAG=8fc8654f4a77a7b6705f351e060244bfc42d664e`
- Immutable tag set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:8fc8654f4a77a7b6705f351e060244bfc42d664e`
- Parity verifier: `scripts\verify-current-immutable-staging-parity.ps1 -RequireVerified`

## Security Review Queue Snapshot Evidence

- Local API/UI proof: `scripts\verify-phase3-security-review-queue.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Local browser proof: `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Hosted API/UI proof: `scripts\verify-phase3-security-review-queue.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Hosted browser proof: `scripts\verify-browser-contract.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Hosted smoke proof: `scripts\verify-hosted-staging-smoke.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Snapshot endpoint: `GET /api/v1/security/review-queue/snapshot`

## Evidence Refs

- `security_review_queue_visible`
- `security_review_item_visible`
- `security_review_filter_state_visible`
- `security_review_decision_history_visible`
- `security_review_evidence_snapshot_visible`
- `security_review_redaction_enforced`
- `security_review_mutation_blocked`

## Verified Fields

- Filter state is visible and bounded to `status`, `severity`, and `category`.
- Risk badges are visible for release-blocker, review-required, runtime-monitor, and monitor paths.
- Decision history is deterministic and includes reviewer/action/evidence refs without raw secret details.
- Evidence snapshots expose source/event/request/trace references and redaction policy, not payload secrets.

## Non-Claims

- No production rollout is claimed.
- No production tag promotion is claimed.
- No live provider call is claimed.
- No live MCP write is claimed.
- No secret payload, raw credential, screenshot, cookie, or prompt body exposure is claimed.
