"use client";

import { useState } from "react";

export type LiveEndpoint = { label: string; path: string };

/**
 * Real interactive console: pick a wired backend endpoint and load it live (GET, no-store).
 * Shows status code, latency, formatted JSON, and copy — turning a static surface into a
 * functional one. No fake data: it calls the page's actually-wired agent-api/mcp/llm routes.
 */
export function LiveConsole({ endpoints, label = "Live-Daten" }: { endpoints: LiveEndpoint[]; label?: string }) {
  const [selected, setSelected] = useState(endpoints[0]?.path ?? "");
  const [out, setOut] = useState('Klick „Aktualisieren" für Live-Daten.');
  const [status, setStatus] = useState("idle");
  const [meta, setMeta] = useState("");
  const [busy, setBusy] = useState(false);

  function persist(key: string, value: string) {
    try {
      localStorage.setItem(key, value);
    } catch {}
  }

  async function load() {
    if (!selected) return;
    setBusy(true);
    setStatus("lädt…");
    const started = performance.now();
    try {
      const res = await fetch(selected, { cache: "no-store", headers: { accept: "application/json" } });
      const text = await res.text();
      let pretty = text;
      try {
        pretty = JSON.stringify(JSON.parse(text), null, 2);
      } catch {
        /* not json — show raw */
      }
      const ms = Math.round(performance.now() - started);
      setStatus(res.ok ? `${res.status} OK` : `${res.status} ${res.statusText}`);
      setMeta(`${new Date().toLocaleTimeString()} · ${ms} ms · ${pretty.length} B`);
      setOut(pretty.length > 6000 ? `${pretty.slice(0, 6000)}\n… (gekürzt)` : pretty);
    } catch (err) {
      setStatus("Fehler");
      setMeta("");
      setOut(err instanceof Error ? err.message : String(err));
    } finally {
      setBusy(false);
    }
  }

  const tone = status.includes("OK") ? "lc-ok" : status === "Fehler" || /^[45]/.test(status) ? "lc-err" : "lc-idle";

  return (
    <div className="live-console" data-testid="live-console">
      <div className="lc-controls">
        {endpoints.length > 1 ? (
          <select
            aria-label={`${label} Endpoint`}
            value={selected}
            onChange={(e) => {
              setSelected(e.target.value);
              persist(`live-console:selected:${label}`, e.target.value);
              persist("live-console:last_select", String(Date.now()));
            }}
            disabled={busy}
          >
            {endpoints.map((ep) => (
              <option key={ep.path} value={ep.path}>{ep.label}</option>
            ))}
          </select>
        ) : (
          <span className="lc-ep mono">{endpoints[0]?.label}</span>
        )}
        <button type="button" className="btn btn-sm btn-primary" onClick={load} disabled={busy} data-testid="live-console-load">
          {busy ? "lädt…" : "↻ Aktualisieren"}
        </button>
        <button
          type="button"
          className="btn btn-sm btn-ghost"
          onClick={() => {
            const op = navigator.clipboard?.writeText(out);
            if (op && typeof op.catch === "function") op.catch(() => undefined);
            persist("live-console:last_copy", String(Date.now()));
          }}
          disabled={busy}
        >
          Kopieren
        </button>
        <span className={`lc-status ${tone}`} aria-live="polite">{status}</span>
        {meta ? <span className="lc-meta mono">{meta}</span> : null}
      </div>
      <pre className="lc-out mono" aria-live="polite">{out}</pre>
    </div>
  );
}
