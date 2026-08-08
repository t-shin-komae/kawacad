import Foundation

/// Document command execution and session-state synchronization actions.
extension DocumentActionHandler {
  @discardableResult
  func updateEntity(_ entity: CanvasEntity) -> Bool {
    guard let request = commandFactory.makeUpdateEntityCommand(entity) else {
      if let derivedElementID = entity.derivedElementID,
        let derivedElement = derivedElements.first(where: {
          $0.id == derivedElementID && $0.kind == .fillet
        }),
        case .arc(_, let radiusMM, _, _) = entity.geometry
      {
        return setDerivedElementDistance(derivedElement, valueMM: radiusMM)
      }
      presentAlert(AppStrings.tr("status.entity_update_not_supported_yet", entity.label))
      return false
    }
    return executeDocumentCommand(request)
  }

  @discardableResult
  func executeDocumentCommand(_ request: DocumentCommandRequest) -> Bool {
    switch cadSession.execute(request, viewMode: canvasPresentation.viewMode) {
    case .success(_, let successMessage):
      statusMessage = successMessage
      return true
    case .failure(let message):
      coreStatus = .unavailable(message.localizedDescription)
      presentCoreFailure(
        message,
        operation: "executeDocumentCommand",
        commandKind: request.payload.kind.rawValue
      )
      return false
    }
  }

  func presentAlert(_ message: String) {
    statusMessage = message
    documentPresentation.setAlertMessage(UserAlertMessage(message: message))
  }

  func applyDocumentState(_ state: LeatherDocumentState) {
    cadSession.applyState(state)
  }

  func clearDocumentState() {
    cadSession.clearState()
  }

  func handleCadSessionStateChange(_ state: LeatherDocumentState?) {
    syncDocumentRecoveryState()
    guard let state else {
      outputPresentation.setPreviewBuildResult(nil)
      canvasPresentation.setConstraintID(nil)
      canvasPresentation.setMeasurementAnnotationID(nil)
      canvasPresentation.setFreeTextID(nil)
      canvasPresentation.setStitchStartPointID(nil)
      canvasPresentation.setFreeTextInlineEditRequestID(nil)
      canvasPresentation.setHoveredConstraintID(nil)
      return
    }
    let printOrientationChanged = actions.workspace.syncPrintOrientation(state.printOrientation)
    if !layers.contains(where: { $0.id == canvasPresentation.activeLayerID }) {
      canvasPresentation.setActiveLayerID(
        layers.first(where: { $0.id == "layer:cut-line" })?.id
          ?? layers.first?.id
          ?? "layer:cut-line"
      )
    }
    if !sharedStyles.contains(where: { $0.id == canvasPresentation.activePatternLineStyleID }) {
      canvasPresentation.setActivePatternLineStyleID(
        sharedStyles.first(where: { $0.id == Self.defaultPatternLineStyleID })?.id
          ?? sharedStyles.first?.id
          ?? Self.defaultPatternLineStyleID
      )
    }
    if let selectedEntityID = canvasPresentation.selectedEntityID,
      !entities.contains(where: { $0.id == selectedEntityID })
    {
      self.selectedEntityID = nil
    }
    canvasPresentation.setEntityIDs(
      selectedEntityIDs.filter { id in
        entities.contains(where: { $0.id == id })
      })
    if let selectedConstraintID = canvasPresentation.selectedConstraintID,
      !constraints.contains(where: { $0.id == selectedConstraintID })
    {
      self.selectedConstraintID = nil
    }
    if let selectedMeasurementAnnotationID = canvasPresentation.selectedMeasurementAnnotationID,
      !measurementAnnotations.contains(where: { $0.id == selectedMeasurementAnnotationID })
    {
      self.selectedMeasurementAnnotationID = nil
    }
    if let selectedFreeTextID = canvasPresentation.selectedFreeTextID,
      !freeTexts.contains(where: { $0.id == selectedFreeTextID })
    {
      self.selectedFreeTextID = nil
      canvasPresentation.setFreeTextInlineEditRequestID(nil)
    }
    if let selectedStitchStartPointID = canvasPresentation.selectedStitchStartPointID,
      !stitchStartPoints.contains(where: { $0.id == selectedStitchStartPointID })
    {
      self.selectedStitchStartPointID = nil
    }
    if let hoveredConstraintID = canvasPresentation.hoveredConstraintID,
      !constraints.contains(where: { $0.id == hoveredConstraintID })
    {
      canvasPresentation.setHoveredConstraintID(nil)
    }
    if let warning = state.warnings.first {
      statusMessage = warning
      presentAlert(warning)
    }
    if outputPresentation.requestDraft != nil {
      outputPresentation.scheduleBuild(session: cadSession)
    }
    if printOrientationChanged, canvasPresentation.viewMode == .outputPreview {
      refreshOutputPreviewBuildResult()
    }
  }
}
