const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

function parseArgs(argv) {
  const args = { allowLocalhost: false, allowLocalWriteGuardProbes: false };
  for (let index = 2; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--allow-localhost") args.allowLocalhost = true;
    else if (arg === "--allow-local-write-guard-probes") args.allowLocalWriteGuardProbes = true;
    else if (arg === "--base-url") args.baseUrl = argv[++index];
    else if (arg === "--build-id") args.buildId = argv[++index];
    else if (arg === "--html-sha256") args.htmlSha256 = argv[++index];
    else if (arg === "--out") args.outDir = argv[++index];
    else if (arg === "--browser-channel") args.browserChannel = argv[++index];
    else throw new Error(`Unknown argument: ${arg}`);
  }
  return args;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function sha256(value) {
  return crypto.createHash("sha256").update(value, "utf8").digest("hex");
}

function safeRequestLabel(request) {
  try {
    const url = new URL(request.url());
    return `${request.method()} ${url.origin}${url.pathname}`;
  } catch {
    return `${request.method()} non-http-resource`;
  }
}

async function assertBlockedFrontendWrite(response, label) {
  assert([401, 403].includes(response.status()), `${label} expected HTTP 401 or 403`);
  const payload = await response.json();
  assert(payload.contract_version === "frontend-boundary-write-guard-v1", `${label} write-guard contract mismatch`);
  for (const field of ["accepted", "persisted", "service_auth_forwarded", "direct_provider_calls", "live_mcp_writes", "production_deploy", "secret_output"]) {
    assert(typeof payload[field] === "boolean" && payload[field] === false, `${label} expected ${field}=false`);
  }
  assert(response.headers()["x-superbrain-write-guard"] === "frontend-boundary-write-guard-v1", `${label} write-guard header mismatch`);
  return response.status();
}

function layoutProbe(page) {
  return page.evaluate(() => ({
    viewport_width: window.innerWidth,
    document_width: document.documentElement.scrollWidth,
    body_width: document.body.scrollWidth,
    horizontal_overflow: Math.max(document.documentElement.scrollWidth, document.body.scrollWidth) > window.innerWidth + 1,
  }));
}

async function main() {
  const args = parseArgs(process.argv);
  assert(args.baseUrl, "--base-url is required");
  assert(args.buildId && /^[A-Za-z0-9_-]{1,64}$/.test(args.buildId), "--build-id is invalid");
  assert(args.htmlSha256 && /^[a-f0-9]{64}$/.test(args.htmlSha256), "--html-sha256 is invalid");
  assert(args.outDir, "--out is required");
  assert(!args.browserChannel || /^[A-Za-z0-9_-]+$/.test(args.browserChannel), "--browser-channel is invalid");

  const base = new URL(args.baseUrl);
  const localHosts = new Set(["localhost", "127.0.0.1", "::1"]);
  const devOnly = localHosts.has(base.hostname);
  assert(base.protocol === "https:" || (devOnly && args.allowLocalhost && base.protocol === "http:"), "Browser proof requires HTTPS; localhost additionally requires --allow-localhost");
  assert(!args.allowLocalWriteGuardProbes || devOnly, "--allow-local-write-guard-probes is DEV-ONLY and requires localhost");
  assert(!base.username && !base.password, "--base-url cannot contain credentials");
  assert(!base.search && !base.hash, "--base-url cannot contain a query or fragment");
  assert(base.pathname === "/", "--base-url must be an origin without a path");

  const repoRoot = path.resolve(__dirname, "..");
  const outDir = path.resolve(repoRoot, args.outDir);
  assert(outDir.startsWith(`${repoRoot}${path.sep}`), "--out must stay inside the repository");
  fs.mkdirSync(outDir, { recursive: true });
  const { chromium } = require(path.join(repoRoot, "apps", "frontend", "node_modules", "playwright"));
  const launchOptions = { headless: true };
  if (args.browserChannel) launchOptions.channel = args.browserChannel;
  const browser = await chromium.launch(launchOptions);
  const profiles = [
    { name: "desktop", width: 1440, height: 960 },
    { name: "mobile", width: 390, height: 844 },
  ];
  const results = [];
  let browserVersion = null;
  let writeGuardProof = {
    executed: false,
    transport: "not_executed_without_explicit_local_gate",
  };

  try {
    browserVersion = browser.version();
    if (args.allowLocalWriteGuardProbes) {
      const guardContext = await browser.newContext();
      try {
        const buildCreate = await guardContext.request.post(new URL("/api/v1/build", base).href, { data: {} });
        const buildDelete = await guardContext.request.delete(new URL("/api/v1/build/invalid%21", base).href);
        const artifactCreate = await guardContext.request.post(new URL("/api/v1/workspace/artifacts", base).href, { data: {} });
        writeGuardProof = {
          executed: true,
          transport: "DEV-ONLY",
          build_create_http: await assertBlockedFrontendWrite(buildCreate, "Unauthenticated build create"),
          build_delete_http: await assertBlockedFrontendWrite(buildDelete, "Unauthenticated build delete"),
          workspace_artifact_create_http: await assertBlockedFrontendWrite(artifactCreate, "Unauthenticated workspace artifact create"),
          service_auth_forwarded: false,
        };
      } finally {
        await guardContext.close();
      }
    }
    for (const profile of profiles) {
      const context = await browser.newContext({ viewport: { width: profile.width, height: profile.height } });
      const unexpectedRequests = [];
      await context.route("**/*", async (route) => {
        const request = route.request();
        let url;
        try { url = new URL(request.url()); } catch { url = null; }
        const allowed = url && url.origin === base.origin && ["GET", "HEAD"].includes(request.method());
        if (!allowed) {
          unexpectedRequests.push(safeRequestLabel(request));
          await route.abort("blockedbyclient");
          return;
        }
        await route.continue();
      });
      const page = await context.newPage();
      const consoleErrors = [];
      const pageErrors = [];
      const failedRequests = [];
      page.on("console", (message) => {
        if (message.type() === "error") consoleErrors.push("console_error");
      });
      page.on("pageerror", () => pageErrors.push("page_error"));
      page.on("requestfailed", (request) => failedRequests.push(safeRequestLabel(request)));

      const appsResponse = await page.goto(new URL("/apps", base).href, { waitUntil: "networkidle", timeout: 60_000 });
      assert(appsResponse?.status() === 200, `${profile.name} /apps expected HTTP 200`);
      const gallery = page.getByTestId("builds-gallery");
      await gallery.waitFor({ state: "visible", timeout: 30_000 });
      const card = gallery.locator(`.bg-card:has(a[href="/run/${args.buildId}"])`);
      assert(await card.count() === 1, `${profile.name} expected one card for the exact persisted build id`);
      assert(await card.getByText("T2 LIVE PROOF", { exact: true }).count() === 1, `${profile.name} persisted build card title mismatch`);
      const openLink = card.locator(`a[href="/run/${args.buildId}"]`);
      assert(await openLink.count() === 1, `${profile.name} persisted build card link is ambiguous`);
      assert(await openLink.getAttribute("href") === `/run/${args.buildId}`, `${profile.name} gallery link does not target the persisted build`);
      const appsLayout = await layoutProbe(page);
      assert(!appsLayout.horizontal_overflow, `${profile.name} /apps has horizontal overflow`);
      await page.screenshot({ path: path.join(outDir, `apps-${profile.name}.png`), fullPage: true, animations: "disabled" });

      const listResponse = await context.request.get(new URL("/api/v1/builds?limit=24", base).href);
      assert(listResponse.status() === 200, `${profile.name} build list expected HTTP 200`);
      const listPayload = await listResponse.json();
      assert(listPayload.contract_version === "cloudflare-d1-stateful-runtime-v1", `${profile.name} build list contract mismatch`);
      assert(listPayload.persisted === true, `${profile.name} build list is not D1-backed`);
      assert(listPayload.direct_provider_calls === false, `${profile.name} build list reports a direct provider bypass`);
      assert(listPayload.secret_output === false, `${profile.name} build list reports secret output`);
      const listed = (Array.isArray(listPayload.builds) ? listPayload.builds : []).filter((build) => build.id === args.buildId);
      assert(listed.length === 1, `${profile.name} build list does not contain the persisted build exactly once`);
      assert(listed[0].live_provider_calls === true, `${profile.name} persisted build lost its live-provider provenance`);

      const runResponse = await page.goto(new URL(`/run/${args.buildId}`, base).href, { waitUntil: "networkidle", timeout: 60_000 });
      assert(runResponse?.status() === 200, `${profile.name} /run expected HTTP 200`);
      const frameElement = page.getByTestId("persisted-build-frame");
      await frameElement.waitFor({ state: "visible", timeout: 30_000 });
      const frame = frameElement.contentFrame();
      await frame.getByRole("heading", { name: "T2 LIVE PROOF" }).waitFor({ state: "visible" });
      await frame.getByRole("button", { name: "RUN" }).click();
      await frame.getByRole("button", { name: "DONE" }).waitFor({ state: "visible" });
      const runLayout = await layoutProbe(page);
      assert(!runLayout.horizontal_overflow, `${profile.name} /run has horizontal overflow`);
      await page.screenshot({ path: path.join(outDir, `run-${profile.name}.png`), fullPage: true, animations: "disabled" });

      const readResponse = await context.request.get(new URL(`/api/v1/build/${args.buildId}`, base).href);
      assert(readResponse.status() === 200, `${profile.name} persisted build read expected HTTP 200`);
      const readPayload = await readResponse.json();
      assert(readPayload.contract_version === "cloudflare-d1-stateful-runtime-v1", `${profile.name} build read contract mismatch`);
      assert(readPayload.persisted === true, `${profile.name} build read is not persisted`);
      assert(readPayload.live_provider_calls === true, `${profile.name} build read lost its live-provider provenance`);
      assert(readPayload.direct_provider_calls === false, `${profile.name} build read reports a direct provider bypass`);
      assert(readPayload.secret_output === false, `${profile.name} build read reports secret output`);
      assert(sha256(String(readPayload.html || "")) === args.htmlSha256, `${profile.name} persisted HTML hash mismatch`);
      assert(unexpectedRequests.length === 0, `${profile.name} attempted ${unexpectedRequests.length} cross-origin or mutating request(s)`);
      assert(consoleErrors.length === 0, `${profile.name} emitted ${consoleErrors.length} console error(s)`);
      assert(pageErrors.length === 0, `${profile.name} emitted ${pageErrors.length} page error(s)`);
      assert(failedRequests.length === 0, `${profile.name} had ${failedRequests.length} failed request(s)`);

      results.push({
        profile: profile.name,
        viewport: { width: profile.width, height: profile.height },
        apps_http: appsResponse.status(),
        build_list_http: listResponse.status(),
        run_http: runResponse.status(),
        build_read_http: readResponse.status(),
        gallery_visible: true,
        persisted_frame_visible: true,
        run_to_done_interaction: true,
        apps_layout: appsLayout,
        run_layout: runLayout,
        console_errors: 0,
        page_errors: 0,
        failed_requests: 0,
        unexpected_requests: 0,
      });
      await context.close();
    }
  } finally {
    await browser.close();
  }

  const report = {
    contract_version: "stateful-build-browser-proof-v1",
    status: "verified",
    checked_at: new Date().toISOString(),
    base_url: base.href.replace(/\/$/, ""),
    dev_only: devOnly,
    hosted_proof: !devOnly,
    browser_channel: args.browserChannel || "playwright-bundled-chromium",
    browser_version: browserVersion,
    build_id: args.buildId,
    html_sha256: args.htmlSha256,
    profile_count: results.length,
    gallery_visible: true,
    persisted_build_rendered: true,
    interaction_verified: true,
    seed_live_provider_calls: true,
    verifier_live_provider_calls: false,
    direct_provider_calls: false,
    secret_output: false,
    unexpected_requests: 0,
    frontend_unauthenticated_write_guards: writeGuardProof,
    profiles: results,
  };
  fs.writeFileSync(path.join(outDir, "report.json"), `${JSON.stringify(report, null, 2)}\n`, "utf8");
  console.log(`[stateful-build-browser] status=verified transport=${devOnly ? "DEV-ONLY" : "hosted"} profiles=${results.length} console_errors=0`);
}

main().catch((error) => {
  console.error(`[stateful-build-browser] status=failed error=${error.message}`);
  process.exitCode = 1;
});
