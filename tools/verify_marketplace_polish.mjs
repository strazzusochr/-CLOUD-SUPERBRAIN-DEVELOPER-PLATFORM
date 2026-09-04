import fs from "fs";
import path from "path";
import { createRequire } from "module";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "..");
const require = createRequire(import.meta.url);
const { chromium } = require(path.join(repoRoot, "apps", "frontend", "node_modules", "playwright"));

function parseArgs(argv) {
  const args = {
    baseUrl: "",
    out: path.join(repoRoot, ".codex", "runs", "CURRENT", "master-goal", "phase3", "3.5b-marketplace-polish"),
    allowLocalhost: false,
  };
  for (let index = 2; index < argv.length; index += 1) {
    if (argv[index] === "--base-url") args.baseUrl = String(argv[++index] ?? "").replace(/\/+$/, "");
    else if (argv[index] === "--out") args.out = path.resolve(String(argv[++index] ?? ""));
    else if (argv[index] === "--allow-localhost") args.allowLocalhost = true;
    else throw new Error(`Unbekanntes Argument: ${argv[index]}`);
  }
  if (!args.baseUrl) throw new Error("--base-url ist erforderlich");
  const parsed = new URL(args.baseUrl);
  const local = ["localhost", "127.0.0.1", "::1", "[::1]"].includes(parsed.hostname);
  if (local && !args.allowLocalhost) throw new Error("Localhost erfordert --allow-localhost und bleibt DEV-ONLY");
  if (!local && parsed.protocol !== "https:") throw new Error("Hosted-Nachweise erfordern HTTPS");
  return { ...args, local };
}

function markdownEscape(value) {
  return String(value ?? "").replaceAll("|", "\\|").replaceAll("\n", " ");
}

async function main() {
  const args = parseArgs(process.argv);
  fs.mkdirSync(args.out, { recursive: true });
  const harPath = path.join(args.out, "network.har");
  const desktopPath = path.join(args.out, "marketplace-desktop.png");
  const mobilePath = path.join(args.out, "marketplace-mobile.png");
  const checks = [];
  const consoleErrors = [];
  const pageErrors = [];
  const artifactPosts = [];
  const check = (id, passed, evidence) => checks.push({ id, passed: Boolean(passed), evidence: String(evidence ?? "") });

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 1100 },
    recordHar: { path: harPath, mode: "full", content: "embed" },
  });
  const page = await context.newPage();
  page.on("console", (message) => message.type() === "error" && consoleErrors.push(message.text()));
  page.on("pageerror", (error) => pageErrors.push(error.message));
  page.on("request", (request) => {
    if (request.method() === "POST" && request.url().includes("/api/v1/workspace/artifacts")) {
      let body = null;
      try { body = request.postDataJSON(); } catch {}
      artifactPosts.push({ url: request.url(), body });
    }
  });

  let fatalError = "";
  try {
    const response = await page.goto(`${args.baseUrl}/marketplace`, { waitUntil: "domcontentloaded", timeout: 60_000 });
    check("marketplace_http_200", response?.status() === 200, `status=${response?.status() ?? 0}`);
    await page.waitForLoadState("networkidle", { timeout: 15_000 }).catch(() => undefined);
    await page.waitForTimeout(900);

    const cards = page.locator("[data-testid='marketplace-card-grid'] .gcard");
    const cardCount = await cards.count();
    const iconCount = await page.locator("[data-testid='marketplace-card-grid'] .marketplace-card-icon svg").count();
    const badgeCount = await page.locator("[data-testid='marketplace-card-grid'] .marketplace-card-preview .badge").count();
    const kinds = await page.locator("[data-testid='marketplace-card-grid'] .marketplace-card-preview .badge").allTextContents();
    const previewMetrics = await page.locator("[data-testid='marketplace-card-grid'] .marketplace-card-preview").first().evaluate((element) => {
      const rect = element.getBoundingClientRect();
      return { width: Math.round(rect.width), height: Math.round(rect.height) };
    });
    check("cards_present", cardCount >= 4, `cards=${cardCount}`);
    check("icon_per_card", iconCount === cardCount, `icons=${iconCount}; cards=${cardCount}`);
    check("type_badge_per_card", badgeCount === cardCount, `badges=${badgeCount}; cards=${cardCount}`);
    check("all_four_types_visible", ["Skill", "Agent", "MCP", "Modell"].every((kind) => kinds.includes(kind)), `types=${[...new Set(kinds)].join(",")}`);
    check("stable_header_size", previewMetrics.height >= 96 && previewMetrics.width >= 180, JSON.stringify(previewMetrics));

    const selector = page.getByLabel("Marktplatz-Eintrag");
    const options = await selector.locator("option").evaluateAll((nodes) => nodes.map((node) => ({ value: node.value, text: node.textContent ?? "" })));
    const selected = options.find((option) => option.value.startsWith("Agent:")) ?? options[1] ?? options[0];
    await selector.selectOption(selected.value);
    const result = page.getByTestId("goal-b-marketplace-result");
    await result.waitFor({ state: "visible" });
    check("result_is_structured_ui", (await result.evaluate((element) => element.tagName)) !== "PRE", `tag=${await result.evaluate((element) => element.tagName)}`);
    check("selection_state_visible", (await result.getAttribute("data-result-state")) === "selected", `state=${await result.getAttribute("data-result-state")}`);

    await page.getByTestId("goal-b-marketplace-details").click();
    await page.waitForFunction(() => document.querySelector("[data-testid='goal-b-marketplace-result']")?.getAttribute("data-result-state") === "details");
    const detailsText = await result.innerText();
    check("details_click_path", detailsText.includes("PASS marketplace_details"), detailsText);
    check("details_read_only", detailsText.includes("provider_writes=false"), detailsText);

    await page.getByTestId("goal-b-marketplace-install").click();
    await page.waitForFunction(() => document.querySelector("[data-testid='goal-b-marketplace-result']")?.getAttribute("data-result-state") === "installed", null, { timeout: 45_000 });
    const installText = await result.innerText();
    check("install_dry_run_click_path", installText.includes("PASS marketplace_install"), installText);
    check("install_provider_writes_false", installText.includes("provider_writes=false"), installText);
    const artifactVisible = /Artefakt\s+[0-9a-f-]{8,}/i.test(installText);
    const projectionTruthVisible = installText.includes("persisted=false") && installText.includes("frontend-projection");
    check(
      "install_persistence_truth_visible",
      args.local ? artifactVisible || projectionTruthVisible : artifactVisible && installText.includes("persisted=true"),
      installText,
    );
    const artifactPost = artifactPosts.at(-1);
    check("artifact_post_observed", Boolean(artifactPost), artifactPost ? artifactPost.url : "missing");
    check(
      "artifact_post_is_plan_only",
      artifactPost?.body?.artifact_type === "marketplace_install_plan"
        && artifactPost?.body?.metadata?.provider_writes === false
        && artifactPost?.body?.metadata?.registry_pull === false,
      JSON.stringify(artifactPost?.body ?? null),
    );

    await page.screenshot({ path: desktopPath, fullPage: true });
    await page.setViewportSize({ width: 390, height: 844 });
    await page.waitForTimeout(400);
    const mobileLayout = await page.evaluate(() => ({
      viewport: window.innerWidth,
      scrollWidth: document.documentElement.scrollWidth,
      resultVisible: Boolean(document.querySelector("[data-testid='goal-b-marketplace-result']")),
    }));
    check("mobile_no_horizontal_overflow", mobileLayout.scrollWidth <= mobileLayout.viewport + 2, JSON.stringify(mobileLayout));
    check("mobile_result_visible", mobileLayout.resultVisible, JSON.stringify(mobileLayout));
    await page.screenshot({ path: mobilePath, fullPage: true });
  } catch (error) {
    fatalError = error instanceof Error ? error.message : String(error);
  } finally {
    await context.close();
    await browser.close();
  }

  check("console_errors_zero", consoleErrors.length === 0, JSON.stringify(consoleErrors));
  check("page_errors_zero", pageErrors.length === 0, JSON.stringify(pageErrors));
  check("desktop_png_written", fs.existsSync(desktopPath), path.basename(desktopPath));
  check("mobile_png_written", fs.existsSync(mobilePath), path.basename(mobilePath));
  check("har_written", fs.existsSync(harPath), path.basename(harPath));
  const failedChecks = checks.filter((item) => !item.passed);
  const passed = !fatalError && failedChecks.length === 0;
  const report = {
    contract_version: "master-goal-s9-marketplace-polish-v1",
    generated_at_utc: new Date().toISOString(),
    status: passed ? "PASS" : "FAIL",
    proof_kind: args.local ? "DEV-ONLY" : "HOSTED_HTTPS",
    base_url: args.baseUrl,
    route: "/marketplace",
    provider_writes: false,
    registry_pull: false,
    check_count: checks.length,
    passed_check_count: checks.length - failedChecks.length,
    failed_check_count: failedChecks.length,
    screenshots: [path.basename(desktopPath), path.basename(mobilePath)],
    har: path.basename(harPath),
    fatal_error: fatalError,
    checks,
    console_errors: consoleErrors,
    page_errors: pageErrors,
  };
  fs.writeFileSync(path.join(args.out, "marketplace-polish.json"), `${JSON.stringify(report, null, 2)}\n`, "utf8");
  const markdown = [
    "# S9 Marktplatz-Politur — Klickpfad-Nachweis",
    "",
    `- Status: **${report.status}**`,
    `- Beweisart: \`${report.proof_kind}\``,
    `- Basis-URL: \`${report.base_url}\``,
    `- Prüfungen: \`${report.passed_check_count}/${report.check_count}\` PASS`,
    "- Klickpfad: Auswahl → Einzelheiten → Installations-Dry-Run",
    "- Sicherheitsinvariante: `provider_writes=false`, `registry_pull=false`",
    `- Screenshots: ${report.screenshots.map((name) => `\`${name}\``).join(", ")}`,
    `- HAR: \`${report.har}\``,
    "",
    "| Prüfung | Ergebnis | Evidenz |",
    "| --- | --- | --- |",
    ...checks.map((item) => `| ${item.id} | ${item.passed ? "PASS" : "FAIL"} | ${markdownEscape(item.evidence)} |`),
    ...(fatalError ? ["", `Fataler Fehler: \`${markdownEscape(fatalError)}\``] : []),
    "",
  ].join("\n");
  fs.writeFileSync(path.join(args.out, "marketplace-polish.md"), markdown, "utf8");
  console.log(`[marketplace-polish] status=${report.status}`);
  console.log(`[marketplace-polish] checks=${report.passed_check_count}/${report.check_count}`);
  console.log(`[marketplace-polish] provider_writes=${report.provider_writes}`);
  console.log(`[marketplace-polish] har=${harPath}`);
  if (!passed) process.exitCode = 1;
}

main().catch((error) => {
  console.error(`[marketplace-polish] fatal=${error instanceof Error ? error.message : String(error)}`);
  process.exitCode = 1;
});
