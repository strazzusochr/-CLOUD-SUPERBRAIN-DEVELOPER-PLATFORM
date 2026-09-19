"use client";

import { useCallback, useEffect, useRef, useState } from "react";
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
  const [paused, setPaused] = useState(false);
  const [pendingCount, setPendingCount] = useState(0);
  const pausedRef = useRef(false);

  const readEvents = useCallback(async (signal?: AbortSignal) => {
    try {
      const response = await fetch("/api/v1/workspace/runtime/events", { cache: "no-store", signal });
      if (response.status === 401) return setState("anonymous");
      if (response.status === 403) return setState("forbidden");
      if (!response.ok) return setState("unavailable");
      const payload = await response.json().catch(() => null) as { events?: RuntimeEvent[] } | null;
      const nextEvents = Array.isArray(payload?.events)
        ? payload.events.filter((event) => event && typeof event.event_id === "string")
        : [];
      if (pausedRef.current) {
        setEvents((current) => {
          const known = new Set(current.map((event) => event.event_id));
          setPendingCount(nextEvents.filter((event) => !known.has(event.event_id)).length);
          return current;
        });
        return;
      }
      setEvents(nextEvents);
      setPendingCount(0);
      setState(nextEvents.length > 0 ? "ready" : "empty");
    } catch {
      if (!signal?.aborted) setState("unavailable");
    }
  }, []);

  useEffect(() => {
    const controller = new AbortController();
    const timer = window.setTimeout(() => controller.abort(), 8_000);
    const initialLoad = window.setTimeout(() => {
      void readEvents(controller.signal).finally(() => window.clearTimeout(timer));
    }, 0);
    const refreshTimer = window.setInterval(() => { void readEvents(); }, 10_000);
    return () => {
      window.clearTimeout(initialLoad);
      window.clearTimeout(timer);
      window.clearInterval(refreshTimer);
      controller.abort();
    };
  }, [readEvents]);

  function togglePaused() {
    const next = !pausedRef.current;
    pausedRef.current = next;
    setPaused(next);
    if (!next) {
      setPendingCount(0);
      void readEvents();
    }
  }

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
      <Panel
        title="Deine Aktivität"
        className="home-runtime-monitor"
        actions={state === "ready" || state === "empty" ? (
          <div className="home-runtime-actions">
            <button type="button" className="btn btn-sm btn-ghost" data-testid="home-runtime-pause" onClick={togglePaused} aria-pressed={paused}>
              {paused ? "Fortsetzen" : "Pausieren"}
            </button>
            {paused ? <span className="meta" data-testid="home-runtime-pending">Neue Ereignisse: {pendingCount}</span> : null}
          </div>
        ) : null}
      >
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
