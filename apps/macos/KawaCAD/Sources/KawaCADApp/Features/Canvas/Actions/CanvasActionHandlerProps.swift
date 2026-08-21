import KawaCADOutput

extension CanvasActionHandler {
  /// Immutable render input assembled from the current canvas presentation.
  var canvasRenderInput: LeatherCanvasRenderInput {
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

    return LeatherCanvasRenderInput(
      document: LeatherCanvasDocumentDisplay(
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
        coincidentPointGroups: previewCoincidentPointGroups ?? coincidentPointGroups
      ),
      selection: LeatherCanvasSelectionDisplay(
        selectedEntityID: selectedEntityID,
        selectedEntityIDs: selectedEntityIDs,
        selectedConstraintID: selectedConstraintID,
        selectedMeasurementAnnotationID: selectedMeasurementAnnotationID,
        selectedFreeTextID: selectedFreeTextID,
        selectedStitchStartPointID: selectedStitchStartPointID,
        highlightedPartEntityIDs: selectedPartEntityIDs,
        highlightedPartFreeTextIDs: Set(selectedPart?.freeTextIDs ?? []),
        highlightedPartMeasurementAnnotationIDs: Set(
          selectedPart?.measurementAnnotationIDs ?? []
        ),
        highlightedPartStitchStartPointIDs: highlightedPartStitchStartPointIDs(
          for: selectedPart
        ),
        hoveredConstraintID: canvasPresentation.hoveredConstraintID,
        pendingConstraintTargets: canvasPresentation.pendingConstraintTargets
      ),
      draft: LeatherCanvasDraftDisplay(
        filletDraftEntityIDs: Set(
          canvasPresentation.pendingConstraintValueDraft?.kind == "fillet"
            ? canvasPresentation.pendingConstraintValueDraft?.filletSourceEntityIDs ?? []
            : []
        ),
        filletDraftClosed: canvasPresentation.pendingConstraintValueDraft?.kind == "fillet"
          ? canvasPresentation.pendingConstraintValueDraft?.filletClosed
          : nil,
        selectedPartOrigin: selectedPart?.visible == true ? selectedPart?.originMM : nil,
        selectedTool: canvasPresentation.selectedTool,
        draftStartPoint: canvasPresentation.draftStartPoint,
        draftArcStartPoint: canvasPresentation.draftArcStartPoint,
        draftCurrentPoint: canvasPresentation.draftCurrentPoint,
        draftArcSweepAngleRad: canvasPresentation.draftArcSweepAngleRad
      ),
      viewport: LeatherCanvasViewportDisplay(
        viewMode: canvasPresentation.viewMode,
        gridVisible: workspacePreferences.gridVisible,
        a4ReferenceVisible: workspacePreferences.a4ReferenceVisible,
        a4ReferenceOrientation: workspacePreferences.a4ReferenceOrientation,
        gridSnapEnabled: workspacePreferences.gridSnapEnabled,
        pointSnapEnabled: workspacePreferences.pointSnapEnabled,
        outputPreviewModel: outputPresentation.previewBuildResult?.outputDocumentModel,
        zoomScale: canvasPresentation.zoomScale,
        panOffset: canvasPresentation.panOffset
      )
    )
  }

  var canvasInteractionInput: LeatherCanvasInteractionInput {
    LeatherCanvasInteractionInput(
      isSettingPartOrigin: inspectorPresentation.isSettingPartOrigin,
      freeTextInlineEditRequestID: canvasPresentation.freeTextInlineEditRequestID
    )
  }

  private func highlightedPartStitchStartPointIDs(
    for part: ProjectPart?
  ) -> Set<String> {
    guard let part else { return [] }
    let targetIDs = Set(part.entityIDs).union(part.derivedElementIDs)
    return Set(stitchStartPoints.compactMap { targetIDs.contains($0.targetID) ? $0.id : nil })
  }

  var canvasActionGroups: LeatherCanvasActionGroups {
    let bindings = KawaCADUIBindings(handler: actions)
    return LeatherCanvasActionGroups(
      selection: LeatherCanvasSelectionActions(
        selectEntity: bindings.canvas.selectEntity,
        toggleEntitySelection: bindings.canvas.toggleEntitySelection,
        selectEntities: bindings.canvas.selectEntities,
        selectConstraint: bindings.canvas.selectConstraint,
        selectMeasurementAnnotation: bindings.canvas.selectMeasurementAnnotation,
        selectFreeText: bindings.canvas.selectFreeText,
        selectStitchStartPoint: bindings.canvas.selectStitchStartPoint,
        hoverConstraint: bindings.canvas.hoverConstraint,
        selectTarget: bindings.canvas.selectTarget,
        deleteSelection: bindings.menu.deleteSelectedEntity,
        selectAllEntities: bindings.menu.selectAllEntities
      ),
      placement: LeatherCanvasPlacementActions(
        setPartOrigin: actions.parts.setSelectedPartOrigin,
        placePoint: bindings.canvas.handleCanvasPlacement,
        hoverPoint: bindings.canvas.handleCanvasHover,
        cursorPoint: bindings.canvas.handleCanvasCursor
      ),
      move: LeatherCanvasMoveActions(
        previewMoveEntity: bindings.canvas.previewMoveEntity,
        previewMoveEntities: bindings.canvas.previewMoveEntities,
        previewMoveControlPoint: bindings.canvas.previewMoveControlPoint,
        cancelMovePreview: bindings.canvas.cancelMovePreview,
        moveEntity: bindings.canvas.moveEntity,
        moveEntities: bindings.canvas.moveEntities,
        moveControlPoint: bindings.canvas.moveControlPoint,
        moveMeasurementAnnotation: bindings.canvas.moveMeasurementAnnotation,
        moveDimensionConstraintAnnotation: bindings.canvas.moveDimensionConstraintAnnotation
      ),
      viewport: LeatherCanvasViewportActions(
        panCanvas: bindings.canvas.panCanvas,
        setCanvasViewport: bindings.canvas.setCanvasViewport
      ),
      editing: LeatherCanvasEditingActions(
        updateFreeText: bindings.canvas.updateFreeText,
        freeTextInlineEditRequestHandled: { requestID in
          guard self.canvasPresentation.freeTextInlineEditRequestID == requestID else { return }
          self.canvasPresentation.setFreeTextInlineEditRequestID(nil)
        },
        convertMeasurementAnnotationToConstraint: bindings.canvas
          .convertMeasurementAnnotationToConstraint,
        smoothSelectedArcTangenciesPrototype: bindings.menu.smoothSelectedArcTangenciesPrototype,
        cancelInteraction: bindings.menu.cancelCurrentInteraction,
        activateTool: bindings.menu.activateTool,
        copySelection: bindings.menu.copySelection,
        pasteCopiedEntity: bindings.menu.pasteCopiedEntity,
        pasteCopiedEntityAtPoint: bindings.menu.pasteCopiedEntityAtPoint,
        duplicateSelection: bindings.menu.duplicateSelection
      )
    )
  }
}
