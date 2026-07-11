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

// Product-language phrases only. Technical names and contract literals such as API,
// MCP, LLM, WebGL, Next.js, source_kind and live:false intentionally remain valid.
const FORBIDDEN_PRODUCT_PHRASES = [
  "Home",
  "Login / Onboarding",
  "Sign in to your workspace",
  "Skip to Home",
  "Welcome back",
  "Developer Platform",
  "Organism / Replay",
  "Organism / Map",
  "Local Files",
  "Local files",
  "MCP / Tools",
  "Marketplace",
  "Observe",
  "Games",
  "Media",
  "Documents",
  "Proof / Evidence",
  "Diagnostics / Archive",
  "Design System",
  "Technology Stack",
  "Settings / Governance",
  "Profile, gates & policies",
  "Security gates",
  "Role management",
  "Color palette",
  "Typography",
  "Components",
  "Live endpoints",
  "Cortex Map",
  "Auto-rotate",
  "Creator Studio",
  "Doc Studio",
  "Read-only Verifier Probe",
  "Verified across 7 cloud layers",
  "Search pages",
  "No matches",
  "Reset search",
  "Copy selection",
  "No results",
  "Type to filter",
  "Open by Design",
  "Self-Hostable",
  "Extensible",
  "Community Powered",
  "Built on open source",
  "Build anything.",
  "Automate everything.",
  "Own your workflow.",
];

const FORBIDDEN_WORDS = ["Checking", "Download", "Search", "Details"];

function parseArgs(argv) {
  const args = {
    baseUrl: "",
    out: path.join(repoRoot, ".codex", "runs", "CURRENT", "master-goal", "phase3", "3.5a-language-consistency"),
    allowLocalhost: false,
  };
  for (let index = 2; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--base-url") args.baseUrl = String(argv[++index] ?? "").replace(/\/+$/, "");
    else if (arg === "--out") args.out = path.resolve(String(argv[++index] ?? ""));
    else if (arg === "--allow-localhost") args.allowLocalhost = true;
    else throw new Error(`Unbekanntes Argument: ${arg}`);
  }
  if (!args.baseUrl) throw new Error("--base-url ist erforderlich");
  const url = new URL(args.baseUrl);
  const local = ["localhost", "127.0.0.1", "::1", "[::1]"].includes(url.hostname);
  if (local && !args.allowLocalhost) throw new Error("Localhost erfordert --allow-localhost und bleibt DEV-ONLY");
  if (!local && url.protocol !== "https:") throw new Error("Hosted-Nachweise erfordern HTTPS");
  return { ...args, local };
}

function routeSlug(route, index) {
  const name = route.replace(/^\//, "").replaceAll("/", "-") || "root";
  return `${String(index + 1).padStart(2, "0")}-${name}`;
}

function phraseHits(text) {
  const hits = [];
  for (const phrase of FORBIDDEN_PRODUCT_PHRASES) {
    if (text.includes(phrase)) hits.push(phrase);
  }
  for (const word of FORBIDDEN_WORDS) {
    const pattern = new RegExp(`\\b${word.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\b`, "g");
    if (pattern.test(text)) hits.push(word);
  }
  return [...new Set(hits)];
}

function mdEscape(value) {
  return String(value ?? "").replaceAll("|", "\\|").replaceAll("\n", " ");
}

async function main() {
  const args = parseArgs(process.argv);
  const screenshotsDir = path.join(args.out, "screenshots");
  const harPath = path.join(args.out, "network.har");
  fs.mkdirSync(screenshotsDir, { recursive: true });

  const consoleErrors = [];
  const pageErrors = [];
  const routes = [];
  let currentRoute = "startup";
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 1000 },
    recordHar: { path: harPath, mode: "full", content: "embed" },
  });
  const page = await context.newPage();
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push({ route: currentRoute, message: message.text() });
  });
  page.on("pageerror", (error) => pageErrors.push({ route: currentRoute, message: error.message }));

  try {
    for (let index = 0; index < CANONICAL_ROUTES.length; index += 1) {
      const route = CANONICAL_ROUTES[index];
      currentRoute = route;
      const started = Date.now();
      let status = 0;
      let navigationError = "";
      try {
        const response = await page.goto(`${args.baseUrl}${route}`, { waitUntil: "domcontentloaded", timeout: 60_000 });
        status = response?.status() ?? 0;
        await page.waitForLoadState("networkidle", { timeout: 12_000 }).catch(() => undefined);
        await page.waitForTimeout(900);
      } catch (error) {
        navigationError = error instanceof Error ? error.message : String(error);
      }

      const language = navigationError
        ? { title: "", bodyText: "", chromeText: "", scanText: "" }
        : await page.evaluate(() => {
            const ignored = "script,style,noscript,pre,code,.mono,.sr-only,[data-language-scan-ignore],[aria-hidden='true']";
            const visibleText = [];
            const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
            while (walker.nextNode()) {
              const node = walker.currentNode;
              const parent = node.parentElement;
              if (!parent || parent.closest(ignored)) continue;
              const style = getComputedStyle(parent);
              if (style.display === "none" || style.visibility === "hidden") continue;
              const value = String(node.textContent ?? "").replace(/\s+/g, " ").trim();
              if (value) visibleText.push(value);
            }
            const chromeSelectors = "h1,h2,h3,button,a,label,option,[aria-label],[placeholder]";
            const chrome = [...document.querySelectorAll(chromeSelectors)]
              .filter((element) => !element.closest(ignored))
              .flatMap((element) => [
                element.textContent,
                element.getAttribute("aria-label"),
                element.getAttribute("placeholder"),
              ])
              .map((value) => String(value ?? "").replace(/\s+/g, " ").trim())
              .filter(Boolean);
            const bodyText = visibleText.join("\n");
            const chromeText = [...new Set(chrome)].join("\n");
            return {
              title: document.title,
              bodyText,
              chromeText,
              scanText: `${document.title}\n${bodyText}\n${chromeText}`,
            };
          });

      const screenshotName = `${routeSlug(route, index)}.png`;
      const screenshotPath = path.join(screenshotsDir, screenshotName);
      if (!navigationError) await page.screenshot({ path: screenshotPath, fullPage: true });
      const hits = phraseHits(language.scanText);
      const routeConsoleErrors = consoleErrors.filter((item) => item.route === route);
      const routePageErrors = pageErrors.filter((item) => item.route === route);
      const passed = status === 200 && !navigationError && hits.length === 0 && routeConsoleErrors.length === 0 && routePageErrors.length === 0;
      routes.push({
        route,
        url: `${args.baseUrl}${route}`,
        http_status: status,
        title: language.title,
        forbidden_hits: hits,
        console_errors: routeConsoleErrors,
        page_errors: routePageErrors,
        navigation_error: navigationError,
        screenshot: navigationError ? null : `screenshots/${screenshotName}`,
        elapsed_ms: Date.now() - started,
        status: passed ? "PASS" : "FAIL",
      });
    }
  } finally {
    await context.close();
    await browser.close();
  }

  const screenshotCount = routes.filter((route) => route.screenshot && fs.existsSync(path.join(args.out, route.screenshot))).length;
  const forbiddenHitCount = routes.reduce((sum, route) => sum + route.forbidden_hits.length, 0);
  const failedRoutes = routes.filter((route) => route.status !== "PASS");
  const passed = routes.length === CANONICAL_ROUTES.length
    && failedRoutes.length === 0
    && screenshotCount === CANONICAL_ROUTES.length
    && fs.existsSync(harPath)
    && forbiddenHitCount === 0
    && consoleErrors.length === 0
    && pageErrors.length === 0;
  const report = {
    contract_version: "master-goal-s7-language-consistency-v1",
    generated_at_utc: new Date().toISOString(),
    status: passed ? "PASS" : "FAIL",
    proof_kind: args.local ? "DEV-ONLY" : "HOSTED_HTTPS",
    base_url: args.baseUrl,
    route_count: routes.length,
    expected_route_count: CANONICAL_ROUTES.length,
    passed_route_count: routes.length - failedRoutes.length,
    failed_route_count: failedRoutes.length,
    screenshot_count: screenshotCount,
    forbidden_hit_count: forbiddenHitCount,
    console_error_count: consoleErrors.length,
    page_error_count: pageErrors.length,
    har: "network.har",
    technical_allowlist: [
      "API", "MCP", "LLM", "SSE", "WebGL", "WebGPU", "Next.js", "React", "LangGraph",
      "PostgreSQL", "pgvector", "Redis", "Vercel", "Fly.io", "Cloudflare", "GitHub", "GHCR",
      "Grafana", "Open Source", "Workers AI", "source_kind", "live:false", "contract_version",
    ],
    forbidden_product_phrases: [...FORBIDDEN_PRODUCT_PHRASES, ...FORBIDDEN_WORDS],
    routes,
    console_errors: consoleErrors,
    page_errors: pageErrors,
  };
  fs.writeFileSync(path.join(args.out, "language-consistency.json"), `${JSON.stringify(report, null, 2)}\n`, "utf8");
  const rows = routes.map((route) => `| ${route.route} | ${route.http_status} | ${route.status} | ${route.forbidden_hits.map(mdEscape).join(", ") || "—"} | ${route.screenshot ?? "—"} |`);
  const markdown = [
    "# S7 Sprachkonsistenz — 22-Seiten-Nachweis",
    "",
    `- Status: **${report.status}**`,
    `- Beweisart: \`${report.proof_kind}\``,
    `- Basis-URL: \`${report.base_url}\``,
    `- Routen: \`${report.passed_route_count}/${report.expected_route_count}\` PASS`,
    `- Verbotene Produktphrasen: \`${report.forbidden_hit_count}\``,
    `- Screenshots: \`${report.screenshot_count}\``,
    `- Konsolenfehler: \`${report.console_error_count}\``,
    `- Seitenfehler: \`${report.page_error_count}\``,
    `- HAR: \`${report.har}\``,
    "",
    "Technische Eigennamen und unveränderte Vertragsliterale sind explizit zugelassen; geprüft wird die sichtbare Produktsprache nach Hydration.",
    "",
    "| Route | HTTP | Ergebnis | Treffer | Screenshot |",
    "| --- | ---: | --- | --- | --- |",
    ...rows,
    "",
  ].join("\n");
  fs.writeFileSync(path.join(args.out, "language-consistency.md"), markdown, "utf8");

  console.log(`[language-22] status=${report.status}`);
  console.log(`[language-22] routes=${report.passed_route_count}/${report.expected_route_count}`);
  console.log(`[language-22] forbidden_hits=${report.forbidden_hit_count}`);
  console.log(`[language-22] screenshots=${report.screenshot_count}`);
  console.log(`[language-22] har=${harPath}`);
  if (!passed) process.exitCode = 1;
}

main().catch((error) => {
  console.error(`[language-22] fatal=${error instanceof Error ? error.message : String(error)}`);
  process.exitCode = 1;
});
