# Phase 3 Auth Credential-Issuance Fail-Closed Contract

Contract: `phase3-auth-credential-issuance-fail-closed-v1`

Evidence markers:

- `auth_credential_issuance_fail_closed`
- `oauth_state_one_time_enforced`
- `refresh_token_registry_enforced`

## Security Boundary

The GitHub callback issues credentials only after all production configuration is present, a
cryptographically random OAuth state matches the `__Host-sb_oauth_state` cookie, that state is
atomically consumed once from Redis, and GitHub returns a verified numeric user id. Missing
configuration, arbitrary callback values, mismatched state, replayed state, failed code exchange,
and failed identity lookup issue no access or refresh credential. A configured OAuth start returns
an HTTP redirect to the fixed GitHub authorization endpoint with only `read:user`; it does not put
the state in a JSON body and does not follow a provider redirect on the backend. Callback failures
expire the OAuth-state cookie on the actual error response. Missing/oversized callback parameters
and provider-denial responses are validated inside the route after one-time state handling, so they
cannot escape cookie clearing through framework-level HTTP 422 validation.
OAuth state must match the exact ASCII URL-safe format `phase3-auth-state-<32_urlsafe_chars>`;
malformed/non-ASCII state is rejected before constant-time comparison. Provider token and identity
responses must be JSON objects, so valid-HTTP list/scalar payloads also fail closed.

Refresh tokens use `__Host-sb_refresh`, must exist in the Redis active-token registry, and are
consumed transactionally before rotation. Unknown, malformed, blacklisted, or replayed values
cannot mint a token. JSON-body refresh tokens are rejected so credentials remain cookie-bound.
Even a registered refresh token cannot mint credentials while the complete OAuth/JWT issuance
configuration is unavailable; that rejection occurs before consuming the active registry record.
Successful callback and refresh responses additionally require a persisted PostgreSQL audit event
before auth cookies are set. If that write fails, issuance returns HTTP 503, the unissued replacement
refresh record is deleted, and no access or refresh cookie is emitted. A refresh audit failure leaves
the already-consumed old token revoked rather than reopening it.
Logout revokes only an active registered cookie token and never claims that an arbitrary value was
revoked. Token values, OAuth code/state values, blacklist keys, and provider credentials are absent
from JSON/error response bodies and audit details. The one-time state appears only where the OAuth
protocol requires it: the GitHub authorization `Location` and the matching `__Host-` cookie.
Logout writes `auth_logout_revoked` only after an active registry token is consumed; missing,
unknown, or replayed tokens use `auth_logout_no_active_token` and never claim revocation.
The Agent API disables Uvicorn's raw request access log, and both Nginx runtime configurations log
only `$uri` without query arguments, preventing callback code/state from entering application or
reverse-proxy access output.

`JWT_SIGNING_SECRET` must be a non-placeholder URL-safe base64 value of 43 to 128 characters that
decodes to at least 32 bytes and passes the configured diversity floor. Without that strong secret,
signing uses a random process-local fallback while credential issuance remains disabled. Production
issuance additionally requires GitHub client id, client secret, and a valid HTTPS callback URI
(loopback HTTP is allowed only for development).

## Verification

`scripts/verify-phase3-auth-fail-closed.ps1` checks source guards, runs at least nineteen backend unit
tests, verifies one-winner OAuth-state and refresh consumption against real Redis under concurrency,
and probes the local runtime negative paths. Its runtime report is written to
`.codex/runs/CURRENT/phase3/auth-fail-closed/report.json` without credential material.

For a non-local HTTPS URL, the verifier is read-only: it reads only `/api/v1/auth/contract` and does
not start OAuth, invoke a callback, rotate a token, or log out a session. This contract-only result
does not prove hosted stateful auth or production identity.

Localhost evidence is `DEV-ONLY; hosted proof still blocked`. It does not prove an Owner-configured
production OAuth identity, make a GitHub OAuth call, expand scopes, write provider state, or close
the production auth gate.
