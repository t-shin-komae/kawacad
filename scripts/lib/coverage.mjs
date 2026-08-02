import fs from "node:fs";
import { command, npmCommand, runCommand, ensureDirectory, removeDirectory } from "./command.mjs";
import { coveragePath, paths } from "./paths.mjs";

export const coverageScopes = ["core", "swift", "tauri"];

export function coverageOutputDirectory(scope) {
  return scope === "core" ? coveragePath("rust-core") : scope === "swift" ? coveragePath("swiftui") : coveragePath("tauri");
}

export function coveragePlan(scope, { liveCore = false } = {}) {
  switch (scope) {
    case "core":
      return [
        command("cargo", ["llvm-cov", "-p", "kawacad-core", "--lcov", "--output-path", coveragePath("rust-core", "lcov.info")]),
        command("cargo", ["llvm-cov", "-p", "kawacad-core", "--html", "--output-dir", coveragePath("rust-core")]),
      ];
    case "swift":
      return [
        command("swift", ["test", "--package-path", paths.macosPackage, "--enable-code-coverage", "--show-codecov-path"], {
          env: liveCore ? { LEATHER_ENABLE_LIVE_CORE_TESTS: "1" } : {},
        }),
      ];
    case "tauri":
      return [
        npmCommand(["run", "test:coverage", "--", `--coverage.reportsDirectory=${coveragePath("tauri")}`]),
      ];
    default:
      throw new Error(`Unknown coverage scope: ${scope}`);
  }
}

export function prepareCoverageDirectory(scope, dryRun = false) {
  const directory = coverageOutputDirectory(scope);
  if (!dryRun) {
    removeDirectory(directory);
    ensureDirectory(directory);
  }
  return directory;
}

export function runCoverage(scope, { dryRun = false, liveCore = false } = {}) {
  const directory = prepareCoverageDirectory(scope, dryRun);
  const specs = coveragePlan(scope, { liveCore });
  const cleanupSpecs = scope === "core" ? [command("cargo", ["llvm-cov", "clean", "--workspace"])] : [];
  if (dryRun) {
    [...cleanupSpecs, ...specs].forEach((spec) => console.log(`[dry-run] ${spec.program} ${spec.args.join(" ")}`));
    return;
  }

  if (scope === "tauri") {
    runCommand(specs[0], { cwd: paths.tauriPackage });
    return;
  }

  if (scope === "swift") {
    const result = runCommand(specs[0], { cwd: paths.repositoryRoot, env: specs[0].env, capture: true });
    process.stdout.write(result.stdout);
    process.stderr.write(result.stderr);
    const coverageFile = result.stdout.split(/\r?\n/u).map((line) => line.trim()).find((line) => line.endsWith(".json"));
    if (!coverageFile || !fs.existsSync(coverageFile)) throw new Error(`Swift coverage JSON was not found: ${coverageFile ?? "<no path reported>"}`);
    fs.copyFileSync(coverageFile, `${directory}/coverage.json`);
    return;
  }

  cleanupSpecs.forEach((spec) => runCommand(spec, { cwd: paths.repositoryRoot }));
  specs.forEach((spec) => runCommand(spec, { cwd: paths.repositoryRoot }));
}
