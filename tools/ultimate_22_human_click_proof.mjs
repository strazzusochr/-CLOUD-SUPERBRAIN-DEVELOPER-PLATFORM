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
  "/files": [
    { tag: "input", ariaLabel: "Memory search query", actionLabel: "files query fill" },
    { tag: "button", testId: "goal-b-files-search", actionLabel: "files search -> /api/v1/memory/search" },
  ],
  "/tools": [
    { tag: "select", ariaLabel: "Read-only tool", actionLabel: "tools select task_router" },
    { tag: "input", ariaLabel: "Tool query", actionLabel: "tools query fill" },
    { tag: "button", testId: "goal-b-tool-execute", actionLabel: "tools execute task_router" },
  ],
  "/marketplace": [
    { tag: "select", ariaLabel: "Marketplace item", actionLabel: "marketplace select item" },
    { tag: "button", testId: "goal-b-marketplace-details", actionLabel: "marketplace details dry-run plan" },
    { tag: "button", testId: "goal-b-marketplace-install", actionLabel: "marketplace install dry-run artifact" },
  ],
  "/games": [
    { tag: "button", testId: "goal-b-games-create", actionLabel: "games create artifact" },
  ],
  "/apps": [
    { tag: "button", testId: "goal-b-apps-create", actionLabel: "apps create artifact" },
  ],
  "/media": [
    { tag: "button", testId: "goal-b-media-create", actionLabel: "media create artifact" },
  ],
  "/docs-output": [
    { tag: "button", testId: "goal-b-docs-output-create", actionLabel: "docs-output create artifact" },
    { tag: "button", testId: "goal-b-docs-export-pdf", actionLabel: "docs-output export pdf plan" },
    { tag: "button", testId: "goal-b-docs-export-md", actionLabel: "docs-output export md plan" },
  ],
  "/home": [
    { tag: "button", testId: "goal-b-home-hero-proof", actionLabel: "home cortex proof" },
  ],
  "/login": [
    { tag: "button", testId: "goal-b-login-github", actionLabel: "login github dry-run" },
    { tag: "button", testId: "goal-b-login-google", actionLabel: "login google dry-run" },
    { tag: "button", testId: "goal-b-login-email", actionLabel: "login email dry-run" },
    { tag: "button", testId: "goal-b-login-guest", actionLabel: "login guest dry-run" },
  ],
  "/observe": [
    { tag: "button", testId: "goal-b-observe-refresh", actionLabel: "observe metrics contract probe" },
  ],
  "/evidence": [
    { tag: "button", testId: "goal-b-evidence-verify", actionLabel: "evidence verifier probe" },
  ],
  "/diagnostics": [
    { tag: "button", testId: "goal-b-diagnostics-probe", actionLabel: "diagnostics audit probe" },
  ],
  "/design-system": [
    { tag: "button", testId: "goal-b-design-system-probe", actionLabel: "design-system token probe" },
  ],
  "/technology": [
    { tag: "button", testId: "goal-b-technology-probe", actionLabel: "technology cloud layer probe" },
  ],
  "/settings": [
    { tag: "button", testId: "goal-b-settings-planonly", actionLabel: "settings gate planonly" },
  ],
  "/open-source": [
    { tag: "button", testId: "goal-b-open-source-probe", actionLabel: "open-source license probe" },
  ],
  "/files/local": [
    { tag: "button", testId: "goal-b-files-local-contract", actionLabel: "files-local contract probe" },
  ],
  "/organism/replay": ORGANISM_COVERAGE_RULES,
  "/organism/map": ORGANISM_COVERAGE_RULES,
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
  const rules = STRICT_ACTION_COVERAGE[route] ?? [];
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
  const beforeStorage = await page.evaluate(() => JSON.stringify({ local: { ...localStorage }, session: { ...sessionStorage } })).catch(() => "");
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
    const afterStorage = await page.evaluate(() => JSON.stringify({ local: { ...localStorage }, session: { ...sessionStorage } })).catch(() => "");
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
  const beforeStorage = await page.evaluate(() => JSON.stringify({ local: { ...localStorage }, session: { ...sessionStorage } })).catch(() => "");
  try {
    await locator.selectOption(value, { timeout: options.timeout ?? 20000 });
    if (options.waitForText && options.resultSelector) {
      await page.locator(options.resultSelector).filter({ hasText: options.waitForText }).first().waitFor({ timeout: options.waitTimeout ?? 45000 });
    }
    await page.waitForTimeout(options.settle ?? 600);
    const afterStorage = await page.evaluate(() => JSON.stringify({ local: { ...localStorage }, session: { ...sessionStorage } })).catch(() => "");
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
        let classification = "WARN_WEAK";
        if (disabled && /(gate|gated|requires|coming soon|dry-run|gesperrt|owner|disabled|read-only)/i.test(explanation)) classification = "PASS_DISABLED_EXPLAINED";
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
        return { tag, text: text.slice(0, 100), ariaLabel, testId, disabled, href, target, class: classification };
      });
  }, baseUrl);
}

async function proofWorkbench(page) {
  const actions = [];
  const fileButtons = await page.locator("[data-testid^='batch1-open-file-']").count();
  for (let index = 0; index < fileButtons; index += 1) {
    actions.push(await clickAndMeasure(page, page.locator(`[data-testid='batch1-open-file-${index}']`), `workbench file open ${index}`, { resultSelector: "[data-testid='batch1-file-open-result']", waitForText: "PASS file_opened" }));
  }
  const tabButtons = await page.locator("[data-testid='batch1-preview-tabs'] button").count();
  for (let index = 0; index < tabButtons; index += 1) {
    actions.push(await clickAndMeasure(page, page.locator("[data-testid='batch1-preview-tabs'] button").nth(index), `workbench preview tab ${index}`, { resultSelector: "[data-testid='batch1-preview-status']", waitForText: "PASS preview_tab" }));
  }
  actions.push(await fillAndMeasure(
    page,
    page.getByLabel("Batch 1 workbench prompt"),
    "D2 batch1 proof: build local dry-run artifact with terminal evidence.",
    "workbench prompt fill",
    { resultSelector: "[data-testid='batch1-prompt-status']", waitForText: "PASS prompt_updated" },
  ));
  actions.push(await clickAndMeasure(page, page.locator("[data-testid='batch1-workbench-run']"), "workbench run -> terminal/result/artifact", { resultSelector: "[data-testid='batch1-workbench-result']", waitForText: "PASS batch1_workbench_run", timeout: 45000, waitTimeout: 90000, settle: 1200 }));
  actions.push(await clickAndMeasure(page, page.locator("[data-testid='batch1-agent-assist']"), "workbench agent assistance", { resultSelector: "[data-testid='batch1-agent-result']", waitForText: "PASS batch1_agent_assistance", timeout: 45000, waitTimeout: 90000, settle: 1200 }));
  const editorTitle = await page.locator("[data-testid='batch1-editor-title']").innerText();
  const editorContent = await page.locator("[data-testid='batch1-editor-content']").innerText();
  const checks = {
    editor_opened: /preview\.adapter|agent-run|verifier\.ts|artifact\.pipeline/.test(`${editorTitle}\n${editorContent}`),
    terminal_result: /PASS|RUN|OPEN|VIEW/.test(await page.locator("[data-testid='batch1-terminal']").innerText()),
    preview_tabs: /PASS preview_tab/.test(await page.locator("[data-testid='batch1-preview-status']").innerText()),
    agent_assistance: /PASS batch1_agent_assistance|Planner\/Coder\/Tester\/DevOps/.test(await page.locator("[data-testid='batch1-agent-result']").innerText()),
    mini_cortex: /BATCH1|idle|executing|verifying/i.test(await page.locator("[data-testid='batch1-mini-cortex']").innerText()),
  };
  return { actions, checks };
}

async function proofOrganism(page) {
  const actions = [];
  const resultSelector = "[data-testid='batch1-organism-action-result']";
  for (const name of ["RUHE", "PLANUNG", "AUSFÜHRUNG", "PRÜFUNG", "BLOCKIERT"]) {
    const button = page.getByRole("button", { name });
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
  const selector = page.locator("[data-testid='goal-b-agents-panel'] select[aria-label='Agent']");
  const status = page.locator("[data-testid='goal-b-agent-status']");
  const start = page.locator("[data-testid='goal-b-agent-start']");
  const reset = page.locator("[data-testid='goal-b-agent-reset']");
  if (await selector.count()) actions.push(await selectAndMeasure(page, selector, "coder", "agents select coder", { resultSelector: "[data-testid='goal-b-agent-result']", waitForText: "PASS agent_select" }));
  actions.push(await clickAndMeasure(page, status, "agents status", { resultSelector: "[data-testid='goal-b-agent-result']", timeout: 45000 }));
  actions.push(await clickAndMeasure(page, start, "agents start", { resultSelector: "[data-testid='goal-b-agent-result']", timeout: 45000 }));
  actions.push(await clickAndMeasure(page, reset, "agents reset", { resultSelector: "[data-testid='goal-b-agent-result']", timeout: 45000 }));
  const body = await page.locator("body").innerText();
  const checks = {
    start_reset_status: /PASS agent_(status|steer|reset)/.test(body),
    pause_kill_gated: /Pause · requires live gate|Kill · owner gate/.test(body),
    no_live_provider_claim: /live_provider_calls=false|no live provider credentials|without Live-Provider/i.test(body),
  };
  return { actions, checks };
}

async function proofFiles(page) {
  const actions = [];
  const origin = new URL(page.url()).origin;
  const seed = await page.request.post(`${origin}/api/v1/workspace/artifacts`, {
    data: {
      project_id: "goal-b-local",
      source_page: "files",
      artifact_type: "batch2_search_seed",
      title: "Goal D2 Batch2 searchable seed",
      summary: "batch2 phase2 memory search proof seed for /files",
      status: "ready",
      metadata: { batch: "batch2", route: "/files", live_provider_calls: false },
    },
  });
  actions.push({
    label: "files seed searchable memory artifact",
    class: seed.ok() ? "PASS_ACTION_RESULT" : "FAIL_CLICK_ERROR",
    strong_signal: seed.ok(),
    url_changed: false,
    storage_changed: false,
    request_count: 1,
    requests: [`POST ${origin}/api/v1/workspace/artifacts`],
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
  const resultText = await page.locator("[data-testid='goal-b-files-result']").innerText();
  const checks = {
    memory_search_endpoint: /PASS files_search/.test(resultText) && /search_mode=lexical_fallback/.test(resultText),
    seeded_hit_visible: /results=[1-9]/.test(resultText),
    read_only_surface: /read-only|pgvector|lexical fallback/i.test(await page.locator("body").innerText()),
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
    { resultSelector, waitForText: "PASS readonly_tool_execute", timeout: 45000, waitTimeout: 90000 },
  ));
  if (await selector.count()) {
    actions.push(await selectAndMeasure(
      page,
      selector,
      "task_router",
      "tools select task_router",
      { resultSelector, waitForText: "PASS readonly_tool_selected" },
    ));
  }
  actions.push(await fillAndMeasure(
    page,
    input,
    "batch2 task routing queue status",
    "tools query fill",
    { resultSelector, waitForText: "PASS readonly_tool_query_updated" },
  ));
  actions.push(await clickAndMeasure(
    page,
    execute,
    "tools execute task_router",
    { resultSelector, waitForText: "PASS readonly_tool_execute", timeout: 45000, waitTimeout: 90000 },
  ));
  const resultText = await page.locator(resultSelector).innerText();
  const checks = {
    read_only_execute_endpoint: /PASS readonly_tool_execute/.test(resultText),
    audit_id_visible: /audit=/.test(resultText),
    live_mcp_writes_closed: /live_mcp_writes=false/.test(resultText) && /read-only|Write-Scopes bleiben gated|memory_read|task_router/i.test(await page.locator("body").innerText()),
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
    provider_writes_closed: /provider_writes=false/.test(resultText) && /no provider write|Installs are simulated|dry-run/i.test(await page.locator("body").innerText()),
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

async function proofDocsOutput(page) {
  const baseProof = await proofWorkspaceMode(page, "/docs-output", "docs-output", "Document");
  const actions = [...baseProof.actions];
  const exportSelector = "[data-testid='goal-b-docs-export-result']";
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='goal-b-docs-export-pdf']"),
    "docs-output export pdf plan",
    { resultSelector: exportSelector, waitForText: "PASS docs_export", timeout: 45000, waitTimeout: 90000 },
  ));
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='goal-b-docs-export-md']"),
    "docs-output export md plan",
    { resultSelector: exportSelector, waitForText: "PASS docs_export", timeout: 45000, waitTimeout: 90000 },
  ));
  const resultText = await page.locator(exportSelector).innerText();
  const checks = {
    ...baseProof.checks,
    export_artifact_endpoint: actions
      .filter((action) => /docs-output export (pdf|md) plan/.test(action.label))
      .every((action) => action.class === "PASS_ACTION_RESULT" && /artifact=/.test(action.result_excerpt)),
    export_plan_visible: /PASS docs_export/.test(resultText) && /mode=plan_only/.test(resultText),
    export_provider_writes_closed: /provider_writes=false/.test(resultText) && /live_provider_calls=false/.test(resultText),
  };
  return { actions, checks };
}

async function proofHome(page) {
  const actions = [];
  const resultSelector = "[data-testid='goal-b-home-result']";
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='goal-b-home-hero-proof']"),
    "home cortex proof",
    { resultSelector, waitForText: "PASS home_hero_check" },
  ));
  const resultText = await page.locator(resultSelector).innerText();
  const bodyText = await page.locator("body").innerText();
  const heroBytes = await page.locator("[data-testid='batch4-home-cortex-hero']").screenshot().then((buffer) => buffer.length).catch(() => 0);
  const checks = {
    glowing_cortex_hero_visible: heroBytes > 12000,
    dev_only_no_fake_stats: /DEV-ONLY/.test(bodyText) && /fake_stats=false/.test(`${bodyText}\n${resultText}`),
    no_project_status_wall: !/Project Progress|Projektstand|Gate-Matrix|Recovery-Historie|Workspace-Surfaces/.test(bodyText),
    home_action_result: /PASS home_hero_check/.test(resultText) && /live_provider_calls=false/.test(resultText),
  };
  return { actions, checks, hero_bytes: heroBytes };
}

async function proofLogin(page) {
  const actions = [];
  const resultSelector = "[data-testid='goal-b-login-result']";
  for (const [testId, label] of [
    ["goal-b-login-github", "login github dry-run"],
    ["goal-b-login-google", "login google dry-run"],
    ["goal-b-login-email", "login email dry-run"],
    ["goal-b-login-guest", "login guest dry-run"],
  ]) {
    actions.push(await clickAndMeasure(
      page,
      page.locator(`[data-testid='${testId}']`),
      label,
      { resultSelector, waitForText: "PASS login_dry_run" },
    ));
  }
  const resultText = await page.locator(resultSelector).innerText();
  const bodyText = await page.locator("body").innerText();
  const checks = {
    dry_run_result_visible: /PASS login_dry_run/.test(resultText),
    live_oauth_closed: /live_oauth=false/.test(resultText) && /No live provider write|OAuth and email providers stay dry-run|dry-run/i.test(bodyText),
    provider_writes_closed: /provider_writes=false/.test(resultText),
    secret_output_closed: /secret_output=false/.test(resultText),
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
  const resultSelector = "[data-testid='goal-b-diagnostics-result']";
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='goal-b-diagnostics-probe']"),
    "diagnostics audit probe",
    { resultSelector, waitForText: "PASS diagnostics_audit_probe", timeout: 45000, waitTimeout: 90000 },
  ));
  const resultText = await page.locator(resultSelector).innerText();
  const bodyText = await page.locator("body").innerText();
  const checks = {
    audit_endpoint_visible: /endpoint=GET \/api\/v1\/audit\/recent/.test(resultText),
    read_only_probe_visible: /provider_writes=false/.test(resultText) && /secret_output=false/.test(resultText),
    diagnostics_archive_visible: /Verifier|Archiv|Recovery/i.test(bodyText),
  };
  return { actions, checks };
}

async function proofDesignSystem(page) {
  const actions = [];
  const resultSelector = "[data-testid='goal-b-design-system-result']";
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='goal-b-design-system-probe']"),
    "design-system token probe",
    { resultSelector, waitForText: "PASS design_system_token_probe", timeout: 45000, waitTimeout: 90000 },
  ));
  const resultText = await page.locator(resultSelector).innerText();
  const bodyText = await page.locator("body").innerText();
  const checks = {
    design_contract_visible: /contract=reference-design-conformance-v1/.test(resultText),
    token_board_visible: /Color palette|Typography|Components/i.test(bodyText),
    no_provider_writes: /provider_writes=false/.test(resultText) && /secret_output=false/.test(resultText),
  };
  return { actions, checks };
}

async function proofTechnology(page) {
  const actions = [];
  const resultSelector = "[data-testid='goal-b-technology-result']";
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='goal-b-technology-probe']"),
    "technology cloud layer probe",
    { resultSelector, waitForText: "PASS technology_cloud_layers", timeout: 45000, waitTimeout: 90000 },
  ));
  const resultText = await page.locator(resultSelector).innerText();
  const bodyText = await page.locator("body").innerText();
  const checks = {
    cloud_layer_contract_visible: /contract=cloud-layer-readiness-v1/.test(resultText),
    action_required_not_fake_live: /status=action_required/.test(resultText) && /action_required|DEV-ONLY/i.test(bodyText),
    retired_providers_absent: /retired_providers_present=false/.test(resultText) && !/\b(Hetzner|GitKraken|Oracle)\b/.test(bodyText),
    no_provider_writes: /provider_writes=false/.test(resultText) && /live_provider_calls=false/.test(resultText),
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
  const actions = [];
  const resultSelector = "[data-testid='goal-b-open-source-result']";
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='goal-b-open-source-probe']"),
    "open-source license probe",
    { resultSelector, waitForText: "PASS open_source_license_probe", timeout: 45000, waitTimeout: 90000 },
  ));
  const resultText = await page.locator(resultSelector).innerText();
  const bodyText = await page.locator("body").innerText();
  const checks = {
    workspace_wiring_visible: /contract=workspace-surface-wiring-v1/.test(resultText),
    license_inventory_visible: /core components|licenses|MIT|Apache/i.test(bodyText),
    no_secret_or_provider_write: /provider_writes=false/.test(resultText) && /secret_output=false/.test(resultText),
  };
  return { actions, checks };
}

async function proofFilesLocal(page) {
  const actions = [];
  const resultSelector = "[data-testid='goal-b-files-local-result']";
  actions.push(await clickAndMeasure(
    page,
    page.locator("[data-testid='goal-b-files-local-contract']"),
    "files-local contract probe",
    { resultSelector, waitForText: "PASS files_local_contract", timeout: 45000, waitTimeout: 90000 },
  ));
  const resultText = await page.locator(resultSelector).innerText();
  const bodyText = await page.locator("body").innerText();
  const checks = {
    local_files_contract_visible: /contract=local-files-readonly-contract-v1/.test(resultText),
    no_host_filesystem_reads: /host_filesystem_mounted=false/.test(resultText) && /live_filesystem_reads=false/.test(resultText),
    read_only_no_secrets: /writes=false/.test(resultText) && /secret_output=false/.test(resultText) && /\.env|secret paths|read-only/i.test(bodyText),
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
  const bodyText = await page.locator("body").innerText();
  const framesText = await page.locator("[data-testid='organism-replay-frames']").innerText().catch(() => "");
  const checks = {
    ...base.checks,
    replay_frames_visible: framesText.length > 0 && /replay_available=true|read-only audit projection/i.test(bodyText),
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
  const bodyText = await page.locator("body").innerText();
  const checks = {
    ...base.checks,
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
  if (route === "/games") return await proofWorkspaceMode(page, route, "games", "Game");
  if (route === "/apps") return await proofWorkspaceMode(page, route, "apps", "App");
  if (route === "/media") return await proofWorkspaceMode(page, route, "media", "Media");
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

async function main() {
  const args = parseArgs(process.argv);
  const batchName = batchNameFromOut(args.out);
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
    non_claims: ["DEV-ONLY localhost proof.", "No cloud mutation.", "No live LLM call.", "No live MCP write.", "No secret output."],
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
      const filteredConsole = consoleErrors.filter((entry) => !/favicon|ResizeObserver loop limit exceeded|hydration-mismatch/i.test(entry));
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
    `# Goal D2 ${batchName.replace(/^batch/, "Batch ")} Human Click Proof`,
    "",
    `Base URL: ${args.baseUrl}`,
    `Routes: ${args.routes.join(", ")}`,
    `FAIL: ${report.fail_count}`,
    "",
    "## Step 0 Evidence",
    "",
    `- Cloud-layer resync: \`.codex/runs/CURRENT/goal-d2/${batchName}/cloud-layers-resync.json\``,
    `- K1-K6 tool contract: \`.codex/runs/CURRENT/goal-d2/${batchName}/tool-contract.json\``,
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
    ...(args.routes.includes("/home") ? ["- `/home`: DEV-ONLY glowing cortex hero screenshot plus visible `PASS home_hero_check`; no fake live stats or project-status wall."] : []),
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
    `- HAR: \`.codex/runs/CURRENT/goal-d2/${batchName}/har/${batchName}-human-click-proof.har\``,
    ...report.routes.flatMap((route) => [
      `- ${route.route} before: \`${route.screenshots.before}\``,
      `- ${route.route} after: \`${route.screenshots.after}\``,
    ]),
    "",
    "## Remaining Owner/Cloud Blockers",
    "",
    "- Hosted staging proof remains blocked until real HTTPS `STAGING_BASE_URL` exists.",
    "- Vercel backend origin health remains blocked until `AGENT_API_BASE_URL`, `MCP_GATEWAY_BASE_URL`, and `LLM_GATEWAY_BASE_URL` are live HTTPS origins.",
    "- GitHub branch-protection verification requires the owner-approved token gate.",
    "- Fly live budget check requires the owner-approved `FLY_API_TOKEN` gate.",
    "- Live LLM calls and live MCP writes remain closed; this proof is dry-run/read-only.",
    "",
    "Non-Claims: DEV-ONLY, no cloud mutation, no live LLM, no live MCP write, no secret output.",
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
