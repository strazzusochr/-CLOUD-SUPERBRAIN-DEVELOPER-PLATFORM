import { cookies } from "next/headers";
import {
  AUTH_SESSION_COOKIE,
  AUTH_SESSION_TTL_SECONDS,
  createSignedAuthSession,
  isHostedAuthSessionToken,
  normalizeAuthIdentity,
  verifySignedAuthSession,
} from "../../../../../lib/authSession";
import {
  createHostedAuthSessionAtBoundary,
  isLocalDevelopmentRequest,
  revokeHostedAuthSessionAtBoundary,
  verifyHostedAuthSessionAtBoundary,
} from "../../../../../lib/frontendBoundary";
import { randomUUID } from "node:crypto";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

function unavailable(operation: "create" | "read" | "revoke"): Response {
  return Response.json(
    {
      status: "blocked",
      error: "hosted_session_boundary_unavailable",
      operation,
      accepted: false,
      persisted: false,
      cookies_cleared: false,
      external_provider_write: false,
      direct_provider_calls: false,
      live_mcp_writes: false,
      production_deploy: false,
      secret_output: false,
    },
    {
      status: 503,
      headers: {
        "cache-control": "no-store",
        "x-superbrain-source": "auth-session-stateful-boundary",
      },
    },
  );
}

async function setSessionCookie(token: string, expiresAtSeconds: number): Promise<void> {
  const jar = await cookies();
  jar.set(AUTH_SESSION_COOKIE, token, {
    httpOnly: true,
    secure: true,
    sameSite: "strict",
    path: "/",
    maxAge: AUTH_SESSION_TTL_SECONDS,
    expires: new Date(expiresAtSeconds * 1000),
  });
}

async function clearSessionCookie(): Promise<void> {
  const jar = await cookies();
  jar.set(AUTH_SESSION_COOKIE, "", {
    httpOnly: true,
    secure: true,
    sameSite: "strict",
    path: "/",
    maxAge: 0,
    expires: new Date(0),
  });
}

export async function POST(req: Request): Promise<Response> {
  let body: Record<string, unknown> = {};
  try { body = (await req.json()) as Record<string, unknown>; } catch { /* empty */ }
  const identity = normalizeAuthIdentity(body);
  if (!identity) {
    return Response.json(
      { status: "invalid_identity", error: "provider_or_name_invalid", allowed_providers: ["guest", "name"] },
      { status: 400, headers: { "cache-control": "no-store", "x-superbrain-source": "auth-session-integrity" } },
    );
  }

  const hostedSession = await createHostedAuthSessionAtBoundary(req, identity);
  if (hostedSession) {
    await setSessionCookie(hostedSession.token, hostedSession.claims.exp);
    return Response.json(
      {
        status: "signed_in",
        session_id: hostedSession.claims.id,
        user: { name: hostedSession.claims.name, provider: hostedSession.claims.provider },
        persisted: true,
        session_scope: "stateful_http_only_cookie",
        session_backend: "cloudflare-d1",
        token_storage: "sha256_only",
        external_provider_write: false,
        secret_output: false,
      },
      { headers: { "cache-control": "no-store", "x-superbrain-source": "auth-session-stateful-boundary" } },
    );
  }
  if (!isLocalDevelopmentRequest(req)) return unavailable("create");

  const session = createSignedAuthSession(identity, randomUUID());
  await setSessionCookie(session.token, session.claims.exp);
  return Response.json(
    {
      status: "signed_in",
      session_id: session.claims.id,
      user: { name: session.claims.name, provider: session.claims.provider },
      persisted: false,
      session_scope: "signed_http_only_cookie",
      session_backend: "local-hmac",
      external_provider_write: false,
      secret_output: false,
    },
    { headers: { "cache-control": "no-store", "x-superbrain-source": "auth-session-integrity" } },
  );
}

export async function GET(req: Request): Promise<Response> {
  const jar = await cookies();
  const token = jar.get(AUTH_SESSION_COOKIE)?.value;
  const verification = verifySignedAuthSession(token);
  if (verification.valid) {
    return Response.json(
      {
        status: "signed_in",
        session_id: verification.claims.id,
        user: { name: verification.claims.name, provider: verification.claims.provider },
        expires_at: new Date(verification.claims.exp * 1000).toISOString(),
        persisted: false,
        session_scope: "signed_http_only_cookie",
        session_backend: "local-hmac",
        external_provider_write: false,
        secret_output: false,
      },
      { headers: { "cache-control": "no-store", "x-superbrain-source": "auth-session-integrity" } },
    );
  }
  if (isHostedAuthSessionToken(token)) {
    const hostedSession = await verifyHostedAuthSessionAtBoundary(req, token);
    if (hostedSession.status === "unavailable") return unavailable("read");
    if (hostedSession.status === "valid") {
      return Response.json(
        {
          status: "signed_in",
          session_id: hostedSession.claims.id,
          user: { name: hostedSession.claims.name, provider: hostedSession.claims.provider },
          expires_at: new Date(hostedSession.claims.exp * 1000).toISOString(),
          persisted: true,
          session_scope: "stateful_http_only_cookie",
          session_backend: "cloudflare-d1",
          token_storage: "sha256_only",
          external_provider_write: false,
          secret_output: false,
        },
        { headers: { "cache-control": "no-store", "x-superbrain-source": "auth-session-stateful-boundary" } },
      );
    }
  }
  if (verification.reason !== "missing") await clearSessionCookie();
  return Response.json(
    {
      status: "anonymous",
      user: null,
      session_invalidated: verification.reason !== "missing",
      external_provider_write: false,
      secret_output: false,
    },
    { headers: { "cache-control": "no-store", "x-superbrain-source": "auth-session-integrity" } },
  );
}

export async function DELETE(req: Request): Promise<Response> {
  const jar = await cookies();
  const token = jar.get(AUTH_SESSION_COOKIE)?.value;
  if (isHostedAuthSessionToken(token)) {
    const registryResult = await revokeHostedAuthSessionAtBoundary(req, token);
    if (registryResult === "unavailable") return unavailable("revoke");
  }
  await clearSessionCookie();
  return Response.json(
    {
      status: "signed_out",
      cookies_cleared: true,
      session_registry_processed: isHostedAuthSessionToken(token),
      external_provider_write: false,
      secret_output: false,
    },
    { headers: { "cache-control": "no-store", "x-superbrain-source": "auth-session-integrity" } },
  );
}
