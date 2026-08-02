import Combine
import CoreGraphics

/// A single source of truth for entity selection.
/// `primaryEntityID` preserves the last focused entity while `entityIDs`
/// represents the complete multi-selection set.
private struct EntitySelectionState {
  var primaryEntityID: String?
  var entityIDs: Set<String> = []

  mutating func setPrimaryEntityID(_ entityID: String?) {
    primaryEntityID = entityID
  }

  mutating func setEntityIDs(_ ids: Set<String>) {
    entityIDs = ids
    guard let primaryEntityID, ids.contains(primaryEntityID) else {
      primaryEntityID = ids.sorted().first
      return
    }
  }
}

/// Canvas-owned presentation state. Core document and preview state remain in
/// `CadSessionState`; gesture-local drag state remains inside `LeatherCanvas`.
final class CanvasPresentationState: ObservableObject {
  @Published private(set) var selectedTool: CanvasTool = .select
  @Published private(set) var viewMode: CanvasViewMode = .editDisplay
  @Published private var entitySelection = EntitySelectionState()
  let annotationSelection: AnnotationSelectionState
  @Published private(set) var freeTextInlineEditRequestID: String?
  @Published private(set) var hoveredConstraintID: String?
  @Published private(set) var activeLayerID = "layer:cut-line"
  @Published private(set) var activePatternLineStyleID = "style:outer-cut-line"
  @Published private(set) var activeRoundHoleKind: ProjectRoundHoleKind = .keyRing
  @Published private(set) var activeRoundHoleDiameterMM = 5.0
  @Published private(set) var activeRoundHoleDiameterInputValid = true
  @Published private(set) var pendingConstraintTargets: [CanvasSelectionTarget] = []
  @Published private(set) var pendingConstraintValueDraft: PendingConstraintValueDraft?
  @Published private(set) var cursorModelPoint: ModelPoint?
  @Published private(set) var cursorCanvasPoint: CGPoint?
  @Published private(set) var draftStartPoint: ModelPoint?
  @Published private(set) var draftCurrentPoint: ModelPoint?
  @Published private(set) var draftArcStartPoint: ModelPoint?
  @Published private(set) var draftArcSweepAngleRad: Double?
  @Published private(set) var zoomScale = 1.0
  @Published private(set) var panOffset: CGSize = .zero
  @Published private(set) var layerPanelVisible = true
  @Published private(set) var parameterPanelVisible = true

  private(set) var selectedEntityID: String? {
    get { entitySelection.primaryEntityID }
    set { entitySelection.setPrimaryEntityID(newValue) }
  }

  private(set) var selectedEntityIDs: Set<String> {
    get { entitySelection.entityIDs }
    set { entitySelection.setEntityIDs(newValue) }
  }

  var selectedConstraintID: String? { annotationSelection.selectedConstraintID }

  var selectedMeasurementAnnotationID: String? {
    annotationSelection.selectedMeasurementAnnotationID
  }

  var selectedFreeTextID: String? { annotationSelection.selectedFreeTextID }

  var selectedStitchStartPointID: String? {
    annotationSelection.selectedStitchStartPointID
  }

  init(annotationSelection: AnnotationSelectionState = AnnotationSelectionState()) {
    self.annotationSelection = annotationSelection
  }

  func clearSelection() {
    selectedEntityID = nil
    selectedEntityIDs = []
    annotationSelection.clear()
    freeTextInlineEditRequestID = nil
  }

  func setSelectedTool(_ tool: CanvasTool) {
    selectedTool = tool
  }

  func setViewMode(_ mode: CanvasViewMode) {
    viewMode = mode
  }

  func setFreeTextInlineEditRequestID(_ id: String?) {
    freeTextInlineEditRequestID = id
  }

  func setHoveredConstraintID(_ id: String?) {
    hoveredConstraintID = id
  }

  func setActiveLayerID(_ id: String) {
    activeLayerID = id
  }

  func setActivePatternLineStyleID(_ id: String) {
    activePatternLineStyleID = id
  }

  func setActiveRoundHole(kind: ProjectRoundHoleKind) {
    activeRoundHoleKind = kind
  }

  func setActiveRoundHole(diameterMM: Double) {
    activeRoundHoleDiameterMM = diameterMM
    activeRoundHoleDiameterInputValid = diameterMM.isFinite && diameterMM > 0
  }

  func setActiveRoundHoleDiameterInputValid(_ valid: Bool) {
    activeRoundHoleDiameterInputValid = valid
  }

  func setPendingConstraintTargets(_ targets: [CanvasSelectionTarget]) {
    pendingConstraintTargets = targets
  }

  func appendPendingConstraintTarget(_ target: CanvasSelectionTarget) {
    pendingConstraintTargets.append(target)
  }

  func removeLastPendingConstraintTarget() {
    guard !pendingConstraintTargets.isEmpty else { return }
    pendingConstraintTargets.removeLast()
  }

  func setPendingConstraintValueDraft(_ draft: PendingConstraintValueDraft?) {
    pendingConstraintValueDraft = draft
  }

  func updatePendingConstraintValueDraft(
    _ update: (inout PendingConstraintValueDraft) -> Void
  ) {
    guard var draft = pendingConstraintValueDraft else { return }
    update(&draft)
    pendingConstraintValueDraft = draft
  }

  func setCursor(modelPoint: ModelPoint?, canvasPoint: CGPoint?) {
    cursorModelPoint = modelPoint
    cursorCanvasPoint = canvasPoint
  }

  func setDraftStartPoint(_ point: ModelPoint?) {
    draftStartPoint = point
  }

  func setDraftCurrentPoint(_ point: ModelPoint?) {
    draftCurrentPoint = point
  }

  func setDraftArcStartPoint(_ point: ModelPoint?) {
    draftArcStartPoint = point
  }

  func setDraftArcSweepAngle(_ angle: Double?) {
    draftArcSweepAngleRad = angle
  }

  func setViewport(zoomScale: Double, panOffset: CGSize) {
    self.zoomScale = zoomScale
    self.panOffset = panOffset
  }

  func setLayerPanelVisible(_ visible: Bool) {
    layerPanelVisible = visible
  }

  func setParameterPanelVisible(_ visible: Bool) {
    parameterPanelVisible = visible
  }

  func setPrimaryEntityID(_ id: String?) {
    selectedEntityID = id
  }

  func setEntityIDs(_ ids: Set<String>) {
    selectedEntityIDs = ids
  }

  func setConstraintID(_ id: String?) {
    annotationSelection.setSelectedConstraintID(id)
  }

  func setMeasurementAnnotationID(_ id: String?) {
    annotationSelection.setSelectedMeasurementAnnotationID(id)
  }

  func setFreeTextID(_ id: String?) {
    annotationSelection.setSelectedFreeTextID(id)
  }

  func setStitchStartPointID(_ id: String?) {
    annotationSelection.setSelectedStitchStartPointID(id)
  }

  func selectConstraint(_ constraintID: String?) {
    selectedEntityID = nil
    selectedEntityIDs = []
    annotationSelection.clear()
    annotationSelection.setSelectedConstraintID(constraintID)
    freeTextInlineEditRequestID = nil
  }

  func selectEntity(_ entityID: String) {
    selectedEntityID = entityID
    selectedEntityIDs = [entityID]
    annotationSelection.clear()
    freeTextInlineEditRequestID = nil
  }

  func toggleEntitySelection(_ entityID: String) {
    var next = selectedEntityIDs
    if next.contains(entityID) {
      next.remove(entityID)
      selectedEntityIDs = next
    } else {
      next.insert(entityID)
      selectedEntityIDs = next
      selectedEntityID = entityID
    }
    annotationSelection.clear()
    freeTextInlineEditRequestID = nil
  }

  func selectEntities(
    _ entityIDs: Set<String>,
    validEntityIDs: Set<String>,
    extendingSelection: Bool
  ) {
    let filteredIDs = entityIDs.intersection(validEntityIDs)
    selectedEntityIDs =
      extendingSelection
      ? selectedEntityIDs.symmetricDifference(filteredIDs)
      : filteredIDs
    annotationSelection.clear()
    freeTextInlineEditRequestID = nil
  }

  func selectFreeText(_ freeTextID: String?) {
    selectedEntityID = nil
    selectedEntityIDs = []
    annotationSelection.clear()
    annotationSelection.setSelectedFreeTextID(freeTextID)
    freeTextInlineEditRequestID = nil
  }

  func selectStitchStartPoint(_ stitchStartPointID: String?) {
    selectedEntityID = nil
    selectedEntityIDs = []
    annotationSelection.clear()
    annotationSelection.setSelectedStitchStartPointID(stitchStartPointID)
    freeTextInlineEditRequestID = nil
  }

  func clearPlacementDraft() {
    draftStartPoint = nil
    draftCurrentPoint = nil
    draftArcStartPoint = nil
    draftArcSweepAngleRad = nil
  }

  func resetForLoadedDocument() {
    selectedTool = .select
    clearSelection()
    hoveredConstraintID = nil
    pendingConstraintTargets = []
    pendingConstraintValueDraft = nil
    activeLayerID = "layer:cut-line"
    activePatternLineStyleID = "style:outer-cut-line"
    activeRoundHoleDiameterInputValid = true
    clearPlacementDraft()
  }
}
