struct SelectionInspectorData {
  let viewMode: CanvasViewMode
  let activeLayerID: String
  let layers: [ProjectLayer]
  let sharedStyles: [ProjectSharedStyle]
  let parameters: [ProjectParameter]
  let entities: [CanvasEntity]
  let constraints: [ProjectConstraint]
  let measurementAnnotations: [ProjectMeasurementAnnotation]
  let freeTexts: [ProjectFreeText]
  let selectedEntity: CanvasEntity?
  let selectedEntities: [CanvasEntity]
  let selectedFreeText: ProjectFreeText?
  let selectedStitchStartPoint: ProjectStitchStartPoint?
  let selectedConstraintID: String?
  let selectedMeasurementAnnotation: ProjectMeasurementAnnotation?
  let selectedDerivedElement: ProjectDerivedElement?
  let selectedRoundHole: ProjectRoundHole?
  let canConstrainSelectedLineLengthsEqual: Bool
}

struct SelectionInspectorActions {
  let setSelectedEntitiesSharedStyle: (String?) -> Bool
  let setSelectedEntityLayer: (String) -> Void
  let deleteSelectedEntity: () -> Void
  let updateFreeText: (ProjectFreeText) -> Bool
  let deleteSelectedFreeText: () -> Void
  let deleteConstraint: (ProjectConstraint) -> Void
  let selectConstraint: (String?) -> Void
  let selectFreeText: (String?) -> Void
  let selectMeasurementAnnotation: (String?) -> Void
  let deleteMeasurementAnnotation: (ProjectMeasurementAnnotation) -> Void
  let convertMeasurementAnnotationToConstraint: (String) -> Void
  let hoverConstraint: (String?) -> Void
  let constrainSelectedLineLengthsEqual: () -> Void
  let setConstraintDegrees: (ProjectConstraint, Double) -> Bool
  let setConstraintValue: (ProjectConstraint, Double) -> Bool
  let setConstraintParameter: (ProjectConstraint, ProjectParameter) -> Bool
  let setDerivedElementDirection: (ProjectDerivedElement, OffsetDirection) -> Bool
  let reverseDerivedElementDirection: (ProjectDerivedElement) -> Bool
  let setDerivedElementDistance: (ProjectDerivedElement, Double) -> Bool
  let setDerivedElementParameter: (ProjectDerivedElement, ProjectParameter) -> Bool
  let setSelectedRoundHoleKind: (ProjectRoundHoleKind) -> Bool
  let setSelectedRoundHoleDiameter: (Double) -> Bool
  let constrainSelectedLineLength: () -> Void
  let setSelectedLineLength: (Double) -> Bool
  let setSelectedCircleRadius: (Double) -> Bool
  let setSelectedArc: (Double, Double, Double) -> Bool
}

struct SelectionInspectorModel {
  let data: SelectionInspectorData
  let actions: SelectionInspectorActions
}

extension SelectionInspectorModel {
  var documentOverviewModel: SelectionDocumentOverviewModel {
    SelectionDocumentOverviewModel(
      viewMode: data.viewMode,
      activeLayerID: data.activeLayerID,
      layers: data.layers,
      entities: data.entities,
      constraints: data.constraints,
      parameters: data.parameters
    )
  }

  var measurementEditorModel: SelectionMeasurementEditorModel {
    SelectionMeasurementEditorModel(
      convert: actions.convertMeasurementAnnotationToConstraint,
      delete: actions.deleteMeasurementAnnotation
    )
  }

  var stitchPointEditorModel: SelectionStitchPointEditorModel {
    SelectionStitchPointEditorModel(
      entities: data.entities,
      delete: actions.deleteSelectedEntity
    )
  }

  var freeTextEditorModel: SelectionFreeTextEditorModel {
    SelectionFreeTextEditorModel(
      update: actions.updateFreeText,
      delete: actions.deleteSelectedFreeText
    )
  }

  var constraintEditorModel: SelectionConstraintEditorModel {
    SelectionConstraintEditorModel(
      parameters: data.parameters,
      delete: actions.deleteConstraint,
      hover: actions.hoverConstraint,
      setDegrees: actions.setConstraintDegrees,
      setValue: actions.setConstraintValue,
      setParameter: actions.setConstraintParameter
    )
  }

  var multiSelectionEditorModel: SelectionMultiSelectionEditorModel {
    SelectionMultiSelectionEditorModel(
      selectedEntities: data.selectedEntities,
      sharedStyles: data.sharedStyles,
      layers: data.layers,
      canConstrainSelectedLineLengthsEqual: data.canConstrainSelectedLineLengthsEqual,
      setSharedStyle: actions.setSelectedEntitiesSharedStyle,
      delete: actions.deleteSelectedEntity,
      constrainSelectedLineLengthsEqual: actions.constrainSelectedLineLengthsEqual
    )
  }

  var derivedElementEditorModel: SelectionDerivedElementEditorModel {
    SelectionDerivedElementEditorModel(
      parameters: data.parameters,
      setDirection: actions.setDerivedElementDirection,
      reverseDirection: actions.reverseDerivedElementDirection,
      setDistance: actions.setDerivedElementDistance,
      setParameter: actions.setDerivedElementParameter
    )
  }

  var roundHoleEditorModel: SelectionRoundHoleEditorModel {
    SelectionRoundHoleEditorModel(
      selectedRoundHole: data.selectedRoundHole,
      selectedEntity: data.selectedEntity,
      setKind: actions.setSelectedRoundHoleKind,
      setDiameter: actions.setSelectedRoundHoleDiameter
    )
  }

  var entityGeometryEditorModel: SelectionEntityGeometryEditorModel {
    SelectionEntityGeometryEditorModel(
      selectedEntity: data.selectedEntity,
      constrainLineLength: actions.constrainSelectedLineLength,
      setLineLength: actions.setSelectedLineLength,
      setCircleRadius: actions.setSelectedCircleRadius,
      setArc: actions.setSelectedArc
    )
  }

  var entityEditorModel: SelectionEntityEditorModel {
    SelectionEntityEditorModel(
      layers: data.layers,
      sharedStyles: data.sharedStyles,
      selectedDerivedElement: data.selectedDerivedElement,
      selectedRoundHole: data.selectedRoundHole,
      selectedEntity: data.selectedEntity,
      setLayer: actions.setSelectedEntityLayer,
      setSharedStyle: actions.setSelectedEntitiesSharedStyle,
      delete: actions.deleteSelectedEntity,
      parameters: data.parameters,
      derived: derivedElementEditorModel,
      roundHole: roundHoleEditorModel,
      geometry: entityGeometryEditorModel
    )
  }
}

struct LayerInspectorData {
  let activeLayerID: String
  let layers: [ProjectLayer]
  let inspectorSelectedLayerID: String?
  let inspectorLayerSearchQuery: String
  let filteredInspectorLayers: [ProjectLayer]
  let shouldShowLayerInspectorSearch: Bool
}
struct LayerInspectorActions {
  let setInspectorSelectedLayerID: (String?) -> Void
  let setInspectorLayerSearchQuery: (String) -> Void
  let setActiveLayer: (String) -> Void
  let renameLayer: (ProjectLayer, String) -> Bool
  let setLayerVisibility: (ProjectLayer, Bool) -> Void
  let setLayerPrintable: (ProjectLayer, Bool) -> Void
  let setLayerStyle: (ProjectLayer) -> Bool
  let deleteLayer: (ProjectLayer) -> Void
  let addLayer: () -> Void
}
struct LayerInspectorModel {
  let data: LayerInspectorData
  let actions: LayerInspectorActions
}

struct StyleInspectorData {
  let inspectorSelectedSharedStyleID: String?
  let inspectorSharedStyleSearchQuery: String
  let filteredInspectorSharedStyles: [ProjectSharedStyle]
  let shouldShowSharedStyleInspectorSearch: Bool
}
struct StyleInspectorActions {
  let setInspectorSelectedSharedStyleID: (String?) -> Void
  let setInspectorSharedStyleSearchQuery: (String) -> Void
  let updateSharedStyle: (ProjectSharedStyle) -> Bool
  let deleteSharedStyle: (ProjectSharedStyle) -> Void
  let addSharedStyle: () -> Void
}
struct StyleInspectorModel {
  let data: StyleInspectorData
  let actions: StyleInspectorActions
}

struct ParameterInspectorData {
  let inspectorSelectedParameterID: String?
  let inspectorParameterSearchQuery: String
  let filteredInspectorParameters: [ProjectParameter]
  let shouldShowParameterInspectorSearch: Bool
}
struct ParameterInspectorActions {
  let setInspectorSelectedParameterID: (String?) -> Void
  let setInspectorParameterSearchQuery: (String) -> Void
  let addParameter: () -> Void
  let updateParameter: (ProjectParameter) -> Bool
  let deleteParameter: (ProjectParameter) -> Void
}
struct ParameterInspectorModel {
  let data: ParameterInspectorData
  let actions: ParameterInspectorActions
}

struct PartInspectorData {
  let parts: [ProjectPart]
  let inspectorSelectedPartID: String?
  let arrangementSelectedPartIDs: Set<String>
  let partLibraryEntries: [PartLibraryEntry]
  let selectedEntities: [CanvasEntity]
  let isSettingPartOrigin: Bool
}
struct PartInspectorActions {
  let createPartFromSelection: () -> Void
  let updatePart: (ProjectPart) -> Bool
  let updatePartSettings: (ProjectPart) -> Bool
  let deletePart: (ProjectPart) -> Void
  let selectPartContents: (ProjectPart) -> Void
  let movePart: (ProjectPart, ModelPoint) -> Bool
  let duplicatePart: (ProjectPart) -> Void
  let addSelectionToPart: (ProjectPart) -> Void
  let removeSelectionFromPart: (ProjectPart) -> Void
  let setPartBoundaryFromSelection: (ProjectPart) -> Void
  let beginSettingPartOrigin: (ProjectPart) -> Void
  let togglePartArrangementSelection: (ProjectPart) -> Void
  let alignSelectedParts: (String) -> Void
  let distributeSelectedParts: (String) -> Void
  let addPartToLibrary: (ProjectPart) -> Void
  let insertPartFromLibrary: (PartLibraryEntry) -> Void
  let removePartLibraryEntry: (PartLibraryEntry) -> Void
}
struct PartInspectorModel {
  let data: PartInspectorData
  let actions: PartInspectorActions
}
