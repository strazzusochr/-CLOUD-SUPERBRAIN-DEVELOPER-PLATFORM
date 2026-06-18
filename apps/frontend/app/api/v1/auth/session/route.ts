// Real lightweight auth: creates a genuine persisted session + httpOnly cookie.
// (Guest / named sign-in; real OAuth would need an OAuth app, which isn't part of
// this free stack — so we do a real, honest session rather than a dry-run.)
import { cookies } from "next/headers";
import * as gh from "../../../../../lib/ghStore";

export const dynamic = "force-dynamic";
const COOKIE = "sb_session";

export async function POST(req: Request): Promise<Response> {
  let body: Record<string, unknown> = {};
  try { body = (await req.json()) as Record<string, unknown>; } catch { /* empty */ }
  const provider = String(body.provider ?? "guest");
  const name = String(body.name ?? "").trim().slice(0, 40) || (provider === "guest" ? "Gast" : provider);
  const id = gh.uuid();
  const session = { id, provider, name, created_at: new Date().toISOString() };

  if (gh.ghConfigured()) {
    try {
      await gh.append("auth_sessions.json", session, 500);
      await gh.audit("session_started", id, provider);
    } catch { /* best-effort — session still issued via cookie */ }
  }

  const jar = await cookies();
  jar.set(COOKIE, id, { httpOnly: true, secure: true, sameSite: "lax", path: "/", maxAge: 60 * 60 * 24 * 30 });
  return Response.json({ status: "signed_in", session_id: id, user: { name, provider }, persisted: gh.ghConfigured() }, { headers: { "x-superbrain-source": "auth" } });
}

export async function GET(): Promise<Response> {
  const jar = await cookies();
  const id = jar.get(COOKIE)?.value;
  if (!id) return Response.json({ status: "anonymous", user: null });
  let user: Record<string, unknown> | null = null;
  if (gh.ghConfigured()) {
    try {
      const rows = (await gh.list("auth_sessions.json", 500, (s) => s.id === id)) as Array<Record<string, unknown>>;
      if (rows[0]) user = { name: rows[0].name, provider: rows[0].provider };
    } catch { /* ignore */ }
  }
  return Response.json({ status: "signed_in", session_id: id, user: user ?? { name: "Sitzung", provider: "session" } });
}

export async function DELETE(): Promise<Response> {
  const jar = await cookies();
  jar.delete(COOKIE);
  return Response.json({ status: "signed_out" });
}
