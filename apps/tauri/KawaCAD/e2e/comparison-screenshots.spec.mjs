import { mkdir } from "node:fs/promises";
import path from "node:path";
import { test as base, expect } from "@playwright/test";
import { preparedPDF } from "./comparison-screenshot-fixtures.mjs";

const appRoot = path.resolve(import.meta.dirname, "..");
const repoRoot = path.resolve(appRoot, "../../..");
const screenshotDirectory = process.env.KAWACAD_SCREENSHOT_OUTPUT_DIR
  ? path.resolve(process.env.KAWACAD_SCREENSHOT_OUTPUT_DIR)
  : path.join(repoRoot, "test-results/comparison-screenshots/screenshots");
const bridgeScript = new URL("./tauri-bridge-init.js", import.meta.url).pathname;

const fixtures = [
  { id: "toolbar-expanded", width: 1532, height: 54, target: "toolbar" },
  { id: "toolbar-condensed", width: 900, height: 54, target: "toolbar" },
  { id: "tool-palette-basic", width: 240, height: 800, target: "palette" },
  { id: "tool-palette-detailed", width: 240, height: 800, target: "palette" },
  { id: "canvas-empty", width: 800, height: 520, target: "canvas" },
  { id: "canvas-geometry", width: 800, height: 520, target: "canvas" },
  { id: "inspector-selection", width: 520, height: 820, target: "inspector" },
  { id: "inspector-parameters-empty", width: 520, height: 280, target: "fixture" },
  { id: "summary", width: 1032, height: 84, target: "summary" },
  { id: "constraint-hud", width: 190, height: 46, target: "constraint" },
  { id: "context-menu", width: 120, height: 40, target: "context" },
  { id: "paste-options", width: 172, height: 28, target: "paste" },
  { id: "licenses-dialog", width: 680, height: 520, target: "licenses" },
  { id: "recovery-dialog", width: 660, height: 400, target: "recovery" },
  { id: "layer-deletion-dialog", width: 360, height: 160, target: "layer-deletion" },
  { id: "pdf-dialog", width: 920, height: 640, target: "pdf" },
];

const themes = ["light", "dark"];

const test = base.extend({
  browserErrors: [
    async ({ page }, use) => {
      const errors = [];
      page.on("pageerror", (error) => errors.push(`pageerror: ${error.message}`));
      page.on("console", (message) => {
        if (message.type() === "error") errors.push(`console.error: ${message.text()}`);
      });
      await use(errors);
      expect(errors).toEqual([]);
    },
    { auto: true },
  ],
});

test.use({
  viewport: { width: 1280, height: 800 },
  deviceScaleFactor: 1,
  locale: "ja-JP",
  timezoneId: "Asia/Tokyo",
});

test.beforeAll(async () => {
  await mkdir(screenshotDirectory, { recursive: true });
});

async function installBridge(page) {
  await page.exposeFunction("__leatherE2EInvoke", (command) => {
    if (command === "prepare_pdf_output") return structuredClone(preparedPDF);
    if (command === "direct_print_availability") return { status: "unavailable" };
    return undefined;
  });
  await page.addInitScript({ path: bridgeScript });
}

function screenshotTarget(page, target) {
  switch (target) {
    case "toolbar":
      return page.getByTestId("leather.component.toolbar");
    case "palette":
      return page.getByTestId("leather.component.tool-palette");
    case "canvas":
      return page.getByTestId("leather.workspace.canvas");
    case "inspector":
      return page.getByTestId("leather.component.inspector");
    case "fixture":
      return page.getByTestId("comparison-fixture");
    case "summary":
      return page.getByTestId("leather.status.bottom-workbench");
    case "constraint":
      return page.getByTestId("leather.component.constraint-hud");
    case "context":
      return page.getByTestId("leather.component.context-menu");
    case "paste":
      return page.getByTestId("leather.paste-options");
    case "licenses":
      return page.getByTestId("leather.component.licenses-dialog");
    case "recovery":
      return page.getByTestId("leather.component.recovery-dialog");
    case "layer-deletion":
      return page.getByTestId("leather.component.layer-deletion-dialog");
    case "pdf":
      return page.getByTestId("leather.pdf-export.dialog");
  }
}

async function captureFixture(page, fixture, theme) {
  await page.emulateMedia({ colorScheme: theme });
  await page.setViewportSize({
    width: Math.max(1024, fixture.width),
    height: Math.max(700, fixture.height),
  });
  await installBridge(page);
  await page.goto(`/?comparison-fixture=${fixture.id}`);
  await page.evaluate(() => document.fonts.ready);
  const target = screenshotTarget(page, fixture.target);
  await expect(target).toBeVisible();
  if (fixture.target === "pdf") {
    await expect(target.getByRole("img", { name: "PDF 1ページ目" })).toBeVisible();
  }
  await target.screenshot({
    path: path.join(screenshotDirectory, `tauri-${fixture.id}-${theme}.jpg`),
    type: "jpeg",
    quality: 80,
    animations: "disabled",
    caret: "hide",
    scale: "css",
  });
}

test.describe("independent component visual fixtures", () => {
  for (const theme of themes) {
    for (const fixture of fixtures) {
      test(`captures ${fixture.id} as an independent ${theme} fixture`, async ({ page }) => {
        await captureFixture(page, fixture, theme);
      });
    }
  }
});
