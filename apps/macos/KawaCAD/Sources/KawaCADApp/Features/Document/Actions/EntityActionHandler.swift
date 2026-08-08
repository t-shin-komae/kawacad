import Foundation

/// History, entity, derived-element, and control-point editing actions.
extension DocumentActionHandler {
  func undo() {
    switch cadSession.undo(viewMode: canvasPresentation.viewMode) {
    case .success:
      canvasPresentation.setPrimaryEntityID(nil)
      canvasPresentation.setPendingConstraintTargets([])
      canvasPresentation.setPendingConstraintValueDraft(nil)
      clearPlacementDraft()
      statusMessage = AppStrings.tr("status.undo")
    case .failure(let message):
      coreStatus = .unavailable(message.localizedDescription)
      presentCoreFailure(message, operation: "undo")
    }
  }

  func redo() {
    switch cadSession.redo(viewMode: canvasPresentation.viewMode) {
    case .success:
      canvasPresentation.setPrimaryEntityID(nil)
      canvasPresentation.setPendingConstraintTargets([])
      canvasPresentation.setPendingConstraintValueDraft(nil)
      clearPlacementDraft()
      statusMessage = AppStrings.tr("status.redo")
    case .failure(let message):
      coreStatus = .unavailable(message.localizedDescription)
      presentCoreFailure(message, operation: "redo")
    }
  }

  func setSelectedEntityLayer(_ layerID: String) {
    let selectedDerivedElement = WorkspaceViewStateFactory.selectedDerivedElement(
      selectedEntities: selectedEntities,
      derivedElements: derivedElements
    )
    if let selectedDerivedElement {
      executeDocumentCommand(
        commandFactory.makeSetDerivedLayerCommand(
          derivedElementID: selectedDerivedElement.id, layerID: layerID))
      return
    }
    guard let selectedEntity else {
      return
    }
    executeDocumentCommand(
      commandFactory.makeSetEntityLayerCommand(entityID: selectedEntity.id, layerID: layerID))
  }

  @discardableResult
  func setSelectedEntitiesSharedStyle(_ styleID: String?) -> Bool {
    var requests =
      selectedEntities
      .filter { $0.derivedElementID == nil }
      .map { commandFactory.makeSetEntitySharedStyleCommand(entityID: $0.id, styleID: styleID) }

    let derivedElementIDs = Array(Set(selectedEntities.compactMap(\.derivedElementID))).sorted()
    requests.append(
      contentsOf: derivedElementIDs.map {
        commandFactory.makeSetDerivedSharedStyleCommand(derivedElementID: $0, styleID: styleID)
      })

    guard !requests.isEmpty else {
      statusMessage = AppStrings.tr("status.shared_style_entity_required")
      return false
    }
    guard requests.count > 1,
      let compound = commandFactory.makeCompoundCommand(
        requests,
        successMessage: AppStrings.tr("command.entity_shared_style_updated")
      )
    else {
      return executeDocumentCommand(requests[0])
    }
    return executeDocumentCommand(compound)
  }

  @discardableResult
  func setDerivedElementDistance(_ derivedElement: ProjectDerivedElement, valueMM: Double) -> Bool {
    guard valueMM > 0, valueMM.isFinite else {
      statusMessage = AppStrings.tr("status.enter_positive_value", "オフセット距離")
      return false
    }
    let request =
      derivedElement.kind == .fillet
      ? commandFactory.makeSetDerivedRadiusCommand(
        derivedElementID: derivedElement.id,
        value: .object(["fixedMm": .number(valueMM)])
      )
      : commandFactory.makeSetDerivedDistanceCommand(
        derivedElementID: derivedElement.id,
        value: .object(["fixedMm": .number(valueMM)])
      )
    return executeDocumentCommand(request)
  }

  @discardableResult
  func setDerivedElementParameter(
    _ derivedElement: ProjectDerivedElement, parameter: ProjectParameter
  ) -> Bool {
    let value = CoreJSONValue.object(["parameter": .string(parameter.id)])
    let request =
      derivedElement.kind == .fillet
      ? commandFactory.makeSetDerivedRadiusCommand(
        derivedElementID: derivedElement.id,
        value: value
      )
      : commandFactory.makeSetDerivedDistanceCommand(
        derivedElementID: derivedElement.id,
        value: value
      )
    return executeDocumentCommand(request)
  }

  @discardableResult
  func setDerivedElementDirection(
    _ derivedElement: ProjectDerivedElement, direction: OffsetDirection
  ) -> Bool {
    executeDocumentCommand(
      commandFactory.makeSetDerivedDirectionCommand(
        derivedElementID: derivedElement.id,
        direction: direction
      )
    )
  }

  @discardableResult
  func reverseDerivedElementDirection(_ derivedElement: ProjectDerivedElement) -> Bool {
    setDerivedElementDirection(derivedElement, direction: derivedElement.direction.reversed)
  }

  func deleteDerivedElement(_ derivedElement: ProjectDerivedElement) {
    let request = commandFactory.makeDeleteDerivedElementCommand(derivedElement)
    executeDocumentCommand(request)
  }

  @discardableResult
  func setSelectedLineLength(_ lengthMM: Double) -> Bool {
    guard lengthMM > 0,
      let selectedEntity,
      case .line = selectedEntity.geometry
    else {
      statusMessage = AppStrings.tr("status.line_length_requires_positive")
      return false
    }
    return executeDocumentCommand(
      commandFactory.makeSetSegmentLengthCommand(
        entityID: selectedEntity.id,
        valueMM: lengthMM
      )
    )
  }

  func constrainSelectedLineLength() {
    guard let selectedEntity,
      case .line = selectedEntity.geometry
    else {
      statusMessage = AppStrings.tr("status.select_line_for_segment_length_constraint")
      return
    }
    applyConstraintUsingCoreInitialValue(
      kind: "segmentLength",
      targets: [["entity": selectedEntity.id]]
    )
  }

  func constrainSelectedLineLengthsEqual() {
    let targets = selectedLineTargetsForEqualLength()
    guard targets.count == 2 else {
      statusMessage = AppStrings.tr("status.select_two_lines_for_equal_length")
      return
    }
    applyConstraint(
      kind: "equalSegmentLength",
      targets: targets.map(\.constraintJSON)
    )
  }

  @discardableResult
  func setSelectedCircleRadius(_ radiusMM: Double) -> Bool {
    guard radiusMM > 0,
      let selectedEntity,
      case .circle = selectedEntity.geometry
    else {
      statusMessage = AppStrings.tr("status.radius_requires_positive")
      return false
    }
    return executeDocumentCommand(
      commandFactory.makeSetCircleRadiusCommand(
        entityID: selectedEntity.id,
        valueMM: radiusMM
      )
    )
  }

  @discardableResult
  func setSelectedArc(radiusMM: Double, sweepAngleRad: Double) -> Bool {
    guard let selectedEntity,
      case .arc(_, _, let startAngleRad, _) = selectedEntity.geometry
    else {
      statusMessage = AppStrings.tr("status.select_arc")
      return false
    }
    return setSelectedArc(
      radiusMM: radiusMM, startAngleRad: startAngleRad, sweepAngleRad: sweepAngleRad)
  }

  @discardableResult
  func setSelectedArc(radiusMM: Double, startAngleRad: Double, sweepAngleRad: Double) -> Bool {
    guard radiusMM > 0, sweepAngleRad != 0,
      let selectedEntity,
      case .arc = selectedEntity.geometry
    else {
      statusMessage = AppStrings.tr("status.arc_requires_positive_radius_and_sweep")
      return false
    }
    guard
      case .arc(_, let currentRadius, let currentStart, let currentSweep) = selectedEntity.geometry
    else { return false }
    return executeDocumentCommand(
      commandFactory.makeSetArcCommand(
        entityID: selectedEntity.id,
        radiusMM: radiusMM == currentRadius ? nil : radiusMM,
        startAngleRad: startAngleRad == currentStart ? nil : startAngleRad,
        sweepAngleRad: sweepAngleRad == currentSweep ? nil : sweepAngleRad
      )
    )
  }

  func moveEntity(_ entityID: String, delta: ModelPoint) {
    moveEntities([entityID], delta: delta, duplicating: false)
  }

  func moveEntities(_ entityIDs: Set<String>, delta: ModelPoint, duplicating: Bool) {
    guard abs(delta.xMM) > 0.0001 || abs(delta.yMM) > 0.0001 else {
      cancelMovePreview()
      return
    }
    if let part = partContainingDraggedEntities(entityIDs) {
      cancelMovePreview()
      if duplicating {
        duplicatePart(part, delta: delta)
      } else {
        _ = movePart(part, delta: delta)
      }
      return
    }
    if !duplicating {
      let message = DocumentEditingFeature.moveCompletionMessage(
        entities: entities.filter { entityIDs.contains($0.id) },
        duplicating: false
      )
      guard
        let request = commandFactory.makeMoveEntitiesCommand(
          entityIDs: entityIDs,
          delta: delta,
          allowSingleLineStretch: true,
          successMessage: message
        )
      else {
        cancelMovePreview()
        statusMessage = AppStrings.tr("status.selection_drag_not_supported")
        return
      }
      if executeDocumentCommand(request, reportsFailure: false) {
        canvasPresentation.setEntityIDs(entityIDs)
        canvasPresentation.setPrimaryEntityID(entityIDs.sorted().last)
        statusMessage = message
        return
      }
      let failureMessage = AppStrings.tr("status.selection_drag_not_supported")
      statusMessage = failureMessage
      presentInvalidDragError(failureMessage)
      return
    }
    let selection = DocumentEditingFeature.selectionReference(
      entityIDs: entityIDs,
      entities: entities
    )
    let message = AppStrings.tr("status.clipboard_items_duplicated", selection.rootCount)
    let request = commandFactory.makeDuplicateSelectionCommand(
      selection: selection,
      dxMM: delta.xMM,
      dyMM: delta.yMM,
      successMessage: message
    )
    guard executeDocumentCommand(request, reportsFailure: false) else {
      let message = AppStrings.tr("status.selection_drag_not_supported")
      statusMessage = message
      presentInvalidDragError(message)
      return
    }
    selectCreatedItems()
    statusMessage = message
  }

  func previewMoveEntity(_ entityID: String, delta: ModelPoint) {
    previewMoveEntities([entityID], delta: delta, duplicating: false)
  }

  func previewMoveEntities(_ entityIDs: Set<String>, delta: ModelPoint, duplicating: Bool) {
    guard abs(delta.xMM) > 0.0001 || abs(delta.yMM) > 0.0001 else {
      cancelMovePreview()
      return
    }
    if let part = partContainingDraggedEntities(entityIDs) {
      let request =
        duplicating
        ? commandFactory.makeDuplicatePartCommand(
          part,
          newName: DocumentEditingFeature.uniqueCopyName(
            sourceName: part.name,
            existingNames: Set(parts.map(\.name))
          ),
          delta: delta
        ).request
        : commandFactory.makeMovePartCommand(part, delta: delta)
      switch cadSession.previewCommand(request.payload, viewMode: canvasPresentation.viewMode) {
      case .success:
        statusMessage = AppStrings.tr(
          duplicating ? "status.preview_duplicate_drag" : "status.preview_move")
      case .failure(let message):
        statusMessage = message.localizedDescription
      }
      return
    }
    if !duplicating {
      guard
        let request = commandFactory.makeMoveEntitiesCommand(
          entityIDs: entityIDs,
          delta: delta,
          allowSingleLineStretch: true,
          successMessage: AppStrings.tr("status.preview_move")
        )
      else {
        cancelMovePreview()
        let message = AppStrings.tr("status.selection_drag_not_supported")
        statusMessage = message
        presentInvalidDragError(message)
        return
      }
      switch cadSession.previewCommand(request.payload, viewMode: canvasPresentation.viewMode) {
      case .success:
        statusMessage = AppStrings.tr("status.preview_move")
      case .failure(let message):
        statusMessage = message.localizedDescription
        presentInvalidDragError(message.localizedDescription)
      }
      return
    }
    let selection = DocumentEditingFeature.selectionReference(
      entityIDs: entityIDs,
      entities: entities
    )
    let request = commandFactory.makeDuplicateSelectionCommand(
      selection: selection,
      dxMM: delta.xMM,
      dyMM: delta.yMM,
      successMessage: AppStrings.tr("status.preview_duplicate_drag")
    )
    switch cadSession.previewCommand(request.payload, viewMode: canvasPresentation.viewMode) {
    case .success:
      statusMessage = AppStrings.tr("status.preview_duplicate_drag")
    case .failure(let message):
      statusMessage = message.localizedDescription
      presentInvalidDragError(message.localizedDescription)
    }
  }

  private func partContainingDraggedEntities(_ entityIDs: Set<String>) -> ProjectPart? {
    let candidates = parts.filter { part in
      let partEntityIDs = PartFeature.canvasEntityIDs(for: part, entities: entities)
      return !entityIDs.isEmpty && entityIDs.isSubset(of: partEntityIDs)
    }
    guard candidates.count == 1 else { return nil }
    return candidates[0]
  }

  private func executeDocumentCommand(
    _ request: DocumentCommandRequest,
    reportsFailure: Bool
  ) -> Bool {
    switch cadSession.execute(request, viewMode: canvasPresentation.viewMode) {
    case .success(_, let successMessage):
      statusMessage = successMessage
      return true
    case .failure(let message):
      guard reportsFailure else {
        return false
      }
      coreStatus = .unavailable(message.localizedDescription)
      presentCoreFailure(message, operation: "applyMove")
      return false
    }
  }

  func moveControlPoint(_ target: CanvasSelectionTarget, to point: ModelPoint) {
    if let request = makeFilletRadiusHandleUpdateCommand(target: target, point: point) {
      _ = executeDocumentCommand(request, reportsFailure: true)
      return
    }
    guard target.controlPoint != nil,
      let request = commandFactory.makeMoveControlPointCommand(
        target: target,
        position: point,
        allowProjection: true
      )
    else {
      cancelMovePreview()
      let message = AppStrings.tr("status.control_point_drag_target_missing")
      statusMessage = message
      presentInvalidDragError(message)
      return
    }
    _ = executeDocumentCommand(request, reportsFailure: true)
  }

  func previewMoveControlPoint(_ target: CanvasSelectionTarget, to point: ModelPoint) {
    if let request = makeFilletRadiusHandleUpdateCommand(target: target, point: point) {
      previewDocumentCommand(request, message: AppStrings.tr("status.preview"))
      return
    }
    guard
      let request = commandFactory.makeMoveControlPointCommand(
        target: target,
        position: point,
        allowProjection: true
      )
    else {
      cancelMovePreview()
      let message = AppStrings.tr("status.control_point_drag_not_supported_yet", target.entityLabel)
      statusMessage = message
      presentInvalidDragError(message)
      return
    }
    switch cadSession.previewCommand(request.payload, viewMode: canvasPresentation.viewMode) {
    case .success:
      statusMessage = AppStrings.tr("status.preview")
    case .failure(let message):
      statusMessage = message.localizedDescription
      presentInvalidDragError(message.localizedDescription)
    }
  }

  private func makeFilletRadiusHandleUpdateCommand(
    target: CanvasSelectionTarget,
    point: ModelPoint
  ) -> DocumentCommandRequest? {
    guard target.controlPoint == .radius,
      let source = entities.first(where: { $0.id == target.entityID }),
      let derivedElementID = source.derivedElementID,
      let resolvedIndex = source.derivedResolvedIndex
    else {
      return nil
    }
    return commandFactory.makeSetDerivedRadiusFromPointCommand(
      derivedElementID: derivedElementID,
      resolvedIndex: resolvedIndex,
      position: point
    )
  }

  func cancelMovePreview() {
    cadSession.clearCanvasPreview()
  }

  @discardableResult
  private func previewDocumentCommand(
    _ request: DocumentCommandRequest,
    message: String,
    reportsFailure: Bool = true
  ) -> Bool {
    switch cadSession.previewCommand(request.payload, viewMode: canvasPresentation.viewMode) {
    case .success:
      statusMessage = message
      return true
    case .failure(let message):
      guard reportsFailure else {
        return false
      }
      statusMessage = message.localizedDescription
      presentInvalidDragError(message.localizedDescription)
      return false
    }
  }

}
