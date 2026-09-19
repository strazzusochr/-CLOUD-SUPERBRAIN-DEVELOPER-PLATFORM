"use client";

import { useEffect, useState } from "react";
import { Panel } from "../components/ui";

type MonitorState = "loading" | "anonymous" | "forbidden" | "unavailable" | "empty" | "ready";
type RuntimeEvent = {
  event_id: string;
  event: string;
  build_id?: string;
  trace_id?: string;
  owner_subject?: string;
  source?: string;
  state?: string;
  effect?: string;
  parent_event_ids?: string[];
  root_event_id?: string;
  observed_at?: string | null;
};

export function HomeRuntimeMonitor() {
  const [state, setState] = useState<MonitorState>("loading");
  const [events, setEvents] = useState<RuntimeEvent[]>([]);

  useEffect(() => {
    const controller = new AbortController();
    const timer = window.setTimeout(() => controller.abort(), 8_000);
    void fetch("/api/v1/workspace/runtime/events", { cache: "no-store", signal: controller.signal })
      .then(async (response) => {
        if (response.status === 401) return setState("anonymous");
        if (response.status === 403) return setState("forbidden");
        if (!response.ok) return setState("unavailable");
        const payload = await response.json().catch(() => null) as { events?: RuntimeEvent[] } | null;
        const nextEvents = Array.isArray(payload?.events) ? payload.events.filter((event) => event && typeof event.event_id === "string") : [];
        setEvents(nextEvents);
        setState(nextEvents.length > 0 ? "ready" : "empty");
      })
      .catch(() => setState("unavailable"))
      .finally(() => window.clearTimeout(timer));
    return () => {
      window.clearTimeout(timer);
      controller.abort();
    };
  }, []);

  const message = state === "loading"
    ? "Aktivität wird geladen."
    : state === "anonymous"
      ? "Mit GitHub anmelden, um eigene Aktivität zu sehen."
      : state === "forbidden"
      ? "Aktivität ist für diese Identität nicht freigegeben."
      : state === "unavailable"
        ? "Aktivität ist gerade nicht erreichbar."
      : state === "empty"
        ? "Keine Aktivität"
        : "Eigene Aktivität";

  return (
    <div data-testid="home-runtime-monitor">
      <Panel title="Deine Aktivität" className="home-runtime-monitor">
        {state === "ready" ? (
          <div className="list home-runtime-event-list" data-testid="home-runtime-events">
            {events.map((event) => (
              <details className="home-runtime-event" key={event.event_id}>
                <summary>{event.event}</summary>
                <dl>
                  <dt>Ereignis</dt><dd>{event.event_id}</dd>
                  {event.build_id ? <><dt>Arbeitsstand</dt><dd>{event.build_id}</dd></> : null}
                  {event.trace_id ? <><dt>Spur</dt><dd>{event.trace_id}</dd></> : null}
                  {event.source ? <><dt>Quelle</dt><dd>{event.source}</dd></> : null}
                  {event.state ? <><dt>Zustand</dt><dd>{event.state}</dd></> : null}
                  {event.effect ? <><dt>Wirkung</dt><dd>{event.effect}</dd></> : null}
                  {event.root_event_id ? <><dt>Ursprung</dt><dd>{event.root_event_id}</dd></> : null}
                  {event.observed_at ? <><dt>Zeit</dt><dd>{event.observed_at}</dd></> : null}
                </dl>
              </details>
            ))}
          </div>
        ) : <p className="home-workspace-empty">{message}</p>}
      </Panel>
    </div>
  );
}
