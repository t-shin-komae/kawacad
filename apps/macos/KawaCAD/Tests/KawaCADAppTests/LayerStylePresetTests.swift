import Testing

@testable import KawaCADApp

@Test("レイヤー線色プリセットは代表色とカスタム色判定を持つ")
func layer_color_presets_include_representative_colors_and_custom_fallback() {
  #expect(LayerColorPreset.all.map(\.displayName) == ["黒", "グレー", "赤", "青", "緑", "オレンジ", "紫"])
  #expect(LayerColorPreset.all.allSatisfy { $0.colorHex.hasPrefix("#") && $0.colorHex.count == 7 })
  #expect(LayerColorPreset.matching("#2563EB")?.displayName == "青")
  #expect(LayerColorPreset.matching("#123456") == nil)
}

@Test("レイヤー線幅プリセットは製図向けの代表値とカスタム線幅判定を持つ")
func layer_stroke_width_presets_include_drafting_widths_and_custom_fallback() {
  #expect(LayerStrokeWidthPreset.all.map(\.widthMM) == [0.13, 0.18, 0.25, 0.35, 0.50, 0.70])
  #expect(LayerStrokeWidthPreset.matching(0.35)?.displayName == "0.35 mm")
  #expect(LayerStrokeWidthPreset.matching(0.45) == nil)
}
