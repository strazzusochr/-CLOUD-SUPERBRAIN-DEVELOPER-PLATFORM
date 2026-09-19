"use client";

import { useState } from "react";

type JsonValue = Record<string, unknown>;

async function readJson(res: Response): Promise<JsonValue> {
  const text = await res.text();
  try {
    return text ? (JSON.parse(text) as JsonValue) : {};
  } catch {
    return { raw: text };
  }
}

async function getJson(path: string): Promise<JsonValue> {
  const res = await fetch(path, { cache: "no-store" });
  const body = await readJson(res);
  if (!res.ok) throw new Error(String(body.detail ?? body.error ?? `${res.status} ${res.statusText}`));
  return body;
}

function ActionResult({ state, testId }: { state: string; testId: string }) {
  return (
    <pre className="goalb-result mono" data-testid={testId} aria-live="polite">
      {state}
    </pre>
  );
}

export function HomeCortexHero() {
  const nodes = [
    [18, 50], [22, 35], [25, 65], [30, 24], [31, 50], [32, 76],
    [39, 34], [40, 62], [45, 18], [46, 48], [47, 80], [53, 20],
    [54, 52], [56, 76], [62, 34], [64, 62], [69, 24], [70, 50],
    [75, 70], [80, 38], [83, 55],
  ];
  const links = nodes.slice(0, -1).map((node, index) => ({
    from: node,
    to: nodes[index + 1],
  }));
  return (
    <div className="home-cortex-card" data-testid="batch4-home-cortex-hero">
      <svg className="home-cortex-visual" viewBox="0 0 100 100" role="img" aria-label="Statische NeuroGlass-Cortex-Darstellung">
        <defs>
          <radialGradient id="home-cortex-core" cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor="#ffffff" stopOpacity="0.95" />
            <stop offset="30%" stopColor="#00e5ff" stopOpacity="0.75" />
            <stop offset="100%" stopColor="#8b5cf6" stopOpacity="0" />
          </radialGradient>
        </defs>
        <g className="home-cortex-links" transform="translate(50 50) scale(1.35) translate(-50 -50)" stroke="#00e5ff" strokeOpacity="0.34" strokeWidth="0.7">
          {links.map(({ from, to }, index) => <line key={index} x1={from[0]} y1={from[1]} x2={to[0]} y2={to[1]} />)}
        </g>
        <circle cx="50" cy="50" r="22" fill="url(#home-cortex-core)" />
        <g className="home-cortex-nodes" transform="translate(50 50) scale(1.35) translate(-50 -50)" fill="#00e5ff">
          {nodes.map(([cx, cy], index) => <circle key={index} cx={cx} cy={cy} r={index % 4 === 0 ? 1.8 : 1.15} />)}
        </g>
        <circle cx="50" cy="50" r="4" fill="#f7fbff" />
      </svg>
    </div>
  );
}

export function ObserveRuntimeProbe() {
  const [result, setResult] = useState("Bereit — noch keine Messung abgerufen.");
  const [busy, setBusy] = useState(false);

  async function probe() {
    setBusy(true);
    try {
      const contract = await getJson("/api/v1/metrics/contract");
      setResult([
        "PASS observe_readonly_probe",
        "endpoint=GET /api/v1/metrics/contract",
        `contract=${String(contract.contract_version ?? "unknown")}`,
        `evidence_ref=${String(contract.evidence_ref ?? "missing")}`,
        "fake_live_metrics=false",
        "provider_writes=false",
        "live_provider_calls=false",
      ].join("\n"));
    } catch (err) {
      setResult(`FAIL observe_readonly_probe\n${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="goalb-action-panel" data-testid="goal-b-observe-panel">
      <div className="goalb-row">
        <button className="btn btn-sm btn-primary" type="button" data-testid="goal-b-observe-refresh" onClick={probe} disabled={busy}>
          Metrikvertrag prüfen
        </button>
        <span className="badge badge-cyan">nur lesend</span>
        <span className="badge badge-amber">Datenverkehrsdiagramm als Spezifikation</span>
      </div>
      <ActionResult state={result} testId="goal-b-observe-result" />
    </div>
  );
}

export function EvidenceVerifierProbe() {
  const [result, setResult] = useState("Bereit — noch kein Verifier-Status gelesen.");
  const [busy, setBusy] = useState(false);

  async function probe() {
    setBusy(true);
    try {
      const [verify, integrity] = await Promise.all([
        getJson("/api/v1/platform/verify"),
        getJson("/api/v1/project/progress/integrity"),
      ]);
      setResult([
        "PASS evidence_verifier_probe",
        "endpoint=GET /api/v1/platform/verify",
        `contract=${String(verify.contract_version ?? "unknown")}`,
        `layers=${String(verify.verified ?? "0")}/${String(verify.total ?? "0")}`,
        `integrity=${String(integrity.status ?? "unknown")}`,
        `evidence_ref=${String(verify.evidence_ref ?? integrity.evidence_ref ?? "missing")}`,
        "provider_writes=false",
        "live_provider_calls=false",
        "secret_output=false",
      ].join("\n"));
    } catch (err) {
      setResult(`FAIL evidence_verifier_probe\n${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="goalb-action-panel" data-testid="goal-b-evidence-panel">
      <div className="goalb-row">
        <button className="btn btn-sm btn-primary" type="button" data-testid="goal-b-evidence-verify" onClick={probe} disabled={busy}>
          Verifier-Status lesen
        </button>
        <span className="badge badge-cyan">nur lesender Nachweis</span>
      </div>
      <ActionResult state={result} testId="goal-b-evidence-result" />
    </div>
  );
}
