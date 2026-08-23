#!/usr/bin/env node

import {
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  writeFileSync,
} from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import {
  captureComparisonScreenshots,
  parseComparisonScreenshotArgs,
} from "./capture-comparison-screenshots.mjs";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const imageExtensions = new Set([".jpeg", ".jpg", ".png", ".webp"]);

export function defaultReviewRoot(sourceRoot = repositoryRoot) {
  const result = spawnSync(
    "git",
    [
      "-C",
      sourceRoot,
      "rev-parse",
      "--path-format=absolute",
      "--git-common-dir",
    ],
    { encoding: "utf8", shell: false },
  );
  const commonDirectory =
    result.status === 0 ? resolve(result.stdout.trim()) : null;
  const sharedRoot = commonDirectory
    ? dirname(commonDirectory)
    : repositoryRoot;
  return join(sharedRoot, "test-results/ui-reviews");
}

export function parseUiReviewArgs(args) {
  const command = args[0];
  if (!["capture", "report"].includes(command)) {
    throw new Error("Usage: ui-review.mjs <capture|report> --pr <number>");
  }
  const options = {
    command,
    reviewRoot: defaultReviewRoot(),
    sourceRoot: repositoryRoot,
    variant: "all",
  };
  for (let index = 1; index < args.length; index += 1) {
    const argument = args[index];
    const value = args[index + 1];
    if (argument === "--pr" && value) options.pr = value;
    else if (argument === "--side" && value) options.side = value;
    else if (argument === "--source-root" && value)
      options.sourceRoot = resolve(value);
    else if (argument === "--review-root" && value)
      options.reviewRoot = resolve(value);
    else if (argument === "--variant" && value) options.variant = value;
    else throw new Error(`Unknown or incomplete argument: ${argument}`);
    index += 1;
  }
  if (!/^[1-9][0-9]*$/u.test(options.pr ?? "")) {
    throw new Error("--pr must be a positive Pull Request number");
  }
  if (command === "capture" && !["before", "after"].includes(options.side)) {
    throw new Error("capture requires --side before or --side after");
  }
  if (!["all", "swift", "tauri"].includes(options.variant)) {
    throw new Error("--variant must be one of: all, swift, tauri");
  }
  return options;
}

export function reviewDirectory(reviewRoot, pr) {
  return join(reviewRoot, `pr-${pr}`);
}

function gitOutput(sourceRoot, args) {
  const result = spawnSync("git", ["-C", sourceRoot, ...args], {
    encoding: "utf8",
    shell: false,
  });
  return result.status === 0 ? result.stdout.trim() : null;
}

function captureMetadata(options) {
  return {
    pr: Number(options.pr),
    side: options.side,
    variant: options.variant,
    sourceRoot: options.sourceRoot,
    commit: gitOutput(options.sourceRoot, ["rev-parse", "HEAD"]),
    branch: gitOutput(options.sourceRoot, ["branch", "--show-current"]),
    dirty: Boolean(gitOutput(options.sourceRoot, ["status", "--porcelain"])),
    capturedAt: new Date().toISOString(),
  };
}

export function captureUiReview(options) {
  const destination = join(
    reviewDirectory(options.reviewRoot, options.pr),
    options.side,
  );
  const captureOptions = parseComparisonScreenshotArgs([
    "--output-dir",
    destination,
    "--source-root",
    options.sourceRoot,
    "--variant",
    options.variant,
  ]);
  captureComparisonScreenshots(captureOptions);
  mkdirSync(destination, { recursive: true });
  writeFileSync(
    join(destination, "capture.json"),
    `${JSON.stringify(captureMetadata(options), null, 2)}\n`,
  );
  return destination;
}

function listScreenshots(directory) {
  if (!existsSync(directory)) return [];
  return readdirSync(directory, { withFileTypes: true })
    .filter((entry) => {
      const extension = entry.name
        .slice(entry.name.lastIndexOf("."))
        .toLowerCase();
      return entry.isFile() && imageExtensions.has(extension);
    })
    .map((entry) => entry.name)
    .sort((left, right) => left.localeCompare(right, "en"));
}

export function buildReviewEntries(reviewPath) {
  const before = new Set(
    listScreenshots(join(reviewPath, "before", "screenshots")),
  );
  const after = new Set(
    listScreenshots(join(reviewPath, "after", "screenshots")),
  );
  return [...new Set([...before, ...after])]
    .sort((left, right) => left.localeCompare(right, "en"))
    .map((name) => ({
      name,
      before: before.has(name)
        ? `before/screenshots/${encodeURIComponent(name)}`
        : null,
      after: after.has(name)
        ? `after/screenshots/${encodeURIComponent(name)}`
        : null,
      status:
        before.has(name) && after.has(name)
          ? "paired"
          : before.has(name)
            ? "before-only"
            : "after-only",
    }));
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function metadata(reviewPath, side) {
  const path = join(reviewPath, side, "capture.json");
  return existsSync(path) ? JSON.parse(readFileSync(path, "utf8")) : null;
}

function imageOrPlaceholder(source, label) {
  return source
    ? `<img src="${source}" alt="${label}" loading="lazy">`
    : `<div class="missing">${label}画像なし</div>`;
}

export function renderReviewHtml({ pr, entries, before, after }) {
  const cards = entries
    .map((entry) => {
      const name = escapeHtml(entry.name);
      const overlay =
        entry.before && entry.after
          ? `<details><summary>重ね合わせ</summary>
            <div class="overlay" style="--split: 50%">
              <img src="${entry.after}" alt="After overlay">
              <img class="before-overlay" src="${entry.before}" alt="Before overlay">
            </div>
            <input class="slider" type="range" min="0" max="100" value="50" aria-label="Before表示幅">
          </details>`
          : "";
      return `<article class="card" data-name="${name.toLowerCase()}">
        <h2>${name}</h2>
        <div class="pair">
          <figure><figcaption>Before</figcaption>${imageOrPlaceholder(entry.before, "Before")}</figure>
          <figure><figcaption>After</figcaption>${imageOrPlaceholder(entry.after, "After")}</figure>
        </div>
        ${overlay}
      </article>`;
    })
    .join("\n");
  const paired = entries.filter((entry) => entry.status === "paired").length;
  const beforeLabel = before?.commit?.slice(0, 12) ?? "未撮影";
  const afterLabel = after?.commit?.slice(0, 12) ?? "未撮影";
  return `<!doctype html>
<html lang="ja">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>UI Review PR #${escapeHtml(pr)}</title>
  <style>
    :root { color-scheme: light dark; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
    body { margin: 0; background: Canvas; color: CanvasText; }
    header { position: sticky; top: 0; z-index: 2; padding: 16px 24px; border-bottom: 1px solid GrayText; background: Canvas; }
    h1 { margin: 0 0 8px; font-size: 22px; }
    .meta { margin: 0 0 12px; color: GrayText; }
    #filter { width: min(520px, 100%); box-sizing: border-box; padding: 8px 10px; font: inherit; }
    main { display: grid; gap: 20px; padding: 20px; }
    .card { border: 1px solid GrayText; border-radius: 10px; padding: 16px; overflow: hidden; }
    h2 { margin: 0 0 12px; font: 600 15px ui-monospace, SFMono-Regular, Menlo, monospace; }
    .pair { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
    figure { margin: 0; min-width: 0; }
    figcaption { margin-bottom: 6px; font-weight: 600; }
    img { display: block; width: 100%; height: auto; background: #8882; }
    .missing { display: grid; min-height: 160px; place-items: center; border: 1px dashed GrayText; color: GrayText; }
    details { margin-top: 12px; }
    summary { cursor: pointer; }
    .overlay { display: grid; margin-top: 10px; }
    .overlay img { grid-area: 1 / 1; }
    .before-overlay { clip-path: inset(0 calc(100% - var(--split)) 0 0); }
    .slider { width: 100%; margin-top: 8px; }
    [hidden] { display: none !important; }
    @media (max-width: 760px) { .pair { grid-template-columns: 1fr; } header { position: static; } }
  </style>
</head>
<body>
  <header>
    <h1>UI Review — PR #${escapeHtml(pr)}</h1>
    <p class="meta">Before: ${escapeHtml(beforeLabel)} / After: ${escapeHtml(afterLabel)} / ${paired}組</p>
    <input id="filter" type="search" placeholder="ファイル名で絞り込み" aria-label="ファイル名で絞り込み">
  </header>
  <main>${cards || '<p class="missing">比較画像がありません。</p>'}</main>
  <script>
    const filter = document.querySelector("#filter");
    filter.addEventListener("input", () => {
      const query = filter.value.toLowerCase();
      for (const card of document.querySelectorAll(".card")) card.hidden = !card.dataset.name.includes(query);
    });
    for (const slider of document.querySelectorAll(".slider")) {
      slider.addEventListener("input", () => slider.previousElementSibling.style.setProperty("--split", slider.value + "%"));
    }
  </script>
</body>
</html>
`;
}

export function generateUiReviewReport(options) {
  const destination = reviewDirectory(options.reviewRoot, options.pr);
  const entries = buildReviewEntries(destination);
  const manifest = {
    pr: Number(options.pr),
    generatedAt: new Date().toISOString(),
    before: metadata(destination, "before"),
    after: metadata(destination, "after"),
    entries,
  };
  mkdirSync(destination, { recursive: true });
  writeFileSync(
    join(destination, "manifest.json"),
    `${JSON.stringify(manifest, null, 2)}\n`,
  );
  writeFileSync(join(destination, "index.html"), renderReviewHtml(manifest));
  return join(destination, "index.html");
}

function main() {
  const options = parseUiReviewArgs(process.argv.slice(2));
  if (options.command === "capture") captureUiReview(options);
  const report = generateUiReviewReport(options);
  console.log(`UI review report: ${relative(repositoryRoot, report)}`);
}

const isMain =
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) main();
