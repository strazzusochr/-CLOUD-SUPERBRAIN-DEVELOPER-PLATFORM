import { mkdirSync } from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";

const base = (process.env.PHASE5_CANDIDATE_BASE_URL ?? "http://localhost:8081").replace(/\/+$/, "");
const endpoint = "/api/v1/release-candidate/local/contract";

test("diagnostics loads the Phase 5 production candidate through a real selection and click", async ({ page }, testInfo) => {
  const response = await page.goto(`${base}/diagnostics`, { waitUntil: "networkidle" });
  expect(response?.status()).toBe(200);

  const consolePanel = page.getByTestId("live-console");
  const endpointSelect = consolePanel.getByLabel("Live-Daten Endpoint");
  await endpointSelect.selectOption({ label: "Phase 5 Production Candidate" });
  await expect(endpointSelect).toHaveValue(endpoint);

  const contractResponsePromise = page.waitForResponse((candidate) => {
    const requestUrl = new URL(candidate.url());
    return requestUrl.pathname === endpoint && candidate.request().method() === "GET";
  });
  await consolePanel.getByTestId("live-console-load").click();
  const contractResponse = await contractResponsePromise;
  const contract = await contractResponse.json();

  expect(contractResponse.status()).toBe(200);
  expect(contract.contract_version).toBe("phase5-production-candidate-local-v1");
  expect(contract.evidence_ref).toBe("phase5_local_production_candidate_verified");
  expect(contract.phase5_progress_after_proof).toBe(68);
  expect(contract.service_count).toBe(6);
  expect(contract.registry_publish).toBe(false);
  expect(contract.hosted_staging_parity).toBe(false);
  expect(contract.production_deploy).toBe(false);
  expect(contract.release_promotion).toBe(false);
  expect(contract.secret_output).toBe(false);

  await expect(consolePanel.locator(".lc-status")).toHaveText("200 OK");
  await expect(consolePanel.locator(".lc-out")).toContainText('"contract_version": "phase5-production-candidate-local-v1"');
  await expect(consolePanel.locator(".lc-out")).toContainText('"evidence_ref": "phase5_local_production_candidate_verified"');
  await expect(consolePanel.locator(".lc-out")).toContainText('"phase5_progress_after_proof": 68');
  await expect(consolePanel.locator(".lc-out")).toContainText('"service_count": 6');
  await expect(consolePanel.locator(".lc-out")).toContainText('"registry_publish": false');
  await expect(consolePanel.locator(".lc-out")).toContainText('"hosted_staging_parity": false');
  await expect(consolePanel.locator(".lc-out")).toContainText('"production_deploy": false');
  await expect(consolePanel.locator(".lc-out")).toContainText('"release_promotion": false');
  await expect(consolePanel.locator(".lc-out")).toContainText('"secret_output": false');

  const artifactDir = process.env.PHASE5_CANDIDATE_ARTIFACT_DIR?.trim();
  const screenshotPath = artifactDir
    ? path.join(artifactDir, "diagnostics-phase5-production-candidate.png")
    : testInfo.outputPath("diagnostics-phase5-production-candidate.png");
  if (artifactDir) mkdirSync(artifactDir, { recursive: true });
  await page.screenshot({ path: screenshotPath, fullPage: true });
});
