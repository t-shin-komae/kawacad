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
