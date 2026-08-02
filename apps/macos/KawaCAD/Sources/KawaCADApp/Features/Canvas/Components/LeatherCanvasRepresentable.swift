import SwiftUI

struct LeatherCanvasRepresentable: NSViewRepresentable {
  let state: LeatherCanvasState
  let actions: LeatherCanvasActions

  func makeNSView(context: Context) -> LeatherCanvasView {
    let view = LeatherCanvasView()
    configure(view)
    return view
  }

  func updateNSView(_ nsView: LeatherCanvasView, context: Context) {
    configure(nsView)
    nsView.reconcileInlineFreeTextEditorState()
    nsView.syncInlineFreeTextEditorWithRequest()
    nsView.refreshAccessibilityState()
    nsView.needsDisplay = true
  }

  private func configure(_ view: LeatherCanvasView) {
    view.onSelectEntity = actions.selectEntity
    view.onSelectEntities = actions.selectEntities
    view.onSelectConstraint = actions.selectConstraint
    view.onSelectMeasurementAnnotation = actions.selectMeasurementAnnotation
    view.onSelectFreeText = actions.selectFreeText
    view.onSelectStitchStartPoint = actions.selectStitchStartPoint
    view.onSetPartOrigin = actions.setPartOrigin
    view.onUpdateFreeText = actions.updateFreeText
    view.onFreeTextInlineEditRequestHandled = actions.freeTextInlineEditRequestHandled
    view.onHoverConstraint = actions.hoverConstraint
    view.onSelectTarget = actions.selectTarget
    view.onPlacePoint = actions.placePoint
    view.onHoverPoint = actions.hoverPoint
    view.onCursorPoint = actions.cursorPoint
    view.onPreviewMoveEntity = actions.previewMoveEntity
    view.onPreviewMoveEntities = actions.previewMoveEntities
    view.onPreviewMoveControlPoint = actions.previewMoveControlPoint
    view.onCancelMovePreview = actions.cancelMovePreview
    view.entities = state.entities
    view.canvasProjection = state.canvasProjection
    view.documentConstraints = state.constraints
    view.freeTexts = state.freeTexts
    view.stitchStartPoints = state.stitchStartPoints
    view.measurementAnnotations = state.measurementAnnotations
    view.measurementEvaluations = state.measurementEvaluations
    view.dimensionConstraintAnnotations = state.dimensionConstraintAnnotations
    view.parameters = state.parameters
    view.derivedElements = state.derivedElements
    view.layers = state.layers
    view.sharedStyles = state.sharedStyles
    view.coincidentPointGroups = state.coincidentPointGroups
    view.selectedEntityID = state.selectedEntityID
    view.selectedEntityIDs = state.selectedEntityIDs
    view.filletDraftEntityIDs = state.filletDraftEntityIDs
    view.filletDraftClosed = state.filletDraftClosed
    view.selectedConstraintID = state.selectedConstraintID
    view.selectedMeasurementAnnotationID = state.selectedMeasurementAnnotationID
    view.selectedFreeTextID = state.selectedFreeTextID
    view.selectedStitchStartPointID = state.selectedStitchStartPointID
    view.selectedPartOrigin = state.selectedPartOrigin
    view.highlightedPartEntityIDs = state.highlightedPartEntityIDs
    view.highlightedPartFreeTextIDs = state.highlightedPartFreeTextIDs
    view.highlightedPartMeasurementAnnotationIDs = state.highlightedPartMeasurementAnnotationIDs
    view.highlightedPartStitchStartPointIDs = state.highlightedPartStitchStartPointIDs
    view.isSettingPartOrigin = state.isSettingPartOrigin
    view.freeTextInlineEditRequestID = state.freeTextInlineEditRequestID
    view.hoveredConstraintID = state.hoveredConstraintID
    view.pendingConstraintTargets = state.pendingConstraintTargets
    view.viewMode = state.viewMode
    view.selectedTool = state.selectedTool
    view.draftStartPoint = state.draftStartPoint
    view.draftArcStartPoint = state.draftArcStartPoint
    view.draftCurrentPoint = state.draftCurrentPoint
    view.draftArcSweepAngleRad = state.draftArcSweepAngleRad
    view.gridVisible = state.gridVisible
    view.a4ReferenceVisible = state.a4ReferenceVisible
    view.a4ReferenceOrientation = state.a4ReferenceOrientation
    view.gridSnapEnabled = state.gridSnapEnabled
    view.pointSnapEnabled = state.pointSnapEnabled
    view.outputPreviewModel = state.outputPreviewModel
    view.zoomScale = state.zoomScale
    view.panOffset = state.panOffset
    view.onMoveEntity = actions.moveEntity
    view.onMoveEntities = actions.moveEntities
    view.onMoveControlPoint = actions.moveControlPoint
    view.onMoveMeasurementAnnotation = actions.moveMeasurementAnnotation
    view.onMoveDimensionConstraintAnnotation = actions.moveDimensionConstraintAnnotation
    view.onConvertMeasurementAnnotationToConstraint =
      actions.convertMeasurementAnnotationToConstraint
    view.onSmoothSelectedArcTangenciesPrototype = actions.smoothSelectedArcTangenciesPrototype
    view.onToggleEntitySelection = actions.toggleEntitySelection
    view.onCancelInteraction = actions.cancelInteraction
    view.onActivateTool = actions.activateTool
    view.onDeleteSelection = actions.deleteSelection
    view.onPanCanvas = actions.panCanvas
    view.onSetCanvasViewport = actions.setCanvasViewport
    view.onCopySelection = actions.copySelection
    view.onPasteCopiedEntity = actions.pasteCopiedEntity
    view.onPasteCopiedEntityAtPoint = actions.pasteCopiedEntityAtPoint
    view.onDuplicateSelection = actions.duplicateSelection
    view.onSelectAllEntities = actions.selectAllEntities
  }
}
