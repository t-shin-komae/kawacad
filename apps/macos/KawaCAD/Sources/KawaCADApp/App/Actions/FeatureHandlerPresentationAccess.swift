import CoreGraphics
import KawaCADOutput

/// Feature-scoped accessors for presentation state.
///
/// These are intentionally attached to the owning feature handlers. They are
/// useful to SwiftUI props and focused tests, while the aggregate remains a
/// composition object rather than a compatibility surface.
extension CanvasActionHandler {
  var selectedTool: CanvasTool {
    get { canvasPresentation.selectedTool }
    set { canvasPresentation.setSelectedTool(newValue) }
  }

  var viewMode: CanvasViewMode {
    get { canvasPresentation.viewMode }
    set { canvasPresentation.setViewMode(newValue) }
  }

  var freeTextInlineEditRequestID: String? {
    get { canvasPresentation.freeTextInlineEditRequestID }
    set { canvasPresentation.setFreeTextInlineEditRequestID(newValue) }
  }

  var activeLayerID: String {
    get { canvasPresentation.activeLayerID }
    set { canvasPresentation.setActiveLayerID(newValue) }
  }

  var activePatternLineStyleID: String {
    get { canvasPresentation.activePatternLineStyleID }
    set { canvasPresentation.setActivePatternLineStyleID(newValue) }
  }

  var activeRoundHoleKind: ProjectRoundHoleKind {
    get { canvasPresentation.activeRoundHoleKind }
    set { canvasPresentation.setActiveRoundHole(kind: newValue) }
  }

  var activeRoundHoleDiameterMM: Double {
    get { canvasPresentation.activeRoundHoleDiameterMM }
    set { canvasPresentation.setActiveRoundHole(diameterMM: newValue) }
  }

  func setActiveRoundHoleDiameterInputValid(_ valid: Bool) {
    canvasPresentation.setActiveRoundHoleDiameterInputValid(valid)
  }

  var pendingConstraintTargets: [CanvasSelectionTarget] {
    get { canvasPresentation.pendingConstraintTargets }
    set { canvasPresentation.setPendingConstraintTargets(newValue) }
  }

  var pendingConstraintValueDraft: PendingConstraintValueDraft? {
    get { canvasPresentation.pendingConstraintValueDraft }
    set { canvasPresentation.setPendingConstraintValueDraft(newValue) }
  }

  var cursorModelPoint: ModelPoint? {
    get { canvasPresentation.cursorModelPoint }
    set {
      canvasPresentation.setCursor(
        modelPoint: newValue, canvasPoint: canvasPresentation.cursorCanvasPoint)
    }
  }

  var cursorCanvasPoint: CGPoint? {
    get { canvasPresentation.cursorCanvasPoint }
    set {
      canvasPresentation.setCursor(
        modelPoint: canvasPresentation.cursorModelPoint, canvasPoint: newValue)
    }
  }

  var draftStartPoint: ModelPoint? {
    get { canvasPresentation.draftStartPoint }
    set { canvasPresentation.setDraftStartPoint(newValue) }
  }

  var draftCurrentPoint: ModelPoint? {
    get { canvasPresentation.draftCurrentPoint }
    set { canvasPresentation.setDraftCurrentPoint(newValue) }
  }

  var draftArcStartPoint: ModelPoint? {
    get { canvasPresentation.draftArcStartPoint }
    set { canvasPresentation.setDraftArcStartPoint(newValue) }
  }

  var draftArcSweepAngleRad: Double? {
    get { canvasPresentation.draftArcSweepAngleRad }
    set { canvasPresentation.setDraftArcSweepAngle(newValue) }
  }

  var canvasZoomScale: Double {
    get { canvasPresentation.zoomScale }
    set {
      canvasPresentation.setViewport(zoomScale: newValue, panOffset: canvasPresentation.panOffset)
    }
  }

  var canvasPanOffset: CGSize {
    get { canvasPresentation.panOffset }
    set {
      canvasPresentation.setViewport(zoomScale: canvasPresentation.zoomScale, panOffset: newValue)
    }
  }

  var layerPanelVisible: Bool {
    get { canvasPresentation.layerPanelVisible }
    set { canvasPresentation.setLayerPanelVisible(newValue) }
  }

  var parameterPanelVisible: Bool {
    get { canvasPresentation.parameterPanelVisible }
    set { canvasPresentation.setParameterPanelVisible(newValue) }
  }
}

extension DocumentActionHandler {
  var alertMessage: UserAlertMessage? {
    get { documentPresentation.alertMessage }
    set { documentPresentation.setAlertMessage(newValue) }
  }

  var layerDeletionConfirmation: LayerDeletionConfirmation? {
    get { documentPresentation.layerDeletionConfirmation }
    set { documentPresentation.setLayerDeletionConfirmation(newValue) }
  }

  var documentSaveConfirmation: DocumentSaveConfirmation? {
    get { documentPresentation.saveConfirmation }
    set { documentPresentation.setSaveConfirmation(newValue) }
  }

  var clipboardBundle: ClipboardBundle? {
    get { documentPresentation.clipboardBundle }
    set { documentPresentation.setClipboardBundle(newValue) }
  }

  var pasteOptionsPresentation: PasteOptionsPresentation? {
    get { documentPresentation.pasteOptions }
    set { documentPresentation.setPasteOptions(newValue) }
  }

}

extension WorkspaceActionHandler {
  var gridVisible: Bool {
    get { workspacePreferences.gridVisible }
    set { workspacePreferences.setGridVisible(newValue) }
  }

  var a4ReferenceVisible: Bool {
    get { workspacePreferences.a4ReferenceVisible }
    set { workspacePreferences.setA4ReferenceVisible(newValue) }
  }

  var a4ReferenceOrientation: OutputPrintOrientation {
    get { workspacePreferences.a4ReferenceOrientation }
    set { workspacePreferences.setA4ReferenceOrientation(newValue) }
  }

  var gridSnapEnabled: Bool {
    get { workspacePreferences.gridSnapEnabled }
    set { workspacePreferences.setGridSnapEnabled(newValue) }
  }

  var pointSnapEnabled: Bool {
    get { workspacePreferences.pointSnapEnabled }
    set { workspacePreferences.setPointSnapEnabled(newValue) }
  }

  var inspectorPanelVisible: Bool {
    get { workspacePreferences.inspectorPanelVisible }
    set { workspacePreferences.setInspectorPanelVisible(newValue) }
  }

  var detailedToolsVisible: Bool {
    get { workspacePreferences.detailedToolsVisible }
    set { workspacePreferences.setDetailedToolsVisible(newValue) }
  }

  var bottomWorkbenchVisible: Bool {
    get { workspacePreferences.bottomWorkbenchVisible }
    set { workspacePreferences.setBottomWorkbenchVisible(newValue) }
  }

  var toolPanelWidth: CGFloat {
    get { workspaceLayout.toolPanelWidth }
    set { workspaceLayout.setToolPanelWidth(newValue) }
  }

  var inspectorPanelWidth: CGFloat {
    get { workspaceLayout.inspectorPanelWidth }
    set { workspaceLayout.setInspectorPanelWidth(newValue) }
  }

  var compactDrawer: CompactDrawer? {
    get { workspaceLayout.compactDrawer }
    set { workspaceLayout.setCompactDrawer(newValue) }
  }

  var windowLayoutMode: WindowLayoutMode {
    get { workspaceLayout.windowLayoutMode }
    set { workspaceLayout.setWindowLayoutMode(newValue) }
  }
}

extension InspectorActionHandler {
  var inspectorTab: InspectorTab {
    get { inspectorPresentation.tab }
    set { setInspectorTab(newValue) }
  }

  var inspectorSelectedLayerID: String? {
    get { inspectorPresentation.selectedLayerID }
    set { inspectorPresentation.setSelectedLayerID(newValue) }
  }

  var inspectorSelectedSharedStyleID: String? {
    get { inspectorPresentation.selectedSharedStyleID }
    set { inspectorPresentation.setSelectedSharedStyleID(newValue) }
  }

  var inspectorSelectedParameterID: String? {
    get { inspectorPresentation.selectedParameterID }
    set { inspectorPresentation.setSelectedParameterID(newValue) }
  }

  var inspectorSelectedPartID: String? {
    get { inspectorPresentation.selectedPartID }
    set { inspectorPresentation.setSelectedPartID(newValue) }
  }

  var isSettingPartOrigin: Bool {
    get { inspectorPresentation.isSettingPartOrigin }
    set { inspectorPresentation.setIsSettingPartOrigin(newValue) }
  }

  var inspectorLayerSearchQuery: String {
    get { inspectorPresentation.layerSearchQuery }
    set { inspectorPresentation.setLayerSearchQuery(newValue) }
  }

  var inspectorSharedStyleSearchQuery: String {
    get { inspectorPresentation.sharedStyleSearchQuery }
    set { inspectorPresentation.setSharedStyleSearchQuery(newValue) }
  }

  var inspectorParameterSearchQuery: String {
    get { inspectorPresentation.parameterSearchQuery }
    set { inspectorPresentation.setParameterSearchQuery(newValue) }
  }

  var inspectorLayerSearchVisible: Bool {
    get { inspectorPresentation.layerSearchVisible }
    set { inspectorPresentation.setLayerSearchVisible(newValue) }
  }

  var inspectorSharedStyleSearchVisible: Bool {
    get { inspectorPresentation.sharedStyleSearchVisible }
    set { inspectorPresentation.setSharedStyleSearchVisible(newValue) }
  }

  var inspectorParameterSearchVisible: Bool {
    get { inspectorPresentation.parameterSearchVisible }
    set { inspectorPresentation.setParameterSearchVisible(newValue) }
  }

  var inspectorHasPendingSelectionChange: Bool {
    let signature = InspectorViewStateFactory.selectionSignature(
      primaryEntityID: selectedEntityID,
      entityIDs: selectedEntityIDs,
      selectedConstraintID: selectedConstraintID,
      selectedMeasurementAnnotationID: selectedMeasurementAnnotationID,
      selectedFreeTextID: selectedFreeTextID,
      selectedStitchStartPointID: selectedStitchStartPointID
    )
    return InspectorViewStateFactory.hasPendingSelectionChange(
      tab: inspectorPresentation.tab,
      selectionSignature: signature,
      acknowledgedSelectionSignature: inspectorPresentation.acknowledgedSelectionSignature
    )
  }

  var shouldShowLayerInspectorSearch: Bool {
    InspectorViewStateFactory.shouldShowSearch(
      itemCount: layers.count,
      explicitlyVisible: inspectorPresentation.layerSearchVisible,
      query: inspectorPresentation.layerSearchQuery
    )
  }

  var shouldShowParameterInspectorSearch: Bool {
    InspectorViewStateFactory.shouldShowSearch(
      itemCount: parameters.count,
      explicitlyVisible: inspectorPresentation.parameterSearchVisible,
      query: inspectorPresentation.parameterSearchQuery
    )
  }

  var filteredInspectorLayers: [ProjectLayer] {
    InspectorViewStateFactory.filteredLayers(layers, query: inspectorPresentation.layerSearchQuery)
  }

  var filteredInspectorParameters: [ProjectParameter] {
    InspectorViewStateFactory.filteredParameters(
      parameters, query: inspectorPresentation.parameterSearchQuery)
  }
}

extension WorkspaceActionHandler {
  var errorPresentation: AppErrorPresentation? { errorPresentationState.presentation }
}

extension OutputActionHandler {
  var outputRequestDraft: OutputRequestDraft? {
    get { outputPresentation.requestDraft }
    set { outputPresentation.setRequestDraft(newValue) }
  }

  var outputPreviewBuildResult: OutputBuildResult? {
    get { outputPresentation.previewBuildResult }
    set { outputPresentation.setPreviewBuildResult(newValue) }
  }
}

extension RecoveryActionHandler {
  var recoveryBanner: DocumentRecoveryBannerState? {
    get { recoverySnapshotState.banner }
    set { recoverySnapshotState.setBanner(newValue) }
  }

  var recoveryChooser: DocumentRecoveryChooserState? {
    get { recoverySnapshotState.chooser }
    set { recoverySnapshotState.setChooser(newValue) }
  }
}
