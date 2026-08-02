import AppKit
import KawaCADOutput
import SwiftUI

/// Canvas selection, tool, viewport, and placement actions.
extension CanvasActionHandler {
  func clearSelection(message: String? = nil) {
    dismissPasteOptions()
    canvasPresentation.clearSelection()
    statusMessage = message ?? canvasPresentation.selectedTool.idleMessage
  }

  func selectConstraint(_ constraintID: String?) {
    canvasPresentation.selectConstraint(constraintID)
    if let constraintID,
      let constraint = constraints.first(where: { $0.id == constraintID })
    {
      statusMessage = AppStrings.tr("status.selected_constraint", constraint.kind)
    } else {
      statusMessage = canvasPresentation.selectedTool.idleMessage
    }
    presentCompactInspectorForSelectionIfNeeded(hasSelection: constraintID != nil)
  }

  func hoverConstraint(_ constraintID: String?) {
    canvasPresentation.setHoveredConstraintID(constraintID)
  }

  func cancelCurrentInteraction() {
    if documentPresentation.pasteOptions != nil {
      dismissPasteOptions()
      statusMessage = canvasPresentation.selectedTool.idleMessage
      return
    }
    if inspectorPresentation.isSettingPartOrigin {
      inspectorPresentation.setIsSettingPartOrigin(false)
      statusMessage = AppStrings.tr("status.part_origin_setting_cancelled")
      return
    }
    if workspaceLayout.compactDrawer != nil {
      workspaceLayout.setCompactDrawer(nil)
      statusMessage = canvasPresentation.selectedTool.idleMessage
      return
    }
    if canvasPresentation.pendingConstraintValueDraft != nil {
      if cancelPendingFilletCollectionStep() {
        return
      }
      cancelPendingConstraintValueEntry()
      return
    }
    if previewEntities != nil || previewCoincidentPointGroups != nil
      || previewCanvasProjection != nil
    {
      cancelMovePreview()
      statusMessage = AppStrings.tr("status.cancelled_drag_preview")
      return
    }
    if canvasPresentation.draftStartPoint != nil || canvasPresentation.draftCurrentPoint != nil
      || canvasPresentation.draftArcStartPoint != nil
    {
      clearPlacementDraft()
      statusMessage = canvasPresentation.selectedTool.idleMessage
      return
    }
    if !canvasPresentation.pendingConstraintTargets.isEmpty {
      if canvasPresentation.selectedTool == .fillet {
        canvasPresentation.removeLastPendingConstraintTarget()
      } else {
        canvasPresentation.setPendingConstraintTargets([])
      }
      statusMessage =
        canvasPresentation.selectedTool.isConstraintTool
          || canvasPresentation.selectedTool.isMeasurementTool
        ? CanvasInteractionFeature.initialConstraintSelectionMessage(
          for: canvasPresentation.selectedTool)
        : canvasPresentation.selectedTool.idleMessage
      return
    }
    if selectedEntityID != nil || !selectedEntityIDs.isEmpty {
      clearSelection(message: AppStrings.tr("status.selection_cleared"))
      return
    }
    if selectedConstraintID != nil || selectedMeasurementAnnotationID != nil
      || selectedFreeTextID != nil
    {
      clearSelection(message: AppStrings.tr("status.selection_cleared"))
      return
    }
    if inspectorPresentation.selectedPartID != nil {
      inspectorPresentation.setSelectedPartID(nil)
      statusMessage = AppStrings.tr("status.part_selection_cleared")
    }
  }

  private func cancelPendingFilletCollectionStep() -> Bool {
    guard let draft = canvasPresentation.pendingConstraintValueDraft,
      draft.kind == "fillet",
      draft.filletUpdateDerivedElementID == nil
    else {
      return false
    }
    var sourceEntityIDs = draft.filletSourceEntityIDs
    guard sourceEntityIDs.count > 1 else {
      canvasPresentation.setPendingConstraintValueDraft(nil)
      canvasPresentation.setEntityIDs([])
      canvasPresentation.setPrimaryEntityID(nil)
      statusMessage = canvasPresentation.selectedTool.idleMessage
      return true
    }
    sourceEntityIDs.removeLast()
    beginFilletValueEntry(
      sourceEntityIDs: sourceEntityIDs,
      initialValueText: draft.valueText,
      lastAddedSourceID: sourceEntityIDs.last
    )
    canvasPresentation.setEntityIDs(Set(sourceEntityIDs))
    canvasPresentation.setPrimaryEntityID(sourceEntityIDs.first)
    return true
  }

  func clearPlacementDraft() {
    canvasPresentation.clearPlacementDraft()
  }

  func setViewMode(_ newMode: CanvasViewMode) {
    guard canvasPresentation.viewMode != newMode else {
      return
    }
    clearTransientCanvasStateForViewModeSwitch()
    outputPresentation.setPreviewBuildResult(nil)
    canvasPresentation.setViewMode(newMode)
    canvasPresentation.setSelectedTool(.select)
    statusMessage =
      newMode == .outputPreview
      ? AppStrings.tr("status.output_preview_mode")
      : AppStrings.tr("status.edit_display_mode")
    reloadFromDocument()
  }

  private func clearTransientCanvasStateForViewModeSwitch() {
    canvasPresentation.setPrimaryEntityID(nil)
    canvasPresentation.setEntityIDs([])
    canvasPresentation.setConstraintID(nil)
    canvasPresentation.setMeasurementAnnotationID(nil)
    canvasPresentation.setHoveredConstraintID(nil)
    canvasPresentation.setPendingConstraintTargets([])
    canvasPresentation.setPendingConstraintValueDraft(nil)
    cadSession.clearCanvasPreview()
    clearPlacementDraft()
  }

  func zoomIn() {
    setCanvasZoomScale(
      canvasPresentation.zoomScale * 1.25, message: AppStrings.tr("status.zoomed_in"))
  }

  func zoomOut() {
    setCanvasZoomScale(
      canvasPresentation.zoomScale / 1.25, message: AppStrings.tr("status.zoomed_out"))
  }

  func zoomToFit() {
    canvasPresentation.setViewport(zoomScale: canvasPresentation.zoomScale, panOffset: .zero)
    setCanvasZoomScale(1.0, message: AppStrings.tr("status.zoom_reset"))
  }

  private func setCanvasZoomScale(_ scale: Double, message: String) {
    canvasPresentation.setViewport(
      zoomScale: min(max(scale, 0.5), 3.0), panOffset: canvasPresentation.panOffset)
    statusMessage = AppStrings.tr(
      "status.zoom_with_percent", message, Int((canvasPresentation.zoomScale * 100).rounded()))
  }

  func panCanvas(by delta: CGSize) {
    guard delta != .zero else {
      return
    }
    canvasPresentation.setViewport(
      zoomScale: canvasPresentation.zoomScale,
      panOffset: CGSize(
        width: canvasPresentation.panOffset.width + delta.width,
        height: canvasPresentation.panOffset.height + delta.height
      ))
  }

  func setCanvasViewport(scale: Double, panOffset: CGSize, message: String) {
    canvasPresentation.setViewport(
      zoomScale: min(max(scale, 0.5), 3.0), panOffset: canvasPresentation.panOffset)
    canvasPresentation.setViewport(zoomScale: canvasPresentation.zoomScale, panOffset: panOffset)
    statusMessage = AppStrings.tr(
      "status.zoom_with_percent", message, Int((canvasPresentation.zoomScale * 100).rounded()))
  }

  func setPointSnapEnabled(_ enabled: Bool) {
    workspacePreferences.setPointSnapEnabled(enabled)
    statusMessage = AppStrings.tr(
      "status.point_snap_enabled",
      enabled ? AppStrings.tr("status.enabled") : AppStrings.tr("status.disabled"))
  }

  func activateTool(_ tool: CanvasTool) {
    dismissPasteOptions()
    let preselectedEntityIDs = selectedEntityIDs
    if canvasPresentation.viewMode == .outputPreview {
      setViewMode(.editDisplay)
    }
    clearPlacementDraft()
    canvasPresentation.setPendingConstraintTargets([])
    canvasPresentation.setPendingConstraintValueDraft(nil)

    if tool.isDetailedTool { setDetailedToolsVisible(true) }
    if workspaceLayout.compactDrawer == .tools {
      workspaceLayout.setCompactDrawer(nil)
    }
    canvasPresentation.setSelectedTool(tool)
    canvasPresentation.setConstraintID(nil)
    canvasPresentation.setMeasurementAnnotationID(nil)
    canvasPresentation.setHoveredConstraintID(nil)
    canvasPresentation.setFreeTextInlineEditRequestID(nil)
    statusMessage = tool.idleMessage
    if tool == .fillet, preselectedEntityIDs.count >= 2 {
      beginFilletValueEntry(sourceEntityIDs: filletSourceEntityIDs(from: preselectedEntityIDs))
      if let draft = canvasPresentation.pendingConstraintValueDraft,
        draft.kind == "fillet"
      {
        canvasPresentation.setEntityIDs(Set(draft.filletSourceEntityIDs))
        canvasPresentation.setPrimaryEntityID(draft.filletSourceEntityIDs.first)
      }
    }
  }

  func selectEntity(_ entityID: String?) {
    dismissPasteOptions()
    if canvasPresentation.selectedTool.isConstraintTool
      || canvasPresentation.selectedTool.isMeasurementTool
    {
      let target = entities.first(where: { $0.id == entityID })?.entitySelectionTarget
      handleConstraintTargetSelection(target)
      return
    }

    guard let entityID else {
      clearSelection()
      return
    }
    canvasPresentation.selectEntity(entityID)
    if let selectedEntity {
      statusMessage = AppStrings.tr("status.selected_entity", selectedEntity.label)
    } else {
      statusMessage = canvasPresentation.selectedTool.idleMessage
    }
    presentCompactInspectorForSelectionIfNeeded(hasSelection: selectedEntityID != nil)
  }

  func toggleEntitySelection(_ entityID: String?) {
    dismissPasteOptions()
    guard let entityID else {
      selectEntity(nil)
      return
    }
    canvasPresentation.toggleEntitySelection(entityID)
    if selectedEntityIDs.isEmpty {
      statusMessage = canvasPresentation.selectedTool.idleMessage
    } else if selectedEntityIDs.count == 1, let selectedEntity {
      statusMessage = AppStrings.tr("status.selected_entity", selectedEntity.label)
    } else {
      statusMessage = AppStrings.tr("status.multiple_entities_selected", selectedEntityIDs.count)
    }
    presentCompactInspectorForSelectionIfNeeded(hasSelection: !selectedEntityIDs.isEmpty)
  }

  func selectEntities(_ entityIDs: Set<String>, extendingSelection: Bool = false) {
    dismissPasteOptions()
    canvasPresentation.selectEntities(
      entityIDs,
      validEntityIDs: Set(entities.map(\.id)),
      extendingSelection: extendingSelection
    )

    if selectedEntityIDs.isEmpty {
      statusMessage = canvasPresentation.selectedTool.idleMessage
    } else if selectedEntityIDs.count == 1, let selectedEntity {
      statusMessage = AppStrings.tr("status.selected_entity", selectedEntity.label)
    } else {
      statusMessage = AppStrings.tr("status.multiple_entities_selected", selectedEntityIDs.count)
    }
    presentCompactInspectorForSelectionIfNeeded(hasSelection: !selectedEntityIDs.isEmpty)
  }

  func selectFreeText(_ freeTextID: String?) {
    canvasPresentation.selectFreeText(freeTextID)
    if let freeTextID,
      let freeText = freeTexts.first(where: { $0.id == freeTextID })
    {
      statusMessage = freeText.content
    } else {
      statusMessage = canvasPresentation.selectedTool.idleMessage
    }
    presentCompactInspectorForSelectionIfNeeded(hasSelection: freeTextID != nil)
  }

  func selectAllEntities() {
    selectEntities(Set(entities.map(\.id)))
  }

  func selectTarget(_ target: CanvasSelectionTarget?) {
    if canvasPresentation.selectedTool.isConstraintTool
      || canvasPresentation.selectedTool.isMeasurementTool
    {
      handleConstraintTargetSelection(target)
      return
    }
    selectEntity(target?.entityID)
  }

  func selectStitchStartPoint(_ stitchStartPointID: String?) {
    canvasPresentation.selectStitchStartPoint(stitchStartPointID)
    statusMessage =
      stitchStartPointID == nil
      ? canvasPresentation.selectedTool.idleMessage
      : AppStrings.tr("status.selected_stitch_start_point")
    presentCompactInspectorForSelectionIfNeeded(hasSelection: stitchStartPointID != nil)
  }

  func handleCanvasPlacement(
    _ point: ModelPoint, modifiers: CanvasPlacementModifiers = CanvasPlacementModifiers()
  ) {
    switch canvasPresentation.selectedTool {
    case .select:
      return

    case .point:
      applyEntityCommand(for: canvasPresentation.selectedTool, start: point, end: point)

    case .freeText:
      addFreeText(at: point)

    case .roundHole:
      applyRoundHoleCommand(center: point)

    case .stitchStartPoint:
      applyStitchStartPointCommand(at: point)

    case .arc:
      guard let center = canvasPresentation.draftStartPoint else {
        canvasPresentation.setDraftStartPoint(point)
        canvasPresentation.setDraftCurrentPoint(point)
        canvasPresentation.setDraftArcStartPoint(nil)
        canvasPresentation.setDraftArcSweepAngle(nil)
        statusMessage = CanvasTool.arc.placementContinuationMessage
        return
      }

      guard let startPoint = canvasPresentation.draftArcStartPoint else {
        guard
          let startPoint = arcPlacementStartPoint(center: center, to: point, modifiers: modifiers)
        else {
          statusMessage = AppStrings.tr("status.arc_start_must_differ_from_center")
          return
        }
        canvasPresentation.setDraftArcStartPoint(startPoint)
        canvasPresentation.setDraftCurrentPoint(startPoint)
        canvasPresentation.setDraftArcSweepAngle(nil)
        statusMessage = AppStrings.tr("status.arc_click_end_point")
        return
      }

      guard
        let placement = arcPlacementEndPoint(
          center: center,
          start: startPoint,
          to: point,
          previousSweepAngleRad: canvasPresentation.draftArcSweepAngleRad,
          modifiers: modifiers
        )
      else {
        statusMessage = AppStrings.tr("status.arc_end_must_differ_angle")
        return
      }
      clearPlacementDraft()
      applyArcEntityCommand(
        center: center,
        start: startPoint,
        end: placement.point,
        sweepReferenceRad: placement.sweepAngleRad
      )

    case .line, .circle, .centerLine, .horizontalCenterLine, .verticalCenterLine:
      guard let start = canvasPresentation.draftStartPoint else {
        let placementPoint =
          canvasPresentation.selectedTool == .line
          ? linePlacementStartPoint(point, modifiers: modifiers) : point
        canvasPresentation.setDraftStartPoint(placementPoint)
        canvasPresentation.setDraftCurrentPoint(placementPoint)
        statusMessage = canvasPresentation.selectedTool.placementContinuationMessage
        return
      }

      clearPlacementDraft()
      if canvasPresentation.selectedTool == .line {
        let assisted = linePlacementEndPoint(from: start, to: point, modifiers: modifiers)
        applyLineEntityCommand(
          start: start,
          end: assisted.point,
          startTarget: linePointTarget(at: start),
          endTarget: assisted.target,
          orientation: assisted.orientation
        )
      } else {
        applyEntityCommand(for: canvasPresentation.selectedTool, start: start, end: point)
      }

    case .offset, .fillet, .coincident, .horizontal, .vertical, .parallel, .perpendicular, .tangent,
      .equalLength, .angle, .symmetric,
      .pointOnLine, .distance, .horizontalDistance, .verticalDistance, .lineLineDistance,
      .segmentLength, .diameter, .radius, .fixed,
      .measureDistance, .measureSegmentLength, .measureAngle, .measureRadius, .measureDiameter,
      .measureArcSweepAngle:
      return
    }
  }

  func handleCanvasHover(
    _ point: ModelPoint, modifiers: CanvasPlacementModifiers = CanvasPlacementModifiers()
  ) {
    guard let start = canvasPresentation.draftStartPoint else {
      return
    }
    if canvasPresentation.selectedTool == .line {
      canvasPresentation.setDraftCurrentPoint(
        linePlacementEndPoint(from: start, to: point, modifiers: modifiers).point)
    } else if canvasPresentation.selectedTool == .arc {
      if let arcStartPoint = canvasPresentation.draftArcStartPoint {
        let placement = arcPlacementEndPoint(
          center: start,
          start: arcStartPoint,
          to: point,
          previousSweepAngleRad: canvasPresentation.draftArcSweepAngleRad,
          modifiers: modifiers
        )
        canvasPresentation.setDraftCurrentPoint(placement?.point)
        if let placement {
          canvasPresentation.setDraftArcSweepAngle(placement.sweepAngleRad)
        }
      } else {
        canvasPresentation.setDraftCurrentPoint(arcPlacementStartPoint(center: start, to: point))
        canvasPresentation.setDraftArcSweepAngle(nil)
      }
    } else {
      canvasPresentation.setDraftCurrentPoint(point)
    }
  }

  func handleCanvasCursor(_ point: ModelPoint?, canvasPoint: CGPoint?) {
    canvasPresentation.setCursor(
      modelPoint: point, canvasPoint: canvasPresentation.cursorCanvasPoint)
    canvasPresentation.setCursor(
      modelPoint: canvasPresentation.cursorModelPoint, canvasPoint: canvasPoint)
  }

  private func presentCompactInspectorForSelectionIfNeeded(hasSelection: Bool) {
    guard hasSelection,
      workspaceLayout.windowLayoutMode == .compact,
      workspacePreferences.inspectorPanelVisible
    else {
      return
    }
    workspaceLayout.setCompactDrawer(.inspector)
  }
}
