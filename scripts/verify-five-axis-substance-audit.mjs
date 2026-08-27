import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = process.cwd();

function read(relativePath) {
  return readFileSync(resolve(root, relativePath), "utf8");
}

function readJson(relativePath) {
  return JSON.parse(read(relativePath));
}

function sha256(relativePath) {
  return createHash("sha256").update(readFileSync(resolve(root, relativePath))).digest("hex");
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

const browserReportPath = process.env.FIVE_AXIS_BROWSER_REPORT?.trim()
  || ".codex/runs/CURRENT/22-page-actions/report.json";
assert(existsSync(resolve(root, browserReportPath)), `browser report is missing: ${browserReportPath}`);
const browserReport = readJson(browserReportPath);
assert(browserReport.contract_version === "22-page-action-acceptance-v2", "browser report contract drift");
assert(browserReport.status === "verified", "browser report is not verified");
assert(browserReport.dev_only === true && browserReport.hosted_proof === false, "browser report scope is not honest DEV-ONLY");
assert(browserReport.proof_scope === "dev_only_localhost", "browser report proof_scope drift");
assert(browserReport.registered_route_count === 22, "browser report registered route count drift");
assert(browserReport.visited_route_count === 22, "browser report visited route count drift");
assert(browserReport.route_registry_parity === true, "browser route registry parity failed");
assert(
  browserReport.audited_enabled_family_count === browserReport.registered_enabled_family_count,
  "enabled family audit is incomplete",
);
assert(
  browserReport.audited_enabled_member_action_count === browserReport.registered_enabled_member_action_count,
  "enabled member audit is incomplete",
);
assert(
  browserReport.direct_effect_count + browserReport.preverified_exact_control_count
    === browserReport.audited_enabled_member_action_count,
  "direct/preverified action accounting drift",
);
assert(
  browserReport.excluded_spec_only_count
    + browserReport.excluded_contract_only_count
    + browserReport.excluded_provider_gated_count
    + browserReport.excluded_conditional_count
    === browserReport.excluded_member_action_count,
  "excluded action accounting drift",
);
assert(browserReport.unregistered_page_local_action_count === 0, "unregistered page-local controls exist");
assert(browserReport.dead_action_count === 0, "dead registered actions exist");
assert(browserReport.click_only_passes === 0, "click-only passes exist");
assert(
  browserReport.provider_request_count === browserReport.allowed_build_request_count,
  "provider request allowlist accounting drift",
);
assert(
  browserReport.live_provider_response_count === browserReport.allowed_build_request_count,
  "allowed build requests lack live gateway responses",
);
assert(browserReport.unexpected_provider_request_count === 0, "unexpected provider requests exist");
assert(browserReport.mocks_used === false, "browser report used mocks");
assert(browserReport.route_interception_used === false, "browser report used request interception");
assert(browserReport.secret_output === false, "browser report detected secret output");

const sourceFiles = {
  action_spec: "apps/frontend/e2e/22-page-actions.spec.ts",
  action_matrix: "apps/frontend/lib/actionMatrix.ts",
  workspace_nav: "apps/frontend/lib/nav.tsx",
  product_acceptance_spec: "apps/frontend/e2e/product-acceptance.spec.ts",
  product_acceptance_report: browserReport.source_binding?.product_acceptance_report_path,
};
for (const [name, path] of Object.entries(sourceFiles)) {
  assert(typeof path === "string" && path.length > 0, `source binding path missing: ${name}`);
  assert(existsSync(resolve(root, path)), `source binding file missing: ${name}`);
  assert(
    browserReport.source_binding?.files_sha256?.[name] === sha256(path),
    `source binding hash mismatch: ${name}`,
  );
}
const sourceBindingMaterial = Object.keys(sourceFiles).sort()
  .map((name) => `${name}:${browserReport.source_binding.files_sha256[name]}`).join("\n");
const expectedSourceBinding = createHash("sha256").update(sourceBindingMaterial).digest("hex");
assert(browserReport.source_binding_sha256 === expectedSourceBinding, "source binding aggregate hash mismatch");

const auditedRoutes = new Set(browserReport.routes.map(({ route }) => route));
for (const { route } of workspacePages) assert(auditedRoutes.has(route), `browser report omitted ${route}`);

const auditReport = read("docs/audit/five-axis-substance-audit-2026-08-02.md");
const classNames = new Map([
  ["ECHT NUTZBAR", "real"],
  ["NUR CONTRACT", "contract"],
  ["SPEC/STUB", "spec"],
]);
const substanceClasses = new Map();
for (const line of auditReport.split(/\r?\n/)) {
  const match = line.match(/^\|\s*\d+\s*\|\s*`([^`]+)`\s*\|.*\|\s*\*\*(ECHT NUTZBAR|NUR CONTRACT|SPEC\/STUB)/);
  if (match) substanceClasses.set(match[1], classNames.get(match[2]));
}
assert(substanceClasses.size === 22, "substance classification must cover exactly 22 routes");
for (const { route } of workspacePages) assert(substanceClasses.has(route), `substance classification omitted ${route}`);
const classCounts = [...substanceClasses.values()].reduce((counts, value) => {
  counts[value] = (counts[value] ?? 0) + 1;
  return counts;
}, {});
for (const [kind, label] of [["real", "ECHT NUTZBAR"], ["contract", "NUR CONTRACT"], ["spec", "SPEC/STUB"]]) {
  const summary = auditReport.match(new RegExp(`- \\*\\*(\\d+) ${label.replace("/", "\\/")}`));
  assert(summary, `audit summary is missing ${label}`);
  assert(Number(summary[1]) === classCounts[kind], `audit summary/table mismatch: ${label}`);
}

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
assert(endpointMentions.length > 0, "authoritative endpoint inventory is empty");

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

const endpointTokenClasses = new Map();
for (const match of auditReport.matchAll(
  /^\|\s*`(\/(?:api|mcp|llm)\/[^`]*|\/api\/v1)`\s*\|\s*`(NEGATIVE-ONLY|NAMESPACE-ONLY)`\s*\|/gm,
)) {
  assert(!endpointTokenClasses.has(match[1]), `duplicate endpoint token classification: ${match[1]}`);
  endpointTokenClasses.set(match[1], match[2]);
}
const negativeOnly = new Set(
  [...endpointTokenClasses].filter(([, kind]) => kind === "NEGATIVE-ONLY").map(([token]) => token),
);
const namespaces = new Set(
  [...endpointTokenClasses].filter(([, kind]) => kind === "NAMESPACE-ONLY").map(([token]) => token),
);
assert(negativeOnly.size > 0, "audit has no explicit NEGATIVE-ONLY endpoint tokens");
assert(namespaces.size > 0, "audit has no explicit NAMESPACE-ONLY endpoint tokens");
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

const organismRoutes = new Map(browserReport.routes.map((route) => [route.route, route]));
assert(organismRoutes.get("/organism")?.visited === true, "organism browser route is not visited");
assert(organismRoutes.get("/organism/replay")?.visited === true, "organism replay browser route is not visited");
const browserActions = new Map(browserReport.actions.map((action) => [action.action_id, action]));
for (const actionId of ["organism-nav-replay", "replay-live-load", "replay-live-copy"]) {
  const action = browserActions.get(actionId);
  assert(action?.passed === true && action?.effect_observed === true, `browser action not measured: ${actionId}`);
}

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

assert(read("AGENTS.md").includes("Stack: Next.js 16.2.11, LangGraph, FastAPI, pgvector"), "active stack version drift");
for (const phrase of [
  "L4 bleibt 55 %",
  "L5 bleibt 56 %",
  "MARKET_READY:false",
  "DEV-ONLY; hosted proof still blocked",
  "Messgrenze:",
  "Organismus-Optik: **OWNER-ABNAHME OFFEN**",
  "Keine Optik-Verifikation aus Quelltext-Markern",
  "R-VIS-1",
  "Endpoint-/Routenabgleich ist statisch",
]) assert(auditReport.includes(phrase), `audit report phrase missing: ${phrase}`);

console.log("[five-axis-audit] PASS");
console.log(`[five-axis-audit] routes=22 real=${classCounts.real} contract=${classCounts.contract} spec=${classCounts.spec}`);
console.log(`[five-axis-audit] actions=${browserReport.audited_enabled_member_action_count} direct=${browserReport.direct_effect_count} preverified=${browserReport.preverified_exact_control_count} excluded=${browserReport.excluded_member_action_count} provider_live=${browserReport.live_provider_response_count}`);
console.log(`[five-axis-audit] L4=${layers.get("layer_4").percent} L5=${layers.get("layer_5").percent} deltas=${deltaLedger.entries.length}`);
console.log(`[five-axis-audit] docs_endpoint_mentions=${endpointMentions.length} declared_routes=${implementedEndpointCount} namespace=${namespaces.size} negative_only=${negativeOnly.size} unresolved=${unresolvedEndpoints.length}`);
console.log(`[five-axis-audit] product_files=${productFiles.length} strict_unfinished=${unfinishedHits.length} dead_scaffolds=0`);
console.log(`[five-axis-audit] inspector/replay=browser_measured neuroglass_tokens_declared=${tokenExpectations.size} organism_visual=owner_blocked`);
console.log("[five-axis-audit] MARKET_READY:false; DEV-ONLY; hosted proof still blocked");
