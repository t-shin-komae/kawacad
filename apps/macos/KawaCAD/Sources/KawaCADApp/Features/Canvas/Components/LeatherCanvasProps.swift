import CoreGraphics
import KawaCADOutput

struct LeatherCanvasDocumentDisplay {
  let entities: [CanvasEntity]
  let canvasProjection: LeatherCanvasProjection
  let constraints: [ProjectConstraint]
  let freeTexts: [ProjectFreeText]
  let stitchStartPoints: [ProjectStitchStartPoint]
  let measurementAnnotations: [ProjectMeasurementAnnotation]
  let measurementEvaluations: [MeasurementEvaluation]
  let dimensionConstraintAnnotations: [ProjectDimensionConstraintAnnotation]
  let parameters: [ProjectParameter]
  let derivedElements: [ProjectDerivedElement]
  let layers: [ProjectLayer]
  let sharedStyles: [ProjectSharedStyle]
  let coincidentPointGroups: [CoincidentPointGroup]
}

struct LeatherCanvasSelectionDisplay {
  let selectedEntityID: String?
  let selectedEntityIDs: Set<String>
  let selectedConstraintID: String?
  let selectedMeasurementAnnotationID: String?
  let selectedFreeTextID: String?
  let selectedStitchStartPointID: String?
  let highlightedPartEntityIDs: Set<String>
  let highlightedPartFreeTextIDs: Set<String>
  let highlightedPartMeasurementAnnotationIDs: Set<String>
  let highlightedPartStitchStartPointIDs: Set<String>
  let hoveredConstraintID: String?
  let pendingConstraintTargets: [CanvasSelectionTarget]
}

struct LeatherCanvasDraftDisplay {
  let filletDraftEntityIDs: Set<String>
  let filletDraftClosed: Bool?
  let selectedPartOrigin: ModelPoint?
  let selectedTool: CanvasTool
  let draftStartPoint: ModelPoint?
  let draftArcStartPoint: ModelPoint?
  let draftCurrentPoint: ModelPoint?
  let draftArcSweepAngleRad: Double?
}

struct LeatherCanvasViewportDisplay {
  let viewMode: CanvasViewMode
  let gridVisible: Bool
  let a4ReferenceVisible: Bool
  let a4ReferenceOrientation: OutputPrintOrientation
  let gridSnapEnabled: Bool
  let pointSnapEnabled: Bool
  let outputPreviewModel: OutputDocumentModel?
  let zoomScale: Double
  let panOffset: CGSize
}

struct LeatherCanvasRenderInput {
  let document: LeatherCanvasDocumentDisplay
  let selection: LeatherCanvasSelectionDisplay
  let draft: LeatherCanvasDraftDisplay
  let viewport: LeatherCanvasViewportDisplay
}

struct LeatherCanvasInteractionInput {
  let isSettingPartOrigin: Bool
  let freeTextInlineEditRequestID: String?
}

struct LeatherCanvasActionGroups {
  let selection: LeatherCanvasSelectionActions
  let placement: LeatherCanvasPlacementActions
  let move: LeatherCanvasMoveActions
  let viewport: LeatherCanvasViewportActions
  let editing: LeatherCanvasEditingActions
}

struct LeatherCanvasSelectionActions {
  let selectEntity: (String?) -> Void
  let toggleEntitySelection: (String?) -> Void
  let selectEntities: (Set<String>, Bool) -> Void
  let selectConstraint: (String?) -> Void
  let selectMeasurementAnnotation: (String?) -> Void
  let selectFreeText: (String?) -> Void
  let selectStitchStartPoint: (String?) -> Void
  let hoverConstraint: (String?) -> Void
  let selectTarget: (CanvasSelectionTarget?) -> Void
  let deleteSelection: () -> Void
  let selectAllEntities: () -> Void
}

struct LeatherCanvasPlacementActions {
  let setPartOrigin: (ModelPoint) -> Void
  let placePoint: (ModelPoint, CanvasPlacementModifiers) -> Void
  let hoverPoint: (ModelPoint, CanvasPlacementModifiers) -> Void
  let cursorPoint: (ModelPoint?, CGPoint?) -> Void
}

struct LeatherCanvasMoveActions {
  let previewMoveEntity: (String, ModelPoint) -> Void
  let previewMoveEntities: (Set<String>, ModelPoint, Bool) -> Void
  let previewMoveControlPoint: (CanvasSelectionTarget, ModelPoint) -> Void
  let cancelMovePreview: () -> Void
  let moveEntity: (String, ModelPoint) -> Void
  let moveEntities: (Set<String>, ModelPoint, Bool) -> Void
  let moveControlPoint: (CanvasSelectionTarget, ModelPoint) -> Void
  let moveMeasurementAnnotation: (String, ModelPoint, Bool) -> Void
  let moveDimensionConstraintAnnotation: (String, ModelPoint, Bool) -> Void
}

struct LeatherCanvasViewportActions {
  let panCanvas: (CGSize) -> Void
  let setCanvasViewport: (Double, CGSize, String) -> Void
}

struct LeatherCanvasEditingActions {
  let updateFreeText: (ProjectFreeText) -> Bool
  let freeTextInlineEditRequestHandled: (String) -> Void
  let convertMeasurementAnnotationToConstraint: (String) -> Void
  let smoothSelectedArcTangenciesPrototype: () -> Void
  let cancelInteraction: () -> Void
  let activateTool: (CanvasTool) -> Void
  let copySelection: () -> Void
  let pasteCopiedEntity: () -> Void
  let pasteCopiedEntityAtPoint: (ModelPoint) -> Void
  let duplicateSelection: () -> Void
}

extension LeatherCanvasView {
  var entities: [CanvasEntity] { renderInput.document.entities }
  var canvasProjection: LeatherCanvasProjection { renderInput.document.canvasProjection }
  var documentConstraints: [ProjectConstraint] { renderInput.document.constraints }
  var freeTexts: [ProjectFreeText] { renderInput.document.freeTexts }
  var stitchStartPoints: [ProjectStitchStartPoint] { renderInput.document.stitchStartPoints }
  var measurementAnnotations: [ProjectMeasurementAnnotation] {
    renderInput.document.measurementAnnotations
  }
  var measurementEvaluations: [MeasurementEvaluation] {
    renderInput.document.measurementEvaluations
  }
  var dimensionConstraintAnnotations: [ProjectDimensionConstraintAnnotation] {
    renderInput.document.dimensionConstraintAnnotations
  }
  var parameters: [ProjectParameter] { renderInput.document.parameters }
  var derivedElements: [ProjectDerivedElement] { renderInput.document.derivedElements }
  var layers: [ProjectLayer] { renderInput.document.layers }
  var sharedStyles: [ProjectSharedStyle] { renderInput.document.sharedStyles }
  var coincidentPointGroups: [CoincidentPointGroup] { renderInput.document.coincidentPointGroups }

  var selectedEntityID: String? { renderInput.selection.selectedEntityID }
  var selectedEntityIDs: Set<String> { renderInput.selection.selectedEntityIDs }
  var filletDraftEntityIDs: Set<String> { renderInput.draft.filletDraftEntityIDs }
  var filletDraftClosed: Bool? { renderInput.draft.filletDraftClosed }
  var selectedConstraintID: String? { renderInput.selection.selectedConstraintID }
  var selectedMeasurementAnnotationID: String? {
    renderInput.selection.selectedMeasurementAnnotationID
  }
  var selectedFreeTextID: String? { renderInput.selection.selectedFreeTextID }
  var selectedStitchStartPointID: String? {
    renderInput.selection.selectedStitchStartPointID
  }
  var selectedPartOrigin: ModelPoint? { renderInput.draft.selectedPartOrigin }
  var highlightedPartEntityIDs: Set<String> { renderInput.selection.highlightedPartEntityIDs }
  var highlightedPartFreeTextIDs: Set<String> { renderInput.selection.highlightedPartFreeTextIDs }
  var highlightedPartMeasurementAnnotationIDs: Set<String> {
    renderInput.selection.highlightedPartMeasurementAnnotationIDs
  }
  var highlightedPartStitchStartPointIDs: Set<String> {
    renderInput.selection.highlightedPartStitchStartPointIDs
  }
  var isSettingPartOrigin: Bool { interactionInput.isSettingPartOrigin }
  var freeTextInlineEditRequestID: String? { interactionInput.freeTextInlineEditRequestID }
  var hoveredConstraintID: String? { renderInput.selection.hoveredConstraintID }
  var pendingConstraintTargets: [CanvasSelectionTarget] {
    renderInput.selection.pendingConstraintTargets
  }
  var viewMode: CanvasViewMode { renderInput.viewport.viewMode }
  var selectedTool: CanvasTool { renderInput.draft.selectedTool }
  var draftStartPoint: ModelPoint? { renderInput.draft.draftStartPoint }
  var draftArcStartPoint: ModelPoint? { renderInput.draft.draftArcStartPoint }
  var draftCurrentPoint: ModelPoint? { renderInput.draft.draftCurrentPoint }
  var draftArcSweepAngleRad: Double? { renderInput.draft.draftArcSweepAngleRad }
  var gridVisible: Bool { renderInput.viewport.gridVisible }
  var a4ReferenceVisible: Bool { renderInput.viewport.a4ReferenceVisible }
  var a4ReferenceOrientation: OutputPrintOrientation { renderInput.viewport.a4ReferenceOrientation }
  var gridSnapEnabled: Bool { renderInput.viewport.gridSnapEnabled }
  var pointSnapEnabled: Bool { renderInput.viewport.pointSnapEnabled }
  var outputPreviewModel: OutputDocumentModel? { renderInput.viewport.outputPreviewModel }
  var zoomScale: Double { renderInput.viewport.zoomScale }
  var panOffset: CGSize { renderInput.viewport.panOffset }
}
