import Foundation
import Testing

@testable import KawaCADApp

private func kawaCADCommandsSource() throws -> String {
  let packageRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let sourceURL =
    packageRoot
    .appendingPathComponent("Sources/KawaCADApp/App/KawaCADCommands.swift")
  return try String(contentsOf: sourceURL, encoding: .utf8)
}

@Test("#26 Swiftメニューにツールパレット表示項目を追加しない")
func swift_menu_omits_tool_palette_visibility_action() throws {
  let source = try kawaCADCommandsSource()
  #expect(!source.contains("showCompactDrawer(.tools)"))
  #expect(!source.contains("setToolPalettePanelVisible"))
}

@Test("#65 Swiftメニューから不足していた作図・拘束・計測ツールへ到達できる")
func swift_menu_reaches_all_previously_missing_tools() throws {
  let source = try kawaCADCommandsSource()
  let requiredToolCases = [
    "freeText",
    "offset",
    "fillet",
    "pointOnLine",
    "horizontalDistance",
    "verticalDistance",
    "lineLineDistance",
    "measureDistance",
  ]
  for toolCase in requiredToolCases {
    #expect(source.contains("activateTool(.\(toolCase))"), "Missing menu route for \(toolCase)")
  }
}
