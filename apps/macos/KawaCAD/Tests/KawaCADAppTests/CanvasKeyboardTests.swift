import AppKit
import Testing

@testable import KawaCADApp

struct CanvasKeyboardTests {
  @Test
  @MainActor
  func part_origin_mode_routes_the_next_canvas_click_to_part_origin() {
    let frame = NSRect(x: 0, y: 0, width: 520, height: 736)
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: frame)
    inputs.isSettingPartOrigin = true
    inputs.selectedTool = .line
    inputs.gridSnapEnabled = false
    inputs.pointSnapEnabled = false
    var origin: ModelPoint?
    var placementCount = 0
    inputs.onSetPartOrigin = { origin = $0 }
    inputs.onPlacePoint = { _, _ in placementCount += 1 }

    view.mouseDown(with: unwrap(mouseDownEvent(at: CGPoint(x: frame.midX, y: frame.midY))))

    #expect(abs(unwrap(origin).xMM) < 0.0001)
    #expect(abs(unwrap(origin).yMM) < 0.0001)
    #expect(placementCount == 0)
  }

  @Test
  @MainActor
  func escape_key_invokes_canvas_cancel_interaction_callback() {
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: NSRect(x: 0, y: 0, width: 320, height: 240))
    var cancelCount = 0
    inputs.onCancelInteraction = {
      cancelCount += 1
    }
    let event = NSEvent.keyEvent(
      with: .keyDown,
      location: .zero,
      modifierFlags: [],
      timestamp: 0,
      windowNumber: 0,
      context: nil,
      characters: "\u{1B}",
      charactersIgnoringModifiers: "\u{1B}",
      isARepeat: false,
      keyCode: 53
    )

    view.keyDown(with: unwrap(event))

    #expect(cancelCount == 1)
  }

  @Test
  @MainActor
  func v_key_activates_select_tool_from_canvas() {
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: NSRect(x: 0, y: 0, width: 320, height: 240))
    inputs.selectedTool = .line
    var activatedTools: [CanvasTool] = []
    inputs.onActivateTool = { tool in
      activatedTools.append(tool)
    }

    view.keyDown(with: unwrap(plainKeyEvent("v")))

    #expect(activatedTools == [.select])
  }

  @Test
  @MainActor
  func modified_v_key_does_not_activate_select_tool_from_canvas() {
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: NSRect(x: 0, y: 0, width: 320, height: 240))
    inputs.selectedTool = .line
    var activatedTools: [CanvasTool] = []
    inputs.onActivateTool = { tool in
      activatedTools.append(tool)
    }

    view.keyDown(with: unwrap(plainKeyEvent("v", modifierFlags: [.command])))

    #expect(activatedTools.isEmpty)
  }

  @Test
  @MainActor
  func escape_key_activates_select_tool_when_no_canvas_interaction_is_active() {
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: NSRect(x: 0, y: 0, width: 320, height: 240))
    inputs.selectedTool = .line
    var cancelCount = 0
    var activatedTools: [CanvasTool] = []
    inputs.onCancelInteraction = {
      cancelCount += 1
    }
    inputs.onActivateTool = { tool in
      activatedTools.append(tool)
    }

    view.keyDown(with: unwrap(escapeKeyEvent()))

    #expect(cancelCount == 0)
    #expect(activatedTools == [.select])
  }

  @Test
  @MainActor
  func escape_key_during_drag_prevents_mouse_up_from_committing_move() {
    let pageRect = CGRect(x: 0, y: 0, width: 520, height: 736)
    let coordinateSpace = CanvasCoordinateSpace(pageRect: pageRect)
    let startPoint = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 10, yMM: 0))
    let draggedPoint = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 25, yMM: 10))
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: pageRect)
    inputs.entities = [
      lineEntity(
        id: "entity:line-a",
        label: "Line A",
        start: .zero,
        end: ModelPoint(xMM: 20, yMM: 0)
      )
    ]
    inputs.layers = defaultLayers()
    inputs.selectedTool = .select
    var cancelCount = 0
    var previewMoveCount = 0
    var committedMoveCount = 0
    inputs.onCancelInteraction = {
      cancelCount += 1
    }
    inputs.onPreviewMoveEntity = { _, _ in
      previewMoveCount += 1
    }
    inputs.onMoveEntity = { _, _ in
      committedMoveCount += 1
    }

    view.beginSelectInteraction(at: startPoint, in: pageRect)
    view.dragSelectInteraction(to: draggedPoint, in: pageRect)
    view.keyDown(with: unwrap(escapeKeyEvent()))
    view.endSelectInteraction(at: draggedPoint, in: pageRect)

    #expect(previewMoveCount == 1)
    #expect(cancelCount == 1)
    #expect(committedMoveCount == 0)
  }

  @Test
  @MainActor
  func select_drag_moves_point_entity_as_entity_not_control_point_issue_296() {
    let pageRect = CGRect(x: 0, y: 0, width: 520, height: 736)
    let coordinateSpace = CanvasCoordinateSpace(pageRect: pageRect)
    let startPoint = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 4, yMM: 6))
    let draggedPoint = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 4, yMM: 10))
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: pageRect)
    inputs.entities = [
      lineEntity(
        id: "entity:line-a",
        label: "Line A",
        start: .zero,
        end: ModelPoint(xMM: 20, yMM: 0)
      ),
      pointEntity(
        id: "entity:point-a",
        label: "Point A",
        point: ModelPoint(xMM: 4, yMM: 6)
      ),
    ]
    inputs.layers = defaultLayers()
    inputs.selectedTool = .select
    inputs.selectedEntityIDs = ["entity:point-a"]
    inputs.gridSnapEnabled = false
    inputs.pointSnapEnabled = false
    var movedEntityID: String?
    var movedDelta: ModelPoint?
    var movedControlPoint: CanvasSelectionTarget?
    inputs.onMoveEntity = { entityID, delta in
      movedEntityID = entityID
      movedDelta = delta
    }
    inputs.onMoveControlPoint = { target, _ in
      movedControlPoint = target
    }

    view.beginSelectInteraction(at: startPoint, in: pageRect)
    view.dragSelectInteraction(to: draggedPoint, in: pageRect)
    view.endSelectInteraction(at: draggedPoint, in: pageRect)

    #expect(movedEntityID == "entity:point-a")
    #expect(abs(unwrap(movedDelta).xMM) < 0.0001)
    #expect(abs(unwrap(movedDelta).yMM - 4) < 0.0001)
    #expect(movedControlPoint == nil)
  }

  @Test
  @MainActor
  func select_drag_keeps_selected_point_entity_when_overlapping_later_line_issue_296() {
    let pageRect = CGRect(x: 0, y: 0, width: 520, height: 736)
    let coordinateSpace = CanvasCoordinateSpace(pageRect: pageRect)
    let startPoint = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 4, yMM: 6))
    let draggedPoint = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 4, yMM: 10))
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: pageRect)
    inputs.entities = [
      pointEntity(
        id: "entity:point-a",
        label: "Point A",
        point: ModelPoint(xMM: 4, yMM: 6)
      ),
      lineEntity(
        id: "entity:line-a",
        label: "Line A",
        start: ModelPoint(xMM: 0, yMM: 6),
        end: ModelPoint(xMM: 20, yMM: 6)
      ),
    ]
    inputs.layers = defaultLayers()
    inputs.selectedTool = .select
    inputs.selectedEntityIDs = ["entity:point-a"]
    inputs.gridSnapEnabled = false
    inputs.pointSnapEnabled = false
    var movedEntityID: String?
    var movedControlPoint: CanvasSelectionTarget?
    inputs.onMoveEntity = { entityID, _ in
      movedEntityID = entityID
    }
    inputs.onMoveControlPoint = { target, _ in
      movedControlPoint = target
    }

    view.beginSelectInteraction(at: startPoint, in: pageRect)
    view.dragSelectInteraction(to: draggedPoint, in: pageRect)
    view.endSelectInteraction(at: draggedPoint, in: pageRect)

    #expect(movedEntityID == "entity:point-a")
    #expect(movedControlPoint == nil)
  }

  @Test
  @MainActor
  func output_preview_ignores_selection_drag_interactions() {
    let pageRect = CGRect(x: 0, y: 0, width: 520, height: 736)
    let coordinateSpace = CanvasCoordinateSpace(pageRect: pageRect)
    let startPoint = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 10, yMM: 0))
    let draggedPoint = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 25, yMM: 10))
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: pageRect)
    inputs.entities = [
      lineEntity(
        id: "entity:line-a",
        label: "Line A",
        start: .zero,
        end: ModelPoint(xMM: 20, yMM: 0)
      )
    ]
    inputs.layers = defaultLayers()
    inputs.selectedTool = .select
    inputs.viewMode = .outputPreview
    var selectedEntityIDs: [String?] = []
    var previewMoveCount = 0
    var committedMoveCount = 0
    inputs.onSelectEntity = { selectedEntityIDs.append($0) }
    inputs.onPreviewMoveEntity = { _, _ in previewMoveCount += 1 }
    inputs.onMoveEntity = { _, _ in committedMoveCount += 1 }

    view.beginSelectInteraction(at: startPoint, in: pageRect)
    view.dragSelectInteraction(to: draggedPoint, in: pageRect)
    view.endSelectInteraction(at: draggedPoint, in: pageRect)

    #expect(selectedEntityIDs.isEmpty)
    #expect(previewMoveCount == 0)
    #expect(committedMoveCount == 0)
  }

  @Test
  @MainActor
  func option_drag_duplication_is_decided_by_drop_modifiers() {
    let pageRect = CGRect(x: 0, y: 0, width: 520, height: 736)
    let coordinateSpace = CanvasCoordinateSpace(pageRect: pageRect)
    let startPoint = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 10, yMM: 0))
    let draggedPoint = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 25, yMM: 10))
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: pageRect)
    inputs.entities = [
      lineEntity(
        id: "entity:line-a",
        label: "Line A",
        start: .zero,
        end: ModelPoint(xMM: 20, yMM: 0)
      )
    ]
    inputs.layers = defaultLayers()
    inputs.selectedTool = .select
    var committedDuplicating: Bool?
    inputs.onMoveEntities = { _, _, duplicating in
      committedDuplicating = duplicating
    }

    view.beginSelectInteraction(at: startPoint, in: pageRect)
    view.dragSelectInteraction(
      to: draggedPoint, in: pageRect, modifiers: CanvasPlacementModifiers(duplicatesOnDrag: false))
    view.endSelectInteraction(
      at: draggedPoint,
      in: pageRect,
      modifiers: CanvasPlacementModifiers(duplicatesOnDrag: true)
    )

    #expect(committedDuplicating == true)
  }

  @Test
  @MainActor
  func select_drag_prefers_fillet_source_line_over_overlapping_derived_line() {
    let pageRect = CGRect(x: 0, y: 0, width: 520, height: 736)
    let coordinateSpace = CanvasCoordinateSpace(pageRect: pageRect)
    let startPoint = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 5, yMM: 0))
    let draggedPoint = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 10, yMM: 5))
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: pageRect)
    let sourceLine = lineEntity(
      id: "entity:line-a",
      label: "Source Line",
      start: .zero,
      end: ModelPoint(xMM: 20, yMM: 0)
    ).withFilletSuppressedStyle()
    let derivedLine = lineEntity(
      id: "derived:fillet-a:resolved:0",
      label: "Derived Line",
      start: .zero,
      end: ModelPoint(xMM: 20, yMM: 0)
    )
    inputs.entities = [sourceLine, derivedLine]
    inputs.layers = defaultLayers()
    inputs.selectedTool = .select
    var movedEntityID: String?
    inputs.onMoveEntity = { entityID, _ in
      movedEntityID = entityID
    }

    view.beginSelectInteraction(at: startPoint, in: pageRect)
    view.dragSelectInteraction(to: draggedPoint, in: pageRect)
    view.endSelectInteraction(at: draggedPoint, in: pageRect)

    #expect(movedEntityID == "entity:line-a")
  }

  @Test
  @MainActor
  func segment_length_tool_prefers_fillet_source_line_over_overlapping_derived_line() {
    let pageRect = CGRect(x: 0, y: 0, width: 520, height: 736)
    let coordinateSpace = CanvasCoordinateSpace(pageRect: pageRect)
    let clickPoint = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 5, yMM: 0))
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: pageRect)
    let sourceLine = lineEntity(
      id: "entity:line-a",
      label: "Source Line",
      start: .zero,
      end: ModelPoint(xMM: 20, yMM: 0)
    ).withFilletSuppressedStyle()
    let derivedLine = lineEntity(
      id: "derived:fillet-a:resolved:0",
      label: "Derived Line",
      start: .zero,
      end: ModelPoint(xMM: 20, yMM: 0)
    )
    inputs.entities = [sourceLine, derivedLine]
    inputs.layers = defaultLayers()
    inputs.selectedTool = .segmentLength
    var selectedTarget: CanvasSelectionTarget?
    inputs.onSelectTarget = { target in
      selectedTarget = target
    }

    view.mouseDown(with: unwrap(mouseDownEvent(at: clickPoint)))

    #expect(selectedTarget?.entityID == "entity:line-a")
  }

  @Test
  @MainActor
  func offset_tool_prefers_fillet_arc_over_nearby_source_lines() {
    let pageRect = CGRect(
      origin: .zero, size: CanvasCoordinateSpace.referencePageSize(for: .portrait))
    let coordinateSpace = CanvasCoordinateSpace(pageRect: pageRect)
    let clickPoint = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 19, yMM: 1))
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: pageRect)
    inputs.entities = [
      lineEntity(
        id: "entity:bottom",
        label: "Bottom",
        start: .zero,
        end: ModelPoint(xMM: 20, yMM: 0)
      ).withFilletSuppressedStyle(),
      lineEntity(
        id: "entity:right",
        label: "Right",
        start: ModelPoint(xMM: 20, yMM: 0),
        end: ModelPoint(xMM: 20, yMM: 10)
      ).withFilletSuppressedStyle(),
      arcEntity(
        id: "derived:fillet-a:resolved:1",
        label: "Fillet Arc",
        center: ModelPoint(xMM: 18, yMM: 2),
        radiusMM: 2,
        startAngleRad: -.pi / 2,
        sweepAngleRad: .pi / 2
      ),
    ]
    inputs.derivedElements = [
      ProjectDerivedElement(
        id: "derived:fillet-a",
        layerID: "layer:cut-line",
        kind: .fillet,
        sourceEntityIDs: ["entity:bottom", "entity:right", "entity:top", "entity:left"],
        distanceMM: nil,
        distanceParameterID: nil,
        radiusMM: 2.0,
        radiusParameterID: nil,
        filletClosed: true
      )
    ]
    inputs.layers = defaultLayers()
    inputs.selectedTool = .offset
    var selectedTarget: CanvasSelectionTarget?
    inputs.onSelectTarget = { target in
      selectedTarget = target
    }

    view.mouseDown(with: unwrap(mouseDownEvent(at: clickPoint)))

    #expect(selectedTarget?.entityID == "derived:fillet-a:resolved:1")
  }

  @Test
  @MainActor
  func select_drag_prefers_fillet_source_control_point_over_overlapping_derived_control_point() {
    let pageRect = CGRect(x: 0, y: 0, width: 520, height: 736)
    let coordinateSpace = CanvasCoordinateSpace(pageRect: pageRect)
    let startPoint = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 20, yMM: 0))
    let draggedPoint = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 25, yMM: 5))
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: pageRect)
    inputs.entities = [
      lineEntity(
        id: "entity:line-a",
        label: "Source Line",
        start: .zero,
        end: ModelPoint(xMM: 20, yMM: 0)
      ).withFilletSuppressedStyle(),
      lineEntity(
        id: "derived:fillet-a:resolved:0",
        label: "Derived Line",
        start: .zero,
        end: ModelPoint(xMM: 20, yMM: 0)
      ),
    ]
    inputs.layers = defaultLayers()
    inputs.selectedTool = .select
    var movedTarget: CanvasSelectionTarget?
    inputs.onMoveControlPoint = { target, _ in
      movedTarget = target
    }

    view.beginSelectInteraction(at: startPoint, in: pageRect)
    view.dragSelectInteraction(to: draggedPoint, in: pageRect)
    view.endSelectInteraction(at: draggedPoint, in: pageRect)

    #expect(movedTarget?.entityID == "entity:line-a")
    #expect(movedTarget?.controlPoint == .end)
  }

  @Test
  @MainActor
  func marquee_selection_excludes_fillet_derived_results() {
    let pageRect = CGRect(x: 0, y: 0, width: 520, height: 736)
    let coordinateSpace = CanvasCoordinateSpace(pageRect: pageRect)
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: pageRect)
    inputs.entities = [
      lineEntity(
        id: "entity:line-a",
        label: "Source Line",
        start: .zero,
        end: ModelPoint(xMM: 20, yMM: 0)
      ).withFilletSuppressedStyle(),
      lineEntity(
        id: "derived:fillet-a:resolved:0",
        label: "Derived Line",
        start: .zero,
        end: ModelPoint(xMM: 20, yMM: 0)
      ),
    ]
    inputs.layers = defaultLayers()
    inputs.derivedElements = [
      ProjectDerivedElement(
        id: "derived:fillet-a",
        layerID: "layer:cut-line",
        kind: .fillet,
        sourceEntityIDs: ["entity:line-a", "entity:line-b"],
        distanceMM: nil,
        distanceParameterID: nil,
        radiusMM: 2.0,
        radiusParameterID: nil
      )
    ]
    inputs.selectedTool = .select
    var selectedIDs = Set<String>()
    inputs.onSelectEntities = { ids, _ in
      selectedIDs = ids
    }

    view.beginSelectInteraction(
      at: coordinateSpace.canvasPoint(for: ModelPoint(xMM: -20, yMM: -20)),
      in: pageRect
    )
    view.dragSelectInteraction(
      to: coordinateSpace.canvasPoint(for: ModelPoint(xMM: 25, yMM: 5)),
      in: pageRect
    )
    view.endSelectInteraction(
      at: coordinateSpace.canvasPoint(for: ModelPoint(xMM: 25, yMM: 5)),
      in: pageRect
    )

    #expect(selectedIDs == ["entity:line-a"])
  }

  @Test
  @MainActor
  func marquee_selection_keeps_offset_derived_results_selectable() {
    let pageRect = CGRect(x: 0, y: 0, width: 520, height: 736)
    let coordinateSpace = CanvasCoordinateSpace(pageRect: pageRect)
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: pageRect)
    inputs.entities = [
      lineEntity(
        id: "derived:offset-a:resolved:0",
        label: "Offset Line",
        start: .zero,
        end: ModelPoint(xMM: 20, yMM: 0)
      )
    ]
    inputs.derivedElements = [
      ProjectDerivedElement(
        id: "derived:offset-a",
        layerID: "layer:cut-line",
        kind: .offsetCurve,
        sourceEntityIDs: ["entity:line-a"],
        distanceMM: 2.0,
        distanceParameterID: nil
      )
    ]
    inputs.layers = defaultLayers()
    inputs.selectedTool = .select
    var selectedIDs = Set<String>()
    inputs.onSelectEntities = { ids, _ in
      selectedIDs = ids
    }

    view.beginSelectInteraction(
      at: coordinateSpace.canvasPoint(for: ModelPoint(xMM: -20, yMM: -20)),
      in: pageRect
    )
    view.dragSelectInteraction(
      to: coordinateSpace.canvasPoint(for: ModelPoint(xMM: 25, yMM: 5)),
      in: pageRect
    )
    view.endSelectInteraction(
      at: coordinateSpace.canvasPoint(for: ModelPoint(xMM: 25, yMM: 5)),
      in: pageRect
    )

    #expect(selectedIDs == ["derived:offset-a:resolved:0"])
  }

  @Test
  @MainActor
  func marquee_direction_switches_between_contained_and_crossing_selection() {
    let pageRect = CGRect(
      origin: .zero, size: CanvasCoordinateSpace.referencePageSize(for: .portrait))
    let coordinateSpace = CanvasCoordinateSpace(pageRect: pageRect)
    let left = coordinateSpace.canvasPoint(for: ModelPoint(xMM: -12, yMM: 20))
    let right = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 12, yMM: -20))
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: pageRect)
    inputs.entities = [
      lineEntity(
        id: "entity:inside", start: ModelPoint(xMM: -10, yMM: 0), end: ModelPoint(xMM: 10, yMM: 0)),
      centerLineEntity(
        id: "entity:crossing", start: ModelPoint(xMM: -20, yMM: 0), end: ModelPoint(xMM: 20, yMM: 0)
      ),
    ]
    inputs.layers = defaultLayers()
    inputs.selectedTool = .select
    var selections: [Set<String>] = []
    inputs.onSelectEntities = { ids, _ in selections.append(ids) }

    view.beginSelectInteraction(at: left, in: pageRect)
    view.dragSelectInteraction(to: right, in: pageRect)
    #expect(
      (view.accessibilityValue() as? String)?.contains(
        AppStrings.tr("accessibility.canvas.interaction.marquee_contained", 1)
      ) == true
    )
    view.endSelectInteraction(at: right, in: pageRect)

    view.beginSelectInteraction(at: right, in: pageRect)
    view.dragSelectInteraction(to: left, in: pageRect)
    #expect(
      (view.accessibilityValue() as? String)?.contains(
        AppStrings.tr("accessibility.canvas.interaction.marquee_crossing", 2)
      ) == true
    )
    view.endSelectInteraction(at: left, in: pageRect)

    #expect(selections == [["entity:inside"], ["entity:inside", "entity:crossing"]])
  }

  @Test
  @MainActor
  func marquee_preserves_shift_toggle_for_contained_and_crossing_directions() {
    let pageRect = CGRect(
      origin: .zero, size: CanvasCoordinateSpace.referencePageSize(for: .portrait))
    let coordinateSpace = CanvasCoordinateSpace(pageRect: pageRect)
    let left = coordinateSpace.canvasPoint(for: ModelPoint(xMM: -12, yMM: 20))
    let right = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 12, yMM: -20))
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: pageRect)
    inputs.entities = [
      lineEntity(
        id: "entity:inside", start: ModelPoint(xMM: -10, yMM: 0), end: ModelPoint(xMM: 10, yMM: 0)),
      centerLineEntity(
        id: "entity:crossing", start: ModelPoint(xMM: -20, yMM: 0), end: ModelPoint(xMM: 20, yMM: 0)
      ),
    ]
    inputs.layers = defaultLayers()
    inputs.selectedTool = .select
    var callbacks: [(Set<String>, Bool)] = []
    inputs.onSelectEntities = { ids, extendingSelection in
      callbacks.append((ids, extendingSelection))
    }

    view.beginSelectInteraction(at: left, in: pageRect, togglesSelection: true)
    view.dragSelectInteraction(to: right, in: pageRect)
    view.endSelectInteraction(at: right, in: pageRect)
    view.beginSelectInteraction(at: right, in: pageRect, togglesSelection: true)
    view.dragSelectInteraction(to: left, in: pageRect)
    view.endSelectInteraction(at: left, in: pageRect)

    #expect(callbacks.count == 2)
    #expect(callbacks[0].0 == ["entity:inside"])
    #expect(callbacks[1].0 == ["entity:inside", "entity:crossing"])
    #expect(callbacks[0].1)
    #expect(callbacks[1].1)
  }

  private func escapeKeyEvent() -> NSEvent? {
    NSEvent.keyEvent(
      with: .keyDown,
      location: .zero,
      modifierFlags: [],
      timestamp: 0,
      windowNumber: 0,
      context: nil,
      characters: "\u{1B}",
      charactersIgnoringModifiers: "\u{1B}",
      isARepeat: false,
      keyCode: 53
    )
  }

  private func plainKeyEvent(
    _ key: String,
    modifierFlags: NSEvent.ModifierFlags = []
  ) -> NSEvent? {
    NSEvent.keyEvent(
      with: .keyDown,
      location: .zero,
      modifierFlags: modifierFlags,
      timestamp: 0,
      windowNumber: 0,
      context: nil,
      characters: key,
      charactersIgnoringModifiers: key.lowercased(),
      isARepeat: false,
      keyCode: 9
    )
  }

  private func mouseDownEvent(at point: CGPoint) -> NSEvent? {
    NSEvent.mouseEvent(
      with: .leftMouseDown,
      location: point,
      modifierFlags: [],
      timestamp: 0,
      windowNumber: 0,
      context: nil,
      eventNumber: 0,
      clickCount: 1,
      pressure: 1.0
    )
  }

}
