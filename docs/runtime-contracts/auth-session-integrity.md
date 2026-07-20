# Auth Session Integrity

Contract: `auth-session-integrity-v1`

The local login surface issues a signed HttpOnly cookie through
`POST /api/v1/auth/session`. The cookie payload contains a bounded local identity,
a random session identifier, issued-at time, and fixed expiry. `GET` accepts the
session only when its HMAC-SHA256 signature and claims are valid and the expiry is
still in the future.

## Guards

- Cookie: `__Host-sb_session`, `HttpOnly`, `Secure`, `SameSite=Strict`, path `/`.
- HMAC signatures are compared with a constant-time check.
- Malformed, modified, future-issued, and expired sessions are rejected.
- Rejected cookies are deleted and their values are never returned.
- Providers are limited to local `guest` and `name` identities.
- The route performs no GitHub, database, cloud, provider, or MCP write.
- `AUTH_SESSION_SECRET` must contain at least 32 bytes for restart-stable sessions.
  Without it, a process-local random secret deliberately invalidates sessions on
  restart instead of using a hard-coded production secret.

The read-only contract is exposed at
`GET /api/v1/auth/session/contract`. Deterministic Node tests cover valid,
tampered, expired, future-issued, malformed, and unsupported-provider paths. A
real Chromium proof signs in through `/login`, inspects cookie flags, tampers the
cookie, and verifies fail-closed invalidation.

## Non-Claims

This is `DEV-ONLY`; hosted proof still remains separate. It does not prove OAuth
identity ownership, a production authentication deployment, persistent
server-side sessions, a live provider call, a provider write, a live MCP write,
or release promotion.
