import Foundation

/// Entity drawing and placement normalization actions.
extension CanvasActionHandler {
  private static let linePointSnapToleranceMM = 2.0
  private static let gridSpacingMM = 5.0
  private static let arcAngleSnapStepRad = Double.pi / 12.0

  func applyEntityCommand(for tool: CanvasTool, start: ModelPoint, end: ModelPoint) {
    guard cadSession.hasDocument else {
      statusMessage = AppStrings.tr("status.document_disconnected")
      return
    }
    guard
      let prepared = commandFactory.makeAddEntityCommand(
        tool: tool,
        start: start,
        end: end,
        layerID: activeDrawingLayerID(for: tool),
        styleID: drawingSharedStyleID(for: tool)
      )
    else {
      return
    }
    executeDocumentCommand(prepared.request)
  }

  func applyArcEntityCommand(
    center: ModelPoint,
    start: ModelPoint,
    end: ModelPoint,
    sweepReferenceRad: Double
  ) {
    guard cadSession.hasDocument else {
      statusMessage = AppStrings.tr("status.document_disconnected")
      return
    }
    guard
      let request = commandFactory.makeAddArcEntityCommand(
        center: center,
        start: start,
        end: end,
        sweepReferenceRad: sweepReferenceRad,
        layerID: activeDrawingLayerID(for: .arc),
        styleID: drawingSharedStyleID(for: .arc)
      )
    else {
      statusMessage = AppStrings.tr("status.arc_requires_distinct_start_and_sweep")
      return
    }
    let success = executeDocumentCommand(request)
    guard success, let createdEntityID = currentDocumentState?.mutation?.created.entityIDs.last
    else {
      return
    }
    canvasPresentation.setPrimaryEntityID(createdEntityID)
    canvasPresentation.setEntityIDs([createdEntityID])
    statusMessage = AppStrings.tr("status.arc_added_with_edit_hint")
  }

  func applyRoundHoleCommand(center: ModelPoint) {
    guard cadSession.hasDocument else {
      statusMessage = AppStrings.tr("status.document_disconnected")
      return
    }
    guard canvasPresentation.activeRoundHoleDiameterInputValid,
      canvasPresentation.activeRoundHoleDiameterMM.isFinite,
      canvasPresentation.activeRoundHoleDiameterMM > 0
    else {
      statusMessage = AppStrings.tr("status.round_hole_diameter_positive")
      return
    }
    guard
      let request = commandFactory.makeAddRoundHoleCommand(
        center: center,
        diameterMM: canvasPresentation.activeRoundHoleDiameterMM,
        kind: canvasPresentation.activeRoundHoleKind,
        layerID: activeDrawingLayerID(for: .roundHole),
        styleID: drawingSharedStyleID(for: .roundHole)
      )
    else {
      statusMessage = AppStrings.tr("status.round_hole_diameter_positive")
      return
    }
    let success = executeDocumentCommand(request)
    guard success, let createdEntityID = currentDocumentState?.mutation?.created.entityIDs.last
    else {
      return
    }
    canvasPresentation.setPrimaryEntityID(createdEntityID)
    canvasPresentation.setEntityIDs([createdEntityID])
  }

  func applyStitchStartPointCommand(at point: ModelPoint) {
    guard cadSession.hasDocument else {
      statusMessage = AppStrings.tr("status.document_disconnected")
      return
    }
    let id = "stitch-start:\(commandFactory.uuidProvider())"
    if executeDocumentCommand(
      commandFactory.makePlaceStitchStartPointCommand(id: id, position: point))
    {
      canvasPresentation.setStitchStartPointID(
        currentDocumentState?.mutation?.created.stitchStartPointIDs.last)
      canvasPresentation.setPrimaryEntityID(nil)
      canvasPresentation.setEntityIDs([])
      canvasPresentation.setConstraintID(nil)
      canvasPresentation.setMeasurementAnnotationID(nil)
      canvasPresentation.setFreeTextID(nil)
    }
  }

  func applyLineEntityCommand(
    start: ModelPoint,
    end: ModelPoint,
    startTarget: CanvasSelectionTarget?,
    endTarget: CanvasSelectionTarget?,
    orientation: LinePlacementOrientation?
  ) {
    guard cadSession.hasDocument else {
      statusMessage = AppStrings.tr("status.document_disconnected")
      return
    }
    let preparedLine = commandFactory.makeCreateLineGestureCommand(
      start: start,
      end: end,
      layerID: activeDrawingLayerID(for: .line),
      styleID: drawingSharedStyleID(for: .line),
      startTarget: startTarget?.constraintJSON,
      endTarget: endTarget?.constraintJSON,
      axis: orientation?.constraintKind
    )
    executeDocumentCommand(preparedLine.request)
  }

  func drawingPlacementPoint(
    _ point: ModelPoint,
    modifiers: CanvasPlacementModifiers = CanvasPlacementModifiers()
  ) -> ModelPoint {
    CanvasInteractionFeature.drawingPlacementPoint(
      point,
      modifiers: modifiers,
      pointSnapEnabled: workspacePreferences.pointSnapEnabled,
      gridSnapEnabled: workspacePreferences.gridSnapEnabled,
      entities: entities,
      linePointSnapToleranceMM: Self.linePointSnapToleranceMM,
      gridSpacingMM: Self.gridSpacingMM
    )
  }

  func linePlacementStartPoint(
    _ point: ModelPoint,
    modifiers: CanvasPlacementModifiers = CanvasPlacementModifiers()
  ) -> ModelPoint {
    drawingPlacementPoint(point, modifiers: modifiers)
  }

  func arcPlacementStartPoint(
    center: ModelPoint,
    to point: ModelPoint,
    modifiers: CanvasPlacementModifiers = CanvasPlacementModifiers()
  ) -> ModelPoint? {
    let candidate = drawingPlacementPoint(point, modifiers: modifiers)
    guard CanvasInteractionFeature.distance(center, candidate) > 0.0001 else {
      return nil
    }
    return candidate
  }

  func arcPlacementEndPoint(
    center: ModelPoint,
    start: ModelPoint,
    to point: ModelPoint,
    previousSweepAngleRad: Double?,
    modifiers: CanvasPlacementModifiers
  ) -> ArcPlacementResult? {
    let candidate = drawingPlacementPoint(point, modifiers: modifiers)
    return CanvasInteractionFeature.arcPlacementEndPoint(
      center: center,
      start: start,
      candidate: candidate,
      previousSweepAngleRad: previousSweepAngleRad,
      forceAxis: modifiers.forceAxis,
      angleSnapStepRad: Self.arcAngleSnapStepRad
    )
  }

  func linePlacementEndPoint(
    from start: ModelPoint,
    to point: ModelPoint,
    modifiers: CanvasPlacementModifiers
  ) -> LinePlacementEnd {
    CanvasInteractionFeature.linePlacementEndPoint(
      from: start,
      to: point,
      modifiers: modifiers,
      pointSnapEnabled: workspacePreferences.pointSnapEnabled,
      gridSnapEnabled: workspacePreferences.gridSnapEnabled,
      entities: entities,
      linePointSnapToleranceMM: Self.linePointSnapToleranceMM,
      gridSpacingMM: Self.gridSpacingMM
    )
  }

  func linePointTarget(at point: ModelPoint) -> CanvasSelectionTarget? {
    CanvasInteractionFeature.nearestLinePointTarget(
      entities: entities,
      near: point,
      toleranceMM: 0.001
    )?.target
  }

  private func activeDrawingLayerID(for tool: CanvasTool) -> String {
    CanvasInteractionFeature.activeDrawingLayerID(
      for: tool,
      activeLayerID: canvasPresentation.activeLayerID,
      layers: layers
    )
  }

  func drawingSharedStyleID(for tool: CanvasTool) -> String? {
    CanvasInteractionFeature.drawingSharedStyleID(
      for: tool,
      activePatternDrawingStyleID: activePatternDrawingStyleID
    )
  }
}
