# Historical Candidate Auth Gate Recheck — Security-Invalidated

Status: `security-invalidated`
disposition: `superseded`
superseded_by: `phase3-auth-credential-issuance-fail-closed-v1`
replacement_status: `implementation-present-verification-pending`
release_id: `prod-candidate-2026-05-05-rc1`
environment: `production-candidate`
base_url: `https://188-34-191-140.sslip.io`
executed_at_utc: `2026-05-07T09:05:00Z`
overall_percent: `70`
phase_4_percent: `100`
phase_5_percent: `67`
integrity_status: `verified`
auth_contract_version: `auth-github-jwt-refresh-v1`
live_github_oauth_call: `false`
owner_decision: `no-release`

## Security Invalidation Notice

This file preserves the May 2026 candidate record and its then-reported values for provenance only. It is not current auth evidence, does not contribute current Phase-3 or Phase-5 credit, and must not be linked as proof of release readiness or production identity. In particular, the historical dry-run callback issued credentials for arbitrary callback input; that behavior is security-invalid and is superseded by `phase3-auth-credential-issuance-fail-closed-v1`.

The historical metadata is intentionally not reinterpreted as today's progress. The original header recorded `phase_5_percent=67`, while the original hosted-truth section recorded `phase_5=63`; both values remain visible as historical provenance rather than being normalized into a new claim.

## Historical Goal

The artifact originally recorded one candidate-scoped auth and identity gate recheck so the release candidate would not rely only on older Phase-3 auth evidence. That goal is retained as history, not accepted as a current security conclusion.

## Historical Hosted Auth Recheck

The following observations were recorded at execution time and are retained only as historical claims:

- `GET /api/v1/auth/contract` was visible with `contract_version=auth-github-jwt-refresh-v1`.
- `GET /api/v1/auth/github` returned `status=configuration_required` without claiming live GitHub OAuth.
- `GET /api/v1/auth/callback?code=dry-run` issued dry-run auth tokens on the hosted candidate.
- `POST /api/v1/auth/refresh` rotated the supplied refresh token and blacklisted the old token.
- `POST /api/v1/auth/logout` cleared cookies and reported refresh-token revocation.

## Historical Hosted Truth Recheck

- `overall=70`
- `phase_4=100`
- `phase_5=63`
- `integrity=verified`
- `completion_can_set_all_to_100=false`
- `external_gates=verified`

## Why The Proof Is Invalid

- Arbitrary dry-run callback input was able to mint credentials without a one-time Redis-backed OAuth state and verified GitHub numeric identity.
- The refresh observation did not prove cookie-only input, membership in an active Redis registry, or transactional single-use consumption before rotation.
- The logout observation did not prove that only an active registered cookie token was revoked or that the audit event truthfully distinguished revocation from cookie clearing.
- The old proof therefore cannot validate the amended ADR-009 boundary or any current candidate.

## Replacement Boundary

`phase3-auth-credential-issuance-fail-closed-v1` requires one-time Redis OAuth state, verified positive numeric GitHub identity, the minimal `read:user` scope, strong configured signing before issuance, process-random fallback without issuance, `__Host-` cookies, callback error-cookie clearing, cookie-only active-registry refresh rotation, and truthful logout audit semantics. Implementation is present, but this historical artifact does not claim that focused, full-suite, hosted, or production verification has passed.

## Non-Claims

- This is not current Phase-3 or Phase-5 evidence.
- This is not a production identity proof.
- This does not claim live GitHub OAuth execution.
- This does not claim the replacement verifier or full suite is green.
- This does not override the historical or current `no-release` decision.
