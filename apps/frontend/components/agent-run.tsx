"use client";

import { useState } from "react";

const SOURCE_PATHS = {
  "project-state": "PROJECT_STATE.md",
  "project-progress": "docs/project-progress.manifest.json",
  "agent-roster": "docs/codex-integration/autonomous-agent-roster.json",
} as const;
const STEP_ROLES = ["planner", "coder", "tester", "devops"] as const;

type SourceId = keyof typeof SOURCE_PATHS;
type StepRole = typeof STEP_ROLES[number];
type Source = {
  source_id: SourceId;
  title: string;
  canonical_path: string;
  extract: string;
  raw_document_sha256: string;
  sanitized_document_sha256: string;
  extract_sha256: string;
  retrieval_reason: "lexical_match" | "baseline_fallback";
};
type SourceBinding = {
  contract_version: "agent-research-repo-source-v1";
  status: "bound";
  mode: "repo_allowlist_lexical";
  source_count: number;
  source_ids: SourceId[];
  read_only: true;
  external_network: false;
  arbitrary_path_input: false;
  filesystem_writes: false;
  source_prompt_instructions_trusted: false;
  source_retrieval_audit_persisted: false;
  file_wide_secret_absence_certified: false;
};
type RoleBinding = {
  contract_version: "agent-research-four-role-v1";
  status: "bound";
  role_order: StepRole[];
  work_mode: "source_grounded_analysis";
  gateway_calls: 4;
  analysis_only: true;
  tool_calls: false;
  filesystem_writes: false;
  test_execution: false;
  deployment_execution: false;
  autonomous_software_delivery: false;
};
type Step = {
  role: StepRole;
  execution_role: StepRole;
  profile_id: StepRole;
  label: string;
  content: string;
  ms: number;
  source_ids: SourceId[];
  analysis_only: true;
  tool_calls: false;
  filesystem_writes: false;
};
type Budget = {
  level: "ok" | "warning" | "critical";
  spent_percentage: number;
  total_cost_cents: number;
  budget_limit_cents: number;
};
type Run = {
  contract_version: "agent-research-run-v3";
  evidence_ref: "agent_research_four_role_repo_sources_visible";
  status: "completed";
  mode: "dev_only_gateway_four_role_repo_sources";
  goal: string;
  provider: string;
  gateway_providers: string[];
  steps: Step[];
  sources: Source[];
  source_binding: SourceBinding;
  role_binding: RoleBinding;
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
  budget: Budget;
  non_claims: string[];
};

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

function isBudget(body: unknown): body is Budget {
  if (!body || typeof body !== "object" || Array.isArray(body)) return false;
  const budget = body as Partial<Budget>;
  return (budget.level === "ok" || budget.level === "warning" || budget.level === "critical")
    && typeof budget.spent_percentage === "number"
    && Number.isFinite(budget.spent_percentage)
    && budget.spent_percentage >= 0
    && typeof budget.total_cost_cents === "number"
    && Number.isInteger(budget.total_cost_cents)
    && budget.total_cost_cents >= 0
    && typeof budget.budget_limit_cents === "number"
    && Number.isInteger(budget.budget_limit_cents)
    && budget.budget_limit_cents > 0;
}

function isSource(body: unknown): body is Source {
  if (!body || typeof body !== "object") return false;
  const source = body as Partial<Source>;
  const sourceId = source.source_id;
  return typeof sourceId === "string"
    && sourceId in SOURCE_PATHS
    && typeof source.title === "string"
    && source.canonical_path === SOURCE_PATHS[sourceId as SourceId]
    && typeof source.extract === "string"
    && Array.from(source.extract).length >= 1
    && Array.from(source.extract).length <= 900
    && typeof source.raw_document_sha256 === "string"
    && /^[a-f0-9]{64}$/.test(source.raw_document_sha256)
    && typeof source.sanitized_document_sha256 === "string"
    && /^[a-f0-9]{64}$/.test(source.sanitized_document_sha256)
    && typeof source.extract_sha256 === "string"
    && /^[a-f0-9]{64}$/.test(source.extract_sha256)
    && (source.retrieval_reason === "lexical_match" || source.retrieval_reason === "baseline_fallback");
}

function isRun(body: unknown): body is Run {
  if (!body || typeof body !== "object") return false;
  const candidate = body as Partial<Run>;
  const binding = candidate.source_binding as Partial<SourceBinding> | undefined;
  const roleBinding = candidate.role_binding as Partial<RoleBinding> | undefined;
  const sourceIds = Array.isArray(candidate.sources)
    ? candidate.sources.map((source) => (source as Partial<Source>).source_id)
    : [];
  return candidate.contract_version === "agent-research-run-v3"
    && candidate.evidence_ref === "agent_research_four_role_repo_sources_visible"
    && candidate.status === "completed"
    && candidate.mode === "dev_only_gateway_four_role_repo_sources"
    && isNonEmptyString(candidate.goal)
    && isNonEmptyString(candidate.provider)
    && Array.isArray(candidate.gateway_providers)
    && candidate.gateway_providers.every(isNonEmptyString)
    && isNonEmptyString(candidate.answer)
    && Array.isArray(candidate.steps)
    && candidate.steps.length === STEP_ROLES.length
    && candidate.steps.every((step, index) => (
      step.role === STEP_ROLES[index]
      && step.execution_role === STEP_ROLES[index]
      && step.profile_id === STEP_ROLES[index]
      && typeof step.label === "string"
      && typeof step.content === "string"
      && step.content.length >= 1
      && Array.from(step.content).length <= 2000
      && typeof step.ms === "number"
      && Number.isFinite(step.ms)
      && step.ms >= 0
      && Array.isArray(step.source_ids)
      && step.source_ids.join(",") === sourceIds.join(",")
      && step.analysis_only === true
      && step.tool_calls === false
      && step.filesystem_writes === false
    ))
    && candidate.answer === candidate.steps.at(-1)?.content
    && Array.isArray(candidate.sources)
    && candidate.sources.length >= 1
    && candidate.sources.length <= 3
    && candidate.sources.every(isSource)
    && new Set(sourceIds).size === sourceIds.length
    && binding?.contract_version === "agent-research-repo-source-v1"
    && binding.status === "bound"
    && binding.mode === "repo_allowlist_lexical"
    && binding.source_count === candidate.sources.length
    && Array.isArray(binding.source_ids)
    && binding.source_ids.join(",") === sourceIds.join(",")
    && binding.read_only === true
    && binding.external_network === false
    && binding.arbitrary_path_input === false
    && binding.filesystem_writes === false
    && binding.source_prompt_instructions_trusted === false
    && binding.source_retrieval_audit_persisted === false
    && binding.file_wide_secret_absence_certified === false
    && roleBinding?.contract_version === "agent-research-four-role-v1"
    && roleBinding.status === "bound"
    && Array.isArray(roleBinding.role_order)
    && roleBinding.role_order.join(",") === STEP_ROLES.join(",")
    && roleBinding.work_mode === "source_grounded_analysis"
    && roleBinding.gateway_calls === 4
    && roleBinding.analysis_only === true
    && roleBinding.tool_calls === false
    && roleBinding.filesystem_writes === false
    && roleBinding.test_execution === false
    && roleBinding.deployment_execution === false
    && roleBinding.autonomous_software_delivery === false
    && candidate.direct_provider_calls === false
    && candidate.live_mcp_writes === false
    && candidate.production_deploy === false
    && candidate.secret_output === false
    && typeof candidate.live_provider_calls === "boolean"
    && typeof candidate.local_model_calls === "boolean"
    && typeof candidate.model_downloads === "boolean"
    && typeof candidate.audit_persisted === "boolean"
    && isNonEmptyString(candidate.trace_id)
    && isBudget(candidate.budget)
    && Array.isArray(candidate.non_claims)
    && candidate.non_claims.every(isNonEmptyString);
}

// Multi-agent runner. The server route forwards only to the Agent API boundary;
// an unavailable stateful runtime is surfaced as an explicit error.
export function AgentRun() {
  const [goal, setGoal] = useState("Wie nutzt Cloud Superbrain pgvector und Embeddings für die Speichersuche?");
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
        setErr("Agent API lieferte keine vollständige agent-research-run-v3-Antwort.");
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
          data-audit-persisted={String(run.audit_persisted)}
          data-analysis-only={String(run.role_binding.analysis_only)}
          data-role-count={String(run.role_binding.gateway_calls)}
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
              <span className="badge badge-green">
                sources={run.source_binding.source_count} · read-only
              </span>
              <span className="badge badge-green">
                roles={run.role_binding.gateway_calls} · analysis-only
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
            <div className="ar-step-head"><b>Ergebnis</b><span className="mono text-12 text-mut">DevOps-Synthese · {run.provider}</span></div>
            <div className="ar-answer-body">{run.answer}</div>
          </div>
          {run.sources.length ? (
            <div className="ar-sources">
              <b className="text-13">Quellen ({run.sources.length})</b>
              {run.sources.map((s, i) => (
                <details
                  key={s.source_id}
                  className="ar-source note"
                  data-testid={`ar-source-detail-${s.source_id}`}
                >
                  <summary className="mono text-12">[{i + 1}] {s.title}</summary>
                  <p className="mono text-12 text-mut">
                    {s.canonical_path} · {s.retrieval_reason}
                  </p>
                  <p className="mono text-12 text-mut" style={{ overflowWrap: "anywhere" }}>
                    raw-sha256={s.raw_document_sha256}
                    <br />
                    sanitized-sha256={s.sanitized_document_sha256}
                    <br />
                    extract-sha256={s.extract_sha256}
                  </p>
                  <p className="ar-source-extract text-12 text-mut">{s.extract}</p>
                </details>
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
