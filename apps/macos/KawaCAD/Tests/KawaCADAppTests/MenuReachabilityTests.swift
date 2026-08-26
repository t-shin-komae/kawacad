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

@Test("#159 Swiftメニューからツールパレットの表示状態を変更できる")
func swift_menu_reaches_tool_palette_visibility_action() throws {
  let source = try kawaCADCommandsSource()
  #expect(source.contains("workspaceLayout.toolPaletteVisible"))
  #expect(source.contains("workspaceLayout.setToolPaletteVisible"))
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

@Test("#8 Swiftメニューは中心線ツールを一本だけ公開する")
func swift_menu_exposes_only_the_general_center_line_tool() throws {
  let source = try kawaCADCommandsSource()

  #expect(source.contains("activateTool(.centerLine)"))
  #expect(!source.contains("activateTool(.horizontalCenterLine)"))
  #expect(!source.contains("activateTool(.verticalCenterLine)"))
}
