import Foundation
import Testing

@Test("#179 SwiftのHelpメニューは3つのヘルプ項目へ到達できる")
func swift_help_menu_reaches_help_sections() throws {
  let packageRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let sourceURL = packageRoot.appendingPathComponent("Sources/KawaCADApp/App/KawaCADCommands.swift")
  let source = try String(contentsOf: sourceURL, encoding: .utf8)

  #expect(source.contains("CommandGroup(replacing: .help)"))
  #expect(source.contains("KawaCADHelpPanel.present(section: .overview)"))
  #expect(source.contains("KawaCADHelpPanel.present(section: .tools)"))
  #expect(source.contains("KawaCADHelpPanel.present(section: .canvas)"))
}

@Test("#179 Swiftのヘルプ画面は全ツールを検索できる")
func swift_help_panel_lists_all_tools_and_supports_search() throws {
  let packageRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let sourceURL = packageRoot.appendingPathComponent("Sources/KawaCADApp/App/KawaCADHelpPanel.swift")
  let source = try String(contentsOf: sourceURL, encoding: .utf8)

  #expect(source.contains("CanvasTool.allCases"))
  #expect(source.contains("TextField(AppStrings.tr(\"help.search\")"))
  #expect(source.contains("help.canvas.control_snap"))
  #expect(source.contains("help.canvas.option_duplicate"))
}
