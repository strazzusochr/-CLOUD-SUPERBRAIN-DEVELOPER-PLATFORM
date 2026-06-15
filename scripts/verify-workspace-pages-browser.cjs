const fs = require("fs");
const path = require("path");

function parseArgs(argv) {
  const args = { allowLocalhost: false };
  for (let i = 2; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--allow-localhost") {
      args.allowLocalhost = true;
    } else if (arg === "--base-url") {
      args.baseUrl = argv[++i];
    }
  }
  return args;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function isLocalhost(url) {
  return /(^|\/\/)(localhost|127\.0\.0\.1|\[::1\])(?::|\/|$)/i.test(url);
}

function routeUrl(baseUrl, route) {
  return `${baseUrl}${route.startsWith("/") ? route : `/${route}`}`;
}

function screenshotName(page) {
  return `${String(page.no).padStart(2, "0")}-${String(page.pageId).replace(/[^a-z0-9_-]+/gi, "-")}.png`;
}

async function fetchJson(page, url, label) {
  const response = await page.goto(url, { waitUntil: "domcontentloaded", timeout: 30000 });
  assert(response && response.ok(), `${label} endpoint is not OK: ${response?.status()}`);
  return await response.json();
}

async function waitForFrontendHealth(page, url) {
  const healthUrl = new URL("/api/health", url).toString();
  for (let attempt = 1; attempt <= 12; attempt += 1) {
    try {
      const response = await page.request.get(healthUrl, { timeout: 5000 });
      if (response.ok()) return true;
    } catch {
      // Retry below; dev-server restarts can briefly refuse connections.
    }
    await page.waitForTimeout(1000);
  }
  return false;
}

async function gotoWorkspaceRoute(page, url, label, consoleErrors) {
  let lastStatus = "no-response";
  for (let attempt = 1; attempt <= 8; attempt += 1) {
    if (consoleErrors) consoleErrors.length = 0;
    const response = await page.goto(url, { waitUntil: "domcontentloaded", timeout: 60000 });
    lastStatus = String(response?.status() ?? "no-response");
    if (response && response.ok()) return response;
    if (!["502", "503", "504"].includes(lastStatus)) break;
    await waitForFrontendHealth(page, url);
    await page.waitForTimeout(1500 * attempt);
  }
  throw new Error(`Workspace route ${label} returned ${lastStatus}.`);
}

function normalizeSurfaces(workspaceWiring) {
  const surfaces = Array.isArray(workspaceWiring.surfaces) ? workspaceWiring.surfaces : [];
  return surfaces
    .map((surface) => ({
      pageId: String(surface.pageId || ""),
      no: Number(surface.no || 0),
      label: String(surface.label || ""),
      route: String(surface.route || ""),
      layer: String(surface.layer || ""),
      brainRegion: String(surface.brainRegion || ""),
      hub: String(surface.hub || ""),
      primaryMode: String(surface.primaryMode || ""),
      dataSources: Array.isArray(surface.dataSources) ? surface.dataSources.map(String) : [],
      verifierRefs: Array.isArray(surface.verifierRefs) ? surface.verifierRefs.map(String) : [],
      eventKinds: Array.isArray(surface.eventKinds) ? surface.eventKinds.map(String) : [],
      live: Boolean(surface.live),
      writes: Boolean(surface.writes),
      secretOutput: Boolean(surface.secretOutput),
    }))
    .sort((a, b) => a.no - b.no);
}

async function main() {
  const args = parseArgs(process.argv);
  assert(args.baseUrl, "--base-url is required");
  const baseUrl = String(args.baseUrl).replace(/\/+$/, "");
  if (!args.allowLocalhost && isLocalhost(baseUrl)) {
    throw new Error("Workspace pages browser proof refuses localhost unless --allow-localhost is set.");
  }

  const repoRoot = path.resolve(__dirname, "..");
  const playwrightPath = path.join(repoRoot, "apps", "frontend", "node_modules", "playwright");
  const { chromium } = require(playwrightPath);
  const screenshotDir = path.join(repoRoot, "apps", "frontend", "e2e", "__artifacts__", "workspace-pages");
  const proofPath = path.join(repoRoot, ".phase1-artifacts", "workspace-pages-browser-proof-latest.json");
  fs.mkdirSync(screenshotDir, { recursive: true });

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1366, height: 920 },
    deviceScaleFactor: 1,
    reducedMotion: "no-preference",
  });
  const page = await context.newPage();
  const consoleErrors = [];
  page.on("pageerror", (error) => consoleErrors.push(`pageerror: ${error.message}`));
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(`console: ${message.text()}`);
  });

  try {
    const workspaceWiring = await fetchJson(page, `${baseUrl}/api/v1/workspace/wiring`, "workspace wiring");
    assert(workspaceWiring.contract_version === "workspace-surface-wiring-v1", "Workspace wiring contract version mismatch.");
    assert(workspaceWiring.page_count === 22, `Workspace wiring page_count mismatch: ${workspaceWiring.page_count}`);
    const surfaces = normalizeSurfaces(workspaceWiring);
    assert(surfaces.length === 22, `Expected 22 workspace surfaces, got ${surfaces.length}.`);

    const referenceContract = await fetchJson(page, `${baseUrl}/api/v1/design/reference-contract`, "reference design");
    assert(referenceContract.contract_version === "reference-design-conformance-v1", "Reference design contract version mismatch.");
    assert(referenceContract.page_count === 22, `Reference design page_count mismatch: ${referenceContract.page_count}`);

    const expectedNumbers = surfaces.map((surface) => surface.no).join(",");
    assert(expectedNumbers === "1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22", `Workspace page numbers are not contiguous: ${expectedNumbers}`);
    const routeSet = new Set(surfaces.map((surface) => surface.route));
    assert(routeSet.size === 22, "Workspace routes are not unique.");
    const pageIdSet = new Set(surfaces.map((surface) => surface.pageId));
    assert(pageIdSet.size === 22, "Workspace page ids are not unique.");

    const pages = [];
    for (const surface of surfaces) {
      assert(surface.route.startsWith("/"), `Invalid route for ${surface.pageId}: ${surface.route}`);
      assert(surface.layer, `Missing layer for ${surface.pageId}`);
      assert(surface.brainRegion, `Missing brain region for ${surface.pageId}`);
      assert(surface.hub, `Missing hub for ${surface.pageId}`);
      assert(surface.dataSources.length > 0, `Missing data sources for ${surface.pageId}`);
      assert(surface.verifierRefs.length > 0, `Missing verifier refs for ${surface.pageId}`);
      assert(surface.eventKinds.length > 0, `Missing event kinds for ${surface.pageId}`);
      assert(surface.live === false, `Workspace surface must not claim live=true: ${surface.pageId}`);
      assert(surface.writes === false, `Workspace surface must not claim writes=true: ${surface.pageId}`);
      assert(surface.secretOutput === false, `Workspace surface must not claim secretOutput=true: ${surface.pageId}`);

      await gotoWorkspaceRoute(page, routeUrl(baseUrl, surface.route), surface.route, consoleErrors);
      await page.waitForTimeout(surface.pageId.startsWith("organism") ? 1500 : 350);

      const probe = await page.evaluate((surfaceArg) => {
        const root = getComputedStyle(document.documentElement);
        const bodyText = document.body.innerText || "";
        const shell = document.querySelector(".app-shell");
        const main = document.querySelector(".main");
        const topbar = document.querySelector(".topbar");
        const rail = document.querySelector(".rail");
        const panels = Array.from(document.querySelectorAll(".panel, .gcard, .frame, .wb-pane, .layerbar, .readiness, .table, .tbl"));
        const largePanelRadii = panels
          .map((element) => {
            const rect = element.getBoundingClientRect();
            return rect.width >= 80 && rect.height >= 36 ? Number.parseFloat(getComputedStyle(element).borderTopLeftRadius) || 0 : 0;
          })
          .filter((radius) => radius > 0);
        const activeRail = document.querySelector(".rail-item.active");
        const visibleTextLength = bodyText.replace(/\s+/g, " ").trim().length;
        return {
          title: document.title,
          hasShell: Boolean(shell),
          hasMain: Boolean(main),
          hasTopbar: Boolean(topbar),
          hasRail: Boolean(rail),
          hasActiveRail: Boolean(activeRail),
          visibleTextLength,
          bgDeep: root.getPropertyValue("--bg-deep").trim(),
          surface1: root.getPropertyValue("--surface-1").trim(),
          surface2: root.getPropertyValue("--surface-2").trim(),
          cyan: root.getPropertyValue("--cyan").trim(),
          maxLargePanelRadius: Math.max(...largePanelRadii, 0),
          containsLabel: bodyText.includes(surfaceArg.label) || bodyText.includes(surfaceArg.label.split(" / ")[0]),
          containsCloudBrand: bodyText.includes("Cloud Superbrain"),
          forbiddenProjectWall: /Workspace-Surfaces|Completion-Gate|Gate-Matrix|Recovery-Historie/.test(bodyText),
          retiredProviderVisible: /\b(Hetzner|GitKraken|Oracle)\b/i.test(bodyText),
          unpaidBudgetVisible: bodyText.includes("Metered Budget"),
          notFoundVisible: /404|not found|This page could not be found/i.test(bodyText),
        };
      }, surface);

      assert(probe.hasShell, `Missing app shell on ${surface.route}`);
      assert(probe.hasMain, `Missing main region on ${surface.route}`);
      assert(probe.hasTopbar, `Missing topbar on ${surface.route}`);
      if (surface.pageId !== "login") {
        assert(probe.hasRail, `Missing rail on ${surface.route}`);
        assert(probe.hasActiveRail, `Missing active rail item on ${surface.route}`);
      }
      assert(probe.visibleTextLength >= 80, `Route has too little visible text: ${surface.route}`);
      assert(probe.bgDeep.toLowerCase() === "#05070d", `Unexpected bg token on ${surface.route}: ${probe.bgDeep}`);
      assert(probe.surface1.toLowerCase() === "#0b1020", `Unexpected surface token on ${surface.route}: ${probe.surface1}`);
      assert(probe.surface2.toLowerCase() === "#101a31", `Unexpected surface2 token on ${surface.route}: ${probe.surface2}`);
      assert(probe.cyan.toLowerCase() === "#00e5ff", `Unexpected cyan token on ${surface.route}: ${probe.cyan}`);
      assert(probe.maxLargePanelRadius <= 16, `Large panel radius exceeds industrial max on ${surface.route}: ${probe.maxLargePanelRadius}`);
      assert(!probe.forbiddenProjectWall, `Forbidden project status wall marker visible on ${surface.route}`);
      assert(!probe.retiredProviderVisible, `Retired provider is visible on active UI route ${surface.route}`);
      if (surface.pageId !== "workbench") {
        assert(!probe.unpaidBudgetVisible, `Metered Budget visible outside explicit paid workbench path on ${surface.route}`);
      }
      if (surface.pageId === "workbench") {
        assert(!probe.unpaidBudgetVisible, "Metered Budget visible on default unpaid workbench path.");
      }
      assert(!probe.notFoundVisible, `Not-found marker visible on ${surface.route}`);

      const screenshotPath = path.join(screenshotDir, screenshotName(surface));
      await page.screenshot({ path: screenshotPath, fullPage: false, caret: "initial" });
      const screenshotBytes = fs.statSync(screenshotPath).size;
      assert(screenshotBytes > 12000, `Screenshot too small for ${surface.route}: ${screenshotBytes}`);
      const routeErrors = consoleErrors.filter((entry) => !/favicon|ResizeObserver loop limit exceeded/i.test(entry));
      assert(routeErrors.length === 0, `Browser console errors on ${surface.route}: ${routeErrors.join(" | ")}`);
      consoleErrors.length = 0;

      pages.push({
        pageId: surface.pageId,
        no: surface.no,
        label: surface.label,
        route: surface.route,
        layer: surface.layer,
        brainRegion: surface.brainRegion,
        hub: surface.hub,
        screenshot: path.relative(repoRoot, screenshotPath).replace(/\\/g, "/"),
        screenshotBytes,
        maxLargePanelRadius: probe.maxLargePanelRadius,
        visibleTextLength: probe.visibleTextLength,
        activeRail: probe.hasActiveRail || surface.pageId === "login",
      });
    }

    const filteredErrors = consoleErrors.filter((entry) => !/favicon|ResizeObserver loop limit exceeded/i.test(entry));
    assert(filteredErrors.length === 0, `Browser console errors: ${filteredErrors.join(" | ")}`);

    const proof = {
      contract: "workspace-pages-browser-proof-v1",
      base_url: baseUrl,
      localhost_dev_only: isLocalhost(baseUrl),
      source_contracts: {
        workspace_wiring: workspaceWiring.contract_version,
        reference_design: referenceContract.contract_version,
      },
      page_count: pages.length,
      screenshots_dir: path.relative(repoRoot, screenshotDir).replace(/\\/g, "/"),
      pages,
      design_guards: {
        bgDeep: "#05070d",
        surface1: "#0b1020",
        surface2: "#101a31",
        cyan: "#00e5ff",
        maxLargePanelRadius: 16,
        retiredProvidersHidden: true,
        projectStatusWallHidden: true,
        unpaidBudgetHidden: true,
      },
      non_claims: [
        "All 22 canonical routes are browser-smoke-proven only; this is not hosted staging proof.",
        "Localhost proof remains DEV-ONLY when base_url is localhost.",
        "No cloud mutation, deploy, live provider call, MCP write, or secret output.",
      ],
    };
    fs.mkdirSync(path.dirname(proofPath), { recursive: true });
    fs.writeFileSync(proofPath, `${JSON.stringify(proof, null, 2)}\n`, "utf8");
    console.log(`[workspace-pages-browser] proof=${path.relative(repoRoot, proofPath)}`);
    console.log("[workspace-pages-browser] checks completed");
  } finally {
    await browser.close();
  }
}

main().catch((error) => {
  console.error(`[workspace-pages-browser] ${error.stack || error.message}`);
  process.exit(1);
});
