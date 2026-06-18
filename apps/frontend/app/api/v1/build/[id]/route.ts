// Load a previously built app back into the builder (to keep iterating on it).
// Returns the stored HTML + metadata. Honest 404 when missing / no store.
import * as gh from "../../../../../lib/ghStore";

export const dynamic = "force-dynamic";

function safeId(v: string): string {
  return /^[A-Za-z0-9_-]{1,64}$/.test(v) ? v : "";
}

export async function GET(_req: Request, ctx: { params: Promise<{ id: string }> }): Promise<Response> {
  const { id } = await ctx.params;
  const clean = safeId(id);
  if (!clean || !gh.ghConfigured()) {
    return Response.json({ status: "not_found", note: "Build nicht gefunden oder kein Speicher." }, { status: 404 });
  }
  try {
    const html = await gh.getRaw(`builds/${clean}.html`);
    if (!html) return Response.json({ status: "not_found" }, { status: 404 });
    const metas = (await gh.list("builds.json", 200, (b) => b.id === clean)) as Array<Record<string, unknown>>;
    const meta = metas[0] ?? {};
    return Response.json(
      { id: clean, title: meta.title ?? "App", model: meta.model ?? "", prompt: meta.prompt ?? "", html, share_path: `/run/${clean}` },
      { headers: { "x-superbrain-source": "github-store" } },
    );
  } catch (err) {
    return Response.json({ status: "store_error", note: err instanceof Error ? err.message : String(err) }, { status: 502 });
  }
}

export async function DELETE(_req: Request, ctx: { params: Promise<{ id: string }> }): Promise<Response> {
  const { id } = await ctx.params;
  const clean = safeId(id);
  if (!clean || !gh.ghConfigured()) return Response.json({ status: "not_found" }, { status: 404 });
  try {
    await gh.mutate("builds.json", (rows) => (rows as Array<Record<string, unknown>>).filter((b) => b.id !== clean));
    await gh.deleteRaw(`builds/${clean}.html`);
    await gh.audit("app_deleted", clean, "");
    return Response.json({ status: "deleted", id: clean }, { headers: { "x-superbrain-source": "github-store" } });
  } catch (err) {
    return Response.json({ status: "store_error", note: err instanceof Error ? err.message : String(err) }, { status: 502 });
  }
}
