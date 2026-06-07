import { defineConfig, devices } from "@playwright/test";
import path from "node:path";

const PORT = 4040;

export default defineConfig({
  testDir: "./e2e",
  timeout: 90_000,
  fullyParallel: false,
  workers: 1,
  reporter: [["list"], ["html", { outputFolder: "playwright-report", open: "never" }]],
  outputDir: "test-results",
  use: {
    baseURL: `http://localhost:${PORT}`,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    reducedMotion: "no-preference",
  },
  projects: [
    {
      name: "chromium",
      use: {
        ...devices["Desktop Chrome"],
        launchOptions: {
          // Software WebGL so the 3D organism renders in headless CI.
          args: [
            "--use-gl=swiftshader",
            "--ignore-gpu-blocklist",
            "--enable-logging=stderr",
            `--log-file=${path.join(process.cwd(), "test-results", "chromium-debug.log")}`,
          ],
        },
      },
    },
  ],
  webServer: {
    command: `node node_modules/next/dist/bin/next start -p ${PORT}`,
    url: `http://localhost:${PORT}/`,
    timeout: 120_000,
    reuseExistingServer: false,
  },
});
