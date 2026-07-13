const fs = require("fs");
const path = require("path");

function parseArgs(argv) {
  const args = { allowLocalhost: false };
  for (let index = 2; index < argv.length; index += 1) {
    if (argv[index] === "--allow-localhost") args.allowLocalhost = true;
    else if (argv[index] === "--base-url") args.baseUrl = argv[++index];
    else if (argv[index] === "--out") args.outDir = argv[++index];
    else if (argv[index] === "--browser-channel") args.browserChannel = argv[++index];
  }
  return args;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function isLocalhost(url) {
  return /(^|\/\/)(localhost|127\.0\.0\.1|\[::1\])(?::|\/|$)/i.test(url);
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function normalizeSurfaces(payload) {
  return [...(Array.isArray(payload.surfaces) ? payload.surfaces : [])]
    .map((surface) => ({
      pageId: String(surface.pageId || ""),
      no: Number(surface.no || 0),
      label: String(surface.label || ""),
      route: String(surface.route || ""),
    }))
    .sort((left, right) => left.no - right.no);
}

async function clickRoute(page, surface, baseUrl) {
  let lastError;
  for (let attempt = 1; attempt <= 2; attempt += 1) {
    try {
      const commandButton = page.getByRole("button", { name: "Suchen oder Befehl ausführen" });
      await commandButton.click();
      const dialog = page.getByRole("dialog", { name: "Befehlspalette" });
      await dialog.waitFor({ state: "visible" });
      const input = dialog.getByRole("textbox", { name: "Seiten durchsuchen" });
      await input.fill(surface.route);
      const routeLabel = dialog.locator(".cmdk-item-route").filter({
        hasText: new RegExp(`^\\s*${escapeRegExp(surface.route)}\\s*$`),
      });
      const option = routeLabel.locator("..");
      assert(await option.count() === 1, `Command palette route is not unique or missing: ${surface.route}`);
      await Promise.all([
        page.waitForURL((url) => url.pathname === surface.route, {
          timeout: 45000,
          waitUntil: "commit",
        }),
        option.click(),
      ]);
      lastError = undefined;
      break;
    } catch (error) {
      if (new URL(page.url()).pathname === surface.route) {
        lastError = undefined;
        break;
      }
      lastError = error;
      if (attempt === 2) break;
      console.warn(`[responsive-22] retry=${surface.route} after=${error.name || "navigation_error"}`);
      await page.keyboard.press("Escape").catch(() => {});
      await page.waitForTimeout(1000);
    }
  }
  if (lastError) throw lastError;
  await page.waitForLoadState("domcontentloaded");
  await page.waitForTimeout(surface.pageId.startsWith("organism") ? 1200 : 250);
  assert(new URL(page.url()).pathname === surface.route, `Click did not navigate to ${surface.route}`);
  assert(page.url().startsWith(baseUrl), `Navigation escaped the configured origin: ${page.url()}`);
}

async function probeLayout(page, surface, profile) {
  return await page.evaluate(({ surfaceArg, profileArg }) => {
    const viewportWidth = document.documentElement.clientWidth;
    const bodyText = (document.body.innerText || "").replace(/\s+/g, " ").trim();
    const candidates = Array.from(document.querySelectorAll("body *"));
    const overflowElements = [];
    for (const element of candidates) {
      const rect = element.getBoundingClientRect();
      if (rect.width <= 1 || rect.height <= 1) continue;
      if (rect.right <= viewportWidth + 2 && rect.left >= -2) continue;
      let ancestor = element;
      let scrollBoundary = false;
      while (ancestor && ancestor !== document.body) {
        const style = getComputedStyle(ancestor);
        if (["auto", "scroll"].includes(style.overflowX)) {
          scrollBoundary = true;
          break;
        }
        ancestor = ancestor.parentElement;
      }
      if (!scrollBoundary && overflowElements.length < 10) {
        overflowElements.push({
          tag: element.tagName.toLowerCase(),
          className: String(element.className || "").slice(0, 100),
          left: Math.round(rect.left),
          right: Math.round(rect.right),
          width: Math.round(rect.width),
        });
      }
    }
    const commandButton = document.querySelector('button[aria-label="Suchen oder Befehl ausführen"]');
    const main = document.querySelector(".main");
    const topbar = document.querySelector(".topbar");
    const rail = document.querySelector(".rail");
    const mainRect = main?.getBoundingClientRect();
    const railRect = rail?.getBoundingClientRect();
    const overlayCollisions = [];
    for (const [leftSelector, rightSelector] of [[".org-hud", ".org-gates"]]) {
      const left = document.querySelector(leftSelector)?.getBoundingClientRect();
      const right = document.querySelector(rightSelector)?.getBoundingClientRect();
      if (!left || !right || left.width <= 1 || left.height <= 1 || right.width <= 1 || right.height <= 1) continue;
      const overlapWidth = Math.min(left.right, right.right) - Math.max(left.left, right.left);
      const overlapHeight = Math.min(left.bottom, right.bottom) - Math.max(left.top, right.top);
      if (overlapWidth > 1 && overlapHeight > 1) {
        overlayCollisions.push({
          left: leftSelector,
          right: rightSelector,
          width: Math.round(overlapWidth),
          height: Math.round(overlapHeight),
        });
      }
    }
    return {
      pageId: surfaceArg.pageId,
      route: surfaceArg.route,
      profile: profileArg,
      viewportWidth,
      documentScrollWidth: document.documentElement.scrollWidth,
      bodyScrollWidth: document.body.scrollWidth,
      visibleTextLength: bodyText.length,
      hasShell: Boolean(document.querySelector(".app-shell")),
      hasMain: Boolean(main),
      hasTopbar: Boolean(topbar),
      hasCommandButton: Boolean(commandButton),
      navigationRailVisible: Boolean(railRect && railRect.width > 1 && railRect.height > 1),
      mainRight: Math.round(mainRect?.right || 0),
      mainLeft: Math.round(mainRect?.left || 0),
      horizontalDocumentOverflow: Math.max(0, document.documentElement.scrollWidth - viewportWidth),
      overflowElements,
      overlayCollisions,
      notFoundVisible: /\b404\b|not found|This page could not be found/i.test(bodyText),
    };
  }, { surfaceArg: surface, profileArg: profile });
}

async function runProfile(browser, profile, surfaces, baseUrl, artifactDir) {
  const context = await browser.newContext({
    viewport: profile.viewport,
    deviceScaleFactor: 1,
    isMobile: profile.mobile,
    hasTouch: profile.mobile,
    reducedMotion: "no-preference",
  });
  const page = await context.newPage();
  const errors = [];
  page.on("pageerror", (error) => errors.push(`pageerror: ${error.message}`));
  page.on("console", (message) => {
    if (message.type() === "error") errors.push(`console: ${message.text()}`);
  });

  const checks = [];
  try {
    const bootstrap = await page.goto(`${baseUrl}/home`, { waitUntil: "networkidle", timeout: 120000 });
    assert(bootstrap && bootstrap.ok(), `${profile.id} bootstrap did not return 200`);
    await page.waitForTimeout(1000);
    const homeSurface = surfaces.find((surface) => surface.route === "/home");
    const loginSurface = surfaces.find((surface) => surface.route === "/login");
    assert(homeSurface && loginSurface, "Workspace wiring must include /home and /login");
    const clickOrder = [
      ...surfaces.filter((surface) => !["/home", "/login"].includes(surface.route)),
      homeSurface,
      loginSurface,
    ];
    for (const surface of clickOrder) {
      console.log(`[responsive-22] profile=${profile.id} click=${surface.route}`);
      errors.length = 0;
      await clickRoute(page, surface, baseUrl);
      const probe = await probeLayout(page, surface, profile.id);
      const isLogin = surface.route === "/login";
      if (isLogin) {
        assert(probe.hasShell && probe.hasMain && probe.hasTopbar, `${profile.id} login shell missing`);
        assert(!probe.hasCommandButton, `${profile.id} login unexpectedly renders the workspace command button`);
        assert(!probe.navigationRailVisible, `${profile.id} login unexpectedly renders the workspace navigation rail`);
        assert(await page.getByRole("link", { name: "Zum Start" }).count() === 1, `${profile.id} login return link missing`);
      } else {
        assert(probe.hasShell && probe.hasMain && probe.hasTopbar, `${profile.id} shell missing on ${surface.route}`);
        assert(probe.hasCommandButton, `${profile.id} command button missing on ${surface.route}`);
      }
      assert(probe.visibleTextLength >= 80, `${profile.id} visible content too small on ${surface.route}`);
      assert(!probe.notFoundVisible, `${profile.id} not-found marker on ${surface.route}`);
      assert(probe.horizontalDocumentOverflow <= 2, `${profile.id} document overflow ${probe.horizontalDocumentOverflow}px on ${surface.route}`);
      assert(probe.overflowElements.length === 0, `${profile.id} incoherent overflow on ${surface.route}: ${JSON.stringify(probe.overflowElements)}`);
      assert(probe.overlayCollisions.length === 0, `${profile.id} overlay collision on ${surface.route}: ${JSON.stringify(probe.overlayCollisions)}`);
      if (profile.mobile) {
        assert(probe.mainRight <= probe.viewportWidth + 2, `Mobile main exceeds viewport on ${surface.route}`);
        assert(probe.mainLeft >= -2, `Mobile main starts outside the viewport on ${surface.route}: ${probe.mainLeft}`);
        assert(!probe.navigationRailVisible, `Mobile navigation rail must be collapsed on ${surface.route}`);
      }
      const routeErrors = errors.filter((entry) => !/favicon|ResizeObserver loop limit exceeded/i.test(entry));
      assert(routeErrors.length === 0, `${profile.id} console errors on ${surface.route}: ${routeErrors.join(" | ")}`);
      checks.push({ ...probe, clickNavigation: true, consoleErrors: [] });

      if (["home", "organism"].includes(surface.pageId)) {
        const screenshot = path.join(artifactDir, `${profile.id}-${surface.pageId}.png`);
        await page.screenshot({ path: screenshot, fullPage: false });
        assert(fs.statSync(screenshot).size > 20000, `Screenshot too small: ${screenshot}`);
      }
    }
    return checks;
  } finally {
    await context.close();
  }
}

async function main() {
  const args = parseArgs(process.argv);
  assert(args.baseUrl, "--base-url is required");
  const baseUrl = String(args.baseUrl).replace(/\/+$/, "");
  if (!args.allowLocalhost && isLocalhost(baseUrl)) {
    throw new Error("Responsive 22-page proof refuses localhost unless --allow-localhost is set.");
  }

  const repoRoot = path.resolve(__dirname, "..");
  const artifactDir = args.outDir
    ? path.resolve(repoRoot, args.outDir)
    : path.join(repoRoot, ".codex", "runs", "CURRENT", "frontend", "responsive-22");
  fs.mkdirSync(artifactDir, { recursive: true });
  const { chromium } = require(path.join(repoRoot, "apps", "frontend", "node_modules", "playwright"));
  const browser = await chromium.launch({
    headless: true,
    ...(args.browserChannel ? { channel: args.browserChannel } : {}),
    args: ["--disable-gpu", "--disable-gpu-compositing", "--use-gl=swiftshader", "--ignore-gpu-blocklist"],
  });
  try {
    const request = await browser.newPage();
    const wiringResponse = await request.request.get(`${baseUrl}/api/v1/workspace/wiring`);
    assert(wiringResponse.ok(), `Workspace wiring returned ${wiringResponse.status()}`);
    const wiring = await wiringResponse.json();
    const surfaces = normalizeSurfaces(wiring);
    assert(wiring.contract_version === "workspace-surface-wiring-v1", "Workspace wiring version mismatch");
    assert(surfaces.length === 22, `Expected 22 routes, got ${surfaces.length}`);
    await request.close();

    const profiles = [
      { id: "desktop", viewport: { width: 1440, height: 960 }, mobile: false },
      { id: "mobile", viewport: { width: 390, height: 844 }, mobile: true },
    ];
    const results = {};
    for (const profile of profiles) {
      results[profile.id] = await runProfile(browser, profile, surfaces, baseUrl, artifactDir);
    }
    const proof = {
      contract_version: "frontend-22-page-responsive-browser-v1",
      status: "verified",
      evidence_ref: "frontend_22_page_responsive_click_proof",
      base_url: baseUrl,
      scope: isLocalhost(baseUrl) ? "DEV-ONLY" : "hosted_https",
      browser_channel: args.browserChannel || "playwright-bundled-chromium",
      browser_version: browser.version(),
      page_count: 22,
      viewport_count: 2,
      click_navigation_count: 44,
      overflow_failures: 0,
      overlay_collision_failures: 0,
      console_errors: 0,
      profiles,
      results,
      screenshots: ["desktop-home.png", "desktop-organism.png", "mobile-home.png", "mobile-organism.png"],
      non_claims: [
        "Localhost evidence remains DEV-ONLY and cannot close the final current hosted frontend proof.",
        "No provider write, live MCP write, deployment, release promotion, or secret use occurred.",
      ],
      generated_at: new Date().toISOString(),
    };
    fs.writeFileSync(path.join(artifactDir, "report.json"), `${JSON.stringify(proof, null, 2)}\n`, "utf8");
    console.log(`[responsive-22] routes=${surfaces.length} viewports=${profiles.length} clicks=44`);
    console.log(`[responsive-22] report=${path.relative(repoRoot, path.join(artifactDir, "report.json"))}`);
    console.log("[responsive-22] checks completed");
  } finally {
    await browser.close();
  }
}

main().catch((error) => {
  console.error(`[responsive-22] ${error.stack || error.message}`);
  process.exit(1);
});
