#!/usr/bin/env node

import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { command, npmCommand, runCommand } from "./lib/command.mjs";

if (process.platform !== "darwin") {
  throw new Error("Swift版のスクリーンショット撮影はmacOSで実行してください。");
}

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const tauriDirectory = join(root, "apps/tauri/KawaCAD");
const swiftDirectory = join(root, "apps/macos/KawaCAD");
const outputRoot = join(root, "test-results/comparison-screenshots");
const screenshotDirectory = join(outputRoot, "screenshots");

runCommand(npmCommand(["run", "screenshots:comparison"]), {
  cwd: tauriDirectory,
});
runCommand(
  command("swift", [
    "test",
    "--filter",
    "ComparisonScreenshotTests.testComparisonScreenshots",
  ]),
  {
    cwd: swiftDirectory,
    env: { KAWACAD_SCREENSHOT_OUTPUT_DIR: screenshotDirectory },
  },
);

console.log(
  `Generated Tauri and Swift comparison screenshots in ${outputRoot}`,
);
