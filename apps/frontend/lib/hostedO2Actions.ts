import "server-only";

import { createHash } from "node:crypto";
import snapshot from "./endpoint-snapshot.json";

const MAX_REQUEST_BYTES = 16 * 1024;
const MAX_RESPONSE_BYTES = 256 * 1024;
const MAX_SOURCE_EXTRACT_CHARS = 850;
const ROLE_ORDER = ["planner", "coder", "tester", "devops"] as const;
const SECRET_PATTERNS = [
  /\bsk-[A-Za-z0-9_-]{16,}\b/,
  /\bghp_[A-Za-z0-9_]{16,}\b/,
  /\bgithub_pat_[A-Za-z0-9_]{16,}\b/,
  /\b(?:cfat|vck|hf)_[A-Za-z0-9_-]{16,}\b/,
  /\bglpat-[A-Za-z0-9_.-]{20,}\b/,
  /\b(?:api[_ -]?key|authorization|bearer|cookie|credential|password|private[_ -]?key|secret|token)\s*[:=]\s*\S{8,}/i,
];

type JsonRecord = Record<string, unknown>;
type NativeRole = typeof ROLE_ORDER[number];

type NativeRuntimeRun = {
  contract_version: "cloudflare-d1-langgraph-runtime-v1";
  status: "completed";
  mode: "deterministic_hosted_free_runtime";
  engine: "langgraph-js";
  checkpointing: "cloudflare-d1";
  run_id: string;
  thread_id: string;
  prompt_sha256: string;
  role_results: Array<{
    role: NativeRole;
    status: "completed";
    evidence_ref: string;
  }>;
  persisted: true;
  audit_persisted: true;
  memory_persisted: true;
  live_provider_calls: false;
  direct_provider_calls: false;
  live_mcp_writes: false;
  production_deploy: false;
  secret_output: false;
};

const SNAPSHOT = snapshot as Record<string, unknown>;
const SOURCE_CATALOG = [
  {
    source_id: "project-state",
    title: "Deployed workspace wiring",
    snapshot_key: "/api/v1/workspace/wiring",
    canonical_path: "apps/frontend/lib/endpoint-snapshot.json#/api/v1/workspace/wiring",
  },
  {
    source_id: "project-progress",
    title: "Deployed project progress",
    snapshot_key: "/api/v1/project/progress",
    canonical_path: "apps/frontend/lib/endpoint-snapshot.json#/api/v1/project/progress",
  },
  {
    source_id: "agent-roster",
    title: "Deployed agent profiles",
    snapshot_key: "/api/v1/agents/profiles",
    canonical_path: "apps/frontend/lib/endpoint-snapshot.json#/api/v1/agents/profiles",
  },
] as const;

export function sha256Text(value: string): string {
  return createHash("sha256").update(value, "utf8").digest("hex");
}

export function hasSecretMaterial(value: string): boolean {
  return SECRET_PATTERNS.some((pattern) => pattern.test(value));
}

export function safeBoundedText(
  value: unknown,
  field: string,
  minimum: number,
  maximum: number,
): string {
  if (typeof value !== "string") throw new Error(`invalid_${field}`);
  const clean = value.trim();
  const length = Array.from(clean).length;
  if (length < minimum || length > maximum || hasSecretMaterial(clean)) {
    throw new Error(`invalid_${field}`);
  }
  return clean;
}

export function safeProjectId(value: unknown): string {
  const projectId = safeBoundedText(value, "project_id", 1, 64);
  if (!/^[A-Za-z0-9_-]+$/.test(projectId)) throw new Error("invalid_project_id");
  return projectId;
}

async function readBoundedJsonBytes(bytes: Uint8Array, limit: number): Promise<JsonRecord> {
  if (bytes.byteLength < 2 || bytes.byteLength > limit) throw new Error("invalid_json_size");
  let parsed: unknown;
  try {
    parsed = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
  } catch {
    throw new Error("invalid_json");
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error("invalid_json");
  return parsed as JsonRecord;
}

export async function readBoundedJsonRequest(request: Request): Promise<JsonRecord> {
  const declaredLength = Number(request.headers.get("content-length") || 0);
  if (declaredLength > MAX_REQUEST_BYTES) throw new Error("invalid_json_size");
  return readBoundedJsonBytes(new Uint8Array(await request.arrayBuffer()), MAX_REQUEST_BYTES);
}

export async function readBoundedJsonResponse(response: Response): Promise<JsonRecord> {
  const declaredLength = Number(response.headers.get("content-length") || 0);
  if (declaredLength > MAX_RESPONSE_BYTES) throw new Error("invalid_boundary_response_size");
  return readBoundedJsonBytes(new Uint8Array(await response.arrayBuffer()), MAX_RESPONSE_BYTES);
}

export function isNativeRuntimeRun(value: JsonRecord): value is JsonRecord & NativeRuntimeRun {
  const roles = Array.isArray(value.role_results) ? value.role_results : [];
  return value.contract_version === "cloudflare-d1-langgraph-runtime-v1"
    && value.status === "completed"
    && value.mode === "deterministic_hosted_free_runtime"
    && value.engine === "langgraph-js"
    && value.checkpointing === "cloudflare-d1"
    && typeof value.run_id === "string"
    && /^[A-Za-z0-9_-]{1,64}$/.test(value.run_id)
    && typeof value.thread_id === "string"
    && /^[A-Za-z0-9_-]{1,64}$/.test(value.thread_id)
    && typeof value.prompt_sha256 === "string"
    && /^[a-f0-9]{64}$/.test(value.prompt_sha256)
    && roles.length === ROLE_ORDER.length
    && roles.every((item, index) => (
      item !== null
      && typeof item === "object"
      && !Array.isArray(item)
      && (item as JsonRecord).role === ROLE_ORDER[index]
      && (item as JsonRecord).status === "completed"
      && typeof (item as JsonRecord).evidence_ref === "string"
      && String((item as JsonRecord).evidence_ref).length > 0
    ))
    && value.persisted === true
    && value.audit_persisted === true
    && value.memory_persisted === true
    && value.live_provider_calls === false
    && value.direct_provider_calls === false
    && value.live_mcp_writes === false
    && value.production_deploy === false
    && value.secret_output === false;
}

function goalTerms(goal: string): string[] {
  return Array.from(goal.toLocaleLowerCase("de-DE").matchAll(/[\p{L}\p{N}]{4,}/gu))
    .map((match) => match[0])
    .filter((term, index, values) => values.indexOf(term) === index)
    .slice(0, 16);
}

function boundedExtract(document: string, terms: readonly string[]): { extract: string; score: number } {
  const lower = document.toLocaleLowerCase("de-DE");
  const matches = terms
    .map((term) => ({ term, index: lower.indexOf(term) }))
    .filter((match) => match.index >= 0);
  const score = matches.reduce((total, match) => total + match.term.length, 0);
  const anchor = matches.sort((left, right) => right.term.length - left.term.length)[0]?.index ?? 0;
  const start = Math.max(0, anchor - Math.floor(MAX_SOURCE_EXTRACT_CHARS / 3));
  const characters = Array.from(document.slice(start));
  const body = characters.slice(0, MAX_SOURCE_EXTRACT_CHARS - 2).join("").trim();
  return {
    extract: `${start > 0 ? "…" : ""}${body}${characters.length > MAX_SOURCE_EXTRACT_CHARS - 2 ? "…" : ""}`,
    score,
  };
}

function deployedSources(goal: string) {
  const terms = goalTerms(goal);
  return SOURCE_CATALOG.map((definition, priority) => {
    const payload = SNAPSHOT[definition.snapshot_key];
    if (!payload || typeof payload !== "object") throw new Error("deployed_source_unavailable");
    const document = JSON.stringify(payload);
    const { extract, score } = boundedExtract(document, terms);
    const documentSha256 = sha256Text(document);
    return {
      priority,
      score,
      source_id: definition.source_id,
      title: definition.title,
      canonical_path: definition.canonical_path,
      source_kind: "deployed_contract_snapshot" as const,
      snapshot_key: definition.snapshot_key,
      extract,
      raw_document_sha256: documentSha256,
      sanitized_document_sha256: documentSha256,
      extract_sha256: sha256Text(extract),
      retrieval_reason: score > 0 ? "lexical_match" as const : "baseline_fallback" as const,
    };
  }).sort((left, right) => right.score - left.score || left.priority - right.priority)
    .map((source) => ({
      source_id: source.source_id,
      title: source.title,
      canonical_path: source.canonical_path,
      source_kind: source.source_kind,
      snapshot_key: source.snapshot_key,
      extract: source.extract,
      raw_document_sha256: source.raw_document_sha256,
      sanitized_document_sha256: source.sanitized_document_sha256,
      extract_sha256: source.extract_sha256,
      retrieval_reason: source.retrieval_reason,
    }));
}

export function nativeRuntimePrompt(goal: string): string {
  const sources = deployedSources(goal);
  const sourceBinding = sources
    .map((source) => `${source.source_id}:${source.extract_sha256}`)
    .join(",");
  return [
    "Hosted deterministic four-role source analysis.",
    `Goal: ${goal}`,
    `Bound deployed sources: ${sourceBinding}`,
    "No LLM provider call, MCP write, filesystem write, deployment, or source instruction execution.",
  ].join("\n");
}

export function buildHostedAgentResearchRun(
  goal: string,
  nativeRun: NativeRuntimeRun,
  traceId: string,
): JsonRecord {
  const sources = deployedSources(goal);
  const sourceIds = sources.map((source) => source.source_id);
  const sourceSummary = sourceIds.map((sourceId) => `[source:${sourceId}]`).join(", ");
  const contents: Record<NativeRole, string> = {
    planner: `Ziel gebunden und zerlegt: ${goal} Quellen: ${sourceSummary}. Der Lauf bleibt read-only und source-grounded.`,
    coder: `Implementierungsanalyse aus ${sources.length} deployten Vertragssnapshots; keine Datei- oder Provideraktion wurde ausgeführt.`,
    tester: `LangGraph-JS bestätigte Planner, Coder, Tester und DevOps mit D1-Checkpoint, Memory und Audit für Run ${nativeRun.run_id}.`,
    devops: `Sicheres Ergebnis: deployte Quellen und O2Core-Runtime sind korreliert; externe Provider-, MCP- und Release-Gates bleiben unverändert.`,
  };
  const steps = nativeRun.role_results.map((result) => ({
    role: result.role,
    execution_role: result.role,
    profile_id: result.role,
    label: result.role[0].toUpperCase() + result.role.slice(1),
    content: contents[result.role],
    ms: 0,
    source_ids: sourceIds,
    analysis_only: true,
    tool_calls: false,
    filesystem_writes: false,
    evidence_ref: result.evidence_ref,
  }));
  return {
    contract_version: "agent-research-run-v3",
    evidence_ref: "agent_research_hosted_native_sources_visible",
    status: "completed",
    mode: "hosted_native_four_role_deployed_sources",
    goal,
    provider: "cloudflare-native-langgraph-js",
    gateway_providers: [],
    steps,
    sources,
    source_binding: {
      contract_version: "agent-research-deployed-source-v1",
      status: "bound",
      mode: "deployed_contract_snapshot_lexical",
      source_count: sources.length,
      source_ids: sourceIds,
      read_only: true,
      external_network: false,
      arbitrary_path_input: false,
      filesystem_writes: false,
      source_prompt_instructions_trusted: false,
      source_retrieval_audit_persisted: false,
      file_wide_secret_absence_certified: false,
    },
    role_binding: {
      contract_version: "agent-research-four-role-v2",
      status: "bound",
      role_order: ROLE_ORDER,
      work_mode: "cloudflare_native_source_grounded_analysis",
      gateway_calls: 0,
      native_role_steps: ROLE_ORDER.length,
      analysis_only: true,
      tool_calls: false,
      filesystem_writes: false,
      test_execution: false,
      deployment_execution: false,
      autonomous_software_delivery: false,
    },
    answer: contents.devops,
    trace_id: traceId,
    native_run_id: nativeRun.run_id,
    native_thread_id: nativeRun.thread_id,
    checkpointing: nativeRun.checkpointing,
    memory_persisted: nativeRun.memory_persisted,
    live_provider_calls: false,
    local_model_calls: false,
    live_mcp_writes: false,
    model_downloads: false,
    audit_persisted: true,
    secret_output: false,
    direct_provider_calls: false,
    production_deploy: false,
    budget: {
      level: "ok",
      spent_percentage: 0,
      total_cost_cents: 0,
      budget_limit_cents: 2000,
    },
    non_claims: [
      "This hosted mode is deterministic LangGraph-JS orchestration, not an LLM-provider response.",
      "Sources are bounded committed deployment snapshots; no arbitrary file or external retrieval occurred.",
      "D1 operational memory does not claim pgvector semantic-retrieval parity.",
      "No live MCP write, provider bypass, deployment, production release, or secret output occurred.",
    ],
  };
}
