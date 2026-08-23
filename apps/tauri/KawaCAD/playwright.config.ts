import { defineConfig, devices } from "@playwright/test";

const chromePath = process.env.LEATHER_E2E_CHROME;

export default defineConfig({
  testDir: "./e2e",
  testIgnore: "**/*screenshots.spec.mjs",
  timeout: 30_000,
  expect: { timeout: 5_000 },
  fullyParallel: false,
  workers: 1,
  reporter: process.env.CI ? "line" : "list",
  use: {
    ...devices["Desktop Chrome"],
    baseURL: "http://127.0.0.1:1420",
    headless: true,
    launchOptions: chromePath ? { executablePath: chromePath } : undefined,
    trace: "retain-on-failure",
  },
  webServer: {
    command: "npm run dev -- --host 127.0.0.1",
    url: "http://127.0.0.1:1420",
    reuseExistingServer: !process.env.CI,
    timeout: 30_000,
  },
});
