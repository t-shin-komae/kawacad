import KawaCADOutput

extension CanvasActionHandler {
  /// Container adapter: derives render-only canvas props from application
  /// state and exposes the existing command boundary as user actions.
  var canvasState: LeatherCanvasState {
    let selectedPart = WorkspaceViewStateFactory.selectedInspectorPart(
      selectedPartID: inspectorPresentation.selectedPartID,
      parts: parts
    )
    let selectedPartEntityIDs = PartFeature.canvasEntityIDs(
      for: selectedPart,
      entities: entities
    )
    let visibleFreeTextIDs = Set(canvasProjection.visibleFreeTextIDs)
    let visibleStitchIDs = Set(
      canvasProjection.stitchStartPoints.filter(\.visible).map(\.id)
    )
    let visibleMeasurementIDs = Set(
      canvasProjection.measurementAnnotations.filter(\.visible).map(\.id)
    )
    return LeatherCanvasState(
      entities: previewEntities ?? entities,
      canvasProjection: canvasProjection,
      constraints: constraints,
      freeTexts: freeTexts.filter { visibleFreeTextIDs.contains($0.id) },
      stitchStartPoints: stitchStartPoints.filter { visibleStitchIDs.contains($0.id) },
      measurementAnnotations: measurementAnnotations.filter {
        visibleMeasurementIDs.contains($0.id)
      },
      measurementEvaluations: measurementEvaluations,
      dimensionConstraintAnnotations: dimensionConstraintAnnotations,
      parameters: parameters,
      derivedElements: derivedElements,
      layers: layers,
      sharedStyles: sharedStyles,
      coincidentPointGroups: previewCoincidentPointGroups ?? coincidentPointGroups,
      selectedEntityID: selectedEntityID,
      selectedEntityIDs: selectedEntityIDs,
      filletDraftEntityIDs: Set(
        canvasPresentation.pendingConstraintValueDraft?.kind == "fillet"
          ? canvasPresentation.pendingConstraintValueDraft?.filletSourceEntityIDs ?? []
          : []
      ),
      filletDraftClosed: canvasPresentation.pendingConstraintValueDraft?.kind == "fillet"
        ? canvasPresentation.pendingConstraintValueDraft?.filletClosed
        : nil,
      selectedConstraintID: selectedConstraintID,
      selectedMeasurementAnnotationID: selectedMeasurementAnnotationID,
      selectedFreeTextID: selectedFreeTextID,
      selectedStitchStartPointID: selectedStitchStartPointID,
      selectedPartOrigin: selectedPart?.visible == true ? selectedPart?.originMM : nil,
      highlightedPartEntityIDs: selectedPartEntityIDs,
      highlightedPartFreeTextIDs: Set(selectedPart?.freeTextIDs ?? []),
      highlightedPartMeasurementAnnotationIDs: Set(
        selectedPart?.measurementAnnotationIDs ?? []
      ),
      highlightedPartStitchStartPointIDs: highlightedPartStitchStartPointIDs(
        for: selectedPart
      ),
      isSettingPartOrigin: inspectorPresentation.isSettingPartOrigin,
      freeTextInlineEditRequestID: canvasPresentation.freeTextInlineEditRequestID,
      hoveredConstraintID: canvasPresentation.hoveredConstraintID,
      pendingConstraintTargets: canvasPresentation.pendingConstraintTargets,
      viewMode: canvasPresentation.viewMode,
      selectedTool: canvasPresentation.selectedTool,
      draftStartPoint: canvasPresentation.draftStartPoint,
      draftArcStartPoint: canvasPresentation.draftArcStartPoint,
      draftCurrentPoint: canvasPresentation.draftCurrentPoint,
      draftArcSweepAngleRad: canvasPresentation.draftArcSweepAngleRad,
      gridVisible: workspacePreferences.gridVisible,
      a4ReferenceVisible: workspacePreferences.a4ReferenceVisible,
      a4ReferenceOrientation: workspacePreferences.a4ReferenceOrientation,
      gridSnapEnabled: workspacePreferences.gridSnapEnabled,
      pointSnapEnabled: workspacePreferences.pointSnapEnabled,
      outputPreviewModel: outputPresentation.previewBuildResult?.outputDocumentModel,
      zoomScale: canvasPresentation.zoomScale,
      panOffset: canvasPresentation.panOffset
    )
  }

  private func highlightedPartStitchStartPointIDs(
    for part: ProjectPart?
  ) -> Set<String> {
    guard let part else { return [] }
    let targetIDs = Set(part.entityIDs).union(part.derivedElementIDs)
    return Set(stitchStartPoints.compactMap { targetIDs.contains($0.targetID) ? $0.id : nil })
  }

  var canvasActions: LeatherCanvasActions {
    let bindings = KawaCADUIBindings(handler: actions)
    return LeatherCanvasActions(
      selectEntity: bindings.canvas.selectEntity,
      toggleEntitySelection: bindings.canvas.toggleEntitySelection,
      selectEntities: bindings.canvas.selectEntities,
      selectConstraint: bindings.canvas.selectConstraint,
      selectMeasurementAnnotation: bindings.canvas.selectMeasurementAnnotation,
      selectFreeText: bindings.canvas.selectFreeText,
      selectStitchStartPoint: bindings.canvas.selectStitchStartPoint,
      setPartOrigin: actions.parts.setSelectedPartOrigin,
      updateFreeText: bindings.canvas.updateFreeText,
      freeTextInlineEditRequestHandled: { requestID in
        guard self.canvasPresentation.freeTextInlineEditRequestID == requestID else { return }
        self.canvasPresentation.setFreeTextInlineEditRequestID(nil)
      },
      hoverConstraint: bindings.canvas.hoverConstraint,
      selectTarget: bindings.canvas.selectTarget,
      placePoint: bindings.canvas.handleCanvasPlacement,
      hoverPoint: bindings.canvas.handleCanvasHover,
      cursorPoint: bindings.canvas.handleCanvasCursor,
      previewMoveEntity: bindings.canvas.previewMoveEntity,
      previewMoveEntities: bindings.canvas.previewMoveEntities,
      previewMoveControlPoint: bindings.canvas.previewMoveControlPoint,
      cancelMovePreview: bindings.canvas.cancelMovePreview,
      moveEntity: bindings.canvas.moveEntity,
      moveEntities: bindings.canvas.moveEntities,
      moveControlPoint: bindings.canvas.moveControlPoint,
      moveMeasurementAnnotation: bindings.canvas.moveMeasurementAnnotation,
      moveDimensionConstraintAnnotation: bindings.canvas.moveDimensionConstraintAnnotation,
      convertMeasurementAnnotationToConstraint: bindings.canvas
        .convertMeasurementAnnotationToConstraint,
      smoothSelectedArcTangenciesPrototype: bindings.menu.smoothSelectedArcTangenciesPrototype,
      cancelInteraction: bindings.menu.cancelCurrentInteraction,
      activateTool: bindings.menu.activateTool,
      deleteSelection: bindings.menu.deleteSelectedEntity,
      panCanvas: bindings.canvas.panCanvas,
      setCanvasViewport: bindings.canvas.setCanvasViewport,
      copySelection: bindings.menu.copySelection,
      pasteCopiedEntity: bindings.menu.pasteCopiedEntity,
      pasteCopiedEntityAtPoint: bindings.menu.pasteCopiedEntityAtPoint,
      duplicateSelection: bindings.menu.duplicateSelection,
      selectAllEntities: bindings.menu.selectAllEntities
    )
  }
}
