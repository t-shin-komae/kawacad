import Foundation

/// Constraint value-entry draft and commit actions.
extension ConstraintActionHandler {
  func beginConstraintValueEntry(
    kind: String,
    title: String,
    prompt: String,
    targets: [[String: Any]],
    initialValueMM: Double
  ) {
    beginConstraintValueEntry(
      kind: kind,
      title: title,
      prompt: prompt,
      targets: targets,
      initialValue: initialValueMM,
      unit: "mm"
    )
  }

  func beginConstraintValueEntry(
    kind: String,
    title: String,
    prompt: String,
    targets: [[String: Any]],
    initialValue: Double,
    unit: String
  ) {
    canvasPresentation.setPendingConstraintValueDraft(
      PendingConstraintValueDraft(
        kind: kind,
        title: title,
        prompt: prompt,
        targets: targets,
        valueText: InspectorValueFormatting.format(initialValue),
        unit: unit,
        allowsParameterReference: kind != "angle",
        entryMode: .fixedValue,
        selectedParameterID: parameters.first?.id,
        anchorCanvasPoint: canvasPresentation.cursorCanvasPoint
      ))
    statusMessage = CanvasInteractionFeature.constraintValueEntryStatusMessage(
      title: title,
      allowsParameterReference: kind != "angle",
      hasParameters: !parameters.isEmpty
    )
  }

  func updatePendingConstraintValueText(_ valueText: String) {
    guard var draft = canvasPresentation.pendingConstraintValueDraft else {
      return
    }
    draft.valueText = valueText
    canvasPresentation.setPendingConstraintValueDraft(draft)
  }

  func updatePendingConstraintEntryMode(_ mode: ConstraintValueEntryMode) {
    guard var draft = canvasPresentation.pendingConstraintValueDraft else {
      return
    }
    if mode == .parameterReference,
      !draft.allowsParameterReference || parameters.isEmpty
    {
      return
    }
    draft.entryMode = mode
    if mode == .parameterReference, draft.selectedParameterID == nil {
      draft.selectedParameterID = parameters.first?.id
    }
    canvasPresentation.setPendingConstraintValueDraft(draft)
    statusMessage =
      mode == .fixedValue
      ? AppStrings.tr("status.enter_fixed_value", draft.title)
      : AppStrings.tr("status.select_parameter_for_constraint", draft.title)
  }

  func updatePendingConstraintParameterID(_ parameterID: String) {
    guard var draft = canvasPresentation.pendingConstraintValueDraft else {
      return
    }
    draft.selectedParameterID = parameterID
    canvasPresentation.setPendingConstraintValueDraft(draft)
    statusMessage = AppStrings.tr("status.select_parameter_for_constraint", draft.title)
  }

  func cancelPendingConstraintValueEntry() {
    canvasPresentation.setPendingConstraintValueDraft(nil)
    statusMessage = canvasPresentation.selectedTool.idleMessage
  }

  func commitPendingConstraintValueEntry() {
    guard let draft = canvasPresentation.pendingConstraintValueDraft else {
      return
    }
    let valuePayload: [String: Any]
    if draft.entryMode == .parameterReference {
      guard draft.allowsParameterReference else {
        statusMessage = AppStrings.tr("status.fixed_value_required", draft.title)
        return
      }
      guard let parameterID = draft.selectedParameterID,
        parameters.contains(where: { $0.id == parameterID })
      else {
        statusMessage = AppStrings.tr("status.select_parameter_reference")
        return
      }
      valuePayload = ["parameter": parameterID]
    } else {
      guard let value = Double(draft.valueText),
        draft.kind == "angle" ? value.isFinite : value > 0
      else {
        statusMessage =
          draft.kind == "angle"
          ? AppStrings.tr("status.enter_finite_angle_value", draft.title)
          : AppStrings.tr("status.enter_positive_value", draft.title)
        return
      }
      valuePayload =
        draft.kind == "angle"
        ? ["fixedDegrees": value]
        : ["fixedMm": value]
    }
    if commitPendingDerivedElementValueEntry(draft: draft, valuePayload: valuePayload) {
      return
    }
    let request = commandFactory.makeAddConstraintCommand(
      kind: draft.kind,
      displayName: draft.title,
      targets: draft.targets,
      value: valuePayload
    )
    let success = executeDocumentCommand(request)
    if success {
      canvasPresentation.setPendingConstraintValueDraft(nil)
    }
  }

}
