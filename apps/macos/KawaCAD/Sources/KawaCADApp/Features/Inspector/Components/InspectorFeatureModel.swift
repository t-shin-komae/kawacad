import Combine
import SwiftUI

/// Immutable Inspector snapshot consumed by SwiftUI.
struct InspectorFeatureViewState {
  let inspectorTab: InspectorTab
  let inspectorSelectedLayerID: String?
  let inspectorSelectedSharedStyleID: String?
  let inspectorSelectedParameterID: String?
  let inspectorSelectedPartID: String?
  let isSettingPartOrigin: Bool
  let inspectorLayerSearchQuery: String
  let inspectorSharedStyleSearchQuery: String
  let inspectorParameterSearchQuery: String
  let inspectorHasPendingSelectionChange: Bool
  let viewMode: CanvasViewMode
  let activeLayerID: String
  let layers: [ProjectLayer]
  let sharedStyles: [ProjectSharedStyle]
  let parameters: [ProjectParameter]
  let parts: [ProjectPart]
  let arrangementSelectedPartIDs: Set<String>
  let partLibraryEntries: [PartLibraryEntry]
  let entities: [CanvasEntity]
  let constraints: [ProjectConstraint]
  let measurementAnnotations: [ProjectMeasurementAnnotation]
  let freeTexts: [ProjectFreeText]
  let selectedEntity: CanvasEntity?
  let selectedEntities: [CanvasEntity]
  let selectedFreeText: ProjectFreeText?
  let selectedConstraintID: String?
  let selectedMeasurementAnnotation: ProjectMeasurementAnnotation?
  let selectedDerivedElement: ProjectDerivedElement?
  let selectedRoundHole: ProjectRoundHole?
  let filteredInspectorLayers: [ProjectLayer]
  let filteredInspectorSharedStyles: [ProjectSharedStyle]
  let filteredInspectorParameters: [ProjectParameter]
  let shouldShowLayerInspectorSearch: Bool
  let shouldShowSharedStyleInspectorSearch: Bool
  let shouldShowParameterInspectorSearch: Bool
  let canConstrainSelectedLineLengthsEqual: Bool

  init(builder: InspectorFeatureViewStateBuilder) {
    self.inspectorTab = builder.inspectorTab
    self.inspectorSelectedLayerID = builder.inspectorSelectedLayerID
    self.inspectorSelectedSharedStyleID = builder.inspectorSelectedSharedStyleID
    self.inspectorSelectedParameterID = builder.inspectorSelectedParameterID
    self.inspectorSelectedPartID = builder.inspectorSelectedPartID
    self.isSettingPartOrigin = builder.isSettingPartOrigin
    self.inspectorLayerSearchQuery = builder.inspectorLayerSearchQuery
    self.inspectorSharedStyleSearchQuery = builder.inspectorSharedStyleSearchQuery
    self.inspectorParameterSearchQuery = builder.inspectorParameterSearchQuery
    self.inspectorHasPendingSelectionChange = builder.inspectorHasPendingSelectionChange
    self.viewMode = builder.viewMode
    self.activeLayerID = builder.activeLayerID
    self.layers = builder.layers
    self.sharedStyles = builder.sharedStyles
    self.parameters = builder.parameters
    self.parts = builder.parts
    self.arrangementSelectedPartIDs = builder.arrangementSelectedPartIDs
    self.partLibraryEntries = builder.partLibraryEntries
    self.entities = builder.entities
    self.constraints = builder.constraints
    self.measurementAnnotations = builder.measurementAnnotations
    self.freeTexts = builder.freeTexts
    self.selectedEntity = builder.selectedEntity
    self.selectedEntities = builder.selectedEntities
    self.selectedFreeText = builder.selectedFreeText
    self.selectedConstraintID = builder.selectedConstraintID
    self.selectedMeasurementAnnotation = builder.selectedMeasurementAnnotation
    self.selectedDerivedElement = builder.selectedDerivedElement
    self.selectedRoundHole = builder.selectedRoundHole
    self.filteredInspectorLayers = builder.filteredInspectorLayers
    self.filteredInspectorSharedStyles = builder.filteredInspectorSharedStyles
    self.filteredInspectorParameters = builder.filteredInspectorParameters
    self.shouldShowLayerInspectorSearch = builder.shouldShowLayerInspectorSearch
    self.shouldShowSharedStyleInspectorSearch = builder.shouldShowSharedStyleInspectorSearch
    self.shouldShowParameterInspectorSearch = builder.shouldShowParameterInspectorSearch
    self.canConstrainSelectedLineLengthsEqual = builder.canConstrainSelectedLineLengthsEqual
  }
}

/// Inspector operations supplied by the feature action handler.
struct InspectorFeatureActions {
  let setInspectorTab: (InspectorTab) -> Void
  let setInspectorSelectedLayerID: (String?) -> Void
  let setInspectorSelectedSharedStyleID: (String?) -> Void
  let setInspectorSelectedParameterID: (String?) -> Void
  let setInspectorLayerSearchQuery: (String) -> Void
  let setInspectorSharedStyleSearchQuery: (String) -> Void
  let setInspectorParameterSearchQuery: (String) -> Void
  let revealInspectorSelectionTab: () -> Void
  let setSelectedEntitiesSharedStyle: (String?) -> Bool
  let setSelectedEntityLayer: (String) -> Void
  let deleteSelectedEntity: () -> Void
  let setActiveLayer: (String) -> Void
  let renameLayer: (ProjectLayer, String) -> Bool
  let setLayerVisibility: (ProjectLayer, Bool) -> Void
  let setLayerPrintable: (ProjectLayer, Bool) -> Void
  let setLayerStyle: (ProjectLayer) -> Bool
  let deleteLayer: (ProjectLayer) -> Void
  let addLayer: () -> Void
  let updateSharedStyle: (ProjectSharedStyle) -> Bool
  let deleteSharedStyle: (ProjectSharedStyle) -> Void
  let addSharedStyle: () -> Void
  let addParameter: () -> Void
  let updateFreeText: (ProjectFreeText) -> Bool
  let deleteSelectedFreeText: () -> Void
  let deleteConstraint: (ProjectConstraint) -> Void
  let selectConstraint: (String?) -> Void
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
  let updateParameter: (ProjectParameter) -> Bool
  let deleteParameter: (ProjectParameter) -> Void
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

  init(builder: InspectorFeatureActionsBuilder) {
    self.setInspectorTab = builder.setInspectorTab
    self.setInspectorSelectedLayerID = builder.setInspectorSelectedLayerID
    self.setInspectorSelectedSharedStyleID = builder.setInspectorSelectedSharedStyleID
    self.setInspectorSelectedParameterID = builder.setInspectorSelectedParameterID
    self.setInspectorLayerSearchQuery = builder.setInspectorLayerSearchQuery
    self.setInspectorSharedStyleSearchQuery = builder.setInspectorSharedStyleSearchQuery
    self.setInspectorParameterSearchQuery = builder.setInspectorParameterSearchQuery
    self.revealInspectorSelectionTab = builder.revealInspectorSelectionTab
    self.setSelectedEntitiesSharedStyle = builder.setSelectedEntitiesSharedStyle
    self.setSelectedEntityLayer = builder.setSelectedEntityLayer
    self.deleteSelectedEntity = builder.deleteSelectedEntity
    self.setActiveLayer = builder.setActiveLayer
    self.renameLayer = builder.renameLayer
    self.setLayerVisibility = builder.setLayerVisibility
    self.setLayerPrintable = builder.setLayerPrintable
    self.setLayerStyle = builder.setLayerStyle
    self.deleteLayer = builder.deleteLayer
    self.addLayer = builder.addLayer
    self.updateSharedStyle = builder.updateSharedStyle
    self.deleteSharedStyle = builder.deleteSharedStyle
    self.addSharedStyle = builder.addSharedStyle
    self.addParameter = builder.addParameter
    self.updateFreeText = builder.updateFreeText
    self.deleteSelectedFreeText = builder.deleteSelectedFreeText
    self.deleteConstraint = builder.deleteConstraint
    self.selectConstraint = builder.selectConstraint
    self.selectMeasurementAnnotation = builder.selectMeasurementAnnotation
    self.deleteMeasurementAnnotation = builder.deleteMeasurementAnnotation
    self.convertMeasurementAnnotationToConstraint = builder.convertMeasurementAnnotationToConstraint
    self.hoverConstraint = builder.hoverConstraint
    self.constrainSelectedLineLengthsEqual = builder.constrainSelectedLineLengthsEqual
    self.setConstraintDegrees = builder.setConstraintDegrees
    self.setConstraintValue = builder.setConstraintValue
    self.setConstraintParameter = builder.setConstraintParameter
    self.setDerivedElementDirection = builder.setDerivedElementDirection
    self.reverseDerivedElementDirection = builder.reverseDerivedElementDirection
    self.setDerivedElementDistance = builder.setDerivedElementDistance
    self.setDerivedElementParameter = builder.setDerivedElementParameter
    self.setSelectedRoundHoleKind = builder.setSelectedRoundHoleKind
    self.setSelectedRoundHoleDiameter = builder.setSelectedRoundHoleDiameter
    self.constrainSelectedLineLength = builder.constrainSelectedLineLength
    self.setSelectedLineLength = builder.setSelectedLineLength
    self.setSelectedCircleRadius = builder.setSelectedCircleRadius
    self.setSelectedArc = builder.setSelectedArc
    self.updateParameter = builder.updateParameter
    self.deleteParameter = builder.deleteParameter
    self.createPartFromSelection = builder.createPartFromSelection
    self.updatePart = builder.updatePart
    self.updatePartSettings = builder.updatePartSettings
    self.deletePart = builder.deletePart
    self.selectPartContents = builder.selectPartContents
    self.movePart = builder.movePart
    self.duplicatePart = builder.duplicatePart
    self.addSelectionToPart = builder.addSelectionToPart
    self.removeSelectionFromPart = builder.removeSelectionFromPart
    self.setPartBoundaryFromSelection = builder.setPartBoundaryFromSelection
    self.beginSettingPartOrigin = builder.beginSettingPartOrigin
    self.togglePartArrangementSelection = builder.togglePartArrangementSelection
    self.alignSelectedParts = builder.alignSelectedParts
    self.distributeSelectedParts = builder.distributeSelectedParts
    self.addPartToLibrary = builder.addPartToLibrary
    self.insertPartFromLibrary = builder.insertPartFromLibrary
    self.removePartLibraryEntry = builder.removePartLibraryEntry
  }
}

final class InspectorFeatureViewStateBuilder {
  var inspectorTab: InspectorTab!
  var inspectorSelectedLayerID: String?
  var inspectorSelectedSharedStyleID: String?
  var inspectorSelectedParameterID: String?
  var inspectorSelectedPartID: String?
  var isSettingPartOrigin: Bool!
  var inspectorLayerSearchQuery: String!
  var inspectorSharedStyleSearchQuery: String!
  var inspectorParameterSearchQuery: String!
  var inspectorHasPendingSelectionChange: Bool!
  var viewMode: CanvasViewMode!
  var activeLayerID: String!
  var layers: [ProjectLayer]!
  var sharedStyles: [ProjectSharedStyle]!
  var parameters: [ProjectParameter]!
  var parts: [ProjectPart]!
  var arrangementSelectedPartIDs: Set<String>!
  var partLibraryEntries: [PartLibraryEntry]!
  var entities: [CanvasEntity]!
  var constraints: [ProjectConstraint]!
  var measurementAnnotations: [ProjectMeasurementAnnotation]!
  var freeTexts: [ProjectFreeText]!
  var selectedEntity: CanvasEntity?
  var selectedEntities: [CanvasEntity]!
  var selectedFreeText: ProjectFreeText?
  var selectedConstraintID: String?
  var selectedMeasurementAnnotation: ProjectMeasurementAnnotation?
  var selectedDerivedElement: ProjectDerivedElement?
  var selectedRoundHole: ProjectRoundHole?
  var filteredInspectorLayers: [ProjectLayer]!
  var filteredInspectorSharedStyles: [ProjectSharedStyle]!
  var filteredInspectorParameters: [ProjectParameter]!
  var shouldShowLayerInspectorSearch: Bool!
  var shouldShowSharedStyleInspectorSearch: Bool!
  var shouldShowParameterInspectorSearch: Bool!
  var canConstrainSelectedLineLengthsEqual: Bool!
}
final class InspectorFeatureActionsBuilder {
  var setInspectorTab: ((InspectorTab) -> Void)!
  var setInspectorSelectedLayerID: ((String?) -> Void)!
  var setInspectorSelectedSharedStyleID: ((String?) -> Void)!
  var setInspectorSelectedParameterID: ((String?) -> Void)!
  var setInspectorLayerSearchQuery: ((String) -> Void)!
  var setInspectorSharedStyleSearchQuery: ((String) -> Void)!
  var setInspectorParameterSearchQuery: ((String) -> Void)!
  var revealInspectorSelectionTab: (() -> Void)!
  var setSelectedEntitiesSharedStyle: ((String?) -> Bool)!
  var setSelectedEntityLayer: ((String) -> Void)!
  var deleteSelectedEntity: (() -> Void)!
  var setActiveLayer: ((String) -> Void)!
  var renameLayer: ((ProjectLayer, String) -> Bool)!
  var setLayerVisibility: ((ProjectLayer, Bool) -> Void)!
  var setLayerPrintable: ((ProjectLayer, Bool) -> Void)!
  var setLayerStyle: ((ProjectLayer) -> Bool)!
  var deleteLayer: ((ProjectLayer) -> Void)!
  var addLayer: (() -> Void)!
  var updateSharedStyle: ((ProjectSharedStyle) -> Bool)!
  var deleteSharedStyle: ((ProjectSharedStyle) -> Void)!
  var addSharedStyle: (() -> Void)!
  var addParameter: (() -> Void)!
  var updateFreeText: ((ProjectFreeText) -> Bool)!
  var deleteSelectedFreeText: (() -> Void)!
  var deleteConstraint: ((ProjectConstraint) -> Void)!
  var selectConstraint: ((String?) -> Void)!
  var selectMeasurementAnnotation: ((String?) -> Void)!
  var deleteMeasurementAnnotation: ((ProjectMeasurementAnnotation) -> Void)!
  var convertMeasurementAnnotationToConstraint: ((String) -> Void)!
  var hoverConstraint: ((String?) -> Void)!
  var constrainSelectedLineLengthsEqual: (() -> Void)!
  var setConstraintDegrees: ((ProjectConstraint, Double) -> Bool)!
  var setConstraintValue: ((ProjectConstraint, Double) -> Bool)!
  var setConstraintParameter: ((ProjectConstraint, ProjectParameter) -> Bool)!
  var setDerivedElementDirection: ((ProjectDerivedElement, OffsetDirection) -> Bool)!
  var reverseDerivedElementDirection: ((ProjectDerivedElement) -> Bool)!
  var setDerivedElementDistance: ((ProjectDerivedElement, Double) -> Bool)!
  var setDerivedElementParameter: ((ProjectDerivedElement, ProjectParameter) -> Bool)!
  var setSelectedRoundHoleKind: ((ProjectRoundHoleKind) -> Bool)!
  var setSelectedRoundHoleDiameter: ((Double) -> Bool)!
  var constrainSelectedLineLength: (() -> Void)!
  var setSelectedLineLength: ((Double) -> Bool)!
  var setSelectedCircleRadius: ((Double) -> Bool)!
  var setSelectedArc: ((Double, Double, Double) -> Bool)!
  var updateParameter: ((ProjectParameter) -> Bool)!
  var deleteParameter: ((ProjectParameter) -> Void)!
  var createPartFromSelection: (() -> Void)!
  var updatePart: ((ProjectPart) -> Bool)!
  var updatePartSettings: ((ProjectPart) -> Bool)!
  var deletePart: ((ProjectPart) -> Void)!
  var selectPartContents: ((ProjectPart) -> Void)!
  var movePart: ((ProjectPart, ModelPoint) -> Bool)!
  var duplicatePart: ((ProjectPart) -> Void)!
  var addSelectionToPart: ((ProjectPart) -> Void)!
  var removeSelectionFromPart: ((ProjectPart) -> Void)!
  var setPartBoundaryFromSelection: ((ProjectPart) -> Void)!
  var beginSettingPartOrigin: ((ProjectPart) -> Void)!
  var togglePartArrangementSelection: ((ProjectPart) -> Void)!
  var alignSelectedParts: ((String) -> Void)!
  var distributeSelectedParts: ((String) -> Void)!
  var addPartToLibrary: ((ProjectPart) -> Void)!
  var insertPartFromLibrary: ((PartLibraryEntry) -> Void)!
  var removePartLibraryEntry: ((PartLibraryEntry) -> Void)!
}

/// UI-only state and actions consumed by Inspector presentation components.
/// The model receives a snapshot and callbacks; composition stays in the
/// feature factory rather than in the view model itself.
final class InspectorFeatureModel: ObservableObject {
  let inspectorTab: InspectorTab
  let inspectorSelectedLayerID: String?
  let inspectorSelectedSharedStyleID: String?
  let inspectorSelectedParameterID: String?
  let inspectorSelectedPartID: String?
  let isSettingPartOrigin: Bool
  let inspectorLayerSearchQuery: String
  let inspectorSharedStyleSearchQuery: String
  let inspectorParameterSearchQuery: String

  let inspectorHasPendingSelectionChange: Bool
  let viewMode: CanvasViewMode
  let activeLayerID: String
  let layers: [ProjectLayer]
  let sharedStyles: [ProjectSharedStyle]
  let parameters: [ProjectParameter]
  let parts: [ProjectPart]
  let arrangementSelectedPartIDs: Set<String>
  let partLibraryEntries: [PartLibraryEntry]
  let entities: [CanvasEntity]
  let constraints: [ProjectConstraint]
  let measurementAnnotations: [ProjectMeasurementAnnotation]
  let freeTexts: [ProjectFreeText]
  let selectedEntity: CanvasEntity?
  let selectedEntities: [CanvasEntity]
  let selectedFreeText: ProjectFreeText?
  let selectedConstraintID: String?
  let selectedMeasurementAnnotation: ProjectMeasurementAnnotation?
  let selectedDerivedElement: ProjectDerivedElement?
  let selectedRoundHole: ProjectRoundHole?
  let filteredInspectorLayers: [ProjectLayer]
  let filteredInspectorSharedStyles: [ProjectSharedStyle]
  let filteredInspectorParameters: [ProjectParameter]
  let shouldShowLayerInspectorSearch: Bool
  let shouldShowSharedStyleInspectorSearch: Bool
  let shouldShowParameterInspectorSearch: Bool
  let canConstrainSelectedLineLengthsEqual: Bool

  let setInspectorTab: (InspectorTab) -> Void
  let setInspectorSelectedLayerID: (String?) -> Void
  let setInspectorSelectedSharedStyleID: (String?) -> Void
  let setInspectorSelectedParameterID: (String?) -> Void
  let setInspectorLayerSearchQuery: (String) -> Void
  let setInspectorSharedStyleSearchQuery: (String) -> Void
  let setInspectorParameterSearchQuery: (String) -> Void
  let revealInspectorSelectionTab: () -> Void
  let setSelectedEntitiesSharedStyle: (String?) -> Bool
  let setSelectedEntityLayer: (String) -> Void
  let deleteSelectedEntity: () -> Void
  let setActiveLayer: (String) -> Void
  let renameLayer: (ProjectLayer, String) -> Bool
  let setLayerVisibility: (ProjectLayer, Bool) -> Void
  let setLayerPrintable: (ProjectLayer, Bool) -> Void
  let setLayerStyle: (ProjectLayer) -> Bool
  let deleteLayer: (ProjectLayer) -> Void
  let addLayer: () -> Void
  let updateSharedStyle: (ProjectSharedStyle) -> Bool
  let deleteSharedStyle: (ProjectSharedStyle) -> Void
  let addSharedStyle: () -> Void
  let addParameter: () -> Void
  let updateFreeText: (ProjectFreeText) -> Bool
  let deleteSelectedFreeText: () -> Void
  let deleteConstraint: (ProjectConstraint) -> Void
  let selectConstraint: (String?) -> Void
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
  let updateParameter: (ProjectParameter) -> Bool
  let deleteParameter: (ProjectParameter) -> Void
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

  init(state: InspectorFeatureViewState, actions: InspectorFeatureActions) {
    self.inspectorTab = state.inspectorTab
    self.inspectorSelectedLayerID = state.inspectorSelectedLayerID
    self.inspectorSelectedSharedStyleID = state.inspectorSelectedSharedStyleID
    self.inspectorSelectedParameterID = state.inspectorSelectedParameterID
    self.inspectorSelectedPartID = state.inspectorSelectedPartID
    self.isSettingPartOrigin = state.isSettingPartOrigin
    self.inspectorLayerSearchQuery = state.inspectorLayerSearchQuery
    self.inspectorSharedStyleSearchQuery = state.inspectorSharedStyleSearchQuery
    self.inspectorParameterSearchQuery = state.inspectorParameterSearchQuery
    self.inspectorHasPendingSelectionChange = state.inspectorHasPendingSelectionChange
    self.viewMode = state.viewMode
    self.activeLayerID = state.activeLayerID
    self.layers = state.layers
    self.sharedStyles = state.sharedStyles
    self.parameters = state.parameters
    self.parts = state.parts
    self.arrangementSelectedPartIDs = state.arrangementSelectedPartIDs
    self.partLibraryEntries = state.partLibraryEntries
    self.entities = state.entities
    self.constraints = state.constraints
    self.measurementAnnotations = state.measurementAnnotations
    self.freeTexts = state.freeTexts
    self.selectedEntity = state.selectedEntity
    self.selectedEntities = state.selectedEntities
    self.selectedFreeText = state.selectedFreeText
    self.selectedConstraintID = state.selectedConstraintID
    self.selectedMeasurementAnnotation = state.selectedMeasurementAnnotation
    self.selectedDerivedElement = state.selectedDerivedElement
    self.selectedRoundHole = state.selectedRoundHole
    self.filteredInspectorLayers = state.filteredInspectorLayers
    self.filteredInspectorSharedStyles = state.filteredInspectorSharedStyles
    self.filteredInspectorParameters = state.filteredInspectorParameters
    self.shouldShowLayerInspectorSearch = state.shouldShowLayerInspectorSearch
    self.shouldShowSharedStyleInspectorSearch = state.shouldShowSharedStyleInspectorSearch
    self.shouldShowParameterInspectorSearch = state.shouldShowParameterInspectorSearch
    self.canConstrainSelectedLineLengthsEqual = state.canConstrainSelectedLineLengthsEqual
    self.setInspectorTab = actions.setInspectorTab
    self.setInspectorSelectedLayerID = actions.setInspectorSelectedLayerID
    self.setInspectorSelectedSharedStyleID = actions.setInspectorSelectedSharedStyleID
    self.setInspectorSelectedParameterID = actions.setInspectorSelectedParameterID
    self.setInspectorLayerSearchQuery = actions.setInspectorLayerSearchQuery
    self.setInspectorSharedStyleSearchQuery = actions.setInspectorSharedStyleSearchQuery
    self.setInspectorParameterSearchQuery = actions.setInspectorParameterSearchQuery
    self.revealInspectorSelectionTab = actions.revealInspectorSelectionTab
    self.setSelectedEntitiesSharedStyle = actions.setSelectedEntitiesSharedStyle
    self.setSelectedEntityLayer = actions.setSelectedEntityLayer
    self.deleteSelectedEntity = actions.deleteSelectedEntity
    self.setActiveLayer = actions.setActiveLayer
    self.renameLayer = actions.renameLayer
    self.setLayerVisibility = actions.setLayerVisibility
    self.setLayerPrintable = actions.setLayerPrintable
    self.setLayerStyle = actions.setLayerStyle
    self.deleteLayer = actions.deleteLayer
    self.addLayer = actions.addLayer
    self.updateSharedStyle = actions.updateSharedStyle
    self.deleteSharedStyle = actions.deleteSharedStyle
    self.addSharedStyle = actions.addSharedStyle
    self.addParameter = actions.addParameter
    self.updateFreeText = actions.updateFreeText
    self.deleteSelectedFreeText = actions.deleteSelectedFreeText
    self.deleteConstraint = actions.deleteConstraint
    self.selectConstraint = actions.selectConstraint
    self.selectMeasurementAnnotation = actions.selectMeasurementAnnotation
    self.deleteMeasurementAnnotation = actions.deleteMeasurementAnnotation
    self.convertMeasurementAnnotationToConstraint = actions.convertMeasurementAnnotationToConstraint
    self.hoverConstraint = actions.hoverConstraint
    self.constrainSelectedLineLengthsEqual = actions.constrainSelectedLineLengthsEqual
    self.setConstraintDegrees = actions.setConstraintDegrees
    self.setConstraintValue = actions.setConstraintValue
    self.setConstraintParameter = actions.setConstraintParameter
    self.setDerivedElementDirection = actions.setDerivedElementDirection
    self.reverseDerivedElementDirection = actions.reverseDerivedElementDirection
    self.setDerivedElementDistance = actions.setDerivedElementDistance
    self.setDerivedElementParameter = actions.setDerivedElementParameter
    self.setSelectedRoundHoleKind = actions.setSelectedRoundHoleKind
    self.setSelectedRoundHoleDiameter = actions.setSelectedRoundHoleDiameter
    self.constrainSelectedLineLength = actions.constrainSelectedLineLength
    self.setSelectedLineLength = actions.setSelectedLineLength
    self.setSelectedCircleRadius = actions.setSelectedCircleRadius
    self.setSelectedArc = actions.setSelectedArc
    self.updateParameter = actions.updateParameter
    self.deleteParameter = actions.deleteParameter
    self.createPartFromSelection = actions.createPartFromSelection
    self.updatePart = actions.updatePart
    self.updatePartSettings = actions.updatePartSettings
    self.deletePart = actions.deletePart
    self.selectPartContents = actions.selectPartContents
    self.movePart = actions.movePart
    self.duplicatePart = actions.duplicatePart
    self.addSelectionToPart = actions.addSelectionToPart
    self.removeSelectionFromPart = actions.removeSelectionFromPart
    self.setPartBoundaryFromSelection = actions.setPartBoundaryFromSelection
    self.beginSettingPartOrigin = actions.beginSettingPartOrigin
    self.togglePartArrangementSelection = actions.togglePartArrangementSelection
    self.alignSelectedParts = actions.alignSelectedParts
    self.distributeSelectedParts = actions.distributeSelectedParts
    self.addPartToLibrary = actions.addPartToLibrary
    self.insertPartFromLibrary = actions.insertPartFromLibrary
    self.removePartLibraryEntry = actions.removePartLibraryEntry
  }
}
