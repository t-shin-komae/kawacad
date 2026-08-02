import Foundation
import KawaCADOutput

/// Derived selection and command selectors shared by feature handlers.
///
/// These selectors are intentionally kept outside the dependency bundle: the
/// context owns only state/adapters, while this extension derives read-only
/// values from them.
extension ActionHandlerStateAccessProviding {
  var documentName: String {
    currentDocumentState?.snapshot.name ?? AppStrings.tr("app.document.untitled")
  }

  var partLibraryEntries: [PartLibraryEntry] { partLibraryState.entries }

  var layers: [ProjectLayer] { currentDocumentState?.layers ?? [] }
  var sharedStyles: [ProjectSharedStyle] { currentDocumentState?.sharedStyles ?? [] }
  var parameters: [ProjectParameter] { currentDocumentState?.parameters ?? [] }
  var parts: [ProjectPart] { currentDocumentState?.parts ?? [] }
  var entities: [CanvasEntity] { currentDocumentState?.entities ?? [] }
  var coincidentPointGroups: [CoincidentPointGroup] {
    currentDocumentState?.coincidentPointGroups ?? []
  }
  var constraints: [ProjectConstraint] { currentDocumentState?.constraints ?? [] }
  var measurementAnnotations: [ProjectMeasurementAnnotation] {
    currentDocumentState?.measurementAnnotations ?? []
  }
  var measurementEvaluations: [MeasurementEvaluation] {
    currentDocumentState?.measurementEvaluations ?? []
  }
  var freeTexts: [ProjectFreeText] { currentDocumentState?.freeTexts ?? [] }
  var roundHoles: [ProjectRoundHole] { currentDocumentState?.roundHoles ?? [] }
  var stitchStartPoints: [ProjectStitchStartPoint] { currentDocumentState?.stitchStartPoints ?? [] }
  var dimensionConstraintAnnotations: [ProjectDimensionConstraintAnnotation] {
    currentDocumentState?.dimensionConstraintAnnotations ?? []
  }
  var derivedElements: [ProjectDerivedElement] { currentDocumentState?.derivedElements ?? [] }
  var coreSnapshot: LeatherDocumentSnapshot? { currentDocumentState?.snapshot }
  var documentURL: URL? { cadSession.documentURL }
  var currentDocumentState: LeatherDocumentState? { cadSession.state }
  var documentWindowPresentation: DocumentWindowPresentation {
    DocumentWindowPresentation(
      documentName: documentName,
      documentURL: documentURL,
      isDocumentEdited: isDocumentDirty
    )
  }
  var canvasProjection: LeatherCanvasProjection {
    previewCanvasProjection ?? currentDocumentState?.canvasProjection ?? .empty
  }

  var activePatternLineStyle: ProjectSharedStyle? {
    sharedStyles.first(where: { $0.id == canvasPresentation.activePatternLineStyleID })
      ?? sharedStyles.first
  }

  var activePatternDrawingStyleID: String? { activePatternLineStyle?.id }

  private var selectionViewState: WorkspaceSelectionViewState {
    WorkspaceViewStateFactory.makeSelection(
      document: currentDocumentState,
      primaryEntityID: selectedEntityID,
      entityIDs: selectedEntityIDs,
      selectedConstraintID: selectedConstraintID,
      selectedMeasurementAnnotationID: selectedMeasurementAnnotationID,
      selectedFreeTextID: selectedFreeTextID,
      selectedStitchStartPointID: selectedStitchStartPointID
    )
  }

  var selectedEntity: CanvasEntity? { selectionViewState.selectedEntity }
  var selectedEntities: [CanvasEntity] { selectionViewState.selectedEntities }
  var selectedFreeText: ProjectFreeText? { selectionViewState.selectedFreeText }
  var selectedClipboardEntities: [CanvasEntity] { selectionViewState.selectedClipboardEntities }
  var selectedDerivedRootIDs: [String] { selectionViewState.selectedDerivedRootIDs }
  var selectedConstraint: ProjectConstraint? { selectionViewState.selectedConstraint }
  var selectedMeasurementAnnotation: ProjectMeasurementAnnotation? {
    selectionViewState.selectedMeasurementAnnotation
  }
  var hasClipboardSelection: Bool { selectionViewState.hasClipboardSelection }
  var selectedRoundHole: ProjectRoundHole? { selectionViewState.selectedRoundHole }
  var selectedStitchStartPoint: ProjectStitchStartPoint? {
    selectionViewState.selectedStitchStartPoint
  }
  var selectedDerivedElement: ProjectDerivedElement? {
    WorkspaceViewStateFactory.selectedDerivedElement(
      selectedEntities: selectedEntities,
      derivedElements: derivedElements
    )
  }
  var canSmoothSelectedArcTangenciesPrototype: Bool {
    DerivedElementFeature.selectedArcEntityID(
      selectedEntityID: selectedEntityID,
      selectedEntityIDs: selectedEntityIDs,
      entities: entities
    ) != nil
  }

  var aggregatedConstraintStatus: ConstraintStatus {
    WorkspaceViewStateFactory.aggregatedConstraintStatus(
      viewMode: canvasPresentation.viewMode,
      snapshot: coreSnapshot,
      constraints: constraints
    )
  }

  var canEditLayers: Bool { cadSession.hasDocument }
  var canRenameDocument: Bool { cadSession.hasDocument }
  var canSaveProject: Bool { cadSession.hasDocument }
  var canExportPDF: Bool { cadSession.hasDocument }
  var canDirectPrint: Bool { cadSession.hasDocument }

  private var hasPendingInteraction: Bool {
    canvasPresentation.pendingConstraintValueDraft != nil
      || previewEntities != nil
      || previewCanvasProjection != nil
      || previewCoincidentPointGroups != nil
      || canvasPresentation.draftStartPoint != nil
      || canvasPresentation.draftCurrentPoint != nil
      || canvasPresentation.draftArcStartPoint != nil
      || canvasPresentation.draftArcSweepAngleRad != nil
      || !canvasPresentation.pendingConstraintTargets.isEmpty
      || !selectedEntityIDs.isEmpty
      || selectedEntityID != nil
      || selectedMeasurementAnnotationID != nil
      || selectedFreeTextID != nil
      || selectedStitchStartPointID != nil
  }

  private var commandAvailability: WorkspaceCommandAvailability {
    WorkspaceViewStateFactory.makeCommandAvailability(
      hasDocument: cadSession.hasDocument,
      viewMode: canvasPresentation.viewMode,
      document: currentDocumentState,
      selection: selectionViewState,
      clipboardBundle: documentPresentation.clipboardBundle,
      hasPendingInteraction: hasPendingInteraction
    )
  }

  var canDeleteSelection: Bool { commandAvailability.canDeleteSelection }
  var canDeleteSelectedConstraint: Bool {
    selectedConstraintID.flatMap { id in constraints.first(where: { $0.id == id }) } != nil
  }
  var canDeleteSelectedMeasurementAnnotation: Bool {
    selectedMeasurementAnnotationID.flatMap { id in
      measurementAnnotations.first(where: { $0.id == id })
    } != nil
  }
  var canDeleteSelectedFreeText: Bool {
    selectedFreeTextID.flatMap { id in freeTexts.first(where: { $0.id == id }) } != nil
  }
  var canDeleteSelectedStitchStartPoint: Bool {
    selectedStitchStartPointID.flatMap { id in stitchStartPoints.first(where: { $0.id == id }) }
      != nil
  }
  var canSelectAllEntities: Bool { commandAvailability.canSelectAllEntities }
  var canCopySelection: Bool { commandAvailability.canCopySelection }
  var canDuplicateSelection: Bool { commandAvailability.canDuplicateSelection }
  var canPasteSelection: Bool { commandAvailability.canPasteSelection }
  var canCancelCurrentInteraction: Bool { commandAvailability.canCancelCurrentInteraction }
  var canConstrainSelectedLineLengthsEqual: Bool {
    CanvasInteractionFeature.lineTargetsForEqualLength(entities: selectedEntities).count == 2
  }
  var canUndo: Bool { cadSession.canUndo }
  var canRedo: Bool { cadSession.canRedo }
  var isDocumentDirty: Bool { cadSession.isDocumentDirty }
  var outputPreviewSummaryText: String? {
    WorkspaceViewStateFactory.outputPreviewSummaryText(
      viewMode: canvasPresentation.viewMode,
      buildResult: outputPresentation.previewBuildResult
    )
  }
}
