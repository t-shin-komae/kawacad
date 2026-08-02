import CoreGraphics
import Testing

@testable import KawaCADApp

struct CanvasInteractionStateTests {
  @Test
  func cancellation_target_is_true_while_dragging() {
    let interaction = CanvasInteractionState(
      dragState: .entities(
        entityIDs: ["entity:line-a"],
        anchorEntityID: "entity:line-a",
        startPoint: .zero,
        currentPoint: .zero,
        duplicating: false
      )
    )

    #expect(
      interaction.hasCancellationTarget(
        draftStartPoint: nil,
        draftCurrentPoint: nil,
        draftArcStartPoint: nil,
        pendingConstraintTargets: [],
        selectedEntityID: nil,
        selectedEntityIDs: [],
        selectedConstraintID: nil
      )
    )
  }

  @Test
  func normalized_rect_is_independent_of_drag_direction() {
    let rect = CanvasInteractionState.normalizedRect(
      from: CGPoint(x: 30, y: 10),
      to: CGPoint(x: 5, y: 40)
    )

    #expect(rect == CGRect(x: 5, y: 10, width: 25, height: 30))
  }

  @Test
  func meaningful_model_movement_uses_same_tolerance_as_canvas_drag() {
    #expect(
      CanvasInteractionState.hasMeaningfulModelMovement(
        from: .zero,
        to: ModelPoint(xMM: 0.00005, yMM: 0.0)
      ) == false
    )
    #expect(
      CanvasInteractionState.hasMeaningfulModelMovement(
        from: .zero,
        to: ModelPoint(xMM: 0.001, yMM: 0.0)
      )
    )
  }
}
