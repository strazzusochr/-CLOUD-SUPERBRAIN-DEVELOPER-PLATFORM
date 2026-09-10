import { defineConfig, devices } from "@playwright/test";

const PORT = 4040;
const externalBaseURL = process.env.PHASE6_BASE_URL?.trim().replace(/\/+$/, "");

export default defineConfig({
  testDir: "./e2e",
  timeout: 90_000,
  fullyParallel: false,
  workers: 1,
  reporter: [["list"], ["html", { outputFolder: "playwright-report", open: "never" }]],
  outputDir: "test-results",
  use: {
    baseURL: externalBaseURL || `http://localhost:${PORT}`,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
  },
  projects: [
    {
      name: "chromium",
      use: {
        ...devices["Desktop Chrome"],
        launchOptions: {
          args: [
            // Keep the deterministic software renderer available in headless CI.
            // Disabling GPU/compositing here makes WebGL2 unavailable and forces the
            // normal-motion Cortex into its accessibility-only 2D fallback.
            "--use-gl=swiftshader",
            "--ignore-gpu-blocklist",
          ],
        },
      },
    },
  ],
  webServer: externalBaseURL
    ? undefined
    : {
        command: `node node_modules/next/dist/bin/next start -p ${PORT}`,
        url: `http://localhost:${PORT}/`,
        timeout: 120_000,
        reuseExistingServer: false,
      },
});
