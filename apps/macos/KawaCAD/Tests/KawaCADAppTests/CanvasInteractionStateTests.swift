import CoreGraphics
import Testing

@testable import KawaCADApp

struct CanvasInteractionStateTests {
  @Test
  func keyboard_command_cancels_existing_interaction_before_deleting() {
    let command = CanvasInteractionController.keyboardCommand(
      for: CanvasKeyboardInput(
        isEscape: true,
        isPlainTextSelectShortcut: false,
        isDelete: false,
        selectedTool: .line,
        hasCancellationTarget: true
      )
    )

    #expect(command == .cancelInteraction)
  }

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

  @Test
  func selection_reducer_owns_blank_click_transition_and_commands() {
    var controller = CanvasInteractionController()
    let result = controller.selectionResult(
      for: CanvasSelectionInput(
        point: CGPoint(x: 12, y: 18),
        modelPoint: .zero,
        clickCount: 1,
        togglesSelection: false,
        modifiers: CanvasPlacementModifiers(),
        selectedEntityIDs: [],
        measurementHit: nil,
        dimensionHit: nil,
        controlPointTarget: nil,
        constraintMarkerID: nil,
        stitchStartPointID: nil,
        freeTextID: nil,
        entityID: nil
      )
    )

    #expect(controller.snapshot.dragState != nil)
    #expect(result.commands.count == 4)
    #expect(result.inlineFreeTextID == nil)
  }

  @Test
  func mouse_down_reducer_consumes_selection_hit_input_without_view_routing() {
    var controller = CanvasInteractionController()
    let result = controller.mouseDownResult(
      for: CanvasMouseDownInput(
        isInsideCanvas: true,
        selectedTool: .select,
        isSettingPartOrigin: false,
        modifiers: CanvasPlacementModifiers(),
        placementPoint: .zero,
        linePoint: .zero,
        constraintTarget: nil,
        selectionInput: CanvasSelectionInput(
          point: CGPoint(x: 12, y: 18),
          modelPoint: .zero,
          clickCount: 1,
          togglesSelection: false,
          modifiers: CanvasPlacementModifiers(),
          selectedEntityIDs: [],
          measurementHit: nil,
          dimensionHit: nil,
          controlPointTarget: nil,
          constraintMarkerID: nil,
          stitchStartPointID: nil,
          freeTextID: nil,
          entityID: nil
        )
      )
    )

    #expect(result.command == nil)
    #expect(result.selectionCommands.count == 4)
    #expect(controller.snapshot.dragState != nil)
  }

  @Test
  func mouse_down_reducer_ignores_selection_input_outside_canvas_bounds() {
    var controller = CanvasInteractionController()
    let result = controller.mouseDownResult(
      for: CanvasMouseDownInput(
        isInsideCanvas: false,
        selectedTool: .select,
        isSettingPartOrigin: false,
        modifiers: CanvasPlacementModifiers(),
        placementPoint: .zero,
        linePoint: .zero,
        constraintTarget: nil,
        selectionInput: CanvasSelectionInput(
          point: CGPoint(x: 12, y: 18),
          modelPoint: .zero,
          clickCount: 1,
          togglesSelection: false,
          modifiers: CanvasPlacementModifiers(),
          selectedEntityIDs: ["entity:line-a"],
          measurementHit: nil,
          dimensionHit: nil,
          controlPointTarget: nil,
          constraintMarkerID: nil,
          stitchStartPointID: nil,
          freeTextID: nil,
          entityID: nil
        )
      )
    )

    #expect(result.command == nil)
    #expect(result.selectionCommands.isEmpty)
    #expect(controller.snapshot.dragState == nil)
  }
}
