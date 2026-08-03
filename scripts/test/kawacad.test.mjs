import assert from "node:assert/strict";
import test from "node:test";
import { parseArgs, releaseArtifactPath, releasePlan, testPlan } from "../kawacad.mjs";
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

test("argument parsing accepts explicit live Core and E2E options", () => {
  const options = parseArgs(["test", "--scope", "tauri", "--live-core", "--e2e", "--dry-run"]);
  assert.equal(options.scope, "tauri");
  assert.equal(options.liveCore, true);
  assert.equal(options.e2e, true);
  assert.equal(options.dryRun, true);
});
