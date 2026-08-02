import KawaCADOutput

/// Immutable selection-derived values used by views and actions.
struct WorkspaceSelectionViewState {
  let selectedEntity: CanvasEntity?
  let selectedEntities: [CanvasEntity]
  let selectedFreeText: ProjectFreeText?
  let selectedClipboardEntities: [CanvasEntity]
  let selectedDerivedRootIDs: [String]
  let selectedConstraint: ProjectConstraint?
  let selectedMeasurementAnnotation: ProjectMeasurementAnnotation?
  let selectedRoundHole: ProjectRoundHole?
  let selectedStitchStartPoint: ProjectStitchStartPoint?

  var hasClipboardSelection: Bool {
    !selectedClipboardEntities.isEmpty
      || !selectedDerivedRootIDs.isEmpty
      || selectedFreeText != nil
      || selectedConstraint != nil
      || selectedMeasurementAnnotation != nil
      || selectedStitchStartPoint != nil
  }
}

/// Immutable command availability consumed by the workspace and native menu.
struct WorkspaceCommandAvailability {
  let canDeleteSelection: Bool
  let canSelectAllEntities: Bool
  let canCopySelection: Bool
  let canDuplicateSelection: Bool
  let canPasteSelection: Bool
  let canCancelCurrentInteraction: Bool
}

/// Pure selectors/factories shared by SwiftUI props and coordinator actions.
/// Every input is an immutable value; the factory neither owns nor mutates
/// feature state.
enum WorkspaceViewStateFactory {
  static func selectedDerivedElement(
    selectedEntities: [CanvasEntity],
    derivedElements: [ProjectDerivedElement]
  ) -> ProjectDerivedElement? {
    let selectedIDs = Set(selectedEntities.compactMap(\.derivedElementID))
    guard selectedIDs.count == 1, let selectedID = selectedIDs.first else {
      return nil
    }
    return derivedElements.first { $0.id == selectedID }
  }

  static func selectedInspectorPart(
    selectedPartID: String?,
    parts: [ProjectPart]
  ) -> ProjectPart? {
    selectedPartID.flatMap { id in parts.first { $0.id == id } }
  }

  static func makeSelection(
    document: LeatherDocumentState?,
    primaryEntityID: String?,
    entityIDs: Set<String>,
    selectedConstraintID: String?,
    selectedMeasurementAnnotationID: String?,
    selectedFreeTextID: String?,
    selectedStitchStartPointID: String?
  ) -> WorkspaceSelectionViewState {
    let entities = document?.entities ?? []
    let selectedEntity = entities.first { $0.id == primaryEntityID }
    let selectedEntities =
      entityIDs.isEmpty
      ? selectedEntity.map { [$0] } ?? []
      : entities.filter { entityIDs.contains($0.id) }
    let selectedFreeText = selectedFreeTextID.flatMap { id in
      document?.freeTexts.first { $0.id == id }
    }
    let selectedConstraint = selectedConstraintID.flatMap { id in
      document?.constraints.first { $0.id == id }
    }
    let selectedMeasurementAnnotation = selectedMeasurementAnnotationID.flatMap { id in
      document?.measurementAnnotations.first { $0.id == id }
    }
    let selectedStitchStartPoint = selectedStitchStartPointID.flatMap { id in
      document?.stitchStartPoints.first { $0.id == id }
    }
    let selectedRoundHole = primaryEntityID.flatMap { entityID in
      document?.roundHoles.first { $0.entityID == entityID }
    }

    return WorkspaceSelectionViewState(
      selectedEntity: selectedEntity,
      selectedEntities: selectedEntities,
      selectedFreeText: selectedFreeText,
      selectedClipboardEntities: selectedEntities.filter {
        $0.derivedElementID == nil
      },
      selectedDerivedRootIDs: Array(
        Set(selectedEntities.compactMap(\.derivedElementID))
      ).sorted(),
      selectedConstraint: selectedConstraint,
      selectedMeasurementAnnotation: selectedMeasurementAnnotation,
      selectedRoundHole: selectedRoundHole,
      selectedStitchStartPoint: selectedStitchStartPoint
    )
  }

  static func makeCommandAvailability(
    hasDocument: Bool,
    viewMode: CanvasViewMode,
    document: LeatherDocumentState?,
    selection: WorkspaceSelectionViewState,
    clipboardBundle: ClipboardBundle?,
    hasPendingInteraction: Bool
  ) -> WorkspaceCommandAvailability {
    let isEditable = viewMode != .outputPreview
    let hasDeletableAnnotation =
      selection.selectedConstraint != nil
      || selection.selectedMeasurementAnnotation != nil
      || selection.selectedFreeText != nil
      || selection.selectedStitchStartPoint != nil
    let canCopySelection = isEditable && selection.hasClipboardSelection

    return WorkspaceCommandAvailability(
      canDeleteSelection: isEditable
        && (!selection.selectedEntities.isEmpty || hasDeletableAnnotation),
      canSelectAllEntities: isEditable && !(document?.entities.isEmpty ?? true),
      canCopySelection: canCopySelection,
      canDuplicateSelection: canCopySelection,
      canPasteSelection: hasDocument
        && isEditable
        && !(clipboardBundle?.isEmpty ?? true),
      canCancelCurrentInteraction: hasPendingInteraction
    )
  }

  static func aggregatedConstraintStatus(
    viewMode: CanvasViewMode,
    snapshot: LeatherDocumentSnapshot?,
    constraints: [ProjectConstraint]
  ) -> ConstraintStatus {
    switch viewMode {
    case .editDisplay:
      return snapshot?.editDisplaySummary.constraintStatus
        ?? constraints.map(\.status).aggregated()
    case .outputPreview:
      return snapshot?.outputPreviewSummary.constraintStatus
        ?? constraints.map(\.status).aggregated()
    }
  }

  static func outputPreviewSummaryText(
    viewMode: CanvasViewMode,
    buildResult: OutputBuildResult?
  ) -> String? {
    guard viewMode == .outputPreview, let buildResult else {
      return nil
    }
    if !buildResult.warnings.isEmpty {
      return AppStrings.tr(
        "status_item.output_preview_warnings",
        buildResult.warnings.map(\.message).joined(
          separator: AppStrings.tr(
            "status_item.output_preview_warning_separator"
          )
        )
      )
    }
    return AppStrings.tr(
      "status_item.output_preview_pages",
      buildResult.outputDocumentModel.pageCount
    )
  }
}
