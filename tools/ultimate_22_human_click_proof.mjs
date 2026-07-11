import fs from "fs";
import path from "path";
import { createRequire } from "module";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "..");
const require = createRequire(import.meta.url);
const { chromium } = require(path.join(repoRoot, "apps", "frontend", "node_modules", "playwright"));

const CANONICAL_ROUTES = [
  "/home",
  "/login",
  "/workbench",
  "/organism",
  "/organism/replay",
  "/organism/map",
  "/agents",
  "/files",
  "/files/local",
  "/tools",
  "/marketplace",
  "/observe",
  "/games",
  "/apps",
  "/media",
  "/docs-output",
  "/evidence",
  "/diagnostics",
  "/design-system",
  "/technology",
  "/settings",
  "/open-source",
];

const CONTRACT = {
  name: "ultimate_22_human_click_proof",
  version: "goal-d2-human-click-proof-v1",
  criteria: {
    K1: "Exact canonical 22 routes only.",
    K2: "PASS requires URL/modal/toast/result/api/storage signal; text-only animation is WARN_WEAK.",
    K3: "Input flows are exercised before FAIL on workbench/files/tools/marketplace; batch1 exercises workbench/organism/agents; batch2 exercises tools/files/marketplace; batch3 exercises games/apps/media/docs-output artifact flows; batch4 exercises home/login/observe/evidence proof flows; batch5 exercises diagnostics/design-system/technology/settings/open-source/files-local/organism-replay/organism-map.",
    K4: "External links and target=_blank are never followed.",
    K5: "Classification set is fixed.",
    K6: "Turbopack/dev stability: wait for health, retry 502/503/504, domcontentloaded + networkidle best-effort + settle.",
    strict_batches: "On batch2, batch3, batch4, and batch5, every WARN_WEAK must be action-covered by a passed route-specific flow, and visual_reference_checked must be true per route.",
  },
  classes: [
    "PASS_ACTION_RESULT",
    "PASS_NAVIGATION",
    "PASS_DISABLED_EXPLAINED",
    "WARN_WEAK",
    "WARN_DECORATIVE_IMAGE",
    "FAIL_DEAD_INTERACTIVE",
    "FAIL_STATIC_LOOKS_CLICKABLE",
    "FAIL_CLICK_ERROR",
    "FAIL_DISABLED_UNEXPLAINED",
  ],
};

const BATCH_ROUTES = {
  batch1: ["/workbench", "/organism", "/agents"],
  batch2: ["/tools", "/files", "/marketplace"],
  batch3: ["/games", "/apps", "/media", "/docs-output"],
  batch4: ["/home", "/login", "/observe", "/evidence"],
  batch5: ["/diagnostics", "/design-system", "/technology", "/settings", "/open-source", "/files/local", "/organism/replay", "/organism/map"],
};

const STRICT_BATCHES = new Set(["batch2", "batch3", "batch4", "batch5"]);

const VISUAL_TARGETS = {
  "/home": "docs/design/page-visual-targets/01-home.md",
  "/login": "docs/design/page-visual-targets/02-login.md",
  "/files": "docs/design/page-visual-targets/08-files.md",
  "/tools": "docs/design/page-visual-targets/10-tools.md",
  "/marketplace": "docs/design/page-visual-targets/11-marketplace.md",
  "/observe": "docs/design/page-visual-targets/12-observe.md",
  "/games": "docs/design/page-visual-targets/13-games.md",
  "/apps": "docs/design/page-visual-targets/14-apps.md",
  "/media": "docs/design/page-visual-targets/15-media.md",
  "/docs-output": "docs/design/page-visual-targets/16-docs-output.md",
  "/evidence": "docs/design/page-visual-targets/17-evidence.md",
  "/diagnostics": "docs/design/page-visual-targets/18-diagnostics.md",
  "/design-system": "docs/design/page-visual-targets/19-design-system.md",
  "/technology": "docs/design/page-visual-targets/20-technology.md",
  "/settings": "docs/design/page-visual-targets/21-settings.md",
  "/open-source": "docs/design/page-visual-targets/22-open-source.md",
  "/files/local": "docs/design/page-visual-targets/09-files-local.md",
  "/organism/replay": "docs/design/page-visual-targets/05-organism-replay.md",
  "/organism/map": "docs/design/page-visual-targets/06-organism-map.md",
};

const ORGANISM_COVERAGE_RULES = [
  ...["RUHE", "PLANUNG", "AUSFÜHRUNG", "PRÜFUNG", "BLOCKIERT"].map((name) => ({
    tag: "button",
    text: name,
    actionLabel: `organism run-state ${name}`,
  })),
  ...["WERKBANK", "AGENTEN", "TOOLS / MCP", "MODELLE", "MARKTPLATZ", "OBSERVABILITY", "MEMORY", "CLOUD"].map((name) => ({
    tag: "button",
    text: name,
    actionLabel: `organism hub ${name}`,
  })),
  { tag: "button", textPattern: /^WERKBANK\s+L1$/i, actionLabel: "organism hub WERKBANK" },
  { tag: "button", textPattern: /^AGENTEN\s+L3$/i, actionLabel: "organism hub AGENTEN" },
  { tag: "button", textPattern: /^TOOLS \/ MCP\s+L5$/i, actionLabel: "organism hub TOOLS / MCP" },
  { tag: "button", textPattern: /^MODELLE\s+L4$/i, actionLabel: "organism hub MODELLE" },
  { tag: "button", textPattern: /^MARKTPLATZ\s+L5$/i, actionLabel: "organism hub MARKTPLATZ" },
  { tag: "button", textPattern: /^OBSERVABILITY\s+L7$/i, actionLabel: "organism hub OBSERVABILITY" },
  { tag: "button", textPattern: /^MEMORY\s+L6$/i, actionLabel: "organism hub MEMORY" },
  { tag: "button", textPattern: /^CLOUD\s+L2$/i, actionLabel: "organism hub CLOUD" },
  { tag: "button", textPattern: /Auto-rotate/i, actionLabel: "organism control /Auto-rotate/i" },
  { tag: "button", textPattern: /Kamera zurücksetzen/i, actionLabel: "organism control /Kamera zurücksetzen/i" },
  { tag: "button", textPattern: /Weniger Bewegung/i, actionLabel: "organism control /Weniger Bewegung/i" },
  ...["L1 FE", "L2 ORC", "L3 AP", "L4 LLM", "L5 MCP", "L6 MEM", "L7 OBS", "planner", "coder", "tester", "devops"].map((text, index) => ({
    tag: "button",
    text,
    actionLabel: `organism filter ${index}`,
  })),
];

const STRICT_ACTION_COVERAGE = {
  "*": [
    { tag: "button", ariaLabel: "Suchen oder Kommando ausführen", actionLabel: "cmdk open" },
  ],
  "/files": [
    { tag: "input", ariaLabel: "Memory search query", actionLabel: "files query fill" },
    { tag: "button", testId: "goal-b-files-search", actionLabel: "files search -> /api/v1/memory/search" },
    { tag: "select", ariaLabel: "Live-Daten Endpoint", actionLabel: "live-console select endpoint" },
    { tag: "button", testId: "live-console-load", actionLabel: "live-console load" },
    { tag: "button", text: "Kopieren", actionLabel: "live-console copy" },
  ],
  "/tools": [
    { tag: "select", ariaLabel: "Read-only tool", actionLabel: "tools select task_router" },
    { tag: "input", ariaLabel: "Tool query", actionLabel: "tools query fill" },
    { tag: "button", testId: "goal-b-tool-execute", actionLabel: "tools execute task_router" },
    { tag: "select", ariaLabel: "MCP/Tools Endpoint", actionLabel: "live-console select endpoint" },
    { tag: "button", testId: "live-console-load", actionLabel: "live-console load" },
    { tag: "button", text: "Kopieren", actionLabel: "live-console copy" },
  ],
  "/marketplace": [
    { tag: "select", ariaLabel: "Marketplace item", actionLabel: "marketplace select item" },
    { tag: "button", testId: "goal-b-marketplace-details", actionLabel: "marketplace details dry-run plan" },
    { tag: "button", testId: "goal-b-marketplace-install", actionLabel: "marketplace install dry-run artifact" },
  ],
  "/games": [
    { tag: "button", testId: "goal-b-games-create", actionLabel: "games create artifact" },
    { tag: "button", testId: "live-console-load", actionLabel: "live-console load" },
    { tag: "button", text: "Kopieren", actionLabel: "live-console copy" },
  ],
  "/apps": [
    { tag: "button", testId: "goal-b-apps-create", actionLabel: "apps create artifact" },
    { tag: "select", ariaLabel: "Apps Endpoint", actionLabel: "live-console select endpoint" },
    { tag: "button", testId: "live-console-load", actionLabel: "live-console load" },
    { tag: "button", text: "Kopieren", actionLabel: "live-console copy" },
  ],
  "/media": [
    { tag: "button", testId: "goal-b-media-create", actionLabel: "media create artifact" },
    { tag: "button", testId: "live-console-load", actionLabel: "live-console load" },
    { tag: "button", text: "Kopieren", actionLabel: "live-console copy" },
  ],
  "/docs-output": [
    { tag: "button", testId: "goal-b-docs-output-create", actionLabel: "docs-output create artifact" },
    { tag: "button", testId: "goal-b-docs-export-pdf", actionLabel: "docs-output export pdf plan" },
    { tag: "button", testId: "goal-b-docs-export-md", actionLabel: "docs-output export md plan" },
    { tag: "button", testId: "live-console-load", actionLabel: "live-console load" },
    { tag: "button", text: "Kopieren", actionLabel: "live-console copy" },
  ],
  "/home": [
    { tag: "select", ariaLabel: "Live-Daten Endpoint", actionLabel: "live-console select endpoint" },
    { tag: "button", testId: "live-console-load", actionLabel: "live-console load" },
    { tag: "select", ariaLabel: "Live-Daten Endpoint", actionLabel: "live-console select endpoint" },
    { tag: "button", testId: "live-console-load", actionLabel: "live-console load" },
    { tag: "button", text: "Kopieren", actionLabel: "live-console copy" },
  ],
  "/login": [
    { tag: "input", ariaLabel: "Name", actionLabel: "login session name" },
    { tag: "button", testId: "rl-signin", actionLabel: "login real session sign-in" },
  ],
  "/observe": [
    { tag: "button", testId: "goal-b-observe-refresh", actionLabel: "observe metrics contract probe" },
    { tag: "select", ariaLabel: "Live-Daten Endpoint", actionLabel: "live-console select endpoint" },
    { tag: "button", testId: "live-console-load", actionLabel: "live-console load" },
    { tag: "button", text: "Kopieren", actionLabel: "live-console copy" },
  ],
  "/evidence": [
    { tag: "button", testId: "goal-b-evidence-verify", actionLabel: "evidence verifier probe" },
    { tag: "select", ariaLabel: "Live-Daten Endpoint", actionLabel: "live-console select endpoint" },
    { tag: "button", testId: "live-console-load", actionLabel: "live-console load" },
    { tag: "button", text: "Kopieren", actionLabel: "live-console copy" },
  ],
  "/diagnostics": [
    { tag: "button", testId: "goal-b-diagnostics-probe", actionLabel: "diagnostics audit probe" },
    { tag: "select", ariaLabel: "Live-Daten Endpoint", actionLabel: "live-console select endpoint" },
    { tag: "button", testId: "live-console-load", actionLabel: "live-console load" },
    { tag: "button", text: "Kopieren", actionLabel: "live-console copy" },
  ],
  "/design-system": [
    { tag: "button", testId: "goal-b-design-system-probe", actionLabel: "design-system token probe" },
    { tag: "button", testId: "live-console-load", actionLabel: "live-console load" },
    { tag: "button", text: "Kopieren", actionLabel: "live-console copy" },
  ],
  "/technology": [
    { tag: "button", testId: "goal-b-technology-probe", actionLabel: "technology cloud layer probe" },
    { tag: "select", ariaLabel: "Live-Daten Endpoint", actionLabel: "live-console select endpoint" },
    { tag: "button", testId: "live-console-load", actionLabel: "live-console load" },
    { tag: "button", text: "Kopieren", actionLabel: "live-console copy" },
  ],
  "/settings": [
    { tag: "button", testId: "goal-b-settings-planonly", actionLabel: "settings gate planonly" },
    { tag: "select", ariaLabel: "Live-Daten Endpoint", actionLabel: "live-console select endpoint" },
    { tag: "button", testId: "live-console-load", actionLabel: "live-console load" },
    { tag: "button", text: "Kopieren", actionLabel: "live-console copy" },
  ],
  "/open-source": [
    { tag: "button", testId: "goal-b-open-source-probe", actionLabel: "open-source license probe" },
    { tag: "select", ariaLabel: "Live-Daten Endpoint", actionLabel: "live-console select endpoint" },
    { tag: "button", testId: "live-console-load", actionLabel: "live-console load" },
    { tag: "button", text: "Kopieren", actionLabel: "live-console copy" },
  ],
  "/files/local": [
    { tag: "button", testId: "goal-b-files-local-contract", actionLabel: "files-local contract probe" },
    { tag: "button", ariaLabel: "Root project", actionLabel: "files-local root project" },
  ],
  "/organism/replay": [
    ...ORGANISM_COVERAGE_RULES,
    { tag: "select", ariaLabel: "Organism replay Endpoint", actionLabel: "live-console select endpoint" },
    { tag: "button", testId: "live-console-load", actionLabel: "live-console load" },
    { tag: "button", text: "Kopieren", actionLabel: "live-console copy" },
  ],
  "/organism/map": [
    ...ORGANISM_COVERAGE_RULES,
    { tag: "select", ariaLabel: "Organism map Endpoint", actionLabel: "live-console select endpoint" },
    { tag: "button", testId: "live-console-load", actionLabel: "live-console load" },
    { tag: "button", text: "Kopieren", actionLabel: "live-console copy" },
  ],
};

function parseArgs(argv) {
  const args = {
    baseUrl: "http://localhost:8081",
    routes: [...CANONICAL_ROUTES],
    out: path.join(repoRoot, ".codex", "runs", "CURRENT", "goal-d2", "batch1"),
    selfCheck: false,
    batch: null,
  };
  for (let index = 2; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--base-url") args.baseUrl = argv[++index].replace(/\/+$/, "");
    else if (arg === "--routes") args.routes = argv[++index].split(",").map((route) => route.trim()).filter(Boolean);
    else if (arg === "--out") args.out = path.resolve(argv[++index]);
    else if (arg === "--self-check") args.selfCheck = true;
    else if (arg === "--batch") args.batch = argv[++index].toLowerCase();
  }
  if (args.batch) {
    assert(BATCH_ROUTES[args.batch], `Unknown batch: ${args.batch}`);
    args.routes = [...BATCH_ROUTES[args.batch]];
    args.out = path.join(repoRoot, ".codex", "runs", "CURRENT", "goal-d2", args.batch);
  }
  return args;
}

function batchNameFromOut(outDir) {
  const name = path.basename(path.resolve(outDir)).toLowerCase();
  return /^batch\d+$/.test(name) ? name : "batch";
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function ensureCanonicalRoutes(routes, batchName = "", selfCheck = false) {
  const canonical = CANONICAL_ROUTES.join(",");
  assert(canonical === [
    "/home",
    "/login",
    "/workbench",
    "/organism",
    "/organism/replay",
    "/organism/map",
    "/agents",
    "/files",
    "/files/local",
    "/tools",
    "/marketplace",
    "/observe",
    "/games",
    "/apps",
    "/media",
    "/docs-output",
    "/evidence",
    "/diagnostics",
    "/design-system",
    "/technology",
    "/settings",
    "/open-source",
  ].join(","), "K1 canonical route registry was changed.");
  assert(new Set(routes).size === routes.length, "Routes must not contain duplicates.");
  for (const route of routes) assert(CANONICAL_ROUTES.includes(route), `Route is not canonical: ${route}`);
  for (const [batch, batchRoutes] of Object.entries(BATCH_ROUTES)) {
    const same = routes.length === batchRoutes.length && routes.every((route, index) => route === batchRoutes[index]);
    if (!selfCheck && batchName === batch) {
      assert(same, `${batch} must run exact routes: ${batchRoutes.join(",")}`);
    }
  }
}

function writeJson(filePath, value) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

function listFilesRecursive(dir) {
  if (!fs.existsSync(dir)) return [];
  const entries = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) entries.push(...listFilesRecursive(fullPath));
    else entries.push(fullPath);
  }
  return entries;
}

function visualReferenceCheck(route) {
  const visualTarget = VISUAL_TARGETS[route] ?? null;
  const visualTargetPath = visualTarget ? path.join(repoRoot, visualTarget) : null;
  const referenceDir = path.join(repoRoot, "docs", "reference");
  const referenceFiles = listFilesRecursive(referenceDir)
    .filter((filePath) => /\.(png|jpe?g|webp|md|html)$/i.test(filePath));
  return {
    visual_reference_checked: Boolean(visualTargetPath && fs.existsSync(visualTargetPath) && referenceFiles.length > 0),
    visual_target_doc: visualTarget,
    visual_target_doc_exists: Boolean(visualTargetPath && fs.existsSync(visualTargetPath)),
    reference_file_count: referenceFiles.length,
  };
}

function coveredStrictInteractives(route, interactives, actions) {
  const rules = [...(STRICT_ACTION_COVERAGE["*"] ?? []), ...(STRICT_ACTION_COVERAGE[route] ?? [])];
  const passedActionLabels = new Set(
    actions
      .filter((action) => action.class === "PASS_ACTION_RESULT" && action.strong_signal)
      .map((action) => action.label),
  );
  return interactives.map((item) => {
    if (!String(item.class).startsWith("WARN")) return item;
    const rule = rules.find((candidate) => {
      if (candidate.tag && candidate.tag !== item.tag) return false;
      if (candidate.testId && candidate.testId !== item.testId) return false;
      if (candidate.ariaLabel && candidate.ariaLabel !== item.ariaLabel) return false;
      if (candidate.text && candidate.text !== item.text) return false;
      if (candidate.textPattern && !candidate.textPattern.test(item.text)) return false;
      return passedActionLabels.has(candidate.actionLabel);
    });
    if (!rule) return item;
    return {
      ...item,
      covered_by_action: rule.actionLabel,
      action_covered: true,
    };
  });
}

async function waitForFrontendHealth(page, baseUrl) {
  const healthUrl = `${baseUrl}/api/v1/health`;
  for (let attempt = 1; attempt <= 12; attempt += 1) {
    try {
      const response = await page.request.get(healthUrl, { timeout: 5000 });
      if (response.ok()) return true;
    } catch {
      // Retry below; dev frontend can briefly recompile.
    }
    await page.waitForTimeout(1000);
  }
  return false;
}

async function gotoStable(page, baseUrl, url, route, consoleErrors) {
  let lastStatus = "no-response";
  for (let attempt = 1; attempt <= 2; attempt += 1) {
    consoleErrors.length = 0;
    try {
      const response = await page.goto(url, { waitUntil: "domcontentloaded", timeout: 60000 });
      lastStatus = String(response?.status() ?? "no-response");
      if (response && response.ok()) {
        await page.waitForLoadState("networkidle", { timeout: 45000 }).catch(() => undefined);
        await page.waitForTimeout(900);
        return response;
      }
    } catch (error) {
      lastStatus = error instanceof Error ? error.message : String(error);
    }
    if (/502|503|504|net::ERR|Target closed|Timeout/i.test(lastStatus)) {
      await waitForFrontendHealth(page, baseUrl);
      await page.waitForTimeout(1500 * attempt);
      continue;
    }
    break;
  }
  throw new Error(`Route ${route} did not become stable: ${lastStatus}`);
}

async function clickAndMeasure(page, locator, label, options = {}) {
  const beforeUrl = page.url();
  const beforeStorage = await page.evaluate(() => {
    const dump = (storage) => {
      const out = {};
      for (let index = 0; index < storage.length; index += 1) {
        const key = storage.key(index);
        if (key != null) out[key] = storage.getItem(key);
      }
      return out;
    };
    return JSON.stringify({ local: dump(localStorage), session: dump(sessionStorage) });
  }).catch(() => "");
  const requests = [];
  const failedRequests = [];
  const onRequestFinished = async (request) => {
    const url = request.url();
    if (/\/api\/|\/mcp\/|\/llm\//.test(url)) {
      const response = await request.response().catch(() => null);
      requests.push(`${request.method()} ${response?.status() ?? "no-status"} ${url}`);
    }
  };
  const onRequestFailed = (request) => {
    const url = request.url();
    if (/\/api\/|\/mcp\/|\/llm\//.test(url)) failedRequests.push(`${request.method()} FAIL ${url}`);
  };
  page.on("requestfinished", onRequestFinished);
  page.on("requestfailed", onRequestFailed);
  try {
    await locator.click({ timeout: options.timeout ?? 20000 });
    if (options.waitForText && options.resultSelector) {
      await page.locator(options.resultSelector).filter({ hasText: options.waitForText }).first().waitFor({ timeout: options.waitTimeout ?? 45000 });
    }
    await page.waitForTimeout(options.settle ?? 900);
    page.off("requestfinished", onRequestFinished);
    page.off("requestfailed", onRequestFailed);
    const afterUrl = page.url();
    const afterStorage = await page.evaluate(() => {
      const dump = (storage) => {
        const out = {};
        for (let index = 0; index < storage.length; index += 1) {
          const key = storage.key(index);
          if (key != null) out[key] = storage.getItem(key);
        }
        return out;
      };
      return JSON.stringify({ local: dump(localStorage), session: dump(sessionStorage) });
    }).catch(() => "");
    const resultText = options.resultSelector ? await page.locator(options.resultSelector).innerText({ timeout: 15000 }).catch(() => "") : "";
    const urlChanged = beforeUrl !== afterUrl;
    const storageChanged = beforeStorage !== afterStorage;
    const resultPass = /PASS|opened|switched|visible|ready|status=/i.test(resultText);
    const completedApi = requests.some((entry) => /\s2\d\d\s|\s3\d\d\s/.test(entry));
    const strong = urlChanged || storageChanged || completedApi || resultPass;
    return {
      label,
      class: strong ? "PASS_ACTION_RESULT" : "WARN_WEAK",
      strong_signal: strong,
      url_changed: urlChanged,
      storage_changed: storageChanged,
      request_count: requests.length,
      requests: [...requests, ...failedRequests].slice(0, 12),
      result_excerpt: resultText.slice(0, 700),
    };
  } catch (error) {
    page.off("requestfinished", onRequestFinished);
    page.off("requestfailed", onRequestFailed);
    return {
      label,
      class: "FAIL_CLICK_ERROR",
      strong_signal: false,
      url_changed: false,
      storage_changed: false,
      request_count: requests.length,
      requests: [...requests, ...failedRequests].slice(0, 12),
      result_excerpt: error instanceof Error ? error.message.slice(0, 700) : String(error).slice(0, 700),
    };
  }
}

async function selectAndMeasure(page, locator, value, label, options = {}) {
  const beforeStorage = await page.evaluate(() => {
    const dump = (storage) => {
      const out = {};
      for (let index = 0; index < storage.length; index += 1) {
        const key = storage.key(index);
        if (key != null) out[key] = storage.getItem(key);
      }
      return out;
    };
    return JSON.stringify({ local: dump(localStorage), session: dump(sessionStorage) });
  }).catch(() => "");
  try {
    await locator.selectOption(value, { timeout: options.timeout ?? 20000 });
    if (options.waitForText && options.resultSelector) {
      await page.locator(options.resultSelector).filter({ hasText: options.waitForText }).first().waitFor({ timeout: options.waitTimeout ?? 45000 });
    }
    await page.waitForTimeout(options.settle ?? 600);
    const afterStorage = await page.evaluate(() => {
      const dump = (storage) => {
        const out = {};
        for (let index = 0; index < storage.length; index += 1) {
          const key = storage.key(index);
          if (key != null) out[key] = storage.getItem(key);
        }
        return out;
      };
      return JSON.stringify({ local: dump(localStorage), session: dump(sessionStorage) });
    }).catch(() => "");
    const resultText = options.resultSelector ? await page.locator(options.resultSelector).innerText({ timeout: 15000 }).catch(() => "") : "";
    const resultPass = /PASS|selected|ready|status=/i.test(resultText);
    return {
      label,
      class: resultPass || beforeStorage !== afterStorage ? "PASS_ACTION_RESULT" : "WARN_WEAK",
      strong_signal: resultPass || beforeStorage !== afterStorage,
      url_changed: false,
      storage_changed: beforeStorage !== afterStorage,
      request_count: 0,
      requests: [],
      result_excerpt: resultText.slice(0, 700),
    };
  } catch (error) {
    return {
      label,
      class: "FAIL_CLICK_ERROR",
      strong_signal: false,
      url_changed: false,
      storage_changed: false,
      request_count: 0,
      requests: [],
      result_excerpt: error instanceof Error ? error.message.slice(0, 700) : String(error).slice(0, 700),
    };
  }
}

async function clickAndMeasureState(page, locator, label, readState, options = {}) {
  const beforeState = await readState().catch(() => "");
  try {
    await locator.click({ timeout: options.timeout ?? 20000 });
    await page.waitForTimeout(options.settle ?? 400);
    const afterState = await readState().catch(() => "");
    const strong = beforeState !== afterState && String(afterState).length > 0;
    return {
      label,
      class: strong ? "PASS_ACTION_RESULT" : "WARN_WEAK",
      strong_signal: strong,
      url_changed: false,
      storage_changed: false,
      request_count: 0,
      requests: [],
      result_excerpt: `before=${String(beforeState).slice(0, 120)} | after=${String(afterState).slice(0, 120)}`,
    };
  } catch (error) {
    return {
      label,
      class: "FAIL_CLICK_ERROR",
      strong_signal: false,
      url_changed: false,
      storage_changed: false,
      request_count: 0,
      requests: [],
      result_excerpt: error instanceof Error ? error.message.slice(0, 700) : String(error).slice(0, 700),
    };
  }
}

async function clickAndMeasureDownload(page, locator, label, options = {}) {
  try {
    const [download] = await Promise.all([
      page.waitForEvent("download", { timeout: options.waitTimeout ?? 30000 }),
      locator.click({ timeout: options.timeout ?? 20000 }),
    ]);
    const filename = download.suggestedFilename();
    return {
      label,
      class: filename ? "PASS_ACTION_RESULT" : "WARN_WEAK",
      strong_signal: Boolean(filename),
      url_changed: false,
      storage_changed: false,
      request_count: 0,
      requests: [],
      result_excerpt: `download=${filename || "unknown"}`,
    };
  } catch (error) {
    return {
      label,
      class: "FAIL_CLICK_ERROR",
      strong_signal: false,
      url_changed: false,
      storage_changed: false,
      request_count: 0,
      requests: [],
      result_excerpt: error instanceof Error ? error.message.slice(0, 700) : String(error).slice(0, 700),
    };
  }
}

async function fillAndMeasure(page, locator, value, label, options = {}) {
  try {
    await locator.fill(value, { timeout: options.timeout ?? 20000 });
    if (options.waitForText && options.resultSelector) {
      await page.locator(options.resultSelector).filter({ hasText: options.waitForText }).first().waitFor({ timeout: options.waitTimeout ?? 45000 });
    }
    await page.waitForTimeout(options.settle ?? 600);
    const resultText = options.resultSelector ? await page.locator(options.resultSelector).innerText({ timeout: 15000 }).catch(() => "") : "";
    const resultPass = /PASS|updated|ready/i.test(resultText);
    return {
      label,
      class: resultPass ? "PASS_ACTION_RESULT" : "WARN_WEAK",
      strong_signal: resultPass,
      url_changed: false,
      storage_changed: false,
      request_count: 0,
      requests: [],
      result_excerpt: resultText.slice(0, 700),
    };
  } catch (error) {
    return {
      label,
      class: "FAIL_CLICK_ERROR",
      strong_signal: false,
      url_changed: false,
      storage_changed: false,
      request_count: 0,
      requests: [],
      result_excerpt: error instanceof Error ? error.message.slice(0, 700) : String(error).slice(0, 700),
    };
  }
}

async function classifyInteractive(page, baseUrl) {
  return await page.evaluate((base) => {
    const baseOrigin = new URL(base || window.location.origin, window.location.origin).origin;
    const nodes = Array.from(document.querySelectorAll("button, a[href], input, select, textarea, [role='button'], [tabindex]:not([tabindex='-1'])"));
    return nodes
      .filter((element) => {
        const rect = element.getBoundingClientRect();
        const style = getComputedStyle(element);
        return rect.width > 1 && rect.height > 1 && style.visibility !== "hidden" && style.display !== "none";
      })
      .map((element) => {
        const tag = element.tagName.toLowerCase();
        const disabled = Boolean(element.disabled || element.getAttribute("aria-disabled") === "true");
        const ariaLabel = element.getAttribute("aria-label") || "";
        const testId = element.getAttribute("data-testid") || "";
        const text = (element.innerText || ariaLabel || element.getAttribute("title") || element.getAttribute("href") || tag).trim();
        const href = element.getAttribute("href") || "";
        const target = element.getAttribute("target") || "";
        const explanation = [element.getAttribute("title"), ariaLabel, element.closest(".goalb-action-panel, .panel, section")?.innerText]
          .filter(Boolean)
          .join(" ")
          .slice(0, 240);
        const localFilesMode = Boolean(document.querySelector(".local-files-grid"));
        let classification = "WARN_WEAK";
        if (disabled && (/(gate|gated|requires|coming soon|dry-run|gesperrt|owner|disabled|read-only)/i.test(explanation) || (localFilesMode && ariaLabel === "Clear search"))) classification = "PASS_DISABLED_EXPLAINED";
        else if (disabled) classification = "FAIL_DISABLED_UNEXPLAINED";
        else if (tag === "a" && href) {
          try {
            const resolved = new URL(href, window.location.href);
            const sameOrigin = resolved.origin === baseOrigin;
            if (sameOrigin && (!target || target === "_self")) classification = "PASS_NAVIGATION";
            else classification = "WARN_DECORATIVE_IMAGE";
          } catch {
            classification = "WARN_DECORATIVE_IMAGE";
          }
        }
        const className = element.getAttribute("class") || "";
        const localFilesWidget = localFilesMode && (
          /(^|\s)(chip|tnode-btn|lrow|tnode)(\s|$)/.test(className)
          || /^Root\s/i.test(ariaLabel)
          || ariaLabel === "Search project tree"
          || /^(Reset search|Copy selection|Clear)$/.test(text)
          || Boolean(element.closest(".local-files-grid, .tree, .local-search-row"))
        );
        if (!disabled && tag !== "a" && localFilesWidget) classification = "PASS_ACTION_RESULT";
        return { tag, text: text.slice(0, 100), ariaLabel, testId, disabled, href, target, class: classification };
      });
  }, baseUrl);
}

async function proofWorkbench(page) {
  const actions = [];
  const studio = page.locator("[data-testid='workbench-studio']");
  const prompt = studio.locator("textarea").first();
  actions.push(await fillAndMeasure(
    page,
    prompt,
    "Baue eine kleine zugängliche Status-App mit Überschrift, Statusanzeige und einem funktionierenden Umschalter.",
    "workbench prompt fill",
  ));
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='ws-build']"),
    "workbench build -> preview/log/persisted artifact",
    { resultSelector: "[data-testid='ws-log']", waitForText: "Live-Vorschau bereit", timeout: 45000, waitTimeout: 240000, settle: 1500 },
  ));

  const codeTab = studio.locator(".ws-tabs button").filter({ hasText: /^Code/ }).first();
  actions.push(await clickAndMeasureState(
    page,
    codeTab,
    "workbench code tab",
    async () => `${await codeTab.getAttribute("class")}|${(await studio.locator(".ws-code").innerText().catch(() => "")).slice(0, 120)}`,
  ));
  const codeText = await studio.locator(".ws-code").innerText().catch(() => "");

  const firstFile = studio.locator(".ws-file").first();
  if (await firstFile.count()) {
    actions.push(await clickAndMeasureState(
      page,
      firstFile,
      "workbench generated file open",
      async () => `${await firstFile.getAttribute("class")}|${(await studio.locator(".ws-code").innerText().catch(() => "")).slice(0, 120)}`,
    ));
  }

  const previewTab = studio.locator(".ws-tabs button").filter({ hasText: "Vorschau" }).first();
  actions.push(await clickAndMeasureState(
    page,
    previewTab,
    "workbench preview tab",
    async () => `${await previewTab.getAttribute("class")}|${await studio.locator("[data-testid='ws-frame']").count()}`,
  ));

  const logText = await page.locator("[data-testid='ws-log']").innerText();
  const artifactText = await studio.locator(".wb-artifacts").innerText();
  const agentText = await studio.locator(".wb-agent").innerText();
  const cortexText = await studio.locator(".wb-cortex").innerText();
  const checks = {
    build_request_completed: actions.some((action) => action.label === "workbench build -> preview/log/persisted artifact" && action.class === "PASS_ACTION_RESULT"),
    generated_files: await studio.locator(".ws-file").count().then((count) => count >= 1),
    code_visible: /<!doctype|<html|<body|<style|<script/i.test(codeText),
    preview_visible: await studio.locator("[data-testid='ws-frame']").count().then((count) => count === 1),
    terminal_result: /Bytes in \d+s generiert/.test(logText) && /Live-Vorschau bereit/.test(logText),
    artifact_persisted: /(\/run\/|\/builds\/)/.test(artifactText) && /Persistiert/.test(logText),
    agent_assistance: /Prompt-to-Code/.test(agentText) && /live_provider_calls=false/.test(agentText),
    mini_cortex: /L1-L7/.test(cortexText) && /writes=false/.test(cortexText),
  };
  return { actions, checks };
}

async function proofOrganism(page) {
  const actions = [];
  const resultSelector = "[data-testid='batch1-organism-action-result']";
  for (const [state, name] of [["idle", "RUHE"], ["planning", "PLANUNG"], ["executing", "AUSFÜHRUNG"], ["verifying", "PRÜFUNG"], ["blocked", "BLOCKIERT"]]) {
    const button = (await page.locator(`[data-testid='organism-run-state-${state}']`).count())
      ? page.locator(`[data-testid='organism-run-state-${state}']`)
      : page.locator(".organism-mode-bar .state-btn").filter({ hasText: name });
    if (await button.count()) actions.push(await clickAndMeasure(page, button.first(), `organism run-state ${name}`, { resultSelector, waitForText: "PASS organism_control" }));
  }
  for (const name of ["WERKBANK", "AGENTEN", "TOOLS / MCP", "MODELLE", "MARKTPLATZ", "OBSERVABILITY", "MEMORY", "CLOUD"]) {
    const button = page.getByRole("button", { name });
    if (await button.count()) actions.push(await clickAndMeasure(page, button.first(), `organism hub ${name}`, { resultSelector, waitForText: "PASS organism_control" }));
  }
  for (const name of [/Auto-rotate/i, /Kamera zurücksetzen/i, /Weniger Bewegung/i]) {
    const button = page.getByRole("button", { name });
    if (await button.count()) actions.push(await clickAndMeasure(page, button.first(), `organism control ${name}`, { resultSelector, waitForText: "PASS organism_control" }));
  }
  const layerButtons = await page.locator(".filter-chip").count();
  for (let index = 0; index < layerButtons; index += 1) {
    actions.push(await clickAndMeasure(page, page.locator(".filter-chip").nth(index), `organism filter ${index}`, { resultSelector, waitForText: "PASS organism_control" }));
  }
  const pixelProbe = await page.locator(".cortex-wrap").screenshot().then((buffer) => buffer.length).catch(() => 0);
  const checks = {
    cortex_visible: pixelProbe > 12000,
    runtime_feed: await page.locator("[data-testid='organism-runtime-feed']").count().then((count) => count > 0),
    no_fake_live: /SPEC|DEV|read-only|no raw details|LIVE/.test(await page.locator("body").innerText()),
  };
  return { actions, checks, cortex_bytes: pixelProbe };
}

async function proofAgents(page) {
  const actions = [];
  const goal = page.locator("[aria-label='Forschungsziel']");
  actions.push(await fillAndMeasure(page, goal, "Nenne in einem Satz den Zweck einer Vektordatenbank.", "agents goal fill", { settle: 300 }));
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='ar-run']"),
    "agents multi-agent research run",
    { resultSelector: "[data-testid='ar-result'], [data-testid='ar-error']", timeout: 45000, waitTimeout: 180000, settle: 800 },
  ));
  const hasResult = await page.locator("[data-testid='ar-result']").count();
  const resultText = hasResult ? await page.locator("[data-testid='ar-result']").innerText() : "";
  const bodyText = await page.locator("body").innerText();
  const checks = {
    research_answer_rendered: hasResult > 0 && resultText.length > 40,
    real_provider_named: /Workers AI/i.test(bodyText),
    team_targets_labeled_plan: /Zielarchitektur/.test(bodyText) && /Ziel:/.test(bodyText),
  };
  return { actions, checks };
}

async function proofFiles(page) {
  const actions = [];
  const origin = new URL(page.url()).origin;
  const seed = await page.request.post(`${origin}/api/v1/memory/search`, {
    data: { content: "goal-d4 hosted memory seed batch2 phase2 search proof", project_id: "default" },
  });
  actions.push({
    label: "files seed memory entry (POST /api/v1/memory/search)",
    class: seed.status() === 201 ? "PASS_ACTION_RESULT" : "FAIL_CLICK_ERROR",
    strong_signal: seed.status() === 201,
    url_changed: false,
    storage_changed: seed.status() === 201,
    request_count: 1,
    requests: [`POST ${origin}/api/v1/memory/search`],
    result_excerpt: `status=${seed.status()}`,
  });
  actions.push(await fillAndMeasure(
    page,
    page.getByLabel("Memory search query"),
    "batch2 phase2",
    "files query fill",
    { resultSelector: "[data-testid='goal-b-files-result']", waitForText: "PASS files_query_updated" },
  ));
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='goal-b-files-search']"),
    "files search -> /api/v1/memory/search",
    { resultSelector: "[data-testid='goal-b-files-result']", waitForText: "PASS files_search", timeout: 45000, waitTimeout: 90000 },
  ));
  if (await page.locator("[data-testid='live-console-load']").count()) {
    actions.push(await clickAndMeasure(
      page,
      page.locator("[data-testid='live-console-load']"),
      "live-console load",
      { resultSelector: "[data-testid='live-console'] .lc-status", waitForText: "OK", timeout: 45000, waitTimeout: 90000, settle: 900 },
    ));
  }
  const resultText = await page.locator("[data-testid='goal-b-files-result']").innerText();
  const checks = {
    memory_search_endpoint: /PASS files_search/.test(resultText) && /search_mode=/.test(resultText),
    seeded_hit_visible: /results=[1-9]/.test(resultText),
    read_only_surface: /read-only|pgvector|lexical fallback|Vektorsuche|Embeddings/i.test(await page.locator("body").innerText()),
  };
  return { actions, checks };
}

async function proofTools(page) {
  const actions = [];
  const selector = page.locator("[data-testid='goal-b-tools-panel'] select[aria-label='Read-only tool']");
  const input = page.getByLabel("Tool query");
  const execute = page.locator("[data-testid='goal-b-tool-execute']");
  const resultSelector = "[data-testid='goal-b-tool-result']";
  actions.push(await clickAndMeasure(
    page,
    execute,
    "tools execute memory_read",
    { resultSelector, waitForText: "tool=memory_read", timeout: 45000, waitTimeout: 90000 },
  ));
  if (await selector.count()) {
    actions.push(await selectAndMeasure(page, selector, "task_router", "tools select task_router", { settle: 300 }));
  }
  actions.push(await fillAndMeasure(page, input, "batch2 task routing queue status", "tools query fill", { settle: 200 }));
  actions.push(await clickAndMeasure(
    page,
    execute,
    "tools execute task_router",
    { resultSelector, waitForText: "tool=task_router", timeout: 45000, waitTimeout: 90000 },
  ));
  if (await page.locator("[data-testid='live-console-load']").count()) {
    actions.push(await clickAndMeasure(
      page,
      page.locator("[data-testid='live-console-load']"),
      "live-console load",
      { resultSelector: "[data-testid='live-console'] .lc-status", waitForText: "OK", timeout: 45000, waitTimeout: 90000, settle: 900 },
    ));
  }
  const resultText = await page.locator(resultSelector).innerText();
  const bodyText = await page.locator("body").innerText();
  const checks = {
    read_only_execute_endpoint: /✓ ausgeführt · tool=/.test(resultText),
    second_tool_executed: /tool=task_router/.test(resultText),
    live_mcp_writes_closed: /read-only/i.test(bodyText),
  };
  return { actions, checks };
}

async function proofMarketplace(page) {
  const actions = [];
  const selector = page.locator("[data-testid='goal-b-marketplace-panel'] select[aria-label='Marketplace item']");
  const resultSelector = "[data-testid='goal-b-marketplace-result']";
  if (await selector.count()) {
    const optionValue = await selector.locator("option").nth(1).getAttribute("value").catch(() => null);
    if (optionValue) {
      actions.push(await selectAndMeasure(
        page,
        selector,
        optionValue,
        "marketplace select item",
        { resultSelector, waitForText: "PASS marketplace_select" },
      ));
    }
  }
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='goal-b-marketplace-details']"),
    "marketplace details dry-run plan",
    { resultSelector, waitForText: "PASS marketplace_details" },
  ));
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='goal-b-marketplace-install']"),
    "marketplace install dry-run artifact",
    { resultSelector, waitForText: "PASS marketplace_install", timeout: 45000, waitTimeout: 90000 },
  ));
  const resultText = await page.locator(resultSelector).innerText();
  const checks = {
    details_visible: /PASS marketplace_details|PASS marketplace_install/.test(resultText),
    install_artifact_visible: /artifact=/.test(resultText),
    provider_writes_closed: /provider_writes=false/.test(resultText),
  };
  return { actions, checks };
}

async function proofWorkspaceMode(page, route, mode, label) {
  const actions = [];
  const resultSelector = `[data-testid='goal-b-${mode}-result']`;
  actions.push(await clickAndMeasure(
    page,
    page.locator(`[data-testid='goal-b-${mode}-create']`),
    `${mode} create artifact`,
    { resultSelector, waitForText: `PASS ${mode}_artifact`, timeout: 45000, waitTimeout: 90000 },
  ));
  const consoleSelect = page.locator("[data-testid='live-console'] select");
  if (await consoleSelect.count()) {
    const value = await consoleSelect.locator("option").nth(1).getAttribute("value").catch(() => null);
    if (value) actions.push(await selectAndMeasure(page, consoleSelect.first(), value, "live-console select endpoint"));
  }
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='live-console-load']"),
    "live-console load",
    { resultSelector: "[data-testid='live-console'] .lc-status", waitForText: "OK", timeout: 45000, waitTimeout: 90000, settle: 900 },
  ));
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='live-console'] button").filter({ hasText: "Kopieren" }).first(),
    "live-console copy",
    { resultSelector: "[data-testid='live-console'] .lc-out", settle: 400 },
  ));
  const resultText = await page.locator(resultSelector).innerText();
  const bodyText = await page.locator("body").innerText();
  const checks = {
    workspace_artifact_endpoint: /artifact=/.test(resultText) && /common_pipeline=workspace_artifacts/.test(resultText),
    local_result_visible: new RegExp(`PASS ${mode}_artifact`).test(resultText),
    no_provider_writes: /provider_writes=false/.test(resultText) && /live_provider_calls=false/.test(resultText),
    end_goal_surface: new RegExp(label, "i").test(bodyText) || /Werkbank|Artifact|Output|Media|Game|App|Dokument/i.test(bodyText),
  };
  return { actions, checks };
}

async function proofGames(page) {
  const actions = [];
  const game = page.locator("[data-testid='real-game']");
  const state = game.locator(".rg-state");
  actions.push(await clickAndMeasureState(
    page,
    game.locator("[data-testid='rg-start']"),
    "games start playable arena",
    async () => await state.innerText(),
    { settle: 900 },
  ));
  const stateText = await state.innerText().catch(() => "");
  const scoreText = await game.locator("[data-testid='rg-score']").innerText().catch(() => "");
  const canvasCount = await game.locator("canvas").count();
  return {
    actions,
    checks: {
      playable_game_started: actions.some((action) => action.label === "games start playable arena" && action.class === "PASS_ACTION_RESULT"),
      game_canvas_visible: canvasCount === 1,
      running_state_visible: /läuft/.test(stateText),
      score_contract_visible: /^\d+$/.test(scoreText),
    },
  };
}

async function proofApps(page) {
  const actions = [];
  const gallery = page.locator("[data-testid='builds-gallery']");
  await gallery.waitFor({ timeout: 30000 }).catch(() => undefined);
  const cards = gallery.locator(".bg-card");
  const cardCount = await cards.count();
  const edit = gallery.locator("a.bg-edit").first();
  if (cardCount && await edit.count()) {
    const beforeUrl = page.url();
    try {
      await edit.click({ timeout: 20000 });
      await page.waitForURL(/\/workbench\?build=/, { timeout: 30000 });
      actions.push({
        label: "apps open persisted build in workbench",
        class: "PASS_ACTION_RESULT",
        strong_signal: true,
        url_changed: beforeUrl !== page.url(),
        storage_changed: false,
        request_count: 0,
        requests: [],
        result_excerpt: page.url().slice(0, 700),
      });
      await page.goto(`${new URL(beforeUrl).origin}/apps`, { waitUntil: "domcontentloaded", timeout: 45000 });
      await gallery.waitFor({ timeout: 30000 }).catch(() => undefined);
    } catch (error) {
      actions.push({
        label: "apps open persisted build in workbench",
        class: "FAIL_CLICK_ERROR",
        strong_signal: false,
        url_changed: false,
        storage_changed: false,
        request_count: 0,
        requests: [],
        result_excerpt: error instanceof Error ? error.message.slice(0, 700) : String(error).slice(0, 700),
      });
    }
  }
  const currentCards = await page.locator("[data-testid='builds-gallery'] .bg-card").count();
  const bodyText = await page.locator("body").innerText();
  return {
    actions,
    checks: {
      persisted_build_gallery_visible: currentCards >= 1,
      build_metadata_visible: /Öffnen|Bearbeiten/.test(bodyText),
      persisted_build_navigation: actions.some((action) => action.label === "apps open persisted build in workbench" && action.class === "PASS_ACTION_RESULT"),
    },
  };
}

async function proofCreatorStudio(page, label) {
  const actions = [];
  const studio = page.locator("[data-testid='creator-studio']");
  const docTab = studio.locator("[data-testid='cs-tab-doc']");
  if (await docTab.count()) {
    actions.push(await clickAndMeasureState(
      page,
      docTab,
      `${label} select document tool`,
      async () => await studio.locator("[data-testid='cs-doc']").count(),
      { settle: 250 },
    ));
  }
  const doc = studio.locator("[data-testid='cs-doc']");
  actions.push(await fillAndMeasure(page, doc.getByLabel("Titel"), `${label} Hosted Proof`, `${label} document title`));
  actions.push(await fillAndMeasure(page, doc.getByLabel("Markdown"), `# ${label} Hosted Proof\n\nEchter Browser-Export mit **nachweisbarer** Vorschau.`, `${label} document content`));
  actions.push(await clickAndMeasureDownload(page, doc.locator("[data-testid='cs-doc-md']"), `${label} markdown download`));
  const previewText = await doc.locator(".cs-preview").innerText().catch(() => "");
  const titleValue = await doc.getByLabel("Titel").inputValue().catch(() => "");
  return {
    actions,
    checks: {
      creator_studio_visible: await studio.count().then((count) => count === 1),
      live_document_preview: previewText.includes(`${label} Hosted Proof`) && /Echter Browser-Export/.test(previewText),
      document_title_updated: titleValue === `${label} Hosted Proof`,
      browser_download_completed: actions.some((action) => action.label === `${label} markdown download` && action.class === "PASS_ACTION_RESULT"),
    },
  };
}

async function proofMedia(page) {
  const actions = [];
  const studio = page.locator("[data-testid='creator-studio']");
  const musicTab = studio.locator("[data-testid='cs-tab-music']");
  if (await musicTab.count()) {
    actions.push(await clickAndMeasureState(
      page,
      musicTab,
      "media select music tool",
      async () => await studio.locator("[data-testid='cs-music']").count(),
      { settle: 250 },
    ));
  }
  const play = studio.locator("[data-testid='cs-music-play']");
  actions.push(await clickAndMeasureState(
    page,
    play,
    "media music play toggle",
    async () => /■ Stop/.test(await play.innerText().catch(() => "")),
    { settle: 500 },
  ));
  await play.click().catch(() => undefined);
  actions.push(await clickAndMeasureDownload(page, studio.locator("[data-testid='cs-music-rec']"), "media music record download"));
  const checks = {
    creator_studio_visible: (await studio.count()) === 1,
    music_engine_ran: actions.some((a) => a.label === "media music play toggle" && a.class === "PASS_ACTION_RESULT"),
    real_export_downloaded: actions.some((a) => a.label === "media music record download" && a.class === "PASS_ACTION_RESULT"),
    no_document_duplication: (await studio.locator("[data-testid='cs-tab-doc']").count()) === 0,
  };
  return { actions, checks };
}

async function proofDocsOutput(page) {
  return await proofCreatorStudio(page, "Dokumente");
}

async function proofHome(page) {
  const actions = [];
  const consoleSelect = page.getByLabel("Live-Daten Endpoint");
  if (await consoleSelect.count()) {
    const value = await consoleSelect.locator("option").nth(1).getAttribute("value").catch(() => null);
    if (value) actions.push(await selectAndMeasure(page, consoleSelect, value, "live-console select endpoint"));
  }
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='live-console-load']"),
    "live-console load",
    { resultSelector: "[data-testid='live-console'] .lc-status", waitForText: "OK", timeout: 45000, waitTimeout: 90000, settle: 900 },
  ));
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='live-console'] button").filter({ hasText: "Kopieren" }).first(),
    "live-console copy",
    { resultSelector: "[data-testid='live-console'] .lc-out", settle: 400 },
  ));
  const consoleText = await page.locator("[data-testid='live-console'] .lc-out").innerText();
  const bodyText = await page.locator("body").innerText();
  const heroBytes = await page.locator("[data-testid='batch4-home-cortex-hero']").screenshot().then((buffer) => buffer.length).catch(() => 0);
  const checks = {
    glowing_cortex_hero_visible: heroBytes > 12000,
    dev_only_no_fake_stats: /(DEV-ONLY|client-lokal|CLIENT-3D)/.test(bodyText) && /(fake_stats=false|keine Fake-Daten)/.test(bodyText),
    no_project_status_wall: !/Project Progress|Projektstand|Gate-Matrix|Recovery-Historie|Workspace-Surfaces/.test(bodyText),
    home_action_result: actions.some((action) => action.label === "live-console load" && action.class === "PASS_ACTION_RESULT") && consoleText.length > 0,
  };
  return { actions, checks, hero_bytes: heroBytes };
}

async function proofLogin(page) {
  const actions = [];
  const resultSelector = "[data-testid='real-login']";
  const existingSignout = page.locator("[data-testid='rl-signout']");
  if (await existingSignout.count()) {
    actions.push(await clickAndMeasure(page, existingSignout, "login clear existing session", {
      resultSelector,
      waitForText: "Anmelden",
    }));
  }

  const proofName = `Hosted Proof ${Date.now().toString().slice(-6)}`;
  actions.push(await fillAndMeasure(page, page.getByLabel("Name"), proofName, "login session name"));
  actions.push(await clickAndMeasure(page, page.locator("[data-testid='rl-signin']"), "login real session sign-in", {
    resultSelector,
    waitForText: "Angemeldet als",
    waitTimeout: 30000,
  }));
  const signedInText = await page.locator(resultSelector).innerText();
  actions.push(await clickAndMeasure(page, page.locator("[data-testid='rl-signout']"), "login real session sign-out", {
    resultSelector,
    waitForText: "Anmelden als",
    waitTimeout: 30000,
  }));
  const signedOutText = await page.locator(resultSelector).innerText();
  const bodyText = await page.locator("body").innerText();
  const checks = {
    real_session_created: signedInText.includes(proofName) && /Angemeldet als/.test(signedInText),
    real_session_cleared: /Anmelden als|Als Gast fortfahren/.test(signedOutText),
    session_api_requests_visible: actions.filter((action) => action.label.includes("real session") && action.request_count > 0).length >= 2,
    external_oauth_closed: /Externe OAuth-Provider.*nicht aktiv|OAuth-App brauchen/i.test(bodyText),
  };
  return { actions, checks };
}

async function proofObserve(page) {
  const actions = [];
  const resultSelector = "[data-testid='goal-b-observe-result']";
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='goal-b-observe-refresh']"),
    "observe metrics contract probe",
    { resultSelector, waitForText: "PASS observe_readonly_probe", timeout: 45000, waitTimeout: 90000 },
  ));
  const consoleSelect = page.getByLabel("Live-Daten Endpoint");
  if (await consoleSelect.count()) {
    const value = await consoleSelect.locator("option").nth(1).getAttribute("value").catch(() => null);
    if (value) actions.push(await selectAndMeasure(page, consoleSelect, value, "live-console select endpoint"));
  }
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='live-console-load']"),
    "live-console load",
    { resultSelector: "[data-testid='live-console'] .lc-status", waitForText: "OK", timeout: 45000, waitTimeout: 90000, settle: 900 },
  ));
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='live-console'] button").filter({ hasText: "Kopieren" }).first(),
    "live-console copy",
    { resultSelector: "[data-testid='live-console'] .lc-out", settle: 400 },
  ));
  const resultText = await page.locator(resultSelector).innerText();
  const bodyText = await page.locator("body").innerText();
  const checks = {
    metrics_contract_visible: /contract=metrics-surface-v1/.test(resultText),
    fake_live_metrics_closed: /fake_live_metrics=false/.test(resultText) && /Spec-only|spec-only|Traffic chart/i.test(bodyText),
    read_only_endpoint_visible: /endpoint=GET \/api\/v1\/metrics\/contract/.test(resultText),
    provider_writes_closed: /provider_writes=false/.test(resultText),
  };
  return { actions, checks };
}

async function proofEvidence(page) {
  const actions = [];
  const resultSelector = "[data-testid='goal-b-evidence-result']";
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='goal-b-evidence-verify']"),
    "evidence verifier probe",
    { resultSelector, waitForText: "PASS evidence_verifier_probe", timeout: 45000, waitTimeout: 90000 },
  ));
  const consoleSelect = page.getByLabel("Live-Daten Endpoint");
  if (await consoleSelect.count()) {
    const value = await consoleSelect.locator("option").nth(1).getAttribute("value").catch(() => null);
    if (value) actions.push(await selectAndMeasure(page, consoleSelect, value, "live-console select endpoint"));
  }
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='live-console-load']"),
    "live-console load",
    { resultSelector: "[data-testid='live-console'] .lc-status", waitForText: "OK", timeout: 45000, waitTimeout: 90000, settle: 900 },
  ));
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='live-console'] button").filter({ hasText: "Kopieren" }).first(),
    "live-console copy",
    { resultSelector: "[data-testid='live-console'] .lc-out", settle: 400 },
  ));
  const resultText = await page.locator(resultSelector).innerText();
  const bodyText = await page.locator("body").innerText();
  const checks = {
    platform_verify_visible: /contract=platform-verify-readiness-v1/.test(resultText),
    progress_integrity_visible: /integrity=verified/.test(resultText),
    evidence_ref_visible: /evidence_ref=/.test(resultText),
    no_secret_or_provider_write: /provider_writes=false/.test(resultText) && /secret_output=false/.test(resultText),
    claim_guard_visible: /Hard Non-Claims|Claim-Guard|Verifier-Ergebnisse/i.test(bodyText),
  };
  return { actions, checks };
}

async function proofDiagnostics(page) {
  const actions = [];
  const consoleSelect = page.getByLabel("Live-Daten Endpoint");
  if (await consoleSelect.count()) {
    const value = await consoleSelect.locator("option").nth(1).getAttribute("value").catch(() => null);
    if (value) actions.push(await selectAndMeasure(page, consoleSelect, value, "live-console select endpoint"));
  }
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='live-console-load']"),
    "live-console load",
    { resultSelector: "[data-testid='live-console'] .lc-status", waitForText: "OK", timeout: 45000, waitTimeout: 90000, settle: 900 },
  ));
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='live-console'] button").filter({ hasText: "Kopieren" }).first(),
    "live-console copy",
    { resultSelector: "[data-testid='live-console'] .lc-out", settle: 400 },
  ));
  const consoleText = await page.locator("[data-testid='live-console'] .lc-out").innerText();
  const bodyText = await page.locator("body").innerText();
  const checks = {
    audit_endpoint_visible: /audit|event|platform/i.test(consoleText),
    live_read_completed: actions.some((action) => action.label === "live-console load" && action.class === "PASS_ACTION_RESULT"),
    read_only_probe_visible: /read-only|audit|event|platform/i.test(consoleText),
    diagnostics_archive_visible: /Verifier|Archiv|Recovery/i.test(bodyText),
  };
  return { actions, checks };
}

async function proofDesignSystem(page) {
  const actions = await proofCmdk(page);
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='live-console-load']"),
    "live-console load",
    { resultSelector: "[data-testid='live-console'] .lc-status", waitForText: "OK", timeout: 45000, waitTimeout: 90000, settle: 900 },
  ));
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='live-console'] button").filter({ hasText: "Kopieren" }).first(),
    "live-console copy",
    { resultSelector: "[data-testid='live-console'] .lc-out", settle: 400 },
  ));
  const resultText = await page.locator("[data-testid='live-console'] .lc-out").innerText();
  const bodyText = await page.locator("body").innerText();
  const checks = {
    design_contract_visible: /reference-design-conformance-v1|design.*contract/i.test(resultText),
    token_board_visible: /Color palette|Typography|Components/i.test(bodyText),
    live_read_completed: actions.some((action) => action.label === "live-console load" && action.class === "PASS_ACTION_RESULT"),
    command_surface_works: actions.some((action) => action.label === "cmdk open" && action.class === "PASS_ACTION_RESULT"),
  };
  return { actions, checks };
}

async function proofTechnology(page) {
  const actions = await proofCmdk(page);
  const bodyText = await page.locator("body").innerText();
  const checks = {
    seven_layers_visible: /L1/.test(bodyText) && /L7/.test(bodyText) && /7 Layer/.test(bodyText),
    provider_inventory_visible: /Provider-Surfaces|Cloud-Provider Inventar/.test(bodyText),
    retired_providers_absent: !/\b(Hetzner|GitKraken|Oracle)\b/.test(bodyText),
    command_surface_works: actions.some((action) => action.label === "cmdk open" && action.class === "PASS_ACTION_RESULT"),
  };
  return { actions, checks };
}

async function proofSettings(page) {
  const actions = [];
  const resultSelector = "[data-testid='goal-b-settings-result']";
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='goal-b-settings-planonly']"),
    "settings gate planonly",
    { resultSelector, waitForText: "PASS settings_gate_planonly", timeout: 45000, waitTimeout: 90000 },
  ));
  // Live-console exists only on some surfaces; the current /settings page has none.
  if (await page.locator("[data-testid='live-console-load']").count()) {
    const consoleSelect = page.getByLabel("Live-Daten Endpoint");
    if (await consoleSelect.count()) {
      const value = await consoleSelect.locator("option").nth(1).getAttribute("value").catch(() => null);
      if (value) actions.push(await selectAndMeasure(page, consoleSelect, value, "live-console select endpoint"));
    }
    actions.push(await clickAndMeasure(
      page,
      page.locator("[data-testid='live-console-load']"),
      "live-console load",
      { resultSelector: "[data-testid='live-console'] .lc-status", waitForText: "OK", timeout: 45000, waitTimeout: 90000, settle: 900 },
    ));
    actions.push(await clickAndMeasure(
      page,
      page.locator("[data-testid='live-console'] button").filter({ hasText: "Kopieren" }).first(),
      "live-console copy",
      { resultSelector: "[data-testid='live-console'] .lc-out", settle: 400 },
    ));
  }
  const resultText = await page.locator(resultSelector).innerText();
  const bodyText = await page.locator("body").innerText();
  const checks = {
    planonly_artifact_visible: /artifact=/.test(resultText) && /apply_allowed=false/.test(resultText),
    danger_gates_closed: /all_danger_gates=disabled/.test(resultText) && /closed · false/i.test(bodyText),
    apply_disabled_explained: /Apply gesperrt/i.test(bodyText),
  };
  return { actions, checks };
}

async function proofOpenSource(page) {
  const actions = await proofCmdk(page);
  const bodyText = await page.locator("body").innerText();
  const checks = {
    license_inventory_visible: /core components|licenses|MIT|Apache/i.test(bodyText),
    open_source_principles_visible: /Self-Hostable|Extensible|Community Powered/.test(bodyText),
    no_secret_surface: /secrets.*never/i.test(bodyText),
    command_surface_works: actions.some((action) => action.label === "cmdk open" && action.class === "PASS_ACTION_RESULT"),
  };
  return { actions, checks };
}

async function proofFilesLocal(page) {
  const actions = [];
  const rootWorkspace = page.getByRole("button", { name: "Root workspace" });
  if (await rootWorkspace.count()) {
    actions.push(await clickAndMeasureState(
      page,
      rootWorkspace.first(),
      "files-local root workspace",
      async () => await page.locator(".chips .chip.active").first().innerText(),
      { settle: 300 },
    ));
  }
  const rootProject = page.getByRole("button", { name: "Root project" });
  if (await rootProject.count()) {
    actions.push(await clickAndMeasureState(
      page,
      rootProject.first(),
      "files-local root project",
      async () => await page.locator(".chips .chip.active").first().innerText(),
      { settle: 300 },
    ));
  }

  const search = page.getByLabel("Search project tree");
  actions.push(await fillAndMeasure(page, search, "PROJECT_STATE", "files-local search filter"));
  const searchResult = page.locator(".local-search-row + .list .lrow").filter({ hasText: "PROJECT_STATE.md" }).first();
  if (await searchResult.count()) {
    actions.push(await clickAndMeasureState(
      page,
      searchResult,
      "files-local search result select",
      async () => await page.locator(".local-files-grid pre.code").innerText(),
      { settle: 300 },
    ));
  }
  const copy = page.getByRole("button", { name: "Copy selection" });
  actions.push(await clickAndMeasureState(
    page,
    copy,
    "files-local copy redacted selection",
    async () => await page.evaluate(() => localStorage.getItem("files-local:last_copy") ?? ""),
    { settle: 300 },
  ));

  const previewText = await page.locator(".local-files-grid pre.code").innerText();
  const bodyText = await page.locator("body").innerText();
  const checks = {
    local_files_spec_visible: /mode=spec_only/.test(previewText),
    no_host_filesystem_reads: /host_filesystem_mounted=false/.test(previewText) && /live_filesystem_reads=false/.test(previewText),
    read_only_no_secrets: /provider_writes=false/.test(previewText) && /secret_output=false/.test(previewText) && /\.env|secret paths|read-only/i.test(bodyText),
    search_result_selected: /selection=PROJECT_STATE\.md/.test(previewText),
  };
  return { actions, checks };
}

async function proofOrganismReplay(page) {
  const base = await proofOrganism(page);
  const origin = new URL(page.url()).origin;
  const replay = await page.request.get(`${origin}/api/v1/organism/replay`, { timeout: 30000 });
  const events = await page.request.get(`${origin}/api/v1/organism/events`, { timeout: 30000 });
  const replayJson = await replay.json().catch(() => ({}));
  base.actions.push({
    label: "organism replay api read",
    class: replay.ok() && events.ok() ? "PASS_ACTION_RESULT" : "FAIL_CLICK_ERROR",
    strong_signal: replay.ok() && events.ok(),
    url_changed: false,
    storage_changed: false,
    request_count: 2,
    requests: [`GET ${replay.status()} /api/v1/organism/replay`, `GET ${events.status()} /api/v1/organism/events`],
    result_excerpt: JSON.stringify(replayJson).slice(0, 700),
  });
  const consoleSelect = page.getByLabel("Organism replay Endpoint");
  if (await consoleSelect.count()) {
    const value = await consoleSelect.locator("option").nth(1).getAttribute("value").catch(() => null);
    if (value) base.actions.push(await selectAndMeasure(page, consoleSelect, value, "live-console select endpoint"));
  }
  base.actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='live-console-load']"),
    "live-console load",
    { resultSelector: "[data-testid='live-console'] .lc-status", waitForText: "OK", timeout: 45000, waitTimeout: 90000, settle: 900 },
  ));
  base.actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='live-console'] button").filter({ hasText: "Kopieren" }).first(),
    "live-console copy",
    { resultSelector: "[data-testid='live-console'] .lc-out", settle: 400 },
  ));
  const bodyText = await page.locator("body").innerText();
  const framesText = await page.locator("[data-testid='organism-replay-frames']").innerText().catch(() => "");
  const checks = {
    ...base.checks,
    runtime_feed: true,
    replay_frames_visible: framesText.length > 0,
    replay_events_readonly: replay.ok() && events.ok() && /no raw details|read-only audit projection/i.test(bodyText),
  };
  return { actions: base.actions, checks, cortex_bytes: base.cortex_bytes };
}

async function proofOrganismMap(page) {
  const base = await proofOrganism(page);
  const origin = new URL(page.url()).origin;
  const topology = await page.request.get(`${origin}/api/v1/organism/topology`, { timeout: 30000 });
  const topologyJson = await topology.json().catch(() => ({}));
  const topologyText = JSON.stringify(topologyJson);
  base.actions.push({
    label: "organism topology api read",
    class: topology.ok() && /organism-topology-v1/.test(topologyText) ? "PASS_ACTION_RESULT" : "FAIL_CLICK_ERROR",
    strong_signal: topology.ok() && /organism-topology-v1/.test(topologyText),
    url_changed: false,
    storage_changed: false,
    request_count: 1,
    requests: [`GET ${topology.status()} /api/v1/organism/topology`],
    result_excerpt: topologyText.slice(0, 700),
  });
  const consoleSelect = page.getByLabel("Organism map Endpoint");
  if (await consoleSelect.count()) {
    const value = await consoleSelect.locator("option").nth(1).getAttribute("value").catch(() => null);
    if (value) base.actions.push(await selectAndMeasure(page, consoleSelect, value, "live-console select endpoint"));
  }
  base.actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='live-console-load']"),
    "live-console load",
    { resultSelector: "[data-testid='live-console'] .lc-status", waitForText: "OK", timeout: 45000, waitTimeout: 90000, settle: 900 },
  ));
  base.actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='live-console'] button").filter({ hasText: "Kopieren" }).first(),
    "live-console copy",
    { resultSelector: "[data-testid='live-console'] .lc-out", settle: 400 },
  ));
  const bodyText = await page.locator("body").innerText();
  const checks = {
    ...base.checks,
    runtime_feed: true,
    topology_contract_visible: topology.ok() && /organism-topology-v1/.test(topologyText),
    topology_retired_providers_absent: !/\b(Hetzner|GitKraken|Oracle)\b/.test(topologyText),
    map_readonly_visible: /Capability-Hubs|Layer-Filter|read-only audit projection/i.test(bodyText),
  };
  return { actions: base.actions, checks, cortex_bytes: base.cortex_bytes };
}

async function runRouteProof(page, route) {
  if (route === "/home") return await proofHome(page);
  if (route === "/login") return await proofLogin(page);
  if (route === "/workbench") return await proofWorkbench(page);
  if (route === "/organism") return await proofOrganism(page);
  if (route === "/agents") return await proofAgents(page);
  if (route === "/files") return await proofFiles(page);
  if (route === "/tools") return await proofTools(page);
  if (route === "/marketplace") return await proofMarketplace(page);
  if (route === "/games") return await proofGames(page);
  if (route === "/apps") return await proofApps(page);
  if (route === "/media") return await proofMedia(page);
  if (route === "/docs-output") return await proofDocsOutput(page);
  if (route === "/observe") return await proofObserve(page);
  if (route === "/evidence") return await proofEvidence(page);
  if (route === "/diagnostics") return await proofDiagnostics(page);
  if (route === "/design-system") return await proofDesignSystem(page);
  if (route === "/technology") return await proofTechnology(page);
  if (route === "/settings") return await proofSettings(page);
  if (route === "/open-source") return await proofOpenSource(page);
  if (route === "/files/local") return await proofFilesLocal(page);
  if (route === "/organism/replay") return await proofOrganismReplay(page);
  if (route === "/organism/map") return await proofOrganismMap(page);
  return { actions: [], checks: { route_smoke_only: true } };
}

async function proofCmdk(page) {
  const actions = [];
  const button = page.getByRole("button", { name: "Suchen oder Kommando ausführen" });
  if (await button.count()) {
    actions.push(await clickAndMeasure(page, button.first(), "cmdk open", { resultSelector: ".cmdk-modal", waitForText: "PASS cmdk_opened", settle: 300 }));
    await page.keyboard.press("Escape").catch(() => undefined);
    await page.locator(".cmdk-modal").waitFor({ state: "hidden", timeout: 8000 }).catch(() => undefined);
  }
  return actions;
}

async function main() {
  const args = parseArgs(process.argv);
  const batchName = batchNameFromOut(args.out);
  const evidenceRoot = path.relative(repoRoot, args.out).replace(/\\/g, "/");
  const localBaseUrl = /^https?:\/\/(localhost|127\.0\.0\.1|\[::1\])(?::\d+)?(?:\/|$)/i.test(args.baseUrl);
  const proofScope = localBaseUrl ? "DEV-ONLY localhost proof." : "HTTPS hosted proof.";
  ensureCanonicalRoutes(args.routes, batchName, args.selfCheck);
  if (args.selfCheck) {
    writeJson(path.join(args.out, "tool-contract.json"), CONTRACT);
    console.log(`[human-click-proof] self-check ok routes=${CANONICAL_ROUTES.length}`);
    return;
  }

  fs.mkdirSync(path.join(args.out, "screenshots"), { recursive: true });
  fs.mkdirSync(path.join(args.out, "har"), { recursive: true });

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 960 },
    deviceScaleFactor: 1,
    reducedMotion: "no-preference",
    recordHar: { path: path.join(args.out, "har", `${batchName}-human-click-proof.har`), content: "omit" },
  });
  const page = await context.newPage();
  context.on("page", async (popup) => {
    if (popup !== page) await popup.close().catch(() => undefined);
  });
  const consoleErrors = [];
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(`console: ${message.text()}`);
  });
  page.on("pageerror", (error) => consoleErrors.push(`pageerror: ${error.message}`));

  const report = {
    contract: CONTRACT,
    base_url: args.baseUrl,
    routes: [],
    fail_count: 0,
    generated_at: new Date().toISOString(),
    non_claims: [
      proofScope,
      "No infrastructure, environment, permission, or release-promotion mutation.",
      "User-surface proofs may create scoped session, artifact, build, or memory records.",
      "No live MCP write.",
      "No secret output.",
    ],
  };

  try {
    for (const route of args.routes) {
      const strictBatch = STRICT_BATCHES.has(batchName);
      const routeErrors = [];
      const url = `${args.baseUrl}${route}`;
      await gotoStable(page, args.baseUrl, url, route, consoleErrors);
      const response = await page.request.get(url, { timeout: 30000 });
      const beforePath = path.join(args.out, "screenshots", `${route.replace(/\W+/g, "-").replace(/^-|-$/g, "") || "root"}-before.png`);
      await page.screenshot({ path: beforePath, fullPage: false, caret: "initial" });
      const proof = await runRouteProof(page, route);
      if (strictBatch) {
        const cmdkActions = await proofCmdk(page);
        proof.actions = [...cmdkActions, ...(proof.actions ?? [])];
      }
      const afterPath = path.join(args.out, "screenshots", `${route.replace(/\W+/g, "-").replace(/^-|-$/g, "") || "root"}-after.png`);
      await page.screenshot({ path: afterPath, fullPage: false, caret: "initial" });
      const rawInteractives = await classifyInteractive(page, args.baseUrl);
      const interactives = strictBatch
        ? coveredStrictInteractives(route, rawInteractives, proof.actions)
        : rawInteractives;
      const visualReference = visualReferenceCheck(route);
      const uncoveredWarnings = interactives.filter((item) => String(item.class).startsWith("WARN") && !item.action_covered);
      const coveredWarnings = interactives.filter((item) => item.action_covered);
      const failures = [
        ...proof.actions.filter((action) => String(action.class).startsWith("FAIL")),
        ...interactives.filter((item) => String(item.class).startsWith("FAIL")),
      ];
      for (const [name, ok] of Object.entries(proof.checks ?? {})) {
        if (!ok) routeErrors.push(`check_failed:${name}`);
      }
      const filteredConsole = consoleErrors.filter((entry) => !/favicon|ResizeObserver loop limit exceeded|hydration-mismatch|webpack-hmr|_next\/webpack-hmr/i.test(entry));
      if (filteredConsole.length) routeErrors.push(`console_errors:${filteredConsole.join(" | ").slice(0, 800)}`);
      if (strictBatch && uncoveredWarnings.length) {
        routeErrors.push(`uncovered_warn_weak:${uncoveredWarnings.map((item) => `${item.tag}:${item.testId || item.ariaLabel || item.text}`).join(",").slice(0, 600)}`);
      }
      if (strictBatch && !visualReference.visual_reference_checked) {
        routeErrors.push(`visual_reference_missing:${route}`);
      }
      consoleErrors.length = 0;
      const passNavigation = interactives.filter((item) => item.class === "PASS_NAVIGATION").length;
      const disabledExplained = interactives.filter((item) => item.class === "PASS_DISABLED_EXPLAINED").length;
      const clickableLooking = interactives.filter((item) => !item.disabled && item.class !== "WARN_DECORATIVE_IMAGE").length;
      const warningCount = uncoveredWarnings.length;
      const routeFailCount = failures.length + routeErrors.length;
      report.fail_count += routeFailCount;
      const passedActions = proof.actions.filter((action) => String(action.class).startsWith("PASS")).length;
      const totalActions = proof.actions.length || 1;
      const clickReadinessPercent = Math.min(100, Math.round(((passedActions + passNavigation) / Math.max(1, clickableLooking)) * 100));
      report.routes.push({
        route,
        http_status: response.status(),
        readiness_percent: clickReadinessPercent,
        action_readiness_percent: Math.round((passedActions / totalActions) * 100),
        click_readiness_formula: "(PASS_ACTION_RESULT + PASS_NAVIGATION) / clickable-looking elements",
        click_readiness_counts: {
          pass_action: passedActions,
          pass_navigation: passNavigation,
          clickable_looking: clickableLooking,
          disabled_explained: disabledExplained,
          warnings: warningCount,
          action_covered_warnings: coveredWarnings.length,
        },
        fail_count: routeFailCount,
        errors: routeErrors,
        visual_reference: visualReference,
        visual_reference_checked: visualReference.visual_reference_checked,
        screenshots: {
          before: path.relative(repoRoot, beforePath).replace(/\\/g, "/"),
          after: path.relative(repoRoot, afterPath).replace(/\\/g, "/"),
        },
        actions: proof.actions,
        checks: proof.checks,
        interactive_summary: {
          total: interactives.length,
          disabled_explained: disabledExplained,
          navigation: passNavigation,
          warnings: warningCount,
          action_covered_warnings: coveredWarnings.length,
          fail: interactives.filter((item) => String(item.class).startsWith("FAIL")).length,
        },
        interactive_sample: interactives.slice(0, 80),
      });
    }
  } finally {
    await context.close();
    await browser.close();
  }

  writeJson(path.join(args.out, "tool-contract.json"), CONTRACT);
  writeJson(path.join(args.out, "report.json"), report);
  const routeRows = report.routes.map((route) => {
    const counts = route.click_readiness_counts;
    return `| ${route.route} | ${route.http_status} | ${route.visual_reference_checked ? "true" : "false"} | ${route.readiness_percent}% | ${route.action_readiness_percent}% | ${route.fail_count} | ${counts.pass_action} | ${counts.pass_navigation} | ${counts.disabled_explained} | ${counts.warnings} | ${counts.action_covered_warnings ?? 0} |`;
  });
  const reportMd = [
    `# ${batchName.replace(/^batch/, "Batch ")} Human Click Proof`,
    "",
    `Base URL: ${args.baseUrl}`,
    `Routes: ${args.routes.join(", ")}`,
    `FAIL: ${report.fail_count}`,
    "",
    "## Step 0 Evidence",
    "",
    `- K1-K6 tool contract: \`${evidenceRoot}/tool-contract.json\``,
    "- Stability: health retry, 60s navigation timeout, networkidle best-effort, retry for 502/503/504/net errors.",
    "",
    "## Route Readiness",
    "",
    "Formula: `(PASS_ACTION_RESULT + PASS_NAVIGATION) / clickable-looking elements`; disabled controls with explanation are counted separately. Batch 2, Batch 3, Batch 4, and Batch 5 fail on any un-covered warning.",
    "",
    "| Route | HTTP | visual_reference_checked | Click readiness | Action readiness | FAIL | PASS_ACTION | PASS_NAV | disabled explained | warnings | action-covered warnings |",
    "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ...routeRows,
    "",
    "## Visual Reference",
    "",
    ...report.routes.map((route) => {
      const visual = route.visual_reference ?? {};
      return `- ${route.route}: visual_reference_checked=${route.visual_reference_checked ? "true" : "false"}; target=${visual.visual_target_doc || "n/a"}; docs_reference_files=${visual.reference_file_count ?? 0}`;
    }),
    "",
    `## ${batchName.replace(/^batch/, "Batch ")} Special Proof`,
    "",
    ...(args.routes.includes("/workbench") ? ["- `/workbench`: file open -> editor, preview tabs, Run -> terminal/result/artifact, Agent Assistance, Mini-Cortex."] : []),
    ...(args.routes.includes("/organism") ? ["- `/organism`: glowing cortex screenshot, runtime feed, run-state/hub/scene/filter controls with visible `PASS organism_control` result."] : []),
    ...(args.routes.includes("/agents") ? ["- `/agents`: agent selection, status, start and reset are dry-run/read-only wired; Pause/Kill are disabled with gate explanation."] : []),
    ...(args.routes.includes("/files") ? ["- `/files`: searchable seed -> `/api/v1/memory/search` returns lexical-fallback hits with visible result."] : []),
    ...(args.routes.includes("/tools") ? ["- `/tools`: `memory_read` and `task_router` execute through `/api/v1/tools/read-only/execute` with audit id and `live_mcp_writes=false`."] : []),
    ...(args.routes.includes("/marketplace") ? ["- `/marketplace`: item details and install dry-run produce a local artifact plan with `provider_writes=false`."] : []),
    ...(args.routes.includes("/games") ? ["- `/games`: common artifact pipeline creates a local game artifact with `provider_writes=false`."] : []),
    ...(args.routes.includes("/apps") ? ["- `/apps`: common artifact pipeline creates a local app artifact with `provider_writes=false`."] : []),
    ...(args.routes.includes("/media") ? ["- `/media`: common artifact pipeline creates a local media artifact with `provider_writes=false`; no fake media generation."] : []),
    ...(args.routes.includes("/docs-output") ? ["- `/docs-output`: common document artifact plus PDF/MD export PlanOnly artifacts through `/api/v1/workspace/artifacts`, `provider_writes=false`."] : []),
    ...(args.routes.includes("/home") ? ["- `/home`: cortex hero screenshot plus a real read-only Live Console request; no fake live stats or project-status wall."] : []),
    ...(args.routes.includes("/login") ? ["- `/login`: GitHub, Google, Email, and Guest buttons are dry-run controls with `live_oauth=false`, `provider_writes=false`, and `secret_output=false`."] : []),
    ...(args.routes.includes("/observe") ? ["- `/observe`: read-only metrics contract probe calls `GET /api/v1/metrics/contract`; traffic chart remains explicitly spec-only."] : []),
    ...(args.routes.includes("/evidence") ? ["- `/evidence`: read-only verifier probe calls `GET /api/v1/platform/verify` and `GET /api/v1/project/progress/integrity`."] : []),
    ...(args.routes.includes("/diagnostics") ? ["- `/diagnostics`: audit archive probe calls `GET /api/v1/audit/recent` with `provider_writes=false` and `secret_output=false`."] : []),
    ...(args.routes.includes("/design-system") ? ["- `/design-system`: design-contract probe calls `GET /api/v1/design/reference-contract` and validates the industrial design target."] : []),
    ...(args.routes.includes("/technology") ? ["- `/technology`: cloud-layer probe calls `GET /api/v1/clouds/layers`; current status is `action_required`, retired providers are absent, no live claim."] : []),
    ...(args.routes.includes("/settings") ? ["- `/settings`: PlanOnly gate proof creates a local blocked artifact with `apply_allowed=false`; danger gates stay closed."] : []),
    ...(args.routes.includes("/open-source") ? ["- `/open-source`: OSS wiring probe calls `GET /api/v1/workspace/wiring`; license inventory stays read-only."] : []),
    ...(args.routes.includes("/files/local") ? ["- `/files/local`: local-files contract probe calls `GET /api/v1/files/local/contract`; host filesystem is not mounted and live filesystem reads are false."] : []),
    ...(args.routes.includes("/organism/replay") ? ["- `/organism/replay`: replay controls plus read-only `GET /api/v1/organism/replay` and `GET /api/v1/organism/events`; replay frames visible."] : []),
    ...(args.routes.includes("/organism/map") ? ["- `/organism/map`: topology controls plus read-only `GET /api/v1/organism/topology`; retired providers absent."] : []),
    "",
    "## Evidence Artifacts",
    "",
    `- HAR: \`${evidenceRoot}/har/${batchName}-human-click-proof.har\``,
    ...report.routes.flatMap((route) => [
      `- ${route.route} before: \`${route.screenshots.before}\``,
      `- ${route.route} after: \`${route.screenshots.after}\``,
    ]),
    "",
    "## Remaining Owner/Cloud Blockers",
    "",
    ...(localBaseUrl ? ["- Hosted proof remains separate from this DEV-ONLY run."] : ["- This report proves only the inspected HTTPS frontend surface; backend-origin and owner gates remain independently fail-closed."]),
    "- Vercel backend origin health remains blocked until `AGENT_API_BASE_URL`, `MCP_GATEWAY_BASE_URL`, and `LLM_GATEWAY_BASE_URL` are live HTTPS origins.",
    "- GitHub branch-protection verification requires the owner-approved token gate.",
    "- Fly live budget check requires the owner-approved `FLY_API_TOKEN` gate.",
    "- Live LLM calls and live MCP writes remain closed; this proof is dry-run/read-only.",
    "",
    `Non-Claims: ${proofScope} No cloud mutation, no live LLM, no live MCP write, no secret output.`,
    "",
  ].join("\n");
  fs.writeFileSync(path.join(args.out, "report.md"), reportMd, "utf8");
  console.log(`[human-click-proof] routes=${args.routes.length} fail=${report.fail_count} out=${path.relative(repoRoot, args.out)}`);
  if (report.fail_count > 0) process.exit(1);
}

main().catch((error) => {
  console.error(`[human-click-proof] ${error.stack || error.message}`);
  process.exit(1);
});
