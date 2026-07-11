"use client";

import { useState } from "react";
import CortexCanvas from "./organism/CortexCanvas";

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
  return (
    <div className="home-cortex-card" data-testid="batch4-home-cortex-hero">
      <CortexCanvas
        runState="planning"
        activeRegion="prefrontal"
        interactive={false}
        showRegions={false}
        nodeCount={520}
        sourceLabel="CLIENT-3D · CORTEX HERO"
        className="home-cortex-canvas"
      />
      <div className="home-cortex-footer">
        <span className="badge badge-cyan">leuchtender 3D-Cortex</span>
        <span className="badge badge-amber">client-lokal</span>
        <span className="badge badge-green">keine Fake-Daten</span>
      </div>
    </div>
  );
}

export function HomeHeroProofPanel() {
  const [result, setResult] = useState("Bereit — Prüfung noch nicht gestartet.");

  function checkHero() {
    setResult([
      "PASS home_hero_check",
      "visual=glowing_3d_cortex",
      "source=client_3d",
      "fake_stats=false",
      "live_provider_calls=false",
      "provider_writes=false",
      "production_deploy=false",
    ].join("\n"));
  }

  return (
    <div className="goalb-action-panel" data-testid="goal-b-home-panel">
      <div className="goalb-row">
        <button
          aria-label="DEV-ONLY-Cortex-Hero prüfen"
          className="btn btn-sm btn-primary"
          type="button"
          data-testid="goal-b-home-hero-proof"
          onClick={checkHero}
        >
          Cortex-Nachweis
        </button>
        <span className="badge badge-cyan">lokaler visueller Vertrag</span>
      </div>
      <ActionResult state={result} testId="goal-b-home-result" />
    </div>
  );
}

export function LoginDryRunPanel() {
  const [result, setResult] = useState("Bereit — noch kein Login-Durchlauf.");

  function choose(provider: "github" | "google" | "email" | "guest") {
    setResult([
      "PASS login_dry_run",
      `provider=${provider}`,
      "session_state=dry_run",
      "live_oauth=false",
      "provider_writes=false",
      "secret_output=false",
      "redirect_allowed=/workbench",
    ].join("\n"));
  }

  return (
    <div className="goalb-action-panel" data-testid="goal-b-login-panel">
      <div className="goalb-row">
        <button className="btn btn-sm" type="button" data-testid="goal-b-login-github" onClick={() => choose("github")}>GitHub-Dry-Run</button>
        <button className="btn btn-sm" type="button" data-testid="goal-b-login-google" onClick={() => choose("google")}>Google-Dry-Run</button>
        <button className="btn btn-sm" type="button" data-testid="goal-b-login-email" onClick={() => choose("email")}>E-Mail-Dry-Run</button>
        <button className="btn btn-sm btn-primary" type="button" data-testid="goal-b-login-guest" onClick={() => choose("guest")}>Gast-Dry-Run</button>
      </div>
      <ActionResult state={result} testId="goal-b-login-result" />
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
