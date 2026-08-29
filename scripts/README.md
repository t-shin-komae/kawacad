# Project automation

All local automation is exposed through the Node.js CLI. It uses only Node's standard library and invokes the existing Rust, Swift, npm, and Tauri tools directly.

Configure the repository hook once:

```bash
git config core.hooksPath .githooks
```

## Pre-commit

```bash
node scripts/kawacad.mjs pre-commit
node scripts/kawacad.mjs pre-commit --fix
```

The check runs Rust formatting and Clippy, Swift formatting checks on macOS, and Tauri formatting and TypeScript checks.

## Pre-push

```bash
node scripts/kawacad.mjs pre-push
```

The pre-push check requires macOS. It validates Swift formatting, builds the
real Core process, runs the regular and live-Core Swift tests, and builds and
stages the unsigned Swift release application. This is the Swift validation
boundary that GitHub Actions runs on its macOS runner. GitHub Actions also
runs the Tauri checks on Linux and Windows; Linux includes a virtual CUPS
direct-print E2E test.

## Tests

```bash
node scripts/kawacad.mjs test --scope core
node scripts/kawacad.mjs test --scope swift
node scripts/kawacad.mjs test --scope tauri
node scripts/kawacad.mjs test --scope tauri --e2e
node scripts/kawacad.mjs test --scope all
```

`--live-core` enables the Swift tests that start a real `kawacad-core-process`. Swift commands require macOS. The `all` scope skips Swift on other operating systems and reports the skip.

## Comparison screenshots

On macOS, regenerate the matching Tauri and Swift screenshot scenarios with:

```bash
node scripts/capture-comparison-screenshots.mjs
```

Generated images are written below `test-results/comparison-screenshots/`, which
is ignored by Git. Swift and Tauri instantiate each corresponding toolbar,
palette, canvas, inspector, summary, or dialog fixture directly in a fixed
component-sized frame; they do not lay out the whole workspace and crop it.
The fixture IDs are shared between both frontends and appear in the output file
names. The capture does not bring an app to the foreground, use Screen Capture
APIs, or require Screen & System Audio Recording permission. Standard controls
can therefore use inactive colors; this fixture does not verify active-window
appearance. The context-menu image uses an in-process visual fixture because a
native `NSMenu` is a separate WindowServer window.

The matrix covers light and dark themes for the toolbar, palette, canvas,
inspector, bottom summary, constraint HUD, context menu, paste overlay, and
dialogs. Fixture data is fixed and isolated, so generated output does not
depend on test order or elapsed time.

## Local UI review

After opening a Draft Pull Request, capture its base and head states into an
isolated local directory:

```bash
node scripts/ui-review.mjs capture --pr 123 --side before --source-root /path/to/base-worktree
node scripts/ui-review.mjs capture --pr 123 --side after
```

Use `--variant tauri` or `--variant swift` when only one frontend changed. The
source worktree must already have the dependencies required by that frontend.
The current worktree remains checked out while the base revision is rendered
from `--source-root`. Before each capture, existing screenshots for the selected
side and variant are removed so deleted or renamed scenarios do not remain as
stale files.

Both captures and their commit metadata are stored under
`test-results/ui-reviews/pr-123/`. The second capture also regenerates
`index.html`. Screenshots with identical file names and bytes are omitted from
the report. Changed, added, and removed screenshots remain available with
side-by-side images, an overlay slider, and a file name filter. The report also
shows how many unchanged images were omitted. The default output root is derived
from Git's common directory, so linked worktrees share the same PR-numbered
reports. The whole directory is ignored by Git and remains available to local
Codex sessions without requiring a GitHub image upload. Use `--review-root` only
when a different shared location is needed.

For a component not covered by the fixed scenarios, place matching image names
under `before/screenshots/` and `after/screenshots/`, then regenerate only the
report:

```bash
node scripts/ui-review.mjs report --pr 123
```

## Coverage

Coverage reports are written under `coverage/`, never as report artifacts under `target/`:

```bash
node scripts/kawacad.mjs coverage --scope core
node scripts/kawacad.mjs coverage --scope swift
node scripts/kawacad.mjs coverage --scope tauri
node scripts/kawacad.mjs coverage --scope all
```

The Rust report contains LCOV and HTML, Swift contains the SwiftPM coverage JSON, and Tauri contains LCOV and the V8 HTML report. No cross-tool summary or CI-specific report is generated.

Rust coverage requires `cargo-llvm-cov`. Swift coverage requires SwiftPM on macOS. Tauri coverage requires dependencies installed with:

```bash
npm ci --prefix apps/tauri/KawaCAD
```

## Release

### OSS license notices

Generate notices from the locked runtime dependency graphs before packaging:

```bash
npm --prefix apps/tauri/KawaCAD run licenses:generate
```

The Tauri build runs this step automatically and places the generated JSON in
the frontend bundle. Tauri output contains Tauri Rust plus Node production
dependencies. The Swift panel prefers the generated Markdown resource, which
contains only the Rust dependencies reachable from the bundled Core process
and Swift executable-target packages; test-only SwiftPM packages are excluded.
The checked-in resource is only a development fallback. Review any entry whose
package does not ship a license file before releasing.

macOS can produce both application variants:

```bash
node scripts/kawacad.mjs release --platform macos --variant swift
node scripts/kawacad.mjs release --platform macos --variant tauri
node scripts/kawacad.mjs release --platform macos --variant all
```

The artifacts are `dist/macos/swift/KawaCAD.app` and `dist/macos/tauri/KawaCAD.app`.

Windows and Linux release commands must run natively on their respective operating systems:

```bash
node scripts/kawacad.mjs release --platform windows
node scripts/kawacad.mjs release --platform linux
```

They produce `dist/windows/KawaCAD.exe` and `dist/linux/KawaCAD`. Installer packages, signing, notarization, DMG, MSI, deb, and AppImage generation are intentionally outside this layer.

Use `--dry-run` with any command to inspect the commands without invoking build tools.
