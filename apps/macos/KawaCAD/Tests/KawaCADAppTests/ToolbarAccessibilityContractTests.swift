import Foundation
import Testing

@testable import KawaCADApp

private func cadToolbarSource() throws -> String {
  let packageRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

  let sourceURL =
    packageRoot
    .appendingPathComponent("Sources/KawaCADApp/Features/Canvas/Components/CADToolbar.swift")
  return try String(contentsOf: sourceURL, encoding: .utf8)
}

@Test("#168 Swiftツールバーのアイコン操作はVoiceOver名を持つ")
func swift_toolbar_icon_actions_have_accessibility_labels() throws {
  let source = try cadToolbarSource()

  for key in [
    "toolbar.zoom_to_fit",
    "toolbar.zoom_out",
    "toolbar.zoom_in",
    "toolbar.more_actions",
  ] {
    #expect(
      source.contains("accessibilityLabel(AppStrings.tr(\"\(key)\"))"),
      "Missing label for \(key)"
    )
  }
}
