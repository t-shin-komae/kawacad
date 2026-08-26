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

@Test("#168 Swiftのオン状態と拘束状態は色以外の手掛かりを持つ")
func swift_accessibility_state_cues_are_visible() throws {
  let toolbarSource = try cadToolbarSource()
  let designSystemURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("Sources/KawaCADApp/Shared/Components/DesignSystem.swift")
  let designSystem = try String(contentsOf: designSystemURL, encoding: .utf8)

  #expect(toolbarSource.contains("ToolbarStateMark"))
  #expect(toolbarSource.contains("checkmark"))
  #expect(designSystem.contains("checkmark.circle.fill"))
  #expect(designSystem.contains("exclamationmark.triangle.fill"))
  #expect(designSystem.contains("exclamationmark.octagon.fill"))
}
