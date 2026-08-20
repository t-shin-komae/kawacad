import Testing

@testable import KawaCADApp

@Test("#130 パーツ既定名とライブラリ自動配置をSwift/Tauri共通条件で計算する")
func part_defaults_match_cross_platform_rules() {
  #expect(PartDefaults.name(number: 3) == "パーツ 3")
  #expect(
    PartDefaults.libraryPlacement(
      cursorPoint: nil,
      existingOrigins: [
        ModelPoint(xMM: -10, yMM: 2),
        ModelPoint(xMM: 20, yMM: 8),
      ]) == ModelPoint(xMM: 50, yMM: 8))
}

@Test("#130 明示したカーソル位置をライブラリ配置で優先する")
func part_library_placement_prefers_cursor() {
  #expect(
    PartDefaults.libraryPlacement(
      cursorPoint: ModelPoint(xMM: 12, yMM: -4),
      existingOrigins: [ModelPoint(xMM: 20, yMM: 8)]
    ) == ModelPoint(xMM: 12, yMM: -4))
}

@Test("#130 負側だけにある既存パーツの自動配置を原点側へ下限補正する")
func part_library_placement_clamps_negative_origins() {
  #expect(
    PartDefaults.libraryPlacement(
      cursorPoint: nil,
      existingOrigins: [
        ModelPoint(xMM: -80, yMM: -8),
        ModelPoint(xMM: -50, yMM: -2),
      ]) == ModelPoint(xMM: 0, yMM: 0))
}
