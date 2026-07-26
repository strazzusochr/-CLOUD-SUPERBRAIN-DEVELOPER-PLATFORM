"use client";

import { useState } from "react";

type Source = { title: string; url: string; extract: string };
type Step = { role: string; label: string; content: string; ms: number };
type Run = {
  contract_version: string;
  evidence_ref: string;
  status: string;
  mode: string;
  goal: string;
  provider: string;
  steps: Step[];
  sources: Source[];
  answer: string;
  trace_id: string;
  live_provider_calls: boolean;
  local_model_calls: boolean;
  live_mcp_writes: false;
  model_downloads: boolean;
  audit_persisted: boolean;
  secret_output: false;
  direct_provider_calls: false;
  production_deploy: false;
  budget: Record<string, unknown>;
  non_claims: string[];
};

function isRun(body: unknown): body is Run {
  if (!body || typeof body !== "object") return false;
  const candidate = body as Partial<Run>;
  return candidate.contract_version === "agent-research-run-v1"
    && candidate.status === "completed"
    && typeof candidate.evidence_ref === "string"
    && typeof candidate.provider === "string"
    && typeof candidate.answer === "string"
    && Array.isArray(candidate.steps)
    && Array.isArray(candidate.sources)
    && Array.isArray(candidate.non_claims);
}

// Multi-agent runner. The server route forwards only to the Agent API boundary;
// an unavailable stateful runtime is surfaced as an explicit error.
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
      const text = await res.text();
      const body = text ? JSON.parse(text) as Record<string, unknown> : {};
      if (!res.ok) {
        setErr(String(body.detail ?? body.error ?? `${res.status} ${res.statusText}`));
      } else if (!isRun(body)) {
        setErr("Agent API lieferte keine vollständige agent-research-run-v1-Antwort.");
      } else {
        setRun(body);
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
        <div
          className="ar-result"
          data-testid="ar-result"
          data-contract-version={run.contract_version}
          data-status={run.status}
          data-live-provider-calls={String(run.live_provider_calls)}
        >
          <div className="note" data-testid="ar-contract">
            <div className="chips">
              <span className="badge badge-green">{run.status}</span>
              <span className="badge badge-cyan">{run.contract_version}</span>
              <span className="badge badge-mut">Provider: {run.provider}</span>
              <span className={`badge badge-${run.live_provider_calls ? "amber" : "green"}`}>
                live_provider_calls={String(run.live_provider_calls)}
              </span>
              <span className={`badge badge-${run.audit_persisted ? "green" : "amber"}`}>
                audit_persisted={String(run.audit_persisted)}
              </span>
              <span className="badge badge-green">direct_provider_calls=false</span>
              <span className="badge badge-green">live_mcp_writes=false</span>
            </div>
            <p className="mono text-12 text-mut mt-12">
              mode={run.mode} · trace={run.trace_id} · evidence={run.evidence_ref}
            </p>
          </div>
          <div className="ar-pipeline">
            {run.steps.map((s) => (
              <div key={s.role} className={`ar-step ar-${s.role}`}>
                <div className="ar-step-head"><b>{s.label}</b><span className="mono text-12 text-mut">{s.ms} ms</span></div>
                <pre className="ar-step-body">{s.content}</pre>
              </div>
            ))}
          </div>
          <div className="ar-answer">
            <div className="ar-step-head"><b>Ergebnis</b><span className="mono text-12 text-mut">Gateway-Bericht · {run.provider}</span></div>
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
          {run.non_claims.length ? (
            <div className="note blocked">
              {run.non_claims.map((claim) => <p key={claim} className="text-12 text-mut">{claim}</p>)}
            </div>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
