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

  test("organism live-state / events / replay are mock-labelled (no fake-live)", async ({ request }) => {
    for (const path of ["live-state", "events", "replay"]) {
      const resp = await request.get(`/api/v1/organism/${path}`);
      expect(resp.status(), path).toBe(200);
      const json = await resp.json();
      expect(json.source, path).toBe("mock");
      expect(json.live, path).toBe(false);
    }
  });

  test("consolidated pages render real content (not re-export shortcuts)", async ({ page }) => {
    await page.goto("/technology", { waitUntil: "domcontentloaded" });
    await expect(page.getByText("Capabilities by category")).toBeVisible();
    await expect(page.getByText("Cloud provider inventory")).toBeVisible();

    await page.goto("/responsive", { waitUntil: "domcontentloaded" });
    await expect(page.getByText("Breakpoint matrix")).toBeVisible();
    await expect(page.getByText("Accessibility & reduced motion")).toBeVisible();

    await page.goto("/open-source", { waitUntil: "domcontentloaded" });
    await expect(page.getByText("core components")).toBeVisible();
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
    await expect(page.getByRole("button", { name: /Reset camera/ })).toBeVisible();
    await expect(page.getByRole("button", { name: /Reduced motion/ })).toBeVisible();

    // keyboard interaction loop must not error
    for (const k of ["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", "Equal", "Minus", "r"]) {
      await page.keyboard.press(k);
    }
    await page.waitForTimeout(200);

    // reduced-motion (motion-sickness guard) switches to the 2D fallback
    await page.getByRole("button", { name: /Reduced motion/ }).click();
    await page.waitForTimeout(800);
    const hud2 = await page.locator(".org-hud").innerText();
    expect(hud2, "HUD shows 2D after reduced-motion").toMatch(/2D/);

    expect(errors, "no console/page errors during 3D control interaction").toEqual([]);
  });
});
