import path from "node:path";
import { expect, test } from "@playwright/test";

const base = process.env.PHASE3_CSRF_BASE_URL ?? "http://localhost:8081";

test("diagnostics loads CSRF guard and performs a same-origin browser POST", async ({ page }, testInfo) => {
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("console", (message) => message.type() === "error" && errors.push(message.text()));

  const response = await page.goto(`${base}/diagnostics`, { waitUntil: "networkidle" });
  expect(response?.status()).toBe(200);

  const consolePanel = page.getByTestId("live-console");
  const endpointSelect = consolePanel.getByLabel("Live-Daten Endpoint");
  await endpointSelect.selectOption("/api/v1/security/csrf/contract");
  const contractResponsePromise = page.waitForResponse((candidate) =>
    candidate.url().includes("/api/v1/security/csrf/contract") && candidate.request().method() === "GET",
  );
  await consolePanel.getByTestId("live-console-load").click();
  const contractResponse = await contractResponsePromise;

  expect(contractResponse.status()).toBe(200);
  await expect(consolePanel.locator(".lc-status")).toHaveText("200 OK");
  await expect(consolePanel.locator(".lc-out")).toContainText('"contract_version": "csrf-origin-guard-v1"');
  await expect(consolePanel.locator(".lc-out")).toContainText('"evidence_ref": "csrf_origin_guard_visible"');
  await expect(consolePanel.locator(".lc-out")).toContainText('"cross_site_browser_requests_allowed": false');

  const browserProbe = await page.evaluate(async () => {
    const result = await fetch("/api/v1/security/csrf/probe", { method: "POST", credentials: "same-origin" });
    return {
      status: result.status,
      contractHeader: result.headers.get("x-superbrain-csrf-contract"),
      body: await result.json(),
    };
  });
  expect(browserProbe.status).toBe(200);
  expect(browserProbe.contractHeader).toBe("csrf-origin-guard-v1");
  expect(browserProbe.body.status).toBe("accepted_same_origin_or_non_browser");
  expect(browserProbe.body.state_write).toBe(false);

  const artifactDir = process.env.PHASE3_CSRF_ARTIFACT_DIR;
  const screenshotPath = artifactDir
    ? path.join(artifactDir, "diagnostics-csrf-origin-guard.png")
    : testInfo.outputPath("diagnostics-csrf-origin-guard.png");
  await page.screenshot({ path: screenshotPath, fullPage: true });
  expect(errors, "no console/page errors during CSRF diagnostics proof").toEqual([]);
});
