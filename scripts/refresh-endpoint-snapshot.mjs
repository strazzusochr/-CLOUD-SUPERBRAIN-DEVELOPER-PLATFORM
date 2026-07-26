import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const repoRoot = fileURLToPath(new URL("../", import.meta.url));
const snapshotPath = fileURLToPath(
  new URL("../apps/frontend/lib/endpoint-snapshot.json", import.meta.url),
);
const baseUrlArg = process.argv.find((value) => value.startsWith("--base-url="));
const baseUrl = (baseUrlArg?.slice("--base-url=".length) || "http://localhost:8081").replace(
  /\/$/,
  "",
);
const parsedBase = new URL(baseUrl);

if (!["localhost", "127.0.0.1", "::1"].includes(parsedBase.hostname)) {
  throw new Error("Endpoint snapshot refresh is DEV-ONLY and accepts localhost targets only.");
}

const current = JSON.parse(readFileSync(snapshotPath, "utf8"));
const paths = Object.keys(current);
if (paths.length < 30 || paths.some((path) => !path.startsWith("/api/v1/"))) {
  throw new Error(`Unexpected endpoint snapshot key set: count=${paths.length}`);
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

const refreshed = {};
for (const path of paths) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15_000);
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
writeFileSync(snapshotPath, serialized, "utf8");
console.log(`[endpoint-snapshot] refreshed=${paths.length} source=DEV-ONLY path=${snapshotPath}`);
