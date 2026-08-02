import Foundation

extension ConstraintActionHandler {
  func offsetSourceOptions(
    for entity: CanvasEntity,
    selectedSourceIDs: Set<String>,
    clickPoint: ModelPoint?
  ) -> [OffsetSourceScopeOption] {
    switch cadSession.preflightDerivedElement(
      kind: .offsetCurve,
      hitEntityID: entity.id,
      selectedEntityIDs: selectedSourceIDs.sorted(),
      clickPoint: clickPoint
    ) {
    case .success(let result):
      return result.offsetOptions.compactMap { option in
        guard let scope = OffsetSourceScope(rawValue: option.scope) else { return nil }
        return OffsetSourceScopeOption(
          scope: scope,
          sourceEntityIDs: option.sourceEntityIds,
          sourceResolvedEntityIDs: option.sourceResolvedEntityIds ?? [],
          direction: option.direction
        )
      }
    case .failure(let failure):
      presentCoreFailure(failure, operation: "preflightDerivedElement")
      return []
    }
  }

  func filletSourceEntityIDs(from targets: [CanvasSelectionTarget]) -> [String] {
    DerivedElementFeature.uniqueEntityIDs(targets.map(\.entityID))
  }

  func filletSourceEntityIDs(from selectedSourceIDs: Set<String>) -> [String] {
    DerivedElementFeature.uniqueEntityIDs(selectedSourceIDs.sorted())
  }

  func beginOffsetValueEntry(
    sourceEntityIDs: [String],
    sourceResolvedEntityIDs: [String] = [],
    direction: String,
    scopeOptions: [OffsetSourceScopeOption] = []
  ) {
    var draft = PendingConstraintValueDraft(
      kind: "offsetCurve",
      title: CanvasTool.offset.displayName,
      prompt: AppStrings.tr("status.specify_offset"),
      targets: [],
      valueText: "",
      unit: "mm",
      allowsParameterReference: true,
      entryMode: .fixedValue,
      selectedParameterID: parameters.first?.id,
      anchorCanvasPoint: canvasPresentation.cursorCanvasPoint
    )
    draft.offsetSourceEntityIDs = sourceEntityIDs
    draft.offsetSourceResolvedEntityIDs = sourceResolvedEntityIDs
    draft.offsetDirection = direction
    draft.offsetSourceScopeOptions = scopeOptions
    draft.selectedOffsetSourceScope = scopeOptions.first?.scope
    canvasPresentation.setPendingConstraintValueDraft(draft)
    statusMessage = CanvasInteractionFeature.constraintValueEntryStatusMessage(
      title: draft.title,
      allowsParameterReference: true,
      hasParameters: !parameters.isEmpty
    )
  }

  func beginFilletValueEntry(
    sourceEntityIDs: [String],
    closed: Bool = false,
    initialValueText: String = "",
    lastAddedSourceID: String? = nil
  ) {
    let sourceEntityIDs = DerivedElementFeature.uniqueEntityIDs(sourceEntityIDs)
    guard sourceEntityIDs.count >= 2 else {
      installFilletDraft(
        sourceEntityIDs: sourceEntityIDs,
        updateDerivedElementID: nil,
        closed: closed,
        initialValueText: initialValueText,
        lastAddedSourceID: lastAddedSourceID
      )
      return
    }
    switch cadSession.preflightDerivedElement(
      kind: .fillet,
      hitEntityID: nil,
      selectedEntityIDs: sourceEntityIDs,
      clickPoint: nil
    ) {
    case .success(let result):
      installFilletDraft(
        sourceEntityIDs: result.sourceEntityIds,
        updateDerivedElementID: result.updateDerivedElementId,
        closed: result.closed,
        initialValueText: initialValueText,
        lastAddedSourceID: lastAddedSourceID
      )
    case .failure(let failure):
      presentCoreFailure(failure, operation: "preflightDerivedElement")
    }
  }

  func beginFilletValueEntry(derivedElement: ProjectDerivedElement) {
    installFilletDraft(
      sourceEntityIDs: derivedElement.sourceEntityIDs,
      updateDerivedElementID: derivedElement.id,
      closed: derivedElement.filletClosed,
      initialValueText: derivedElement.radiusMM.map { String(format: "%.2f", $0) } ?? "",
      lastAddedSourceID: nil
    )
    if let parameterID = derivedElement.radiusParameterID {
      canvasPresentation.updatePendingConstraintValueDraft {
        $0.entryMode = .parameterReference
        $0.selectedParameterID = parameterID
      }
    }
  }

  private func installFilletDraft(
    sourceEntityIDs: [String],
    updateDerivedElementID: String?,
    closed: Bool,
    initialValueText: String,
    lastAddedSourceID: String?
  ) {
    var draft = PendingConstraintValueDraft(
      kind: "fillet",
      title: CanvasTool.fillet.displayName,
      prompt: AppStrings.tr("status.specify_fillet_radius"),
      targets: [],
      valueText: initialValueText,
      unit: "mm",
      allowsParameterReference: true,
      entryMode: .fixedValue,
      selectedParameterID: parameters.first?.id,
      anchorCanvasPoint: canvasPresentation.cursorCanvasPoint
    )
    draft.filletSourceEntityIDs = sourceEntityIDs
    draft.filletUpdateDerivedElementID = updateDerivedElementID
    draft.filletClosed = closed
    draft.filletLastAddedSourceID = lastAddedSourceID
    canvasPresentation.setPendingConstraintValueDraft(draft)
    statusMessage =
      draft.filletIsReadyForValueEntry
      ? AppStrings.tr(
        "status.fillet_draft_ready",
        draft.filletSourceEntityIDs.count,
        draft.filletCornerCount,
        draft.filletClosed
          ? AppStrings.tr("fillet.draft.closed") : AppStrings.tr("fillet.draft.open")
      )
      : AppStrings.tr("status.fillet_draft_collecting", draft.filletSourceEntityIDs.count)
  }

  func updatePendingOffsetSourceScope(_ scope: OffsetSourceScope) {
    guard var draft = canvasPresentation.pendingConstraintValueDraft,
      let option = draft.offsetSourceScopeOptions.first(where: { $0.scope == scope })
    else { return }
    draft.selectedOffsetSourceScope = scope
    draft.offsetSourceEntityIDs = option.sourceEntityIDs
    draft.offsetSourceResolvedEntityIDs = option.sourceResolvedEntityIDs
    draft.offsetDirection = option.direction
    canvasPresentation.setPendingConstraintValueDraft(draft)
  }

  func commitPendingDerivedElementValueEntry(
    draft: PendingConstraintValueDraft,
    valuePayload: [String: Any]
  ) -> Bool {
    if draft.kind == "offsetCurve" {
      guard !draft.offsetSourceEntityIDs.isEmpty else {
        statusMessage = AppStrings.tr("status.offset_source_required")
        return true
      }
      let success = executeDocumentCommand(
        commandFactory.makeAddOffsetCurveCommand(
          sourceEntityIDs: draft.offsetSourceEntityIDs,
          sourceResolvedEntityIDs: draft.offsetSourceResolvedEntityIDs,
          distance: valuePayload,
          direction: draft.offsetDirection ?? "left",
          layerID: canvasPresentation.activeLayerID,
          styleID: drawingSharedStyleID(for: .offset)
        ))
      if success { canvasPresentation.setPendingConstraintValueDraft(nil) }
      return true
    }
    if draft.kind == "fillet" {
      guard draft.filletSourceEntityIDs.count >= 2 else {
        statusMessage = AppStrings.tr("status.fillet_source_required")
        return true
      }
      let request: DocumentCommandRequest
      if let updateID = draft.filletUpdateDerivedElementID,
        let existing = derivedElements.first(where: { $0.id == updateID && $0.kind == .fillet })
      {
        if existing.sourceEntityIDs == draft.filletSourceEntityIDs,
          existing.filletClosed == draft.filletClosed
        {
          request = commandFactory.makeSetDerivedRadiusCommand(
            derivedElementID: existing.id,
            value: try! CoreJSONValue(any: valuePayload)
          )
        } else {
          let sources = commandFactory.makeSetFilletSourcesCommand(
            derivedElementID: existing.id,
            sourceEntityIDs: draft.filletSourceEntityIDs,
            closed: draft.filletClosed
          )
          let radius = commandFactory.makeSetDerivedRadiusCommand(
            derivedElementID: existing.id,
            value: try! CoreJSONValue(any: valuePayload)
          )
          request = commandFactory.makeCompoundCommand(
            [sources, radius],
            successMessage: AppStrings.tr(
              "command.derived_element_updated", existing.kind.displayName)
          )!
        }
      } else {
        request = commandFactory.makeAddFilletCommand(
          sourceEntityIDs: draft.filletSourceEntityIDs,
          radius: valuePayload,
          layerID: canvasPresentation.activeLayerID,
          closed: draft.filletClosed
        )
      }
      let success = executeDocumentCommand(request)
      if success { canvasPresentation.setPendingConstraintValueDraft(nil) }
      return true
    }
    return false
  }
}
