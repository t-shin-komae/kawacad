import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { parseComparisonScreenshotArgs } from "../capture-comparison-screenshots.mjs";
import {
  buildReviewComparison,
  buildReviewEntries,
  defaultReviewRoot,
  parseUiReviewArgs,
  renderReviewHtml,
  reviewDirectory,
} from "../ui-review.mjs";

test("comparison screenshot arguments accept isolated source and output roots", () => {
  const options = parseComparisonScreenshotArgs([
    "--source-root",
    "/tmp/source",
    "--output-dir",
    "/tmp/output",
    "--variant",
    "tauri",
  ]);
  assert.equal(options.sourceRoot, "/tmp/source");
  assert.equal(options.outputDirectory, "/tmp/output");
  assert.equal(options.variant, "tauri");
});

test("UI review arguments isolate captures by PR and side", () => {
  const options = parseUiReviewArgs([
    "capture",
    "--pr",
    "123",
    "--side",
    "before",
    "--variant",
    "swift",
  ]);
  assert.equal(options.pr, "123");
  assert.equal(options.side, "before");
  assert.equal(options.variant, "swift");
  assert.match(reviewDirectory(options.reviewRoot, options.pr), /pr-123$/u);
  assert.match(defaultReviewRoot(), /test-results[\\/]ui-reviews$/u);
});

test("UI review arguments reject missing PR numbers and capture sides", () => {
  assert.throws(() => parseUiReviewArgs(["report"]), /positive Pull Request/u);
  assert.throws(
    () => parseUiReviewArgs(["capture", "--pr", "1"]),
    /requires --side/u,
  );
});

test("UI review entries omit unchanged images and retain changed or one-sided images", () => {
  const root = mkdtempSync(join(tmpdir(), "kawacad-ui-review-"));
  try {
    const before = join(root, "before/screenshots");
    const after = join(root, "after/screenshots");
    mkdirSync(before, { recursive: true });
    mkdirSync(after, { recursive: true });
    writeFileSync(join(before, "paired.png"), "before");
    writeFileSync(join(after, "paired.png"), "after");
    writeFileSync(join(before, "unchanged.png"), "same");
    writeFileSync(join(after, "unchanged.png"), "same");
    writeFileSync(join(before, "removed.webp"), "before");
    writeFileSync(join(after, "added.jpg"), "after");

    assert.deepEqual(buildReviewEntries(root), [
      {
        name: "added.jpg",
        before: null,
        after: "after/screenshots/added.jpg",
        status: "added",
      },
      {
        name: "paired.png",
        before: "before/screenshots/paired.png",
        after: "after/screenshots/paired.png",
        status: "changed",
      },
      {
        name: "removed.webp",
        before: "before/screenshots/removed.webp",
        after: null,
        status: "removed",
      },
    ]);
    assert.deepEqual(buildReviewComparison(root).summary, {
      total: 4,
      changed: 1,
      added: 1,
      removed: 1,
      unchanged: 1,
    });
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("UI review HTML renders side-by-side and overlay comparisons", () => {
  const html = renderReviewHtml({
    pr: 42,
    before: { commit: "111111111111abcdef" },
    after: { commit: "222222222222abcdef" },
    entries: [
      {
        name: "toolbar.png",
        before: "before/screenshots/toolbar.png",
        after: "after/screenshots/toolbar.png",
        status: "changed",
      },
    ],
    summary: { total: 10, changed: 1, added: 0, removed: 0, unchanged: 9 },
  });
  assert.match(html, /UI Review — PR #42/u);
  assert.match(html, /Before: 111111111111/u);
  assert.match(html, /After: 222222222222/u);
  assert.match(html, /重ね合わせ/u);
  assert.match(html, /変更なし: 9件（除外）/u);
  assert.match(html, /before\/screenshots\/toolbar\.png/u);
});

test("UI review HTML explains when every screenshot is unchanged", () => {
  const html = renderReviewHtml({
    pr: 43,
    before: null,
    after: null,
    entries: [],
    summary: { total: 5, changed: 0, added: 0, removed: 0, unchanged: 5 },
  });
  assert.match(html, /差のある画像はありません/u);
  assert.match(html, /5件の一致画像を除外しました/u);
});
