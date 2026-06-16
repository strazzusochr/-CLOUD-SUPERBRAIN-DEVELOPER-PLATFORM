"use client";

import { useState } from "react";

type Source = { title: string; url: string; extract: string };
type Step = { role: string; label: string; content: string; ms: number };
type Run = { goal: string; provider: string; steps: Step[]; sources: Source[]; answer: string };

// Real multi-agent deep-research runner. Posts a goal to /api/v1/agent-run, which
// executes Planner→Researcher(Wikipedia)→Writer against the live LLM, and renders
// every genuine role output, source, and timing. Honest error/503 surfacing.
export function AgentRun() {
  const [goal, setGoal] = useState("Was ist eine Vektordatenbank und wofür nutzt man sie?");
  const [busy, setBusy] = useState(false);
  const [run, setRun] = useState<Run | null>(null);
  const [err, setErr] = useState<string | null>(null);

  async function start() {
    if (!goal.trim() || busy) return;
    setBusy(true); setErr(null); setRun(null);
    try {
      const res = await fetch("/api/v1/agent-run", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ goal }),
      });
      const body = await res.json();
      if (!res.ok) {
        setErr(String(body.note ?? `${res.status} ${res.statusText}`));
      } else {
        setRun(body as Run);
      }
    } catch (e) {
      setErr(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="agent-run" data-testid="agent-run">
      <div className="ar-controls">
        <input
          className="ar-input"
          value={goal}
          onChange={(e) => setGoal(e.target.value)}
          placeholder="Forschungsziel eingeben…"
          aria-label="Forschungsziel"
          onKeyDown={(e) => { if (e.key === "Enter") start(); }}
          disabled={busy}
        />
        <button type="button" className="btn btn-sm btn-primary" onClick={start} disabled={busy} data-testid="ar-run">
          {busy ? "Agenten arbeiten…" : "▶ Multi-Agent starten"}
        </button>
      </div>
      {err ? <div className="note blocked" data-testid="ar-error">⚠ {err}</div> : null}
      {run ? (
        <div className="ar-result" data-testid="ar-result">
          <div className="ar-pipeline">
            {run.steps.map((s) => (
              <div key={s.role} className={`ar-step ar-${s.role}`}>
                <div className="ar-step-head"><b>{s.label}</b><span className="mono text-12 text-mut">{s.ms} ms</span></div>
                <pre className="ar-step-body">{s.content}</pre>
              </div>
            ))}
          </div>
          <div className="ar-answer">
            <div className="ar-step-head"><b>Ergebnis</b><span className="mono text-12 text-mut">{run.provider}</span></div>
            <div className="ar-answer-body">{run.answer}</div>
          </div>
          {run.sources.length ? (
            <div className="ar-sources">
              <b className="text-13">Quellen ({run.sources.length})</b>
              {run.sources.map((s, i) => (
                <div key={s.url} className="ar-source">
                  <a href={s.url} target="_blank" rel="noopener noreferrer" className="mono text-12">[{i + 1}] {s.title}</a>
                </div>
              ))}
            </div>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
