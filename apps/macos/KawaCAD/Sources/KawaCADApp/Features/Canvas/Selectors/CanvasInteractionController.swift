import CoreGraphics

enum CanvasKeyboardCommand: Equatable {
  case activateSelectTool
  case cancelInteraction
  case deleteSelection
  case unhandled
}

struct CanvasKeyboardInput {
  let isEscape: Bool
  let isPlainTextSelectShortcut: Bool
  let isDelete: Bool
  let selectedTool: CanvasTool
  let hasCancellationTarget: Bool
}

enum CanvasSelectionCommand {
  case selectEntity(String?, toggled: Bool)
  case selectEntities(Set<String>, extending: Bool)
  case selectConstraint(String?)
  case selectMeasurementAnnotation(String?)
  case selectFreeText(String?)
  case selectStitchStartPoint(String?)
}

struct CanvasSelectionInput {
  let point: CGPoint
  let modelPoint: ModelPoint
  let clickCount: Int
  let togglesSelection: Bool
  let modifiers: CanvasPlacementModifiers
  let selectedEntityIDs: Set<String>
  let measurementHit: (id: String, labelOnly: Bool)?
  let dimensionHit: (id: String, labelOnly: Bool)?
  let controlPointTarget: CanvasSelectionTarget?
  let constraintMarkerID: String?
  let stitchStartPointID: String?
  let freeTextID: String?
  let entityID: String?
}

struct CanvasSelectionResult {
  let commands: [CanvasSelectionCommand]
  let inlineFreeTextID: String?
}

struct CanvasInteractionSnapshot {
  let hoveredConstraintTarget: CanvasSelectionTarget?
  let constraintHoverPoint: CGPoint?
  let interactionState: CanvasInteractionState
  let snapIndicatorPoint: ModelPoint?
  let snapSuppressionPoint: ModelPoint?
  let contextMenuModelPoint: ModelPoint?
  let contextMenuFreeTextID: String?
  let measurementDragState: MeasurementAnnotationDragState?
  let dimensionConstraintDragState: DimensionConstraintAnnotationDragState?
  let freeTextDragState: FreeTextDragState?

  var dragState: CanvasDragState? { interactionState.dragState }
}

/// Applies interaction decisions to feature actions without making the AppKit view an action
/// router.
struct CanvasInteractionCommandExecutor {
  let actions: LeatherCanvasActionGroups

  func execute(_ command: CanvasKeyboardCommand) {
    switch command {
    case .activateSelectTool:
      actions.editing.activateTool(.select)
    case .cancelInteraction:
      actions.editing.cancelInteraction()
    case .deleteSelection:
      actions.selection.deleteSelection()
    case .unhandled:
      break
    }
  }

  @discardableResult
  func updateFreeText(_ freeText: ProjectFreeText) -> Bool {
    actions.editing.updateFreeText(freeText)
  }
  func selectMeasurementAnnotation(_ id: String?) {
    actions.selection.selectMeasurementAnnotation(id)
  }
  func selectConstraint(_ id: String?) { actions.selection.selectConstraint(id) }
  func selectFreeText(_ id: String?) { actions.selection.selectFreeText(id) }
  func selectEntity(_ id: String?) { actions.selection.selectEntity(id) }
  func hoverPoint(_ point: ModelPoint, modifiers: CanvasPlacementModifiers) {
    actions.placement.hoverPoint(point, modifiers)
  }
  func clearHoverConstraint() { actions.selection.hoverConstraint(nil) }
  func hoverConstraint(_ id: String?) { actions.selection.hoverConstraint(id) }
  func updateCursorPoint(_ modelPoint: ModelPoint?, _ screenPoint: CGPoint?) {
    actions.placement.cursorPoint(modelPoint, screenPoint)
  }
  func freeTextInlineEditRequestHandled(_ id: String) {
    actions.editing.freeTextInlineEditRequestHandled(id)
  }

  func execute(_ result: CanvasInteractionResult) {
    if let command = result.command {
      execute(command)
    }
    execute(result.selectionCommands)
  }

  func execute(_ commands: [CanvasSelectionCommand]) {
    for command in commands {
      switch command {
      case .selectEntity(let entityID, let toggled):
        if toggled, let entityID {
          actions.selection.toggleEntitySelection(entityID)
        } else {
          actions.selection.selectEntity(entityID)
        }
      case .selectEntities(let entityIDs, let extending):
        actions.selection.selectEntities(entityIDs, extending)
      case .selectConstraint(let constraintID):
        actions.selection.selectConstraint(constraintID)
      case .selectMeasurementAnnotation(let annotationID):
        actions.selection.selectMeasurementAnnotation(annotationID)
      case .selectFreeText(let freeTextID):
        actions.selection.selectFreeText(freeTextID)
      case .selectStitchStartPoint(let stitchStartPointID):
        actions.selection.selectStitchStartPoint(stitchStartPointID)
      }
    }
  }

  func execute(_ command: CanvasInteractionCommand) {
    switch command {
    case .setPartOrigin(let modelPoint):
      actions.placement.setPartOrigin(modelPoint)
    case .placePoint(let modelPoint, let modifiers):
      actions.placement.placePoint(modelPoint, modifiers)
    case .selectConstraintTarget(let target):
      actions.selection.selectTarget(target)
    case .previewMoveEntities(let entityIDs, let delta, let duplicating):
      actions.move.previewMoveEntities(entityIDs, delta, duplicating)
    case .previewMoveControlPoint(let target, let modelPoint):
      actions.move.previewMoveControlPoint(target, modelPoint)
    case .previewMoveEntity(let entityID, let delta):
      actions.move.previewMoveEntity(entityID, delta)
    case .moveEntities(let entityIDs, let delta, let duplicating):
      actions.move.moveEntities(entityIDs, delta, duplicating)
    case .moveControlPoint(let target, let modelPoint):
      actions.move.moveControlPoint(target, modelPoint)
    case .moveEntity(let entityID, let delta):
      actions.move.moveEntity(entityID, delta)
    case .cancelMovePreview:
      actions.move.cancelMovePreview()
    case .selectEntities(let entityIDs, let extending):
      actions.selection.selectEntities(entityIDs, extending)
    case .moveMeasurementAnnotation(let id, let delta, let labelOnly):
      actions.move.moveMeasurementAnnotation(id, delta, labelOnly)
    case .moveDimensionConstraintAnnotation(let id, let delta, let labelOnly):
      actions.move.moveDimensionConstraintAnnotation(id, delta, labelOnly)
    case .updateFreeText(let freeText):
      _ = actions.editing.updateFreeText(freeText)
    case .panCanvas(let delta):
      actions.viewport.panCanvas(delta)
    case .setCanvasViewport(let scale, let pan, let message):
      actions.viewport.setCanvasViewport(scale, pan, message)
    case .copySelection:
      actions.editing.copySelection()
    case .pasteCopiedEntity(let point):
      if let point {
        actions.editing.pasteCopiedEntityAtPoint(point)
      } else {
        actions.editing.pasteCopiedEntity()
      }
    case .duplicateSelection:
      actions.editing.duplicateSelection()
    case .deleteSelection:
      actions.selection.deleteSelection()
    case .convertMeasurementToConstraint(let id):
      actions.editing.convertMeasurementAnnotationToConstraint(id)
    case .smoothSelectedArcTangencies:
      actions.editing.smoothSelectedArcTangenciesPrototype()
    case .selectAllEntities:
      actions.selection.selectAllEntities()
    }
  }
}

/// Owns transient interaction state and turns keyboard intent into canvas commands.
struct CanvasInteractionController {
  private var hoveredConstraintTarget: CanvasSelectionTarget?
  private var constraintHoverPoint: CGPoint?
  private var interactionState = CanvasInteractionState()
  private var snapIndicatorPoint: ModelPoint?
  private var snapSuppressionPoint: ModelPoint?
  private var contextMenuModelPoint: ModelPoint?
  private var contextMenuFreeTextID: String?
  private var measurementDragState: MeasurementAnnotationDragState?
  private var dimensionConstraintDragState: DimensionConstraintAnnotationDragState?
  private var freeTextDragState: FreeTextDragState?

  var snapshot: CanvasInteractionSnapshot {
    CanvasInteractionSnapshot(
      hoveredConstraintTarget: hoveredConstraintTarget,
      constraintHoverPoint: constraintHoverPoint,
      interactionState: interactionState,
      snapIndicatorPoint: snapIndicatorPoint,
      snapSuppressionPoint: snapSuppressionPoint,
      contextMenuModelPoint: contextMenuModelPoint,
      contextMenuFreeTextID: contextMenuFreeTextID,
      measurementDragState: measurementDragState,
      dimensionConstraintDragState: dimensionConstraintDragState,
      freeTextDragState: freeTextDragState
    )
  }

  mutating func updateHover(target: CanvasSelectionTarget?, at point: CGPoint?) {
    hoveredConstraintTarget = target
    constraintHoverPoint = target == nil ? nil : point
  }

  mutating func clearHover() {
    hoveredConstraintTarget = nil
    constraintHoverPoint = nil
  }

  mutating func updateSnap(indicator: ModelPoint?, suppression: ModelPoint?) {
    snapIndicatorPoint = indicator
    snapSuppressionPoint = suppression
  }

  mutating func clearSnap() {
    snapIndicatorPoint = nil
    snapSuppressionPoint = nil
  }

  mutating func setContextMenu(modelPoint: ModelPoint?, freeTextID: String?) {
    contextMenuModelPoint = modelPoint
    contextMenuFreeTextID = freeTextID
  }

  mutating func clearDragState() {
    interactionState.dragState = nil
  }

  mutating func handleKeyboardCommand(_ command: CanvasKeyboardCommand) {
    if command == .cancelInteraction {
      clearTransientInteraction()
    }
  }

  mutating func mouseDownResult(for input: CanvasMouseDownInput) -> CanvasInteractionResult {
    if input.selectedTool == .select, let selectionInput = input.selectionInput {
      let selectionResult = selectionResult(for: selectionInput)
      return CanvasInteractionResult(
        command: nil,
        selectionCommands: selectionResult.commands,
        inlineFreeTextID: selectionResult.inlineFreeTextID,
        shouldRedraw: false
      )
    }
    return CanvasInteraction.mouseDownResult(for: input)
  }

  mutating func dragResult(for input: CanvasDragInput) -> CanvasInteractionResult {
    let result = CanvasInteraction.dragResult(for: input)
    interactionState.dragState = result.nextDragState
    return result
  }

  mutating func endDragResult(for input: CanvasDragInput) -> CanvasInteractionResult {
    let result = CanvasInteraction.endDragResult(for: input)
    interactionState.dragState = result.nextDragState
    return result
  }

  mutating func selectionResult(for input: CanvasSelectionInput) -> CanvasSelectionResult {
    if let measurementHit = input.measurementHit {
      beginMeasurementDrag(
        annotationID: measurementHit.id,
        labelOnly: measurementHit.labelOnly,
        at: input.modelPoint
      )
      return CanvasSelectionResult(
        commands: [.selectMeasurementAnnotation(measurementHit.id)],
        inlineFreeTextID: nil
      )
    }
    if let dimensionHit = input.dimensionHit {
      beginDimensionDrag(
        constraintID: dimensionHit.id,
        labelOnly: dimensionHit.labelOnly,
        at: input.modelPoint
      )
      return CanvasSelectionResult(
        commands: [.selectConstraint(dimensionHit.id)],
        inlineFreeTextID: nil
      )
    }
    if let controlPointTarget = input.controlPointTarget {
      interactionState.dragState = .controlPoint(
        target: controlPointTarget,
        startPoint: input.modelPoint,
        currentPoint: input.modelPoint
      )
      let entityID = controlPointTarget.entityID
      return CanvasSelectionResult(
        commands: [
          input.togglesSelection
            ? .selectEntity(entityID, toggled: true)
            : .selectEntity(entityID, toggled: false)
        ],
        inlineFreeTextID: nil
      )
    }
    if let constraintMarkerID = input.constraintMarkerID {
      interactionState.dragState = nil
      return CanvasSelectionResult(
        commands: [.selectConstraint(constraintMarkerID)],
        inlineFreeTextID: nil
      )
    }
    if let stitchStartPointID = input.stitchStartPointID {
      interactionState.dragState = nil
      return CanvasSelectionResult(
        commands: [.selectStitchStartPoint(stitchStartPointID)],
        inlineFreeTextID: nil
      )
    }
    if let freeTextID = input.freeTextID {
      interactionState.dragState = nil
      if input.clickCount >= 2 {
        return CanvasSelectionResult(
          commands: [.selectFreeText(freeTextID)],
          inlineFreeTextID: freeTextID
        )
      }
      beginFreeTextDrag(id: freeTextID, at: input.modelPoint)
      return CanvasSelectionResult(
        commands: [.selectFreeText(freeTextID)],
        inlineFreeTextID: nil
      )
    }
    if let entityID = input.entityID {
      let draggingIDs =
        input.selectedEntityIDs.contains(entityID)
        ? input.selectedEntityIDs
        : [entityID]
      interactionState.dragState = .entities(
        entityIDs: draggingIDs,
        anchorEntityID: entityID,
        startPoint: input.modelPoint,
        currentPoint: input.modelPoint,
        duplicating: input.modifiers.duplicatesOnDrag
      )
      if input.togglesSelection {
        return CanvasSelectionResult(
          commands: [.selectEntity(entityID, toggled: true)],
          inlineFreeTextID: nil
        )
      }
      let command: CanvasSelectionCommand =
        input.selectedEntityIDs.contains(entityID) && input.selectedEntityIDs.count > 1
        ? .selectEntities(input.selectedEntityIDs, extending: false)
        : .selectEntity(entityID, toggled: false)
      return CanvasSelectionResult(commands: [command], inlineFreeTextID: nil)
    }

    interactionState.dragState = .marquee(
      startPoint: input.point,
      currentPoint: input.point,
      extendingSelection: input.togglesSelection
    )
    let commands: [CanvasSelectionCommand] =
      input.togglesSelection
      ? []
      : [
        .selectEntity(nil, toggled: false),
        .selectMeasurementAnnotation(nil),
        .selectFreeText(nil),
        .selectStitchStartPoint(nil),
      ]
    return CanvasSelectionResult(commands: commands, inlineFreeTextID: nil)
  }

  mutating func beginMeasurementDrag(
    annotationID: String,
    labelOnly: Bool,
    at point: ModelPoint
  ) {
    measurementDragState = MeasurementAnnotationDragState(
      annotationID: annotationID,
      labelOnly: labelOnly,
      startPoint: point,
      currentPoint: point
    )
  }

  mutating func updateMeasurementDrag(to point: ModelPoint) {
    guard let measurementDragState else { return }
    self.measurementDragState = MeasurementAnnotationDragState(
      annotationID: measurementDragState.annotationID,
      labelOnly: measurementDragState.labelOnly,
      startPoint: measurementDragState.startPoint,
      currentPoint: point
    )
  }

  mutating func finishMeasurementDragResult() -> CanvasInteractionResult {
    guard let state = measurementDragState else {
      return CanvasInteractionResult(command: nil, shouldRedraw: false)
    }
    measurementDragState = nil
    let command: CanvasInteractionCommand? =
      CanvasInteractionState.hasMeaningfulModelMovement(
        from: state.startPoint,
        to: state.currentPoint
      )
      ? .moveMeasurementAnnotation(
        state.annotationID,
        CanvasInteractionState.delta(from: state.startPoint, to: state.currentPoint),
        state.labelOnly
      )
      : nil
    return CanvasInteractionResult(command: command, shouldRedraw: true)
  }

  mutating func beginDimensionDrag(
    constraintID: String,
    labelOnly: Bool,
    at point: ModelPoint
  ) {
    dimensionConstraintDragState = DimensionConstraintAnnotationDragState(
      constraintID: constraintID,
      labelOnly: labelOnly,
      startPoint: point,
      currentPoint: point
    )
  }

  mutating func updateDimensionDrag(to point: ModelPoint) {
    guard let dimensionConstraintDragState else { return }
    self.dimensionConstraintDragState = DimensionConstraintAnnotationDragState(
      constraintID: dimensionConstraintDragState.constraintID,
      labelOnly: dimensionConstraintDragState.labelOnly,
      startPoint: dimensionConstraintDragState.startPoint,
      currentPoint: point
    )
  }

  mutating func finishDimensionDragResult() -> CanvasInteractionResult {
    guard let state = dimensionConstraintDragState else {
      return CanvasInteractionResult(command: nil, shouldRedraw: false)
    }
    dimensionConstraintDragState = nil
    let command: CanvasInteractionCommand? =
      CanvasInteractionState.hasMeaningfulModelMovement(
        from: state.startPoint,
        to: state.currentPoint
      )
      ? .moveDimensionConstraintAnnotation(
        state.constraintID,
        CanvasInteractionState.delta(from: state.startPoint, to: state.currentPoint),
        state.labelOnly
      )
      : nil
    return CanvasInteractionResult(command: command, shouldRedraw: true)
  }

  mutating func beginFreeTextDrag(id: String, at point: ModelPoint) {
    freeTextDragState = FreeTextDragState(
      freeTextID: id,
      startPoint: point,
      currentPoint: point
    )
  }

  mutating func updateFreeTextDrag(to point: ModelPoint) {
    guard let freeTextDragState else { return }
    self.freeTextDragState = FreeTextDragState(
      freeTextID: freeTextDragState.freeTextID,
      startPoint: freeTextDragState.startPoint,
      currentPoint: point
    )
  }

  mutating func finishFreeTextDragResult(freeText: ProjectFreeText?) -> CanvasInteractionResult {
    guard let state = freeTextDragState else {
      return CanvasInteractionResult(command: nil, shouldRedraw: false)
    }
    freeTextDragState = nil
    guard
      CanvasInteractionState.hasMeaningfulModelMovement(
        from: state.startPoint,
        to: state.currentPoint
      ),
      let freeText
    else {
      return CanvasInteractionResult(command: nil, shouldRedraw: true)
    }
    let delta = CanvasInteractionState.delta(from: state.startPoint, to: state.currentPoint)
    return CanvasInteractionResult(
      command: .updateFreeText(
        freeText.withPosition(
          freeText.positionMM.translatedBy(dxMM: delta.xMM, dyMM: delta.yMM)
        )),
      shouldRedraw: true
    )
  }

  static func panCommand(delta: CGSize) -> CanvasInteractionCommand? {
    guard abs(delta.width) > 0.01 || abs(delta.height) > 0.01 else { return nil }
    return .panCanvas(delta)
  }

  static func magnifyCommand(for input: CanvasMagnifyInput) -> CanvasInteractionCommand {
    let nextScale = min(
      max(input.currentScale * (1.0 + Double(input.magnification)), CanvasMetrics.zoomMinimum),
      CanvasMetrics.zoomMaximum
    )
    let basePageRect = CanvasLayout.pageRect(
      in: input.canvasBounds,
      zoomScale: nextScale,
      panOffset: .zero,
      orientation: input.orientation
    )
    let baseAnchorPoint = CanvasCoordinateSpace(
      pageRect: basePageRect,
      orientation: input.orientation
    ).canvasPoint(for: input.anchorModelPoint)
    return .setCanvasViewport(
      nextScale,
      CGSize(
        width: input.anchorPoint.x - baseAnchorPoint.x,
        height: input.anchorPoint.y - baseAnchorPoint.y
      ),
      input.message
    )
  }

  mutating func contextMenuExecution(
    for action: CanvasContextMenuAction,
    selectedMeasurementID: String?,
    selectedFreeTextID: String?
  ) -> CanvasContextMenuExecution? {
    defer { setContextMenu(modelPoint: nil, freeTextID: nil) }
    switch action {
    case .copySelection:
      return .command(.copySelection)
    case .pasteCopiedEntity:
      return .command(.pasteCopiedEntity(contextMenuModelPoint))
    case .duplicateSelection:
      return .command(.duplicateSelection)
    case .deleteSelection:
      return .command(.deleteSelection)
    case .editFreeText:
      return .editFreeText(contextMenuFreeTextID ?? selectedFreeTextID)
    case .convertMeasurementToConstraint:
      return selectedMeasurementID.map {
        .command(.convertMeasurementToConstraint($0))
      }
    case .smoothArcTangenciesPrototype:
      return .command(.smoothSelectedArcTangencies)
    case .selectAllEntities:
      return .command(.selectAllEntities)
    }
  }

  static func keyboardCommand(for input: CanvasKeyboardInput) -> CanvasKeyboardCommand {
    if input.isEscape {
      return input.selectedTool != .select && !input.hasCancellationTarget
        ? .activateSelectTool
        : .cancelInteraction
    }
    if input.isPlainTextSelectShortcut {
      return .activateSelectTool
    }
    if input.isDelete {
      return .deleteSelection
    }
    return .unhandled
  }

  func hasCancellationTarget(
    isSettingPartOrigin: Bool,
    measurementAnnotationSelected: Bool,
    freeTextSelected: Bool,
    draftStartPoint: ModelPoint?,
    draftCurrentPoint: ModelPoint?,
    draftArcStartPoint: ModelPoint?,
    pendingConstraintTargets: [CanvasSelectionTarget],
    selectedEntityID: String?,
    selectedEntityIDs: Set<String>,
    selectedConstraintID: String?
  ) -> Bool {
    isSettingPartOrigin
      || measurementDragState != nil
      || dimensionConstraintDragState != nil
      || freeTextDragState != nil
      || measurementAnnotationSelected
      || freeTextSelected
      || interactionState.hasCancellationTarget(
        draftStartPoint: draftStartPoint,
        draftCurrentPoint: draftCurrentPoint,
        draftArcStartPoint: draftArcStartPoint,
        pendingConstraintTargets: pendingConstraintTargets,
        selectedEntityID: selectedEntityID,
        selectedEntityIDs: selectedEntityIDs,
        selectedConstraintID: selectedConstraintID
      )
  }

  mutating func clearTransientInteraction() {
    interactionState.dragState = nil
    measurementDragState = nil
    dimensionConstraintDragState = nil
    freeTextDragState = nil
    snapIndicatorPoint = nil
    snapSuppressionPoint = nil
    hoveredConstraintTarget = nil
    constraintHoverPoint = nil
    contextMenuModelPoint = nil
    contextMenuFreeTextID = nil
  }
}
