import AppKit
import Testing

@testable import KawaCADApp

struct CanvasEmptyStateTests {
  @Test
  func empty_state_guide_is_anchored_to_the_visible_canvas_bounds() {
    let visibleBounds = CGRect(x: 40, y: 12, width: 320, height: 240)
    let guideCenter = LeatherCanvasView.emptyStateGuideCenter(in: visibleBounds)

    #expect(guideCenter.x == visibleBounds.midX)
    #expect(abs(guideCenter.y - (visibleBounds.minY + visibleBounds.height * 0.24)) < 0.0001)

    let compactBounds = CGRect(x: 0, y: 0, width: 220, height: 80)
    let compactGuideCenter = LeatherCanvasView.emptyStateGuideCenter(in: compactBounds)
    #expect(compactGuideCenter.x == compactBounds.midX)
    #expect(compactGuideCenter.y >= compactBounds.minY)
    #expect(compactGuideCenter.y <= compactBounds.maxY)
  }

  @Test
  @MainActor
  func empty_state_uses_shared_copy_and_only_appears_on_an_empty_edit_canvas() {
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: NSRect(x: 0, y: 0, width: 320, height: 240))

    #expect(AppStrings.tr("canvas.empty.title") == "作図を始めましょう")
    #expect(
      AppStrings.tr("canvas.empty.body") == "ツールを選択してキャンバスをクリックしてください。")
    #expect(view.shouldDrawEmptyState)

    inputs.freeTexts = [
      ProjectFreeText(
        id: "free-text:note",
        content: "メモ",
        positionMM: .zero,
        fontSizeMM: 4
      )
    ]
    #expect(!view.shouldDrawEmptyState)

    inputs.freeTexts = []
    inputs.entities = [pointEntity(id: "entity:point", point: .zero)]
    #expect(!view.shouldDrawEmptyState)

    inputs.entities = []
    inputs.viewMode = .outputPreview
    #expect(!view.shouldDrawEmptyState)
  }
}
