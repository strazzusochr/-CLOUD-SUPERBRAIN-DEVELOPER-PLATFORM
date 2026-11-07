"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { Panel } from "../components/ui";

type MonitorState = "loading" | "anonymous" | "forbidden" | "unavailable" | "empty" | "incomplete" | "stale" | "ready";
type RuntimeValue = string | number | boolean | null | undefined | Record<string, unknown> | unknown[];
type RuntimeEvent = {
  event_id: string;
  event: string;
  build_id?: string;
  trace_id?: string;
  owner_subject?: string;
  source?: RuntimeValue;
  state?: string;
  effect?: RuntimeValue;
  actor_type?: string | null;
  actor_id?: string | null;
  parent_event_id?: string | null;
  parent_event_ids?: string[];
  root_event_id?: string;
  owner_sequence?: string | null;
  prev_hash?: string | null;
  event_hash?: string | null;
  completeness?: string | null;
  missing_refs?: string[];
  runtime_class?: string;
  outcome?: string | null;
  observed_at?: string | null;
};


function displayRuntimeValue(value: RuntimeValue): string {
  if (value === null || value === undefined || value === "") return "";
  if (typeof value === "string") return value;
  try { return JSON.stringify(value); } catch { return "[nicht darstellbar]"; }
}

function mergeRuntimeEvents(current: RuntimeEvent[], incoming: RuntimeEvent[]): RuntimeEvent[] {
  const byId = new Map<string, RuntimeEvent>();
  for (const event of [...current, ...incoming]) byId.set(event.event_id, event);
  return [...byId.values()].sort((left, right) => {
    const leftSequence = Number(left.owner_sequence ?? 0);
    const rightSequence = Number(right.owner_sequence ?? 0);
    return rightSequence - leftSequence || right.event_id.localeCompare(left.event_id);
  });
}

function parseRuntimeStream(body: string): { events: RuntimeEvent[]; gap: boolean } {
  const events: RuntimeEvent[] = [];
  let gap = false;
  for (const block of body.split(/\r?\n\r?\n/)) {
    if (!block.trim()) continue;
    const lines = block.split(/\r?\n/);
    const eventType = lines.find((line) => line.startsWith("event:"))?.slice(6).trim();
    const data = lines.filter((line) => line.startsWith("data:")).map((line) => line.slice(5).trim()).join("\n");
    if (eventType === "runtime_gap") {
      gap = true;
      continue;
    }
    if (eventType !== "runtime_event" || !data) continue;
    try {
      const parsed = JSON.parse(data) as RuntimeEvent;
      if (parsed && typeof parsed.event_id === "string") events.push(parsed);
    } catch {
      // A malformed event is not allowed to become visible UI data.
    }
  }
  return { events, gap };
}

export function HomeRuntimeMonitor() {
  const [state, setState] = useState<MonitorState>("loading");
  const [events, setEvents] = useState<RuntimeEvent[]>([]);
  const [paused, setPaused] = useState(false);
  const [pendingCount, setPendingCount] = useState(0);
  const [detail, setDetail] = useState<{ event: RuntimeEvent; chain: RuntimeEvent[] } | null>(null);
  const [detailError, setDetailError] = useState<string | null>(null);
  const pausedRef = useRef(false);
  const lastEventIdRef = useRef<string | null>(null);
  const knownEventIdsRef = useRef(new Set<string>());
  const detailRequestRef = useRef<string | null>(null);
  const incompleteRef = useRef(false);

  const readEvents = useCallback(async (signal?: AbortSignal): Promise<boolean> => {
    try {
      const response = await fetch("/api/v1/workspace/runtime/events", { cache: "no-store", signal });
      if (response.status === 401) { setState("anonymous"); return false; }
      if (response.status === 403) { setState("forbidden"); return false; }
      if (!response.ok) { setState("unavailable"); return false; }
      const payload = await response.json().catch(() => null) as { events?: RuntimeEvent[]; complete?: boolean; stale?: boolean } | null;
      const nextEvents = Array.isArray(payload?.events)
        ? payload.events.filter((event) => event && typeof event.event_id === "string")
        : [];
      incompleteRef.current = payload?.complete === false;
      lastEventIdRef.current = nextEvents[0]?.event_id ?? lastEventIdRef.current;
      if (pausedRef.current) {
        setEvents((current) => {
          const known = new Set(current.map((event) => event.event_id));
          setPendingCount(nextEvents.filter((event) => !known.has(event.event_id)).length);
          return current;
        });
        return true;
      }
      knownEventIdsRef.current = new Set(nextEvents.map((event) => event.event_id));
      setEvents(nextEvents);
      setPendingCount(0);
      setState(nextEvents.length > 0 ? (payload?.stale === true ? "stale" : incompleteRef.current ? "incomplete" : "ready") : "empty");
      return true;
    } catch {
      if (!signal?.aborted) setState("unavailable");
      return false;
    }
  }, []);

  const readStream = useCallback(async (signal?: AbortSignal): Promise<void> => {
    try {
      const headers = new Headers({ accept: "text/event-stream" });
      if (lastEventIdRef.current) headers.set("Last-Event-ID", lastEventIdRef.current);
      const response = await fetch("/api/v1/workspace/runtime/events/stream", {
        headers,
        cache: "no-store",
        signal,
      });
      if (response.status === 401) { setState("anonymous"); return; }
      if (response.status === 403) { setState("forbidden"); return; }
      if (!response.ok) { setState("unavailable"); return; }
      const parsed = parseRuntimeStream(await response.text());
      if (parsed.gap) {
        await readEvents(signal);
        return;
      }
      if (!parsed.events.length) return;
      lastEventIdRef.current = parsed.events[0].event_id;
      if (pausedRef.current) {
        const unseen = parsed.events.filter((event) => !knownEventIdsRef.current.has(event.event_id));
        setPendingCount((count) => count + unseen.length);
        return;
      }
      setEvents((current) => {
        const merged = mergeRuntimeEvents(current, parsed.events);
        knownEventIdsRef.current = new Set(merged.map((event) => event.event_id));
        return merged;
      });
      setPendingCount(0);
      setState(incompleteRef.current ? "incomplete" : "ready");
    } catch {
      if (!signal?.aborted) setState("unavailable");
    }
  }, [readEvents]);

  const loadDetail = useCallback(async (event: RuntimeEvent) => {
    if (detailRequestRef.current === event.event_id) return;
    detailRequestRef.current = event.event_id;
    setDetailError(null);
    try {
      const response = await fetch(`/api/v1/workspace/runtime/events/${encodeURIComponent(event.event_id)}`, { cache: "no-store" });
      if (!response.ok) throw new Error("Detail nicht erreichbar");
      const payload = await response.json() as { event?: RuntimeEvent };
      const detailEvent = payload.event ?? event;
      let chain = [detailEvent];
      if (detailEvent.trace_id) {
        const traceResponse = await fetch(`/api/v1/workspace/runtime/traces/${encodeURIComponent(detailEvent.trace_id)}`, { cache: "no-store" });
        if (traceResponse.ok) {
          const tracePayload = await traceResponse.json() as { events?: RuntimeEvent[] };
          if (Array.isArray(tracePayload.events)) chain = tracePayload.events;
        }
      }
      setDetail({ event: detailEvent, chain });
    } catch {
      setDetail({ event, chain: [] });
      setDetailError("Ereignisdetail ist gerade nicht erreichbar.");
    } finally {
      detailRequestRef.current = null;
    }
  }, []);

  useEffect(() => {
    const controller = new AbortController();
    const timer = window.setTimeout(() => controller.abort(), 8_000);
    const initialLoad = window.setTimeout(() => {
      void readEvents(controller.signal).then((available) => {
        if (available) return readStream(controller.signal);
        return undefined;
      }).finally(() => window.clearTimeout(timer));
    }, 0);
    const refreshTimer = window.setInterval(() => {
      void readEvents().then((available) => {
        if (available) return readStream();
        return undefined;
      });
    }, 10_000);
    return () => {
      window.clearTimeout(initialLoad);
      window.clearTimeout(timer);
      window.clearInterval(refreshTimer);
      controller.abort();
    };
  }, [readEvents, readStream]);

  function togglePaused() {
    const next = !pausedRef.current;
    pausedRef.current = next;
    setPaused(next);
    if (!next) {
      setPendingCount(0);
      void readEvents().then((available) => {
        if (available) return readStream();
        return undefined;
      });
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
      : state === "stale"
        ? "Aktivität ist veraltet — Quelle bitte neu verbinden."
      : state === "incomplete"
        ? "Aktivität ist unvollständig — noch nicht alle Wirkungsquellen sind verbunden."
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
        {state === "ready" || state === "incomplete" || state === "stale" ? (
          <>
            {state !== "ready" ? <p className="home-workspace-empty" role="status">{message}</p> : null}
            <div className="list home-runtime-event-list" data-testid="home-runtime-events">
              {events.map((event) => (
              <details className="home-runtime-event" key={event.event_id} onToggle={(toggleEvent) => {
                if ((toggleEvent.currentTarget as HTMLDetailsElement).open) void loadDetail(event);
              }}>
                <summary>{event.event}</summary>
                <dl>
                  <dt>Ereignis</dt><dd>{event.event_id}</dd>
                  {event.build_id ? <><dt>Arbeitsstand</dt><dd>{event.build_id}</dd></> : null}
                  {event.trace_id ? <><dt>Spur</dt><dd>{event.trace_id}</dd></> : null}
                  {event.source ? <><dt>Quelle</dt><dd>{displayRuntimeValue(event.source)}</dd></> : null}
                  {event.state ? <><dt>Zustand</dt><dd>{event.state}</dd></> : null}
                  {event.effect ? <><dt>Wirkung</dt><dd>{displayRuntimeValue(event.effect)}</dd></> : null}
                  {event.root_event_id ? <><dt>Ursprung</dt><dd>{event.root_event_id}</dd></> : null}
                  {event.observed_at ? <><dt>Zeit</dt><dd>{event.observed_at}</dd></> : null}
                </dl>
                {detail?.event.event_id === event.event_id ? (
                  <div className="home-runtime-event-detail" data-testid="home-runtime-detail">
                    <strong>Nachweis</strong>
                    <span>{detail.event.actor_type ?? "Akteur unbekannt"} · {detail.event.outcome ?? "Ergebnis unbekannt"}</span>
                    <span>{detail.event.completeness ?? "Vollständigkeit unbekannt"}</span>
                    <span>Parent-/Root-Kette: {detail.chain.map((item) => item.event_id).join(" → ")}</span>
                    <span>Hashkette: {detail.event.prev_hash ?? "Root"} → {detail.event.event_hash ?? "unbekannt"}</span>
                    {detail.event.missing_refs?.length ? <span>Fehlende Verweise: {detail.event.missing_refs.join(", ")}</span> : null}
                  </div>
                ) : null}
                {detailError && detail?.event.event_id === event.event_id ? <p className="home-workspace-empty">{detailError}</p> : null}
              </details>
              ))}
            </div>
          </>
        ) : <p className="home-workspace-empty">{message}</p>}
      </Panel>
    </div>
  );
}
