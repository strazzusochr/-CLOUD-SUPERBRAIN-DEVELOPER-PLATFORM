import { createHash } from "node:crypto";
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { expect, test, type FrameLocator, type Locator, type Page } from "@playwright/test";

const PRODUCT_PROMPT = "Baue ein 3D-Web-Game mit Three.js: drehbarer Würfel, Punktestand, Tastatursteuerung.";
const SESSION_COOKIE = "__Host-sb_session";
const baseUrl = (process.env.PRODUCT_ACCEPTANCE_BASE_URL ?? "http://localhost:8081").trim().replace(/\/+$/, "");
const expectedGatewayProvider = (process.env.PRODUCT_ACCEPTANCE_EXPECTED_GATEWAY_PROVIDER ?? "cloudflare-workers-ai").trim();
const expectedSourceCommitSha = (process.env.PRODUCT_ACCEPTANCE_SOURCE_COMMIT_SHA ?? "").trim();
const expectedSourceArchiveSha256 = (process.env.PRODUCT_ACCEPTANCE_SOURCE_ARCHIVE_SHA256 ?? "").trim();
const expectedDeploymentId = (process.env.PRODUCT_ACCEPTANCE_DEPLOYMENT_ID ?? "").trim();

type JsonRecord = Record<string, unknown>;

type PixelProbe = {
  pngSha256: string;
  pngBytes: number;
  width: number;
  height: number;
  nonZeroSamples: number;
  uniqueColorBuckets: number;
};

function sha256(value: string | Buffer): string {
  return createHash("sha256").update(value).digest("hex");
}

function asRecord(value: unknown): JsonRecord {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as JsonRecord
    : {};
}

function safeMessage(value: unknown): string {
  return String(value ?? "unknown")
    .replace(/\b(?:sk-|ghp_|github_pat_|glpat-|cfat|hf_)[A-Za-z0-9_.-]{8,}\b/gi, "[REDACTED]")
    .replace(/\b(token|secret|password|api[_-]?key)\s*[:=]\s*\S+/gi, "$1=[REDACTED]")
    .slice(0, 500);
}

function responseFailure(payload: JsonRecord): string {
  return safeMessage(payload.error ?? payload.reason ?? payload.note ?? "unknown response");
}

function responseMatches(responseUrl: string, method: string, pathname: string, expectedMethod = "POST"): boolean {
  try {
    const url = new URL(responseUrl);
    return url.origin === new URL(baseUrl).origin && url.pathname === pathname && method === expectedMethod;
  } catch {
    return false;
  }
}

async function pixelProbe(page: Page, canvas: Locator): Promise<PixelProbe> {
  const png = await canvas.screenshot();
  const pngDataUrl = `data:image/png;base64,${png.toString("base64")}`;
  const raster = await page.evaluate(async (sourceUrl) => {
    const source = new Image();
    source.src = sourceUrl;
    await source.decode();
    const sample = document.createElement("canvas");
    // A 64x64 raster keeps thin, legitimate WebGL wireframes measurable.
    sample.width = 64;
    sample.height = 64;
    const context = sample.getContext("2d", { willReadFrequently: true });
    if (!context) throw new Error("2D pixel probe unavailable");
    context.drawImage(source, 0, 0, sample.width, sample.height);
    const pixels = context.getImageData(0, 0, sample.width, sample.height).data;
    let nonZeroSamples = 0;
    const buckets = new Set<string>();
    for (let offset = 0; offset < pixels.length; offset += 4) {
      const red = pixels[offset];
      const green = pixels[offset + 1];
      const blue = pixels[offset + 2];
      const alpha = pixels[offset + 3];
      if (alpha > 0 && red + green + blue > 0) nonZeroSamples += 1;
      if (alpha > 0) buckets.add(`${red >> 4}:${green >> 4}:${blue >> 4}:${alpha >> 6}`);
    }
    return {
      width: source.naturalWidth,
      height: source.naturalHeight,
      nonZeroSamples,
      uniqueColorBuckets: buckets.size,
    };
  }, pngDataUrl);
  return {
    pngSha256: sha256(png),
    pngBytes: png.length,
    ...raster,
  };
}

async function findRenderedWebGlCanvas(page: Page, frame: FrameLocator): Promise<Locator> {
  let selected: Locator | null = null;
  await expect.poll(async () => {
    const canvases = frame.locator("canvas");
    const count = await canvases.count();
    for (let index = 0; index < count; index += 1) {
      const canvas = canvases.nth(index);
      if (!(await canvas.isVisible().catch(() => false))) continue;
      const context = await canvas.evaluate((element: HTMLCanvasElement) => {
        const gl = element.getContext("webgl2") || element.getContext("webgl");
        return {
          available: Boolean(gl),
          drawingWidth: gl?.drawingBufferWidth ?? 0,
          drawingHeight: gl?.drawingBufferHeight ?? 0,
        };
      }).catch(() => ({ available: false, drawingWidth: 0, drawingHeight: 0 }));
      if (context.available && context.drawingWidth >= 32 && context.drawingHeight >= 32) {
        selected = canvas;
        return index;
      }
    }
    return -1;
  }, {
    message: "generated artifact must expose a visible, initialized WebGL canvas",
    timeout: 45_000,
    intervals: [250, 500, 1_000],
  }).toBeGreaterThanOrEqual(0);
  if (!selected) throw new Error("WebGL canvas selection failed");
  await page.waitForTimeout(500);
  return selected;
}

async function visibleState(frame: FrameLocator): Promise<{ textSha256: string; stateSha256: string }> {
  const state = await frame.locator("body").evaluate((body) => {
    const text = ((body as HTMLElement).innerText || "").replace(/\s+/g, " ").trim();
    const marked = Array.from(body.querySelectorAll(
      "[data-score], [data-state], [data-rotation], [data-position], #score, .score, [class*='score']",
    )).slice(0, 20).map((element) => ({
      tag: element.tagName,
      id: element.id,
      className: typeof element.className === "string" ? element.className : "",
      text: (element.textContent || "").replace(/\s+/g, " ").trim().slice(0, 200),
      data: { ...(element as HTMLElement).dataset },
    }));
    return { text, marked };
  });
  return {
    textSha256: sha256(state.text),
    stateSha256: sha256(JSON.stringify(state)),
  };
}

test.describe.configure({ mode: "serial" });

test("real prompt builds, runs, interacts, and reloads the persisted 3D game", async ({ page, context }, testInfo) => {
  test.setTimeout(240_000);

  const artifactDir = process.env.PRODUCT_ACCEPTANCE_ARTIFACT_DIR?.trim()
    ? path.resolve(process.env.PRODUCT_ACCEPTANCE_ARTIFACT_DIR)
    : testInfo.outputDir;
  const screenshotPath = path.join(artifactDir, "product-acceptance.png");
  const reportPath = path.join(artifactDir, "report.json");
  await mkdir(artifactDir, { recursive: true });
  const origin = new URL(baseUrl);
  const devOnly = ["localhost", "127.0.0.1", "::1"].includes(origin.hostname);

  const consoleErrors: string[] = [];
  const pageErrors: string[] = [];
  const failedRequests: string[] = [];
  let buildPostCount = 0;
  let caughtFailure: unknown = null;
  const startedAt = new Date().toISOString();
  const report: JsonRecord = {
    contract_version: "product-acceptance-3d-game-v1",
    status: "running",
    started_at: startedAt,
    completed_at: null,
    base_url: baseUrl,
    dev_only: devOnly,
    hosted_proof: !devOnly,
    proof_scope: devOnly ? "dev_only_localhost" : "hosted_https",
    source_binding: {
      source_commit_sha: expectedSourceCommitSha || null,
      source_archive_sha256: expectedSourceArchiveSha256 || null,
      deployment_id: expectedDeploymentId || null,
    },
    prompt: PRODUCT_PROMPT,
    prompt_sha256: sha256(PRODUCT_PROMPT),
    expected_gateway_provider: expectedGatewayProvider,
    auth: {},
    build: {},
    html: {},
    run: {},
    interaction: {},
    persistence: {},
    browser: {
      project: testInfo.project.name,
      version: page.context().browser()?.version() ?? "unknown",
    },
    screenshot: "product-acceptance.png",
    mocks_used: false,
    route_interception_used: false,
    secret_output: false,
  };

  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(safeMessage(message.text()));
  });
  page.on("pageerror", (error) => pageErrors.push(safeMessage(error.message)));
  page.on("requestfailed", (request) => {
    const failure = request.failure()?.errorText ?? "request_failed";
    failedRequests.push(safeMessage(`${request.method()} ${new URL(request.url()).pathname}: ${failure}`));
  });
  page.on("request", (request) => {
    if (responseMatches(request.url(), request.method(), "/api/v1/build")) buildPostCount += 1;
  });

  try {
    expect(origin.username || origin.password, "base URL must not contain credentials").toBe("");
    if (devOnly) {
      expect(origin.port || (origin.protocol === "https:" ? "443" : "80"), "DEV-ONLY product acceptance must target localhost:8081").toBe("8081");
    } else {
      expect(origin.protocol, "hosted product acceptance requires HTTPS").toBe("https:");
      expect(origin.port || "443", "hosted product acceptance requires standard HTTPS").toBe("443");
      expect(origin.hostname.endsWith(".vercel.app"), "hosted product acceptance requires a Vercel deployment origin").toBe(true);
      expect(expectedSourceCommitSha, "hosted proof requires a source commit").toMatch(/^[0-9a-f]{40}$/);
      expect(expectedSourceArchiveSha256, "hosted proof requires a source archive hash").toMatch(/^[0-9a-f]{64}$/);
      expect(expectedDeploymentId, "hosted proof requires a Vercel deployment id").toMatch(/^dpl_[A-Za-z0-9]+$/);
    }
    expect(expectedGatewayProvider, "expected gateway provider is required").not.toBe("");

    const sessionBootstrapPromise = page.waitForResponse((candidate) =>
      responseMatches(candidate.url(), candidate.request().method(), "/api/v1/auth/session", "GET"),
    );
    const loginNavigation = await page.goto(`${baseUrl}/login`, { waitUntil: "domcontentloaded", timeout: 60_000 });
    expect(loginNavigation?.status(), "login page HTTP status").toBe(200);
    const sessionBootstrap = await sessionBootstrapPromise;
    expect(sessionBootstrap.status(), "session bootstrap HTTP status").toBe(200);
    const signInResponsePromise = page.waitForResponse((candidate) =>
      responseMatches(candidate.url(), candidate.request().method(), "/api/v1/auth/session"),
    );
    await page.getByTestId("rl-signin").click();
    const signInResponse = await signInResponsePromise;
    const signIn = asRecord(await signInResponse.json());
    expect(signInResponse.status(), `guest sign-in failed: ${responseFailure(signIn)}`).toBe(200);
    expect(signIn.status).toBe("signed_in");
    expect(asRecord(signIn.user).provider).toBe("guest");
    expect(signIn.session_scope).toBe(devOnly ? "signed_http_only_cookie" : "stateful_http_only_cookie");
    expect(signIn.persisted).toBe(!devOnly);
    expect(signIn.session_backend).toBe(devOnly ? "local-hmac" : "cloudflare-d1");
    expect(signIn.external_provider_write).toBe(false);
    const sessionCookie = (await context.cookies()).find((cookie) => cookie.name === SESSION_COOKIE);
    expect(sessionCookie?.httpOnly).toBe(true);
    expect(sessionCookie?.secure).toBe(true);
    expect(sessionCookie?.sameSite).toBe("Strict");
    if (devOnly) {
      expect(sessionCookie?.value.split(".")).toHaveLength(2);
    } else {
      expect(sessionCookie?.value).toMatch(/^[A-Za-z0-9_-]{43}$/);
      expect(sessionCookie?.value.split(".")).toHaveLength(1);
    }

    const sessionRead = await page.evaluate(async () => {
      const response = await fetch("/api/v1/auth/session", { cache: "no-store" });
      return { status: response.status, payload: await response.json() };
    });
    expect(sessionRead.status).toBe(200);
    expect(sessionRead.payload.status).toBe("signed_in");
    expect(sessionRead.payload.session_id).toBe(signIn.session_id);
    report.auth = {
      status: "signed_in",
      provider: "guest",
      session_scope: signIn.session_scope,
      session_backend: signIn.session_backend,
      persisted: signIn.persisted,
      http_only_cookie: sessionCookie?.httpOnly === true,
      secure_cookie: sessionCookie?.secure === true,
      same_site: sessionCookie?.sameSite,
      credential_segments: sessionCookie?.value.split(".").length,
      credential_format: devOnly ? "hmac_signed_payload" : "opaque_base64url_256_bit",
      external_provider_write: false,
      session_id_sha256: sha256(String(signIn.session_id)),
    };

    const runtimeReadyResponsePromise = page.waitForResponse((candidate) =>
      responseMatches(candidate.url(), candidate.request().method(), "/api/v1/builds", "GET"),
      { timeout: 60_000 },
    );
    await page.getByRole("link", { name: /Werkbank/ }).click();
    await expect(page).toHaveURL(`${baseUrl}/workbench`);
    await expect(page.getByTestId("workbench-studio")).toBeVisible();
    const runtimeReadyResponse = await runtimeReadyResponsePromise;
    const runtimeReadyPayload = asRecord(await runtimeReadyResponse.json());
    expect(runtimeReadyResponse.status(), `build runtime unavailable: ${responseFailure(runtimeReadyPayload)}`).toBe(200);
    expect(runtimeReadyPayload.persisted, "workbench runtime must expose persisted storage").toBe(true);
    await expect(page.getByTestId("ws-build")).toBeEnabled();
    await page.getByLabel("Beschreibung für die App-Erstellung").fill(PRODUCT_PROMPT);
    await expect(page.getByLabel("Beschreibung für die App-Erstellung")).toHaveValue(PRODUCT_PROMPT);

    const buildResponsePromise = page.waitForResponse((candidate) =>
      responseMatches(candidate.url(), candidate.request().method(), "/api/v1/build"),
      { timeout: 120_000 },
    );
    await page.getByTestId("ws-build").click();
    const buildResponse = await buildResponsePromise;
    const build = asRecord(await buildResponse.json());
    const buildId = String(build.id ?? "");
    const html = String(build.html ?? "");

    report.build = {
      response_status: buildResponse.status(),
      response_source: buildResponse.headers()["x-superbrain-source"] ?? null,
      build_id: buildId || null,
      contract_version: build.contract_version ?? null,
      model: build.model ?? null,
      gateway_mode: build.gateway_mode ?? null,
      gateway_provider: build.gateway_provider ?? null,
      live_provider_calls: build.live_provider_calls ?? null,
      audit_persisted: build.audit_persisted ?? null,
      persisted: build.persisted ?? null,
      share_path: build.share_path ?? null,
      direct_provider_calls: build.direct_provider_calls ?? null,
      live_mcp_writes: build.live_mcp_writes ?? null,
      secret_output: build.secret_output ?? null,
    };

    expect(buildResponse.status(), `build failed: ${responseFailure(build)}`).toBe(200);
    expect(buildResponse.headers()["x-superbrain-source"]).toBe("llm-gateway-boundary");
    expect(buildPostCount, "exactly one product build POST is allowed").toBe(1);
    expect(buildId).toMatch(/^[A-Za-z0-9_-]{1,64}$/);
    expect(build.live_provider_calls, "build must document a real provider call").toBe(true);
    expect(build.direct_provider_calls, "frontend must not bypass the LLM Gateway").toBe(false);
    expect(build.live_mcp_writes).toBe(false);
    expect(build.secret_output).toBe(false);
    expect(build.audit_persisted, "build audit must be persisted").toBe(true);
    expect(build.persisted, "generated build must be persisted").toBe(true);
    expect(build.share_path).toBe(`/run/${buildId}`);
    expect(build.gateway_provider, "unexpected live gateway provider").toBe(expectedGatewayProvider);
    expect(String(build.gateway_mode)).not.toMatch(/^(?:|unknown|dry[-_ ]?run|deterministic)$/i);
    expect(String(build.model)).not.toMatch(/^(?:|unknown)$/i);

    const htmlMarkers = {
      complete_document: /^\s*<!doctype html/i.test(html) && /<\/html>\s*$/i.test(html),
      canvas: /(?:<canvas\b|WebGLRenderer|createElement\s*\(\s*["']canvas["'])/i.test(html),
      three_js: /(?:\bTHREE\b|three(?:\.min)?\.js|three@[\d.]+)/i.test(html),
      webgl: /(?:WebGLRenderer|getContext\s*\(\s*["']webgl2?["']|WebGLRenderingContext)/i.test(html),
      keyboard_control: /(?:addEventListener\s*\(\s*["']key(?:down|up)["']|onkey(?:down|up)\s*=|KeyboardEvent)/i.test(html),
    };
    report.html = {
      sha256: sha256(html),
      bytes: Buffer.byteLength(html),
      markers: htmlMarkers,
    };
    expect(htmlMarkers.complete_document).toBe(true);
    expect(htmlMarkers.canvas, "generated HTML must contain a canvas").toBe(true);
    expect(htmlMarkers.three_js, "generated HTML must contain Three.js code").toBe(true);
    expect(htmlMarkers.webgl, "generated HTML must initialize WebGL").toBe(true);
    expect(htmlMarkers.keyboard_control, "generated game must declare keyboard controls").toBe(true);
    await expect(page.getByTestId("ws-log")).toContainText("Live-Vorschau bereit", { timeout: 45_000 });
    await expect(page.getByText("live_provider_calls=true", { exact: true })).toBeVisible();
    await expect(page.getByText(`/run/${buildId}`, { exact: true })).toBeVisible();

    const initialReadPromise = page.waitForResponse((candidate) => {
      try {
        const url = new URL(candidate.url());
        return url.origin === new URL(baseUrl).origin
          && url.pathname === `/api/v1/build/${buildId}`
          && candidate.request().method() === "GET";
      } catch {
        return false;
      }
    });
    const runNavigation = await page.goto(`${baseUrl}/run/${buildId}`, { waitUntil: "domcontentloaded", timeout: 60_000 });
    const initialReadResponse = await initialReadPromise;
    const initialRead = asRecord(await initialReadResponse.json());
    expect(runNavigation?.status()).toBe(200);
    expect(initialReadResponse.status()).toBe(200);
    expect(initialRead.id).toBe(buildId);
    expect(initialRead.persisted).toBe(true);
    // Audit atomicity is asserted on the create response; public reads do not join the audit table.
    expect(initialRead.live_provider_calls).toBe(true);
    expect(initialRead.gateway_provider).toBe(expectedGatewayProvider);
    expect(initialRead.direct_provider_calls).toBe(false);
    expect(initialRead.live_mcp_writes).toBe(false);
    expect(initialRead.secret_output).toBe(false);
    expect(sha256(String(initialRead.html ?? ""))).toBe(sha256(html));

    const frameElement = page.getByTestId("persisted-build-frame");
    await expect(frameElement).toBeVisible({ timeout: 30_000 });
    const frame = frameElement.contentFrame();
    const canvas = await findRenderedWebGlCanvas(page, frame);
    const beforeState = await visibleState(frame);
    const beforePixels = await pixelProbe(page, canvas);
    report.run = {
      route: `/run/${buildId}`,
      http_status: runNavigation?.status() ?? null,
      webgl_canvas_visible: true,
      nonblank_canvas: false,
      initial_pixel_probe: beforePixels,
    };
    expect(beforePixels.pngBytes).toBeGreaterThan(1_000);
    expect(beforePixels.nonZeroSamples, "rendered canvas must contain visible pixels").toBeGreaterThan(16);
    expect(beforePixels.uniqueColorBuckets, "rendered canvas must not be a flat placeholder").toBeGreaterThan(4);

    await canvas.click();
    await page.waitForTimeout(350);
    const afterClickPixels = await pixelProbe(page, canvas);
    await page.keyboard.press("ArrowRight");
    await page.keyboard.press("ArrowUp");
    await page.keyboard.press("Space");
    await page.waitForTimeout(700);
    const afterState = await visibleState(frame);
    const afterKeyboardPixels = await pixelProbe(page, canvas);
    const clickPixelChanged = beforePixels.pngSha256 !== afterClickPixels.pngSha256;
    const keyboardPixelChanged = afterClickPixels.pngSha256 !== afterKeyboardPixels.pngSha256;
    const visibleStateChanged = beforeState.stateSha256 !== afterState.stateSha256
      || beforeState.textSha256 !== afterState.textSha256;
    expect(
      keyboardPixelChanged || clickPixelChanged || visibleStateChanged,
      "keyboard/click must cause a measurable visible state or pixel change",
    ).toBe(true);
    report.interaction = {
      input_events: ["click", "ArrowRight", "ArrowUp", "Space"],
      click_pixel_changed: clickPixelChanged,
      keyboard_pixel_changed: keyboardPixelChanged,
      visible_dom_state_changed: visibleStateChanged,
      before: beforePixels,
      after_click: afterClickPixels,
      after_keyboard: afterKeyboardPixels,
    };

    const reloadReadPromise = page.waitForResponse((candidate) => {
      try {
        const url = new URL(candidate.url());
        return url.origin === new URL(baseUrl).origin
          && url.pathname === `/api/v1/build/${buildId}`
          && candidate.request().method() === "GET";
      } catch {
        return false;
      }
    });
    await page.reload({ waitUntil: "domcontentloaded", timeout: 60_000 });
    const reloadReadResponse = await reloadReadPromise;
    const reloadRead = asRecord(await reloadReadResponse.json());
    expect(reloadReadResponse.status()).toBe(200);
    expect(reloadRead.id).toBe(buildId);
    expect(reloadRead.persisted).toBe(true);
    expect(reloadRead.audit_persisted).toBe(true);
    expect(reloadRead.live_provider_calls).toBe(true);
    expect(reloadRead.gateway_provider).toBe(expectedGatewayProvider);
    const reloadedHtmlSha256 = sha256(String(reloadRead.html ?? ""));
    expect(reloadedHtmlSha256).toBe(sha256(html));

    const reloadedFrameElement = page.getByTestId("persisted-build-frame");
    await expect(reloadedFrameElement).toBeVisible({ timeout: 30_000 });
    const reloadedFrame = reloadedFrameElement.contentFrame();
    const reloadedCanvas = await findRenderedWebGlCanvas(page, reloadedFrame);
    const reloadedPixels = await pixelProbe(page, reloadedCanvas);
    expect(reloadedPixels.nonZeroSamples).toBeGreaterThan(16);
    expect(reloadedPixels.uniqueColorBuckets).toBeGreaterThan(4);
    report.run = {
      route: `/run/${buildId}`,
      http_status: runNavigation?.status() ?? null,
      webgl_canvas_visible: true,
      nonblank_canvas: true,
      initial_pixel_probe: beforePixels,
      reloaded_pixel_probe: reloadedPixels,
    };
    report.persistence = {
      build_id: buildId,
      initial_read_http: initialReadResponse.status(),
      reload_read_http: reloadReadResponse.status(),
      persisted: reloadRead.persisted,
      audit_persisted: reloadRead.audit_persisted,
      live_provider_calls: reloadRead.live_provider_calls,
      gateway_provider: reloadRead.gateway_provider,
      initial_html_sha256: sha256(String(initialRead.html ?? "")),
      reloaded_html_sha256: reloadedHtmlSha256,
      same_artifact_after_reload: reloadedHtmlSha256 === sha256(html),
    };

    expect(consoleErrors, `console errors: ${consoleErrors.join(" | ")}`).toEqual([]);
    expect(pageErrors, `page errors: ${pageErrors.join(" | ")}`).toEqual([]);
    expect(buildPostCount).toBe(1);
    report.status = "verified";
  } catch (error) {
    caughtFailure = error;
    report.status = "failed";
    report.failure = safeMessage(error instanceof Error ? error.message : error);
    throw error;
  } finally {
    report.completed_at = new Date().toISOString();
    report.build_post_count = buildPostCount;
    report.console_errors = consoleErrors;
    report.console_error_count = consoleErrors.length;
    report.page_errors = pageErrors;
    report.page_error_count = pageErrors.length;
    report.failed_requests = failedRequests;
    report.failed_request_count = failedRequests.length;
    if (caughtFailure === null && report.status !== "verified") report.status = "failed";
    await page.screenshot({ path: screenshotPath, fullPage: true }).catch((error) => {
      report.screenshot_error = safeMessage(error instanceof Error ? error.message : error);
    });
    await writeFile(reportPath, `${JSON.stringify(report, null, 2)}\n`, "utf8");
  }
});
