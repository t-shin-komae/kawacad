import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptsDirectory = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

export const repositoryRoot = path.resolve(scriptsDirectory, "..");
export const paths = {
  repositoryRoot,
  scriptsDirectory,
  appsDirectory: path.join(repositoryRoot, "apps"),
  macosPackage: path.join(repositoryRoot, "apps", "macos", "KawaCAD"),
  tauriPackage: path.join(repositoryRoot, "apps", "tauri", "KawaCAD"),
  tauriRustPackage: path.join(repositoryRoot, "apps", "tauri", "KawaCAD", "src-tauri"),
  coverageDirectory: path.join(repositoryRoot, "coverage"),
  distributionDirectory: path.join(repositoryRoot, "dist"),
  rustReleaseDirectory: path.join(repositoryRoot, "target", "release"),
};

export function coveragePath(scope, ...segments) {
  return path.join(paths.coverageDirectory, scope, ...segments);
}

export function distributionPath(platform, variant, ...segments) {
  return path.join(paths.distributionDirectory, platform, variant, ...segments);
}
