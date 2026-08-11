import Foundation

/// Document naming, layer, parameter, style, and round-hole actions.
extension DocumentActionHandler {
  func updatePendingDocumentNameDraft(_ value: String) {
    documentPresentation.setPendingNameDraft(value == documentName ? nil : value)
  }

  @discardableResult
  func commitPendingDocumentNameDraft(_ explicitValue: String? = nil) -> SyncedTextFieldCommitResult
  {
    let value = explicitValue ?? documentPresentation.pendingNameDraft ?? documentName
    switch CommonFieldValidators.requiredName(value) {
    case .success(let canonicalValue):
      let name = canonicalValue ?? value
      guard renameDocument(to: name) else {
        return .failure(.init(kind: .domain, text: AppStrings.tr("field.error.invalid_value")))
      }
      documentPresentation.setPendingNameDraft(nil)
      return .success(canonicalValue: canonicalValue)
    case .failure(let message):
      return .failure(message)
    }
  }

  @discardableResult
  func commitPendingDocumentNameDraftBeforeDocumentTransition() -> Bool {
    guard documentPresentation.pendingNameDraft != nil else {
      return true
    }
    if case .success = commitPendingDocumentNameDraft() {
      return true
    }
    return false
  }

  /// A replacement operation must not mutate the current document merely to
  /// validate an in-progress title. The replacement itself either succeeds
  /// or leaves the existing document and its draft untouched.
  func hasValidPendingDocumentNameDraft() -> Bool {
    guard let pendingDocumentNameDraft = documentPresentation.pendingNameDraft else {
      return true
    }
    if case .success = CommonFieldValidators.requiredName(pendingDocumentNameDraft) {
      return true
    }
    return false
  }

  func setLayerVisibility(_ layer: ProjectLayer, visible: Bool) {
    let request = commandFactory.makeSetLayerVisibilityCommand(layer, visible: visible)
    executeDocumentCommand(request)
  }

  func setLayerPrintable(_ layer: ProjectLayer, printable: Bool) {
    if printable, layer.kind == .construction {
      statusMessage = AppStrings.tr("status.layer_construction_not_printable", layer.name)
      return
    }
    let request = commandFactory.makeSetLayerPrintableCommand(layer, printable: printable)
    executeDocumentCommand(request)
  }

  @discardableResult
  func setLayerStyle(_ layer: ProjectLayer) -> Bool {
    guard layer.strokeWidthMM > 0, layer.strokeWidthMM.isFinite else {
      statusMessage = AppStrings.tr("status.stroke_width_positive")
      return false
    }
    guard DocumentEditingFeature.isValidHexColor(layer.colorHex) else {
      statusMessage = AppStrings.tr("status.color_hex_required")
      return false
    }
    let request = commandFactory.makeSetLayerStyleCommand(layer)
    return executeDocumentCommand(request)
  }

  func addParameter() {
    let number = parameters.count + 1
    let request = commandFactory.makeAddParameterCommand(number: number)
    executeDocumentCommand(request)
  }

  @discardableResult
  func setParameterValue(_ parameter: ProjectParameter, valueMM: Double) -> Bool {
    guard valueMM >= 0, valueMM.isFinite else {
      statusMessage = AppStrings.tr("status.parameter_name_and_value_required")
      return false
    }
    return executeDocumentCommand(
      commandFactory.makeSetParameterValueCommand(
        parameterID: parameter.id,
        name: parameter.name,
        valueMM: valueMM
      )
    )
  }

  @discardableResult
  func updateParameter(_ parameter: ProjectParameter) -> Bool {
    let trimmedName = parameter.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty,
      parameter.valueMM >= 0
    else {
      statusMessage = AppStrings.tr("status.parameter_name_and_value_required")
      return false
    }
    guard
      !parameters.contains(where: {
        $0.id != parameter.id
          && $0.name.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedName
      })
    else {
      statusMessage = AppStrings.tr("status.parameter_name_must_be_unique")
      return false
    }
    let request = commandFactory.makeUpdateParameterCommand(parameter)
    return executeDocumentCommand(request)
  }

  func deleteParameter(_ parameter: ProjectParameter) {
    let request = commandFactory.makeDeleteParameterCommand(parameter)
    executeDocumentCommand(request)
  }

  func reportUnavailable(_ feature: String) {
    statusMessage = AppStrings.tr("status.feature_not_implemented_yet", feature)
  }

  func addLayer() {
    let number = layers.count + 1
    let request = commandFactory.makeAddLayerCommand(number: number)
    if executeDocumentCommand(request) {
      canvasPresentation.setActiveLayerID(
        (request.payload["payload"] as? [String: Any])?["id"] as? String
          ?? canvasPresentation.activeLayerID)
    }
  }

  func addSharedStyle() {
    let number = sharedStyles.count + 1
    let request = commandFactory.makeAddSharedStyleCommand(number: number)
    _ = executeDocumentCommand(request)
  }

  @discardableResult
  func updateSharedStyle(_ style: ProjectSharedStyle) -> Bool {
    let trimmed = style.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      statusMessage = AppStrings.tr("status.shared_style_name_required")
      return false
    }
    guard style.strokeWidthMM > 0, style.strokeWidthMM.isFinite else {
      statusMessage = AppStrings.tr(
        "status.enter_positive_value", AppStrings.tr("status.line_width"))
      return false
    }
    let request = commandFactory.makeUpdateSharedStyleCommand(style.withName(trimmed))
    return executeDocumentCommand(request)
  }

  func deleteSharedStyle(_ style: ProjectSharedStyle) {
    let request = commandFactory.makeDeleteSharedStyleCommand(style)
    _ = executeDocumentCommand(request)
  }

  func setActiveLayer(_ layerID: String) {
    canvasPresentation.setActiveLayerID(layerID)
    if let layer = layers.first(where: { $0.id == layerID }) {
      statusMessage = AppStrings.tr("status.active_layer_changed", layer.name)
    }
  }

  func setActivePatternLineStyle(_ styleID: String) {
    guard let style = sharedStyles.first(where: { $0.id == styleID }) else {
      statusMessage = AppStrings.tr("status.pattern_line_style_unavailable")
      return
    }
    canvasPresentation.setActivePatternLineStyleID(style.id)
    statusMessage = AppStrings.tr("status.pattern_line_style_changed", style.name)
  }

  func setActiveRoundHoleKind(_ kind: ProjectRoundHoleKind) {
    canvasPresentation.setActiveRoundHole(kind: kind)
    statusMessage = AppStrings.tr("status.round_hole_kind_changed", kind.displayName)
  }

  @discardableResult
  func setActiveRoundHoleDiameter(_ diameterMM: Double) -> Bool {
    guard diameterMM.isFinite, diameterMM > 0 else {
      canvasPresentation.setActiveRoundHoleDiameterInputValid(false)
      statusMessage = AppStrings.tr("status.round_hole_diameter_positive")
      return false
    }
    canvasPresentation.setActiveRoundHole(diameterMM: diameterMM)
    statusMessage = AppStrings.tr(
      "status.round_hole_diameter_changed", String(format: "%.2f", diameterMM))
    return true
  }

  @discardableResult
  func setSelectedRoundHoleKind(_ kind: ProjectRoundHoleKind) -> Bool {
    guard let selectedRoundHole else {
      statusMessage = AppStrings.tr("status.select_round_hole")
      return false
    }
    return executeDocumentCommand(
      commandFactory.makeSetRoundHoleKindCommand(roundHoleID: selectedRoundHole.id, kind: kind)
    )
  }

  @discardableResult
  func setSelectedRoundHoleDiameter(_ diameterMM: Double) -> Bool {
    guard diameterMM.isFinite, diameterMM > 0,
      let selectedRoundHole
    else {
      statusMessage = AppStrings.tr("status.round_hole_diameter_positive")
      return false
    }
    return executeDocumentCommand(
      commandFactory.makeSetRoundHoleDiameterCommand(
        roundHoleID: selectedRoundHole.id,
        diameterMM: diameterMM
      )
    )
  }

  @discardableResult
  func applyActivePatternLineStyleToSelection() -> Bool {
    setSelectedEntitiesSharedStyle(activePatternDrawingStyleID)
  }

  @discardableResult
  func renameDocument(to name: String) -> Bool {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      statusMessage = AppStrings.tr("status.project_name_required")
      return false
    }
    guard trimmed != documentName else {
      return true
    }
    let request = commandFactory.makeRenameDocumentCommand(name: trimmed)
    return executeDocumentCommand(request)
  }

  @discardableResult
  func renameLayer(_ layer: ProjectLayer, name: String) -> Bool {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      statusMessage = AppStrings.tr("status.layer_name_required")
      return false
    }
    guard
      !layers.contains(where: {
        $0.id != layer.id && $0.name.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed
      })
    else {
      statusMessage = AppStrings.tr("status.layer_name_must_be_unique")
      return false
    }
    guard trimmed != layer.name else {
      return true
    }
    let request = commandFactory.makeRenameLayerCommand(layer, name: trimmed)
    return executeDocumentCommand(request)
  }

  func deleteLayer(_ layer: ProjectLayer) {
    guard layers.count > 1 else {
      statusMessage = AppStrings.tr("status.last_layer_cannot_delete")
      return
    }
    let impact: LayerDeletionImpact
    switch cadSession.layerDeletionImpact(layerID: layer.id) {
    case .success(let value): impact = value
    case .failure(let failure):
      presentCoreFailure(failure, operation: "layerDeletionImpact")
      return
    }
    if impact.affectedCount > 0 {
      documentPresentation.setLayerDeletionConfirmation(
        LayerDeletionConfirmation(
          layer: layer,
          entityCount: impact.affectedCount
        ))
      statusMessage = AppStrings.tr("status.layer_delete_confirmation_required", layer.name)
      return
    }
    deleteLayerWithoutConfirmation(layer)
  }

  func confirmLayerDeletion() {
    guard let confirmation = documentPresentation.layerDeletionConfirmation else {
      return
    }
    documentPresentation.setLayerDeletionConfirmation(nil)
    deleteLayerWithoutConfirmation(confirmation.layer)
  }

  func cancelLayerDeletion() {
    guard let confirmation = documentPresentation.layerDeletionConfirmation else {
      return
    }
    documentPresentation.setLayerDeletionConfirmation(nil)
    statusMessage = AppStrings.tr("status.layer_delete_cancelled", confirmation.layer.name)
  }

  private func deleteLayerWithoutConfirmation(_ layer: ProjectLayer) {
    let request = commandFactory.makeDeleteLayerCommand(layer)
    executeDocumentCommand(request)
  }
}
