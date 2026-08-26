import Testing

@testable import KawaCADApp

struct CanvasOperationGuideTests {
  @Test("選択ツールの待機中はキャンバスガイドを表示しない")
  func select_tool_hides_idle_guide() {
    #expect(
      CanvasOperationGuideState.instruction(
        selectedTool: .select,
        viewMode: .editDisplay,
        topBannerVisible: false,
        isSettingPartOrigin: false,
        filletDraftEntityCount: 0,
        filletDraftClosed: false,
        draftPointCount: 0,
        hasArcStartPoint: false,
        pendingConstraintTargetCount: 0
      ) == nil
    )
  }

  @Test("作図ツールの待機中は現在のツールの操作案内を表示する")
  func drawing_tool_uses_idle_message() {
    #expect(
      CanvasOperationGuideState.instruction(
        selectedTool: .line,
        viewMode: .editDisplay,
        topBannerVisible: false,
        isSettingPartOrigin: false,
        filletDraftEntityCount: 0,
        filletDraftClosed: false,
        draftPointCount: 0,
        hasArcStartPoint: false,
        pendingConstraintTargetCount: 0
      ) == CanvasTool.line.idleMessage
    )
  }

  @Test("値入力を伴う出力プレビューではキャンバスガイドを表示しない")
  func output_preview_hides_guide() {
    #expect(
      CanvasOperationGuideState.instruction(
        selectedTool: .line,
        viewMode: .outputPreview,
        topBannerVisible: false,
        isSettingPartOrigin: false,
        filletDraftEntityCount: 0,
        filletDraftClosed: false,
        draftPointCount: 0,
        hasArcStartPoint: false,
        pendingConstraintTargetCount: 0
      ) == nil
    )
  }

  @Test("上部バナー表示中はキャンバスガイドを表示しない")
  func top_banner_hides_guide() {
    #expect(
      CanvasOperationGuideState.instruction(
        selectedTool: .line,
        viewMode: .editDisplay,
        topBannerVisible: true,
        isSettingPartOrigin: false,
        filletDraftEntityCount: 0,
        filletDraftClosed: false,
        draftPointCount: 0,
        hasArcStartPoint: false,
        pendingConstraintTargetCount: 0
      ) == nil
    )
  }
}
