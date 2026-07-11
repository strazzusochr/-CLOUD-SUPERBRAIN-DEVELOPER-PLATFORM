import { test, expect } from "@playwright/test";

/** The 22 spec page routes + the 3 organism subroutes. */
const PAGE_ROUTES = [
  "/", "/home", "/login", "/workbench", "/files", "/files/local",
  "/organism", "/organism/live", "/organism/replay", "/organism/map",
  "/agents", "/tools", "/marketplace", "/observe", "/evidence", "/settings",
  "/diagnostics", "/design-system", "/responsive", "/technology", "/open-source",
  "/games", "/media", "/docs-output", "/apps",
];

test.describe("Cloud Superbrain platform", () => {
  test.beforeEach(async ({ page }) => {
    await page.emulateMedia({ reducedMotion: "no-preference" });
  });

  test("all page routes return 200", async ({ page }) => {
    for (const route of PAGE_ROUTES) {
      const resp = await page.goto(route, { waitUntil: "domcontentloaded" });
      expect(resp?.status(), `route ${route}`).toBe(200);
    }
  });

  test("organism contract API serves the v1 contract", async ({ request }) => {
    const resp = await request.get("/api/v1/organism/contract");
    expect(resp.status()).toBe(200);
    const json = await resp.json();
    expect(json.contract_version).toBe("organism-surface-v1");
    expect(Array.isArray(json.hubs)).toBeTruthy();
    expect(json.hubs.length).toBe(8);
  });

  test("organism live-state / replay are spec-only when no backend is configured", async ({ request }) => {
    for (const path of ["live-state", "replay"]) {
      const resp = await request.get(`/api/v1/organism/${path}`);
      expect(resp.status(), path).toBe(200);
      const json = await resp.json();
      expect(json.source, path).toBe("spec_only");
      expect(json.live, path).toBe(false);
      expect(json.non_claims.join(" "), path).toMatch(/no secret|no live provider/i);
    }
  });

  test("organism events stay honest: backend/platform-audit when configured, spec-only otherwise", async ({ request }) => {
    const resp = await request.get("/api/v1/organism/events");
    expect(resp.status()).toBe(200);
    const json = await resp.json();
    expect(json.contract_version).toBe("organism-events-v1");
    expect(json.source).toMatch(/agent-api|platform-audit|spec_only/);
    expect(json.source_kind).toMatch(/agent_api_redacted|platform_audit|spec_only/);
    expect(typeof json.live).toBe("boolean");
    expect(json.events.length).toBeGreaterThan(0);
    expect(JSON.stringify(json)).not.toMatch(/session_id|user_id|"details"/);
    expect(json.non_claims.join(" ")).toMatch(/no secret|no live provider/i);
  });

  test("organism topology / regions / safety contracts are wired and read-only", async ({ request }) => {
    const topologyResp = await request.get("/api/v1/organism/topology");
    expect(topologyResp.status()).toBe(200);
    const topology = await topologyResp.json();
    expect(topology.contract_version).toBe("organism-topology-v1");
    const nodeIds = new Set((topology.nodes as Array<{ id: string }>).map((node) => node.id));
    expect(nodeIds.has("layer:FE")).toBeTruthy();
    expect(nodeIds.has("agent:planner")).toBeTruthy();
    expect(nodeIds.has("tool:mcp_gateway")).toBeTruthy();
    expect(nodeIds.has("model:deepseek-ai/DeepSeek-V4-Pro")).toBeTruthy();
    for (const edge of topology.edges as Array<{ from: string; to: string }>) {
      expect(nodeIds.has(edge.from), `edge source ${edge.from}`).toBeTruthy();
      expect(nodeIds.has(edge.to), `edge target ${edge.to}`).toBeTruthy();
    }
    expect((topology.nodes as Array<{ writes: boolean }>).every((node) => node.writes === false)).toBeTruthy();

    const regionsResp = await request.get("/api/v1/organism/regions");
    expect(regionsResp.status()).toBe(200);
    const regions = await regionsResp.json();
    expect(regions.contract_version).toBe("organism-regions-v1");
    expect(regions.regions.length).toBeGreaterThanOrEqual(10);
    expect(regions.regions.every((region: { secret_output: boolean; writes: boolean }) => !region.secret_output && !region.writes)).toBeTruthy();

    const safetyResp = await request.get("/api/v1/organism/safety");
    expect(safetyResp.status()).toBe(200);
    const safety = await safetyResp.json();
    expect(safety.contract_version).toBe("organism-safety-v1");
    expect(safety.data_rules.no_fake_live).toBe(true);
    expect(safety.data_rules.secret_output).toBe(false);
    expect(safety.data_rules.provider_write).toBe(false);
  });

  test("workspace wiring maps all 22 pages to organism regions and verifiers", async ({ request }) => {
    const resp = await request.get("/api/v1/workspace/wiring");
    expect(resp.status()).toBe(200);
    const json = await resp.json();
    expect(json.contract_version).toBe("workspace-surface-wiring-v1");
    expect(json.evidence_ref).toBe("workspace_surface_wiring_visible");
    expect(json.page_count).toBe(22);
    expect(json.surfaces.length).toBe(22);
    const routes = new Set(json.surfaces.map((surface: { route: string }) => surface.route));
    for (const route of ["/home", "/workbench", "/organism", "/agents", "/files", "/tools", "/evidence", "/open-source"]) {
      expect(routes.has(route), route).toBeTruthy();
    }
    for (const surface of json.surfaces as Array<{
      brainRegion: string;
      hub: string;
      dataSources: string[];
      verifierRefs: string[];
      live: boolean;
      writes: boolean;
      secretOutput: boolean;
    }>) {
      expect(surface.brainRegion).toBeTruthy();
      expect(surface.hub).toBeTruthy();
      expect(surface.dataSources.length).toBeGreaterThan(0);
      expect(surface.verifierRefs.length).toBeGreaterThan(0);
      expect(surface.live).toBe(false);
      expect(surface.writes).toBe(false);
      expect(surface.secretOutput).toBe(false);
    }
  });

  test("workbench hides budget until a paid or metered option is selected", async ({ page }) => {
    await page.goto("/workbench", { waitUntil: "networkidle" });
    await expect(page.getByText("Metered Budget")).toHaveCount(0);
    await expect(page.getByText("paid/metered Capability")).toHaveCount(0);
    await expect(page.getByTestId("workbench-studio")).toBeVisible();
    await expect(page.getByText("Dateien", { exact: true })).toBeVisible();
    await expect(page.getByText("Build-Protokoll", { exact: true })).toBeVisible();
    await expect(page.getByRole("button", { name: "Vorschau" })).toBeVisible();

    await page.goto("/workbench?billing=paid", { waitUntil: "networkidle" });
    await expect(page.getByTestId("workbench-studio")).toBeVisible();
    await expect(page.getByText("Metered Budget")).toHaveCount(0);
    await expect(page.getByText("paid/metered Capability")).toHaveCount(0);
  });

  test("consolidated pages render real content (not re-export shortcuts)", async ({ page }) => {
    await page.goto("/technology", { waitUntil: "domcontentloaded" });
    await expect(page.getByText("Fähigkeiten nach Kategorie")).toBeVisible();
    await expect(page.getByText("Cloud-Provider-Inventar")).toBeVisible();

    await page.goto("/responsive", { waitUntil: "domcontentloaded" });
    await expect(page.getByText("Breakpoint-Matrix")).toBeVisible();
    await expect(page.getByText("Accessibility & Reduced Motion")).toBeVisible();

    await page.goto("/open-source", { waitUntil: "domcontentloaded" });
    await expect(page.getByText(/Kernkomponenten und ihre Lizenzen/)).toBeVisible();
    await expect(page.getByText("MIT").first()).toBeVisible();
  });

  test("removed alias/duplicate routes are gone (404)", async ({ page }) => {
    for (const dead of ["/about/stack", "/about/open-source", "/design-system/responsive"]) {
      const resp = await page.goto(dead, { waitUntil: "domcontentloaded" });
      expect(resp?.status(), `dead route ${dead}`).toBe(404);
    }
  });

  test("organism GLB core asset is served and fetched by the canvas", async ({ page, request }) => {
    const glb = await request.get("/organism/core.glb");
    expect(glb.status()).toBe(200);
    const bytes = await glb.body();
    expect(bytes.length, "core.glb byte size").toBeGreaterThan(1000);
    expect(bytes.subarray(0, 4).toString("ascii"), "glTF magic").toBe("glTF");

    const fetched: string[] = [];
    page.on("requestfinished", (r) => {
      if (r.url().includes("core.glb")) fetched.push(r.url());
    });
    await page.goto("/organism", { waitUntil: "networkidle" });
    await page.waitForTimeout(3000);
    expect(fetched.length, "canvas fetched core.glb").toBeGreaterThan(0);
  });

  test("organism 3D renders a WebGL canvas with no console errors (+ screenshot proof)", async ({ page }) => {
    const errors: string[] = [];
    page.on("pageerror", (e) => errors.push(`pageerror: ${e.message}`));
    page.on("console", (m) => {
      if (m.type() === "error") errors.push(`console: ${m.text()}`);
    });

    await page.goto("/organism", { waitUntil: "networkidle" });
    await page.waitForTimeout(6000);

    const info = await page.evaluate(() => {
      const c = document.querySelector("canvas");
      const badge = document.querySelector(".cortex-badge")?.textContent ?? "";
      const gl = c ? !!(c.getContext("webgl2") || c.getContext("webgl")) : false;
      return { hasCanvas: !!c, gl, badge };
    });

    expect(info.hasCanvas, "canvas present").toBeTruthy();
    expect(info.gl, "webgl context").toBeTruthy();
    expect(info.badge).toContain("WEBGL");
    expect(errors, "no console/page errors").toEqual([]);

    const box = await page.locator(".cortex-wrap").first().boundingBox();
    await page.screenshot({ path: "e2e/__artifacts__/organism.png", clip: box ?? undefined });
  });

  test("organism Phase-6 3D controls: capability, frame-budget HUD, keyboard, reduced-motion", async ({ page }) => {
    const errors: string[] = [];
    page.on("pageerror", (e) => errors.push(e.message));
    page.on("console", (m) => m.type() === "error" && errors.push(m.text()));

    await page.goto("/organism", { waitUntil: "networkidle" });
    await page.waitForTimeout(4000);

    // GPU capability badge (WebGPU detection with WebGL fallback)
    await expect(page.locator(".cap-badge")).toBeVisible();
    // frame-budget perf overlay (FPS + ms/frame)
    const hud = await page.locator(".org-hud").innerText();
    expect(hud).toMatch(/FPS/);
    expect(hud).toMatch(/ms/);
    // scene controls present
    await expect(page.getByRole("button", { name: /Kamera zurücksetzen/ })).toBeVisible();
    await expect(page.getByRole("button", { name: /Weniger Bewegung/ })).toBeVisible();

    // keyboard interaction loop must not error
    for (const k of ["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", "Equal", "Minus", "r"]) {
      await page.keyboard.press(k);
    }
    await page.waitForTimeout(200);

    // reduced-motion (motion-sickness guard) switches to the 2D fallback
    await page.getByRole("button", { name: /Weniger Bewegung/ }).click();
    await page.waitForTimeout(800);
    const hud2 = await page.locator(".org-hud").innerText();
    expect(hud2, "HUD shows 2D after reduced-motion").toMatch(/2D/);

    expect(errors, "no console/page errors during 3D control interaction").toEqual([]);
  });

  test("organism UI renders redaction-aware runtime feed and replay surface", async ({ page }) => {
    await page.goto("/organism", { waitUntil: "networkidle" });
    const feed = page.getByTestId("organism-runtime-feed");
    await expect(feed).toBeVisible();
    await expect(feed).toHaveAttribute("data-source-kind", /spec_only|agent_api_redacted|platform_audit/);
    await expect(feed).toContainText(/Runtime-Ereignisse/);
    await expect(feed).toContainText(/nur lesende Audit-Projektion/);
    await expect(feed).toContainText(/keine Rohdetails/);
    await expect(feed).not.toContainText(/"details"/);
    await expect(feed).not.toContainText(/user_id/);
    await expect(feed).not.toContainText(/session_id/);

    await page.goto("/organism/replay", { waitUntil: "networkidle" });
    await expect(page.getByTestId("organism-runtime-feed")).toBeVisible();
    await expect(page.getByTestId("organism-replay-frames")).toBeVisible();
  });

  test("organism runtime feed forwards run_id to events and replay APIs", async ({ page }) => {
    const runId = "ui-proof-run-20260610";
    const seen = { events: false, replay: false };

    await page.route("**/api/v1/organism/events?**", async (route) => {
      const url = new URL(route.request().url());
      seen.events = url.searchParams.get("run_id") === runId;
      await route.fulfill({
        contentType: "application/json",
        body: JSON.stringify({
          contract_version: "organism-events-v1",
          source: "agent-api",
          source_kind: "agent_api_redacted",
          live: true,
          run_id: runId,
          note: "redacted ui run proof",
          events: [{
            seq: 1,
            kind: "planning",
            hub: "workbench",
            run_state: "planning",
            severity: "info",
            source_kind: "agent_api_redacted",
            secret_output: false,
            writes: false,
          }],
          non_claims: ["read-only audit projection", "no raw details", "no secret values"],
        }),
      });
    });

    await page.route("**/api/v1/organism/replay?**", async (route) => {
      const url = new URL(route.request().url());
      seen.replay = url.searchParams.get("run_id") === runId;
      await route.fulfill({
        contentType: "application/json",
        body: JSON.stringify({
          contract_version: "organism-replay-v1",
          source: "agent-api",
          source_kind: "agent_api_redacted",
          live: true,
          run_id: runId,
          replay_available: true,
          frames: [{ t: 0, run_state: "planning", active: ["workbench"], regions: ["prefrontal_cortex"], source_kind: "agent_api_redacted" }],
          non_claims: ["read-only audit projection", "no raw details", "no secret values"],
        }),
      });
    });

    await page.goto(`/organism/replay?run_id=${encodeURIComponent(runId)}`, { waitUntil: "networkidle" });
    const feed = page.getByTestId("organism-runtime-feed");
    await expect(feed).toHaveAttribute("data-source-kind", "agent_api_redacted");
    await expect(feed).toHaveAttribute("data-live", "true");
    await expect(feed).toHaveAttribute("data-run-id", runId);
    await expect(feed).toContainText(`run_id=${runId}`);
    await expect(page.getByTestId("organism-replay-frames")).toBeVisible();
    expect(seen.events).toBe(true);
    expect(seen.replay).toBe(true);
  });
});
