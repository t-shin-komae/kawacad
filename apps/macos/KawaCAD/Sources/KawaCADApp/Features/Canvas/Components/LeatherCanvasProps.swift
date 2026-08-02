import CoreGraphics
import KawaCADOutput

/// Immutable render input for the AppKit canvas.
///
/// Keeping this separate from callbacks makes the canvas boundary equivalent to
/// a React component's props: rendering reads `LeatherCanvasState`; all user
/// initiated work goes through `LeatherCanvasActions`.
struct LeatherCanvasState {
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
  let selectedEntityID: String?
  let selectedEntityIDs: Set<String>
  let filletDraftEntityIDs: Set<String>
  let filletDraftClosed: Bool?
  let selectedConstraintID: String?
  let selectedMeasurementAnnotationID: String?
  let selectedFreeTextID: String?
  let selectedStitchStartPointID: String?
  let selectedPartOrigin: ModelPoint?
  let highlightedPartEntityIDs: Set<String>
  let highlightedPartFreeTextIDs: Set<String>
  let highlightedPartMeasurementAnnotationIDs: Set<String>
  let highlightedPartStitchStartPointIDs: Set<String>
  let isSettingPartOrigin: Bool
  let freeTextInlineEditRequestID: String?
  let hoveredConstraintID: String?
  let pendingConstraintTargets: [CanvasSelectionTarget]
  let viewMode: CanvasViewMode
  let selectedTool: CanvasTool
  let draftStartPoint: ModelPoint?
  let draftArcStartPoint: ModelPoint?
  let draftCurrentPoint: ModelPoint?
  let draftArcSweepAngleRad: Double?
  let gridVisible: Bool
  let a4ReferenceVisible: Bool
  let a4ReferenceOrientation: OutputPrintOrientation
  let gridSnapEnabled: Bool
  let pointSnapEnabled: Bool
  let outputPreviewModel: OutputDocumentModel?
  let zoomScale: Double
  let panOffset: CGSize
}

/// Effect boundary for the AppKit canvas. The canvas never reaches into
/// `AppCoordinator`, process bridges, or persistence services directly.
struct LeatherCanvasActions {
  let selectEntity: (String?) -> Void
  let toggleEntitySelection: (String?) -> Void
  let selectEntities: (Set<String>, Bool) -> Void
  let selectConstraint: (String?) -> Void
  let selectMeasurementAnnotation: (String?) -> Void
  let selectFreeText: (String?) -> Void
  let selectStitchStartPoint: (String?) -> Void
  let setPartOrigin: (ModelPoint) -> Void
  let updateFreeText: (ProjectFreeText) -> Bool
  let freeTextInlineEditRequestHandled: (String) -> Void
  let hoverConstraint: (String?) -> Void
  let selectTarget: (CanvasSelectionTarget?) -> Void
  let placePoint: (ModelPoint, CanvasPlacementModifiers) -> Void
  let hoverPoint: (ModelPoint, CanvasPlacementModifiers) -> Void
  let cursorPoint: (ModelPoint?, CGPoint?) -> Void
  let previewMoveEntity: (String, ModelPoint) -> Void
  let previewMoveEntities: (Set<String>, ModelPoint, Bool) -> Void
  let previewMoveControlPoint: (CanvasSelectionTarget, ModelPoint) -> Void
  let cancelMovePreview: () -> Void
  let moveEntity: (String, ModelPoint) -> Void
  let moveEntities: (Set<String>, ModelPoint, Bool) -> Void
  let moveControlPoint: (CanvasSelectionTarget, ModelPoint) -> Void
  let moveMeasurementAnnotation: (String, ModelPoint, Bool) -> Void
  let moveDimensionConstraintAnnotation: (String, ModelPoint, Bool) -> Void
  let convertMeasurementAnnotationToConstraint: (String) -> Void
  let smoothSelectedArcTangenciesPrototype: () -> Void
  let cancelInteraction: () -> Void
  let activateTool: (CanvasTool) -> Void
  let deleteSelection: () -> Void
  let panCanvas: (CGSize) -> Void
  let setCanvasViewport: (Double, CGSize, String) -> Void
  let copySelection: () -> Void
  let pasteCopiedEntity: () -> Void
  let pasteCopiedEntityAtPoint: (ModelPoint) -> Void
  let duplicateSelection: () -> Void
  let selectAllEntities: () -> Void
}
