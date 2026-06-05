// Server-only helpers shared by the organism events/replay routes. Never
// imported client-side. Maps the agent-api activity trace onto organism hubs and
// deliberately exposes ONLY the generic event_type — no session/user identifiers.

type RawEvent = { event_type?: unknown };

/** Ordered: more specific event-type keywords win (e.g. "completed" before "task"). */
const HUB_BY_KIND: Array<[RegExp, string, string]> = [
  [/tool/i, "tools", "executing"],
  [/valid|verif|check|test/i, "observe", "verifying"],
  [/memory|embed|vector/i, "memory", "executing"],
  [/model|llm|inferenc/i, "models", "executing"],
  [/plan/i, "workbench", "planning"],
  [/complete|passed|done|success/i, "observe", "idle"],
  [/exec|mission|task|dispatch|agent/i, "agents", "executing"],
];

export function mapKind(kind: string): { hub: string; run_state: string } {
  for (const [re, hub, run_state] of HUB_BY_KIND) {
    if (re.test(kind)) return { hub, run_state };
  }
  return { hub: "workbench", run_state: "executing" };
}

/** Fetch the agent-api activity trace when AGENT_API_INTERNAL_URL is reachable.
 *  Returns the generic event_type strings only, or null (→ caller serves mock). */
export async function fetchActivityKinds(limit = 12): Promise<string[] | null> {
  const base = process.env.AGENT_API_INTERNAL_URL?.replace(/\/$/, "");
  if (!base) return null;
  try {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 1500);
    const res = await fetch(`${base}/api/v1/agent-activity/recent`, { cache: "no-store", signal: ctrl.signal });
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
