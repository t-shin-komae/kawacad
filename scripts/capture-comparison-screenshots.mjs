#!/usr/bin/env node

import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readdirSync,
  rmSync,
} from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { command, npmCommand, runCommand } from "./lib/command.mjs";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");

export function parseComparisonScreenshotArgs(args) {
  const options = {
    outputDirectory: join(
      repositoryRoot,
      "test-results/comparison-screenshots",
    ),
    sourceRoot: repositoryRoot,
    variant: "all",
  };
  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    const value = args[index + 1];
    if (argument === "--output-dir" && value) {
      options.outputDirectory = resolve(value);
      index += 1;
    } else if (argument === "--source-root" && value) {
      options.sourceRoot = resolve(value);
      index += 1;
    } else if (argument === "--variant" && value) {
      options.variant = value;
      index += 1;
    } else {
      throw new Error(`Unknown or incomplete argument: ${argument}`);
    }
  }
  if (!["all", "swift", "tauri"].includes(options.variant)) {
    throw new Error("--variant must be one of: all, swift, tauri");
  }
  return options;
}

export function clearComparisonScreenshots(outputDirectory, variant) {
  const screenshotDirectory = join(outputDirectory, "screenshots");
  if (!existsSync(screenshotDirectory)) return;
  const prefixes = variant === "all" ? ["swift-", "tauri-"] : [`${variant}-`];
  for (const entry of readdirSync(screenshotDirectory, {
    withFileTypes: true,
  })) {
    if (
      entry.isFile() &&
      prefixes.some((prefix) => entry.name.startsWith(prefix))
    ) {
      rmSync(join(screenshotDirectory, entry.name));
    }
  }
}

export function captureComparisonScreenshots(options) {
  if (
    (options.variant === "all" || options.variant === "swift") &&
    process.platform !== "darwin"
  ) {
    throw new Error(
      "Swift版のスクリーンショット撮影はmacOSで実行してください。",
    );
  }

  const tauriDirectory = join(options.sourceRoot, "apps/tauri/KawaCAD");
  const swiftDirectory = join(options.sourceRoot, "apps/macos/KawaCAD");
  const screenshotDirectory = join(options.outputDirectory, "screenshots");
  const legacyOutputDirectory = join(
    options.sourceRoot,
    "test-results/comparison-screenshots",
  );
  const env = { KAWACAD_SCREENSHOT_OUTPUT_DIR: screenshotDirectory };

  clearComparisonScreenshots(options.outputDirectory, options.variant);
  if (
    (options.variant === "all" || options.variant === "tauri") &&
    resolve(legacyOutputDirectory) !== resolve(options.outputDirectory)
  ) {
    clearComparisonScreenshots(legacyOutputDirectory, "tauri");
  }

  if (options.variant === "all" || options.variant === "tauri") {
    runCommand(npmCommand(["run", "screenshots:comparison"]), {
      cwd: tauriDirectory,
      env,
    });
    const hasTauriImages =
      existsSync(screenshotDirectory) &&
      readdirSync(screenshotDirectory).some((name) =>
        name.startsWith("tauri-"),
      );
    const legacyDirectory = join(legacyOutputDirectory, "screenshots");
    if (!hasTauriImages && existsSync(legacyDirectory)) {
      // Older base revisions ignore KAWACAD_SCREENSHOT_OUTPUT_DIR. This keeps
      // local PR comparisons usable while such a revision is checked out.
      mkdirSync(screenshotDirectory, { recursive: true });
      for (const name of readdirSync(legacyDirectory)) {
        if (name.startsWith("tauri-")) {
          copyFileSync(
            join(legacyDirectory, name),
            join(screenshotDirectory, name),
          );
        }
      }
    }
  }
  if (options.variant === "all" || options.variant === "swift") {
    runCommand(
      command("swift", [
        "test",
        "--filter",
        "ComparisonScreenshotTests.testComparisonScreenshots",
      ]),
      { cwd: swiftDirectory, env },
    );
  }

  console.log(
    `Generated ${options.variant} comparison screenshots in ${options.outputDirectory}`,
  );
}

const isMain =
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  captureComparisonScreenshots(
    parseComparisonScreenshotArgs(process.argv.slice(2)),
  );
}
