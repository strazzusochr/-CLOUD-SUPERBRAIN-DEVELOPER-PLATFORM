import path from "node:path";
import { expect, test } from "@playwright/test";

const base = process.env.PHASE3_CROSS_ORIGIN_BASE_URL ?? "http://localhost:8081";

test("diagnostics loads the cross-origin response guard through a real click", async ({ page, request }, testInfo) => {
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("console", (message) => message.type() === "error" && errors.push(message.text()));

  const response = await page.goto(`${base}/diagnostics`, { waitUntil: "networkidle" });
  expect(response?.status()).toBe(200);

  const consolePanel = page.getByTestId("live-console");
  const endpointSelect = consolePanel.getByLabel("Live-Daten Endpoint");
  await endpointSelect.selectOption("/api/v1/security/cross-origin/contract");
  const contractResponsePromise = page.waitForResponse((candidate) =>
    candidate.url().includes("/api/v1/security/cross-origin/contract") && candidate.request().method() === "GET",
  );
  await consolePanel.getByTestId("live-console-load").click();
  const contractResponse = await contractResponsePromise;

  expect(contractResponse.status()).toBe(200);
  expect(contractResponse.headers()["cross-origin-opener-policy"]).toBe("same-origin");
  expect(contractResponse.headers()["cross-origin-resource-policy"]).toBe("same-origin");
  await expect(consolePanel.locator(".lc-status")).toHaveText("200 OK");
  await expect(consolePanel.locator(".lc-out")).toContainText('"contract_version": "cross-origin-response-guard-v1"');
  await expect(consolePanel.locator(".lc-out")).toContainText('"attacker_origin_reflected": false');

  const attackerResponse = await request.get(`${base}/api/v1/health`, {
    headers: { Origin: "https://cross-origin-attacker.invalid" },
  });
  expect(attackerResponse.status()).toBe(200);
  expect(attackerResponse.headers()["cross-origin-opener-policy"]).toBe("same-origin");
  expect(attackerResponse.headers()["cross-origin-resource-policy"]).toBe("same-origin");
  expect(attackerResponse.headers()["access-control-allow-origin"]).toBeUndefined();

  const artifactDir = process.env.PHASE3_CROSS_ORIGIN_ARTIFACT_DIR;
  const screenshotPath = artifactDir
    ? path.join(artifactDir, "diagnostics-cross-origin-response-guard.png")
    : testInfo.outputPath("diagnostics-cross-origin-response-guard.png");
  await page.screenshot({ path: screenshotPath, fullPage: true });
  expect(errors, "no console/page errors during cross-origin diagnostics proof").toEqual([]);
});
