#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

const repositoryRoot = process.cwd();
const allowlist = JSON.parse(
  fs.readFileSync(path.join(repositoryRoot, "scripts/localization-allowlist.json"), "utf8"),
);
const allowedLiterals = new Set(
  allowlist.map(({ file, text }) => `${file}\0${text}`),
);
const japaneseCharacters = /[ぁ-んァ-ヶ一-龯]/u;
const stringLiteral = /"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`/gu;
const sourceRoots = [
  {
    directory: "apps/tauri/KawaCAD/src",
    shouldScan(relativePath) {
      return !relativePath.startsWith("localization/") && !relativePath.startsWith("test/");
    },
  },
  {
    directory: "apps/macos/KawaCAD/Sources/KawaCADApp",
    shouldScan(relativePath) {
      return !relativePath.startsWith("Resources/");
    },
  },
];

function sourceFiles(directory, relativeDirectory = "") {
  const absoluteDirectory = path.join(repositoryRoot, directory, relativeDirectory);
  return fs.readdirSync(absoluteDirectory, { withFileTypes: true }).flatMap((entry) => {
    const relativePath = path.join(relativeDirectory, entry.name).replaceAll(path.sep, "/");
    if (entry.isDirectory()) return sourceFiles(directory, relativePath);
    if (!/\.(?:swift|ts|tsx)$/u.test(entry.name)) return [];
    return [relativePath];
  });
}

const violations = [];
for (const { directory, shouldScan } of sourceRoots) {
  for (const relativePath of sourceFiles(directory)) {
    if (!shouldScan(relativePath)) continue;
    const repositoryPath = path.join(directory, relativePath).replaceAll(path.sep, "/");
    const contents = fs.readFileSync(path.join(repositoryRoot, repositoryPath), "utf8");
    for (const [lineNumber, line] of contents.split("\n").entries()) {
      for (const match of line.matchAll(stringLiteral)) {
        const text = match[0].slice(1, -1);
        if (!japaneseCharacters.test(text)) continue;
        if (!allowedLiterals.has(`${repositoryPath}\0${text}`)) {
          violations.push(`${repositoryPath}:${lineNumber + 1}: ${text}`);
        }
      }
    }
  }
}

if (violations.length > 0) {
  console.error("Unlocalized Japanese literals found outside localization catalogs:");
  for (const violation of violations) console.error(`- ${violation}`);
  process.exitCode = 1;
} else {
  console.log("Localization literal scan passed.");
}
