import { mkdirSync } from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";

const base = process.env.ORCHESTRATOR_COMPLETION_BASE_URL ?? "http://localhost:8081";

test("diagnostics loads orchestrator completion evidence through a real click", async ({ page }, testInfo) => {
  const response = await page.goto(`${base}/diagnostics`, { waitUntil: "networkidle" });
  expect(response?.status()).toBe(200);

  const consolePanel = page.getByTestId("live-console");
  const endpointSelect = consolePanel.getByLabel("Live-Daten Endpoint");
  await endpointSelect.selectOption("/api/v1/orchestrator/completion/contract");
  await expect(endpointSelect).toHaveValue("/api/v1/orchestrator/completion/contract");

  const contractResponsePromise = page.waitForResponse((candidate) =>
    candidate.url().includes("/api/v1/orchestrator/completion/contract") && candidate.request().method() === "GET",
  );
  await consolePanel.getByTestId("live-console-load").click();
  const contractResponse = await contractResponsePromise;
  const contract = await contractResponse.json();

  expect(contractResponse.status()).toBe(200);
  expect(contract.contract_version).toBe("orchestrator-completion-evidence-v1");
  expect(contract.evidence_ref).toBe("orchestrator_completion_evidence_verified");
  expect(contract.layer_progress_after_proof).toBe(100);
  expect(contract.live_provider_calls).toBe(false);
  expect(contract.live_mcp_writes).toBe(false);
  expect(contract.production_deploy).toBe(false);

  await expect(consolePanel.locator(".lc-status")).toHaveText("200 OK", { timeout: 10000 });
  await expect(consolePanel.locator(".lc-out")).toContainText('"contract_version": "orchestrator-completion-evidence-v1"');
  await expect(consolePanel.locator(".lc-out")).toContainText('"evidence_ref": "orchestrator_completion_evidence_verified"');
  await expect(consolePanel.locator(".lc-out")).toContainText('"layer_progress_after_proof": 100');
  await expect(consolePanel.locator(".lc-out")).toContainText('"live_provider_calls": false');
  await expect(consolePanel.locator(".lc-out")).toContainText('"live_mcp_writes": false');
  await expect(consolePanel.locator(".lc-out")).toContainText('"production_deploy": false');

  const artifactDir = process.env.ORCHESTRATOR_COMPLETION_ARTIFACT_DIR;
  const screenshotPath = artifactDir
    ? path.join(artifactDir, "diagnostics-orchestrator-completion-evidence.png")
    : testInfo.outputPath("diagnostics-orchestrator-completion-evidence.png");
  if (artifactDir) mkdirSync(artifactDir, { recursive: true });
  await page.screenshot({ path: screenshotPath, fullPage: true });
});
