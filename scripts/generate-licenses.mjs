#!/usr/bin/env node

/**
 * Generate the notices shown by both desktop frontends.
 *
 * The input is the resolved dependency graph, not the package manifests:
 * this keeps dev-only tools out of the shipped notice while retaining
 * transitive runtime dependencies. Missing license files are kept as an
 * explicit entry so the release review cannot silently drop a dependency.
 */
import { execFileSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  writeFileSync,
} from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const tauriDir = join(root, "apps/tauri/KawaCAD");
const packageLockPath = join(tauriDir, "package-lock.json");
const cargoManifestPath = join(tauriDir, "src-tauri/Cargo.toml");
const swiftPackagePath = join(root, "apps/macos/KawaCAD/Package.swift");
const swiftResolvedPath = join(root, "apps/macos/KawaCAD/Package.resolved");
const swiftBuildPath = join(root, "apps/macos/KawaCAD/.build");
const tauriOutputPath = join(tauriDir, "public/ThirdPartyNotices.json");
const swiftOutputPath = join(
  root,
  "apps/macos/KawaCAD/Sources/KawaCADApp/Resources/ThirdPartyNotices.generated.md",
);

function licenseFiles(directory) {
  if (!existsSync(directory)) return [];
  return readdirSync(directory)
    .filter((name) => /^(license|copying|notice)/i.test(name))
    .sort()
    .map((name) => join(directory, name))
    .filter((path) => !path.endsWith(".json"));
}

function licenseText(directory, expression) {
  const files = licenseFiles(directory);
  if (!files.length) {
    return `License text was not found in the package source.\nDeclared license expression: ${expression ?? "unknown"}\nPackage source must be reviewed before release.`;
  }
  return files
    .map(
      (path) =>
        `----- ${relative(directory, path)} -----\n${readFileSync(path, "utf8").trim()}`,
    )
    .join("\n\n");
}

function nodePackages() {
  const lock = JSON.parse(readFileSync(packageLockPath, "utf8"));
  return Object.entries(lock.packages)
    .filter(([path, item]) => path && item.dev !== true)
    .map(([path, item]) => {
      const directory = join(tauriDir, path);
      const packageJsonPath = join(directory, "package.json");
      const packageJson = existsSync(packageJsonPath)
        ? JSON.parse(readFileSync(packageJsonPath, "utf8"))
        : {};
      return {
        name: packageJson.name ?? path.slice(path.lastIndexOf("/") + 1),
        version: packageJson.version ?? item.version ?? "unknown",
        license: packageJson.license ?? item.license ?? "unknown",
        source: item.resolved ?? `npm:${packageJson.name ?? path}`,
        text: licenseText(directory, item.license),
      };
    });
}

function cargoMetadata() {
  const metadata = JSON.parse(
    execFileSync(
      "cargo",
      [
        "metadata",
        "--format-version",
        "1",
        "--locked",
        "--manifest-path",
        cargoManifestPath,
      ],
      {
        cwd: root,
        encoding: "utf8",
        maxBuffer: 32 * 1024 * 1024,
      },
    ),
  );
  return metadata;
}

function rustPackages(metadata, rootPackageName) {
  const packageById = new Map(metadata.packages.map((item) => [item.id, item]));
  const nodeById = new Map(
    (metadata.resolve?.nodes ?? []).map((node) => [node.id, node]),
  );
  const root = metadata.packages.find((item) => item.name === rootPackageName);
  if (!root) throw new Error(`Cargo package not found: ${rootPackageName}`);

  const visited = new Set();
  const pending = [root.id];
  while (pending.length) {
    const id = pending.pop();
    if (!id || visited.has(id)) continue;
    visited.add(id);
    for (const dependency of nodeById.get(id)?.deps ?? [])
      pending.push(dependency.pkg);
  }

  return [...visited]
    .map((id) => packageById.get(id))
    .filter((item) => item?.source)
    .map((item) => {
      const directory = dirname(item.manifest_path);
      return {
        name: item.name,
        version: item.version,
        license: item.license ?? "unknown",
        source: item.repository ?? item.source,
        text: licenseText(directory, item.license),
      };
    });
}

function swiftRuntimePackageIdentities() {
  if (!existsSync(swiftPackagePath)) return new Set();
  const packageSource = readFileSync(swiftPackagePath, "utf8");
  const executableSource = packageSource.split(".testTarget(", 1)[0];
  return new Set(
    [
      ...executableSource.matchAll(
        /\.product\(name:\s*"[^"]+",\s*package:\s*"([^"]+)"/g,
      ),
    ].map((match) => match[1]),
  );
}

function swiftPackages() {
  if (!existsSync(swiftResolvedPath)) return [];
  const runtimeIdentities = swiftRuntimePackageIdentities();
  if (!runtimeIdentities.size) return [];
  const resolved = JSON.parse(readFileSync(swiftResolvedPath, "utf8"));
  return resolved.pins
    .filter((pin) => runtimeIdentities.has(pin.identity))
    .map((pin) => {
      const state = pin.state ?? {};
      const version = state.version ?? state.revision ?? "unknown";
      const directory = join(swiftBuildPath, "checkouts", pin.identity);
      return {
        name: pin.identity,
        version,
        license: "review package LICENSE/NOTICE",
        source: pin.location,
        text: licenseText(directory, "unknown"),
      };
    });
}

function uniquePackages(packages) {
  return packages
    .sort((a, b) =>
      `${a.name}@${a.version}`.localeCompare(`${b.name}@${b.version}`),
    )
    .filter(
      (item, index, all) =>
        index === 0 ||
        `${item.name}@${item.version}` !==
          `${all[index - 1].name}@${all[index - 1].version}`,
    );
}

export function generateLicenseNotices() {
  const metadata = cargoMetadata();
  const tauriPackages = uniquePackages([
    ...nodePackages(),
    ...rustPackages(metadata, "kawa-cad-tauri"),
  ]);
  const swiftPackagesForDisplay = uniquePackages([
    ...rustPackages(metadata, "kawacad-core-process"),
    ...swiftPackages(),
  ]);
  mkdirSync(dirname(tauriOutputPath), { recursive: true });
  writeFileSync(
    tauriOutputPath,
    `${JSON.stringify({ schemaVersion: 1, components: tauriPackages }, null, 2)}\n`,
  );

  const swiftSource = `# Third-party notices\n\n${swiftPackagesForDisplay
    .map(
      (item) =>
        `## ${item.name} ${item.version}\n\nLicense: ${item.license}\n\nSource: ${item.source}\n\n${item.text}`,
    )
    .join("\n\n")}\n`;
  writeFileSync(swiftOutputPath, swiftSource);

  return {
    tauriPackages,
    swiftPackages: swiftPackagesForDisplay,
    tauriOutputPath,
    swiftOutputPath,
  };
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(resolve(process.argv[1])).href
) {
  const result = generateLicenseNotices();
  console.log(
    `Generated ${result.tauriPackages.length} Tauri and ${result.swiftPackages.length} macOS third-party license entries.`,
  );
}
