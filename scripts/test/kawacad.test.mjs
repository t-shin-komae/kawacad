import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { inflateSync } from "node:zlib";
import { generateLicenseNotices } from "../generate-licenses.mjs";
import {
  infoPlistContents,
  parseArgs,
  prePushPlan,
  releaseArtifactPath,
  releasePlan,
  testPlan,
} from "../kawacad.mjs";
import { coverageOutputDirectory, coveragePlan } from "../lib/coverage.mjs";

const repositoryRoot = resolve(
  dirname(fileURLToPath(import.meta.url)),
  "../..",
);

function commandText(spec) {
  return `${spec.program} ${spec.args.join(" ")}`;
}

function pngImage(path) {
  const bytes = readFileSync(path);
  assert.equal(bytes.subarray(0, 8).toString("hex"), "89504e470d0a1a0a");
  const width = bytes.readUInt32BE(16);
  const height = bytes.readUInt32BE(20);
  assert.equal(bytes[24], 8, `${path} must use 8-bit channels`);
  assert.equal(bytes[25], 6, `${path} must use RGBA pixels`);
  assert.equal(bytes[28], 0, `${path} must not be interlaced`);

  const idat = [];
  for (let offset = 8; offset < bytes.length;) {
    const length = bytes.readUInt32BE(offset);
    const type = bytes.subarray(offset + 4, offset + 8).toString("ascii");
    if (type === "IDAT")
      idat.push(bytes.subarray(offset + 8, offset + 8 + length));
    offset += 12 + length;
  }
  const encoded = inflateSync(Buffer.concat(idat));
  const stride = width * 4;
  let previous = Buffer.alloc(stride);
  let hasVisiblePixel = false;
  for (let y = 0; y < height; y += 1) {
    const filter = encoded[y * (stride + 1)];
    const row = Buffer.alloc(stride);
    for (let x = 0; x < stride; x += 1) {
      const raw = encoded[y * (stride + 1) + x + 1];
      const left = x >= 4 ? row[x - 4] : 0;
      const above = previous[x];
      const upperLeft = x >= 4 ? previous[x - 4] : 0;
      const estimate = left + above - upperLeft;
      const paeth = [left, above, upperLeft].reduce((best, candidate) =>
        Math.abs(estimate - candidate) < Math.abs(estimate - best)
          ? candidate
          : best,
      );
      row[x] =
        (raw +
          [0, left, above, Math.floor((left + above) / 2), paeth][filter]) &
        0xff;
    }
    for (let alpha = 3; alpha < stride; alpha += 4)
      hasVisiblePixel ||= row[alpha] > 0;
    previous = row;
  }
  return { width, height, hasVisiblePixel };
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
  assert.match(
    releaseArtifactPath("macos", "swift"),
    /dist\/macos\/swift\/KawaCAD\.app$/u,
  );
  assert.match(
    releaseArtifactPath("macos", "tauri"),
    /dist\/macos\/tauri\/KawaCAD\.app$/u,
  );
  assert.match(
    releaseArtifactPath("windows", "tauri"),
    /dist\/windows\/KawaCAD\.exe$/u,
  );
  assert.match(releaseArtifactPath("linux", "tauri"), /dist\/linux\/KawaCAD$/u);
});

test("test scopes select the expected suites", () => {
  const core = testPlan("core", { nodePlatform: "darwin" })
    .map(commandText)
    .join("\n");
  const tauri = testPlan("tauri", { nodePlatform: "darwin", e2e: true })
    .map(commandText)
    .join("\n");
  assert.match(core, /kawacad-core/);
  assert.doesNotMatch(core, /npm/);
  assert.match(tauri, /npm test/);
  assert.match(tauri, /playwright install chromium/);
  assert.match(tauri, /test:e2e/);
});

test("pre-push verifies Swift formatting, real-Core tests, and the release build", () => {
  const plan = prePushPlan();
  const commands = plan.map(commandText).join("\n");
  const swiftTest = plan.find(
    (spec) => spec.program === "swift" && spec.args[0] === "test",
  );

  assert.match(commands, /swift format lint/);
  assert.match(commands, /cargo build -p kawacad-core-process/);
  assert.match(commands, /swift test/);
  assert.match(commands, /swift build.*--configuration release/);
  assert.equal(
    swiftTest?.env.KAWACAD_CORE_PROCESS.endsWith(
      "target/debug/kawacad-core-process",
    ),
    true,
  );
  assert.equal(
    swiftTest?.env.CLANG_MODULE_CACHE_PATH.endsWith(
      "target/pre-push-module-cache/clang",
    ),
    true,
  );
  assert.equal(
    swiftTest?.env.SWIFTPM_MODULECACHE_OVERRIDE.endsWith(
      "target/pre-push-module-cache/swiftpm",
    ),
    true,
  );
  assert.equal(swiftTest?.env.LEATHER_ENABLE_LIVE_CORE_TESTS, "1");
});

test("Swift is skipped from all-tests planning on non-macOS", () => {
  const plan = testPlan("all", { nodePlatform: "linux" })
    .map(commandText)
    .join("\n");
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

  assert.match(
    developmentPlist,
    /<key>CFBundleName<\/key><string>KawaCAD<\/string>/u,
  );
  assert.match(
    developmentPlist,
    /<key>CFBundleShortVersionString<\/key><string>0\.3\.0<\/string>/u,
  );
  assert.match(
    developmentPlist,
    /<key>KawaCADBuildChannel<\/key><string>development<\/string>/u,
  );
  assert.match(
    developmentPlist,
    /<key>NSHumanReadableCopyright<\/key><string>© 2026 t-shin-komae<\/string>/u,
  );
  assert.match(
    releasePlist,
    /<key>KawaCADBuildChannel<\/key><string>release<\/string>/u,
  );
  assert.match(
    developmentPlist,
    /<key>CFBundleVersion<\/key><string>1<\/string>/u,
  );
});

test("Tauri About metadata switches between development and release display versions", async () => {
  const { productInfoForBuild } = await import(
    new URL("../../apps/tauri/KawaCAD/vite.config.ts", import.meta.url)
  );

  assert.deepEqual(productInfoForBuild(false), {
    name: "KawaCAD",
    version: "0.3.0",
    displayVersion: "0.3.0-dev",
    copyright: "© 2026 t-shin-komae",
  });
  assert.equal(productInfoForBuild(true).displayVersion, "0.3.0");
  assert.equal(Object.hasOwn(productInfoForBuild(true), "buildNumber"), false);
});

test("argument parsing accepts explicit live Core and E2E options", () => {
  const options = parseArgs([
    "test",
    "--scope",
    "tauri",
    "--live-core",
    "--e2e",
    "--dry-run",
  ]);
  assert.equal(options.scope, "tauri");
  assert.equal(options.liveCore, true);
  assert.equal(options.e2e, true);
  assert.equal(options.dryRun, true);
});

test("desktop icon sources have the configured formats, dimensions, and visible pixels", () => {
  const iconDirectory = join(
    repositoryRoot,
    "apps/tauri/KawaCAD/src-tauri/icons",
  );
  for (const [name, dimension] of [
    ["32x32.png", 32],
    ["64x64.png", 64],
    ["128x128.png", 128],
    ["128x128@2x.png", 256],
    ["icon.png", 512],
  ]) {
    assert.deepEqual(pngImage(join(iconDirectory, name)), {
      width: dimension,
      height: dimension,
      hasVisiblePixel: true,
    });
  }

  for (const path of [
    join(iconDirectory, "icon.icns"),
    join(repositoryRoot, "apps/macos/KawaCAD/Resources/KawaCAD.icns"),
  ]) {
    const bytes = readFileSync(path);
    assert.equal(bytes.subarray(0, 4).toString("ascii"), "icns");
    assert.ok(
      bytes.length > 100_000,
      `${path} must contain non-trivial icon data`,
    );
  }
  const ico = readFileSync(join(iconDirectory, "icon.ico"));
  assert.equal(ico.subarray(0, 4).toString("hex"), "00000100");
  assert.ok(ico.length > 10_000);
});

test("desktop package metadata and required offline resources match the shared product configuration", () => {
  const product = JSON.parse(
    readFileSync(join(repositoryRoot, "config/product.json"), "utf8"),
  );
  const tauri = JSON.parse(
    readFileSync(
      join(repositoryRoot, "apps/tauri/KawaCAD/src-tauri/tauri.conf.json"),
      "utf8",
    ),
  );
  const packageManifest = readFileSync(
    join(repositoryRoot, "apps/macos/KawaCAD/Package.swift"),
    "utf8",
  );

  assert.equal(tauri.productName, product.name);
  assert.equal(tauri.version, product.version);
  assert.equal(tauri.bundle.copyright, product.copyright);
  assert.deepEqual(tauri.bundle.icon, [
    "icons/32x32.png",
    "icons/64x64.png",
    "icons/128x128.png",
    "icons/128x128@2x.png",
    "icons/icon.png",
    "icons/icon.ico",
    "icons/icon.icns",
  ]);
  assert.match(packageManifest, /\.process\("Resources"\)/u);
});

test("generated license notices keep runtime dependencies separated by frontend", () => {
  const result = generateLicenseNotices();
  const tauriNames = new Set(result.tauriPackages.map((item) => item.name));
  const swiftNames = new Set(result.swiftPackages.map((item) => item.name));
  const packageJson = JSON.parse(
    readFileSync(
      join(repositoryRoot, "apps/tauri/KawaCAD/package.json"),
      "utf8",
    ),
  );

  assert.ok(tauriNames.has("tauri"));
  assert.ok(tauriNames.has("@tauri-apps/api"));
  assert.ok(swiftNames.has("serde"));
  assert.ok(swiftNames.has("serde_json"));
  assert.equal(
    [...swiftNames].some((name) => name.includes("tauri")),
    false,
  );
  for (const name of Object.keys(packageJson.devDependencies))
    assert.equal(tauriNames.has(name), false, name);
  for (const item of [...result.tauriPackages, ...result.swiftPackages]) {
    for (const field of ["name", "version", "license", "source", "text"])
      assert.ok(item[field]?.trim(), `${item.name}.${field} must not be empty`);
  }

  const tauriNotice = JSON.parse(readFileSync(result.tauriOutputPath, "utf8"));
  const swiftNotice = readFileSync(result.swiftOutputPath, "utf8");
  assert.ok(readFileSync(result.tauriOutputPath).length > 1_000);
  assert.ok(readFileSync(result.swiftOutputPath).length > 1_000);
  assert.equal(tauriNotice.schemaVersion, 1);
  assert.equal(tauriNotice.components.length, result.tauriPackages.length);
  assert.match(swiftNotice, /^# Third-party notices/u);
  assert.doesNotMatch(
    swiftNotice,
    /Generated by scripts\/generate-licenses\.mjs/u,
  );
  assert.doesNotMatch(swiftNotice, /^## .*tauri/imu);
});
