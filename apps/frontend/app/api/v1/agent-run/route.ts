import { runDeepResearch } from "../../../../lib/agentChain";

export const dynamic = "force-dynamic";
export const maxDuration = 60;

export async function POST(req: Request): Promise<Response> {
  let goal = "";
  try {
    const body = (await req.json()) as { goal?: unknown };
    goal = typeof body.goal === "string" ? body.goal.trim() : "";
  } catch {
    /* empty body */
  }
  if (!goal) {
    return Response.json({ status: "bad_request", note: "Feld 'goal' (string) erforderlich." }, { status: 400 });
  }
  if (goal.length > 500) goal = goal.slice(0, 500);
  try {
    const run = await runDeepResearch(goal);
    return Response.json(run, { headers: { "x-superbrain-source": "multi-agent-deep-research" } });
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    const noKey = /not configured/i.test(msg);
    return Response.json(
      {
        status: noKey ? "no_live_backend" : "agent_run_error",
        live_backend: false,
        note: noKey
          ? "Multi-Agent benötigt einen Live-LLM (CF_WORKERS_AI_TOKEN + CLOUDFLARE_ACCOUNT_ID). Nicht konfiguriert in dieser Deployment-Umgebung."
          : msg,
      },
      { status: noKey ? 503 : 502, headers: { "x-superbrain-source": "multi-agent-deep-research" } },
    );
  }
}
