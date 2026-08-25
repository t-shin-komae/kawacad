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
  let selectionStart = try #require(source.range(of: "func drawSelectionHighlight"))
  let selectionEnd = try #require(
    source.range(
      of: "\n  func drawFilletDraftHighlight",
      range: selectionStart.upperBound..<source.endIndex
    )
  )
  let selectionFunction = source[selectionStart.lowerBound..<selectionEnd.lowerBound]
  #expect(selectionFunction.contains("path.setLineDash([5, 3], count: 2, phase: 0)"))
}
