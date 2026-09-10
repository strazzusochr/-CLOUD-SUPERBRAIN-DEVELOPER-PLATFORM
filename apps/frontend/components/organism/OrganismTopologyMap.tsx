"use client";

import { useEffect, useState } from "react";
import { Badge } from "../ui";

const TOPOLOGY_ENDPOINT = "/api/v1/organism/topology";
const TOPOLOGY_CONTRACT_VERSION = "organism-topology-v1";
const TOPOLOGY_EVIDENCE_REF = "organism_topology_visible";
const DEFAULT_NODE_ID = "page:organism-map";
const ALL_KINDS = "all";
const MAX_TOPOLOGY_NODES = 512;
const MAX_TOPOLOGY_EDGES = 4_096;
const MAX_NON_CLAIMS = 32;
const MAX_TOPOLOGY_RESPONSE_BYTES = 524_288;
const MAX_NODE_LABEL_LENGTH = 256;

type TopologyNode = {
  id: string;
  kind: string;
  writes: false;
  secret_output: false;
  label?: string;
  name?: string;
};

type TopologyEdge = {
  from: string;
  to: string;
  kind: string;
};

type TopologyPayload = {
  contract_version: typeof TOPOLOGY_CONTRACT_VERSION;
  evidence_ref: typeof TOPOLOGY_EVIDENCE_REF;
  endpoint: typeof TOPOLOGY_ENDPOINT;
  source_kind: "contract";
  live: false;
  nodes: TopologyNode[];
  edges: TopologyEdge[];
  non_claims: string[];
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

function isTopologyNode(value: unknown): value is TopologyNode {
  if (!isRecord(value)) return false;
  return isNonEmptyString(value.id)
    && value.id.length <= 256
    && isNonEmptyString(value.kind)
    && value.kind.length <= 64
    && value.writes === false
    && value.secret_output === false
    && (value.label === undefined || (isNonEmptyString(value.label) && value.label.length <= MAX_NODE_LABEL_LENGTH))
    && (value.name === undefined || (isNonEmptyString(value.name) && value.name.length <= MAX_NODE_LABEL_LENGTH));
}

function isTopologyEdge(value: unknown): value is TopologyEdge {
  if (!isRecord(value)) return false;
  return isNonEmptyString(value.from)
    && value.from.length <= 256
    && isNonEmptyString(value.to)
    && value.to.length <= 256
    && isNonEmptyString(value.kind)
    && value.kind.length <= 128;
}

function isTopologyPayload(value: unknown): value is TopologyPayload {
  if (!isRecord(value)) return false;
  if (
    value.contract_version !== TOPOLOGY_CONTRACT_VERSION
    || value.evidence_ref !== TOPOLOGY_EVIDENCE_REF
    || value.endpoint !== TOPOLOGY_ENDPOINT
    || value.source_kind !== "contract"
    || value.live !== false
    || !Array.isArray(value.nodes)
    || value.nodes.length === 0
    || value.nodes.length > MAX_TOPOLOGY_NODES
    || !value.nodes.every(isTopologyNode)
    || !Array.isArray(value.edges)
    || value.edges.length === 0
    || value.edges.length > MAX_TOPOLOGY_EDGES
    || !value.edges.every(isTopologyEdge)
    || !Array.isArray(value.non_claims)
    || value.non_claims.length === 0
    || value.non_claims.length > MAX_NON_CLAIMS
    || !value.non_claims.every((claim) => isNonEmptyString(claim) && claim.length <= 500)
  ) {
    return false;
  }

  const nodeIds = new Set(value.nodes.map((node) => node.id));
  return nodeIds.size === value.nodes.length
    && value.edges.every((edge) => nodeIds.has(edge.from) && nodeIds.has(edge.to));
}

function normalizeTopologyPayload(value: unknown): TopologyPayload {
  if (!isTopologyPayload(value)) {
    throw new Error("Ungültiger Topologievertrag; Daten werden nicht angezeigt.");
  }

  return {
    contract_version: TOPOLOGY_CONTRACT_VERSION,
    evidence_ref: TOPOLOGY_EVIDENCE_REF,
    endpoint: TOPOLOGY_ENDPOINT,
    source_kind: "contract",
    live: false,
    nodes: value.nodes.map((node) => {
      const normalized: TopologyNode = {
        id: node.id,
        kind: node.kind,
        writes: false,
        secret_output: false,
      };
      if (node.label !== undefined) normalized.label = node.label;
      if (node.name !== undefined) normalized.name = node.name;
      return normalized;
    }),
    edges: value.edges.map((edge) => ({
      from: edge.from,
      to: edge.to,
      kind: edge.kind,
    })),
    non_claims: [...value.non_claims],
  };
}

async function readBoundedJson(response: Response): Promise<unknown> {
  const contentType = response.headers.get("content-type")?.split(";", 1)[0]?.trim().toLowerCase();
  if (!contentType || (contentType !== "application/json" && !contentType.endsWith("+json"))) {
    throw new Error("Topologieantwort ist kein JSON.");
  }

  const declaredLength = response.headers.get("content-length");
  if (declaredLength !== null) {
    const normalizedLength = declaredLength.trim();
    if (!/^\d+$/.test(normalizedLength) || Number(normalizedLength) > MAX_TOPOLOGY_RESPONSE_BYTES) {
      throw new Error("Topologieantwort überschreitet das Größenlimit.");
    }
  }

  const reader = response.body?.getReader();
  if (!reader) {
    throw new Error("Topologieantwort enthält keinen lesbaren Inhalt.");
  }

  const decoder = new TextDecoder();
  let byteCount = 0;
  let text = "";
  try {
    while (true) {
      const chunk = await reader.read();
      if (chunk.done) break;
      byteCount += chunk.value.byteLength;
      if (byteCount > MAX_TOPOLOGY_RESPONSE_BYTES) {
        await reader.cancel("topology response byte limit exceeded");
        throw new Error("Topologieantwort überschreitet das Größenlimit.");
      }
      text += decoder.decode(chunk.value, { stream: true });
    }
    text += decoder.decode();
  } finally {
    reader.releaseLock();
  }

  try {
    return JSON.parse(text) as unknown;
  } catch {
    throw new Error("Topologieantwort enthält ungültiges JSON.");
  }
}

let topologyRequest: Promise<TopologyPayload> | null = null;

function requestTopology(): Promise<TopologyPayload> {
  if (topologyRequest) return topologyRequest;
  const request = (async () => {
    const response = await fetch(TOPOLOGY_ENDPOINT, {
      method: "GET",
      cache: "no-store",
      headers: { accept: "application/json" },
    });
    if (!response.ok) {
      throw new Error(`Topologie nicht verfügbar (${response.status}).`);
    }
    const body = await readBoundedJson(response);
    return normalizeTopologyPayload(body);
  })();
  topologyRequest = request;
  void request.catch(() => {
    if (topologyRequest === request) topologyRequest = null;
  });
  return request;
}

function nodeLabel(node: TopologyNode): string {
  if (isNonEmptyString(node.label)) return node.label;
  if (isNonEmptyString(node.name)) return node.name;
  return node.id;
}

function kindLabel(kind: string): string {
  return kind.replaceAll("_", " ");
}

export default function OrganismTopologyMap() {
  const [topology, setTopology] = useState<TopologyPayload | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [activeKind, setActiveKind] = useState(ALL_KINDS);
  const [selectedNodeId, setSelectedNodeId] = useState(DEFAULT_NODE_ID);

  useEffect(() => {
    let active = true;
    void requestTopology().then(
      (payload) => {
        if (active) setTopology(payload);
      },
      (reason: unknown) => {
        if (active) {
          setError(reason instanceof Error ? reason.message : "Topologie konnte nicht geladen werden.");
        }
      },
    );
    return () => {
      active = false;
    };
  }, []);

  const loading = topology === null && error === null;
  const kinds = topology
    ? Array.from(new Set(topology.nodes.map((node) => node.kind))).sort((a, b) => a.localeCompare(b))
    : [];
  const visibleNodes = topology
    ? topology.nodes.filter((node) => activeKind === ALL_KINDS || node.kind === activeKind)
    : [];
  const selectedNode = topology
    ? topology.nodes.find((node) => node.id === selectedNodeId) ?? topology.nodes[0] ?? null
    : null;
  const incoming = topology && selectedNode
    ? topology.edges.filter((edge) => edge.to === selectedNode.id)
    : [];
  const outgoing = topology && selectedNode
    ? topology.edges.filter((edge) => edge.from === selectedNode.id)
    : [];
  const nodesById = new Map(topology?.nodes.map((node) => [node.id, node]) ?? []);

  function selectKind(kind: string) {
    setActiveKind(kind);
    if (!topology || kind === ALL_KINDS) return;
    const firstMatch = topology.nodes.find((node) => node.kind === kind);
    if (firstMatch) setSelectedNodeId(firstMatch.id);
  }

  function selectAdjacentNode(nodeId: string) {
    setActiveKind(ALL_KINDS);
    setSelectedNodeId(nodeId);
  }

  function retryTopology() {
    setError(null);
    setTopology(null);
    void requestTopology().then(
      (payload) => setTopology(payload),
      (reason: unknown) => {
        setError(reason instanceof Error ? reason.message : "Topologie konnte nicht geladen werden.");
      },
    );
  }

  return (
    <section
      className="panel organism-topology-map"
      data-testid="organism-topology-map"
      data-contract-version={topology?.contract_version ?? "pending"}
      data-evidence-ref={topology?.evidence_ref ?? "pending"}
      data-endpoint={topology?.endpoint ?? TOPOLOGY_ENDPOINT}
      data-source-kind={topology?.source_kind ?? "pending"}
      data-live={topology ? String(topology.live) : "pending"}
      data-read-only={topology ? "true" : "pending"}
      data-node-count={topology?.nodes.length ?? 0}
      data-edge-count={topology?.edges.length ?? 0}
      data-visible-node-count={visibleNodes.length}
      data-selected-node-id={selectedNode?.id ?? ""}
      aria-busy={loading}
    >
      <div className="panel-head topology-map-head">
        <div>
          <span className="panel-title">Vertragsgebundene Topologie</span>
          <p>Knoten, Kanten und Nachbarschaften aus einem statischen, nur lesenden Vertrag.</p>
        </div>
        <div className="topology-map-badges" data-testid="organism-topology-evidence">
          <Badge tone="cyan">{TOPOLOGY_CONTRACT_VERSION}</Badge>
          {topology ? (
            <>
              <Badge tone="green">read_only=true</Badge>
              <Badge tone="green">live=false</Badge>
            </>
          ) : (
            <Badge tone={error ? "red" : "amber"}>{error ? "contract=blocked" : "contract=pending"}</Badge>
          )}
        </div>
      </div>

      {loading ? (
        <div className="topology-map-state" data-testid="organism-topology-loading" role="status">
          Topologie wird geladen…
        </div>
      ) : null}

      {error ? (
        <div className="topology-map-state topology-map-error" data-testid="organism-topology-error" role="alert">
          <strong>Topologie blockiert.</strong>
          <span>{error}</span>
          <button
            type="button"
            className="btn btn-ghost btn-sm"
            data-testid="organism-topology-retry"
            onClick={retryTopology}
          >
            Erneut laden
          </button>
        </div>
      ) : null}

      {topology && selectedNode ? (
        <div className="topology-map-body">
          <div className="topology-map-contract mono">
            <span>evidence={topology.evidence_ref}</span>
            <span>endpoint={topology.endpoint}</span>
            <span>source_kind={topology.source_kind}</span>
            <span>nodes={topology.nodes.length}</span>
            <span>edges={topology.edges.length}</span>
          </div>

          <div className="topology-map-filters" role="group" aria-label="Knotenart filtern">
            <button
              type="button"
              className={activeKind === ALL_KINDS ? "topology-kind active" : "topology-kind"}
              data-testid="organism-topology-kind-filter"
              data-node-kind={ALL_KINDS}
              aria-pressed={activeKind === ALL_KINDS}
              onClick={() => selectKind(ALL_KINDS)}
            >
              Alle <span>{topology.nodes.length}</span>
            </button>
            {kinds.map((kind) => {
              const count = topology.nodes.filter((node) => node.kind === kind).length;
              return (
                <button
                  type="button"
                  className={activeKind === kind ? "topology-kind active" : "topology-kind"}
                  data-testid="organism-topology-kind-filter"
                  data-node-kind={kind}
                  aria-pressed={activeKind === kind}
                  onClick={() => selectKind(kind)}
                  key={kind}
                >
                  {kindLabel(kind)} <span>{count}</span>
                </button>
              );
            })}
          </div>

          <div className="topology-map-grid">
            <div className="topology-node-column">
              <div className="topology-section-title">
                <span>Knoten</span>
                <span className="mono">{visibleNodes.length}/{topology.nodes.length}</span>
              </div>
              <div className="topology-node-list" data-testid="organism-topology-node-list">
                {visibleNodes.map((node) => (
                  <button
                    type="button"
                    className={selectedNode.id === node.id ? "topology-node active" : "topology-node"}
                    data-testid="organism-topology-node"
                    data-node-id={node.id}
                    data-node-kind={node.kind}
                    aria-pressed={selectedNode.id === node.id}
                    onClick={() => setSelectedNodeId(node.id)}
                    key={node.id}
                  >
                    <span>{nodeLabel(node)}</span>
                    <small className="mono">{node.id}</small>
                    <em>{kindLabel(node.kind)}</em>
                  </button>
                ))}
              </div>
            </div>

            <aside
              className="topology-adjacency"
              data-testid="organism-topology-adjacency"
              data-incoming-count={incoming.length}
              data-outgoing-count={outgoing.length}
            >
              <div className="topology-selected-node">
                <span className="eyebrow">Ausgewählter Knoten</span>
                <h2>{nodeLabel(selectedNode)}</h2>
                <code>{selectedNode.id}</code>
                <Badge tone="violet">{kindLabel(selectedNode.kind)}</Badge>
              </div>

              <div className="topology-adjacency-grid">
                <AdjacencyList
                  title="Eingehend"
                  direction="incoming"
                  emptyText="Keine eingehenden Kanten."
                  edges={incoming}
                  neighborId={(edge) => edge.from}
                  nodesById={nodesById}
                  onSelect={selectAdjacentNode}
                />
                <AdjacencyList
                  title="Ausgehend"
                  direction="outgoing"
                  emptyText="Keine ausgehenden Kanten."
                  edges={outgoing}
                  neighborId={(edge) => edge.to}
                  nodesById={nodesById}
                  onSelect={selectAdjacentNode}
                />
              </div>
            </aside>
          </div>

          <div className="topology-nonclaims">
            <strong>Nicht behauptet</strong>
            <ul>
              {topology.non_claims.map((claim) => <li key={claim}>{claim}</li>)}
            </ul>
          </div>
        </div>
      ) : null}
    </section>
  );
}

function AdjacencyList({
  title,
  direction,
  emptyText,
  edges,
  neighborId,
  nodesById,
  onSelect,
}: {
  title: string;
  direction: "incoming" | "outgoing";
  emptyText: string;
  edges: TopologyEdge[];
  neighborId: (edge: TopologyEdge) => string;
  nodesById: Map<string, TopologyNode>;
  onSelect: (nodeId: string) => void;
}) {
  return (
    <section className="topology-adjacency-list">
      <div className="topology-section-title">
        <span>{title}</span>
        <span className="mono">{edges.length}</span>
      </div>
      {edges.length === 0 ? <p>{emptyText}</p> : (
        <ul>
          {edges.map((edge, index) => {
            const adjacentId = neighborId(edge);
            const adjacentNode = nodesById.get(adjacentId);
            return (
              <li key={`${edge.from}:${edge.to}:${edge.kind}:${index}`}>
                <button
                  type="button"
                  data-testid="organism-topology-adjacent-node"
                  data-node-id={adjacentId}
                  data-edge-kind={edge.kind}
                  data-direction={direction}
                  onClick={() => onSelect(adjacentId)}
                >
                  <span>{adjacentNode ? nodeLabel(adjacentNode) : adjacentId}</span>
                  <small className="mono">{edge.kind}</small>
                </button>
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}
