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
});
