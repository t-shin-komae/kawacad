/// Composition boundary for the Inspector shell and its focused tab models.
enum InspectorFeatureModelFactory {
  static func make(
    actionHandlers: AppActionHandlers,
    inspectorPresentation: InspectorPresentationState,
    canvasPresentation: CanvasPresentationState
  ) -> InspectorPanelModel {
    let selectionSignature = InspectorViewStateFactory.selectionSignature(
      primaryEntityID: actionHandlers.canvas.selectedEntityID,
      entityIDs: actionHandlers.canvas.selectedEntityIDs,
      selectedConstraintID: actionHandlers.canvas.selectedConstraintID,
      selectedMeasurementAnnotationID: actionHandlers.canvas.selectedMeasurementAnnotationID,
      selectedFreeTextID: actionHandlers.canvas.selectedFreeTextID,
      selectedStitchStartPointID: actionHandlers.canvas.selectedStitchStartPointID
    )
    let hasPendingSelectionChange = InspectorViewStateFactory.hasPendingSelectionChange(
      tab: inspectorPresentation.tab,
      selectionSignature: selectionSignature,
      acknowledgedSelectionSignature: inspectorPresentation.acknowledgedSelectionSignature
    )
    let document = actionHandlers.document
    let canvas = actionHandlers.canvas
    let inspector = actionHandlers.inspector
    let parts = actionHandlers.parts
    let filteredLayers = InspectorViewStateFactory.filteredLayers(
      document.layers,
      query: inspectorPresentation.layerSearchQuery
    )
    let filteredStyles = InspectorViewStateFactory.filteredSharedStyles(
      document.sharedStyles,
      query: inspectorPresentation.sharedStyleSearchQuery
    )
    let filteredParameters = InspectorViewStateFactory.filteredParameters(
      document.parameters,
      query: inspectorPresentation.parameterSearchQuery
    )
    let selectedDerivedElement = WorkspaceViewStateFactory.selectedDerivedElement(
      selectedEntities: canvas.selectedEntities,
      derivedElements: document.derivedElements
    )

    let selection = SelectionInspectorModel(
      data: SelectionInspectorData(
        viewMode: canvasPresentation.viewMode,
        activeLayerID: canvasPresentation.activeLayerID,
        layers: document.layers,
        sharedStyles: document.sharedStyles,
        parameters: document.parameters,
        entities: document.entities,
        constraints: document.constraints,
        measurementAnnotations: document.measurementAnnotations,
        freeTexts: document.freeTexts,
        selectedEntity: canvas.selectedEntity,
        selectedEntities: canvas.selectedEntities,
        selectedFreeText: canvas.selectedFreeText,
        selectedStitchStartPoint: canvas.selectedStitchStartPoint,
        selectedConstraintID: canvas.selectedConstraintID,
        selectedMeasurementAnnotation: canvas.selectedMeasurementAnnotation,
        selectedDerivedElement: selectedDerivedElement,
        selectedRoundHole: canvas.selectedRoundHole,
        canConstrainSelectedLineLengthsEqual: canvas.canConstrainSelectedLineLengthsEqual
      ),
      actions: SelectionInspectorActions(
        setSelectedEntitiesSharedStyle: document.setSelectedEntitiesSharedStyle,
        setSelectedEntityLayer: document.setSelectedEntityLayer,
        deleteSelectedEntity: canvas.deleteSelectedEntity,
        updateFreeText: canvas.updateFreeText,
        deleteSelectedFreeText: canvas.deleteSelectedFreeText,
        deleteConstraint: canvas.deleteConstraint,
        selectConstraint: canvas.selectConstraint,
        selectFreeText: canvas.selectFreeText,
        selectMeasurementAnnotation: canvas.selectMeasurementAnnotation,
        deleteMeasurementAnnotation: canvas.deleteMeasurementAnnotation,
        convertMeasurementAnnotationToConstraint: canvas.convertMeasurementAnnotationToConstraint,
        hoverConstraint: canvas.hoverConstraint,
        constrainSelectedLineLengthsEqual: document.constrainSelectedLineLengthsEqual,
        setConstraintDegrees: canvas.setConstraintDegrees,
        setConstraintValue: canvas.setConstraintValue,
        setConstraintParameter: canvas.setConstraintParameter,
        setDerivedElementDirection: document.setDerivedElementDirection,
        reverseDerivedElementDirection: document.reverseDerivedElementDirection,
        setDerivedElementDistance: document.setDerivedElementDistance,
        setDerivedElementParameter: document.setDerivedElementParameter,
        setSelectedRoundHoleKind: document.setSelectedRoundHoleKind,
        setSelectedRoundHoleDiameter: document.setSelectedRoundHoleDiameter,
        constrainSelectedLineLength: document.constrainSelectedLineLength,
        setSelectedLineLength: document.setSelectedLineLength,
        setSelectedCircleRadius: document.setSelectedCircleRadius,
        setSelectedArc: document.setSelectedArc
      )
    )
    let layers = LayerInspectorModel(
      data: LayerInspectorData(
        activeLayerID: canvasPresentation.activeLayerID,
        layers: document.layers,
        inspectorSelectedLayerID: inspectorPresentation.selectedLayerID,
        inspectorLayerSearchQuery: inspectorPresentation.layerSearchQuery,
        filteredInspectorLayers: filteredLayers,
        shouldShowLayerInspectorSearch: InspectorViewStateFactory.shouldShowSearch(
          itemCount: document.layers.count,
          explicitlyVisible: inspectorPresentation.layerSearchVisible,
          query: inspectorPresentation.layerSearchQuery
        )
      ),
      actions: LayerInspectorActions(
        setInspectorSelectedLayerID: inspectorPresentation.setSelectedLayerID,
        setInspectorLayerSearchQuery: inspectorPresentation.setLayerSearchQuery,
        setActiveLayer: document.setActiveLayer,
        renameLayer: document.renameLayer,
        setLayerVisibility: document.setLayerVisibility,
        setLayerPrintable: document.setLayerPrintable,
        setLayerStyle: document.setLayerStyle,
        deleteLayer: document.deleteLayer,
        addLayer: document.addLayer
      )
    )
    let styles = StyleInspectorModel(
      data: StyleInspectorData(
        inspectorSelectedSharedStyleID: inspectorPresentation.selectedSharedStyleID,
        inspectorSharedStyleSearchQuery: inspectorPresentation.sharedStyleSearchQuery,
        filteredInspectorSharedStyles: filteredStyles,
        shouldShowSharedStyleInspectorSearch: InspectorViewStateFactory.shouldShowSearch(
          itemCount: document.sharedStyles.count,
          explicitlyVisible: inspectorPresentation.sharedStyleSearchVisible,
          query: inspectorPresentation.sharedStyleSearchQuery
        )
      ),
      actions: StyleInspectorActions(
        setInspectorSelectedSharedStyleID: inspectorPresentation.setSelectedSharedStyleID,
        setInspectorSharedStyleSearchQuery: inspectorPresentation.setSharedStyleSearchQuery,
        updateSharedStyle: document.updateSharedStyle,
        deleteSharedStyle: document.deleteSharedStyle,
        addSharedStyle: document.addSharedStyle
      )
    )
    let parameters = ParameterInspectorModel(
      data: ParameterInspectorData(
        inspectorSelectedParameterID: inspectorPresentation.selectedParameterID,
        inspectorParameterSearchQuery: inspectorPresentation.parameterSearchQuery,
        filteredInspectorParameters: filteredParameters,
        shouldShowParameterInspectorSearch: InspectorViewStateFactory.shouldShowSearch(
          itemCount: document.parameters.count,
          explicitlyVisible: inspectorPresentation.parameterSearchVisible,
          query: inspectorPresentation.parameterSearchQuery
        )
      ),
      actions: ParameterInspectorActions(
        setInspectorSelectedParameterID: inspectorPresentation.setSelectedParameterID,
        setInspectorParameterSearchQuery: inspectorPresentation.setParameterSearchQuery,
        addParameter: document.addParameter,
        updateParameter: document.updateParameter,
        deleteParameter: document.deleteParameter
      )
    )
    let partModel = PartInspectorModel(
      data: PartInspectorData(
        parts: document.parts,
        inspectorSelectedPartID: inspectorPresentation.selectedPartID,
        arrangementSelectedPartIDs: inspectorPresentation.arrangementSelectedPartIDs,
        partLibraryEntries: parts.partLibraryEntries,
        selectedEntities: canvas.selectedEntities,
        isSettingPartOrigin: inspectorPresentation.isSettingPartOrigin
      ),
      actions: PartInspectorActions(
        createPartFromSelection: parts.createPartFromSelection,
        updatePart: parts.updatePart,
        updatePartSettings: parts.updatePartSettings,
        deletePart: parts.deletePart,
        selectPartContents: parts.selectPartContents,
        movePart: { part, delta in parts.movePart(part, delta: delta) },
        duplicatePart: { part in parts.duplicatePart(part) },
        addSelectionToPart: parts.addSelectionToPart,
        removeSelectionFromPart: parts.removeSelectionFromPart,
        setPartBoundaryFromSelection: parts.setPartBoundaryFromSelection,
        beginSettingPartOrigin: parts.beginSettingPartOrigin,
        togglePartArrangementSelection: parts.togglePartArrangementSelection,
        alignSelectedParts: parts.alignSelectedParts,
        distributeSelectedParts: parts.distributeSelectedParts,
        addPartToLibrary: parts.addPartToLibrary,
        insertPartFromLibrary: parts.insertPartFromLibrary,
        removePartLibraryEntry: parts.removePartLibraryEntry
      )
    )
    return InspectorPanelModel(
      inspectorTab: inspectorPresentation.tab,
      inspectorHasPendingSelectionChange: hasPendingSelectionChange,
      setInspectorTab: inspector.setInspectorTab,
      revealInspectorSelectionTab: inspector.revealInspectorSelectionTab,
      selection: selection,
      layers: layers,
      styles: styles,
      parameters: parameters,
      parts: partModel
    )
  }
}
