// Server-only helpers shared by the organism events/replay routes. Never
// imported client-side. Maps the agent-api activity trace onto organism hubs and
// deliberately exposes ONLY the generic event_type — no session/user identifiers.

type RawEvent = { event_type?: unknown };
type OrganismProjectionKind = "events" | "replay";

/** Ordered: more specific event-type keywords win (e.g. "completed" before "task"). */
const HUB_BY_KIND: Array<[RegExp, string, string, string[]]> = [
  [/tool|mcp/i, "tools", "executing", ["basal", "sensory", "motor", "callosum"]],
  [/valid|verif|check|test/i, "observe", "verifying", ["cerebellum", "sensory", "callosum"]],
  [/memory|embed|vector/i, "memory", "executing", ["hippocampus", "callosum"]],
  [/model|llm|inferenc/i, "models", "executing", ["basal", "thalamus", "callosum"]],
  [/plan/i, "workbench", "planning", ["prefrontal", "thalamus", "callosum"]],
  [/complete|passed|done|success/i, "observe", "idle", ["cerebellum", "autonomic", "callosum"]],
  [/exec|mission|task|dispatch|agent/i, "agents", "executing", ["motor", "basal", "callosum"]],
];

export function mapKind(kind: string): { hub: string; run_state: string; regions: string[] } {
  for (const [re, hub, run_state, regions] of HUB_BY_KIND) {
    if (re.test(kind)) return { hub, run_state, regions };
  }
  return { hub: "workbench", run_state: "executing", regions: ["sensory", "prefrontal", "callosum"] };
}

/** Fetch the agent-api activity trace when AGENT_API_INTERNAL_URL is reachable.
 *  Returns the generic event_type strings only, or null (→ caller serves spec-only). */
export async function fetchActivityKinds(limit = 12, traceId?: string | null): Promise<string[] | null> {
  const base = process.env.AGENT_API_INTERNAL_URL?.replace(/\/$/, "");
  if (!base) return null;
  try {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 1500);
    const path = new URL(`${base}/api/v1/agent-activity/recent`);
    if (traceId) path.searchParams.set("trace_id", traceId);
    const res = await fetch(path, { cache: "no-store", signal: ctrl.signal });
    clearTimeout(timer);
    if (!res.ok) return null;
    const body: unknown = await res.json();
    const raw = (body as { events?: unknown })?.events;
    if (!Array.isArray(raw) || !raw.length) return null;
    const kinds = raw
      .map((e) => String((e as RawEvent)?.event_type ?? "").trim())
      .filter(Boolean)
      .slice(0, limit);
    return kinds.length ? kinds : null;
  } catch {
    return null;
  }
}

/** Prefer the Agent API's explicit organism projection when available. It is
 * already redacted by contract, and callers still keep their spec-only fallback. */
export async function fetchOrganismProjection(kind: OrganismProjectionKind, runId?: string | null): Promise<Record<string, unknown> | null> {
  const base = process.env.AGENT_API_INTERNAL_URL?.replace(/\/$/, "");
  if (!base) return null;
  let timer: ReturnType<typeof setTimeout> | null = null;
  try {
    const ctrl = new AbortController();
    timer = setTimeout(() => ctrl.abort(), 1500);
    const path = new URL(`${base}/api/v1/organism/${kind}`);
    if (runId) path.searchParams.set("run_id", runId);
    const res = await fetch(path, { cache: "no-store", signal: ctrl.signal });
    if (!res.ok) return null;
    const body = (await res.json()) as Record<string, unknown>;
    if (body?.source !== "agent-api" || body?.source_kind !== "agent_api_redacted") return null;
    return body;
  } catch {
    return null;
  } finally {
    if (timer) clearTimeout(timer);
  }
}
