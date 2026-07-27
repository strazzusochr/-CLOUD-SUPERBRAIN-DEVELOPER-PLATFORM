"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { Badge } from "../ui";

const MAX_RESPONSE_BYTES = 1_048_576;
const MAX_STRING_LIST_ITEMS = 128;
const MAX_PROVIDER_RESOURCES = 256;
const MAX_PREFLIGHT_GATES = 32;
const EXACT_PROVIDER_COUNT = 8;
const INVENTORY_PATH = "/api/v1/clouds";
const LAYERS_PATH = "/api/v1/clouds/layers";
const PREFLIGHT_PATH = "/api/v1/clouds/deployment-preflight";
const EXPECTED_LAYER_IDS = [
  "layer_1",
  "layer_2",
  "layer_3",
  "layer_4",
  "layer_5",
  "layer_6",
  "layer_7",
] as const;
const CLOUDFLARE_LAYER_IDS = ["layer_2", "layer_3", "layer_4", "layer_6", "layer_7"] as const;
const RESPONSE_SOURCES = ["agent-api-boundary", "project-state-projection", "frontend-projection"] as const;
const PROVIDER_FILTERS = ["all", "configured", "live_verified", "action_required", "historical_only"] as const;

type ResponseSource = typeof RESPONSE_SOURCES[number];
type ProviderFilter = typeof PROVIDER_FILTERS[number];
type LoadState = "loading" | "ready" | "error";

type Provider = {
  id: string;
  label: string;
  role: string;
  layers: string[];
  configured: boolean;
  live_verified: boolean;
  status: string;
  required_env: string[];
  optional_env: string[];
  env_status: Array<{ key: string; configured: boolean }>;
  resources: Record<string, unknown>[];
  monthly_cost_cents: number | null;
  last_checked_at: string | null;
  non_claims: string[];
  historical_only?: boolean;
};

type LayerMapping = {
  layer_id: string;
  label: string;
  providers: string[];
  evidence_ref: "cloud_provider_inventory_visible";
};

type CloudInventory = {
  contract_version: "cloud-provider-inventory-v1";
  status: "complete" | "partial" | "action_required";
  endpoint: "GET /api/v1/clouds";
  evidence_ref: "cloud_provider_inventory_visible";
  configured_count: number;
  live_verified_count: number;
  total_count: number;
  providers: Provider[];
  seven_layer_mapping: LayerMapping[];
  policy_checks: string[];
  non_claims: string[];
};

type LayerReadiness = {
  layer_id: string;
  label: string;
  status: "live_verified" | "partial_live_verified" | "action_required" | "metadata_ready";
  required_providers: string[];
  configured_providers: string[];
  live_verified_providers: string[];
  blockers: string[];
  evidence_ref: "cloud_layer_readiness_visible";
  next_safe_action: string;
  non_claims: string[];
};

type CloudLayers = {
  contract_version: "cloud-layer-readiness-v1";
  status: "verified" | "partial" | "action_required";
  endpoint: "GET /api/v1/clouds/layers";
  evidence_ref: "cloud_layer_readiness_visible";
  ready_layer_count: number;
  partial_layer_count: number;
  total_layer_count: number;
  layers: LayerReadiness[];
  provider_inventory_endpoint: "GET /api/v1/clouds";
  provider_inventory_evidence_ref: "cloud_provider_inventory_visible";
  policy_checks: string[];
  non_claims: string[];
};

type PreflightGate = {
  id: string;
  label: string;
  required_env: string[];
  required_scopes?: string[];
  required_artifact: string;
  verifier: string;
  environment_configured: boolean;
  tool_configured?: boolean;
  configured: boolean;
  verified: boolean;
  evidence_ref: string;
  required_evidence_artifact: string;
  next_action: string;
};

type CloudPreflight = {
  contract_version: "cloud-deployment-preflight-v1";
  status: "verified" | "ready_for_external_execution" | "action_required";
  endpoint: "GET /api/v1/clouds/deployment-preflight";
  evidence_ref: "cloud_deployment_preflight_visible";
  required_sequence: string[];
  gates: PreflightGate[];
  missing_or_blocked_gates: string[];
  preflight_ready: boolean;
  external_execution_ready: boolean;
  cloud_deploy_claim_allowed: boolean;
  production_deploy_claim_allowed: boolean;
  canonical_summary_status: string;
  canonical_summary_source_artifact: string;
  localhost_role: "dev_control_plane_only";
  manual_external_actions: string[];
  claim_policy: string;
  policy_checks: string[];
  non_claims: string[];
};

type SourceResult<T> = {
  payload: T;
  responseSource: ResponseSource;
};

type TechnologyRuntime = {
  inventory: SourceResult<CloudInventory>;
  layers: SourceResult<CloudLayers>;
  preflight: SourceResult<CloudPreflight>;
};

type SourceDefinition = {
  label: string;
  path: string;
  endpoint: string;
  contract: string;
  evidence: string;
};

const SOURCE_DEFINITIONS: SourceDefinition[] = [
  {
    label: "Provider-Inventar",
    path: INVENTORY_PATH,
    endpoint: "GET /api/v1/clouds",
    contract: "cloud-provider-inventory-v1",
    evidence: "cloud_provider_inventory_visible",
  },
  {
    label: "Schichtbereitschaft",
    path: LAYERS_PATH,
    endpoint: "GET /api/v1/clouds/layers",
    contract: "cloud-layer-readiness-v1",
    evidence: "cloud_layer_readiness_visible",
  },
  {
    label: "Deployment-Preflight",
    path: PREFLIGHT_PATH,
    endpoint: "GET /api/v1/clouds/deployment-preflight",
    contract: "cloud-deployment-preflight-v1",
    evidence: "cloud_deployment_preflight_visible",
  },
];

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

function isNonNegativeInteger(value: unknown): value is number {
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 0;
}

function isStringArray(
  value: unknown,
  allowEmpty = true,
  maxItems = MAX_STRING_LIST_ITEMS,
): value is string[] {
  return Array.isArray(value)
    && (allowEmpty || value.length > 0)
    && value.length <= maxItems
    && value.every(isNonEmptyString)
    && new Set(value).size === value.length;
}

function hasSameMembers(left: readonly string[], right: readonly string[]): boolean {
  return left.length === right.length
    && left.every((item) => right.includes(item))
    && right.every((item) => left.includes(item));
}

function isResponseSource(value: string | null): value is ResponseSource {
  return value !== null && RESPONSE_SOURCES.some((source) => source === value);
}

function isProvider(value: unknown): value is Provider {
  if (!isRecord(value)) return false;
  if (
    !isNonEmptyString(value.id)
    || !isNonEmptyString(value.label)
    || !isNonEmptyString(value.role)
    || !isStringArray(value.layers)
    || value.layers.some((layer) => !/^layer_[1-7]$/.test(layer))
    || typeof value.configured !== "boolean"
    || typeof value.live_verified !== "boolean"
    || !isNonEmptyString(value.status)
    || !isStringArray(value.required_env)
    || !isStringArray(value.optional_env)
    || !Array.isArray(value.env_status)
    || value.env_status.length > MAX_STRING_LIST_ITEMS
    || !value.env_status.every((item) => (
      isRecord(item)
      && isNonEmptyString(item.key)
      && typeof item.configured === "boolean"
    ))
    || !Array.isArray(value.resources)
    || value.resources.length > MAX_PROVIDER_RESOURCES
    || !value.resources.every((item) => (
      isRecord(item)
      && (item.source === undefined || isNonEmptyString(item.source))
    ))
    || !(value.monthly_cost_cents === null || isNonNegativeInteger(value.monthly_cost_cents))
    || !(value.last_checked_at === null || isNonEmptyString(value.last_checked_at))
    || !isStringArray(value.non_claims, false)
    || !(value.historical_only === undefined || typeof value.historical_only === "boolean")
  ) {
    return false;
  }

  const envKeys = [...value.required_env, ...value.optional_env];
  const statusKeys = value.env_status.map((item) => item.key);
  return hasSameMembers(envKeys, statusKeys);
}

function isLayerMapping(value: unknown): value is LayerMapping {
  if (!isRecord(value)) return false;
  return /^layer_[1-7]$/.test(String(value.layer_id))
    && isNonEmptyString(value.label)
    && isStringArray(value.providers, false)
    && value.evidence_ref === "cloud_provider_inventory_visible";
}

function isCloudInventory(value: unknown): value is CloudInventory {
  if (!isRecord(value)) return false;
  if (
    value.contract_version !== "cloud-provider-inventory-v1"
    || !["complete", "partial", "action_required"].includes(String(value.status))
    || value.endpoint !== "GET /api/v1/clouds"
    || value.evidence_ref !== "cloud_provider_inventory_visible"
    || !isNonNegativeInteger(value.configured_count)
    || !isNonNegativeInteger(value.live_verified_count)
    || !isNonNegativeInteger(value.total_count)
    || !Array.isArray(value.providers)
    || value.providers.length !== EXACT_PROVIDER_COUNT
    || !value.providers.every(isProvider)
    || value.total_count !== EXACT_PROVIDER_COUNT
    || value.total_count !== value.providers.length
    || !Array.isArray(value.seven_layer_mapping)
    || value.seven_layer_mapping.length !== EXPECTED_LAYER_IDS.length
    || !value.seven_layer_mapping.every(isLayerMapping)
    || !isStringArray(value.policy_checks, false)
    || !isStringArray(value.non_claims, false)
  ) {
    return false;
  }

  const providerIds = value.providers.map((provider) => provider.id);
  const layerIds = value.seven_layer_mapping.map((layer) => layer.layer_id);
  const fly = value.providers.filter((provider) => provider.id === "fly_io");
  const cloudflare = value.providers.filter((provider) => provider.id === "cloudflare_edge");
  const configuredCount = value.providers.filter((provider) => provider.configured).length;
  const liveCount = value.providers.filter((provider) => provider.live_verified).length;
  const expectedStatus = configuredCount === value.providers.length
    ? "complete"
    : configuredCount > 0
      ? "partial"
      : "action_required";

  return new Set(providerIds).size === providerIds.length
    && hasSameMembers(layerIds, EXPECTED_LAYER_IDS)
    && value.seven_layer_mapping.every((mapping) => (
      mapping.providers.every((providerId) => providerIds.includes(providerId) && providerId !== "fly_io")
    ))
    && configuredCount === value.configured_count
    && liveCount === value.live_verified_count
    && value.status === expectedStatus
    && fly.length === 1
    && fly[0].historical_only === true
    && ["historical_only", "historical_read_verified"].includes(fly[0].status)
    && fly[0].layers.length === 0
    && cloudflare.length === 1
    && hasSameMembers(cloudflare[0].layers, CLOUDFLARE_LAYER_IDS);
}

function isLayerReadiness(value: unknown): value is LayerReadiness {
  if (!isRecord(value)) return false;
  if (
    !/^layer_[1-7]$/.test(String(value.layer_id))
    || !isNonEmptyString(value.label)
    || !["live_verified", "partial_live_verified", "action_required", "metadata_ready"].includes(String(value.status))
    || !isStringArray(value.required_providers, false)
    || !isStringArray(value.configured_providers)
    || !isStringArray(value.live_verified_providers)
    || !isStringArray(value.blockers)
    || value.evidence_ref !== "cloud_layer_readiness_visible"
    || !isNonEmptyString(value.next_safe_action)
    || !isStringArray(value.non_claims, false)
  ) {
    return false;
  }

  const expectedStatus: LayerReadiness["status"] = (
    value.blockers.length === 0
    && value.live_verified_providers.length >= value.required_providers.length
  )
    ? "live_verified"
    : value.live_verified_providers.length > 0
      ? "partial_live_verified"
      : value.blockers.length > 0
        ? "action_required"
        : "metadata_ready";
  return value.status === expectedStatus;
}

function isCloudLayers(value: unknown): value is CloudLayers {
  if (!isRecord(value)) return false;
  if (
    value.contract_version !== "cloud-layer-readiness-v1"
    || !["verified", "partial", "action_required"].includes(String(value.status))
    || value.endpoint !== "GET /api/v1/clouds/layers"
    || value.evidence_ref !== "cloud_layer_readiness_visible"
    || !isNonNegativeInteger(value.ready_layer_count)
    || !isNonNegativeInteger(value.partial_layer_count)
    || !isNonNegativeInteger(value.total_layer_count)
    || !Array.isArray(value.layers)
    || value.layers.length !== EXPECTED_LAYER_IDS.length
    || !value.layers.every(isLayerReadiness)
    || value.total_layer_count !== value.layers.length
    || value.provider_inventory_endpoint !== "GET /api/v1/clouds"
    || value.provider_inventory_evidence_ref !== "cloud_provider_inventory_visible"
    || !isStringArray(value.policy_checks, false)
    || !isStringArray(value.non_claims, false)
  ) {
    return false;
  }

  const layerIds = value.layers.map((layer) => layer.layer_id);
  const readyCount = value.layers.filter((layer) => layer.status === "live_verified").length;
  const partialCount = value.layers.filter((layer) => layer.status === "partial_live_verified").length;
  const expectedStatus = readyCount === value.layers.length
    ? "verified"
    : readyCount > 0 || partialCount > 0
      ? "partial"
      : "action_required";
  return new Set(layerIds).size === layerIds.length
    && hasSameMembers(layerIds, EXPECTED_LAYER_IDS)
    && readyCount === value.ready_layer_count
    && partialCount === value.partial_layer_count
    && value.status === expectedStatus;
}

function isPreflightGate(value: unknown): value is PreflightGate {
  if (!isRecord(value)) return false;
  return isNonEmptyString(value.id)
    && isNonEmptyString(value.label)
    && isStringArray(value.required_env)
    && (value.required_scopes === undefined || isStringArray(value.required_scopes))
    && isNonEmptyString(value.required_artifact)
    && isNonEmptyString(value.verifier)
    && typeof value.environment_configured === "boolean"
    && (value.tool_configured === undefined || typeof value.tool_configured === "boolean")
    && typeof value.configured === "boolean"
    && typeof value.verified === "boolean"
    && isNonEmptyString(value.evidence_ref)
    && isNonEmptyString(value.required_evidence_artifact)
    && isNonEmptyString(value.next_action);
}

function isCloudPreflight(value: unknown): value is CloudPreflight {
  if (!isRecord(value)) return false;
  if (
    value.contract_version !== "cloud-deployment-preflight-v1"
    || !["verified", "ready_for_external_execution", "action_required"].includes(String(value.status))
    || value.endpoint !== "GET /api/v1/clouds/deployment-preflight"
    || value.evidence_ref !== "cloud_deployment_preflight_visible"
    || !isStringArray(value.required_sequence, false)
    || !Array.isArray(value.gates)
    || value.gates.length === 0
    || value.gates.length > MAX_PREFLIGHT_GATES
    || !value.gates.every(isPreflightGate)
    || !isStringArray(value.missing_or_blocked_gates)
    || typeof value.preflight_ready !== "boolean"
    || typeof value.external_execution_ready !== "boolean"
    || typeof value.cloud_deploy_claim_allowed !== "boolean"
    || typeof value.production_deploy_claim_allowed !== "boolean"
    || !isNonEmptyString(value.canonical_summary_status)
    || !isNonEmptyString(value.canonical_summary_source_artifact)
    || value.localhost_role !== "dev_control_plane_only"
    || !isStringArray(value.manual_external_actions, false)
    || !isNonEmptyString(value.claim_policy)
    || !isStringArray(value.policy_checks, false)
    || !isStringArray(value.non_claims, false)
  ) {
    return false;
  }

  const gateIds = value.gates.map((gate) => gate.id);
  const actualMissing = value.gates.filter((gate) => !gate.verified).map((gate) => gate.id);
  const ready = actualMissing.length === 0;
  const expectedStatus = !ready
    ? "action_required"
    : value.production_deploy_claim_allowed
      ? "verified"
      : "ready_for_external_execution";
  return new Set(gateIds).size === gateIds.length
    && hasSameMembers(value.missing_or_blocked_gates, actualMissing)
    && value.preflight_ready === ready
    && value.external_execution_ready === ready
    && value.cloud_deploy_claim_allowed === ready
    && (!value.production_deploy_claim_allowed || ready)
    && value.status === expectedStatus;
}

function areContractsConsistent(
  inventory: CloudInventory,
  layers: CloudLayers,
  preflight: CloudPreflight,
  requireVolatileParity: boolean,
): boolean {
  const providers = new Map(inventory.providers.map((provider) => [provider.id, provider]));
  const mappings = new Map(inventory.seven_layer_mapping.map((mapping) => [mapping.layer_id, mapping]));

  const layersMatch = layers.layers.every((layer) => {
    const mapping = mappings.get(layer.layer_id);
    if (!mapping || mapping.label !== layer.label || !hasSameMembers(mapping.providers, layer.required_providers)) {
      return false;
    }
    const structuralParity = layer.configured_providers.every((providerId) => mapping.providers.includes(providerId))
      && layer.live_verified_providers.every((providerId) => (
        mapping.providers.includes(providerId) && layer.configured_providers.includes(providerId)
      ));
    if (!structuralParity || !requireVolatileParity) return structuralParity;

    const expectedConfigured = mapping.providers.filter((providerId) => providers.get(providerId)?.configured === true);
    const expectedLive = mapping.providers.filter((providerId) => providers.get(providerId)?.live_verified === true);
    return hasSameMembers(expectedConfigured, layer.configured_providers)
      && hasSameMembers(expectedLive, layer.live_verified_providers);
  });

  const flyIsHistorical = providers.get("fly_io")?.historical_only === true
    && !inventory.seven_layer_mapping.some((mapping) => mapping.providers.includes("fly_io"));
  const requiredMappingsBelongToProviders = inventory.seven_layer_mapping.every((mapping) => (
    mapping.providers.every((providerId) => providers.get(providerId)?.layers.includes(mapping.layer_id) === true)
  ));
  const cloudflareLayers = providers.get("cloudflare_edge")?.layers ?? [];
  const missingCloudflareGate = preflight.missing_or_blocked_gates.includes(
    "cloudflare_native_zero_card_hosted_runtime",
  );
  const cloudflareHosted = providers.get("cloudflare_edge")?.live_verified === true;

  return layersMatch
    && flyIsHistorical
    && requiredMappingsBelongToProviders
    && hasSameMembers(cloudflareLayers, CLOUDFLARE_LAYER_IDS)
    && (cloudflareHosted || missingCloudflareGate);
}

async function readBoundedJson(response: Response): Promise<unknown> {
  const declaredLength = response.headers.get("content-length");
  if (declaredLength !== null) {
    const parsedLength = Number(declaredLength);
    if (!Number.isSafeInteger(parsedLength) || parsedLength < 0 || parsedLength > MAX_RESPONSE_BYTES) {
      throw new Error("Antwort überschreitet das zulässige Größenlimit.");
    }
  }
  if (!response.body) throw new Error("Leere JSON-Antwort.");

  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > MAX_RESPONSE_BYTES) {
      await reader.cancel();
      throw new Error("Antwort überschreitet das zulässige Größenlimit.");
    }
    chunks.push(value);
  }
  if (total === 0) throw new Error("Leere JSON-Antwort.");

  const merged = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    merged.set(chunk, offset);
    offset += chunk.byteLength;
  }
  try {
    const text = new TextDecoder("utf-8", { fatal: true }).decode(merged).replace(/^\uFEFF/, "");
    return JSON.parse(text) as unknown;
  } catch {
    throw new Error("Antwort enthält kein gültiges UTF-8-JSON.");
  }
}

async function fetchSource(path: string): Promise<SourceResult<unknown>> {
  const response = await fetch(path, {
    method: "GET",
    cache: "no-store",
    headers: { accept: "application/json" },
  });
  if (!response.ok) throw new Error(`Runtime-Quelle nicht verfügbar (${response.status}).`);
  const contentType = response.headers.get("content-type")?.toLowerCase() ?? "";
  if (!contentType.includes("application/json")) throw new Error("Runtime-Quelle liefert kein JSON.");
  const responseSource = response.headers.get("x-superbrain-source");
  if (!isResponseSource(responseSource)) throw new Error("Runtime-Quelle ist nicht explizit typisiert.");
  return {
    payload: await readBoundedJson(response),
    responseSource,
  };
}

function matchesFilter(provider: Provider, filter: ProviderFilter): boolean {
  if (filter === "all") return true;
  if (filter === "configured") return provider.configured;
  if (filter === "live_verified") return provider.live_verified && provider.historical_only !== true;
  if (filter === "historical_only") return provider.historical_only === true;
  return provider.historical_only !== true && !provider.live_verified;
}

function filterLabel(filter: ProviderFilter): string {
  const labels: Record<ProviderFilter, string> = {
    all: "Alle",
    configured: "Konfiguriert",
    live_verified: "Live verifiziert",
    action_required: "Aktion erforderlich",
    historical_only: "Nur historisch",
  };
  return labels[filter];
}

function sourceFor(runtime: TechnologyRuntime, index: number): ResponseSource {
  if (index === 0) return runtime.inventory.responseSource;
  if (index === 1) return runtime.layers.responseSource;
  return runtime.preflight.responseSource;
}

export default function TechnologyRuntimeView() {
  const [state, setState] = useState<LoadState>("loading");
  const [runtime, setRuntime] = useState<TechnologyRuntime | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [providerFilter, setProviderFilter] = useState<ProviderFilter>("all");
  const [selectedLayerId, setSelectedLayerId] = useState<string>("layer_1");
  const [refreshCount, setRefreshCount] = useState(0);
  const initialLoadStarted = useRef(false);
  const inFlight = useRef(false);

  const loadRuntime = useCallback(async () => {
    if (inFlight.current) return;
    inFlight.current = true;
    setState("loading");
    setRuntime(null);
    setError(null);
    try {
      const [inventoryResult, layersResult, preflightResult] = await Promise.all([
        fetchSource(INVENTORY_PATH),
        fetchSource(LAYERS_PATH),
        fetchSource(PREFLIGHT_PATH),
      ]);
      const currentLiveProof = [
        inventoryResult.responseSource,
        layersResult.responseSource,
        preflightResult.responseSource,
      ].every((source) => source === "agent-api-boundary");
      if (
        !isCloudInventory(inventoryResult.payload)
        || !isCloudLayers(layersResult.payload)
        || !isCloudPreflight(preflightResult.payload)
        || !areContractsConsistent(
          inventoryResult.payload,
          layersResult.payload,
          preflightResult.payload,
          currentLiveProof,
        )
      ) {
        throw new Error("Runtime-Verträge oder deren Querverweise sind ungültig.");
      }

      const nextRuntime: TechnologyRuntime = {
        inventory: {
          payload: inventoryResult.payload,
          responseSource: inventoryResult.responseSource,
        },
        layers: {
          payload: layersResult.payload,
          responseSource: layersResult.responseSource,
        },
        preflight: {
          payload: preflightResult.payload,
          responseSource: preflightResult.responseSource,
        },
      };
      setRuntime(nextRuntime);
      setSelectedLayerId((current) => (
        nextRuntime.layers.payload.layers.some((layer) => layer.layer_id === current)
          ? current
          : nextRuntime.layers.payload.layers[0].layer_id
      ));
      setRefreshCount((current) => current + 1);
      setState("ready");
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "Runtime-Verträge konnten nicht geladen werden.");
      setState("error");
    } finally {
      inFlight.current = false;
    }
  }, []);

  useEffect(() => {
    if (initialLoadStarted.current) return;
    initialLoadStarted.current = true;
    void loadRuntime();
  }, [loadRuntime]);

  const inventory = runtime?.inventory.payload ?? null;
  const layerState = runtime?.layers.payload ?? null;
  const preflight = runtime?.preflight.payload ?? null;
  const providers = inventory?.providers ?? [];
  const providersById = new Map(providers.map((provider) => [provider.id, provider]));
  const visibleProviders = providers.filter((provider) => matchesFilter(provider, providerFilter));
  const selectedLayer = layerState?.layers.find((layer) => layer.layer_id === selectedLayerId) ?? null;
  const missingGates = preflight?.gates.filter((gate) => preflight.missing_or_blocked_gates.includes(gate.id)) ?? [];
  const currentLiveProof = runtime !== null && [
    runtime.inventory.responseSource,
    runtime.layers.responseSource,
    runtime.preflight.responseSource,
  ].every((source) => source === "agent-api-boundary");
  const nonClaims = runtime
    ? Array.from(new Set([
      ...runtime.inventory.payload.non_claims,
      ...runtime.layers.payload.non_claims,
      ...runtime.preflight.payload.non_claims,
    ]))
    : [];

  return (
    <section
      className="technology-runtime-view"
      data-testid="technology-runtime-view"
      data-state={state}
      data-provider-count={inventory?.total_count ?? 0}
      data-layer-count={layerState?.total_layer_count ?? 0}
      data-visible-provider-count={visibleProviders.length}
      data-selected-layer-id={selectedLayer?.layer_id ?? selectedLayerId}
      data-provider-filter={providerFilter}
      data-preflight-missing-count={preflight?.missing_or_blocked_gates.length ?? 0}
      data-current-live-proof={String(currentLiveProof)}
      data-current-preflight-proof={String(currentLiveProof)}
      data-current-production-deploy-claim={String(
        currentLiveProof && preflight?.production_deploy_claim_allowed === true,
      )}
      data-refresh-count={refreshCount}
      aria-busy={state === "loading"}
    >
      <div className="technology-runtime-toolbar">
        <div>
          <span className="eyebrow">Runtime-Verträge</span>
          <h2>Cloud-Inventar, Schichten und Gates</h2>
          <p>Drei begrenzte Same-Origin-Quellen; inkonsistente oder untypisierte Antworten werden vollständig verworfen.</p>
        </div>
        <button
          type="button"
          className="btn btn-sm btn-primary"
          data-testid="technology-runtime-refresh"
          onClick={() => void loadRuntime()}
          disabled={state === "loading"}
        >
          {state === "loading" ? "Lädt…" : "↻ Aktualisieren"}
        </button>
        <span className="mono technology-runtime-refresh-status" data-testid="technology-runtime-refresh-status">
          validated_loads={refreshCount}
        </span>
      </div>

      {state === "loading" ? (
        <div className="technology-runtime-state" data-testid="technology-runtime-loading" role="status">
          Drei Runtime-Verträge werden parallel geprüft…
        </div>
      ) : null}

      {state === "error" ? (
        <div className="technology-runtime-state technology-runtime-error" data-testid="technology-runtime-error" role="alert">
          <div>
            <strong>Runtime-Ansicht blockiert.</strong>
            <p>{error}</p>
          </div>
          <button
            type="button"
            className="btn btn-sm btn-ghost"
            data-testid="technology-runtime-retry"
            onClick={() => void loadRuntime()}
          >
            Erneut prüfen
          </button>
        </div>
      ) : null}

      {runtime && inventory && layerState && preflight && selectedLayer ? (
        <div className="technology-runtime-content">
          <div className="technology-runtime-safety">
            <Badge tone="cyan">read_only=true</Badge>
            <Badge tone="green">provider_writes=false</Badge>
            <Badge tone="green">live_mcp_writes=false</Badge>
            <Badge tone="green">model_downloads=false</Badge>
            <Badge tone="amber">production_rollout_claimed=false</Badge>
          </div>

          <section className="technology-runtime-sources" aria-label="Vertragsquellen">
            {SOURCE_DEFINITIONS.map((source, index) => (
              <article
                className="technology-runtime-source"
                data-testid="technology-runtime-source"
                data-endpoint={source.endpoint}
                data-contract-version={source.contract}
                data-evidence-ref={source.evidence}
                data-response-source={sourceFor(runtime, index)}
                key={source.path}
              >
                <span>{source.label}</span>
                <code>{source.endpoint}</code>
                <small>{source.contract}</small>
                <small>{source.evidence}</small>
                <Badge tone="violet">{sourceFor(runtime, index)}</Badge>
              </article>
            ))}
          </section>
          {[
            runtime.inventory.responseSource,
            runtime.layers.responseSource,
            runtime.preflight.responseSource,
          ].some((source) => source !== "agent-api-boundary") ? (
            <div className="technology-runtime-projection-note" role="note">
              Project-State-/Frontend-Projektion zeigt committed oder projizierte Vertragsdaten und ist kein aktueller
              Live-Provider-, Hosted-, Deployment- oder Production-Beweis. Auch projizierte True-Werte erlauben keinen
              aktuellen Rollout-Claim.
            </div>
          ) : null}

          <section className="technology-runtime-panel">
            <div className="technology-runtime-section-head">
              <div>
                <span className="eyebrow">7-Schichten-Status</span>
                <h3>{layerState.total_layer_count} vertraglich zugeordnete Schichten</h3>
              </div>
              <Badge tone={currentLiveProof && layerState.status === "verified" ? "green" : "amber"}>
                {currentLiveProof ? layerState.status : "projection_not_current"}
              </Badge>
            </div>
            <div className="technology-layer-tabs" role="group" aria-label="Architekturschicht auswählen">
              {layerState.layers.map((layer) => (
                <button
                  type="button"
                  className={selectedLayer.layer_id === layer.layer_id ? "technology-layer-select active" : "technology-layer-select"}
                  data-testid="technology-layer-select"
                  data-layer-id={layer.layer_id}
                  aria-pressed={selectedLayer.layer_id === layer.layer_id}
                  onClick={() => setSelectedLayerId(layer.layer_id)}
                  key={layer.layer_id}
                >
                  <span>{layer.layer_id.replace("layer_", "L")}</span>
                  <small>{layer.label}</small>
                </button>
              ))}
            </div>
            <article
              className="technology-layer-detail"
              data-testid="technology-layer-detail"
              data-layer-id={selectedLayer.layer_id}
              data-layer-status={selectedLayer.status}
              data-required-provider-count={selectedLayer.required_providers.length}
              data-blocker-count={selectedLayer.blockers.length}
            >
              <div className="technology-layer-detail-head">
                <div>
                  <span className="eyebrow">{selectedLayer.layer_id}</span>
                  <h3>{selectedLayer.label}</h3>
                </div>
                <Badge tone={currentLiveProof && selectedLayer.status === "live_verified" ? "green" : currentLiveProof && selectedLayer.status === "partial_live_verified" ? "cyan" : "amber"}>
                  {currentLiveProof ? selectedLayer.status : "projection_not_current"}
                </Badge>
              </div>
              <div className="technology-layer-facts">
                <div>
                  <span>Erforderlich</span>
                  <strong>{selectedLayer.required_providers.length}</strong>
                  <small>{selectedLayer.required_providers.join(", ")}</small>
                </div>
                <div>
                  <span>Konfiguriert</span>
                  <strong>{selectedLayer.configured_providers.length}</strong>
                  <small>{selectedLayer.configured_providers.join(", ") || "keine"}</small>
                </div>
                <div>
                  <span>{currentLiveProof ? "Aktuell live verifiziert" : "Projizierter Live-Vertragswert"}</span>
                  <strong>
                    {currentLiveProof
                      ? selectedLayer.live_verified_providers.length
                      : `captured_contract_value=${selectedLayer.live_verified_providers.length}`}
                  </strong>
                  <small>
                    {currentLiveProof
                      ? selectedLayer.live_verified_providers.join(", ") || "keine"
                      : `kein aktueller Beweis · ${selectedLayer.live_verified_providers.join(", ") || "keine"}`}
                  </small>
                </div>
              </div>
              <div className="technology-layer-blockers">
                <strong>Blocker ({selectedLayer.blockers.length})</strong>
                {selectedLayer.blockers.length ? (
                  <ul>{selectedLayer.blockers.map((blocker) => <li className="mono" key={blocker}>{blocker}</li>)}</ul>
                ) : <p>Keine Vertragsblocker gemeldet.</p>}
                <code>next_safe_action={selectedLayer.next_safe_action}</code>
              </div>
            </article>
          </section>

          <section className="technology-runtime-panel" data-testid="technology-declared-runtime">
            <div className="technology-runtime-section-head">
              <div>
                <span className="eyebrow">Runtime-Technologien</span>
                <h3>Erforderliche Schichtzuordnung und Providerrollen</h3>
              </div>
              <Badge tone="violet">contract_declared</Badge>
            </div>
            <div className="technology-declared-grid">
              {inventory.seven_layer_mapping.map((mapping) => (
                <article data-layer-id={mapping.layer_id} key={mapping.layer_id}>
                  <span className="mono">{mapping.layer_id.replace("layer_", "L")}</span>
                  <h4>{mapping.label}</h4>
                  <ul>
                    {mapping.providers.map((providerId) => (
                      <li key={providerId}>
                        <strong>{providersById.get(providerId)?.label ?? providerId}</strong>
                        <small>{providersById.get(providerId)?.role ?? "Keine Providerrolle im Vertrag."}</small>
                      </li>
                    ))}
                  </ul>
                </article>
              ))}
            </div>
          </section>

          <section className="technology-runtime-panel">
            <div className="technology-runtime-section-head">
              <div>
                <span className="eyebrow">Provider-Inventar</span>
                <h3>{inventory.total_count} typisierte Provider-Oberflächen</h3>
              </div>
              <div className="technology-runtime-safety">
                <span className="mono technology-runtime-count">{visibleProviders.length} sichtbar</span>
                <Badge tone={currentLiveProof ? "green" : "amber"}>
                  {currentLiveProof ? "current_live_proof" : "projection_not_current"}
                </Badge>
              </div>
            </div>
            <div className="technology-provider-filters" role="group" aria-label="Provider filtern">
              {PROVIDER_FILTERS.map((filter) => {
                const count = providers.filter((provider) => matchesFilter(provider, filter)).length;
                return (
                  <button
                    type="button"
                    className={providerFilter === filter ? "technology-provider-filter active" : "technology-provider-filter"}
                    data-testid="technology-provider-filter"
                    data-filter={filter}
                    aria-pressed={providerFilter === filter}
                    onClick={() => setProviderFilter(filter)}
                    key={filter}
                  >
                    {filterLabel(filter)} <span>{count}</span>
                  </button>
                );
              })}
            </div>
            <div className="technology-provider-grid" data-testid="technology-provider-grid">
              {visibleProviders.map((provider) => (
                <article
                  className="technology-provider-card"
                  data-testid="technology-provider-card"
                  data-provider-id={provider.id}
                  data-provider-status={provider.status}
                  data-configured={String(provider.configured)}
                  data-live-verified={String(provider.live_verified)}
                  data-live-value-kind={currentLiveProof ? "current" : "captured_contract"}
                  data-historical-only={String(provider.historical_only === true)}
                  key={provider.id}
                >
                  <div className="technology-provider-card-head">
                    <h4>{provider.label}</h4>
                    <Badge tone={provider.historical_only ? "violet" : !currentLiveProof ? "amber" : provider.live_verified ? "green" : provider.configured ? "cyan" : "amber"}>
                      {provider.historical_only
                        ? "historical_only"
                        : currentLiveProof
                          ? provider.status
                          : `captured:${provider.status}`}
                    </Badge>
                  </div>
                  <p>{provider.role}</p>
                  {provider.historical_only ? <code className="mono">read_status={provider.status}</code> : null}
                  <div className="technology-provider-layers">
                    <small>Deklarierte Zugehörigkeit (inkl. optional)</small>
                    {provider.layers.length
                      ? provider.layers.map((layer) => <span className="mono" key={layer}>{layer.replace("layer_", "L")}</span>)
                      : <span className="mono">keine aktive Schicht</span>}
                  </div>
                  <dl>
                    <div>
                      <dt>{currentLiveProof ? "configured" : "captured_configured"}</dt>
                      <dd>{String(provider.configured)}</dd>
                    </div>
                    <div>
                      <dt>{currentLiveProof ? "live_verified_current" : "captured_live_verified"}</dt>
                      <dd>{currentLiveProof ? String(provider.live_verified) : `${String(provider.live_verified)} · kein aktueller Beweis`}</dd>
                    </div>
                  </dl>
                </article>
              ))}
              {visibleProviders.length === 0 ? (
                <p className="technology-provider-empty">Kein Provider erfüllt diesen Filter.</p>
              ) : null}
            </div>
          </section>

          <section className="technology-runtime-panel" data-testid="technology-declared-toolstack">
            <div className="technology-runtime-section-head">
              <div>
                <span className="eyebrow">Toolstack</span>
                <h3>Repo- und Vertragsreferenzen der Preflight-Gates</h3>
              </div>
              <Badge tone="violet">repo_declared</Badge>
            </div>
            <div className="technology-toolstack-grid">
              {preflight.gates.map((gate) => (
                <article data-gate-id={gate.id} key={gate.id}>
                  <h4>{gate.label}</h4>
                  <code>{gate.required_artifact}</code>
                  <small className="mono">verifier={gate.verifier}</small>
                  <Badge tone={currentLiveProof && gate.verified ? "green" : "amber"}>
                    {currentLiveProof
                      ? gate.verified ? "evidence verified" : "evidence missing"
                      : gate.verified ? "captured:evidence_verified" : "captured:evidence_missing"}
                  </Badge>
                </article>
              ))}
            </div>
          </section>

          <section className="technology-runtime-panel technology-preflight">
            <div className="technology-runtime-section-head">
              <div>
                <span className="eyebrow">Deployment-Preflight</span>
                <h3>
                  {currentLiveProof
                    ? `${preflight.missing_or_blocked_gates.length} fehlende oder blockierte Gates`
                    : `${preflight.missing_or_blocked_gates.length} projizierte fehlende Gate-Werte`}
                </h3>
              </div>
              <Badge tone={currentLiveProof ? preflight.preflight_ready ? "green" : "red" : "amber"}>
                {currentLiveProof ? preflight.status : "projection_not_current"}
              </Badge>
            </div>
            <div className="technology-preflight-facts">
              <span>
                preflight_ready=
                {currentLiveProof
                  ? String(preflight.preflight_ready)
                  : `captured_contract_value=${String(preflight.preflight_ready)} · kein aktueller Beweis`}
              </span>
              <span>
                cloud_deploy_claim_allowed=
                {currentLiveProof
                  ? String(preflight.cloud_deploy_claim_allowed)
                  : `captured_contract_value=${String(preflight.cloud_deploy_claim_allowed)} · kein aktueller Beweis`}
              </span>
              <span>
                production_deploy_claim_allowed=
                {currentLiveProof
                  ? String(preflight.production_deploy_claim_allowed)
                  : `captured_contract_value=${String(preflight.production_deploy_claim_allowed)} · kein aktueller Beweis`}
              </span>
              <span>
                localhost_role=
                {currentLiveProof
                  ? preflight.localhost_role
                  : `captured_contract_value=${preflight.localhost_role} · kein aktueller Hosted-Beweis`}
              </span>
            </div>
            <div className="technology-preflight-gates">
              {missingGates.map((gate) => (
                <article
                  className="technology-preflight-missing-gate"
                  data-testid="technology-preflight-missing-gate"
                  data-gate-id={gate.id}
                  key={gate.id}
                >
                  <div>
                    <h4>{gate.label}</h4>
                    <code>{gate.id}</code>
                  </div>
                  <Badge tone="red">{currentLiveProof ? "verified=false" : "captured:verified=false"}</Badge>
                  <p>{gate.required_evidence_artifact}</p>
                  <small className="mono">next={gate.next_action}</small>
                </article>
              ))}
              {missingGates.length === 0 ? (
                <p>
                  {currentLiveProof
                    ? "Keine fehlenden Gates gemeldet."
                    : "captured_contract_value=keine fehlenden Gates · kein aktueller Hosted-, Deployment- oder Production-Beweis"}
                </p>
              ) : null}
            </div>
          </section>

          <section className="technology-runtime-nonclaims">
            <div className="technology-runtime-section-head">
              <div>
                <span className="eyebrow">Nichtbehauptungen</span>
                <h3>Explizite Vertragsgrenzen</h3>
              </div>
            </div>
            <ul>{nonClaims.map((claim) => <li key={claim}>{claim}</li>)}</ul>
          </section>
        </div>
      ) : null}
    </section>
  );
}
