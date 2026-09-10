import { expect, test } from "@playwright/test";

const base = process.env.GOAL_B_PRODUCT_BASE_URL ?? "";

test("F1 workbench build renders real Workers AI output", async ({ page }) => {
  const seen: string[] = [];
  page.on("requestfinished", (request) => seen.push(request.url()));

  const response = await page.goto(`${base}/workbench`, { waitUntil: "domcontentloaded" });
  expect(response?.status()).toBe(200);
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});

  await page.getByLabel("Beschreibung für die App-Erstellung").fill("Baue eine kleine zugängliche Statuskarte mit Überschrift und Umschalter.");
  const buildResponsePromise = page.waitForResponse((candidate) => candidate.url().includes("/api/v1/build") && candidate.request().method() === "POST");
  await page.getByTestId("ws-build").click();
  const buildResponse = await buildResponsePromise;
  expect(buildResponse.status()).toBe(200);
  expect(buildResponse.headers()["x-superbrain-source"]).toBe("ai-builder");
  const body = await buildResponse.json();
  expect(String(body.model)).toMatch(/^@cf\//);
  expect(String(body.html)).toMatch(/<!doctype html/i);
  expect(String(body.html).length).toBeGreaterThan(500);
  await expect(page.getByTestId("ws-log")).toContainText("Live-Vorschau bereit", { timeout: 240_000 });
  await expect(page.getByTestId("ws-frame")).toBeVisible();
  expect(seen.some((url) => url.includes("/api/v1/build"))).toBeTruthy();
});
