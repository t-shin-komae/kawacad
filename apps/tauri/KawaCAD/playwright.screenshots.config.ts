import { defineConfig } from "@playwright/test";
import baseConfig from "./playwright.config";

export default defineConfig(baseConfig, {
  testIgnore: [],
  testMatch: "**/comparison-screenshots.spec.mjs",
  reporter: "list",
});
