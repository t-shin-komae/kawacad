import Foundation

/// Copy, paste, and duplicate actions.
extension DocumentActionHandler {
  func copySelection() {
    guard hasClipboardSelection else {
      statusMessage = AppStrings.tr("status.select_items_to_copy")
      return
    }
    switch cadSession.exportSelection(
      DocumentEditingFeature.selectionReference(
        entityIDs: selectedClipboardEntities.map(\.id),
        derivedElementIDs: selectedDerivedRootIDs,
        constraintID: selectedConstraintID,
        measurementAnnotationID: selectedMeasurementAnnotationID,
        stitchStartPointID: selectedStitchStartPointID,
        freeTextID: selectedFreeTextID
      ))
    {
    case .success(let export):
      documentPresentation.setClipboardBundle(ClipboardBundle(export: export))
      documentPresentation.setPasteOptions(nil)
      documentPresentation.resetPasteTracking()
      statusMessage = AppStrings.tr("status.clipboard_items_copied", export.rootCount)
    case .failure(let failure):
      presentCoreFailure(failure, operation: "exportSelection")
    }
  }

  func pasteCopiedEntity() {
    pasteCopiedEntity(preferredPoint: canvasPresentation.cursorModelPoint)
  }

  func pasteCopiedEntity(at point: ModelPoint) {
    pasteCopiedEntity(preferredPoint: point)
  }

  func selectPastePlacement(_ mode: PastePlacementMode) {
    guard let presentation = documentPresentation.pasteOptions else { return }
    guard presentation.activeMode != mode else {
      documentPresentation.setPasteOptions(nil)
      return
    }
    guard case .success = cadSession.undo(viewMode: canvasPresentation.viewMode) else {
      statusMessage = AppStrings.tr("status.paste_option_replace_failed")
      return
    }
    let target = mode == .cursor ? presentation.cursorPoint : presentation.nearSourcePoint
    guard let target else {
      _ = cadSession.redo(viewMode: canvasPresentation.viewMode)
      statusMessage = AppStrings.tr("status.copied_entity_cannot_paste_at_position")
      return
    }
    guard
      performPaste(
        clipboard: presentation.clipboard,
        sourceAnchor: presentation.sourceAnchor,
        target: target,
        mode: mode,
        pasteNamespace: presentation.pasteNamespace,
        cursorPoint: presentation.cursorPoint,
        canvasPoint: presentation.canvasPoint,
        nearSourcePoint: presentation.nearSourcePoint
      )
    else {
      _ = cadSession.redo(viewMode: canvasPresentation.viewMode)
      statusMessage = AppStrings.tr("status.paste_option_replace_failed")
      return
    }
  }

  func dismissPasteOptions() {
    documentPresentation.setPasteOptions(nil)
  }

  private func pasteCopiedEntity(preferredPoint: ModelPoint?) {
    guard let clipboardBundle = documentPresentation.clipboardBundle,
      !clipboardBundle.isEmpty
    else {
      statusMessage = AppStrings.tr("status.nothing_to_paste")
      return
    }
    guard let sourceAnchor = clipboardBundle.anchorPoint else {
      pasteNearSource(clipboard: clipboardBundle, sourceAnchor: nil, preferredPoint: preferredPoint)
      return
    }
    if let preferredPoint,
      DocumentEditingFeature.canPasteAtCursor(
        preferredPoint,
        sourceAnchor: sourceAnchor,
        sourceBounds: clipboardBundle.bounds,
        lastPasteCursorPoint: documentPresentation.lastPasteCursorPoint
      )
    {
      _ = performPaste(
        clipboard: clipboardBundle,
        sourceAnchor: sourceAnchor,
        target: preferredPoint,
        mode: .cursor,
        pasteNamespace: nil,
        cursorPoint: preferredPoint,
        canvasPoint: canvasPresentation.cursorCanvasPoint,
        nearSourcePoint: sourceAnchor.translatedBy(dxMM: 5, dyMM: 5)
      )
      return
    }
    pasteNearSource(
      clipboard: clipboardBundle, sourceAnchor: sourceAnchor, preferredPoint: preferredPoint)
  }

  private func pasteNearSource(
    clipboard: ClipboardBundle, sourceAnchor: ModelPoint?, preferredPoint: ModelPoint?
  ) {
    let sequence = documentPresentation.clipboardPasteSequence + 1
    let target: ModelPoint
    if let preferredPoint,
      let lastPasteCursorPoint = documentPresentation.lastPasteCursorPoint,
      DocumentEditingFeature.pointsApproximatelyEqual(preferredPoint, lastPasteCursorPoint),
      let lastPastePlacementPoint = documentPresentation.lastPastePlacementPoint
    {
      target = lastPastePlacementPoint.translatedBy(dxMM: 5, dyMM: 5)
    } else if let sourceAnchor {
      target = sourceAnchor.translatedBy(dxMM: Double(sequence * 5), dyMM: Double(sequence * 5))
    } else {
      target = ModelPoint(xMM: Double(sequence * 5), yMM: Double(sequence * 5))
    }
    guard
      performPaste(
        clipboard: clipboard,
        sourceAnchor: sourceAnchor,
        target: target,
        mode: .nearSource,
        pasteNamespace: nil,
        cursorPoint: preferredPoint,
        canvasPoint: canvasPresentation.cursorCanvasPoint,
        nearSourcePoint: sourceAnchor?.translatedBy(dxMM: 5, dyMM: 5) ?? target
      )
    else { return }
    documentPresentation.advancePasteSequence(to: sequence)
  }

  @discardableResult
  private func performPaste(
    clipboard: ClipboardBundle,
    sourceAnchor: ModelPoint?,
    target: ModelPoint,
    mode: PastePlacementMode,
    pasteNamespace: String?,
    cursorPoint: ModelPoint?,
    canvasPoint: CGPoint?,
    nearSourcePoint: ModelPoint
  ) -> Bool {
    let source = sourceAnchor ?? ModelPoint(xMM: 0, yMM: 0)
    let namespace = pasteNamespace ?? UUID().uuidString.lowercased()
    let request = commandFactory.makePasteSelectionCommand(
      clipboardJSON: clipboard.clipboardJSON,
      dxMM: target.xMM - source.xMM,
      dyMM: target.yMM - source.yMM,
      idNamespace: namespace,
      successMessage: AppStrings.tr("status.clipboard_items_pasted", clipboard.rootCount)
    )
    guard executeDocumentCommand(request) else { return false }
    selectCreatedItems()
    documentPresentation.recordPastePlacement(
      cursorPoint: cursorPoint,
      placementPoint: target
    )
    if let sourceAnchor {
      documentPresentation.setPasteOptions(
        PasteOptionsPresentation(
          clipboard: clipboard,
          sourceAnchor: sourceAnchor,
          pasteNamespace: namespace,
          cursorPoint: cursorPoint,
          canvasPoint: canvasPoint,
          nearSourcePoint: nearSourcePoint,
          activeMode: mode
        ))
    } else {
      documentPresentation.setPasteOptions(nil)
    }
    statusMessage =
      mode == .cursor
      ? AppStrings.tr(
        "status.clipboard_items_pasted_at_cursor_coordinate", clipboard.rootCount, target.xMM,
        target.yMM)
      : AppStrings.tr(
        "status.clipboard_items_pasted_near_source", clipboard.rootCount,
        abs(target.xMM - source.xMM))
    return true
  }

  func duplicateSelection() {
    dismissPasteOptions()
    guard hasClipboardSelection else {
      statusMessage = AppStrings.tr("status.select_items_to_duplicate")
      return
    }
    let selection = DocumentEditingFeature.selectionReference(
      entityIDs: selectedClipboardEntities.map(\.id),
      derivedElementIDs: selectedDerivedRootIDs,
      constraintID: selectedConstraintID,
      measurementAnnotationID: selectedMeasurementAnnotationID,
      stitchStartPointID: selectedStitchStartPointID,
      freeTextID: selectedFreeTextID
    )
    let rootCount = selection.rootCount
    let request = commandFactory.makeDuplicateSelectionCommand(
      selection: selection,
      dxMM: 5.0,
      dyMM: 5.0,
      successMessage: AppStrings.tr("status.clipboard_items_duplicated", rootCount)
    )
    guard executeDocumentCommand(request) else {
      return
    }
    selectCreatedItems()
    statusMessage = AppStrings.tr("status.clipboard_items_duplicated", rootCount)
  }

}
