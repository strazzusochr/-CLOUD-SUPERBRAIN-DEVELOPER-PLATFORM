import { defineConfig, devices } from "@playwright/test";

const PORT = 4040;
const externalBaseURL = process.env.PHASE6_BASE_URL?.trim().replace(/\/+$/, "");
const resolvedBaseURL = externalBaseURL || `http://localhost:${PORT}`;

// Action specifications must use the same resolved target as Playwright. This
// avoids a second, stale localhost port becoming an independent test truth.
process.env.PAGE_ACTIONS_BASE_URL ??= resolvedBaseURL;

export default defineConfig({
  testDir: "./e2e",
  timeout: 90_000,
  fullyParallel: false,
  workers: 1,
  reporter: [["list"], ["html", { outputFolder: "playwright-report", open: "never" }]],
  outputDir: "test-results",
  use: {
    baseURL: resolvedBaseURL,
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
            "--disable-gpu",
            "--ignore-gpu-blocklist",
          ],
        },
      },
    },
  ],
  webServer: externalBaseURL
    ? undefined
    : {
        // The canonical local stack is the development transport. It is
        // required for the explicit local-session fallback used by the
        // browser contract; `next start` forces NODE_ENV=production and
        // turns that local-only path into a misleading 503.
        command: `node node_modules/next/dist/bin/next dev --webpack -p ${PORT}`,
        url: `http://localhost:${PORT}/`,
        timeout: 120_000,
        reuseExistingServer: false,
      },
});
