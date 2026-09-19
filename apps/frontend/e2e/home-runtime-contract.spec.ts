import { test, expect } from "@playwright/test";

test.describe("Page 01 — personal runtime contract", () => {
  test("renders the personal activity monitor surface", async ({ page }) => {
    await page.goto("/home", { waitUntil: "domcontentloaded" });

    await expect(page.getByText("Deine Aktivität", { exact: true })).toBeVisible();
    await expect(page.locator("section.home-runtime-monitor")).toBeVisible();
    await expect(page.getByText(/Aktivität wird geladen\.|Mit GitHub anmelden, um eigene Aktivität zu sehen\.|Aktivität ist gerade nicht erreichbar\.|Keine Aktivität/)).toBeVisible({ timeout: 15_000 });
  });

  test("keeps the runtime event read boundary owner-bound", async ({ request }) => {
    const response = await request.get("/api/v1/workspace/runtime/events", {
      headers: { "x-superbrain-workspace-subject": "github:999999" },
    });

    expect([401, 403, 503]).toContain(response.status());
    const body = await response.json().catch(() => null);
    expect(body).toBeTruthy();
    expect(JSON.stringify(body)).not.toContain("github:999999");
  });

  test("keeps detail, trace, and stream reads owner-bound", async ({ request }) => {
    for (const path of [
      "/api/v1/workspace/runtime/events/event-does-not-exist",
      "/api/v1/workspace/runtime/traces/trace-does-not-exist",
      "/api/v1/workspace/runtime/events/stream",
    ]) {
      const response = await request.get(path, {
        headers: { "x-superbrain-workspace-subject": "github:999999" },
      });
      expect([401, 403, 503]).toContain(response.status());
      const body = await response.text();
      expect(body).not.toContain("github:999999");
    }
  });

  test("does not expose a provider or build write from Home", async ({ page }) => {
    const writes: string[] = [];
    page.on("request", (request) => {
      if (["POST", "PUT", "PATCH", "DELETE"].includes(request.method())) {
        writes.push(`${request.method()} ${request.url()}`);
      }
    });

    await page.goto("/home", { waitUntil: "domcontentloaded" });
    expect(writes.filter((entry) => /\/api\/v1\/build|llm|mcp/i.test(entry))).toEqual([]);
  });

  test("pauses and resumes the owner activity presentation without changing the read boundary", async ({ page }) => {
    await page.goto("/login?monitorpause=" + Date.now(), { waitUntil: "domcontentloaded" });
    const session = await page.evaluate(async () => {
      const response = await fetch("/api/v1/auth/session", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ provider: "guest" }),
      });
      return { status: response.status, payload: await response.json() };
    });
    expect(session.status).toBe(200);
    expect(session.payload.status).toBe("signed_in");

    const feedResponse = page.waitForResponse((response) =>
      response.request().method() === "GET"
      && new URL(response.url()).pathname === "/api/v1/workspace/runtime/events",
    );
    await page.goto("/home?monitorpause=" + Date.now(), { waitUntil: "domcontentloaded" });
    expect((await feedResponse).status()).toBe(200);

    const pause = page.getByTestId("home-runtime-pause");
    await expect(pause).toBeVisible({ timeout: 15_000 });
    await pause.click();
    await expect(pause).toHaveText("Fortsetzen");
    await expect(page.getByTestId("home-runtime-pending")).toHaveText("Neue Ereignisse: 0");
    await pause.click();
    await expect(pause).toHaveText("Pausieren");
  });

  test("opens the owner-bound runtime stream after the authenticated collection read", async ({ page }) => {
    await page.goto("/login?stream=" + Date.now(), { waitUntil: "domcontentloaded" });
    const session = await page.evaluate(async () => {
      const response = await fetch("/api/v1/auth/session", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ provider: "guest" }),
      });
      return { status: response.status, payload: await response.json() };
    });
    expect(session.status).toBe(200);
    expect(session.payload.status).toBe("signed_in");

    const streamResponse = page.waitForResponse((response) =>
      response.request().method() === "GET"
      && new URL(response.url()).pathname === "/api/v1/workspace/runtime/events/stream",
    );
    await page.goto("/home?stream=" + Date.now(), { waitUntil: "domcontentloaded" });
    const response = await streamResponse;
    expect(response.status()).toBe(200);
    expect(response.headers()["content-type"]).toContain("text/event-stream");
  });

  test("forwards the authenticated stream cursor without accepting a client identity", async ({ page }) => {
    await page.goto("/login?stream-cursor=" + Date.now(), { waitUntil: "domcontentloaded" });
    const session = await page.evaluate(async () => {
      const response = await fetch("/api/v1/auth/session", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ provider: "guest" }),
      });
      return { status: response.status, payload: await response.json() };
    });
    expect(session.status).toBe(200);
    const result = await page.evaluate(async () => {
      const response = await fetch("/api/v1/workspace/runtime/events/stream", {
        headers: { "Last-Event-ID": "cursor-check" },
      });
      return {
        status: response.status,
        cursor: response.headers.get("x-runtime-cursor"),
        body: await response.text(),
      };
    });
    expect(result.status).toBe(200);
    expect(result.cursor).toBe("cursor-check");
    expect(result.body).toContain("runtime_gap");
  });
});
