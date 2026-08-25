import Testing

@testable import KawaCADApp

struct WorkspaceViewStateFactoryTests {
  @Test
  func selection_uses_primary_entity_when_multi_selection_is_empty() {
    let first = lineEntity(
      id: "entity:first",
      start: .zero,
      end: ModelPoint(xMM: 10, yMM: 0)
    )
    let second = lineEntity(
      id: "entity:second",
      start: .zero,
      end: ModelPoint(xMM: 0, yMM: 10)
    )
    let document = makeDocumentState(entities: [first, second])

    let selection = WorkspaceViewStateFactory.makeSelection(
      document: document,
      primaryEntityID: second.id,
      entityIDs: [],
      selectedConstraintID: nil,
      selectedMeasurementAnnotationID: nil,
      selectedFreeTextID: nil,
      selectedStitchStartPointID: nil
    )

    #expect(selection.selectedEntity?.id == second.id)
    #expect(selection.selectedEntities.map(\.id) == [second.id])
    #expect(selection.hasClipboardSelection)
  }

  @Test
  func command_availability_disables_editing_in_output_preview() {
    let entity = lineEntity(
      id: "entity:selected",
      start: .zero,
      end: ModelPoint(xMM: 10, yMM: 0)
    )
    let document = makeDocumentState(entities: [entity])
    let selection = WorkspaceViewStateFactory.makeSelection(
      document: document,
      primaryEntityID: entity.id,
      entityIDs: [entity.id],
      selectedConstraintID: nil,
      selectedMeasurementAnnotationID: nil,
      selectedFreeTextID: nil,
      selectedStitchStartPointID: nil
    )

    let editing = WorkspaceViewStateFactory.makeCommandAvailability(
      hasDocument: true,
      viewMode: .editDisplay,
      document: document,
      selection: selection,
      clipboardBundle: nil,
      hasPendingInteraction: false
    )
    let preview = WorkspaceViewStateFactory.makeCommandAvailability(
      hasDocument: true,
      viewMode: .outputPreview,
      document: document,
      selection: selection,
      clipboardBundle: nil,
      hasPendingInteraction: false
    )

    #expect(editing.canDeleteSelection)
    #expect(editing.canCopySelection)
    #expect(!preview.canDeleteSelection)
    #expect(!preview.canCopySelection)
  }

  @Test
  func aggregated_constraint_status_uses_the_summary_for_the_active_view_mode() {
    let statistics = LeatherDocumentStatistics(
      layerCount: 0,
      sharedStyleCount: 0,
      parameterCount: 0,
      entityCount: 0,
      derivedElementCount: 0,
      constraintCount: 0
    )
    let snapshot = LeatherDocumentSnapshot(
      statistics: statistics,
      editDisplaySummary: LeatherSnapshotSummary(
        visibleEntityCount: 0,
        constraintCount: 0,
        constraintStatus: .underConstrained
      ),
      outputPreviewSummary: LeatherSnapshotSummary(
        visibleEntityCount: 0,
        constraintCount: 0,
        constraintStatus: .fullyConstrained
      )
    )

    #expect(
      WorkspaceViewStateFactory.aggregatedConstraintStatus(
        viewMode: .editDisplay,
        snapshot: snapshot,
        constraints: []
      ) == .underConstrained
    )
    #expect(
      WorkspaceViewStateFactory.aggregatedConstraintStatus(
        viewMode: .outputPreview,
        snapshot: snapshot,
        constraints: []
      ) == .fullyConstrained
    )
  }
}
