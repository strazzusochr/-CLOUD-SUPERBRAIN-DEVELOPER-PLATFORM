# ADR-009 Auth Design For Owner-Gated Runtime

Status: Accepted (security amendment active)
Date: 2026-04-29
Security amendment: 2026-07-22

## Context

The runtime exposes the `auth-github-jwt-refresh-v1` surface for GitHub OAuth, short-lived access JWTs, refresh-token rotation, and logout. Earlier deterministic and hosted proofs accepted arbitrary callback values for dry-run credential issuance and treated blacklist-only refresh/logout behavior as sufficient. Those proofs are security-invalidated: a contract probe is not identity assurance, and an unknown token must never become a credential.

Live credential activation, secret use, auth-scope expansion, and production OAuth remain Owner/review-gated. Local or hosted contract visibility cannot open that gate.

## Decision

Auth is owner-gated and fail-closed. The binding credential-issuance decision is `phase3-auth-credential-issuance-fail-closed-v1`.

### OAuth start and callback

1. Production credential issuance requires all of the following: a strong configured JWT signing secret, GitHub client id and client secret, an allowed callback URI, a cryptographically random OAuth state, and a successful GitHub code exchange followed by identity lookup.
2. OAuth state is registered server-side in Redis with a bounded TTL, bound to the `__Host-sb_oauth_state` cookie, compared in constant time, and atomically consumed once. Missing, mismatched, expired, unknown, or replayed state issues no credential.
3. The callback accepts an identity only when GitHub returns a positive numeric user id. The local subject is derived from that immutable id; arbitrary code/state values or unverified profile data are never an identity source.
4. The requested GitHub OAuth scope is exactly `read:user`. `user:email`, repository access, organization access, or any other scope requires a separate Owner/review gate and an ADR update.
5. The state cookie is cleared on success and on every callback error response. The actual HTTP error response sent to the browser must carry the clearing `Set-Cookie`; mutating a response object that is discarded by exception handling is insufficient.

### Signing and cookies

1. A configured `JWT_SIGNING_SECRET` is accepted only as a non-placeholder URL-safe base64 value of 43 to 128 characters that decodes to at least 32 bytes and passes the diversity floor. Otherwise the process uses a cryptographically random, process-local signing fallback only for non-issuance contract isolation; credential issuance remains disabled.
2. Browser auth material is cookie-bound under the `__Host-` prefix: `__Host-sb_access`, `__Host-sb_refresh`, and `__Host-sb_oauth_state`. All use `Secure`, `HttpOnly`, `Path=/`, and no `Domain`; access and refresh use `SameSite=Strict`, while OAuth state uses `SameSite=Lax` for the provider redirect.
3. Access-token TTL is 900 seconds. Refresh-token TTL is 604800 seconds.

### Refresh and logout

1. A refresh token is valid only while its hash has an active Redis registry record bound to a verified `github:<numeric-id>` subject. Rotation atomically consumes that active record before issuing the replacement and blacklists the consumed token hash.
2. Unknown, malformed, blacklisted, replayed, or invalid-subject refresh tokens issue no credential. Refresh tokens are accepted only from `__Host-sb_refresh`; request-body refresh tokens are rejected.
3. Logout always clears browser auth cookies, but it revokes only an active registered cookie token. Audit event names and details must distinguish an actual revocation from cookie clearing, missing credentials, or rejection; an event named `auth_logout_revoked` is valid only when `refresh_token_revoked=true`.
4. Raw access/refresh tokens, OAuth code/state values, provider credentials, and derived Redis keys must not appear in JSON/error response bodies, application audit details, or evidence artifacts. OAuth state appears only in the protocol-required GitHub authorization `Location` and matching state cookie; auth code does not log or otherwise echo either value.
5. A successful callback or refresh response requires its PostgreSQL audit event to persist before auth cookies are set. Audit failure returns HTTP 503, removes the unissued replacement refresh record, emits no auth cookie, and never reactivates an already-consumed refresh token.

## Rationale

The decision separates deterministic contract verification from identity assurance. One-time state protects the OAuth redirect, GitHub's numeric id anchors the subject, the active registry makes refresh tokens server-revocable and single-use, and cookie-only transport reduces credential exposure. The random fallback avoids a shared development secret without accidentally authorizing issuance.

## Consequences

1. Missing or weak configuration, provider failure, or Redis state failure blocks credential issuance.
2. The historical dry-run callback and blacklist-only lifecycle proofs cannot support current Phase-3, candidate, hosted-auth, or production claims.
3. Production OAuth remains closed until the Owner supplies/approves the required credentials and callback configuration and the hosted verifier passes without scope expansion.
4. Any move from owner-only auth to multi-user tenant auth requires a new ADR.
5. Implementation and verification status are recorded separately in `docs/verification-register.md`; this accepted decision is not itself runtime proof.
