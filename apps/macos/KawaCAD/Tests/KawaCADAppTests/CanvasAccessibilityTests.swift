import AppKit
import Testing

@testable import KawaCADApp

struct CanvasAccessibilityTests {
  @Test
  @MainActor
  func canvas_exposes_stable_identifier_and_high_level_state() {
    let view = LeatherCanvasView(frame: NSRect(x: 0, y: 0, width: 320, height: 240))
    view.selectedTool = .line
    view.entities = [
      lineEntity(
        id: "entity:line-a",
        label: "Line A",
        start: .zero,
        end: ModelPoint(xMM: 20, yMM: 0)
      )
    ]
    view.selectedEntityIDs = ["entity:line-a"]
    view.pendingConstraintTargets = [
      CanvasSelectionTarget(
        entityID: "entity:line-a",
        entityLabel: "Line A",
        entityKind: .lineSegment,
        controlPoint: nil,
        point: nil
      )
    ]

    view.refreshAccessibilityState()

    #expect(view.accessibilityIdentifier() == AccessibilityIdentifier.workspaceCanvas)
    #expect(view.accessibilityLabel() == AppStrings.tr("accessibility.canvas"))
    #expect(
      view.accessibilityValue() as? String
        == AppStrings.tr(
          "accessibility.canvas.value",
          CanvasTool.line.displayName,
          CanvasViewMode.editDisplay.displayName,
          1,
          1,
          1,
          AppStrings.tr("accessibility.canvas.interaction.constraint_target")
        )
    )
  }

  @Test
  @MainActor
  func canvas_reports_drawing_progress_without_exposing_mutation() throws {
    let view = LeatherCanvasView(frame: NSRect(x: 0, y: 0, width: 320, height: 240))
    view.draftStartPoint = .zero
    view.draftArcStartPoint = ModelPoint(xMM: 10, yMM: 0)

    view.refreshAccessibilityState()

    let value = try #require(view.accessibilityValue() as? String)
    #expect(value.contains(AppStrings.tr("accessibility.canvas.interaction.arc_end")))
  }

  @Test
  @MainActor
  func canvas_reports_fillet_draft_reference_and_corner_counts() throws {
    let view = LeatherCanvasView(frame: NSRect(x: 0, y: 0, width: 320, height: 240))
    view.filletDraftEntityIDs = ["entity:a", "entity:b", "entity:c"]
    view.filletDraftClosed = false

    view.refreshAccessibilityState()

    let value = try #require(view.accessibilityValue() as? String)
    #expect(
      value.contains(
        AppStrings.tr(
          "accessibility.canvas.interaction.fillet_draft", 3, 2, AppStrings.tr("fillet.draft.open"))
      ))
  }
}
