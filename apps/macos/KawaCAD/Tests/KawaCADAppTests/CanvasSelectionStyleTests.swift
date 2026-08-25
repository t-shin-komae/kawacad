import Foundation
import Testing

@testable import KawaCADApp

private func canvasRenderingSource() throws -> String {
  let packageRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let sourceURL =
    packageRoot
    .appendingPathComponent(
      "Sources/KawaCADApp/Features/Canvas/Components/LeatherCanvasView.Rendering.swift")
  return try String(contentsOf: sourceURL, encoding: .utf8)
}

@Test("#164 Swiftの選択表示は破線境界を併用する")
func swift_selection_highlight_has_a_non_color_boundary_cue() throws {
  let source = try canvasRenderingSource()
  #expect(source.contains("func drawSelectionHighlight"))
  #expect(source.contains("path.setLineDash([5, 3], count: 2, phase: 0)"))
}
