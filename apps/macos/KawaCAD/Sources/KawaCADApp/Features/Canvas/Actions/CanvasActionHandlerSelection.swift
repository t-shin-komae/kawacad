import Foundation

/// Selection deletion, annotation, and constraint editing actions.
extension CanvasActionHandler {
  func addFreeText(at positionMM: ModelPoint) {
    let freeText = ProjectFreeText(
      id: "free-text:\(commandFactory.uuidProvider())",
      content: AppStrings.tr("app.annotation"),
      positionMM: positionMM,
      fontSizeMM: 4.0
    )
    if executeDocumentCommand(commandFactory.makeAddFreeTextCommand(freeText)) {
      canvasPresentation.setFreeTextID(freeText.id)
      canvasPresentation.setFreeTextInlineEditRequestID(freeText.id)
      canvasPresentation.setPrimaryEntityID(nil)
      canvasPresentation.setEntityIDs([])
      canvasPresentation.setConstraintID(nil)
      canvasPresentation.setMeasurementAnnotationID(nil)
    }
  }

  @discardableResult
  func updateFreeText(_ freeText: ProjectFreeText) -> Bool {
    guard !freeText.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      freeText.positionMM.xMM.isFinite,
      freeText.positionMM.yMM.isFinite,
      freeText.fontSizeMM.isFinite,
      freeText.fontSizeMM > 0
    else {
      statusMessage = AppStrings.tr("status.free_text_invalid")
      return false
    }
    return executeDocumentCommand(commandFactory.makeUpdateFreeTextCommand(freeText))
  }

  func deleteSelectedFreeText() {
    guard let selectedFreeTextID = canvasPresentation.selectedFreeTextID else {
      return
    }
    if executeDocumentCommand(commandFactory.makeDeleteFreeTextCommand(id: selectedFreeTextID)) {
      self.selectedFreeTextID = nil
      canvasPresentation.setFreeTextInlineEditRequestID(nil)
    }
  }

  func deleteSelectedStitchStartPoint() {
    guard let selectedStitchStartPointID = canvasPresentation.selectedStitchStartPointID else {
      return
    }
    if executeDocumentCommand(
      commandFactory.makeDeleteStitchStartPointCommand(id: selectedStitchStartPointID))
    {
      self.selectedStitchStartPointID = nil
    }
  }

  func deleteSelectedEntity() {
    dismissPasteOptions()
    if selectedStitchStartPointID != nil {
      deleteSelectedStitchStartPoint()
      return
    }

    if selectedFreeTextID != nil {
      deleteSelectedFreeText()
      return
    }

    if let selectedMeasurementAnnotationID = canvasPresentation.selectedMeasurementAnnotationID,
      let annotation = measurementAnnotations.first(where: {
        $0.id == selectedMeasurementAnnotationID
      })
    {
      deleteMeasurementAnnotation(annotation)
      return
    }

    if let selectedConstraintID = canvasPresentation.selectedConstraintID,
      let constraint = constraints.first(where: { $0.id == selectedConstraintID })
    {
      deleteConstraint(constraint)
      return
    }

    let selectedDerivedElement = WorkspaceViewStateFactory.selectedDerivedElement(
      selectedEntities: selectedEntities,
      derivedElements: derivedElements
    )
    if let selectedDerivedElement {
      deleteDerivedElement(selectedDerivedElement)
      canvasPresentation.setPrimaryEntityID(nil)
      canvasPresentation.setEntityIDs([])
      return
    }

    let ids = selectedEntities.map(\.id)
    guard !ids.isEmpty else {
      statusMessage = AppStrings.tr("status.select_entity_to_delete")
      return
    }
    let requests = ids.map { id in
      commandFactory.makeDeleteEntityCommand(
        id: id,
        successMessage: AppStrings.tr("status.deleted_selected_entities")
      )
    }
    let request: DocumentCommandRequest?
    if requests.count == 1 {
      request = requests.first
    } else {
      request = commandFactory.makeCompoundCommand(
        requests,
        successMessage: AppStrings.tr("status.deleted_selected_entities")
      )
    }
    guard let request, executeDocumentCommand(request) else {
      return
    }
    canvasPresentation.setPrimaryEntityID(nil)
    canvasPresentation.setEntityIDs([])
  }

  func deleteConstraint(_ constraint: ProjectConstraint) {
    let request = commandFactory.makeDeleteConstraintCommand(constraint)
    if executeDocumentCommand(request) {
      canvasPresentation.setConstraintID(nil)
      canvasPresentation.setHoveredConstraintID(nil)
    }
  }

  func deleteMeasurementAnnotation(_ annotation: ProjectMeasurementAnnotation) {
    let request = commandFactory.makeDeleteMeasurementAnnotationCommand(annotation)
    if executeDocumentCommand(request) {
      canvasPresentation.setMeasurementAnnotationID(nil)
    }
  }

  func selectMeasurementAnnotation(_ annotationID: String?) {
    canvasPresentation.setPrimaryEntityID(nil)
    canvasPresentation.setEntityIDs([])
    canvasPresentation.setConstraintID(nil)
    canvasPresentation.setMeasurementAnnotationID(annotationID)
    if let annotationID,
      let annotation = measurementAnnotations.first(where: { $0.id == annotationID })
    {
      statusMessage = AppStrings.tr("status.selected_measurement_annotation", annotation.kind)
    } else {
      statusMessage = canvasPresentation.selectedTool.idleMessage
    }
    if annotationID != nil,
      workspaceLayout.windowLayoutMode == .compact,
      workspacePreferences.inspectorPanelVisible
    {
      workspaceLayout.setCompactDrawer(.inspector)
    }
  }

  func moveMeasurementAnnotation(id: String, delta: ModelPoint, labelOnly: Bool) {
    executeDocumentCommand(
      DocumentCommandRequest(
        payload: CoreDocumentCommand(
          kind: .moveMeasurementAnnotation,
          payload: .object([
            "annotationId": .string(id),
            "delta": .object(["xMm": .number(delta.xMM), "yMm": .number(delta.yMM)]),
            "labelOnly": .bool(labelOnly),
          ])), successMessage: AppStrings.tr("command.entity_updated", id)))
  }

  func moveDimensionConstraintAnnotation(constraintID: String, delta: ModelPoint, labelOnly: Bool) {
    guard constraints.contains(where: { $0.id == constraintID && $0.isDimensionConstraint }) else {
      return
    }
    executeDocumentCommand(
      DocumentCommandRequest(
        payload: CoreDocumentCommand(
          kind: .moveDimensionConstraintAnnotation,
          payload: .object([
            "constraintId": .string(constraintID),
            "delta": .object(["xMm": .number(delta.xMM), "yMm": .number(delta.yMM)]),
            "labelOnly": .bool(labelOnly),
          ])), successMessage: AppStrings.tr("command.entity_updated", constraintID)))
  }

  func convertMeasurementAnnotationToConstraint(id: String) {
    guard measurementAnnotations.contains(where: { $0.id == id }) else {
      statusMessage = AppStrings.tr("status.measurement_annotation_convert_failed")
      return
    }
    let request = commandFactory.makeConvertMeasurementCommand(
      annotationID: id,
      constraintID: "constraint:measurement-\(UUID().uuidString.lowercased())"
    )
    if executeDocumentCommand(request) {
      canvasPresentation.setMeasurementAnnotationID(nil)
    }
  }

  func selectCreatedItems() {
    guard let created = currentDocumentState?.mutation?.created else {
      return
    }
    let createdEntityIDs = Set(created.entityIDs)
    let createdDerivedElementIDs = Set(created.derivedElementIDs)
    let copiedEntityIDs =
      entities
      .filter {
        createdEntityIDs.contains($0.id)
          || $0.derivedElementID.map(createdDerivedElementIDs.contains) == true
      }
      .map(\.id)
    canvasPresentation.setEntityIDs(Set(copiedEntityIDs))
    canvasPresentation.setPrimaryEntityID(copiedEntityIDs.last)
    canvasPresentation.setConstraintID(nil)
    canvasPresentation.setMeasurementAnnotationID(nil)
    canvasPresentation.setHoveredConstraintID(nil)
    canvasPresentation.setFreeTextID(created.freeTextIDs.last)
    canvasPresentation.setStitchStartPointID(created.stitchStartPointIDs.last)
    canvasPresentation.setFreeTextInlineEditRequestID(nil)
  }

  @discardableResult
  func setConstraintValue(_ constraint: ProjectConstraint, valueMM: Double) -> Bool {
    if constraint.rawKind == "angle" {
      guard valueMM.isFinite else {
        statusMessage = AppStrings.tr("status.constraint_angle_requires_finite_degrees")
        return false
      }
    } else {
      guard valueMM > 0 else {
        statusMessage = AppStrings.tr("status.constraint_dimension_requires_positive")
        return false
      }
    }

    guard
      let request = commandFactory.makeUpdateConstraintValueCommand(constraint, valueMM: valueMM)
    else {
      statusMessage = AppStrings.tr("status.constraint_targets_restore_failed")
      return false
    }
    return executeDocumentCommand(request)
  }

  @discardableResult
  func setConstraintDegrees(_ constraint: ProjectConstraint, valueDegrees: Double) -> Bool {
    guard valueDegrees.isFinite else {
      statusMessage = AppStrings.tr("status.constraint_angle_requires_finite_degrees")
      return false
    }
    guard
      let request = commandFactory.makeUpdateConstraintValueCommand(
        constraint, valueMM: valueDegrees)
    else {
      statusMessage = AppStrings.tr("status.constraint_targets_restore_failed")
      return false
    }
    return executeDocumentCommand(request)
  }

  @discardableResult
  func setConstraintParameter(_ constraint: ProjectConstraint, parameter: ProjectParameter) -> Bool
  {
    guard constraint.rawKind != "angle" else {
      statusMessage = AppStrings.tr("status.angle_constraint_requires_fixed_degrees")
      return false
    }
    guard
      let request = commandFactory.makeUpdateConstraintParameterCommand(
        constraint,
        parameter: parameter
      )
    else {
      statusMessage = AppStrings.tr("status.constraint_targets_restore_failed")
      return false
    }
    return executeDocumentCommand(request)
  }

}
