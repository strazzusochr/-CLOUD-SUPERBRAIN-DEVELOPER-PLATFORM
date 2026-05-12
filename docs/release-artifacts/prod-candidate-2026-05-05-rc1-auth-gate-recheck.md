# Executed Candidate Auth Gate Recheck

Status: `verified`
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

## Goal

Record one candidate-scoped auth and identity gate recheck so the release candidate no longer relies only on older Phase-3 auth evidence.

## Hosted Auth Recheck

- `GET /api/v1/auth/contract` remains visible with `contract_version=auth-github-jwt-refresh-v1`.
- `GET /api/v1/auth/github` remains fail-closed and returns `status=configuration_required` without claiming live GitHub OAuth.
- `GET /api/v1/auth/callback?code=dry-run` still issues dry-run auth tokens on the hosted candidate.
- `POST /api/v1/auth/refresh` still rotates the refresh token and blacklists the old token.
- `POST /api/v1/auth/logout` still clears cookies and revokes the refresh token.

## Hosted Truth Recheck

- `overall=70`
- `phase_4=100`
- `phase_5=63`
- `integrity=verified`
- `completion_can_set_all_to_100=false`
- `external_gates=verified`

## Non-Claims

- This is not a production identity proof.
- This does not claim live GitHub OAuth execution.
- This does not override the current `no-release` decision.
