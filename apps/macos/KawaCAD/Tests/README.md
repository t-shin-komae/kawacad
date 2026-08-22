# Tests

This package keeps Swift-side boundary and state-transition tests under
`KawaCADAppTests`.

The suite uses Swift Testing and is intended to be executed with `swift test`
from `apps/macos/KawaCAD/`.

`UsabilityInspectionUITests.swift` is the UI regression suite for every
charter in the usability inspections: UP-01 through UP-07 and UXE-01 through
UXE-12. It covers items that passed the inspection as well as the remediated
findings, using the same menu, toolbar, canvas, and sheet bindings as the app.

## Test groups

The regular Swift suite uses test doubles at the UI/Core boundary. The package
manifest excludes `LiveCoreConstraintIntegrationTests.swift`, so the regular
suite neither compiles those tests nor starts the Rust Core process:

```bash
swift test
```

Tests in `LiveCoreConstraintIntegrationTests.swift` start the real Rust Core
process. Enable and run them separately after building
`kawacad-core-process`:

```bash
cargo build -p kawacad-core-process
KAWACAD_CORE_PROCESS="$PWD/target/debug/kawacad-core-process" \
  LEATHER_ENABLE_LIVE_CORE_TESTS=1 \
  swift test --package-path apps/macos/KawaCAD --filter 'live_core_'
```

## Comparison screenshots

`ComparisonScreenshotTests.swift` renders the SwiftUI/AppKit states paired with the
Tauri visual verification. Run both variants and generate side-by-side images
from the repository root:

```bash
node scripts/capture-comparison-screenshots.mjs
```

The Swift test draws its `NSHostingView` directly into a bitmap instead of
capturing WindowServer pixels. It does not require app activation or Screen &
System Audio Recording permission. Because the test process is not activated,
standard controls can use their inactive colors; this fixture does not verify
active-window appearance. The context-menu image is an in-process visual fixture;
menu actions and item construction remain covered by non-visual tests.

Regular `swift test` does not update generated images because the output
environment variable is absent. The repository command sets it only for this
screenshot case.
