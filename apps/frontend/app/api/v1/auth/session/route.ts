import { cookies } from "next/headers";
import {
  AUTH_SESSION_COOKIE,
  AUTH_SESSION_TTL_SECONDS,
  createSignedAuthSession,
  normalizeAuthIdentity,
  verifySignedAuthSession,
} from "../../../../../lib/authSession";
import { randomUUID } from "node:crypto";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

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

  const session = createSignedAuthSession(identity, randomUUID());
  const jar = await cookies();
  jar.set(AUTH_SESSION_COOKIE, session.token, {
    httpOnly: true,
    secure: true,
    sameSite: "strict",
    path: "/",
    maxAge: AUTH_SESSION_TTL_SECONDS,
    expires: new Date(session.claims.exp * 1000),
  });
  return Response.json(
    {
      status: "signed_in",
      session_id: session.claims.id,
      user: { name: session.claims.name, provider: session.claims.provider },
      persisted: false,
      session_scope: "signed_http_only_cookie",
      external_provider_write: false,
    },
    { headers: { "cache-control": "no-store", "x-superbrain-source": "auth-session-integrity" } },
  );
}

export async function GET(): Promise<Response> {
  const jar = await cookies();
  const verification = verifySignedAuthSession(jar.get(AUTH_SESSION_COOKIE)?.value);
  if (!verification.valid) {
    if (verification.reason !== "missing") jar.delete(AUTH_SESSION_COOKIE);
    return Response.json(
      { status: "anonymous", user: null, session_invalidated: verification.reason !== "missing" },
      { headers: { "cache-control": "no-store", "x-superbrain-source": "auth-session-integrity" } },
    );
  }
  return Response.json(
    {
      status: "signed_in",
      session_id: verification.claims.id,
      user: { name: verification.claims.name, provider: verification.claims.provider },
      expires_at: new Date(verification.claims.exp * 1000).toISOString(),
      session_scope: "signed_http_only_cookie",
    },
    { headers: { "cache-control": "no-store", "x-superbrain-source": "auth-session-integrity" } },
  );
}

export async function DELETE(): Promise<Response> {
  const jar = await cookies();
  jar.delete(AUTH_SESSION_COOKIE);
  return Response.json(
    { status: "signed_out", cookies_cleared: true },
    { headers: { "cache-control": "no-store", "x-superbrain-source": "auth-session-integrity" } },
  );
}
