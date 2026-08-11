import AppKit
import Testing

@testable import KawaCADApp

struct CanvasEmptyStateTests {
  @Test
  @MainActor
  func empty_state_uses_shared_copy_and_only_appears_on_an_empty_edit_canvas() {
    let view = LeatherCanvasView(frame: NSRect(x: 0, y: 0, width: 320, height: 240))

    #expect(AppStrings.tr("canvas.empty.title") == "作図を始めましょう")
    #expect(
      AppStrings.tr("canvas.empty.body") == "ツールを選択してキャンバスをクリックしてください。")
    #expect(view.shouldDrawEmptyState)

    view.freeTexts = [
      ProjectFreeText(
        id: "free-text:note",
        content: "メモ",
        positionMM: .zero,
        fontSizeMM: 4
      )
    ]
    #expect(!view.shouldDrawEmptyState)

    view.freeTexts = []
    view.entities = [pointEntity(id: "entity:point", point: .zero)]
    #expect(!view.shouldDrawEmptyState)

    view.entities = []
    view.viewMode = .outputPreview
    #expect(!view.shouldDrawEmptyState)
  }
}
