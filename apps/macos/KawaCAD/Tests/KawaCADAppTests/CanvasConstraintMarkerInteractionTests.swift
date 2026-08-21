import AppKit
import Testing

@testable import KawaCADApp

struct CanvasConstraintMarkerInteractionTests {
  @Test
  @MainActor
  func hit_testing_constraint_marker_returns_the_constraint() {
    let pageRect = CGRect(x: 0, y: 0, width: 520, height: 736)
    let coordinateSpace = CanvasCoordinateSpace(pageRect: pageRect)
    let markerAnchor = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 10, yMM: 0))
    let markerClickPoint = CGPoint(x: markerAnchor.x + 21, y: markerAnchor.y - 15)
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
    inputs.documentConstraints = [
      projectConstraint(
        id: "constraint:horizontal",
        rawKind: "horizontal",
        targetsJSON: #"[{"entity":"entity:line-a"}]"#
      )
    ]
    inputs.layers = defaultLayers()
    inputs.selectedTool = .select
    setConstraintMarkerProjection(
      on: inputs,
      id: "constraint:horizontal",
      position: ModelPoint(xMM: 10, yMM: 0)
    )

    #expect(view.constraintMarkerID(at: markerClickPoint, in: pageRect) == "constraint:horizontal")
  }

  @Test
  @MainActor
  func output_preview_does_not_hit_test_constraint_markers() {
    let pageRect = CGRect(x: 0, y: 0, width: 520, height: 736)
    let coordinateSpace = CanvasCoordinateSpace(pageRect: pageRect)
    let markerAnchor = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 10, yMM: 0))
    let markerClickPoint = CGPoint(x: markerAnchor.x + 21, y: markerAnchor.y - 15)
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
    inputs.documentConstraints = [
      projectConstraint(
        id: "constraint:horizontal",
        rawKind: "horizontal",
        targetsJSON: #"[{"entity":"entity:line-a"}]"#
      )
    ]
    inputs.layers = defaultLayers()
    inputs.selectedTool = .select
    inputs.viewMode = .outputPreview
    setConstraintMarkerProjection(
      on: inputs,
      id: "constraint:horizontal",
      position: ModelPoint(xMM: 10, yMM: 0)
    )

    #expect(view.constraintMarkerID(at: markerClickPoint, in: pageRect) == nil)
    #expect(view.contextMenuItems(at: markerClickPoint, in: pageRect).isEmpty)
  }

  @Test
  @MainActor
  func hovering_constraint_marker_reports_the_constraint() {
    let pageRect = CGRect(x: 0, y: 0, width: 520, height: 736)
    let coordinateSpace = CanvasCoordinateSpace(pageRect: pageRect)
    let markerAnchor = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 10, yMM: 0))
    let markerHoverPoint = CGPoint(x: markerAnchor.x + 21, y: markerAnchor.y - 15)
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
    inputs.documentConstraints = [
      projectConstraint(
        id: "constraint:horizontal",
        rawKind: "horizontal",
        targetsJSON: #"[{"entity":"entity:line-a"}]"#
      )
    ]
    inputs.layers = defaultLayers()
    inputs.selectedTool = .select
    setConstraintMarkerProjection(
      on: inputs,
      id: "constraint:horizontal",
      position: ModelPoint(xMM: 10, yMM: 0)
    )
    var hoveredConstraintID: String?
    inputs.onHoverConstraint = { constraintID in
      hoveredConstraintID = constraintID
    }

    view.updateHoveredConstraintMarker(for: markerHoverPoint, in: pageRect)

    #expect(hoveredConstraintID == "constraint:horizontal")
  }

  @Test
  @MainActor
  func coincident_group_visibility_reads_core_target_objects() {
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: CGRect(x: 0, y: 0, width: 520, height: 736))
    let visibleGroup = CoincidentPointGroup(
      id: "group:visible",
      representative: .zero,
      targetsJSON:
        #"[{"controlPoint":{"entity_id":"entity:line-a","point":"start"}},{"entity":"entity:point-a"}]"#
    )
    let hiddenGroup = CoincidentPointGroup(
      id: "group:hidden",
      representative: .zero,
      targetsJSON:
        #"[{"controlPoint":{"entity_id":"entity:line-a","point":"start"}},{"entity":"entity:point-hidden"}]"#
    )
    let visibleEntityIDs: Set<String> = ["entity:line-a", "entity:point-a"]

    #expect(view.coincidentGroupIsVisible(visibleGroup, visibleEntityIDs: visibleEntityIDs))
    #expect(!view.coincidentGroupIsVisible(hiddenGroup, visibleEntityIDs: visibleEntityIDs))
  }

  @Test
  @MainActor
  func context_menu_items_change_by_canvas_target() {
    let pageRect = CGRect(x: 0, y: 0, width: 520, height: 736)
    let coordinateSpace = CanvasCoordinateSpace(pageRect: pageRect)
    let markerAnchor = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 10, yMM: 0))
    let markerPoint = CGPoint(x: markerAnchor.x + 21, y: markerAnchor.y - 15)
    let entityPoint = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 10, yMM: 0))
    let blankPoint = coordinateSpace.canvasPoint(for: ModelPoint(xMM: -80, yMM: -80))
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
    inputs.documentConstraints = [
      projectConstraint(
        id: "constraint:horizontal",
        rawKind: "horizontal",
        targetsJSON: #"[{"entity":"entity:line-a"}]"#
      )
    ]
    inputs.layers = defaultLayers()
    setConstraintMarkerProjection(
      on: inputs,
      id: "constraint:horizontal",
      position: ModelPoint(xMM: 10, yMM: 0)
    )

    #expect(
      view.contextMenuItems(at: markerPoint, in: pageRect).map(\.action) == [.deleteSelection])
    #expect(
      view.contextMenuItems(at: entityPoint, in: pageRect).map(\.action) == [
        .copySelection,
        .duplicateSelection,
        nil,
        .deleteSelection,
      ])
    #expect(
      view.contextMenuItems(at: blankPoint, in: pageRect).map(\.action) == [
        .pasteCopiedEntity,
        .selectAllEntities,
      ])
  }

  @Test
  @MainActor
  func free_text_context_menu_prefers_note_actions() {
    let pageRect = CGRect(x: 0, y: 0, width: 520, height: 736)
    let coordinateSpace = CanvasCoordinateSpace(pageRect: pageRect)
    let notePoint = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 10, yMM: -8))
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: pageRect)
    inputs.freeTexts = [
      ProjectFreeText(
        id: "free-text:note",
        content: "注記",
        positionMM: ModelPoint(xMM: 10, yMM: -8),
        fontSizeMM: 4.0
      )
    ]

    #expect(
      view.contextMenuItems(at: notePoint, in: pageRect).map(\.action) == [
        .editFreeText,
        nil,
        .deleteSelection,
      ])
  }

  @Test
  @MainActor
  func inline_free_text_editor_opens_from_request_and_commits_updates() throws {
    let pageRect = CGRect(x: 0, y: 0, width: 520, height: 736)
    let freeText = ProjectFreeText(
      id: "free-text:note",
      content: "注記",
      positionMM: ModelPoint(xMM: 10, yMM: -8),
      fontSizeMM: 4.0
    )
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: pageRect)
    inputs.freeTexts = [freeText]
    inputs.freeTextInlineEditRequestID = freeText.id
    var handledRequestID: String?
    var updatedFreeText: ProjectFreeText?
    inputs.onFreeTextInlineEditRequestHandled = { handledRequestID = $0 }
    inputs.onUpdateFreeText = { update in
      updatedFreeText = update
      return true
    }

    view.syncInlineFreeTextEditorWithRequest()

    let editor = try #require(view.subviews.compactMap { $0 as? NSTextView }.first)
    #expect(handledRequestID == freeText.id)
    #expect(editor.string == "注記")

    editor.string = "縫い始め位置"
    view.endInlineFreeTextEditing(commit: true)

    #expect(updatedFreeText == freeText.withContent("縫い始め位置"))
    #expect(view.subviews.compactMap { $0 as? NSTextView }.isEmpty)
  }

  @Test
  @MainActor
  func double_clicking_free_text_opens_inline_editor_without_inspector_focus() throws {
    let pageRect = CGRect(x: 0, y: 0, width: 520, height: 736)
    let coordinateSpace = CanvasCoordinateSpace(pageRect: pageRect)
    let notePoint = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 10, yMM: -8))
    let freeText = ProjectFreeText(
      id: "free-text:note",
      content: "注記",
      positionMM: ModelPoint(xMM: 10, yMM: -8),
      fontSizeMM: 4.0
    )
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: pageRect)
    inputs.freeTexts = [freeText]
    var selectedFreeTextID: String?
    inputs.onSelectFreeText = { selectedFreeTextID = $0 }

    view.beginSelectInteraction(at: notePoint, in: pageRect, clickCount: 2)

    #expect(selectedFreeTextID == freeText.id)
    let editor = try #require(view.subviews.compactMap { $0 as? NSTextView }.first)
    #expect(editor.string == "注記")
  }

  @Test
  @MainActor
  func dragging_free_text_with_select_tool_updates_position() {
    let pageRect = CGRect(x: 0, y: 0, width: 520, height: 736)
    let coordinateSpace = CanvasCoordinateSpace(pageRect: pageRect)
    let startModelPoint = ModelPoint(xMM: 10, yMM: -8)
    let dropModelPoint = ModelPoint(xMM: 24, yMM: -2)
    let startPoint = coordinateSpace.canvasPoint(for: startModelPoint)
    let dropPoint = coordinateSpace.canvasPoint(for: dropModelPoint)
    let freeText = ProjectFreeText(
      id: "free-text:note",
      content: "注記",
      positionMM: startModelPoint,
      fontSizeMM: 4.0
    )
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: pageRect)
    inputs.freeTexts = [freeText]
    inputs.selectedTool = .select
    inputs.gridSnapEnabled = false
    inputs.pointSnapEnabled = false
    var selectedFreeTextID: String?
    var updatedFreeText: ProjectFreeText?
    inputs.onSelectFreeText = { selectedFreeTextID = $0 }
    inputs.onUpdateFreeText = { update in
      updatedFreeText = update
      return true
    }

    view.beginSelectInteraction(at: startPoint, in: pageRect)
    view.dragFreeTextInteraction(to: dropPoint, in: pageRect)
    view.mouseUp(with: unwrap(mouseEvent(.leftMouseUp, at: eventPoint(for: dropPoint, in: view))))

    #expect(selectedFreeTextID == freeText.id)
    #expect(updatedFreeText?.id == freeText.id)
    #expect(updatedFreeText?.content == freeText.content)
    #expect(abs((updatedFreeText?.positionMM.xMM ?? .infinity) - dropModelPoint.xMM) < 0.0001)
    #expect(abs((updatedFreeText?.positionMM.yMM ?? .infinity) - dropModelPoint.yMM) < 0.0001)
    #expect(updatedFreeText?.fontSizeMM == freeText.fontSizeMM)
  }

  @Test
  @MainActor
  func context_menu_items_work_outside_origin_a4_page() {
    let pageRect = CGRect(x: 0, y: 0, width: 520, height: 736)
    let coordinateSpace = CanvasCoordinateSpace(pageRect: pageRect)
    let outsideEntityPoint = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 320, yMM: -410))
    let outsideBlankPoint = coordinateSpace.canvasPoint(for: ModelPoint(xMM: -320, yMM: 410))
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: pageRect)
    inputs.entities = [
      pointEntity(
        id: "entity:outside-a4",
        label: "Outside A4",
        point: ModelPoint(xMM: 320, yMM: -410)
      )
    ]
    inputs.layers = defaultLayers()

    #expect(
      view.contextMenuItems(at: outsideEntityPoint, in: pageRect).map(\.action) == [
        .copySelection,
        .duplicateSelection,
        nil,
        .deleteSelection,
      ])
    #expect(
      view.contextMenuItems(at: outsideBlankPoint, in: pageRect).map(\.action) == [
        .pasteCopiedEntity,
        .selectAllEntities,
      ])
  }

  @Test
  @MainActor
  func dimension_constraint_display_hit_testing_distinguishes_label_and_dimension_line() {
    let pageRect = CGRect(x: 0, y: 0, width: 520, height: 736)
    let coordinateSpace = CanvasCoordinateSpace(pageRect: pageRect)
    let start = coordinateSpace.canvasPoint(for: .zero)
    let end = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 100, yMM: 0))
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: pageRect)
    inputs.entities = [
      lineEntity(
        id: "entity:line-a",
        label: "Line A",
        start: .zero,
        end: ModelPoint(xMM: 100, yMM: 0)
      )
    ]
    inputs.documentConstraints = [
      projectConstraint(
        id: "constraint:length",
        rawKind: "segmentLength",
        targetsJSON: #"[{"entity":"entity:line-a"}]"#,
        valueMM: 100.0
      )
    ]
    inputs.layers = defaultLayers()
    inputs.selectedTool = .select
    setDimensionProjection(
      on: inputs,
      id: "constraint:length",
      start: .zero,
      end: ModelPoint(xMM: 100, yMM: 0)
    )

    let labelPoint = CGPoint(x: (start.x + end.x) / 2.0, y: start.y + 16.0)
    let linePoint = CGPoint(x: start.x + (end.x - start.x) * 0.25, y: start.y + 12.0)

    let labelHit = view.dimensionConstraintAnnotationHitInfo(at: labelPoint, in: pageRect)
    let lineHit = view.dimensionConstraintAnnotationHitInfo(at: linePoint, in: pageRect)

    #expect(labelHit?.constraintID == "constraint:length")
    #expect(labelHit?.labelOnly == true)
    #expect(lineHit?.constraintID == "constraint:length")
    #expect(lineHit?.labelOnly == false)
  }

  @Test
  @MainActor
  func dragging_dimension_constraint_line_requests_overall_display_move() {
    let pageRect = CGRect(
      origin: .zero, size: CanvasCoordinateSpace.referencePageSize(for: .portrait))
    let coordinateSpace = CanvasCoordinateSpace(pageRect: pageRect)
    let start = coordinateSpace.canvasPoint(for: .zero)
    let end = coordinateSpace.canvasPoint(for: ModelPoint(xMM: 100, yMM: 0))
    let linePoint = CGPoint(x: start.x + (end.x - start.x) * 0.25, y: start.y + 12.0)
    let dropPoint = CGPoint(x: linePoint.x, y: linePoint.y + 24.0)
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: pageRect)
    inputs.entities = [
      lineEntity(
        id: "entity:line-a",
        label: "Line A",
        start: .zero,
        end: ModelPoint(xMM: 100, yMM: 0)
      )
    ]
    inputs.documentConstraints = [
      projectConstraint(
        id: "constraint:length",
        rawKind: "segmentLength",
        targetsJSON: #"[{"entity":"entity:line-a"}]"#,
        valueMM: 100.0
      )
    ]
    inputs.layers = defaultLayers()
    inputs.selectedTool = .select
    setDimensionProjection(
      on: inputs,
      id: "constraint:length",
      start: .zero,
      end: ModelPoint(xMM: 100, yMM: 0)
    )

    var moved: (constraintID: String, labelOnly: Bool)?
    inputs.onMoveDimensionConstraintAnnotation = { constraintID, _, labelOnly in
      moved = (constraintID, labelOnly)
    }

    view.mouseDown(
      with: unwrap(mouseEvent(.leftMouseDown, at: eventPoint(for: linePoint, in: view))))
    view.mouseDragged(
      with: unwrap(mouseEvent(.leftMouseDragged, at: eventPoint(for: dropPoint, in: view))))
    view.mouseUp(with: unwrap(mouseEvent(.leftMouseUp, at: eventPoint(for: dropPoint, in: view))))

    #expect(moved?.constraintID == "constraint:length")
    #expect(moved?.labelOnly == false)
  }
}

@MainActor
private func setConstraintMarkerProjection(
  on inputs: CanvasTestInputBuilder,
  id: String,
  position: ModelPoint
) {
  inputs.canvasProjection = canvasProjection(
    constraintMarkers: [resolvedCanvasPoint(id: id, position: position)]
  )
}

@MainActor
private func setDimensionProjection(
  on inputs: CanvasTestInputBuilder,
  id: String,
  start: ModelPoint,
  end: ModelPoint
) {
  inputs.canvasProjection = canvasProjection(
    dimensionConstraints: [
      resolvedCanvasGeometry(id: id, start: start, end: end)
    ]
  )
}

private func projectConstraint(
  id: String,
  rawKind: String,
  targetsJSON: String,
  valueMM: Double? = nil
) -> ProjectConstraint {
  ProjectConstraint(
    id: id,
    rawKind: rawKind,
    kind: rawKind,
    targets: [],
    targetsJSON: targetsJSON,
    valueMM: valueMM,
    valueDegrees: nil,
    valueParameterID: nil,
    status: .underConstrained
  )
}

private func mouseEvent(_ type: NSEvent.EventType, at point: CGPoint) -> NSEvent? {
  NSEvent.mouseEvent(
    with: type,
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

private func eventPoint(for viewPoint: CGPoint, in view: NSView) -> CGPoint {
  CGPoint(x: viewPoint.x, y: view.bounds.height - viewPoint.y)
}
