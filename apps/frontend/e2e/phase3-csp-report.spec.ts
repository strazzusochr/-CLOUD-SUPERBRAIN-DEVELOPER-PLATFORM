import path from "node:path";
import { expect, test } from "@playwright/test";

const base = process.env.PHASE3_CSP_BASE_URL ?? "http://localhost:8081";

test("diagnostics loads the CSP report contract through a real click", async ({ page }, testInfo) => {
  const response = await page.goto(`${base}/diagnostics`, { waitUntil: "domcontentloaded" });
  expect(response?.status()).toBe(200);

  const consolePanel = page.getByTestId("live-console");
  await expect(consolePanel.locator(".lc-status")).toHaveText("200 OK");
  const endpointSelect = consolePanel.getByLabel("Live-Daten Endpoint");
  await endpointSelect.selectOption("/api/v1/security/csp/contract");
  await expect(endpointSelect).toHaveValue("/api/v1/security/csp/contract");
  const contractResponsePromise = page.waitForResponse((candidate) =>
    candidate.url().includes("/api/v1/security/csp/contract") && candidate.request().method() === "GET",
  );
  await consolePanel.getByTestId("live-console-load").click();
  const contractResponse = await contractResponsePromise;

  expect(contractResponse.status()).toBe(200);
  await expect(consolePanel.locator(".lc-status")).toHaveText("200 OK");
  await expect(consolePanel.locator(".lc-out")).toContainText('"contract_version": "csp-report-contract-v1"');
  await expect(consolePanel.locator(".lc-out")).toContainText('"evidence_ref": "csp_report_contract_visible"');
  await expect(consolePanel.locator(".lc-out")).toContainText('"audit_evidence_ref": "csp_report_audit_persisted"');

  const artifactDir = process.env.PHASE3_CSP_ARTIFACT_DIR;
  const screenshotPath = artifactDir
    ? path.join(artifactDir, "diagnostics-csp-report-contract.png")
    : testInfo.outputPath("diagnostics-csp-report-contract.png");
  await page.screenshot({ path: screenshotPath, fullPage: true });
  if (!artifactDir) {
    await testInfo.attach("diagnostics-csp-report-contract", { path: screenshotPath, contentType: "image/png" });
  }
});
