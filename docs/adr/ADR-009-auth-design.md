# ADR-009 Auth Design For Owner-Gated Runtime

Status: Accepted
Date: 2026-04-29

## Context

The runtime already exposes an auth contract for GitHub OAuth, JWT access tokens, refresh-token rotation, Redis blacklist, logout revocation, and no-live-OAuth non-claims. The audit report still flagged auth design as an ADR gap because the boundary between local deterministic proof, hosted staging, and live credential activation was not captured as an architecture decision.

## Decision

Auth is owner-gated and fail-closed.

The platform uses the `auth-github-jwt-refresh-v1` contract for the planned live flow: GitHub OAuth produces short-lived access tokens, refresh tokens rotate on use, reused refresh tokens are blocked, logout revokes refresh tokens, and Redis stores blacklist state. Until the external auth gate is configured, the runtime may verify only deterministic contract behavior and must not claim a live GitHub OAuth exchange.

Access-token TTL is 900 seconds. Refresh-token TTL is 604800 seconds. Browser cookies must be `HttpOnly`, `Secure`, and `SameSite=Strict` for hosted operation.

## Rationale

This keeps auth aligned with the existing no-secret and no-live-provider gates while still allowing local contract verification. It also prevents local dry-run auth behavior from being mistaken for production identity assurance.

## Consequences

1. No hosted or production auth claim is valid without external secret gates.
2. Refresh-token reuse must remain a critical audit event.
3. Auth scope expansion requires an Owner/review gate.
4. Any move from owner-only auth to multi-user tenant auth requires a new ADR.

