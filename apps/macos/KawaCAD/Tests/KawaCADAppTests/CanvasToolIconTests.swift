import Testing

@testable import KawaCADApp

@Test("ツールパレットの各ツールは表示用アイコンを持つ")
func canvas_tool_icons_have_display_fallbacks() {
  for tool in CanvasTool.allCases {
    #expect(!tool.symbolName.isEmpty, "\(tool.rawValue) should have a fallback SF Symbol")
    #expect(!tool.iconIdentity.isEmpty, "\(tool.rawValue) should have a display icon identity")
  }
}

@Test("ツールパレットの主要アイコンはグループ内で意味が衝突しない")
func canvas_tool_icons_do_not_collide_within_palette_groups() {
  let groups: [[CanvasTool]] = [
    [
      .select, .point, .line, .circle, .arc, .centerLine, .horizontalCenterLine,
      .verticalCenterLine, .offset, .fillet,
    ],
    [
      .coincident, .horizontal, .vertical, .parallel, .perpendicular, .tangent, .equalLength,
      .angle, .symmetric, .fixed,
    ],
    [.distance, .segmentLength, .diameter, .radius],
  ]

  for group in groups {
    let identities = group.map(\.iconIdentity)
    #expect(Set(identities).count == identities.count)
  }
}

@Test("ツールパレットは接線拘束を表示する")
func project_sidebar_palette_includes_tangent_constraint_tool() {
  let paletteTools = ProjectSidebar.toolGroups.flatMap(\.tools)

  #expect(paletteTools.contains(.tangent))
}

@Test("ツールパレットは全ツールをカテゴリ切替なしで表示対象にする")
func project_sidebar_palette_includes_all_canvas_tools() {
  let paletteTools = ProjectSidebar.toolGroups.flatMap(\.tools)

  #expect(Set(paletteTools) == Set(CanvasTool.allCases))
  #expect(paletteTools.count == CanvasTool.allCases.count)
}

@Test("戻した拘束ツールはPR前のSF Symbolを使う")
func restored_constraint_tool_icons_use_previous_symbols() {
  #expect(CanvasTool.horizontal.symbolName == "arrow.left.and.right")
  #expect(CanvasTool.vertical.symbolName == "arrow.up.and.down")
  #expect(CanvasTool.parallel.symbolName == "equal")
  #expect(CanvasTool.equalLength.symbolName == "ruler")
}

@Test("拘束、寸法ツールは個別のCAD記号を使う")
func canvas_tool_icons_distinguish_cad_specific_tools() {
  #expect(CanvasTool.symmetric.iconIdentity != CanvasTool.horizontal.iconIdentity)
  #expect(CanvasTool.equalLength.iconIdentity != CanvasTool.segmentLength.iconIdentity)
  #expect(CanvasTool.segmentLength.iconIdentity != CanvasTool.radius.iconIdentity)
  #expect(CanvasTool.perpendicular.iconIdentity != CanvasTool.angle.iconIdentity)
}
