import assert from "node:assert/strict";
import test from "node:test";
import { infoPlistContents, parseArgs, prePushPlan, releaseArtifactPath, releasePlan, testPlan } from "../kawacad.mjs";
import { coverageOutputDirectory, coveragePlan } from "../lib/coverage.mjs";

function commandText(spec) {
  return `${spec.program} ${spec.args.join(" ")}`;
}

test("release plan supports both macOS variants", () => {
  const swift = releasePlan("macos", "swift").map(commandText).join("\n");
  const tauri = releasePlan("macos", "tauri").map(commandText).join("\n");
  assert.match(swift, /swift build/);
  assert.match(swift, /kawacad-core-process/);
  assert.match(tauri, /build --bundles app --no-sign/);
  assert.equal(releasePlan("macos", "swift")[0].env.KAWACAD_RELEASE, "1");
  assert.equal(releasePlan("macos", "tauri")[0].env.KAWACAD_RELEASE, "1");
});

test("Windows and Linux release plans use the Tauri binary path", () => {
  for (const platform of ["windows", "linux"]) {
    const plan = releasePlan(platform, "tauri").map(commandText).join("\n");
    assert.match(plan, /build --no-bundle/);
  }
});

test("release artifacts use the platform-specific formats and paths", () => {
  assert.match(releaseArtifactPath("macos", "swift"), /dist\/macos\/swift\/KawaCAD\.app$/u);
  assert.match(releaseArtifactPath("macos", "tauri"), /dist\/macos\/tauri\/KawaCAD\.app$/u);
  assert.match(releaseArtifactPath("windows", "tauri"), /dist\/windows\/KawaCAD\.exe$/u);
  assert.match(releaseArtifactPath("linux", "tauri"), /dist\/linux\/KawaCAD$/u);
});

test("test scopes select the expected suites", () => {
  const core = testPlan("core", { nodePlatform: "darwin" }).map(commandText).join("\n");
  const tauri = testPlan("tauri", { nodePlatform: "darwin", e2e: true }).map(commandText).join("\n");
  assert.match(core, /kawacad-core/);
  assert.doesNotMatch(core, /npm/);
  assert.match(tauri, /npm test/);
  assert.match(tauri, /playwright install chromium/);
  assert.match(tauri, /test:e2e/);
});

test("pre-push verifies Swift formatting, real-Core tests, and the release build", () => {
  const plan = prePushPlan();
  const commands = plan.map(commandText).join("\n");
  const swiftTest = plan.find((spec) => spec.program === "swift" && spec.args[0] === "test");

  assert.match(commands, /swift format lint/);
  assert.match(commands, /cargo build -p kawacad-core-process/);
  assert.match(commands, /swift test/);
  assert.match(commands, /swift build.*--configuration release/);
  assert.equal(swiftTest?.env.KAWACAD_CORE_PROCESS.endsWith("target/debug/kawacad-core-process"), true);
  assert.equal(swiftTest?.env.CLANG_MODULE_CACHE_PATH.endsWith("target/pre-push-module-cache/clang"), true);
  assert.equal(swiftTest?.env.SWIFTPM_MODULECACHE_OVERRIDE.endsWith("target/pre-push-module-cache/swiftpm"), true);
  assert.equal(swiftTest?.env.LEATHER_ENABLE_LIVE_CORE_TESTS, "1");
});

test("Swift is skipped from all-tests planning on non-macOS", () => {
  const plan = testPlan("all", { nodePlatform: "linux" }).map(commandText).join("\n");
  assert.doesNotMatch(plan, /swift test/);
  assert.match(plan, /cargo test/);
  assert.match(plan, /npm test/);
});

test("coverage artifacts remain outside target", () => {
  for (const scope of ["core", "swift", "tauri"]) {
    const plan = coveragePlan(scope).map(commandText).join("\n");
    assert.match(coverageOutputDirectory(scope), /coverage[\\/]/);
    assert.doesNotMatch(plan, /target[\\/]/);
  }
});

test("argument parsing defaults macOS release to both variants", () => {
  const options = parseArgs(["release", "--platform", "macos"]);
  assert.equal(options.variant, "all");
  assert.equal(options.platform, "macos");
});

test("staged Swift metadata contains the shared product information without a build number", () => {
  const developmentPlist = infoPlistContents();
  const releasePlist = infoPlistContents({ release: true });

  assert.match(developmentPlist, /<key>CFBundleName<\/key><string>KawaCAD<\/string>/u);
  assert.match(developmentPlist, /<key>CFBundleShortVersionString<\/key><string>0\.1\.0<\/string>/u);
  assert.match(developmentPlist, /<key>KawaCADBuildChannel<\/key><string>development<\/string>/u);
  assert.match(developmentPlist, /<key>NSHumanReadableCopyright<\/key><string>© 2026 t-shin-komae<\/string>/u);
  assert.match(releasePlist, /<key>KawaCADBuildChannel<\/key><string>release<\/string>/u);
  assert.match(developmentPlist, /<key>CFBundleVersion<\/key><string>1<\/string>/u);
});

test("argument parsing accepts explicit live Core and E2E options", () => {
  const options = parseArgs(["test", "--scope", "tauri", "--live-core", "--e2e", "--dry-run"]);
  assert.equal(options.scope, "tauri");
  assert.equal(options.liveCore, true);
  assert.equal(options.e2e, true);
  assert.equal(options.dryRun, true);
});
