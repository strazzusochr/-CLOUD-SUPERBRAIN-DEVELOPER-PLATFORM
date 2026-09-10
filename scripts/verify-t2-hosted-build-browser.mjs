import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const require = createRequire(import.meta.url);
const { chromium } = require(path.join(repoRoot, "apps", "frontend", "node_modules", "playwright"));

function parseArgs(argv) {
  const result = { browserChannel: "chrome" };
  for (let index = 2; index < argv.length; index += 1) {
    if (argv[index] === "--base-url") result.baseUrl = argv[++index];
    else if (argv[index] === "--out") result.outDir = argv[++index];
    else if (argv[index] === "--browser-channel") result.browserChannel = argv[++index];
  }
  return result;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function sha256(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

const args = parseArgs(process.argv);
assert(args.baseUrl, "--base-url is required");
assert(args.outDir, "--out is required");
const baseUrl = String(args.baseUrl).replace(/\/$/, "");
const target = new URL(baseUrl);
assert(target.protocol === "https:", "T2 hosted proof requires HTTPS");
assert(!["localhost", "127.0.0.1", "::1"].includes(target.hostname), "T2 hosted proof cannot use localhost");

const outDir = path.resolve(repoRoot, args.outDir);
fs.mkdirSync(outDir, { recursive: true });
const prompt = "Create a tiny page. It must visibly contain the exact heading T2 LIVE PROOF and one button labeled RUN. When clicked, the button text must become DONE. Use only inline CSS and JavaScript.";
const consoleErrors = [];
const pageErrors = [];
let buildPostCount = 0;
const startedAt = new Date().toISOString();
const browser = await chromium.launch({ headless: true, channel: args.browserChannel });

try {
  const context = await browser.newContext({ viewport: { width: 1440, height: 960 } });
  const page = await context.newPage();
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(message.text());
  });
  page.on("pageerror", (error) => pageErrors.push(error.message));
  page.on("request", (request) => {
    const url = new URL(request.url());
    if (request.method() === "POST" && url.pathname === "/api/v1/build") buildPostCount += 1;
  });

  await page.goto(`${baseUrl}/workbench`, { waitUntil: "domcontentloaded", timeout: 60_000 });
  await page.getByTestId("workbench-studio").waitFor({ state: "visible", timeout: 30_000 });
  await page.getByRole("textbox", { name: "Beschreibung fur die App-Erstellung" }).fill(prompt).catch(async () => {
    await page.locator(".wb-composer-input").first().fill(prompt);
  });

  const responsePromise = page.waitForResponse((response) => {
    const url = new URL(response.url());
    return response.request().method() === "POST" && url.pathname === "/api/v1/build";
  }, { timeout: 60_000 });
  await page.getByTestId("ws-build").click();
  const response = await responsePromise;
  const payload = await response.json();

  assert(response.status() === 200, `Hosted build returned HTTP ${response.status()}: ${payload.error || payload.reason || payload.note || "unknown"}`);
  assert(response.headers()["x-superbrain-source"] === "llm-gateway-boundary", "Hosted build response did not cross the LLM Gateway boundary");
  assert(payload.live_provider_calls === true, "Hosted build did not prove a live provider call behind the gateway");
  assert(payload.direct_provider_calls === false, "Hosted build claimed a direct frontend provider call");
  assert(payload.gateway_provider === "cloudflare-workers-ai", "Hosted build did not identify Workers AI as the gateway provider");
  assert(/^<!doctype html>/i.test(String(payload.html || "").trim()), "Generated output is not a complete HTML document");
  assert(/<\/body>\s*<\/html>\s*$/i.test(String(payload.html || "").trim()), "Generated HTML is incomplete");
  assert(buildPostCount === 1, `Expected exactly one hosted build POST, saw ${buildPostCount}`);

  await page.getByTestId("ws-frame").waitFor({ state: "visible", timeout: 30_000 });
  await page.getByTestId("ws-log").getByText("Live-Vorschau bereit", { exact: false }).waitFor({ state: "visible", timeout: 30_000 });
  await page.getByText("live_provider_calls=true", { exact: true }).waitFor({ state: "visible", timeout: 30_000 });
  const preview = page.frameLocator('[data-testid="ws-frame"]');
  await preview.getByText("T2 LIVE PROOF", { exact: true }).waitFor({ state: "visible", timeout: 30_000 });
  const generatedButton = preview.getByRole("button", { name: "RUN", exact: true });
  await generatedButton.click();
  await preview.getByRole("button", { name: "DONE", exact: true }).waitFor({ state: "visible", timeout: 10_000 });

  const screenshotPath = path.join(outDir, "workbench-live-build.png");
  await page.screenshot({ path: screenshotPath, fullPage: true });
  fs.writeFileSync(path.join(outDir, "generated.html"), payload.html, "utf8");
  assert(consoleErrors.length === 0, `Console errors detected: ${consoleErrors.join(" | ")}`);
  assert(pageErrors.length === 0, `Page errors detected: ${pageErrors.join(" | ")}`);

  const report = {
    contract_version: "t2-hosted-workers-ai-build-browser-proof-v1",
    status: "verified",
    generated_at: new Date().toISOString(),
    started_at: startedAt,
    base_url: baseUrl,
    route: "/workbench",
    browser_channel: args.browserChannel,
    browser_version: browser.version(),
    build_post_count: buildPostCount,
    live_provider_call_count_upper_bound: 1,
    prompt_sha256: sha256(prompt),
    response_status: response.status(),
    response_source: response.headers()["x-superbrain-source"],
    model: payload.model,
    gateway_mode: payload.gateway_mode,
    gateway_provider: payload.gateway_provider,
    live_provider_calls: payload.live_provider_calls,
    direct_provider_calls: payload.direct_provider_calls,
    persisted: payload.persisted,
    html_sha256: sha256(payload.html),
    html_bytes: Buffer.byteLength(payload.html),
    preview_heading_verified: true,
    preview_interaction_verified: true,
    console_errors: consoleErrors,
    page_errors: pageErrors,
    screenshot: "workbench-live-build.png",
    generated_html: "generated.html",
    secret_output: false,
  };
  fs.writeFileSync(path.join(outDir, "report.json"), `${JSON.stringify(report, null, 2)}\n`, "utf8");
  console.log(`[t2-hosted-build] status=verified posts=1 provider=${payload.gateway_provider} browser=${browser.version()}`);
} finally {
  await browser.close();
}
