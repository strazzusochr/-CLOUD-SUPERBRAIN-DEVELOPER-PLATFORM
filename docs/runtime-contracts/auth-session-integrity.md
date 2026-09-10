# Auth Session Integrity

Contracts: `auth-session-integrity-v1` and `cloudflare-d1-hosted-session-v1`

The login surface issues an HttpOnly cookie through `POST /api/v1/auth/session`.
On localhost, the cookie contains a bounded local identity signed with
HMAC-SHA256. On a hosted origin, the frontend obtains a 256-bit opaque credential
from the authenticated Cloudflare runtime and stores only that credential in the
HttpOnly cookie. D1 stores its SHA-256 digest, session claims, expiry, and
revocation state; it never stores the raw credential.

## Guards

- Cookie: `__Host-sb_session`, `HttpOnly`, `Secure`, `SameSite=Strict`, path `/`.
- HMAC signatures are compared with a constant-time check.
- Malformed, modified, future-issued, and expired sessions are rejected.
- Rejected cookies are deleted and their values are never returned.
- Providers are limited to local `guest` and `name` identities.
- `AUTH_SESSION_SECRET` must contain at least 32 bytes for restart-stable sessions.
  Without it, a process-local random secret deliberately invalidates sessions on
  restart instead of using a hard-coded production secret.
- Hosted origins never fall back to the process-local signer. Creation,
  verification, and revocation fail closed when the authenticated D1 boundary is
  unavailable.
- The server-only `AGENT_API_AUTH_TOKEN` protects the Cloudflare session
  endpoints and is removed from browser-facing requests and responses.
- Session creation and revocation are atomic with redacted audit events.
- The hosted adapter uses D1 only: no R2, payment method, new auth secret,
  external identity provider, LLM provider, or MCP write.

The read-only contract is exposed at
`GET /api/v1/auth/session/contract`. Deterministic Node tests cover local signed
sessions and strict hosted-envelope parsing. Cloudflare runtime tests cover an
authenticated create/verify/revoke roundtrip, hash-only storage, invalid
credentials, and audit-atomic failure. A real Chromium proof signs in through
`/login` and inspects the cookie flags.

## Non-Claims

The HMAC browser proof remains `DEV-ONLY`; hosted product acceptance is a
separate verifier result. Neither adapter proves OAuth identity ownership,
production authentication, a live provider call, a provider write, a live MCP
write, or release promotion.
