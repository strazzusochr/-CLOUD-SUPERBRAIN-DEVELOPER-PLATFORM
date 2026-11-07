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

  test("shows and opens a real owner-bound build event", async ({ page }) => {
    await page.goto("/login?runtime-event=" + Date.now(), { waitUntil: "domcontentloaded" });
    const build = await page.evaluate(async () => {
      const sessionResponse = await fetch("/api/v1/auth/session", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ provider: "guest" }),
      });
      if (sessionResponse.status !== 200) return { sessionStatus: sessionResponse.status, buildStatus: 0, build: null };
      const response = await fetch("/api/v1/build", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          prompt: "Erzeuge eine kleine, vollständige, interaktive Workbench-Demo mit sichtbarem Titel und zwei funktionierenden Schaltflächen.",
          project_id: "default",
        }),
      });
      return { sessionStatus: sessionResponse.status, buildStatus: response.status, build: await response.json().catch(() => null) };
    });
    expect(build.sessionStatus).toBe(200);
    expect(build.buildStatus).toBe(200);
    expect(build.build?.persisted).toBe(true);
    expect(build.build?.direct_provider_calls).toBe(false);
    expect(String(build.build?.id)).toMatch(/^[A-Za-z0-9_-]{1,64}$/);

    const eventFeed = await page.evaluate(async () => {
      const response = await fetch("/api/v1/workspace/runtime/events");
      return { status: response.status, payload: await response.json().catch(() => null) };
    });
    expect(eventFeed.status).toBe(200);
    const eventHash = String(eventFeed.payload?.events?.[0]?.event_hash ?? "");
    expect(eventHash).toMatch(/^[a-f0-9]{64}$/);

    await page.goto("/home?runtime-event=" + Date.now(), { waitUntil: "domcontentloaded" });
    const event = page.locator("details.home-runtime-event").filter({ hasText: "build_created" }).first();
    await expect(event).toBeVisible({ timeout: 30_000 });
    await event.locator("summary").click();
    await expect(event.getByTestId("home-runtime-detail")).toContainText("Parent-/Root-Kette:", { timeout: 15_000 });
    await expect(event.getByTestId("home-runtime-detail")).toContainText("Hashkette:");
    await expect(event.getByTestId("home-runtime-detail")).toContainText(eventHash);
    await expect(event).toContainText(String(build.build?.id));
  });

  test("marks missing runtime producer classes as incomplete instead of claiming a complete feed", async ({ page }) => {
    await page.goto("/login?runtime-completeness=" + Date.now(), { waitUntil: "domcontentloaded" });
    const result = await page.evaluate(async () => {
      const sessionResponse = await fetch("/api/v1/auth/session", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ provider: "guest" }),
      });
      if (sessionResponse.status !== 200) return { sessionStatus: sessionResponse.status, buildStatus: 0, feedStatus: 0, feed: null };
      const buildResponse = await fetch("/api/v1/build", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ prompt: "Erzeuge eine kleine Runtime-Vollständigkeitsprobe.", project_id: "default" }),
      });
      const feedResponse = await fetch("/api/v1/workspace/runtime/events");
      return {
        sessionStatus: sessionResponse.status,
        buildStatus: buildResponse.status,
        feedStatus: feedResponse.status,
        feed: await feedResponse.json().catch(() => null),
      };
    });
    expect(result.sessionStatus).toBe(200);
    expect(result.buildStatus).toBe(200);
    expect(result.feedStatus).toBe(200);
    expect(result.feed?.complete).toBe(false);
    expect(result.feed?.observed_classes).toContain("workspace");
    expect(result.feed?.observed_classes).toContain("llm");
    expect(result.feed?.missing_classes).toEqual(expect.arrayContaining(["agent", "tool_mcp", "memory", "artifact", "auth", "security"]));
    expect(result.feed?.missing_classes).not.toContain("llm");
    await page.goto("/home?runtime-completeness-view=" + Date.now(), { waitUntil: "domcontentloaded" });
    await expect(page.getByText(/Aktivität ist unvollständig/)).toBeVisible({ timeout: 30_000 });
  });

  test("shows a visible pending state while a real workspace mutation is in flight", async ({ page }) => {
    await page.goto("/login?workspace-pending=" + Date.now(), { waitUntil: "domcontentloaded" });
    const build = await page.evaluate(async () => {
      const sessionResponse = await fetch("/api/v1/auth/session", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ provider: "guest" }),
      });
      if (sessionResponse.status !== 200) return { sessionStatus: sessionResponse.status, buildStatus: 0, id: "" };
      const response = await fetch("/api/v1/build", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ prompt: "Erzeuge eine kleine persistierte Pending-Probe.", project_id: "default" }),
      });
      const payload = await response.json().catch(() => null) as { id?: string } | null;
      return { sessionStatus: sessionResponse.status, buildStatus: response.status, id: String(payload?.id ?? "") };
    });
    expect(build.sessionStatus).toBe(200);
    expect(build.buildStatus).toBe(200);
    expect(build.id).toMatch(/^[A-Za-z0-9_-]{1,64}$/);

    await page.goto("/home?workspace-pending-view=" + Date.now(), { waitUntil: "domcontentloaded" });
    const pin = page.getByTestId(`home-workspace-pin-${build.id}`);
    await expect(pin).toBeVisible({ timeout: 30_000 });
    await pin.click();
    await expect(page.getByTestId("home-workspace-pending")).toBeVisible();
    await expect(page.getByTestId("home-workspace-builds").getByTestId(`home-workspace-pin-${build.id}`)).toBeEnabled({ timeout: 30_000 });
  });

  test("reconnects the owner-bound stream from a real persisted cursor", async ({ page }) => {
    await page.goto("/login?runtime-reconnect=" + Date.now(), { waitUntil: "domcontentloaded" });
    const result = await page.evaluate(async () => {
      const sessionResponse = await fetch("/api/v1/auth/session", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ provider: "guest" }),
      });
      if (sessionResponse.status !== 200) return { sessionStatus: sessionResponse.status, buildStatuses: [], feedStatus: 0, streamStatus: 0, gap: "", cursor: "", eventIds: [], body: "" };
      const buildStatuses: number[] = [];
      for (const suffix of ["one", "two"]) {
        const response = await fetch("/api/v1/build", {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({
            prompt: `Erzeuge eine kleine vollständige Workbench-Demo für den Reconnect-Nachweis ${suffix}.`,
            project_id: "default",
          }),
        });
        buildStatuses.push(response.status);
      }
      const feedResponse = await fetch("/api/v1/workspace/runtime/events");
      const feed = await feedResponse.json().catch(() => null) as { events?: Array<{ event_id?: string }> } | null;
      const eventIds = Array.isArray(feed?.events)
        ? feed.events.map((event) => String(event.event_id ?? "")).filter(Boolean)
        : [];
      const oldest = eventIds.at(-1) ?? "";
      const streamResponse = oldest
        ? await fetch("/api/v1/workspace/runtime/events/stream", { headers: { "Last-Event-ID": oldest } })
        : null;
      return {
        sessionStatus: sessionResponse.status,
        buildStatuses,
        feedStatus: feedResponse.status,
        streamStatus: streamResponse?.status ?? 0,
        gap: streamResponse?.headers.get("x-runtime-gap") ?? "",
        cursor: streamResponse?.headers.get("x-runtime-cursor") ?? "",
        eventIds,
        body: streamResponse ? await streamResponse.text() : "",
      };
    });
    expect(result.sessionStatus).toBe(200);
    expect(result.buildStatuses).toEqual([200, 200]);
    expect(result.feedStatus).toBe(200);
    expect(result.eventIds.length).toBeGreaterThanOrEqual(2);
    const oldest = result.eventIds.at(-1);
    const newest = result.eventIds[0];
    expect(result.streamStatus).toBe(200);
    expect(result.gap).toBe("false");
    expect(result.cursor).toBe(oldest);
    expect(result.body).toContain("runtime_event");
    expect(result.body).toContain(newest);
    expect(result.body).not.toContain(oldest);
  });
});
