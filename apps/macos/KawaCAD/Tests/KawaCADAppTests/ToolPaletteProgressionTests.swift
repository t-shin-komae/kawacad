import Foundation
import Testing

@testable import KawaCADApp

@Test("基本/詳細ツール分類は全 CanvasTool を一意にカバーする")
func tool_palette_classification_covers_every_canvas_tool_once() {
  let basicTools = Set(CanvasTool.allCases.filter(\.isBasicTool))
  let detailedTools = Set(CanvasTool.allCases.filter(\.isDetailedTool))

  #expect(basicTools.count == 15)
  #expect(detailedTools.count == 22)
  #expect(basicTools.intersection(detailedTools).isEmpty)
  #expect(basicTools.union(detailedTools) == Set(CanvasTool.allCases))
}
