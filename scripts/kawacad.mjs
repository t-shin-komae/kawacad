#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import {
  assertExecutable,
  command,
  copyDirectory,
  copyFile,
  ensureDirectory,
  findExisting,
  localBinary,
  npmCommand,
  removeDirectory,
  runCommand,
} from "./lib/command.mjs";
import { coverageScopes, runCoverage } from "./lib/coverage.mjs";
import { paths, distributionPath } from "./lib/paths.mjs";
import { currentPlatform, isNativePlatform, supportedPlatforms } from "./lib/platform.mjs";

const swiftSourceDirectory = path.join(paths.macosPackage, "Sources");
const swiftTestDirectory = path.join(paths.macosPackage, "Tests");
const swiftAppIcon = path.join(paths.macosPackage, "Resources", "KawaCAD.icns");
const prePushModuleCacheRoot = path.join(paths.repositoryRoot, "target", "pre-push-module-cache");
const prePushSwiftEnvironment = {
  CLANG_MODULE_CACHE_PATH: path.join(prePushModuleCacheRoot, "clang"),
  KAWACAD_CORE_PROCESS: path.join(paths.repositoryRoot, "target", "debug", "kawacad-core-process"),
  LEATHER_ENABLE_LIVE_CORE_TESTS: "1",
  SWIFTPM_MODULECACHE_OVERRIDE: path.join(prePushModuleCacheRoot, "swiftpm"),
};

export function parseArgs(argv) {
  const [commandName = "help", ...tokens] = argv;
  const options = { command: commandName === "--help" || commandName === "-h" ? "help" : commandName, platform: currentPlatform(), variant: undefined, scope: "all", dryRun: false, fix: false, liveCore: false, e2e: false };
  if (commandName === "--help" || commandName === "-h") options.help = true;
  for (let index = 0; index < tokens.length; index += 1) {
    const token = tokens[index];
    if (token === "--help" || token === "-h") options.help = true;
    else if (token === "--dry-run") options.dryRun = true;
    else if (token === "--fix") options.fix = true;
    else if (token === "--live-core") options.liveCore = true;
    else if (token === "--e2e") options.e2e = true;
    else if (token === "--platform" || token === "--variant" || token === "--scope") {
      const value = tokens[index + 1];
      if (!value || value.startsWith("--")) throw new Error(`${token} requires a value`);
      options[token.slice(2)] = value;
      index += 1;
    } else {
      throw new Error(`Unknown option: ${token}`);
    }
  }
  if (options.command === "release" && !options.variant) options.variant = options.platform === "macos" ? "all" : "tauri";
  return options;
}

export function preCommitPlan({ fix = false, nodePlatform = process.platform } = {}) {
  const specs = [
    command("cargo", fix ? ["fmt", "--all"] : ["fmt", "--all", "--check"], { cwd: paths.repositoryRoot }),
    command("cargo", ["clippy", "--workspace", "--all-targets", "--", "-D", "warnings"], { cwd: paths.repositoryRoot }),
  ];
  if (currentPlatform(nodePlatform) === "macos") {
    if (fix) specs.push(command("swift", ["format", "format", "--recursive", "--in-place", swiftSourceDirectory, swiftTestDirectory], { cwd: paths.repositoryRoot }));
    specs.push(command("swift", ["format", "lint", "--recursive", "--strict", swiftSourceDirectory, swiftTestDirectory], { cwd: paths.repositoryRoot }));
  }
  specs.push(
    npmCommand(["run", fix ? "format" : "format:check"], { cwd: paths.tauriPackage }),
    command(localBinary(paths.tauriPackage, "tsc"), ["--noEmit"], { cwd: paths.tauriPackage }),
  );
  return specs;
}

export function prePushPlan() {
  const releaseSpecs = releasePlan("macos", "swift").map((spec) =>
    spec.program === "swift"
      ? { ...spec, env: { ...spec.env, ...prePushSwiftEnvironment } }
      : spec,
  );
  return [
    command("swift", ["format", "lint", "--recursive", "--strict", swiftSourceDirectory, swiftTestDirectory], { cwd: paths.repositoryRoot }),
    command("cargo", ["build", "-p", "kawacad-core-process"], { cwd: paths.repositoryRoot }),
    command("swift", ["test", "--package-path", paths.macosPackage], {
      cwd: paths.repositoryRoot,
      env: prePushSwiftEnvironment,
    }),
    ...releaseSpecs,
  ];
}

export function testPlan(scope, { liveCore = false, e2e = false, nodePlatform = process.platform } = {}) {
  const specs = [];
  if (scope === "core" || scope === "all") {
    specs.push(command("cargo", ["test", "-p", "kawacad-core", "-p", "kawacad-core-process", "-p", "kawacad-output-engine"], { cwd: paths.repositoryRoot }));
  }
  if (scope === "swift" || scope === "all") {
    if (currentPlatform(nodePlatform) === "macos") {
      specs.push(command("swift", ["test", "--package-path", paths.macosPackage], {
        cwd: paths.repositoryRoot,
        env: liveCore ? { LEATHER_ENABLE_LIVE_CORE_TESTS: "1" } : {},
      }));
    } else if (scope === "swift") {
      throw new Error("Swift tests require macOS");
    }
  }
  if (scope === "tauri" || scope === "all") {
    specs.push(
      npmCommand(["test"], { cwd: paths.tauriPackage }),
      command("cargo", ["test", "-p", "kawa-cad-tauri"], { cwd: paths.repositoryRoot }),
    );
    if (e2e) {
      specs.push(command(localBinary(paths.tauriPackage, "playwright"), ["install", "chromium"], { cwd: paths.tauriPackage }));
      specs.push(npmCommand(["run", "test:e2e"], { cwd: paths.tauriPackage }));
    }
  }
  if (!["core", "swift", "tauri", "all"].includes(scope)) throw new Error(`Unknown test scope: ${scope}`);
  return specs;
}

export function releasePlan(platform, variant = platform === "macos" ? "all" : "tauri") {
  if (!supportedPlatforms.includes(platform)) throw new Error(`Unsupported release platform: ${platform}`);
  if (platform === "macos") {
    if (!["swift", "tauri", "all"].includes(variant)) throw new Error(`Unsupported macOS release variant: ${variant}`);
    const specs = [];
    if (variant === "swift" || variant === "all") {
      specs.push(
        command("cargo", ["build", "-p", "kawacad-core-process", "--release"], { cwd: paths.repositoryRoot }),
        command("swift", ["build", "--package-path", paths.macosPackage, "--configuration", "release"], { cwd: paths.repositoryRoot }),
      );
    }
    if (variant === "tauri" || variant === "all") {
      specs.push(npmCommand(["run", "tauri", "--", "build", "--bundles", "app", "--no-sign"], { cwd: paths.tauriPackage }));
    }
    return specs;
  }
  if (variant !== "tauri") throw new Error(`${platform} release only supports the Tauri variant`);
  return [npmCommand(["run", "tauri", "--", "build", "--no-bundle"], { cwd: paths.tauriPackage })];
}

export function releaseArtifactPath(platform, variant) {
  if (platform === "macos") return distributionPath("macos", variant, "KawaCAD.app");
  const extension = platform === "windows" ? ".exe" : "";
  return path.join(paths.distributionDirectory, platform, `KawaCAD${extension}`);
}

function executeSpecs(specs, { dryRun = false } = {}) {
  for (const spec of specs) runCommand(spec, { dryRun, cwd: spec.cwd, env: spec.env });
}

function assertNative(platform, dryRun) {
  if (!dryRun && !isNativePlatform(platform)) throw new Error(`Native ${platform} builds must run on ${platform}`);
}

function writeInfoPlist(destination) {
  const contents = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleExecutable</key><string>KawaCAD</string>
<key>CFBundleIdentifier</key><string>com.leathercraft.cad</string>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundleIconFile</key><string>KawaCAD</string>
<key>CFBundleName</key><string>KawaCAD</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
`;
  fs.writeFileSync(destination, contents);
}

function stageSwiftApp({ dryRun = false, env = {} } = {}) {
  const destination = releaseArtifactPath("macos", "swift");
  const coreProcess = path.join(paths.rustReleaseDirectory, "kawacad-core-process");
  if (dryRun) {
    console.log(`[stage] Swift app -> ${destination}`);
    return;
  }
  const binResult = runCommand(command("swift", ["build", "--package-path", paths.macosPackage, "--configuration", "release", "--show-bin-path"]), { cwd: paths.repositoryRoot, capture: true, env });
  const binDirectory = binResult.stdout.trim().split(/\r?\n/u).at(-1);
  if (!binDirectory) throw new Error("SwiftPM release bin path was not reported");
  const swiftExecutable = path.join(binDirectory, "KawaCAD");
  assertExecutable(swiftExecutable, "Swift KawaCAD executable");
  assertExecutable(coreProcess, "kawacad-core-process");
  removeDirectory(destination);
  const macosDirectory = path.join(destination, "Contents", "MacOS");
  const resourcesDirectory = path.join(destination, "Contents", "Resources");
  ensureDirectory(macosDirectory);
  ensureDirectory(resourcesDirectory);
  copyFile(swiftExecutable, path.join(macosDirectory, "KawaCAD"));
  copyFile(coreProcess, path.join(macosDirectory, "kawacad-core-process"));
  copyFile(swiftAppIcon, path.join(resourcesDirectory, "KawaCAD.icns"));
  for (const entry of fs.readdirSync(binDirectory)) {
    if (entry.endsWith(".bundle")) copyDirectory(path.join(binDirectory, entry), path.join(macosDirectory, entry));
  }
  writeInfoPlist(path.join(destination, "Contents", "Info.plist"));
  runCommand(command("plutil", ["-lint", path.join(destination, "Contents", "Info.plist")]), { cwd: paths.repositoryRoot });
  console.log(`[artifact] ${destination}`);
}

function stageTauriMacApp({ dryRun = false } = {}) {
  const destination = releaseArtifactPath("macos", "tauri");
  if (dryRun) {
    console.log(`[stage] Tauri macOS app -> ${destination}`);
    return;
  }
  const source = findExisting([
    path.join(paths.rustReleaseDirectory, "bundle", "macos", "KawaCAD.app"),
    path.join(paths.tauriRustPackage, "target", "release", "bundle", "macos", "KawaCAD.app"),
    path.join(paths.tauriPackage, "src-tauri", "target", "release", "bundle", "macos", "KawaCAD.app"),
  ], "Tauri macOS app");
  copyDirectory(source, destination);
  console.log(`[artifact] ${destination}`);
}

function stageTauriBinary(platform, { dryRun = false } = {}) {
  const extension = platform === "windows" ? ".exe" : "";
  const destination = releaseArtifactPath(platform, "tauri");
  if (dryRun) {
    console.log(`[stage] Tauri ${platform} binary -> ${destination}`);
    return;
  }
  const source = findExisting([
    path.join(paths.rustReleaseDirectory, `kawa-cad-tauri${extension}`),
    path.join(paths.rustReleaseDirectory, `kawa_cad_tauri${extension}`),
    path.join(paths.tauriRustPackage, "target", "release", `kawa-cad-tauri${extension}`),
    path.join(paths.tauriRustPackage, "target", "release", `kawa_cad_tauri${extension}`),
  ], `Tauri ${platform} binary`);
  copyFile(source, destination);
  if (platform !== "windows") fs.chmodSync(destination, 0o755);
  console.log(`[artifact] ${destination}`);
}

function runRelease(options) {
  const { platform, variant, dryRun } = options;
  assertNative(platform, dryRun);
  executeSpecs(releasePlan(platform, variant), { dryRun });
  if (platform === "macos") {
    if (variant === "swift" || variant === "all") stageSwiftApp({ dryRun });
    if (variant === "tauri" || variant === "all") stageTauriMacApp({ dryRun });
  } else stageTauriBinary(platform, { dryRun });
}

function runTests(options) {
  executeSpecs(testPlan(options.scope, options), { dryRun: options.dryRun });
  if (options.scope === "all" && currentPlatform() !== "macos") console.log("[skip] Swift tests require macOS");
}

function runPreCommit(options) {
  executeSpecs(preCommitPlan({ fix: options.fix }), { dryRun: options.dryRun });
}

function runPrePush(options) {
  assertNative("macos", options.dryRun);
  if (!options.dryRun) {
    ensureDirectory(prePushSwiftEnvironment.CLANG_MODULE_CACHE_PATH);
    ensureDirectory(prePushSwiftEnvironment.SWIFTPM_MODULECACHE_OVERRIDE);
  }
  executeSpecs(prePushPlan(), { dryRun: options.dryRun });
  stageSwiftApp({ dryRun: options.dryRun, env: prePushSwiftEnvironment });
}

function printHelp() {
  console.log(`KawaCAD project automation\n\nUsage:\n  node scripts/kawacad.mjs <command> [options]\n\nCommands:\n  pre-commit                 Run formatters and lint checks\n  pre-push                   Verify the Swift application on macOS\n  test --scope <scope>      Run core, swift, tauri, or all tests\n  coverage --scope <scope>  Generate native coverage artifacts\n  release                   Build a native release artifact\n\nOptions:\n  --platform <macos|windows|linux>\n  --variant <swift|tauri|all>\n  --scope <core|swift|tauri|all>\n  --live-core               Include Swift tests using the real Core process\n  --e2e                     Include Tauri Playwright tests\n  --fix                     Apply formatters during pre-commit\n  --dry-run                 Print commands without running them\n  --help                    Show this help\n`);
}

export async function main(argv = process.argv.slice(2)) {
  const options = parseArgs(argv);
  if (options.help || options.command === "help") return printHelp();
  switch (options.command) {
    case "pre-commit":
      return runPreCommit(options);
    case "pre-push":
      return runPrePush(options);
    case "test":
      return runTests(options);
    case "coverage":
      if (options.scope === "all") {
        for (const scope of coverageScopes) {
          if (scope === "swift" && currentPlatform() !== "macos") {
            console.log("[skip] Swift coverage requires macOS");
            continue;
          }
          runCoverage(scope, options);
        }
      } else {
        if (options.scope === "swift" && currentPlatform() !== "macos" && !options.dryRun) throw new Error("Swift coverage requires macOS");
        runCoverage(options.scope, options);
      }
      return;
    case "release":
      return runRelease(options);
    default:
      throw new Error(`Unknown command: ${options.command}`);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main().catch((error) => {
    console.error(`[error] ${error.message}`);
    process.exitCode = 1;
  });
}
