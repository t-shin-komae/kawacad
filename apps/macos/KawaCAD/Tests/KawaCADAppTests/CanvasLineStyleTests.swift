import AppKit
import Testing

@testable import KawaCADApp

@Test("UC3 中心線は通常線分と異なる補助線スタイルで描画される")
func center_line_style_is_visually_distinct_from_regular_line() {
  let regular = lineEntity(
    id: "entity:line",
    start: .zero,
    end: ModelPoint(xMM: 10.0, yMM: 0.0)
  )
  let center = centerLineEntity(
    id: "entity:center",
    start: .zero,
    end: ModelPoint(xMM: 10.0, yMM: 0.0)
  )
  let base = CanvasLineStyle(
    color: NSColor(calibratedRed: 0.1, green: 0.2, blue: 0.3, alpha: 1.0),
    lineWidth: 2.0,
    pattern: .solid
  )

  let regularStyle = base.distinguished(for: regular)
  let centerStyle = base.distinguished(for: center)

  #expect(regularStyle.pattern == .solid)
  #expect(regularStyle.dashPattern == nil)
  #expect(centerStyle.pattern == .construction)
  #expect(centerStyle.dashPattern?.count == 4)
  #expect(centerStyle.color != regularStyle.color)
  #expect(center.kind.displayName == "中心線")
}
