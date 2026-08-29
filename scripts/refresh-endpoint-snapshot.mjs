import { createHash } from "node:crypto";
import {
  closeSync,
  fsyncSync,
  openSync,
  readFileSync,
  renameSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = fileURLToPath(new URL("../", import.meta.url));
const snapshotPath = fileURLToPath(
  new URL("../apps/frontend/lib/endpoint-snapshot.json", import.meta.url),
);

export const SNAPSHOT_METADATA_KEY = "__snapshot_metadata";
export const SNAPSHOT_METADATA_CONTRACT = "endpoint-snapshot-metadata-v1";
export const GATE_RELEVANT_PATHS = Object.freeze(
  [
    "/api/v1/clouds",
    "/api/v1/clouds/deployment-preflight",
    "/api/v1/clouds/go-live-readiness",
    "/api/v1/clouds/layers",
    "/api/v1/external-gates",
    "/api/v1/project/progress",
    "/api/v1/project/progress/completion",
  ].sort(),
);

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

export function canonicalTextSha256(value) {
  const text = Buffer.isBuffer(value) ? value.toString("utf8") : String(value);
  return sha256(Buffer.from(text.replace(/\r\n?/g, "\n"), "utf8"));
}

export function endpointPathsFromSnapshot(snapshot) {
  if (!snapshot || typeof snapshot !== "object" || Array.isArray(snapshot)) {
    throw new Error("Endpoint snapshot must be a JSON object.");
  }
  const unexpected = Object.keys(snapshot).filter(
    (key) => key !== SNAPSHOT_METADATA_KEY && !key.startsWith("/api/v1/"),
  );
  if (unexpected.length > 0) {
    throw new Error(`Unexpected endpoint snapshot key: ${unexpected.sort().join(",")}`);
  }
  return Object.keys(snapshot)
    .filter((key) => key.startsWith("/api/v1/"))
    .sort();
}

function readSourceBindings(root) {
  const pointerPath = join(root, "docs", "release-artifacts", "current-release-candidate.json");
  const manifestPath = join(root, "docs", "project-progress.manifest.json");
  const summaryPath = join(root, "docs", "runtime-state", "external-gate-summary.json");
  const pointerBytes = readFileSync(pointerPath);
  const pointer = JSON.parse(pointerBytes.toString("utf8"));
  const activeReleaseId = String(pointer?.active_release_id ?? "");
  if (!/^[a-z0-9][a-z0-9._-]+$/.test(activeReleaseId)) {
    throw new Error("Current release candidate has an invalid active_release_id.");
  }
  if (pointer?.production_rollout_claimed !== false) {
    throw new Error("Endpoint snapshot refresh requires production_rollout_claimed=false.");
  }

  const candidatePath = join(root, "docs", "release-artifacts", `${activeReleaseId}.md`);
  const candidateBytes = readFileSync(candidatePath);
  const candidateText = candidateBytes.toString("utf8");
  const releaseIdMatch = candidateText.match(/^release_id:\s*`([^`]+)`\s*$/m);
  const sourceMatch = candidateText.match(/^source_commit_sha:\s*`([0-9a-f]{40})`\s*$/m);
  if (releaseIdMatch?.[1] !== activeReleaseId || !sourceMatch) {
    throw new Error("Active release candidate artifact is not source-bound to its pointer.");
  }
  if (
    !/^[0-9a-f]{40}$/.test(String(pointer?.source_commit_sha ?? "")) ||
    pointer.source_commit_sha !== sourceMatch[1]
  ) {
    throw new Error("Current release candidate pointer source_commit_sha does not match its artifact.");
  }

  return {
    activeReleaseId,
    sourceCommitSha: pointer.source_commit_sha,
    currentReleaseCandidateSha256: canonicalTextSha256(pointerBytes),
    releaseCandidateArtifactSha256: canonicalTextSha256(candidateBytes),
    projectProgressManifestSha256: canonicalTextSha256(readFileSync(manifestPath)),
    externalGateSummarySha256: canonicalTextSha256(readFileSync(summaryPath)),
  };
}

export function buildSnapshotMetadata({
  allEndpointPaths,
  selectedPaths,
  bindings,
  runtimeSourceAttestation = null,
  generatedAtUtc = new Date().toISOString(),
}) {
  const allPaths = [...new Set(allEndpointPaths)].sort();
  const refreshedPaths = [...new Set(selectedPaths)].sort();
  const allPathSet = new Set(allPaths);
  if (refreshedPaths.some((path) => !allPathSet.has(path))) {
    throw new Error("Snapshot metadata received an unknown refreshed endpoint path.");
  }
  const missingGatePaths = GATE_RELEVANT_PATHS.filter((path) => !allPathSet.has(path));
  if (missingGatePaths.length > 0) {
    throw new Error(`Endpoint snapshot is missing gate-relevant paths: ${missingGatePaths.join(",")}`);
  }

  const selectedSet = new Set(refreshedPaths);
  const selectedGateCount = GATE_RELEVANT_PATHS.filter((path) => selectedSet.has(path)).length;
  const gateRefreshAtomic =
    selectedGateCount === 0 || selectedGateCount === GATE_RELEVANT_PATHS.length;
  const fullRefresh = refreshedPaths.length === allPaths.length;
  const refreshScope = fullRefresh
    ? "full"
    : selectedGateCount === GATE_RELEVANT_PATHS.length
      ? "gate_atomic"
      : "partial";
  const runtimeSourceCommitSha =
    runtimeSourceAttestation?.verified === true &&
    /^[0-9a-f]{40}$/.test(String(runtimeSourceAttestation?.sourceCommitSha ?? ""))
      ? String(runtimeSourceAttestation.sourceCommitSha)
      : null;
  const runtimeSourceAttested = runtimeSourceCommitSha !== null;
  const candidateSourceParity =
    runtimeSourceAttested && runtimeSourceCommitSha === bindings.sourceCommitSha;
  const current = fullRefresh && candidateSourceParity;
  const currentReason = !fullRefresh
    ? gateRefreshAtomic
      ? "partial_refresh_mixed_epoch"
      : "partial_gate_refresh_non_atomic"
    : !runtimeSourceAttested
      ? "runtime_source_unattested_prequalification"
      : !candidateSourceParity
        ? "runtime_source_candidate_mismatch"
        : "all_endpoint_payloads_refreshed_with_candidate_source_parity";

  return {
    contract_version: SNAPSHOT_METADATA_CONTRACT,
    generated_at_utc: generatedAtUtc,
    refresh_scope: refreshScope,
    payload_epoch_complete: fullRefresh,
    current,
    current_reason: currentReason,
    qualification_state: current ? "candidate_source_attested" : "prequalification",
    source_scope: "DEV-ONLY",
    target_scope: "localhost_only",
    endpoint_count: allPaths.length,
    refreshed_endpoint_count: refreshedPaths.length,
    refreshed_paths: refreshedPaths,
    gate_relevant_paths: [...GATE_RELEVANT_PATHS],
    gate_refresh_atomic: gateRefreshAtomic,
    active_release_id: bindings.activeReleaseId,
    candidate_source_commit_sha: bindings.sourceCommitSha,
    runtime_source_commit_sha: runtimeSourceCommitSha,
    runtime_source_attested: runtimeSourceAttested,
    candidate_source_parity: candidateSourceParity,
    current_release_candidate_sha256: bindings.currentReleaseCandidateSha256,
    release_candidate_artifact_sha256: bindings.releaseCandidateArtifactSha256,
    project_progress_manifest_sha256: bindings.projectProgressManifestSha256,
    external_gate_summary_sha256: bindings.externalGateSummarySha256,
  };
}

function sanitizePayload(path, payload) {
  if (path !== "/api/v1/clouds" || !payload || typeof payload !== "object") {
    return payload;
  }
  const providers = Array.isArray(payload.providers)
    ? payload.providers.map((provider) => {
        const historicalOnly = provider?.historical_only === true;
        const sanitized = {
          ...provider,
          configured: false,
          live_verified: false,
          status: historicalOnly ? "historical_only" : "action_required",
          env_status: Array.isArray(provider?.env_status)
            ? provider.env_status.map((item) => ({ ...item, configured: false }))
            : [],
          resources: [],
          monthly_cost_cents: null,
          last_checked_at: null,
        };
        if ("provider_read_live_verified" in sanitized) {
          sanitized.provider_read_live_verified = false;
        }
        if ("hosted_runtime_claim_allowed" in sanitized) {
          sanitized.hosted_runtime_claim_allowed = false;
        }
        delete sanitized.error;
        return sanitized;
      })
    : [];
  return {
    ...payload,
    status: "action_required",
    configured_count: 0,
    live_verified_count: 0,
    providers,
  };
}

const secretPatterns = [
  { id: "provider_key", pattern: /\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}\b/i },
  { id: "github_token", pattern: /\bgh[oprsu]_[A-Za-z0-9_]{20,}\b/i },
  {
    id: "private_key",
    pattern: /-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----/i,
  },
];

function findPatternPath(value, pattern, path = "$") {
  if (typeof value === "string") {
    pattern.lastIndex = 0;
    return pattern.test(value) ? path : null;
  }
  if (Array.isArray(value)) {
    for (let index = 0; index < value.length; index += 1) {
      const found = findPatternPath(value[index], pattern, `${path}[${index}]`);
      if (found) return found;
    }
    return null;
  }
  if (value && typeof value === "object") {
    for (const [key, nested] of Object.entries(value)) {
      pattern.lastIndex = 0;
      if (pattern.test(key)) return `${path}.${key}`;
      const found = findPatternPath(nested, pattern, `${path}.${key}`);
      if (found) return found;
    }
  }
  return null;
}

function writeSnapshotAtomic(targetPath, serialized) {
  const temporaryPath = `${targetPath}.tmp-${process.pid}-${Date.now()}`;
  let descriptor;
  try {
    descriptor = openSync(temporaryPath, "wx");
    writeFileSync(descriptor, serialized, "utf8");
    fsyncSync(descriptor);
    closeSync(descriptor);
    descriptor = undefined;
    renameSync(temporaryPath, targetPath);
  } catch (error) {
    if (descriptor !== undefined) closeSync(descriptor);
    try {
      unlinkSync(temporaryPath);
    } catch {
      // The temp file may already have been renamed or may never have been created.
    }
    throw error;
  }
}

async function main(args = process.argv.slice(2)) {
  const baseUrlArg = args.find((value) => value.startsWith("--base-url="));
  const pathArgs = args
    .filter((value) => value.startsWith("--path="))
    .map((value) => value.slice("--path=".length));
  const baseUrl = (baseUrlArg?.slice("--base-url=".length) || "http://localhost:8081").replace(
    /\/$/,
    "",
  );
  const parsedBase = new URL(baseUrl);

  if (!["localhost", "127.0.0.1", "::1"].includes(parsedBase.hostname)) {
    throw new Error("Endpoint snapshot refresh is DEV-ONLY and accepts localhost targets only.");
  }

  const current = JSON.parse(readFileSync(snapshotPath, "utf8"));
  const paths = endpointPathsFromSnapshot(current);
  if (paths.length < 30) {
    throw new Error(`Unexpected endpoint snapshot key set: count=${paths.length}`);
  }
  const selectedPaths = pathArgs.length > 0 ? [...new Set(pathArgs)].sort() : paths;
  if (selectedPaths.some((path) => !paths.includes(path))) {
    throw new Error("Endpoint snapshot refresh received an unknown --path target.");
  }

  const refreshed = Object.fromEntries(paths.map((path) => [path, current[path]]));
  for (const path of selectedPaths) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 60_000);
    let response;
    try {
      response = await fetch(`${baseUrl}${path}`, {
        method: "GET",
        headers: { accept: "application/json" },
        signal: controller.signal,
      });
    } finally {
      clearTimeout(timeout);
    }
    if (!response.ok) {
      throw new Error(`Snapshot refresh failed: ${path} returned HTTP ${response.status}`);
    }
    const contentType = response.headers.get("content-type") || "";
    if (!contentType.toLowerCase().includes("application/json")) {
      throw new Error(`Snapshot refresh failed: ${path} returned ${contentType || "no content-type"}`);
    }
    refreshed[path] = sanitizePayload(path, await response.json());
  }

  refreshed[SNAPSHOT_METADATA_KEY] = buildSnapshotMetadata({
    allEndpointPaths: paths,
    selectedPaths,
    bindings: readSourceBindings(repoRoot),
  });

  for (const [path, payload] of Object.entries(refreshed)) {
    for (const { id, pattern } of secretPatterns) {
      const jsonPath = findPatternPath(payload, pattern);
      if (jsonPath) {
        throw new Error(
          `Snapshot refresh blocked secret-like pattern=${id} endpoint=${path} json_path=${jsonPath}.`,
        );
      }
    }
  }

  const serialized = `${JSON.stringify(refreshed)}\n`;
  writeSnapshotAtomic(snapshotPath, serialized);
  const metadata = refreshed[SNAPSHOT_METADATA_KEY];
  console.log(
    `[endpoint-snapshot] refreshed=${selectedPaths.length}/${paths.length} scope=${metadata.refresh_scope} current=${metadata.current} gate_atomic=${metadata.gate_refresh_atomic} source=DEV-ONLY path=${snapshotPath}`,
  );
}

const invokedPath = process.argv[1] ? resolve(process.argv[1]).toLowerCase() : "";
if (invokedPath === resolve(fileURLToPath(import.meta.url)).toLowerCase()) {
  await main();
}
