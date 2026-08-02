import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = process.cwd();

function read(relativePath) {
  return readFileSync(resolve(root, relativePath), "utf8");
}

function readJson(relativePath) {
  return JSON.parse(read(relativePath));
}

function assert(condition, message) {
  if (!condition) throw new Error(`[five-axis-audit] ${message}`);
}

function trackedFiles(...pathspecs) {
  return execFileSync("git", ["ls-files", "--", ...pathspecs], {
    cwd: root,
    encoding: "utf8",
  })
    .split(/\r?\n/)
    .filter(Boolean);
}

function routePattern(route) {
  const parts = route.split(/(\{[^}]+\})/g).filter(Boolean);
  const escaped = parts.map((part) => {
    if (part.startsWith("{") && part.endsWith("}")) return "[^/]+";
    return part.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  });
  return new RegExp(`^${escaped.join("")}$`);
}

const navSource = read("apps/frontend/lib/nav.tsx");
const workspaceBlock = navSource.match(
  /export const WORKSPACE_PAGES:[^=]+?=\s*\[([\s\S]*?)\n\];/,
);
assert(workspaceBlock, "WORKSPACE_PAGES block is missing");

const workspacePages = workspaceBlock[1]
  .split(/\r?\n/)
  .map((line) => line.match(/\{ id: "([^"]+)", no: (\d+), label: "([^"]+)", route: "([^"]+)",[^}]+layer: "([^"]+)" \}/))
  .filter(Boolean)
  .map((match) => ({
    id: match[1],
    no: Number(match[2]),
    label: match[3],
    route: match[4],
    layer: match[5],
  }));

assert(workspacePages.length === 22, `expected 22 workspace routes, got ${workspacePages.length}`);
assert(new Set(workspacePages.map(({ id }) => id)).size === 22, "workspace page ids are not unique");
assert(new Set(workspacePages.map(({ route }) => route)).size === 22, "workspace routes are not unique");
for (const page of workspacePages) {
  assert(page.no >= 1 && page.no <= 22, `invalid page number for ${page.route}`);
  const pagePath = `apps/frontend/app${page.route}/page.tsx`;
  assert(existsSync(resolve(root, pagePath)), `missing page implementation ${pagePath}`);
}

const browserReport = readJson(".codex/runs/CURRENT/22-page-actions/report.json");
assert(browserReport.contract_version === "22-page-action-acceptance-v2", "browser report contract drift");
assert(browserReport.status === "verified", "browser report is not verified");
assert(browserReport.dev_only === true && browserReport.hosted_proof === false, "browser report scope is not honest DEV-ONLY");
assert(browserReport.proof_scope === "dev_only_localhost", "browser report proof_scope drift");
assert(browserReport.registered_route_count === 22, "browser report registered route count drift");
assert(browserReport.visited_route_count === 22, "browser report visited route count drift");
assert(browserReport.route_registry_parity === true, "browser route registry parity failed");
assert(browserReport.audited_enabled_family_count === 29, "enabled family count drift");
assert(browserReport.audited_enabled_member_action_count === 161, "enabled member count drift");
assert(browserReport.direct_effect_count === 160, "direct effect count drift");
assert(browserReport.preverified_exact_control_count === 1, "preverified control count drift");
assert(browserReport.excluded_member_action_count === 13, "excluded member count drift");
assert(browserReport.excluded_spec_only_count === 5, "spec-only exclusion count drift");
assert(browserReport.excluded_contract_only_count === 2, "contract-only exclusion count drift");
assert(browserReport.excluded_provider_gated_count === 1, "provider-gated exclusion count drift");
assert(browserReport.excluded_conditional_count === 5, "conditional exclusion count drift");
assert(browserReport.unregistered_page_local_action_count === 0, "unregistered page-local controls exist");
assert(browserReport.dead_action_count === 0, "dead registered actions exist");
assert(browserReport.click_only_passes === 0, "click-only passes exist");
assert(browserReport.provider_request_count === 2, "provider request count drift");
assert(browserReport.allowed_build_request_count === 2, "allowed build request count drift");
assert(browserReport.live_provider_response_count === 2, "live provider response count drift");
assert(browserReport.unexpected_provider_request_count === 0, "unexpected provider requests exist");
assert(browserReport.mocks_used === false, "browser report used mocks");
assert(browserReport.route_interception_used === false, "browser report used request interception");
assert(browserReport.secret_output === false, "browser report detected secret output");

const auditedRoutes = new Set(browserReport.routes.map(({ route }) => route));
for (const { route } of workspacePages) assert(auditedRoutes.has(route), `browser report omitted ${route}`);

const substanceClasses = new Map([
  ["/home", "real"],
  ["/login", "real"],
  ["/workbench", "real"],
  ["/organism", "real"],
  ["/organism/replay", "contract"],
  ["/organism/map", "contract"],
  ["/agents", "contract"],
  ["/files", "real"],
  ["/files/local", "spec"],
  ["/tools", "real"],
  ["/marketplace", "contract"],
  ["/observe", "contract"],
  ["/games", "real"],
  ["/apps", "real"],
  ["/media", "real"],
  ["/docs-output", "real"],
  ["/evidence", "contract"],
  ["/diagnostics", "contract"],
  ["/design-system", "real"],
  ["/technology", "contract"],
  ["/settings", "contract"],
  ["/open-source", "contract"],
]);
assert(substanceClasses.size === 22, "substance classification must cover exactly 22 routes");
for (const { route } of workspacePages) assert(substanceClasses.has(route), `substance classification omitted ${route}`);
const classCounts = [...substanceClasses.values()].reduce((counts, value) => {
  counts[value] = (counts[value] ?? 0) + 1;
  return counts;
}, {});
assert(classCounts.real === 11 && classCounts.contract === 10 && classCounts.spec === 1, "substance class totals drift");

const manifest = readJson("docs/project-progress.manifest.json");
const layers = new Map(manifest.vertical.items.map((item) => [item.id, item]));
assert(layers.get("layer_4")?.percent === 55, "L4 must remain verifier-locked at 55%");
assert(layers.get("layer_5")?.percent === 56, "L5 must remain verifier-locked at 56%");
const deltaLedger = readJson("docs/runtime-state/project-progress-delta-ledger.json");
assert(deltaLedger.contract_version === "project-progress-delta-ledger-v1", "progress delta ledger contract drift");
assert(Array.isArray(deltaLedger.entries) && deltaLedger.entries.length === 0, "v1 progress delta ledger must remain empty");

const authoritativeDocs = [
  "PROJECT_STATE.md",
  "docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md",
  "docs/CLOUD_SUPERBRAIN_ULTIMATUM_GPT55_PATCHED_2026-04-29.md",
  "docs/system-architecture.md",
];
const authoritativeText = authoritativeDocs.map(read).join("\n");
const endpointMentions = [...new Set(
  (authoritativeText.match(/\/(?:api|mcp|llm)\/[A-Za-z0-9_./{}:\-]+(?:\?[A-Za-z0-9_=&{}:\-]+)?/g) ?? [])
    .map((value) => value.replace(/[.,;:)\]]+$/g, "").replace(/\/+$/g, "")),
)].sort();
assert(endpointMentions.length === 98, `authoritative endpoint mention count drift: ${endpointMentions.length}`);

const serviceSourceFiles = trackedFiles("services/**").filter((file) =>
  /\.(?:py|ts|tsx|js|mjs|cjs)$/.test(file) && !/(?:^|\/)(?:node_modules|dist|coverage)(?:\/|$)/.test(file),
);
const backendRoutes = new Set();
for (const file of serviceSourceFiles) {
  const source = read(file);
  const matcher = /@?(?:app|router)\.(?:get|post|put|patch|delete)\(\s*["']([^"']+)["']/g;
  for (const match of source.matchAll(matcher)) backendRoutes.add(match[1].split("?")[0]);
}

const nginxSource = `${read("infrastructure/nginx/dev.conf")}\n${read("infrastructure/nginx/cloud.conf")}`;
assert(nginxSource.includes("location /mcp/"), "nginx MCP gateway prefix is missing");
assert(nginxSource.includes("location /llm/"), "nginx LLM gateway prefix is missing");

const negativeOnly = new Set(["/api/v1/model-capabilities"]);
const namespaces = new Set(["/api/v1"]);
const unresolvedEndpoints = [];
let implementedEndpointCount = 0;
for (const mention of endpointMentions) {
  const base = mention.split("?")[0];
  if (negativeOnly.has(base) || namespaces.has(base)) continue;
  const routedBase = base.replace(/^\/(?:mcp|llm)(?=\/)/, "");
  const matched = [...backendRoutes].some((route) => routePattern(route).test(routedBase));
  if (matched) implementedEndpointCount += 1;
  else unresolvedEndpoints.push(mention);
}
assert(unresolvedEndpoints.length === 0, `unresolved authoritative endpoints: ${unresolvedEndpoints.join(", ")}`);
assert(implementedEndpointCount === 96, `implemented authoritative endpoint count drift: ${implementedEndpointCount}`);
assert(authoritativeText.includes("stale Ref `/api/v1/model-capabilities` ist verboten"), "negative legacy endpoint context drift");

const applicationServices = ["frontend", "agent-api", "agent-worker", "memory-worker", "mcp-gateway", "llm-gateway"];
const serviceDockerfiles = new Map([
  ["frontend", "apps/frontend/Dockerfile"],
  ["agent-api", "services/agent-api/Dockerfile"],
  ["agent-worker", "services/agent-worker/Dockerfile"],
  ["memory-worker", "services/memory-worker/Dockerfile"],
  ["mcp-gateway", "services/mcp-gateway/Dockerfile"],
  ["llm-gateway", "services/llm-gateway/Dockerfile"],
]);
const cloudCompose = read("docker-compose.cloud.yml");
const devCompose = read("docker-compose.dev.yml");
for (const service of applicationServices) {
  assert(existsSync(resolve(root, serviceDockerfiles.get(service))), `missing Dockerfile for ${service}`);
  assert(cloudCompose.includes(`/${service}:\${IMAGE_TAG:-staging}`), `cloud compose image missing for ${service}`);
  assert(new RegExp(`^  ${service}:`, "m").test(devCompose), `dev compose service missing for ${service}`);
}
for (const dependency of ["postgres", "redis", "nginx"]) {
  assert(new RegExp(`^  ${dependency}:`, "m").test(devCompose), `dev compose dependency missing: ${dependency}`);
  assert(new RegExp(`^  ${dependency}:`, "m").test(cloudCompose), `cloud compose dependency missing: ${dependency}`);
}
assert(/^  local-llm:/m.test(devCompose), "dev compose local-llm fallback is missing");
assert(/^  caddy:/m.test(cloudCompose), "cloud compose caddy edge service is missing");
for (const cloudflareService of ["cloudflare-stateful-runtime", "cloudflare-llm-gateway"]) {
  assert(existsSync(resolve(root, `services/${cloudflareService}`)), `missing ${cloudflareService} source directory`);
}

const productFiles = trackedFiles("apps/frontend/**", "services/**").filter((file) =>
  /\.(?:py|ts|tsx|js|mjs|cjs)$/.test(file)
  && !/(?:^|\/)(?:tests?|e2e|node_modules|\.next|dist|coverage)(?:\/|$)/.test(file),
);
const unfinishedPattern = /\b(?:TODO|FIXME|HACK)\b|NotImplementedError|\bnot_implemented\b/g;
const unfinishedHits = [];
for (const file of productFiles) {
  const lines = read(file).split(/\r?\n/);
  lines.forEach((line, index) => {
    if (unfinishedPattern.test(line)) unfinishedHits.push(`${file}:${index + 1}`);
    unfinishedPattern.lastIndex = 0;
  });
}
assert(unfinishedHits.length === 0, `strict unfinished markers exist: ${unfinishedHits.join(", ")}`);

const removedScaffolds = [
  "HomeHeroProofPanel",
  "LoginDryRunPanel",
  "DiagnosticsProbe",
  "DesignSystemProbe",
  "TechnologyProbe",
  "OpenSourceProbe",
  "FilesLocalContractProbe",
];
const productSource = productFiles.map(read).join("\n");
for (const name of removedScaffolds) assert(!productSource.includes(name), `dead scaffold still exists: ${name}`);
assert(productSource.includes("mode=spec_only"), "files-local spec-only boundary is missing");
assert(productSource.includes("analysis_only"), "agent analysis-only boundary is missing");
assert(productSource.includes("dry_run_contract_only"), "MCP dry-run boundary is missing");

const organismView = read("apps/frontend/components/organism/OrganismView.tsx");
const cortex3d = read("apps/frontend/components/organism/CortexCanvas3D.tsx");
assert(organismView.includes(">Inspektion<"), "organism inspector is missing");
assert(organismView.includes('data-testid="organism-runtime-feed"'), "organism runtime feed is missing");
assert(organismView.includes('data-testid="organism-replay-frames"'), "organism replay frames are missing");
for (const marker of [
  'data-visual-dot-globe="fibonacci-360"',
  'data-visual-matrix-rain="dom"',
  'data-visual-scanlines="hud"',
  'data-visual-shards="plane-12-opacity-0.06"',
  'data-visual-waveform="runtime-telemetry"',
  'data-visual-core-edges="active"',
]) assert(cortex3d.includes(marker), `organism visual-v2 marker missing: ${marker}`);

const styles = read("apps/frontend/app/styles.css");
const designPage = read("apps/frontend/app/design-system/page.tsx");
const tokenExpectations = new Map([
  ["--bg-deep", "#05070d"],
  ["--surface-1", "#0b1020"],
  ["--surface-2", "#101a31"],
  ["--cyan", "#00e5ff"],
  ["--blue", "#3b82f6"],
  ["--violet", "#8b5cf6"],
  ["--magenta", "#ec4899"],
  ["--gold", "#fbbf24"],
  ["--green", "#22c55e"],
  ["--amber", "#f59e0b"],
  ["--red", "#ef4444"],
  ["--text-pri", "#eaf2ff"],
]);
for (const [token, value] of tokenExpectations) {
  assert(styles.includes(`${token}: ${value};`), `NeuroGlass token drift: ${token}`);
}
assert(designPage.includes('{ name: "Surface 2", hex: "#101A31"'), "design-system Surface 2 display drift");
for (const token of tokenExpectations.keys()) assert(styles.includes(`background: var(${token});`), `token swatch is not source-bound: ${token}`);

const openSourcePage = read("apps/frontend/app/open-source/page.tsx");
assert(!existsSync(resolve(root, "LICENSE")), "unexpected root LICENSE; rerun legal/license audit");
assert(openSourcePage.includes("OWNER-BLOCKED · Lizenzwahl"), "license Owner block is not visible");
assert(!openSourcePage.includes("Cloud Superbrain ist Open Source"), "unlicensed open-source claim returned");
assert(!openSourcePage.includes("Lizenzen eingehalten"), "unverified license-compliance claim returned");

const auditReport = read("docs/audit/five-axis-substance-audit-2026-08-02.md");
assert(read("AGENTS.md").includes("Stack: Next.js 16.2.11, LangGraph, FastAPI, pgvector"), "active stack version drift");
for (const phrase of [
  "11 ECHT NUTZBAR",
  "10 NUR CONTRACT",
  "1 SPEC/STUB",
  "96 aktuelle Endpoints",
  "L4 bleibt 55 %",
  "L5 bleibt 56 %",
  "MARKET_READY:false",
  "DEV-ONLY; hosted proof still blocked",
]) assert(auditReport.includes(phrase), `audit report phrase missing: ${phrase}`);

console.log("[five-axis-audit] PASS");
console.log(`[five-axis-audit] routes=22 real=${classCounts.real} contract=${classCounts.contract} spec=${classCounts.spec}`);
console.log(`[five-axis-audit] actions=161 direct=160 preverified=1 excluded=13 provider_live=2`);
console.log(`[five-axis-audit] L4=${layers.get("layer_4").percent} L5=${layers.get("layer_5").percent} deltas=${deltaLedger.entries.length}`);
console.log(`[five-axis-audit] docs_endpoint_mentions=98 implemented=96 namespace=1 negative_legacy=1 unresolved=0`);
console.log(`[five-axis-audit] product_files=${productFiles.length} strict_unfinished=0 dead_scaffolds=0`);
console.log("[five-axis-audit] inspector=true replay=true neuroglass_tokens=12 organism_visual_v2=verified");
console.log("[five-axis-audit] MARKET_READY:false; DEV-ONLY; hosted proof still blocked");
