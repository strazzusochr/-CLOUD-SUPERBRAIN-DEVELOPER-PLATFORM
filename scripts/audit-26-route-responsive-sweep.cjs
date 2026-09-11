#!/usr/bin/env node
/**
 * Full-surface audit sweep: every real Next.js page route x desktop+mobile.
 *
 * Unlike scripts/verify-workspace-responsive-browser.cjs, this does NOT read the
 * /api/v1/workspace/wiring registry (which is pinned to 22 surfaces). It walks the
 * filesystem route tree so that surfaces missing from the registry are still proven.
 *
 * Captures per route/viewport: HTTP status, title, console errors, page exceptions,
 * failed network requests, mobile horizontal overflow, duplicate element ids, and a
 * screenshot. Then exercises safe interactive elements and re-checks for new errors.
 */
const fs = require("fs");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..");
const PLAYWRIGHT_ROOT =
  process.env.AUDIT_PLAYWRIGHT_ROOT ||
  path.join(repoRoot, "apps", "frontend", "node_modules", "playwright");
const { chromium } = require(PLAYWRIGHT_ROOT);

const BASE_URL = process.env.AUDIT_BASE_URL || "http://localhost:8081";
const OUT_DIR =
  process.env.AUDIT_OUT_DIR ||
  path.join(repoRoot, ".codex", "runs", "CURRENT", "master-goal", "evidence", "browser-26");

const VIEWPORTS = [
  { name: "desktop", width: 1440, height: 900, isMobile: false },
  { name: "mobile", width: 390, height: 844, isMobile: true },
];

/** Text patterns that must never be clicked automatically (irreversible / external). */
const UNSAFE = /(delete|löschen|loeschen|purge|remove|entfernen|deploy|publish|push|rotate|rotieren|reset|zurücksetzen|zuruecksetzen|logout|abmelden|sign\s*out|clear|leeren|revoke|destroy|drop|shutdown|stop|kill|abort|cancel run|freigeben|grant|approve|merge)/i;

/** Bounds so one pathological surface cannot stall the whole sweep. */
const MAX_CLICKS_PER_PAGE = Number(process.env.AUDIT_MAX_CLICKS || 14);
const ROUTE_BUDGET_MS = Number(process.env.AUDIT_ROUTE_BUDGET_MS || 60000);

function withTimeout(promise, ms, label) {
  let timer;
  return Promise.race([
    promise,
    new Promise((_, reject) => {
      timer = setTimeout(() => reject(new Error(`${label} exceeded ${ms}ms budget`)), ms);
    }),
  ]).finally(() => clearTimeout(timer));
}

function routesFromFilesystem() {
  const appDir = path.join(repoRoot, "apps", "frontend", "app");
  const found = [];
  (function walk(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        if (entry.name === "api") continue; // API handlers are not pages
        walk(full);
      } else if (entry.name === "page.tsx") {
        let rel = path.relative(appDir, dir).split(path.sep).join("/");
        rel = rel === "" ? "/" : `/${rel}`;
        found.push(rel);
      }
    }
  })(appDir);
  return found.sort();
}

/** Dynamic segments need a concrete value to be reachable. */
function materialize(route) {
  return route.replace(/\[([^\]]+)\]/g, "audit-probe");
}

function isIgnorableConsole(text) {
  return (
    /Download the React DevTools/i.test(text) ||
    /\[Fast Refresh\]/i.test(text) ||
    /React DevTools/i.test(text)
  );
}

async function main() {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const routes = routesFromFilesystem();
  const browser = await chromium.launch();
  const results = [];
  let totalInteractions = 0;

  for (const viewport of VIEWPORTS) {
    const context = await browser.newContext({
      viewport: { width: viewport.width, height: viewport.height },
      isMobile: viewport.isMobile,
      hasTouch: viewport.isMobile,
      deviceScaleFactor: 1,
    });

    for (const route of routes) {
      const url = `${BASE_URL}${materialize(route) === "/" ? "/" : materialize(route)}`;
      const consoleErrors = [];
      const pageErrors = [];
      const failedRequests = [];
      const page = await context.newPage();

      // A modal dialog would otherwise block every subsequent action indefinitely.
      page.on("dialog", (dialog) => dialog.dismiss().catch(() => {}));
      page.on("console", (msg) => {
        if (msg.type() !== "error" && msg.type() !== "warning") return;
        const text = msg.text();
        if (isIgnorableConsole(text)) return;
        if (msg.type() === "error") consoleErrors.push(text.slice(0, 300));
      });
      page.on("pageerror", (err) => pageErrors.push(String(err.message).slice(0, 300)));
      page.on("requestfailed", (req) => {
        const f = req.failure();
        failedRequests.push(`${req.method()} ${req.url().slice(0, 160)} :: ${f ? f.errorText : "failed"}`);
      });
      page.on("response", (res) => {
        if (res.status() >= 400) {
          failedRequests.push(`HTTP ${res.status()} ${res.url().slice(0, 160)}`);
        }
      });

      const record = {
        route,
        url,
        viewport: viewport.name,
        status: null,
        title: null,
        ok: false,
        consoleErrors,
        pageErrors,
        failedRequests,
        horizontalOverflow: null,
        duplicateIds: [],
        interactiveFound: 0,
        interactionsPerformed: 0,
        interactionErrors: [],
        screenshot: null,
        error: null,
      };

      try {
        await withTimeout((async () => {
        const response = await page.goto(url, { waitUntil: "domcontentloaded", timeout: 30000 });
        record.status = response ? response.status() : null;
        // Streaming surfaces (SSE) never reach networkidle; treat it as best-effort.
        await page.waitForLoadState("networkidle", { timeout: 6000 }).catch(() => {});
        record.title = await page.title();
        record.ok = record.status !== null && record.status < 400;

        // Layout integrity: no horizontal scroll (critical on mobile).
        record.horizontalOverflow = await page.evaluate(
          () => document.documentElement.scrollWidth - document.documentElement.clientWidth
        );

        // Accessibility basic: duplicate DOM ids break label/aria references.
        record.duplicateIds = await page.evaluate(() => {
          const seen = new Map();
          for (const el of document.querySelectorAll("[id]")) {
            const id = el.id;
            if (!id) continue;
            seen.set(id, (seen.get(id) || 0) + 1);
          }
          return [...seen.entries()].filter(([, n]) => n > 1).map(([id]) => id).slice(0, 10);
        });

        const shotName = `${viewport.name}__${route === "/" ? "root" : route.replace(/[^a-z0-9]+/gi, "_").replace(/^_|_$/g, "")}.png`;
        const shotPath = path.join(OUT_DIR, shotName);
        await page.screenshot({ path: shotPath, fullPage: false });
        record.screenshot = path.relative(repoRoot, shotPath).split(path.sep).join("/");

        // Exercise safe interactive controls.
        const handles = await page.$$("button:not([disabled]), [role='tab'], [role='button']:not([disabled])");
        record.interactiveFound = handles.length;
        const errorsBefore = consoleErrors.length + pageErrors.length;

        for (const handle of handles) {
          if (record.interactionsPerformed >= MAX_CLICKS_PER_PAGE) break;
          try {
            if (!(await handle.isVisible()) || !(await handle.isEnabled())) continue;
            const label = ((await handle.innerText().catch(() => "")) || (await handle.getAttribute("aria-label")) || "").trim();
            if (UNSAFE.test(label)) continue;
            await handle.click({ timeout: 2500, noWaitAfter: true });
            record.interactionsPerformed += 1;
            totalInteractions += 1;
            await page.waitForTimeout(60);
            // Interactions must not navigate us off the surface under test.
            if (!page.url().startsWith(BASE_URL)) {
              await page.goto(url, { waitUntil: "domcontentloaded", timeout: 20000 });
            }
          } catch (err) {
            record.interactionErrors.push(String(err.message).split("\n")[0].slice(0, 160));
          }
        }
        record.newErrorsAfterInteraction = consoleErrors.length + pageErrors.length - errorsBefore;
        })(), ROUTE_BUDGET_MS, `route ${route} @ ${viewport.name}`);
      } catch (err) {
        record.error = String(err.message).split("\n")[0].slice(0, 300);
      } finally {
        await page.close();
      }

      results.push(record);
      // Append-as-we-go so a stalled or killed run still leaves usable evidence.
      fs.appendFileSync(path.join(OUT_DIR, "progress.ndjson"), `${JSON.stringify(record)}\n`);
      const flag = record.error ? "ERR " : record.ok ? "ok  " : "BAD ";
      console.log(
        `${flag}${viewport.name.padEnd(7)} ${record.route.padEnd(20)} status=${String(record.status).padEnd(4)} clicks=${String(record.interactionsPerformed).padEnd(3)} consoleErr=${consoleErrors.length} pageErr=${pageErrors.length} netFail=${failedRequests.length} overflow=${record.horizontalOverflow}`
      );
    }
    await context.close();
  }

  await browser.close();

  const summary = {
    contract_version: "audit-full-surface-responsive-v1",
    generated_at_utc: new Date().toISOString(),
    base_url: BASE_URL,
    route_count: routes.length,
    viewport_count: VIEWPORTS.length,
    page_visits: results.length,
    total_interactions: totalInteractions,
    routes,
    results,
    totals: {
      visits_ok: results.filter((r) => r.ok).length,
      visits_failed: results.filter((r) => !r.ok).length,
      with_console_errors: results.filter((r) => r.consoleErrors.length > 0).length,
      with_page_errors: results.filter((r) => r.pageErrors.length > 0).length,
      with_failed_requests: results.filter((r) => r.failedRequests.length > 0).length,
      mobile_horizontal_overflow: results.filter((r) => r.viewport === "mobile" && r.horizontalOverflow > 0).length,
      with_duplicate_ids: results.filter((r) => r.duplicateIds.length > 0).length,
    },
  };
  const reportPath = path.join(OUT_DIR, "report.json");
  fs.writeFileSync(reportPath, JSON.stringify(summary, null, 2));
  console.log(`\nreport: ${reportPath}`);
  console.log(JSON.stringify(summary.totals, null, 2));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
