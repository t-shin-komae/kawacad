import Combine
import Testing

@testable import KawaCADApp

struct FeatureStateOwnershipTests {
  @Test
  func error_presentation_state_merges_repeated_errors_and_dismisses_them() {
    let state = AppErrorPresentationState()
    let error = AppErrorPresentation.make(
      category: .operationFailure,
      code: "commandFailed",
      operation: "addLine",
      message: "failed"
    )

    state.present(error)
    state.present(error)

    #expect(state.presentation?.occurrenceCount == 2)
    state.dismiss()
    #expect(state.presentation == nil)
  }

  @Test
  func inspector_state_owns_tab_search_and_reset_behavior() {
    let state = InspectorPresentationState()

    state.setTab(.layers, selectionSignature: "entity:a")
    state.setLayerSearchQuery("outline")
    state.revealSearchForCurrentTab()

    #expect(state.tab == .layers)
    #expect(state.layerSearchVisible)
    #expect(state.layerSearchQuery == "outline")
    #expect(state.acknowledgedSelectionSignature == "entity:a")

    state.reset()

    #expect(state.tab == .selection)
    #expect(!state.layerSearchVisible)
    #expect(state.layerSearchQuery.isEmpty)
  }

  @Test
  func inspector_feature_filters_without_owning_state() {
    let values = ["Outline", "Stitch", "Dimension"]

    #expect(
      InspectorFeature.filter(values, query: "line") { [$0] }
        == ["Outline"]
    )
    #expect(
      InspectorFeature.selectionSignature(
        selectedEntityID: "entity:b",
        selectedEntityIDs: ["entity:b", "entity:a"],
        selectedConstraintID: nil,
        selectedMeasurementAnnotationID: nil,
        selectedFreeTextID: nil,
        selectedStitchStartPointID: nil
      ) == "entity:b|entity:a,entity:b||||"
    )
  }

  @Test
  @MainActor
  func coordinator_does_not_rebroadcast_feature_state_changes() {
    let documentAdapter = StubDocumentSessionAdapter(
      createNewDocumentState: makeDocumentState()
    )
    let coordinator = AppCoordinator(
      documentAdapter: documentAdapter,
      coreStatusProvider: {
        .connected(.init(fileFormatMajor: 0, schemaMajor: 0))
      }
    )
    var coordinatorChanges = 0
    var canvasChanges = 0
    let coordinatorObservation = coordinator.objectWillChange.sink {
      coordinatorChanges += 1
    }
    let canvasObservation = coordinator.canvasPresentation.objectWillChange.sink {
      canvasChanges += 1
    }

    coordinator.canvasPresentation.setSelectedTool(.line)

    #expect(canvasChanges == 1)
    #expect(coordinatorChanges == 0)
    withExtendedLifetime((coordinatorObservation, canvasObservation)) {}
  }

  @Test
  @MainActor
  func annotation_selection_is_an_independent_owner_shared_with_canvas_state() {
    let annotationSelection = AnnotationSelectionState()
    let canvas = CanvasPresentationState(
      annotationSelection: annotationSelection
    )
    var annotationChanges = 0
    var canvasChanges = 0
    let annotationObservation = annotationSelection.objectWillChange.sink {
      annotationChanges += 1
    }
    let canvasObservation = canvas.objectWillChange.sink {
      canvasChanges += 1
    }

    annotationSelection.setSelectedConstraintID("constraint:a")

    #expect(canvas.selectedConstraintID == "constraint:a")
    #expect(annotationChanges == 1)
    #expect(canvasChanges == 0)
    withExtendedLifetime((annotationObservation, canvasObservation)) {}
  }
}
