/// Composition boundary between the AppActionHandlers and the Inspector view model.
enum InspectorFeatureModelFactory {
  static func make(
    actionHandlers: AppActionHandlers,
    inspectorPresentation: InspectorPresentationState,
    canvasPresentation: CanvasPresentationState
  ) -> InspectorFeatureModel {
    let state = InspectorFeatureViewStateBuilder()
    let actions = InspectorFeatureActionsBuilder()
    let selectionSignature = InspectorViewStateFactory.selectionSignature(
      primaryEntityID: actionHandlers.canvas.selectedEntityID,
      entityIDs: actionHandlers.canvas.selectedEntityIDs,
      selectedConstraintID: actionHandlers.canvas.selectedConstraintID,
      selectedMeasurementAnnotationID: actionHandlers.canvas.selectedMeasurementAnnotationID,
      selectedFreeTextID: actionHandlers.canvas.selectedFreeTextID,
      selectedStitchStartPointID: actionHandlers.canvas.selectedStitchStartPointID
    )
    state.inspectorTab = inspectorPresentation.tab
    state.inspectorSelectedLayerID = inspectorPresentation.selectedLayerID
    state.inspectorSelectedSharedStyleID = inspectorPresentation.selectedSharedStyleID
    state.inspectorSelectedParameterID = inspectorPresentation.selectedParameterID
    state.inspectorSelectedPartID = inspectorPresentation.selectedPartID
    state.isSettingPartOrigin = inspectorPresentation.isSettingPartOrigin
    state.inspectorLayerSearchQuery = inspectorPresentation.layerSearchQuery
    state.inspectorSharedStyleSearchQuery = inspectorPresentation.sharedStyleSearchQuery
    state.inspectorParameterSearchQuery = inspectorPresentation.parameterSearchQuery
    state.inspectorHasPendingSelectionChange =
      InspectorViewStateFactory.hasPendingSelectionChange(
        tab: inspectorPresentation.tab,
        selectionSignature: selectionSignature,
        acknowledgedSelectionSignature:
          inspectorPresentation.acknowledgedSelectionSignature
      )
    state.viewMode = canvasPresentation.viewMode
    state.activeLayerID = canvasPresentation.activeLayerID
    state.layers = actionHandlers.document.layers
    state.sharedStyles = actionHandlers.document.sharedStyles
    state.parameters = actionHandlers.document.parameters
    state.parts = actionHandlers.document.parts
    state.arrangementSelectedPartIDs = inspectorPresentation.arrangementSelectedPartIDs
    state.partLibraryEntries = actionHandlers.parts.partLibraryEntries
    state.entities = actionHandlers.document.entities
    state.constraints = actionHandlers.document.constraints
    state.measurementAnnotations = actionHandlers.document.measurementAnnotations
    state.freeTexts = actionHandlers.document.freeTexts
    state.selectedEntity = actionHandlers.canvas.selectedEntity
    state.selectedEntities = actionHandlers.canvas.selectedEntities
    state.selectedFreeText = actionHandlers.canvas.selectedFreeText
    state.selectedConstraintID = actionHandlers.canvas.selectedConstraintID
    state.selectedMeasurementAnnotation = actionHandlers.canvas.selectedMeasurementAnnotation
    state.selectedDerivedElement = WorkspaceViewStateFactory.selectedDerivedElement(
      selectedEntities: actionHandlers.canvas.selectedEntities,
      derivedElements: actionHandlers.document.derivedElements
    )
    state.selectedRoundHole = actionHandlers.canvas.selectedRoundHole
    state.filteredInspectorLayers = InspectorViewStateFactory.filteredLayers(
      actionHandlers.document.layers,
      query: inspectorPresentation.layerSearchQuery
    )
    state.filteredInspectorSharedStyles =
      InspectorViewStateFactory.filteredSharedStyles(
        actionHandlers.document.sharedStyles,
        query: inspectorPresentation.sharedStyleSearchQuery
      )
    state.filteredInspectorParameters = InspectorViewStateFactory.filteredParameters(
      actionHandlers.document.parameters,
      query: inspectorPresentation.parameterSearchQuery
    )
    state.shouldShowLayerInspectorSearch = InspectorViewStateFactory.shouldShowSearch(
      itemCount: actionHandlers.document.layers.count,
      explicitlyVisible: inspectorPresentation.layerSearchVisible,
      query: inspectorPresentation.layerSearchQuery
    )
    state.shouldShowSharedStyleInspectorSearch =
      InspectorViewStateFactory.shouldShowSearch(
        itemCount: actionHandlers.document.sharedStyles.count,
        explicitlyVisible:
          inspectorPresentation.sharedStyleSearchVisible,
        query: inspectorPresentation.sharedStyleSearchQuery
      )
    state.shouldShowParameterInspectorSearch =
      InspectorViewStateFactory.shouldShowSearch(
        itemCount: actionHandlers.document.parameters.count,
        explicitlyVisible:
          inspectorPresentation.parameterSearchVisible,
        query: inspectorPresentation.parameterSearchQuery
      )
    state.canConstrainSelectedLineLengthsEqual =
      actionHandlers.canvas.canConstrainSelectedLineLengthsEqual
    actions.setInspectorTab = actionHandlers.inspector.setInspectorTab
    actions.setInspectorSelectedLayerID = inspectorPresentation.setSelectedLayerID
    actions.setInspectorSelectedSharedStyleID = inspectorPresentation.setSelectedSharedStyleID
    actions.setInspectorSelectedParameterID = inspectorPresentation.setSelectedParameterID
    actions.setInspectorLayerSearchQuery = inspectorPresentation.setLayerSearchQuery
    actions.setInspectorSharedStyleSearchQuery = inspectorPresentation.setSharedStyleSearchQuery
    actions.setInspectorParameterSearchQuery = inspectorPresentation.setParameterSearchQuery
    actions.revealInspectorSelectionTab = actionHandlers.inspector.revealInspectorSelectionTab
    actions.setSelectedEntitiesSharedStyle = actionHandlers.document.setSelectedEntitiesSharedStyle
    actions.setSelectedEntityLayer = actionHandlers.document.setSelectedEntityLayer
    actions.deleteSelectedEntity = actionHandlers.canvas.deleteSelectedEntity
    actions.setActiveLayer = actionHandlers.document.setActiveLayer
    actions.renameLayer = actionHandlers.document.renameLayer
    actions.setLayerVisibility = actionHandlers.document.setLayerVisibility
    actions.setLayerPrintable = actionHandlers.document.setLayerPrintable
    actions.setLayerStyle = actionHandlers.document.setLayerStyle
    actions.deleteLayer = actionHandlers.document.deleteLayer
    actions.addLayer = actionHandlers.document.addLayer
    actions.updateSharedStyle = actionHandlers.document.updateSharedStyle
    actions.deleteSharedStyle = actionHandlers.document.deleteSharedStyle
    actions.addSharedStyle = actionHandlers.document.addSharedStyle
    actions.addParameter = actionHandlers.document.addParameter
    actions.updateFreeText = actionHandlers.canvas.updateFreeText
    actions.deleteSelectedFreeText = actionHandlers.canvas.deleteSelectedFreeText
    actions.deleteConstraint = actionHandlers.canvas.deleteConstraint
    actions.selectConstraint = actionHandlers.canvas.selectConstraint
    actions.selectMeasurementAnnotation = actionHandlers.canvas.selectMeasurementAnnotation
    actions.deleteMeasurementAnnotation = actionHandlers.canvas.deleteMeasurementAnnotation
    actions.convertMeasurementAnnotationToConstraint =
      actionHandlers.canvas.convertMeasurementAnnotationToConstraint
    actions.hoverConstraint = actionHandlers.canvas.hoverConstraint
    actions.constrainSelectedLineLengthsEqual =
      actionHandlers.document.constrainSelectedLineLengthsEqual
    actions.setConstraintDegrees = actionHandlers.canvas.setConstraintDegrees
    actions.setConstraintValue = actionHandlers.canvas.setConstraintValue
    actions.setConstraintParameter = actionHandlers.canvas.setConstraintParameter
    actions.setDerivedElementDirection = actionHandlers.document.setDerivedElementDirection
    actions.reverseDerivedElementDirection = actionHandlers.document.reverseDerivedElementDirection
    actions.setDerivedElementDistance = actionHandlers.document.setDerivedElementDistance
    actions.setDerivedElementParameter = actionHandlers.document.setDerivedElementParameter
    actions.setSelectedRoundHoleKind = actionHandlers.document.setSelectedRoundHoleKind
    actions.setSelectedRoundHoleDiameter = actionHandlers.document.setSelectedRoundHoleDiameter
    actions.constrainSelectedLineLength = actionHandlers.document.constrainSelectedLineLength
    actions.setSelectedLineLength = actionHandlers.document.setSelectedLineLength
    actions.setSelectedCircleRadius = actionHandlers.document.setSelectedCircleRadius
    actions.setSelectedArc = { radius, start, sweep in
      actionHandlers.document.setSelectedArc(
        radiusMM: radius, startAngleRad: start, sweepAngleRad: sweep)
    }
    actions.updateParameter = actionHandlers.document.updateParameter
    actions.deleteParameter = actionHandlers.document.deleteParameter
    actions.createPartFromSelection = actionHandlers.parts.createPartFromSelection
    actions.updatePart = actionHandlers.parts.updatePart
    actions.updatePartSettings = actionHandlers.parts.updatePartSettings
    actions.deletePart = actionHandlers.parts.deletePart
    actions.selectPartContents = actionHandlers.parts.selectPartContents
    actions.movePart = { part, delta in actionHandlers.parts.movePart(part, delta: delta) }
    actions.duplicatePart = { part in actionHandlers.parts.duplicatePart(part) }
    actions.addSelectionToPart = actionHandlers.parts.addSelectionToPart
    actions.removeSelectionFromPart = actionHandlers.parts.removeSelectionFromPart
    actions.setPartBoundaryFromSelection = actionHandlers.parts.setPartBoundaryFromSelection
    actions.beginSettingPartOrigin = actionHandlers.parts.beginSettingPartOrigin
    actions.togglePartArrangementSelection = actionHandlers.parts.togglePartArrangementSelection
    actions.alignSelectedParts = actionHandlers.parts.alignSelectedParts
    actions.distributeSelectedParts = actionHandlers.parts.distributeSelectedParts
    actions.addPartToLibrary = actionHandlers.parts.addPartToLibrary
    actions.insertPartFromLibrary = actionHandlers.parts.insertPartFromLibrary
    actions.removePartLibraryEntry = actionHandlers.parts.removePartLibraryEntry
    return InspectorFeatureModel(
      state: InspectorFeatureViewState(builder: state),
      actions: InspectorFeatureActions(builder: actions)
    )
  }
}
