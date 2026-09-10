import fs from "fs";
import path from "path";
import { createRequire } from "module";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "..");
const require = createRequire(import.meta.url);
const { chromium } = require(path.join(repoRoot, "apps", "frontend", "node_modules", "playwright"));

const CANONICAL_ROUTES = [
  "/home", "/login", "/workbench", "/organism", "/organism/replay", "/organism/map",
  "/agents", "/files", "/files/local", "/tools", "/marketplace", "/observe", "/games",
  "/apps", "/media", "/docs-output", "/evidence", "/diagnostics", "/design-system",
  "/technology", "/settings", "/open-source",
];

function parseArgs(argv) {
  const args = {
    baseUrl: "http://localhost:8081",
    out: path.join(repoRoot, ".codex", "runs", "CURRENT", "goal-d4", "batch0", "surface-audit"),
    routes: [...CANONICAL_ROUTES],
  };
  for (let index = 2; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--base-url") args.baseUrl = argv[++index].replace(/\/+$/, "");
    else if (arg === "--out") args.out = path.resolve(argv[++index]);
    else if (arg === "--routes") args.routes = argv[++index].split(",").filter(Boolean);
  }
  const unique = new Set(args.routes);
  if (unique.size !== args.routes.length || args.routes.some((route) => !CANONICAL_ROUTES.includes(route))) {
    throw new Error("Routes must be unique members of the canonical 22-route registry.");
  }
  return args;
}

function writeJson(filePath, value) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

function slug(route) {
  return route.replace(/\W+/g, "-").replace(/^-|-$/g, "") || "root";
}

function localUrl(baseUrl) {
  return /^https?:\/\/(localhost|127\.0\.0\.1|\[::1\])(?::\d+)?(?:\/|$)/i.test(baseUrl);
}

async function stableGoto(page, url) {
  let lastError = "no response";
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try {
      const response = await page.goto(url, { waitUntil: "domcontentloaded", timeout: 60000 });
      if (response?.ok()) {
        await page.waitForLoadState("networkidle", { timeout: 30000 }).catch(() => undefined);
        await page.waitForTimeout(500);
        return response;
      }
      lastError = `HTTP ${response?.status() ?? "no-response"}`;
    } catch (error) {
      lastError = error instanceof Error ? error.message : String(error);
    }
    await page.waitForTimeout(1000 * attempt);
  }
  throw new Error(lastError);
}

async function proveInternalNavigation(page, baseUrl, route) {
  const beforeUrl = page.url();
  const link = page.locator("a[href]").evaluateAll((links, currentRoute) => {
    const candidate = links.find((item) => {
      const href = item.getAttribute("href") || "";
      return href.startsWith("/") && href !== currentRoute;
    });
    return candidate?.getAttribute("href") || null;
  }, route);
  const target = await link;
  if (!target) return { class: "FAIL", target: null, detail: "no internal rail navigation candidate" };
  await page.locator(`a[href="${target}"]`).first().click({ timeout: 20000 });
  await page.waitForURL(new RegExp(`${target.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}(?:$|[?#])`), { timeout: 20000, waitUntil: "commit" });
  const changed = page.url() !== beforeUrl;
  await stableGoto(page, `${baseUrl}${route}`);
  return { class: changed ? "PASS" : "FAIL", target, detail: changed ? "url_changed_then_restored" : "url_not_changed" };
}

async function main() {
  const args = parseArgs(process.argv);
  const local = localUrl(args.baseUrl);
  const evidenceRoot = path.relative(repoRoot, args.out).replace(/\\/g, "/");
  fs.mkdirSync(path.join(args.out, "screenshots"), { recursive: true });
  fs.mkdirSync(path.join(args.out, "har"), { recursive: true });

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 960 },
    recordHar: { path: path.join(args.out, "har", "surface-audit.har"), content: "omit" },
  });
  const page = await context.newPage();
  const report = {
    contract_version: "goal-d4-surface-audit-v1",
    base_url: args.baseUrl,
    scope: local ? "DEV-ONLY" : "HTTPS_HOSTED",
    canonical_route_count: args.routes.length,
    routes: [],
    fail_count: 0,
    non_claims: ["No cloud mutation.", "No live LLM call.", "No live MCP write.", "No secret output."],
  };
  const consoleErrors = [];
  page.on("pageerror", (error) => consoleErrors.push(error.message));
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(message.text());
  });

  try {
    for (const route of args.routes) {
      const errors = [];
      const url = `${args.baseUrl}${route}`;
      let status = 0;
      let appShell = false;
      let main = false;
      let nav = { class: "FAIL", target: null, detail: "navigation_not_run" };
      const before = path.join(args.out, "screenshots", `${slug(route)}-before.png`);
      const after = path.join(args.out, "screenshots", `${slug(route)}-after.png`);
      try {
        const response = await stableGoto(page, url);
        status = response.status();
        appShell = await page.locator(".app-shell").count().then((count) => count > 0);
        main = await page.locator("main").count().then((count) => count > 0);
        await page.screenshot({ path: before, fullPage: false });
        nav = await proveInternalNavigation(page, args.baseUrl, route);
        await page.screenshot({ path: after, fullPage: false });
      } catch (error) {
        errors.push(error instanceof Error ? error.message : String(error));
      }
      const relevantConsole = consoleErrors.filter((entry) => !/favicon|ResizeObserver|webpack-hmr|_next\/webpack-hmr/i.test(entry));
      consoleErrors.length = 0;
      if (status !== 200) errors.push(`http_status:${status}`);
      if (!appShell) errors.push("app_shell_missing");
      if (!main) errors.push("main_missing");
      if (nav.class !== "PASS") errors.push(`navigation:${nav.detail}`);
      report.fail_count += errors.length;
      report.routes.push({
        route,
        http_status: status,
        app_shell: appShell,
        main,
        internal_navigation: nav,
        console_errors: relevantConsole,
        fail_count: errors.length,
        errors,
        screenshots: {
          before: path.relative(repoRoot, before).replace(/\\/g, "/"),
          after: path.relative(repoRoot, after).replace(/\\/g, "/"),
        },
      });
    }
  } finally {
    await context.close();
    await browser.close();
  }

  writeJson(path.join(args.out, "report.json"), report);
  const rows = report.routes.map((route) => `| ${route.route} | ${route.http_status} | ${route.app_shell} | ${route.main} | ${route.internal_navigation.class} | ${route.fail_count} |`).join("\n");
  const reportMd = [
    "# Goal D4 Surface Audit",
    "",
    `Base URL: ${args.baseUrl}`,
    `Scope: ${report.scope}`,
    `Canonical routes: ${report.canonical_route_count}`,
    `FAIL: ${report.fail_count}`,
    "",
    "| Route | HTTP | App shell | Main | Internal navigation | FAIL |",
    "| --- | ---: | --- | --- | --- | ---: |",
    rows,
    "",
    `- HAR: \`${evidenceRoot}/har/surface-audit.har\``,
    "- Each route has before/after PNG evidence under `screenshots/`.",
    "- Navigation proof uses an existing internal rail link and restores the inspected route before its after screenshot.",
    "",
    `Non-Claims: ${local ? "DEV-ONLY localhost proof." : "HTTPS hosted proof."} No cloud mutation, live LLM call, live MCP write, or secret output.`,
    "",
  ].join("\n");
  fs.writeFileSync(path.join(args.out, "report.md"), reportMd, "utf8");
  console.log(`[goal-d4-surface-audit] routes=${report.canonical_route_count} fail=${report.fail_count} out=${evidenceRoot}`);
  if (report.fail_count) process.exit(1);
}

main().catch((error) => {
  console.error(`[goal-d4-surface-audit] ${error.stack || error.message}`);
  process.exit(1);
});
